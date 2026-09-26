import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/core/failures.dart';
import 'package:mitra/integrations/notion/notion_client.dart';
import 'package:mitra/integrations/notion/notion_schema.dart';
import 'package:mitra/integrations/notion/notion_task_mapper.dart';

void main() {
  group('Notion Schema Discovery & Mapping (Plan §6)', () {
    test('Resolves schema from canonical property names', () {
      final propertiesJson = {
        'Task Name': {'id': 'title_1', 'type': 'title'},
        'Status': {
          'id': 'status_1',
          'type': 'status',
          'status': {
            'options': [
              {'id': '1', 'name': 'To Do'},
              {'id': '2', 'name': 'In Progress'},
              {'id': '3', 'name': 'Done'},
            ]
          }
        },
        'Due Date': {'id': 'date_1', 'type': 'date'},
        'Priority': {
          'id': 'prio_1',
          'type': 'select',
          'select': {
            'options': [
              {'id': 'p1', 'name': 'High'},
              {'id': 'p2', 'name': 'Medium'},
              {'id': 'p3', 'name': 'Low'},
            ]
          }
        },
        'Tags': {
          'id': 'tags_1',
          'type': 'multi_select',
          'multi_select': {
            'options': [
              {'id': 't1', 'name': 'Work'},
              {'id': 't2', 'name': 'Personal'},
            ]
          }
        },
      };

      final schema = NotionResolvedSchema.fromPropertiesMap(
        dataSourceId: 'ds_123',
        propertiesJson: propertiesJson,
      );

      expect(schema.dataSourceId, equals('ds_123'));
      expect(schema.titleProperty, equals('Task Name'));
      expect(schema.statusProperty, equals('Status'));
      expect(schema.statusOptions, contains('To Do'));
      expect(schema.dueDateProperty, equals('Due Date'));
      expect(schema.priorityProperty, equals('Priority'));
      expect(schema.priorityOptions, contains('High'));
      expect(schema.tagsProperty, equals('Tags'));
      expect(schema.droppedConcepts, isEmpty);
    });

    test('Resolves schema from renamed custom properties', () {
      final propertiesJson = {
        'Headline': {'id': 't', 'type': 'title'},
        'Current State': {
          'id': 's',
          'type': 'select',
          'select': {
            'options': [
              {'id': '1', 'name': 'Backlog'},
              {'id': '2', 'name': 'Completed'},
            ]
          }
        },
        'Deadline': {'id': 'd', 'type': 'date'},
        'Urgency Prio': {
          'id': 'p',
          'type': 'select',
          'select': {
            'options': [
              {'id': 'u1', 'name': 'Urgent'},
              {'id': 'u2', 'name': 'Normal'},
            ]
          }
        },
      };

      final schema = NotionResolvedSchema.fromPropertiesMap(
        dataSourceId: 'ds_456',
        propertiesJson: propertiesJson,
      );

      expect(schema.titleProperty, equals('Headline'));
      expect(schema.statusProperty, equals('Current State'));
      expect(schema.dueDateProperty, equals('Deadline'));
      expect(schema.priorityProperty, equals('Urgency Prio'));
      expect(schema.tagsProperty, isNull);
      expect(schema.droppedConcepts, contains('Tags'));
    });

    test('Handles minimal title-only database schema without failing', () {
      final propertiesJson = {
        'Title': {'id': 't', 'type': 'title'},
      };

      final schema = NotionResolvedSchema.fromPropertiesMap(
        dataSourceId: 'ds_minimal',
        propertiesJson: propertiesJson,
      );

      expect(schema.titleProperty, equals('Title'));
      expect(schema.statusProperty, isNull);
      expect(schema.dueDateProperty, isNull);
      expect(schema.priorityProperty, isNull);
      expect(schema.tagsProperty, isNull);
      expect(schema.droppedConcepts.length, equals(4));
    });

    test('Builds create page payload with data_source_id parent', () {
      final schema = NotionResolvedSchema.fromPropertiesMap(
        dataSourceId: 'ds_test',
        propertiesJson: {
          'Name': {'id': 'title', 'type': 'title'},
          'Status': {
            'id': 'status',
            'type': 'status',
            'status': {
              'options': [
                {'id': '1', 'name': 'To Do'}
              ]
            }
          },
          'Date': {'id': 'date', 'type': 'date'},
        },
      );

      final payload = NotionTaskMapper.buildCreatePagePayload(
        schema: schema,
        title: 'Review PR #42',
        status: 'To Do',
        dueDate: 'tomorrow',
      );

      expect(payload['parent']['type'], equals('data_source_id'));
      expect(payload['parent']['data_source_id'], equals('ds_test'));
      expect(payload['properties']['Name']['title'][0]['text']['content'],
          equals('Review PR #42'));
      expect(payload['properties']['Status']['status']['name'], equals('To Do'));
      expect(payload['properties']['Date']['date']['start'], isNotEmpty);
    });
  });

  group('NotionClient Error Mapping', () {
    test('Maps 401/403 to AuthFailure', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {'message': 'API token is invalid.'},
            ),
          ));
        },
      ));

      final client = NotionClient(apiKey: 'bad_token', dio: dio);
      final result = await client.testConnection();

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AuthFailure>());
      expect((result.failureOrNull as AuthFailure).service, equals('notion'));
    });

    test('Maps 429 to RateLimitFailure with retry-after header', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 429,
              headers: Headers.fromMap({
                'retry-after': ['5'],
              }),
              data: {'message': 'Rate limited'},
            ),
          ));
        },
      ));

      final client = NotionClient(apiKey: 'test_token', dio: dio);
      final result = await client.testConnection();

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<RateLimitFailure>());
      expect((result.failureOrNull as RateLimitFailure).retryAfter?.inSeconds, equals(5));
    });
  });
}
