import '../../core/failures.dart';
import '../../core/result.dart';
import '../../domain/agent/tool_descriptor.dart';
import '../../domain/models/enums.dart';
import 'notion_client.dart';
import 'notion_schema.dart';
import 'notion_task_mapper.dart';

class NotionSchemaCache {
  final Map<String, NotionResolvedSchema> _cache = {};

  NotionResolvedSchema? get(String key) => _cache[key];

  void put(String key, NotionResolvedSchema schema) {
    _cache[key] = schema;
    if (schema.dataSourceId.isNotEmpty) {
      _cache[schema.dataSourceId] = schema;
    }
  }

  void clear() => _cache.clear();
}

class NotionTools {
  NotionTools._();

  static List<ToolDescriptor> createDescriptors({
    required NotionClient client,
    NotionResolvedSchema? schema,
    NotionSchemaCache? schemaCache,
  }) {
    final cache = schemaCache ?? NotionSchemaCache();
    if (schema != null) {
      cache.put(schema.dataSourceId, schema);
    }

    final tools = <ToolDescriptor>[
      _buildSearchDatabasesTool(client),
      _buildDescribeDatabaseTool(client, cache),
      _buildCreatePagesTool(client, cache),
      _buildUndoTaskTool(client),
    ];

    if (schema != null) {
      tools.add(_buildCreateTasksTool(client, schema));
    }

    return tools;
  }

  static ToolDescriptor _buildSearchDatabasesTool(NotionClient client) {
    return ToolDescriptor(
      name: 'notion.search_databases',
      description:
          'Searches for Notion databases or data sources accessible by your integration token.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Optional text query to filter database titles.',
          },
        },
      },
      source: ToolSource.builtin,
      requiresConfirmation: false,
      handler: (args) async {
        final query = args['query'] as String?;
        final res = await client.searchDatabases(query: query);
        if (res.isOk) {
          return Result.ok({'databases': res.valueOrNull ?? []});
        }
        return Result.err(res.failureOrNull!);
      },
    );
  }

  static ToolDescriptor _buildDescribeDatabaseTool(
    NotionClient client,
    NotionSchemaCache cache,
  ) {
    return ToolDescriptor(
      name: 'notion.describe_database',
      description:
          'Inspects and resolves property schemas, columns, and allowed options from a Notion database ID or URL.',
      inputSchema: {
        'type': 'object',
        'required': ['database_id_or_url'],
        'properties': {
          'database_id_or_url': {
            'type': 'string',
            'description':
                'The Notion database UUID, data source ID, or full Notion web URL (e.g. https://www.notion.so/workspace/Tasks-274e0d9bfad74bb4ba1c080327f3aa41).',
          },
        },
      },
      source: ToolSource.builtin,
      requiresConfirmation: false,
      handler: (args) async {
        final idOrUrl = args['database_id_or_url'] as String? ?? '';
        final cleanId = NotionClient.extractId(idOrUrl);
        if (cleanId == null || cleanId.isEmpty) {
          return const Result.err(ValidationFailure(
            message:
                'Invalid Notion database ID or URL. Provide a 32-character hex ID or full Notion URL.',
          ));
        }

        final cached = cache.get(cleanId);
        if (cached != null) {
          return Result.ok(_formatSchemaSummary(cached));
        }

        final schemaRes = await client.resolveSchema(cleanId);
        if (schemaRes.isErr) {
          return Result.err(schemaRes.failureOrNull!);
        }

        final schema = schemaRes.valueOrNull!;
        cache.put(cleanId, schema);
        return Result.ok(_formatSchemaSummary(schema));
      },
    );
  }

  static Map<String, dynamic> _formatSchemaSummary(NotionResolvedSchema schema) {
    final props = <String, dynamic>{};
    for (final entry in schema.rawProperties.entries) {
      props[entry.key] = {
        'type': entry.value.type,
        if (entry.value.options.isNotEmpty)
          'options': entry.value.options.map((o) => o.name).toList(),
      };
    }

    return {
      'data_source_id': schema.dataSourceId,
      'title_property': schema.titleProperty,
      'status_property': schema.statusProperty,
      'status_options': schema.statusOptions,
      'due_date_property': schema.dueDateProperty,
      'priority_property': schema.priorityProperty,
      'priority_options': schema.priorityOptions,
      'tags_property': schema.tagsProperty,
      'tags_options': schema.tagsOptions,
      'properties': props,
      'dropped_concepts': schema.droppedConcepts,
    };
  }

  static ToolDescriptor _buildCreatePagesTool(
    NotionClient client,
    NotionSchemaCache cache,
  ) {
    return ToolDescriptor(
      name: 'notion.create_pages',
      description:
          'Creates pages/tasks in any Notion database specified by ID or URL, validating properties just-in-time against its schema.',
      inputSchema: {
        'type': 'object',
        'required': ['database_id_or_url', 'pages'],
        'properties': {
          'database_id_or_url': {
            'type': 'string',
            'description': 'Target database ID or URL.',
          },
          'pages': {
            'type': 'array',
            'items': {
              'type': 'object',
              'required': ['title'],
              'properties': {
                'title': {'type': 'string'},
                'status': {'type': 'string'},
                'due_date': {'type': 'string'},
                'priority': {'type': 'string'},
                'tags': {
                  'type': 'array',
                  'items': {'type': 'string'}
                },
              },
            },
            'description': 'List of task pages to create.',
          },
        },
      },
      source: ToolSource.builtin,
      requiresConfirmation: false,
      handler: (args) async {
        final idOrUrl = args['database_id_or_url'] as String? ?? '';
        final cleanId = NotionClient.extractId(idOrUrl);
        if (cleanId == null || cleanId.isEmpty) {
          return const Result.err(ValidationFailure(
            message: 'Invalid database_id_or_url argument.',
          ));
        }

        var schema = cache.get(cleanId);
        if (schema == null) {
          final schemaRes = await client.resolveSchema(cleanId);
          if (schemaRes.isErr) {
            return Result.err(schemaRes.failureOrNull!);
          }
          schema = schemaRes.valueOrNull!;
          cache.put(cleanId, schema);
        }

        final rawPages = args['pages'] as List<dynamic>? ?? [];
        final createdTasks = <NotionCreatedTaskResult>[];

        for (final item in rawPages) {
          if (item is Map<String, dynamic>) {
            final title = item['title'] as String? ?? '';
            final status = item['status'] as String?;
            final dueDate = item['due_date'] as String?;
            final priority = item['priority'] as String?;
            final tags = (item['tags'] as List<dynamic>?)?.cast<String>();

            final createRes = await client.createPage(
              schema: schema,
              title: title,
              status: status,
              dueDate: dueDate,
              priority: priority,
              tags: tags,
            );

            if (createRes.isOk) {
              createdTasks.add(createRes.valueOrNull!);
            } else {
              return Result.err(createRes.failureOrNull!);
            }
          }
        }

        return Result.ok({
          'success': true,
          'count': createdTasks.length,
          'created_tasks': createdTasks.map((t) => t.toJson()).toList(),
          'dropped_properties': schema.droppedConcepts,
        });
      },
    );
  }

  static ToolDescriptor _buildCreateTasksTool(
    NotionClient client,
    NotionResolvedSchema schema,
  ) {
    final statusPropSchema = <String, dynamic>{
      'type': 'string',
      'description': 'Current status of the task.',
    };
    if (schema.statusOptions.isNotEmpty) {
      statusPropSchema['enum'] = schema.statusOptions;
    }

    final priorityPropSchema = <String, dynamic>{
      'type': 'string',
      'description': 'Priority level.',
    };
    if (schema.priorityOptions.isNotEmpty) {
      priorityPropSchema['enum'] = schema.priorityOptions;
    }

    final taskItemSchema = <String, dynamic>{
      'type': 'object',
      'required': ['title'],
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Clear, actionable title of the task.',
        },
        'status': statusPropSchema,
        'due_date': {
          'type': 'string',
          'description':
              'Due date in ISO format YYYY-MM-DD or relative date string like "tomorrow", "next monday", "eow".',
        },
        'priority': priorityPropSchema,
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Labels or tags for categorization.',
        },
      },
    };

    final inputSchema = <String, dynamic>{
      'type': 'object',
      'required': ['tasks'],
      'properties': {
        'tasks': {
          'type': 'array',
          'items': taskItemSchema,
          'description': 'List of tasks to create in the Notion database.',
        },
      },
    };

    return ToolDescriptor(
      name: 'notion.create_tasks',
      description:
          'Creates one or multiple tasks in the user\'s configured Notion database with title, status, due date, priority, and tags.',
      inputSchema: inputSchema,
      source: ToolSource.builtin,
      requiresConfirmation: false,
      handler: (args) async {
        final rawTasks = args['tasks'] as List<dynamic>? ?? [];
        final createdTasks = <NotionCreatedTaskResult>[];

        for (final item in rawTasks) {
          if (item is Map<String, dynamic>) {
            final title = item['title'] as String? ?? '';
            final status = item['status'] as String?;
            final dueDate = item['due_date'] as String?;
            final priority = item['priority'] as String?;
            final tags = (item['tags'] as List<dynamic>?)?.cast<String>();

            final createRes = await client.createPage(
              schema: schema,
              title: title,
              status: status,
              dueDate: dueDate,
              priority: priority,
              tags: tags,
            );

            if (createRes.isOk) {
              createdTasks.add(createRes.valueOrNull!);
            } else {
              return Result.err(createRes.failureOrNull!);
            }
          }
        }

        return Result.ok({
          'success': true,
          'count': createdTasks.length,
          'created_tasks': createdTasks.map((t) => t.toJson()).toList(),
          'dropped_properties': schema.droppedConcepts,
        });
      },
    );
  }

  static ToolDescriptor _buildUndoTaskTool(NotionClient client) {
    return ToolDescriptor(
      name: 'notion.undo_task',
      description: 'Archives a previously created Notion page / task.',
      inputSchema: {
        'type': 'object',
        'required': ['page_id'],
        'properties': {
          'page_id': {
            'type': 'string',
            'description': 'The UUID of the Notion page to archive/delete.',
          },
        },
      },
      source: ToolSource.builtin,
      requiresConfirmation: true,
      handler: (args) async {
        final pageId = args['page_id'] as String? ?? '';
        if (pageId.isEmpty) {
          return const Result.err(ValidationFailure(
            message: 'Missing page_id argument for notion.undo_task',
          ));
        }

        final res = await client.archivePage(pageId);
        if (res.isOk) {
          return Result.ok({'success': true, 'archived_page_id': pageId});
        }
        return Result.err(res.failureOrNull!);
      },
    );
  }
}
