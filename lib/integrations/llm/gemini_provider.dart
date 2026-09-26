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

class GeminiProvider implements LlmProvider {
  GeminiProvider({
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
  String get id => 'gemini';

  @override
  List<ModelOption> get models =>
      kAvailableModels.where((m) => m.providerId == 'gemini').toList();

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
      yield const LlmErrorEvent('Gemini API Key is not configured in Settings.');
      return;
    }

    final contents = _formatContents(history);
    final functionDeclarations = _formatTools(tools);

    final payload = <String, dynamic>{
      'contents': contents,
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ],
      },
      'generationConfig': {
        'temperature': 0.2,
      },
    };

    if (functionDeclarations.isNotEmpty) {
      payload['tools'] = [
        {'function_declarations': functionDeclarations}
      ];
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=$apiKey';

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
        url,
        data: payload,
        cancelToken: localCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        yield const LlmErrorEvent('Empty response from Gemini API.');
        return;
      }

      var buffer = '';
      await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder)) {
        if (localCancelToken.isCancelled || (cancelToken?.isCancelled ?? false)) {
          break;
        }
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
                final candidates = decoded['candidates'] as List<dynamic>?;
                if (candidates != null && candidates.isNotEmpty) {
                  final first = candidates.first as Map<String, dynamic>;
                  final finishReason = first['finishReason'] as String?;
                  final content = first['content'] as Map<String, dynamic>?;
                  final parts = content?['parts'] as List<dynamic>? ?? [];

                  for (final p in parts) {
                    if (p is Map<String, dynamic>) {
                      if (p.containsKey('text')) {
                        final text = p['text'] as String? ?? '';
                        if (text.isNotEmpty) {
                          yield LlmTextDeltaEvent(text);
                        }
                      } else if (p.containsKey('functionCall')) {
                        final fnCall = p['functionCall'] as Map<String, dynamic>;
                        final rawName = fnCall['name'] as String? ?? '';
                        final name = rawName.replaceAll('__', '.');
                        final args = (fnCall['args'] as Map<String, dynamic>?) ?? {};
                        yield LlmToolCallEvent(ToolCallProposal(
                          callId: '',
                          toolName: name,
                          arguments: args,
                        ));
                      }
                    }
                  }

                  if (finishReason != null && finishReason.isNotEmpty) {
                    finished = true;
                    break;
                  }
                }
              }
            } catch (e) {
              AppLogger.warning('Gemini chunk parse error: $e');
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
        var msg = e.message ?? 'Unknown Gemini error';
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
  List<Map<String, dynamic>> formatContentsForTesting(List<LlmMessage> history) =>
      _formatContents(history);

  @visibleForTesting
  List<Map<String, dynamic>> formatToolsForTesting(List<ToolDescriptor> tools) =>
      _formatTools(tools);

  List<Map<String, dynamic>> _formatContents(List<LlmMessage> history) {
    final contents = <Map<String, dynamic>>[];

    for (final msg in history) {
      if (msg.role == MessageRole.tool) {
        final responseParts = <Map<String, dynamic>>[];
        for (final part in msg.parts) {
          if (part is ToolResponsePart) {
            final sanitizedName = part.toolName.replaceAll('.', '__');
            responseParts.add({
              'functionResponse': {
                'name': sanitizedName,
                'response': {
                  'name': sanitizedName,
                  'content': part.response,
                },
              },
            });
          }
        }
        if (responseParts.isNotEmpty) {
          if (contents.isNotEmpty && contents.last['role'] == 'user') {
            final lastParts = contents.last['parts'] as List<dynamic>?;
            if (lastParts != null &&
                lastParts.isNotEmpty &&
                lastParts.first is Map<String, dynamic> &&
                (lastParts.first as Map<String, dynamic>).containsKey('functionResponse')) {
              lastParts.addAll(responseParts);
              continue;
            }
          }
          contents.add({
            'role': 'user',
            'parts': responseParts,
          });
        }
        continue;
      }

      final role = msg.role == MessageRole.user ? 'user' : 'model';
      final parts = <Map<String, dynamic>>[];

      for (final part in msg.parts) {
        switch (part) {
          case TextPart(:final text):
            if (text.isNotEmpty) {
              parts.add({'text': text});
            }
          case ImagePart(:final bytes, :final mimeType):
            parts.add({
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(bytes),
              },
            });
          case ToolCallPart(:final toolName, :final arguments):
            final sanitizedName = toolName.replaceAll('.', '__');
            parts.add({
              'functionCall': {
                'name': sanitizedName,
                'args': arguments,
              },
            });
          case ToolResponsePart(:final toolName, :final response):
            final sanitizedName = toolName.replaceAll('.', '__');
            parts.add({
              'functionResponse': {
                'name': sanitizedName,
                'response': {
                  'name': sanitizedName,
                  'content': response,
                },
              },
            });
        }
      }

      if (parts.isNotEmpty) {
        contents.add({
          'role': role,
          'parts': parts,
        });
      }
    }

    return contents;
  }

  List<Map<String, dynamic>> _formatTools(List<ToolDescriptor> tools) {
    return tools.map((t) {
      final sanitizedName = t.name.replaceAll('.', '__');
      final cleanSchema = _cleanGeminiSchema(t.inputSchema);
      return {
        'name': sanitizedName,
        'description': t.description,
        'parameters': cleanSchema,
      };
    }).toList();
  }

  Map<String, dynamic> _cleanGeminiSchema(Map<String, dynamic> raw) {
    final clean = <String, dynamic>{};

    // If schema has anyOf / oneOf, normalize nullable or sub-schemas
    if (raw.containsKey('anyOf') && raw['anyOf'] is List) {
      final list = raw['anyOf'] as List<dynamic>;
      final nonNull = list
          .where((item) => item is Map<String, dynamic> && item['type'] != 'null')
          .toList();
      final hasNull =
          list.any((item) => item is Map<String, dynamic> && item['type'] == 'null');
      if (nonNull.length == 1 && nonNull.first is Map<String, dynamic>) {
        final base = _cleanGeminiSchema(nonNull.first as Map<String, dynamic>);
        if (hasNull) base['nullable'] = true;
        return base;
      }
    }

    if (raw.containsKey('oneOf') && raw['oneOf'] is List) {
      final list = raw['oneOf'] as List<dynamic>;
      final nonNull = list
          .where((item) => item is Map<String, dynamic> && item['type'] != 'null')
          .toList();
      final hasNull =
          list.any((item) => item is Map<String, dynamic> && item['type'] == 'null');
      if (nonNull.length == 1 && nonNull.first is Map<String, dynamic>) {
        final base = _cleanGeminiSchema(nonNull.first as Map<String, dynamic>);
        if (hasNull) base['nullable'] = true;
        return base;
      }
    }

    for (final entry in raw.entries) {
      final key = entry.key;
      final val = entry.value;

      // Strip unsupported JSON Schema keywords for Gemini
      if (key == 'additionalProperties' ||
          key == 'additional_properties' ||
          key == r'$schema' ||
          key == r'$id' ||
          key == r'$defs' ||
          key == 'definitions' ||
          key == 'title' ||
          key == 'default' ||
          key == 'examples') {
        continue;
      }

      if (key == 'type') {
        if (val is List && val.isNotEmpty) {
          final nonNullType =
              val.firstWhere((t) => t != 'null', orElse: () => 'string');
          clean['type'] = nonNullType.toString().toLowerCase();
          if (val.contains('null')) {
            clean['nullable'] = true;
          }
        } else if (val is String) {
          clean['type'] = val.toLowerCase();
        } else {
          clean['type'] = val;
        }
      } else if (key == 'properties' && val is Map<String, dynamic>) {
        final cleanProps = <String, dynamic>{};
        for (final prop in val.entries) {
          if (prop.value is Map<String, dynamic>) {
            cleanProps[prop.key] =
                _cleanGeminiSchema(prop.value as Map<String, dynamic>);
          } else {
            cleanProps[prop.key] = prop.value;
          }
        }
        clean['properties'] = cleanProps;
      } else if (key == 'items' && val is Map<String, dynamic>) {
        clean['items'] = _cleanGeminiSchema(val);
      } else if ((key == 'anyOf' || key == 'any_of' || key == 'oneOf' || key == 'one_of' || key == 'allOf' || key == 'all_of') &&
          val is List) {
        final cleanList = <dynamic>[];
        for (final item in val) {
          if (item is Map<String, dynamic>) {
            cleanList.add(_cleanGeminiSchema(item));
          } else {
            cleanList.add(item);
          }
        }
        clean[key] = cleanList;
      } else if (key == 'required' && val is List) {
        clean['required'] = val.map((e) => e.toString()).toList();
      } else if (key == 'enum' && val is List) {
        clean['enum'] = val.map((e) => e.toString()).toList();
      } else if (key == 'description' && val is String) {
        clean['description'] = val;
      } else if (key == 'nullable' && val is bool) {
        clean['nullable'] = val;
      } else if (val is Map<String, dynamic>) {
        clean[key] = _cleanGeminiSchema(val);
      } else {
        clean[key] = val;
      }
    }

    if (!clean.containsKey('type') && clean.containsKey('properties')) {
      clean['type'] = 'object';
    }

    return clean;
  }
}
