import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/domain/models/enums.dart';
import 'package:mitra/integrations/llm/anthropic_provider.dart';
import 'package:mitra/integrations/llm/gemini_provider.dart';
import 'package:mitra/integrations/llm/llm_types.dart';
import 'package:mitra/integrations/llm/openai_provider.dart';

void main() {
  group('Provider Wire Format Tests (Plan §F2.5 Test 2)', () {
    final history = <LlmMessage>[
      const LlmMessage(
        role: MessageRole.user,
        parts: [TextPart('List cards for sprint 70 and sprint 71')],
      ),
      const LlmMessage(
        role: MessageRole.assistant,
        parts: [
          TextPart('Checking sprints...'),
          ToolCallPart(
            callId: 'call_1_0_azure_devops_list_work_items',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            arguments: {'sprint': '70'},
          ),
          ToolCallPart(
            callId: 'call_1_1_azure_devops_list_work_items',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            arguments: {'sprint': '71'},
          ),
        ],
      ),
      const LlmMessage(
        role: MessageRole.tool,
        parts: [
          ToolResponsePart(
            callId: 'call_1_0_azure_devops_list_work_items',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            response: {'cards': ['Card A']},
          ),
        ],
      ),
      const LlmMessage(
        role: MessageRole.tool,
        parts: [
          ToolResponsePart(
            callId: 'call_1_1_azure_devops_list_work_items',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            response: {'cards': ['Card B']},
          ),
        ],
      ),
    ];

    test('Gemini wire format groups functionResponses and formats functionCalls with sanitized names', () {
      final provider = GeminiProvider(apiKeyProvider: () async => 'test-key');
      final contents = provider.formatContentsForTesting(history);

      expect(contents.length, equals(3));

      // 1. User message
      expect(contents[0]['role'], equals('user'));
      expect(contents[0]['parts'], equals([{'text': 'List cards for sprint 70 and sprint 71'}]));

      // 2. Model message with text and 2 functionCalls in order
      expect(contents[1]['role'], equals('model'));
      final modelParts = contents[1]['parts'] as List<dynamic>;
      expect(modelParts.length, equals(3));
      expect(modelParts[0], equals({'text': 'Checking sprints...'}));
      expect(modelParts[1], equals({
        'functionCall': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'args': {'sprint': '70'},
        }
      }));
      expect(modelParts[2], equals({
        'functionCall': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'args': {'sprint': '71'},
        }
      }));

      // 3. User message grouping BOTH functionResponses
      expect(contents[2]['role'], equals('user'));
      final responseParts = contents[2]['parts'] as List<dynamic>;
      expect(responseParts.length, equals(2));
      expect(responseParts[0], equals({
        'functionResponse': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'response': {
            'name': 'mcp__mitra__azure_devops_list_work_items',
            'content': {'cards': ['Card A']},
          }
        }
      }));
      expect(responseParts[1], equals({
        'functionResponse': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'response': {
            'name': 'mcp__mitra__azure_devops_list_work_items',
            'content': {'cards': ['Card B']},
          }
        }
      }));
    });

    test('Anthropic wire format groups tool_results into a single user message and formats tool_use', () {
      final provider = AnthropicProvider(apiKeyProvider: () async => 'test-key');
      final messages = provider.formatMessagesForTesting(history);

      expect(messages.length, equals(3));

      // 1. User message
      expect(messages[0]['role'], equals('user'));
      expect(messages[0]['content'], equals([{'type': 'text', 'text': 'List cards for sprint 70 and sprint 71'}]));

      // 2. Assistant message with tool_use
      expect(messages[1]['role'], equals('assistant'));
      final assistantContent = messages[1]['content'] as List<dynamic>;
      expect(assistantContent.length, equals(3));
      expect(assistantContent[0], equals({'type': 'text', 'text': 'Checking sprints...'}));
      expect(assistantContent[1], equals({
        'type': 'tool_use',
        'id': 'call_1_0_azure_devops_list_work_items',
        'name': 'mcp__mitra__azure_devops_list_work_items',
        'input': {'sprint': '70'},
      }));
      expect(assistantContent[2], equals({
        'type': 'tool_use',
        'id': 'call_1_1_azure_devops_list_work_items',
        'name': 'mcp__mitra__azure_devops_list_work_items',
        'input': {'sprint': '71'},
      }));

      // 3. User message with grouped tool_result blocks
      expect(messages[2]['role'], equals('user'));
      final toolResultContent = messages[2]['content'] as List<dynamic>;
      expect(toolResultContent.length, equals(2));
      expect(toolResultContent[0], equals({
        'type': 'tool_result',
        'tool_use_id': 'call_1_0_azure_devops_list_work_items',
        'content': jsonEncode({'cards': ['Card A']}),
      }));
      expect(toolResultContent[1], equals({
        'type': 'tool_result',
        'tool_use_id': 'call_1_1_azure_devops_list_work_items',
        'content': jsonEncode({'cards': ['Card B']}),
      }));
    });

    test('OpenAI wire format separates tool responses and formats assistant tool_calls with stringified args', () {
      final provider = OpenAiProvider(apiKeyProvider: () async => 'test-key');
      final messages = provider.formatMessagesForTesting(history, 'System instruction');

      expect(messages.length, equals(5));

      // 0. System prompt
      expect(messages[0]['role'], equals('system'));
      expect(messages[0]['content'], equals('System instruction'));

      // 1. User message
      expect(messages[1]['role'], equals('user'));
      expect(messages[1]['content'], equals([{'type': 'text', 'text': 'List cards for sprint 70 and sprint 71'}]));

      // 2. Assistant message with tool_calls
      expect(messages[2]['role'], equals('assistant'));
      expect(messages[2]['content'], equals('Checking sprints...'));
      final toolCalls = messages[2]['tool_calls'] as List<dynamic>;
      expect(toolCalls.length, equals(2));
      expect(toolCalls[0], equals({
        'id': 'call_1_0_azure_devops_list_work_items',
        'type': 'function',
        'function': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'arguments': jsonEncode({'sprint': '70'}),
        }
      }));
      expect(toolCalls[1], equals({
        'id': 'call_1_1_azure_devops_list_work_items',
        'type': 'function',
        'function': {
          'name': 'mcp__mitra__azure_devops_list_work_items',
          'arguments': jsonEncode({'sprint': '71'}),
        }
      }));

      // 3. First tool response
      expect(messages[3], equals({
        'role': 'tool',
        'tool_call_id': 'call_1_0_azure_devops_list_work_items',
        'content': jsonEncode({'cards': ['Card A']}),
      }));

      // 4. Second tool response
      expect(messages[4], equals({
        'role': 'tool',
        'tool_call_id': 'call_1_1_azure_devops_list_work_items',
        'content': jsonEncode({'cards': ['Card B']}),
      }));
    });
  });
}
