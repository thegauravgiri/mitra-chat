import '../../core/utils/date_parsing.dart';
import 'notion_schema.dart';

class NotionCreatedTaskResult {
  const NotionCreatedTaskResult({
    required this.id,
    required this.url,
    required this.title,
    this.status,
    this.dueDate,
    this.priority,
    this.tags = const [],
    this.droppedConcepts = const [],
  });

  final String id;
  final String url;
  final String title;
  final String? status;
  final String? dueDate;
  final String? priority;
  final List<String> tags;
  final List<String> droppedConcepts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_id': id,
        'url': url,
        'title': title,
        'status': status,
        'dueDate': dueDate,
        'priority': priority,
        'tags': tags,
        'droppedConcepts': droppedConcepts,
      };

  factory NotionCreatedTaskResult.fromJson(Map<String, dynamic> json) =>
      NotionCreatedTaskResult(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String?,
        dueDate: json['dueDate'] as String?,
        priority: json['priority'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
        droppedConcepts:
            (json['droppedConcepts'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

class NotionTaskMapper {
  NotionTaskMapper._();

  static Map<String, dynamic> buildCreatePagePayload({
    required NotionResolvedSchema schema,
    required String title,
    String? status,
    String? dueDate,
    String? priority,
    List<String>? tags,
  }) {
    final properties = <String, dynamic>{
      schema.titleProperty: {
        'title': [
          {
            'type': 'text',
            'text': {'content': title},
          }
        ],
      },
    };

    final dropped = <String>[];

    // Status
    if (status != null && status.isNotEmpty) {
      if (schema.statusProperty != null) {
        final matchedOption = _matchOption(status, schema.statusOptions);
        final propDef = schema.rawProperties[schema.statusProperty!];
        if (propDef?.type == 'status') {
          properties[schema.statusProperty!] = {
            'status': {'name': matchedOption ?? status},
          };
        } else {
          properties[schema.statusProperty!] = {
            'select': {'name': matchedOption ?? status},
          };
        }
      } else {
        dropped.add('Status');
      }
    }

    // Due Date
    if (dueDate != null && dueDate.isNotEmpty) {
      if (schema.dueDateProperty != null) {
        final parsedDate = DateParsing.parseFlexible(dueDate);
        final isoStr = parsedDate != null
            ? DateParsing.toIsoDateString(parsedDate)
            : dueDate;
        properties[schema.dueDateProperty!] = {
          'date': {'start': isoStr},
        };
      } else {
        dropped.add('Due Date');
      }
    }

    // Priority
    if (priority != null && priority.isNotEmpty) {
      if (schema.priorityProperty != null) {
        final matchedOption = _matchOption(priority, schema.priorityOptions);
        final propDef = schema.rawProperties[schema.priorityProperty!];
        if (propDef?.type == 'status') {
          properties[schema.priorityProperty!] = {
            'status': {'name': matchedOption ?? priority},
          };
        } else {
          properties[schema.priorityProperty!] = {
            'select': {'name': matchedOption ?? priority},
          };
        }
      } else {
        dropped.add('Priority');
      }
    }

    // Tags
    if (tags != null && tags.isNotEmpty) {
      if (schema.tagsProperty != null) {
        properties[schema.tagsProperty!] = {
          'multi_select': tags.map((t) => {'name': t}).toList(),
        };
      } else {
        dropped.add('Tags');
      }
    }

    return {
      'parent': {
        'type': 'data_source_id',
        'data_source_id': schema.dataSourceId,
      },
      'properties': properties,
    };
  }

  static String? _matchOption(String input, List<String> availableOptions) {
    if (availableOptions.isEmpty) return null;
    final clean = input.trim().toLowerCase();
    for (final opt in availableOptions) {
      if (opt.toLowerCase() == clean) return opt;
    }
    // Partial match (e.g. "todo" -> "To Do", "in progress" -> "In Progress")
    for (final opt in availableOptions) {
      final optClean = opt.replaceAll(RegExp(r'[\s\-_]'), '').toLowerCase();
      final inClean = clean.replaceAll(RegExp(r'[\s\-_]'), '');
      if (optClean == inClean || optClean.contains(inClean) || inClean.contains(optClean)) {
        return opt;
      }
    }
    return availableOptions.first;
  }

  static NotionCreatedTaskResult parsePageResponse({
    required Map<String, dynamic> response,
    required NotionResolvedSchema schema,
    required String requestedTitle,
    String? requestedStatus,
    String? requestedDueDate,
    String? requestedPriority,
    List<String>? requestedTags,
  }) {
    final id = response['id'] as String? ?? '';
    final url = response['url'] as String? ?? 'https://www.notion.so/${id.replaceAll('-', '')}';

    final dropped = List<String>.from(schema.droppedConcepts);

    return NotionCreatedTaskResult(
      id: id,
      url: url,
      title: requestedTitle,
      status: schema.statusProperty != null ? requestedStatus : null,
      dueDate: schema.dueDateProperty != null ? requestedDueDate : null,
      priority: schema.priorityProperty != null ? requestedPriority : null,
      tags: schema.tagsProperty != null ? (requestedTags ?? const []) : const [],
      droppedConcepts: dropped,
    );
  }
}
