import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('McpClient RPC Tests (Plan §F2.5 Test 5)', () {
    late MockDio mockDio;
    late McpServerConfig config;
    late StreamableHttpChannel channel;
    late McpClient client;

    setUp(() {
      mockDio = MockDio();
      config = McpServerConfig(
        id: 'mitra',
        name: 'Mitra MCP',
        endpointUrl: 'http://localhost:8080/mcp',
        bearerToken: 'test_token',
      );
      channel = StreamableHttpChannel(
        endpointUrl: config.endpointUrl,
        bearerToken: config.bearerToken,
        dio: mockDio,
      );
      client = McpClient(config: config, channel: channel);
    });

    test('Initializes with 2025-06-18 protocol and retains capabilities', () async {
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
          expect(decoded['params']['protocolVersion'], equals('2025-06-18'));
          expect(decoded['params']['capabilities']['prompts'], isNotNull);
          expect(decoded['params']['capabilities']['resources'], isNotNull);

          return Response<String>(
            data: jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'protocolVersion': '2025-06-18',
                'capabilities': <String, dynamic>{
                  'prompts': {'listChanged': true},
                  'resources': {'subscribe': true},
                  'tools': {'listChanged': true},
                },
                'serverInfo': {'name': 'test-server', 'version': '1.0.0'},
              },
            }),
            statusCode: 200,
            headers: Headers.fromMap({
              'content-type': ['application/json'],
              'mcp-session-id': ['sess-123'],
            }),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        } else if (method == 'notifications/initialized') {
          return Response<String>(
            data: '',
            statusCode: 200,
            headers: Headers(),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        }

        return Response<String>(
          data: jsonEncode(<String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': <String, dynamic>{}}),
          statusCode: 200,
          headers: Headers(),
          requestOptions: RequestOptions(path: config.endpointUrl),
        );
      });

      final connRes = await client.connect();
      expect(connRes.isOk, isTrue);
      expect(client.status, equals(McpConnectionStatus.connected));
      expect(client.hasCapability('prompts'), isTrue);
      expect(client.hasCapability('resources'), isTrue);
    });

    test('listPrompts follows cursor pagination and parses prompt summaries', () async {
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        final dataStr = invocation.namedArguments[#data] as String;
        final decoded = jsonDecode(dataStr) as Map<String, dynamic>;
        final method = decoded['method'] as String?;
        final id = decoded['id'];
        final params = decoded['params'] as Map<String, dynamic>? ?? <String, dynamic>{};

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
          if (params['cursor'] == null) {
            return Response<String>(
              data: jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'prompts': <Map<String, dynamic>>[
                    {
                      'name': 'notion-dashboard',
                      'description': 'Notion dashboard skill prompt',
                      'arguments': <Map<String, dynamic>>[],
                    }
                  ],
                  'nextCursor': 'page-2',
                },
              }),
              statusCode: 200,
              headers: Headers(),
              requestOptions: RequestOptions(path: config.endpointUrl),
            );
          } else if (params['cursor'] == 'page-2') {
            return Response<String>(
              data: jsonEncode({
                'jsonrpc': '2.0',
                'id': id,
                'result': {
                  'prompts': <Map<String, dynamic>>[
                    {
                      'name': 'azure-devops-guide',
                      'description': 'Azure DevOps workflow guide',
                      'arguments': <Map<String, dynamic>>[
                        {'name': 'project', 'required': false}
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
        }

        return Response<String>(
          data: '',
          statusCode: 200,
          headers: Headers(),
          requestOptions: RequestOptions(path: config.endpointUrl),
        );
      });

      final promptsRes = await client.listPrompts();
      expect(promptsRes.isOk, isTrue);
      final prompts = promptsRes.valueOrNull!;
      expect(prompts.length, equals(2));
      expect(prompts[0].name, equals('notion-dashboard'));
      expect(prompts[1].name, equals('azure-devops-guide'));
      expect(prompts[1].arguments.first.name, equals('project'));
    });

    test('-32601 Method not found gracefully degrades to empty list without error', () async {
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
              'result': {'capabilities': <String, dynamic>{}},
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
              'error': {'code': -32601, 'message': 'Method not found: prompts/list'},
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

      final promptsRes = await client.listPrompts();
      expect(promptsRes.isOk, isTrue);
      expect(promptsRes.valueOrNull, isEmpty);
    });

    test('callTool with isError=true maps to ToolFailure', () async {
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
              'result': {'capabilities': <String, dynamic>{}},
            }),
            statusCode: 200,
            headers: Headers.fromMap({'mcp-session-id': ['sess-1']}),
            requestOptions: RequestOptions(path: config.endpointUrl),
          );
        }

        if (method == 'tools/call') {
          return Response<String>(
            data: jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'content': [
                  {'type': 'text', 'text': 'Project not found on server'}
                ],
                'isError': true,
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

      final result = await client.callTool('azure_devops_list_work_items', {'project': 'jarvis'});
      expect(result.isErr, isTrue);
      expect(result.failureOrNull?.message, contains('Project not found on server'));
    });
  });
}
