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

class AnthropicProvider implements LlmProvider {
  AnthropicProvider({
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
  String get id => 'anthropic';

  @override
  List<ModelOption> get models =>
      kAvailableModels.where((m) => m.providerId == 'anthropic').toList();

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
      yield const LlmErrorEvent('Anthropic API Key is not configured in Settings.');
      return;
    }

    final formattedMessages = _formatMessages(history);
    final anthropicTools = _formatTools(tools);

    final payload = <String, dynamic>{
      'model': modelId,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': formattedMessages,
      'stream': true,
    };

    if (anthropicTools.isNotEmpty) {
      payload['tools'] = anthropicTools;
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
        'https://api.anthropic.com/v1/messages',
        data: payload,
        cancelToken: localCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        yield const LlmErrorEvent('Empty response from Anthropic API.');
        return;
      }

      var buffer = '';
      String? currentToolId;
      String? currentToolName;
      var currentToolArgsJson = '';

      await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
        if (localCancelToken.isCancelled || (cancelToken?.isCancelled ?? false)) break;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data:')) {
            final jsonStr = trimmed.substring(5).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

            try {
              final decoded = jsonDecode(jsonStr);
              if (decoded is Map<String, dynamic>) {
                final type = decoded['type'] as String?;

                if (type == 'content_block_start') {
                  final contentBlock = decoded['content_block'] as Map<String, dynamic>?;
                  if (contentBlock?['type'] == 'tool_use') {
                    currentToolId = contentBlock?['id'] as String?;
                    final rawName = contentBlock?['name'] as String?;
                    currentToolName = rawName?.replaceAll('__', '.');
                    currentToolArgsJson = '';
                  }
                } else if (type == 'content_block_delta') {
                  final delta = decoded['delta'] as Map<String, dynamic>?;
                  if (delta?['type'] == 'text_delta') {
                    final text = delta?['text'] as String? ?? '';
                    if (text.isNotEmpty) yield LlmTextDeltaEvent(text);
                  } else if (delta?['type'] == 'input_json_delta') {
                    currentToolArgsJson += delta?['partial_json'] as String? ?? '';
                  }
                } else if (type == 'content_block_stop') {
                  if (currentToolId != null && currentToolName != null) {
                    Map<String, dynamic> args = {};
                    try {
                      if (currentToolArgsJson.isNotEmpty) {
                        args = jsonDecode(currentToolArgsJson) as Map<String, dynamic>;
                      }
                    } catch (_) {}

                    yield LlmToolCallEvent(ToolCallProposal(
                      callId: currentToolId,
                      toolName: currentToolName,
                      arguments: args,
                    ));

                    currentToolId = null;
                    currentToolName = null;
                    currentToolArgsJson = '';
                  }
                } else if (type == 'message_stop') {
                  finished = true;
                  break;
                }
              }
            } catch (e) {
              AppLogger.warning('Anthropic SSE chunk error: $e');
            }
          }
        }
        if (finished) break;
      }

      if (!localCancelToken.isCancelled && !(cancelToken?.isCancelled ?? false)) {
        yield const LlmDoneEvent();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || localCancelToken.isCancelled || (cancelToken?.isCancelled ?? false)) {
        yield const LlmErrorEvent('Request was cancelled.');
      } else {
        var msg = e.message ?? 'Anthropic error';
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
  List<Map<String, dynamic>> formatMessagesForTesting(List<LlmMessage> history) =>
      _formatMessages(history);

  @visibleForTesting
  List<Map<String, dynamic>> formatToolsForTesting(List<ToolDescriptor> tools) =>
      _formatTools(tools);

  List<Map<String, dynamic>> _formatMessages(List<LlmMessage> history) {
    final messages = <Map<String, dynamic>>[];

    for (final msg in history) {
      if (msg.role == MessageRole.tool) {
        final toolResults = <Map<String, dynamic>>[];
        for (final part in msg.parts) {
          if (part is ToolResponsePart) {
            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': part.callId,
              'content': jsonEncode(part.response),
            });
          }
        }
        if (toolResults.isNotEmpty) {
          if (messages.isNotEmpty && messages.last['role'] == 'user') {
            final lastContent = messages.last['content'] as List<dynamic>?;
            if (lastContent != null &&
                lastContent.isNotEmpty &&
                lastContent.first is Map<String, dynamic> &&
                (lastContent.first as Map<String, dynamic>)['type'] == 'tool_result') {
              lastContent.addAll(toolResults);
              continue;
            }
          }
          messages.add({'role': 'user', 'content': toolResults});
        }
        continue;
      }

      final role = msg.role == MessageRole.user ? 'user' : 'assistant';
      final content = <Map<String, dynamic>>[];

      for (final part in msg.parts) {
        switch (part) {
          case TextPart(:final text):
            if (text.isNotEmpty) content.add({'type': 'text', 'text': text});
          case ImagePart(:final bytes, :final mimeType):
            content.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mimeType,
                'data': base64Encode(bytes),
              },
            });
          case ToolCallPart(:final callId, :final toolName, :final arguments):
            content.add({
              'type': 'tool_use',
              'id': callId,
              'name': toolName.replaceAll('.', '__'),
              'input': arguments,
            });
          case ToolResponsePart(:final callId, :final response):
            content.add({
              'type': 'tool_result',
              'tool_use_id': callId,
              'content': jsonEncode(response),
            });
        }
      }

      if (content.isNotEmpty) {
        messages.add({'role': role, 'content': content});
      }
    }

    return messages;
  }

  List<Map<String, dynamic>> _formatTools(List<ToolDescriptor> tools) {
    return tools.map((t) {
      return {
        'name': t.name.replaceAll('.', '__'),
        'description': t.description,
        'input_schema': t.inputSchema,
      };
    }).toList();
  }
}
