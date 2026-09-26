import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/domain/agent/skill_context_builder.dart';
import 'package:mitra/domain/agent/system_prompts.dart';
import 'package:mitra/integrations/mcp/mcp_client.dart';
import 'package:mitra/integrations/mcp/mcp_server_config.dart';
import 'package:mitra/integrations/mcp/streamable_http_channel.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  group('SkillContextBuilder & System Prompt Injection (Plan §F2.5 Test 6)', () {
    late MockDio mockDio;
    late McpClient client;
    late SkillContextBuilder builder;

    setUp(() {
      mockDio = MockDio();
      final config = McpServerConfig(
        id: 'mitra',
        name: 'Mitra MCP',
        endpointUrl: 'http://localhost:8080/mcp',
      );
      final channel = StreamableHttpChannel(
        endpointUrl: config.endpointUrl,
        dio: mockDio,
      );
      client = McpClient(config: config, channel: channel);
      builder = SkillContextBuilder(maxCharBudget: 24000);

      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        final dataStr = invocation.namedArguments[#data] as String;
        final decoded = jsonDecode(dataStr) as Map<String, dynamic>;
        final method = decoded['method'] as String?;
        final id = decoded['id'];

        if (method == 'initialize') {
          return Response<String>(
            data: jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'capabilities': <String, dynamic>{'prompts': <String, dynamic>{}},
              },
            }),
            statusCode: 200,
            headers: Headers.fromMap({'mcp-session-id': ['sess-1']}),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        }

        if (method == 'prompts/list') {
          return Response<String>(
            data: jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'prompts': <Map<String, dynamic>>[
                  {
                    'name': 'notion-dashboard',
                    'description': 'Notion dashboard skill definition',
                    'arguments': <Map<String, dynamic>>[],
                  },
                  {
                    'name': 'unrelated-prompt',
                    'description': 'Something else',
                    'arguments': <Map<String, dynamic>>[
                      {'name': 'required_arg', 'required': true}
                    ],
                  }
                ],
              },
            }),
            statusCode: 200,
            headers: Headers(),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        }

        if (method == 'prompts/get') {
          return Response<String>(
            data: jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {
                        'type': 'text',
                        'text':
                            'Database ID: 274e0d9bfad74bb4ba1c080327f3aa41. Properties: Task (title), Status (status), Due Date (date).'
                      }
                    ]
                  }
                ]
              },
            }),
            statusCode: 200,
            headers: Headers(),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        }

        return Response<String>(
          data: '',
          statusCode: 200,
          headers: Headers(),
          requestOptions: RequestOptions(path: config.endpointUrl),
        );
      });
    });

    test('buildSkillContext discovers skill prompt and formats ### CONNECTED SKILLS block', () async {
      final skillContext = await builder.buildSkillContext(mcpClients: [client]);

      expect(skillContext, isNotNull);
      expect(skillContext, contains('### CONNECTED SKILLS'));
      expect(skillContext, contains('BEGIN SKILL: notion-dashboard (mitra)'));
      expect(skillContext, contains('Database ID: 274e0d9bfad74bb4ba1c080327f3aa41'));
      expect(skillContext, contains('END SKILL: notion-dashboard'));

      final fullPrompt = SystemPrompts.buildAgentSystemPrompt(skillContext: skillContext);
      expect(fullPrompt, contains('### CONNECTED SKILLS'));
      expect(fullPrompt, contains('Database ID: 274e0d9bfad74bb4ba1c080327f3aa41'));
    });

    test('Respects character budget and truncates deterministically', () async {
      final smallBudgetBuilder = SkillContextBuilder(maxCharBudget: 50);
      final skillContext = await smallBudgetBuilder.buildSkillContext(mcpClients: [client]);

      // When the single block is larger than 50 chars, it is dropped and null is returned
      expect(skillContext, isNull);
    });
  });
}
