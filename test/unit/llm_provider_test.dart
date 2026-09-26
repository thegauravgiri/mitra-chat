import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/core/result.dart';
import 'package:mitra/domain/agent/tool_descriptor.dart';
import 'package:mitra/domain/models/enums.dart';
import 'package:mitra/integrations/llm/anthropic_provider.dart';
import 'package:mitra/integrations/llm/gemini_provider.dart';
import 'package:mitra/integrations/llm/llm_types.dart';
import 'package:mitra/integrations/llm/openai_provider.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('GeminiProvider SSE fixture tests', () {
    test('Emits deltas, closes, and emits exactly one LlmDoneEvent on finishReason', () async {
      const sseData =
          'data: {"candidates":[{"content":{"parts":[{"text":"Hello "}]}}]}\n\n'
          'data: {"candidates":[{"content":{"parts":[{"text":"world!"}]},"finishReason":"STOP"}]}\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = GeminiProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [],
        systemPrompt: 'You are an assistant',
        modelId: 'gemini-3.7-flash',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmTextDeltaEvent>().map((e) => e.delta).join(), equals('Hello world!'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });

    test('Gemini emits tool call before finishReason and terminates cleanly', () async {
      const sseData =
          'data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"notion__create_tasks","args":{"title":"Task 1"}}}]},"finishReason":"STOP"}]}\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = GeminiProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [
          ToolDescriptor(
            name: 'notion.create_tasks',
            description: 'Create task',
            inputSchema: const {},
            source: ToolSource.builtin,
            handler: (args) async => const Result.ok(<String, dynamic>{}),
          ),
        ],
        systemPrompt: 'You are an assistant',
        modelId: 'gemini-3.7-flash',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmToolCallEvent>().length, equals(1));
      expect(events.whereType<LlmToolCallEvent>().first.proposal.toolName, equals('notion.create_tasks'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });
  });

  group('AnthropicProvider SSE fixture tests', () {
    test('Emits deltas, closes, and emits exactly one LlmDoneEvent on message_stop', () async {
      const sseData =
          'data: {"type":"message_start","message":{"id":"msg_1","role":"assistant"}}\n\n'
          'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello "}}\n\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Claude!"}}\n\n'
          'data: {"type":"content_block_stop","index":0}\n\n'
          'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}\n\n'
          'data: {"type":"message_stop"}\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = AnthropicProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [],
        systemPrompt: 'You are an assistant',
        modelId: 'claude-sonnet-4',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmTextDeltaEvent>().map((e) => e.delta).join(), equals('Hello Claude!'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });

    test('Anthropic emits tool call on content_block_stop and terminates cleanly on message_stop', () async {
      const sseData =
          'data: {"type":"message_start","message":{"id":"msg_2","role":"assistant"}}\n\n'
          'data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"call_123","name":"notion__create_tasks"}}\n\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"title\\":\\"Task 1\\"}"}}\n\n'
          'data: {"type":"content_block_stop","index":0}\n\n'
          'data: {"type":"message_stop"}\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = AnthropicProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [
          ToolDescriptor(
            name: 'notion.create_tasks',
            description: 'Create task',
            inputSchema: const {},
            source: ToolSource.builtin,
            handler: (args) async => const Result.ok(<String, dynamic>{}),
          ),
        ],
        systemPrompt: 'You are an assistant',
        modelId: 'claude-sonnet-4',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmToolCallEvent>().length, equals(1));
      expect(events.whereType<LlmToolCallEvent>().first.proposal.toolName, equals('notion.create_tasks'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });
  });

  group('OpenAiProvider SSE fixture tests', () {
    test('Emits deltas, closes, and emits exactly one LlmDoneEvent on [DONE]', () async {
      const sseData =
          'data: {"choices":[{"delta":{"content":"Hello "}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"GPT!"}}]}\n\n'
          'data: [DONE]\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = OpenAiProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [],
        systemPrompt: 'You are an assistant',
        modelId: 'gpt-4o',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmTextDeltaEvent>().map((e) => e.delta).join(), equals('Hello GPT!'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });

    test('OpenAI emits tool calls before [DONE] and terminates cleanly', () async {
      const sseData =
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_abc","function":{"name":"notion__create_tasks","arguments":"{\\"title\\":\\"Task 1\\"}"}}]}}]}\n\n'
          'data: [DONE]\n\n';

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          sseData,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );
      });

      final provider = OpenAiProvider(
        apiKeyProvider: () async => 'test-api-key',
        dio: dio,
      );

      final events = await provider.streamChat(
        history: [
          const LlmMessage(
            role: MessageRole.user,
            parts: [TextPart('Hi')],
          ),
        ],
        tools: [
          ToolDescriptor(
            name: 'notion.create_tasks',
            description: 'Create task',
            inputSchema: const {},
            source: ToolSource.builtin,
            handler: (args) async => const Result.ok(<String, dynamic>{}),
          ),
        ],
        systemPrompt: 'You are an assistant',
        modelId: 'gpt-4o',
      ).timeout(const Duration(seconds: 2)).toList();

      expect(events.whereType<LlmToolCallEvent>().length, equals(1));
      expect(events.whereType<LlmToolCallEvent>().first.proposal.toolName, equals('notion.create_tasks'));
      expect(events.whereType<LlmDoneEvent>().length, equals(1));
    });
  });
}
