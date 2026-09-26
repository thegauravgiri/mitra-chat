import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import '../../core/logging/logger.dart';
import '../../domain/agent/tool_descriptor.dart';
import '../../domain/models/enums.dart';
import 'llm_provider.dart';
import 'llm_types.dart';

class _OpenAiToolCallAccumulator {
  String id = '';
  String name = '';
  String argumentsJson = '';
}

class OpenAiProvider implements LlmProvider {
  OpenAiProvider({
    required this.apiKeyProvider,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 120),
              ),
            );

  final Future<String?> Function() apiKeyProvider;
  final Dio _dio;

  @override
  String get id => 'openai';

  @override
  List<ModelOption> get models =>
      kAvailableModels.where((m) => m.providerId == 'openai').toList();

  @override
  bool get supportsVision => true;

  @override
  bool get supportsTools => true;

  @override
  Stream<LlmStreamEvent> streamChat({
    required List<LlmMessage> history,
    required List<ToolDescriptor> tools,
    required String systemPrompt,
    required String modelId,
    CancelToken? cancelToken,
  }) async* {
    final apiKey = await apiKeyProvider();
    if (apiKey == null || apiKey.isEmpty) {
      yield const LlmErrorEvent('OpenAI API Key is not configured in Settings.');
      return;
    }

    final formattedMessages = _formatMessages(history, systemPrompt);
    final openAiTools = _formatTools(tools);

    final payload = <String, dynamic>{
      'model': modelId,
      'messages': formattedMessages,
      'stream': true,
      'temperature': 0.2,
    };

    if (openAiTools.isNotEmpty) {
      payload['tools'] = openAiTools;
    }

    final localCancelToken = CancelToken();
    if (cancelToken != null) {
      unawaited(cancelToken.whenCancel.then((_) {
        if (!localCancelToken.isCancelled) {
          localCancelToken.cancel('Caller cancelled');
        }
      }));
    }

    var finished = false;

    try {
      final response = await _dio.post<ResponseBody>(
        'https://api.openai.com/v1/chat/completions',
        data: payload,
        cancelToken: localCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        yield const LlmErrorEvent('Empty response from OpenAI API.');
        return;
      }

      var buffer = '';
      final Map<int, _OpenAiToolCallAccumulator> toolAccumulators = {};

      await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
        if (localCancelToken.isCancelled || (cancelToken?.isCancelled ?? false)) break;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data:')) {
            final jsonStr = trimmed.substring(5).trim();
            if (trimmed == 'data: [DONE]' || jsonStr == '[DONE]') {
              for (final acc in toolAccumulators.values) {
                if (acc.name.isNotEmpty) {
                  Map<String, dynamic> args = {};
                  try {
                    if (acc.argumentsJson.isNotEmpty) {
                      args = jsonDecode(acc.argumentsJson) as Map<String, dynamic>;
                    }
                  } catch (_) {}

                  yield LlmToolCallEvent(ToolCallProposal(
                    callId: acc.id.isNotEmpty
                        ? acc.id
                        : 'call_${DateTime.now().millisecondsSinceEpoch}',
                    toolName: acc.name,
                    arguments: args,
                  ));
                }
              }
              toolAccumulators.clear();
              finished = true;
              break;
            }

            try {
              final decoded = jsonDecode(jsonStr);
              if (decoded is Map<String, dynamic>) {
                final choices = decoded['choices'] as List<dynamic>? ?? [];
                if (choices.isNotEmpty) {
                  final first = choices.first as Map<String, dynamic>;
                  final delta = first['delta'] as Map<String, dynamic>? ?? {};

                  // Text delta
                  final content = delta['content'] as String?;
                  if (content != null && content.isNotEmpty) {
                    yield LlmTextDeltaEvent(content);
                  }

                  // Tool calls delta
                  final toolCalls = delta['tool_calls'] as List<dynamic>?;
                  if (toolCalls != null) {
                    for (final tc in toolCalls) {
                      if (tc is Map<String, dynamic>) {
                        final index = tc['index'] as int? ?? 0;
                        final acc = toolAccumulators.putIfAbsent(
                          index,
                          () => _OpenAiToolCallAccumulator(),
                        );

                        if (tc['id'] != null) acc.id = tc['id'] as String;
                        final fn = tc['function'] as Map<String, dynamic>?;
                        if (fn != null) {
                          if (fn['name'] != null) {
                            acc.name = (fn['name'] as String).replaceAll('__', '.');
                          }
                          if (fn['arguments'] != null) {
                            acc.argumentsJson += fn['arguments'] as String;
                          }
                        }
                      }
                    }
                  }
                }
              }
            } catch (e) {
              AppLogger.warning('OpenAI SSE chunk parse error: $e');
            }
          }
        }
        if (finished) break;
      }

      // Emit accumulated tool calls if any remain
      for (final acc in toolAccumulators.values) {
        if (acc.name.isNotEmpty) {
          Map<String, dynamic> args = {};
          try {
            if (acc.argumentsJson.isNotEmpty) {
              args = jsonDecode(acc.argumentsJson) as Map<String, dynamic>;
            }
          } catch (_) {}

          yield LlmToolCallEvent(ToolCallProposal(
            callId: acc.id.isNotEmpty
                ? acc.id
                : 'call_${DateTime.now().millisecondsSinceEpoch}',
            toolName: acc.name,
            arguments: args,
          ));
        }
      }

      if (!localCancelToken.isCancelled && !(cancelToken?.isCancelled ?? false)) {
        yield const LlmDoneEvent();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || localCancelToken.isCancelled || (cancelToken?.isCancelled ?? false)) {
        yield const LlmErrorEvent('Request was cancelled.');
      } else {
        var msg = e.message ?? 'OpenAI error';
        try {
          final data = e.response?.data;
          if (data is ResponseBody) {
            final bytes = await data.stream.reduce((a, b) => Uint8List.fromList([...a, ...b]));
            final bodyStr = utf8.decode(bytes);
            final decoded = jsonDecode(bodyStr);
            if (decoded is Map<String, dynamic>) {
              final errorMap = decoded['error'] as Map<String, dynamic>?;
              msg = errorMap?['message'] as String? ?? bodyStr;
            } else {
              msg = bodyStr;
            }
          } else if (data is Map<String, dynamic>) {
            final errorMap = data['error'] as Map<String, dynamic>?;
            msg = errorMap?['message'] as String? ?? msg;
          }
        } catch (_) {}
        yield LlmErrorEvent(msg);
      }
    } catch (e) {
      yield LlmErrorEvent(e.toString());
    } finally {
      if (!localCancelToken.isCancelled) {
        localCancelToken.cancel('stream complete');
      }
    }
  }

  @visibleForTesting
  List<Map<String, dynamic>> formatMessagesForTesting(
          List<LlmMessage> history, String systemPrompt) =>
      _formatMessages(history, systemPrompt);

  @visibleForTesting
  List<Map<String, dynamic>> formatToolsForTesting(List<ToolDescriptor> tools) =>
      _formatTools(tools);

  List<Map<String, dynamic>> _formatMessages(List<LlmMessage> history, String systemPrompt) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      if (msg.role == MessageRole.assistant) {
        final toolCalls = <Map<String, dynamic>>[];
        var textContent = '';
        for (final part in msg.parts) {
          switch (part) {
            case TextPart(:final text):
              textContent += text;
            case ToolCallPart(:final callId, :final toolName, :final arguments):
              toolCalls.add({
                'id': callId,
                'type': 'function',
                'function': {
                  'name': toolName.replaceAll('.', '__'),
                  'arguments': jsonEncode(arguments),
                },
              });
            case ImagePart():
              break;
            case ToolResponsePart():
              break;
          }
        }
        final assistantMap = <String, dynamic>{
          'role': 'assistant',
          'content': textContent.isNotEmpty ? textContent : null,
        };
        if (toolCalls.isNotEmpty) {
          assistantMap['tool_calls'] = toolCalls;
        }
        messages.add(assistantMap);
        continue;
      }

      if (msg.role == MessageRole.tool) {
        for (final part in msg.parts) {
          if (part is ToolResponsePart) {
            messages.add({
              'role': 'tool',
              'tool_call_id': part.callId,
              'content': jsonEncode(part.response),
            });
          }
        }
        continue;
      }

      if (msg.role == MessageRole.user) {
        final contents = <Map<String, dynamic>>[];
        for (final part in msg.parts) {
          switch (part) {
            case TextPart(:final text):
              if (text.isNotEmpty) contents.add({'type': 'text', 'text': text});
            case ImagePart(:final bytes, :final mimeType):
              contents.add({
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,${base64Encode(bytes)}'},
              });
            default:
              break;
          }
        }
        if (contents.isNotEmpty) {
          messages.add({'role': 'user', 'content': contents});
        }
        continue;
      }
    }

    return messages;
  }

  List<Map<String, dynamic>> _formatTools(List<ToolDescriptor> tools) {
    return tools.map((t) {
      return {
        'type': 'function',
        'function': {
          'name': t.name.replaceAll('.', '__'),
          'description': t.description,
          'parameters': t.inputSchema,
        },
      };
    }).toList();
  }
}
