import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/failures.dart';
import '../../core/logging/logger.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/stores/attachment_store.dart';
import '../../integrations/llm/llm_provider.dart';
import '../../integrations/llm/llm_types.dart';
import '../models/enums.dart';
import 'agent_event.dart';
import 'system_prompts.dart';
import 'tool_descriptor.dart';
import 'tool_registry.dart';
import 'tool_result_envelope.dart';

class AgentOrchestrator {
  AgentOrchestrator({
    required MessageRepository messageRepository,
    required ConversationRepository conversationRepository,
    required this.attachmentStore,
    required this.toolRegistry,
    required this.providers,
    this.maxSteps = 25,
    this.maxConsecutiveToolErrors = 4,
    this.watchdogTimeout = const Duration(seconds: 90),
  })  : _messageRepo = messageRepository,
        _conversationRepo = conversationRepository;

  final MessageRepository _messageRepo;
  final ConversationRepository _conversationRepo;
  final AttachmentStore attachmentStore;
  final ToolRegistry toolRegistry;
  final Map<String, LlmProvider> providers;
  final int maxSteps;
  final int maxConsecutiveToolErrors;
  final Duration watchdogTimeout;

  Stream<AgentEvent> run({
    required String conversationId,
    required String providerId,
    required String modelId,
    String? skillContext,
    bool autoRunTools = true,
    Future<bool> Function({
      required String invocationId,
      required String toolName,
      required Map<String, dynamic> arguments,
    })? confirmationHandler,
    CancelToken? cancelToken,
  }) async* {
    final provider = providers[providerId];
    if (provider == null) {
      const err = 'Selected LLM provider is not available.';
      yield const AgentFailed(messageId: '', errorMessage: err);
      return;
    }

    // 1. Create streaming assistant message placeholder
    final assistantMsg =
        await _messageRepo.createPendingAssistantMessage(conversationId);
    final messageId = assistantMsg.id;

    var accumulatedText = '';
    final systemPrompt = SystemPrompts.buildAgentSystemPrompt(
      skillContext: skillContext,
    );

    // 2. Build history with context budgeting and tool memory (Plan §7.4, §F2.3.5)
    final history = await _buildBudgetedHistory(conversationId);

    var currentStep = 0;
    var done = false;
    final callCounts = <String, int>{};
    var consecutiveErrors = 0;

    while (currentStep < maxSteps && !done) {
      currentStep++;
      yield AgentStepStarted(step: currentStep, maxSteps: maxSteps);

      if (cancelToken?.isCancelled ?? false) {
        await _messageRepo.failAssistantMessage(messageId, 'Request cancelled');
        yield AgentFailed(messageId: messageId, errorMessage: 'Request cancelled');
        return;
      }

      // Step budget final nudge: at maxSteps - 1, nudge to summarize
      if (currentStep == maxSteps - 1) {
        history.add(const LlmMessage(
          role: MessageRole.user,
          parts: [
            TextPart(
              'Step budget nearly exhausted. Do not call more tools. Summarize what you found and what remains.',
            ),
          ],
        ));
      }

      // Force text only on the absolute final step
      final tools = (currentStep >= maxSteps)
          ? const <ToolDescriptor>[]
          : toolRegistry.getAll();
      final toolCallsInStep = <ToolCallProposal>[];

      // Stream from LLM provider
      final rawStream = provider.streamChat(
        history: history,
        tools: tools,
        systemPrompt: systemPrompt,
        modelId: modelId,
        cancelToken: cancelToken,
      );

      final stream = rawStream.timeout(
        watchdogTimeout,
        onTimeout: (sink) {
          sink.add(const LlmErrorEvent('Provider stream stalled'));
          sink.close();
        },
      );

      var stepText = '';
      var providerFinished = false;

      await for (final event in stream) {
        if (cancelToken?.isCancelled ?? false) {
          await _messageRepo.failAssistantMessage(messageId, 'Request cancelled');
          yield AgentFailed(messageId: messageId, errorMessage: 'Request cancelled');
          return;
        }

        switch (event) {
          case LlmTextDeltaEvent(:final delta):
            stepText += delta;
            accumulatedText += delta;
            await _messageRepo.updateMessageStreaming(messageId, accumulatedText);
            yield AgentTextDelta(delta);
          case LlmToolCallEvent(:final proposal):
            final effectiveProposal = proposal.callId.isNotEmpty
                ? proposal
                : ToolCallProposal(
                    callId: 'call_${currentStep}_${toolCallsInStep.length}_${proposal.toolName.replaceAll('.', '_')}',
                    toolName: proposal.toolName,
                    arguments: proposal.arguments,
                  );
            toolCallsInStep.add(effectiveProposal);
            yield AgentToolCallProposed(effectiveProposal);
          case LlmDoneEvent():
            providerFinished = true;
            break;
          case LlmErrorEvent(:final error):
            final errMsg = error.toString();
            await _messageRepo.failAssistantMessage(messageId, errMsg);
            yield AgentFailed(messageId: messageId, errorMessage: errMsg);
            return;
        }

        if (providerFinished) {
          break;
        }
      }

      if (toolCallsInStep.isEmpty) {
        // No tool calls -> turn complete
        final finalText = accumulatedText.trim().isNotEmpty
            ? accumulatedText
            : 'Completed request.';
        await _messageRepo.completeAssistantMessage(messageId, finalText);
        yield AgentDone(messageId: messageId, finalText: finalText);
        done = true;
        break;
      } else {
        // Append model turn to history with ToolCallParts
        final modelParts = <LlmPart>[
          if (stepText.isNotEmpty) TextPart(stepText),
          for (final p in toolCallsInStep)
            ToolCallPart(
              callId: p.callId,
              toolName: p.toolName,
              arguments: p.arguments,
            ),
        ];
        if (modelParts.isNotEmpty) {
          history.add(LlmMessage(role: MessageRole.assistant, parts: modelParts));
        }

        if (cancelToken?.isCancelled ?? false) {
          for (final p in toolCallsInStep) {
            history.add(LlmMessage(
              role: MessageRole.tool,
              parts: [
                ToolResponsePart(
                  callId: p.callId,
                  toolName: p.toolName,
                  response: const {'error': 'cancelled'},
                ),
              ],
            ));
          }
          await _messageRepo.failAssistantMessage(messageId, 'Request cancelled');
          yield AgentFailed(messageId: messageId, errorMessage: 'Request cancelled');
          return;
        }

        // Execute proposed tool calls (parallel where possible)
        final toolExecutionFutures = toolCallsInStep.map((proposal) async {
          final toolDesc = toolRegistry.get(proposal.toolName);
          final source = toolDesc?.source ?? ToolSource.builtin;
          final serverId = toolDesc?.serverId;
          final canonicalKey =
              '${proposal.toolName}::${jsonEncode(_canonicalJsonMap(proposal.arguments))}';
          final previousAttempts = callCounts[canonicalKey] ?? 0;

          // Record in DB as running
          final invocation = await _messageRepo.recordToolInvocation(
            messageId: messageId,
            toolName: proposal.toolName,
            source: source,
            serverId: serverId,
            argumentsJson: jsonEncode(proposal.arguments),
          );

          // Repetition guard (Plan §F2.3.3): if identical call proposed 3rd time, refuse it
          if (previousAttempts >= 2) {
            const repetitionMsg =
                'This exact call was already attempted twice with the same arguments and the same result. Change the arguments or take a different approach.';
            final failureEnvelope = ToolResultEnvelope.failure(
              message: repetitionMsg,
              customErrorKind: 'invalid_argument',
              customRecoverable: false,
              attempt: previousAttempts + 1,
            );
            await _messageRepo.updateToolInvocationResult(
              invocationId: invocation.id,
              status: ToolStatus.error,
              errorMessage: repetitionMsg,
              durationMs: 0,
            );
            return (
              proposal: proposal,
              invocationId: invocation.id,
              source: source,
              result: failureEnvelope,
              failure: ToolFailure(
                toolName: proposal.toolName,
                message: repetitionMsg,
              ),
            );
          }

          callCounts[canonicalKey] = previousAttempts + 1;

          // Confirmation gating (Plan §F2.3.4, TASK-1016)
          final requiresConfirmation =
              (toolDesc?.requiresConfirmation ?? false) || !autoRunTools;
          if (requiresConfirmation) {
            final confirmed = confirmationHandler != null
                ? await confirmationHandler(
                    invocationId: invocation.id,
                    toolName: proposal.toolName,
                    arguments: proposal.arguments,
                  )
                : true;

            if (!confirmed) {
              const declineMsg = 'The user declined this action.';
              final failureEnvelope = ToolResultEnvelope.failure(
                message: declineMsg,
                customErrorKind: 'declined',
                customRecoverable: false,
                attempt: previousAttempts + 1,
              );
              await _messageRepo.updateToolInvocationResult(
                invocationId: invocation.id,
                status: ToolStatus.error,
                errorMessage: declineMsg,
                durationMs: 0,
              );
              return (
                proposal: proposal,
                invocationId: invocation.id,
                source: source,
                result: failureEnvelope,
                failure: ToolFailure(
                  toolName: proposal.toolName,
                  message: declineMsg,
                ),
              );
            }
          }

          final stopwatch = Stopwatch()..start();
          final result = await toolRegistry.invoke(
            proposal.toolName,
            proposal.arguments,
          );
          stopwatch.stop();

          if (result.isOk) {
            final resMap = result.valueOrNull ?? {};
            final envelope = ToolResultEnvelope.success(resMap);
            await _messageRepo.updateToolInvocationResult(
              invocationId: invocation.id,
              status: ToolStatus.ok,
              resultJson: jsonEncode(resMap),
              durationMs: stopwatch.elapsedMilliseconds,
            );
            return (
              proposal: proposal,
              invocationId: invocation.id,
              source: source,
              result: envelope,
              failure: null,
            );
          } else {
            final failure = result.failureOrNull!;
            final related = toolRegistry.suggestRelated(proposal.toolName);
            final envelope = ToolResultEnvelope.failure(
              message: failure.message,
              appFailure: failure,
              relatedTools: related,
              attempt: previousAttempts + 1,
            );
            await _messageRepo.updateToolInvocationResult(
              invocationId: invocation.id,
              status: ToolStatus.error,
              errorMessage: failure.message,
              durationMs: stopwatch.elapsedMilliseconds,
            );
            return (
              proposal: proposal,
              invocationId: invocation.id,
              source: source,
              result: envelope,
              failure: failure,
            );
          }
        });

        final results = await Future.wait(toolExecutionFutures);

        var allFailed = true;
        for (final item in results) {
          if (item.failure != null) {
            consecutiveErrors++;
            yield AgentToolFailed(
              invocationId: item.invocationId,
              toolName: item.proposal.toolName,
              failure: item.failure!,
            );
          } else {
            allFailed = false;
            consecutiveErrors = 0;
            yield AgentToolCompleted(
              invocationId: item.invocationId,
              toolName: item.proposal.toolName,
              result: item.result,
            );
          }

          history.add(LlmMessage(
            role: MessageRole.tool,
            parts: [
              ToolResponsePart(
                callId: item.proposal.callId,
                toolName: item.proposal.toolName,
                response: item.result,
              ),
            ],
          ));
        }

        // If consecutive errors threshold exceeded, break loop to summarize
        if (allFailed && consecutiveErrors >= maxConsecutiveToolErrors) {
          history.add(const LlmMessage(
            role: MessageRole.user,
            parts: [
              TextPart(
                'Multiple consecutive tool errors encountered. Please explain the issue plainly to the user and summarize what was accomplished.',
              ),
            ],
          ));
        }
      }
    }

    if (!done) {
      final finalText = accumulatedText.trim().isNotEmpty
          ? accumulatedText
          : 'I processed your request, but could not produce a final text summary within the step budget.';
      await _messageRepo.completeAssistantMessage(messageId, finalText);
      yield AgentDone(messageId: messageId, finalText: finalText);
    }

    // Auto-generate title after first exchange asynchronously
    unawaited(_checkAndAutoTitle(
      conversationId,
      activeProviderId: providerId,
      activeModelId: modelId,
    ));
  }

  Future<List<LlmMessage>> _buildBudgetedHistory(String conversationId) async {
    final allMessages = await _messageRepo.getMessages(conversationId);
    final history = <LlmMessage>[];

    // Context budget: limit to last 20 messages, and at most 3 images
    final window = allMessages.length > 20
        ? allMessages.sublist(allMessages.length - 20)
        : allMessages;

    // Find the most recent assistant message in window
    final lastAssistantMsg = window.where((m) => m.role == MessageRole.assistant).lastOrNull;

    var imagesIncluded = 0;

    for (final msg in window) {
      if (msg.status == MessageStatus.streaming) continue;

      if (msg.role == MessageRole.user) {
        final parts = <LlmPart>[];
        if (msg.content.isNotEmpty) {
          parts.add(TextPart(msg.content));
        }

        // Attachments
        final atts = await _messageRepo.getAttachmentsForMessage(msg.id);
        for (final att in atts) {
          if (att.mimeType.startsWith('image/') && imagesIncluded < 3) {
            try {
              final file = await attachmentStore.resolveFile(att.relativePath);
              if (file.existsSync()) {
                final bytes = await file.readAsBytes();
                parts.add(ImagePart(bytes: bytes, mimeType: att.mimeType));
                imagesIncluded++;
              }
            } catch (_) {}
          } else {
            parts.add(const TextPart('[Attached image]'));
          }
        }

        if (parts.isNotEmpty) {
          history.add(LlmMessage(role: MessageRole.user, parts: parts));
        }
      } else if (msg.role == MessageRole.assistant) {
        final parts = <LlmPart>[];
        if (msg.content.isNotEmpty) {
          parts.add(TextPart(msg.content));
        }

        final invocations =
            await _messageRepo.getToolInvocationsForMessage(msg.id);

        if (msg.id == lastAssistantMsg?.id) {
          // Replay full ToolCallPart + ToolResponsePart for the most recent turn
          final toolCallParts = <ToolCallPart>[];
          final toolResponseMessages = <LlmMessage>[];

          for (final inv in invocations) {
            var args = <String, dynamic>{};
            if (inv.argumentsJson.isNotEmpty) {
              try {
                args = jsonDecode(inv.argumentsJson) as Map<String, dynamic>;
              } catch (_) {}
            }

            final callId = 'call_hist_${inv.id}';
            toolCallParts.add(ToolCallPart(
              callId: callId,
              toolName: inv.toolName,
              arguments: args,
            ));

            Map<String, dynamic> responseEnvelope;
            if (inv.status == ToolStatus.ok && inv.resultJson != null) {
              var rawResult = inv.resultJson!;
              if (rawResult.length > 4000) {
                rawResult = '${rawResult.substring(0, 4000)}... [truncated]';
              }
              try {
                final parsed = jsonDecode(rawResult) as Map<String, dynamic>;
                responseEnvelope = ToolResultEnvelope.success(parsed);
              } catch (_) {
                responseEnvelope = ToolResultEnvelope.success({'text': rawResult});
              }
            } else {
              responseEnvelope = ToolResultEnvelope.failure(
                message: inv.errorMessage ?? 'Tool invocation failed in prior turn',
              );
            }

            toolResponseMessages.add(LlmMessage(
              role: MessageRole.tool,
              parts: [
                ToolResponsePart(
                  callId: callId,
                  toolName: inv.toolName,
                  response: responseEnvelope,
                ),
              ],
            ));
          }

          history.add(LlmMessage(
            role: MessageRole.assistant,
            parts: [...parts, ...toolCallParts],
          ));
          history.addAll(toolResponseMessages);
        } else {
          // Compact older assistant invocations into summary text
          if (invocations.isNotEmpty) {
            final summary = invocations
                .map((inv) => '${inv.toolName}: ${inv.status.name}')
                .join(', ');
            parts.add(TextPart('[Tools used in earlier turn: $summary]'));
          }
          history.add(LlmMessage(role: MessageRole.assistant, parts: parts));
        }
      }
    }

    return history;
  }

  Map<String, dynamic> _canonicalJsonMap(Map<String, dynamic> input) {
    final keys = input.keys.toList()..sort();
    final result = <String, dynamic>{};
    for (final key in keys) {
      final val = input[key];
      if (val is Map<String, dynamic>) {
        result[key] = _canonicalJsonMap(val);
      } else if (val is List) {
        result[key] = val
            .map((item) => item is Map<String, dynamic>
                ? _canonicalJsonMap(item)
                : item)
            .toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }

  Future<void> _checkAndAutoTitle(
    String conversationId, {
    String? activeProviderId,
    String? activeModelId,
  }) async {
    try {
      final convo = await _conversationRepo.getConversationById(conversationId);
      if (convo == null) return;

      final msgs = await _messageRepo.getMessages(conversationId);
      final firstUserMsg =
          msgs.where((m) => m.role == MessageRole.user).firstOrNull;
      if (firstUserMsg == null || firstUserMsg.content.trim().isEmpty) return;

      final isDefault = ConversationRepository.isDefaultTitle(convo.title);
      final isPreliminary = convo.title ==
          ConversationRepository.derivePreliminaryTitle(firstUserMsg.content);

      if (!isDefault && !isPreliminary) {
        return;
      }

      final effectiveProvider = (activeProviderId != null
              ? providers[activeProviderId]
              : null) ??
          providers['gemini'] ??
          providers.values.firstOrNull;
      if (effectiveProvider == null) return;

      final cheapModel = effectiveProvider.models.firstWhere(
        (m) => m.isCheap,
        orElse: () => effectiveProvider.models.first,
      ).id;

      final titlePrompt =
          SystemPrompts.buildTitleGenerationPrompt(firstUserMsg.content);

      final stream = effectiveProvider.streamChat(
        history: [
          LlmMessage(
            role: MessageRole.user,
            parts: [TextPart(titlePrompt)],
          ),
        ],
        tools: [],
        systemPrompt: 'You generate brief, clean titles.',
        modelId: cheapModel,
      );

      var generatedTitle = '';
      await for (final ev in stream) {
        if (ev is LlmTextDeltaEvent) {
          generatedTitle += ev.delta;
        }
      }

      var cleanTitle = generatedTitle
          .replaceAll(
              RegExp(r'^(Title|title)\s*:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\r\n"“”`*_#]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanTitle.endsWith('.')) {
        cleanTitle = cleanTitle.substring(0, cleanTitle.length - 1).trim();
      }

      if (cleanTitle.isNotEmpty && cleanTitle.length <= 60) {
        await _conversationRepo.updateTitle(conversationId, cleanTitle);
      }
    } catch (e) {
      AppLogger.warning('Auto-titling failed: $e');
    }
  }
}
