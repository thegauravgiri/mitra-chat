import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/integrations/notion/notion_client.dart';
import 'package:mitra/integrations/notion/notion_tools.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  group('Notion Discovery & Dynamic Schema (Plan §F2.5 Test 7)', () {
    test('extractId extracts 32-hex ID from various Notion URLs and IDs', () {
      expect(
        NotionClient.extractId('274e0d9bfad74bb4ba1c080327f3aa41'),
        equals('274e0d9bfad74bb4ba1c080327f3aa41'),
      );
      expect(
        NotionClient.extractId('274e0d9b-fad7-4bb4-ba1c-080327f3aa41'),
        equals('274e0d9bfad74bb4ba1c080327f3aa41'),
      );
      expect(
        NotionClient.extractId('https://www.notion.so/myworkspace/Dashboard-274e0d9bfad74bb4ba1c080327f3aa41?v=123'),
        equals('274e0d9bfad74bb4ba1c080327f3aa41'),
      );
      expect(
        NotionClient.extractId('https://notion.so/274e0d9bfad74bb4ba1c080327f3aa41'),
        equals('274e0d9bfad74bb4ba1c080327f3aa41'),
      );
      expect(
        NotionClient.extractId('invalid-string-with-no-hex'),
        isNull,
      );
    });

    test('describe_database and create_pages work end-to-end with NotionTools', () async {
      final mockDio = MockDio();
      final client = NotionClient(apiKey: 'secret_test', dio: mockDio);
      final cache = NotionSchemaCache();
      final descriptors = NotionTools.createDescriptors(
        client: client,
        schemaCache: cache,
      );

      final describeTool = descriptors.firstWhere((t) => t.name == 'notion.describe_database');
      final createPagesTool = descriptors.firstWhere((t) => t.name == 'notion.create_pages');
      final searchDatabasesTool = descriptors.firstWhere((t) => t.name == 'notion.search_databases');

      // Mock search
      when(() => mockDio.post<Map<String, dynamic>>(
            '/v1/search',
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            data: {
              'results': [
                {
                  'id': '274e0d9bfad74bb4ba1c080327f3aa41',
                  'title': [
                    {'plain_text': 'Engineering Tasks'}
                  ],
                  'url': 'https://notion.so/274e0d9bfad74bb4ba1c080327f3aa41',
                }
              ]
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/search'),
          ));

      // Mock database get -> data sources
      when(() => mockDio.get<Map<String, dynamic>>(
            '/v1/databases/274e0d9bfad74bb4ba1c080327f3aa41',
          )).thenAnswer((_) async => Response(
            data: {
              'data_sources': [
                {'id': 'ds_101', 'name': 'Default View'}
              ]
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/databases/274e0d9bfad74bb4ba1c080327f3aa41'),
          ));

      // Mock data source schema
      when(() => mockDio.get<Map<String, dynamic>>(
            '/v1/data_sources/ds_101',
          )).thenAnswer((_) async => Response(
            data: {
              'properties': {
                'Task Name': {'id': 'title', 'type': 'title'},
                'Status': {
                  'id': 'st',
                  'type': 'status',
                  'status': {
                    'options': [
                      {'name': 'To Do'},
                      {'name': 'In Progress'},
                      {'name': 'Done'}
                    ]
                  }
                },
                'Due Date': {'id': 'dt', 'type': 'date'},
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/v1/data_sources/ds_101'),
          ));

      // Mock page create
      when(() => mockDio.post<Map<String, dynamic>>(
            '/v1/pages',
            data: any(named: 'data'),
          )).thenAnswer((invocation) async {
        final payload = invocation.namedArguments[#data] as Map<String, dynamic>;
        expect(payload['parent']['data_source_id'], equals('ds_101'));
        return Response(
          data: {
            'id': 'page_999',
            'url': 'https://notion.so/page_999',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/v1/pages'),
        );
      });

      // 1. Search databases
      final searchRes = await searchDatabasesTool.invoke({'query': 'Engineering'});
      expect(searchRes.isOk, isTrue);
      final searchDbs = searchRes.valueOrNull?['databases'] as List<dynamic>;
      expect(searchDbs.length, equals(1));
      expect(searchDbs.first['title'], equals('Engineering Tasks'));

      // 2. Describe database from URL
      final descRes = await describeTool.invoke({
        'database_id_or_url': 'https://www.notion.so/Engineering-Tasks-274e0d9bfad74bb4ba1c080327f3aa41?v=1',
      });
      expect(descRes.isOk, isTrue);
      final descData = descRes.valueOrNull!;
      expect(descData['title_property'], equals('Task Name'));
      expect(descData['status_property'], equals('Status'));
      expect(descData['status_options'], contains('To Do'));

      // Schema should now be cached in NotionSchemaCache
      expect(cache.get('274e0d9bfad74bb4ba1c080327f3aa41'), isNotNull);

      // 3. Create pages using generic create_pages tool
      final createPagesRes = await createPagesTool.invoke({
        'database_id_or_url': '274e0d9bfad74bb4ba1c080327f3aa41',
        'pages': [
          {'title': 'New automated task', 'status': 'To Do', 'due_date': '2026-09-01'}
        ]
      });

      expect(createPagesRes.isOk, isTrue);
      final createData = createPagesRes.valueOrNull!;
      expect(createData['count'], equals(1));
      final createdList = createData['created_tasks'] as List<dynamic>;
      expect(createdList.first['page_id'], equals('page_999'));
    });
  });
}
