import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/failures.dart';
import '../../core/result.dart';
import 'notion_schema.dart';
import 'notion_task_mapper.dart';

class NotionDataSourceSummary {
  const NotionDataSourceSummary({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory NotionDataSourceSummary.fromJson(Map<String, dynamic> json) =>
      NotionDataSourceSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Default View',
      );
}

class NotionDatabaseSummary {
  const NotionDatabaseSummary({
    required this.id,
    required this.title,
    required this.dataSources,
  });

  final String id;
  final String title;
  final List<NotionDataSourceSummary> dataSources;
}

class NotionClient {
  NotionClient({
    required String apiKey,
    Dio? dio,
    String baseUrl = 'https://api.notion.com',
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'Authorization': 'Bearer $apiKey',
                  'Notion-Version': '2025-09-03',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  static String? extractId(String idOrUrl) {
    final trimmed = idOrUrl.trim();
    if (trimmed.isEmpty) return null;

    final match = RegExp(
      r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|[a-f0-9]{32})',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (match != null) {
      return match.group(0)!.replaceAll('-', '').toLowerCase();
    }
    return null;
  }

  Future<Result<Map<String, dynamic>>> testConnection() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/users/me');
      return Result.ok(response.data ?? {});
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> searchDatabases({String? query}) async {
    try {
      final payload = <String, dynamic>{
        'page_size': 50,
      };
      if (query != null && query.isNotEmpty) {
        payload['query'] = query;
      }
      payload['filter'] = {'value': 'data_source', 'property': 'object'};

      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          '/v1/search',
          data: payload,
        );
      } catch (_) {
        payload['filter'] = {'value': 'database', 'property': 'object'};
        response = await _dio.post<Map<String, dynamic>>(
          '/v1/search',
          data: payload,
        );
      }

      final results = (response.data?['results'] as List<dynamic>?) ?? [];
      final list = <Map<String, dynamic>>[];

      for (final raw in results) {
        if (raw is Map<String, dynamic>) {
          final id = raw['id'] as String? ?? '';
          var title = '';
          final titleList = raw['title'] as List<dynamic>? ?? [];
          for (final t in titleList) {
            if (t is Map<String, dynamic> && t['plain_text'] != null) {
              title += t['plain_text'] as String;
            }
          }
          if (title.isEmpty) title = raw['name'] as String? ?? 'Untitled';
          final url = raw['url'] as String? ?? 'https://notion.so/$id';

          list.add({
            'id': id,
            'title': title,
            'url': url,
          });
        }
      }

      return Result.ok(list);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  Future<Result<List<NotionDatabaseSummary>>> listDatabases() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/search',
        data: {
          'filter': {'value': 'database', 'property': 'object'},
          'page_size': 50,
        },
      );

      final results = (response.data?['results'] as List<dynamic>?) ?? [];
      final databases = <NotionDatabaseSummary>[];

      for (final raw in results) {
        if (raw is Map<String, dynamic>) {
          final id = raw['id'] as String? ?? '';
          final titleList = raw['title'] as List<dynamic>? ?? [];
          var title = '';
          for (final t in titleList) {
            if (t is Map<String, dynamic> && t['plain_text'] != null) {
              title += t['plain_text'] as String;
            }
          }
          if (title.isEmpty) title = 'Untitled Database';

          final dataSourcesRaw = (raw['data_sources'] as List<dynamic>?) ?? [];
          final dataSources = dataSourcesRaw
              .whereType<Map<String, dynamic>>()
              .map(NotionDataSourceSummary.fromJson)
              .toList();

          databases.add(NotionDatabaseSummary(
            id: id,
            title: title,
            dataSources: dataSources,
          ));
        }
      }

      return Result.ok(databases);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  /// Fetches a database and resolves its data sources (API 2025-09-03).
  Future<Result<List<NotionDataSourceSummary>>> getDataSourcesForDatabase(
      String databaseId) async {
    try {
      final cleanId = databaseId.replaceAll('-', '');
      final response =
          await _dio.get<Map<String, dynamic>>('/v1/databases/$cleanId');
      final data = response.data ?? {};

      final dataSourcesRaw = (data['data_sources'] as List<dynamic>?) ?? [];
      final dataSources = dataSourcesRaw
          .whereType<Map<String, dynamic>>()
          .map(NotionDataSourceSummary.fromJson)
          .toList();

      if (dataSources.isEmpty) {
        // Fallback: If no explicit data sources array, use the database id directly as data source id
        dataSources.add(NotionDataSourceSummary(id: cleanId, name: 'Default'));
      }

      return Result.ok(dataSources);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  /// Fetches the authoritative properties schema from GET /v1/data_sources/{id}.
  Future<Result<NotionResolvedSchema>> getDataSourceSchema(
      String dataSourceId) async {
    try {
      final cleanId = dataSourceId.replaceAll('-', '');
      final response =
          await _dio.get<Map<String, dynamic>>('/v1/data_sources/$cleanId');
      final data = response.data ?? {};
      final properties =
          (data['properties'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final resolved = NotionResolvedSchema.fromPropertiesMap(
        dataSourceId: cleanId,
        propertiesJson: properties,
      );

      return Result.ok(resolved);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  /// Complete 2-step schema discovery chain (Plan §6).
  Future<Result<NotionResolvedSchema>> resolveSchema(
    String databaseId, {
    String? preferredDataSourceId,
  }) async {
    if (preferredDataSourceId != null && preferredDataSourceId.isNotEmpty) {
      return getDataSourceSchema(preferredDataSourceId);
    }

    final dataSourcesResult = await getDataSourcesForDatabase(databaseId);
    if (dataSourcesResult.isErr) {
      return Result.err(dataSourcesResult.failureOrNull!);
    }

    final dataSources = dataSourcesResult.valueOrNull!;
    if (dataSources.isEmpty) {
      return const Result.err(ValidationFailure(
        message: 'No data source found for database.',
      ));
    }

    final chosenId = dataSources.first.id;
    return getDataSourceSchema(chosenId);
  }

  /// Creates a page in Notion under the data_source_id.
  Future<Result<NotionCreatedTaskResult>> createPage({
    required NotionResolvedSchema schema,
    required String title,
    String? status,
    String? dueDate,
    String? priority,
    List<String>? tags,
  }) async {
    try {
      final payload = NotionTaskMapper.buildCreatePagePayload(
        schema: schema,
        title: title,
        status: status,
        dueDate: dueDate,
        priority: priority,
        tags: tags,
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/pages',
        data: payload,
      );

      final result = NotionTaskMapper.parsePageResponse(
        response: response.data ?? {},
        schema: schema,
        requestedTitle: title,
        requestedStatus: status,
        requestedDueDate: dueDate,
        requestedPriority: priority,
        requestedTags: tags,
      );

      return Result.ok(result);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  /// Archives a page (used for Undo).
  Future<Result<bool>> archivePage(String pageId) async {
    try {
      final cleanId = pageId.replaceAll('-', '');
      await _dio.patch<Map<String, dynamic>>(
        '/v1/pages/$cleanId',
        data: {'archived': true},
      );
      return const Result.ok(true);
    } catch (e) {
      return Result.err(_mapDioError(e));
    }
  }

  AppFailure _mapDioError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      Map<String, dynamic>? rawJson;
      String? notionMessage;

      if (responseData is Map<String, dynamic>) {
        rawJson = responseData;
        notionMessage = responseData['message'] as String?;
      }

      if (statusCode == 401 || statusCode == 403) {
        return AuthFailure(
          message: notionMessage ?? 'Invalid or unauthorized Notion API token.',
          service: 'notion',
          statusCode: statusCode ?? 401,
          cause: error,
        );
      }

      if (statusCode == 429) {
        final retryAfterSeconds = int.tryParse(
          error.response?.headers.value('retry-after') ?? '',
        );
        return RateLimitFailure(
          message: notionMessage ?? 'Notion API rate limit exceeded.',
          retryAfter: retryAfterSeconds != null
              ? Duration(seconds: retryAfterSeconds)
              : const Duration(seconds: 1),
          cause: error,
        );
      }

      if (statusCode == 400 || statusCode == 404) {
        return ValidationFailure(
          message: notionMessage ?? 'Notion request validation error.',
          rawErrorPayload: rawJson,
          cause: error,
        );
      }

      return NetworkFailure(
        message: notionMessage ?? error.message ?? 'Notion network error.',
        statusCode: statusCode,
        cause: error,
      );
    }

    return UnknownFailure(
      message: error.toString(),
      cause: error,
    );
  }
}
