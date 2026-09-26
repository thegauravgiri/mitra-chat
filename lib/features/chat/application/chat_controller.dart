import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/logger.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/stores/attachment_store.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/agent/agent_event.dart';
import '../../../domain/agent/agent_orchestrator.dart';
import '../../../integrations/llm/anthropic_provider.dart';
import '../../../integrations/llm/gemini_provider.dart';
import '../../../integrations/llm/llm_provider.dart';
import '../../../integrations/llm/openai_provider.dart';
import '../../../integrations/notion/notion_client.dart';

final conversationMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessages(conversationId);
});

final conversationToolInvocationsProvider =
    StreamProvider.family<List<ToolInvocation>, String>((ref, conversationId) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchToolInvocationsForConversation(conversationId);
});

final chatControllerProvider = StateNotifierProvider.family<
    ChatController, ChatState, String>((ref, conversationId) {
  return ChatController(ref: ref, conversationId: conversationId);
});

class ChatState {
  const ChatState({
    this.isStreaming = false,
    this.inFlightText = '',
    this.errorMessage,
  });

  final bool isStreaming;
  final String inFlightText;
  final String? errorMessage;

  ChatState copyWith({
    bool? isStreaming,
    String? inFlightText,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ChatState(
        isStreaming: isStreaming ?? this.isStreaming,
        inFlightText: inFlightText ?? this.inFlightText,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required this.ref,
    required this.conversationId,
  }) : super(const ChatState());

  final Ref ref;
  final String conversationId;

  CancelToken? _cancelToken;
  StreamSubscription<AgentEvent>? _orchestratorSub;

  void _finishRun({String? error}) {
    _orchestratorSub?.cancel();
    _orchestratorSub = null;
    state = state.copyWith(
      isStreaming: false,
      inFlightText: '',
      errorMessage: error,
      clearError: error == null && state.errorMessage != null,
    );
    ref.read(messageRepositoryProvider).cleanUpStaleStreamingMessages(conversationId);
  }

  Future<void> sendMessage({
    required String text,
    List<StoredAttachmentInfo> attachments = const [],
  }) async {
    if (state.isStreaming) return;

    final msgRepo = ref.read(messageRepositoryProvider);
    final convoRepo = ref.read(conversationRepositoryProvider);
    final attStore = ref.read(attachmentStoreProvider);
    final secStore = ref.read(secretStoreProvider);
    final prefsStore = ref.read(prefsStoreProvider);

    // 1. Append user message
    await msgRepo.appendUserMessage(
      conversationId: conversationId,
      text: text,
      attachments: attachments,
    );

    // 1b. Immediately auto-set preliminary title if conversation has default title
    final convo = await convoRepo.getConversationById(conversationId);
    if (convo != null && ConversationRepository.isDefaultTitle(convo.title) && text.trim().isNotEmpty) {
      final preliminaryTitle = ConversationRepository.derivePreliminaryTitle(text);
      await convoRepo.updateTitle(conversationId, preliminaryTitle);
    }

    // 2. Ensure session-scoped AgentRuntime is ready
    final runtime = ref.read(agentRuntimeProvider);
    await runtime.ensureReady();

    // 3. Setup Providers
    final providers = <String, LlmProvider>{
      'gemini': GeminiProvider(
        apiKeyProvider: () => secStore.getGeminiApiKey(),
      ),
      'anthropic': AnthropicProvider(
        apiKeyProvider: () => secStore.getAnthropicApiKey(),
      ),
      'openai': OpenAiProvider(
        apiKeyProvider: () => secStore.getOpenAiApiKey(),
      ),
    };

    final orchestrator = AgentOrchestrator(
      messageRepository: msgRepo,
      conversationRepository: convoRepo,
      attachmentStore: attStore,
      toolRegistry: runtime.toolRegistry,
      providers: providers,
    );

    state = state.copyWith(isStreaming: true, inFlightText: '', clearError: true);
    _cancelToken = CancelToken();

    final providerId = prefsStore.providerId;
    final modelId = prefsStore.modelId;

    final eventStream = orchestrator.run(
      conversationId: conversationId,
      providerId: providerId,
      modelId: modelId,
      skillContext: runtime.skillContext,
      autoRunTools: prefsStore.autoRunTools,
      cancelToken: _cancelToken,
    );

    _orchestratorSub = eventStream.listen(
      (event) {
        switch (event) {
          case AgentTextDelta(:final delta):
            state = state.copyWith(inFlightText: state.inFlightText + delta);
          case AgentStepStarted():
          case AgentToolRetrying():
          case AgentToolAwaitingConfirmation():
          case AgentToolCallProposed():
          case AgentToolStarted():
          case AgentToolCompleted():
          case AgentToolFailed():
            break;
          case AgentDone():
            _finishRun();
          case AgentFailed(:final errorMessage):
            _finishRun(error: errorMessage);
        }
      },
      onError: (Object e) {
        AppLogger.error('Orchestrator stream error', e);
        _finishRun(error: e.toString());
      },
      onDone: () {
        if (state.isStreaming) {
          _finishRun();
        }
      },
    );
  }

  void cancelRun() {
    _cancelToken?.cancel();
    _finishRun();
  }

  Future<void> undoToolInvocation(ToolInvocation invocation) async {
    final msgRepo = ref.read(messageRepositoryProvider);
    final secStore = ref.read(secretStoreProvider);

    if (invocation.toolName == 'notion.create_tasks') {
      final token = await secStore.getNotionToken();
      if (token != null && token.isNotEmpty && invocation.resultJson != null) {
        try {
          final res = jsonDecode(invocation.resultJson!) as Map<String, dynamic>;
          final created = res['created_tasks'] as List<dynamic>? ?? [];
          final client = NotionClient(apiKey: token);
          for (final task in created) {
            if (task is Map<String, dynamic> && task['page_id'] != null) {
              await client.archivePage(task['page_id'] as String);
            }
          }
        } catch (_) {}
      }
    }
    await msgRepo.markToolUndone(invocation.id);
  }

  Future<void> deleteMessage(String messageId) async {
    final db = ref.read(databaseProvider);
    await db.messageDao.deleteMessage(messageId);
  }

  Future<void> retryMessage(String messageId) async {
    final msgRepo = ref.read(messageRepositoryProvider);
    final messages = await msgRepo.getMessages(conversationId);
    final msg = messages.firstWhere((m) => m.id == messageId, orElse: () => throw StateError('Not found'));
    if (msg.role == MessageRole.user) {
      await sendMessage(text: msg.content);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _orchestratorSub?.cancel();
    _orchestratorSub = null;
    super.dispose();
  }
}
