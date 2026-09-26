class NotionPropertyOption {
  const NotionPropertyOption({
    required this.id,
    required this.name,
    this.color,
  });

  final String id;
  final String name;
  final String? color;

  factory NotionPropertyOption.fromJson(Map<String, dynamic> json) =>
      NotionPropertyOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String?,
      );
}

class NotionPropertySchema {
  const NotionPropertySchema({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
  });

  final String id;
  final String name;
  final String type; // title, status, select, multi_select, date, etc.
  final List<NotionPropertyOption> options;

  factory NotionPropertySchema.fromJson(String name, Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    List<NotionPropertyOption> options = [];

    if (type == 'status' && json['status'] is Map<String, dynamic>) {
      final statusMap = json['status'] as Map<String, dynamic>;
      final rawOptions = statusMap['options'] as List<dynamic>? ?? [];
      options = rawOptions
          .whereType<Map<String, dynamic>>()
          .map(NotionPropertyOption.fromJson)
          .toList();
    } else if (type == 'select' && json['select'] is Map<String, dynamic>) {
      final selectMap = json['select'] as Map<String, dynamic>;
      final rawOptions = selectMap['options'] as List<dynamic>? ?? [];
      options = rawOptions
          .whereType<Map<String, dynamic>>()
          .map(NotionPropertyOption.fromJson)
          .toList();
    } else if (type == 'multi_select' && json['multi_select'] is Map<String, dynamic>) {
      final multiSelectMap = json['multi_select'] as Map<String, dynamic>;
      final rawOptions = multiSelectMap['options'] as List<dynamic>? ?? [];
      options = rawOptions
          .whereType<Map<String, dynamic>>()
          .map(NotionPropertyOption.fromJson)
          .toList();
    }

    return NotionPropertySchema(
      id: json['id'] as String? ?? '',
      name: name,
      type: type,
      options: options,
    );
  }
}

class NotionResolvedSchema {
  const NotionResolvedSchema({
    required this.dataSourceId,
    required this.titleProperty,
    this.statusProperty,
    this.statusOptions = const [],
    this.dueDateProperty,
    this.priorityProperty,
    this.priorityOptions = const [],
    this.tagsProperty,
    this.tagsOptions = const [],
    this.rawProperties = const {},
    this.droppedConcepts = const [],
  });

  final String dataSourceId;
  final String titleProperty;
  final String? statusProperty;
  final List<String> statusOptions;
  final String? dueDateProperty;
  final String? priorityProperty;
  final List<String> priorityOptions;
  final String? tagsProperty;
  final List<String> tagsOptions;
  final Map<String, NotionPropertySchema> rawProperties;
  final List<String> droppedConcepts;

  /// Resolves properties type-first, name-second (Plan §6 table).
  factory NotionResolvedSchema.fromPropertiesMap({
    required String dataSourceId,
    required Map<String, dynamic> propertiesJson,
  }) {
    final properties = <String, NotionPropertySchema>{};
    for (final entry in propertiesJson.entries) {
      if (entry.value is Map<String, dynamic>) {
        properties[entry.key] = NotionPropertySchema.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        );
      }
    }

    // 1. Title: The single property with type == 'title'
    String? titleProp;
    for (final p in properties.values) {
      if (p.type == 'title') {
        titleProp = p.name;
        break;
      }
    }
    titleProp ??= 'Name'; // fallback default

    // 2. Status: type in {status, select}, matching /status|state/i, else first status/select
    String? statusProp;
    List<String> statusOpts = [];
    final statusCandidates = properties.values.where(
      (p) => p.type == 'status' || p.type == 'select',
    );
    final statusRegex = RegExp(r'status|state', caseSensitive: false);
    final statusMatch = statusCandidates.firstWhere(
      (p) => statusRegex.hasMatch(p.name),
      orElse: () => statusCandidates.isNotEmpty ? statusCandidates.first : const NotionPropertySchema(id: '', name: '', type: ''),
    );
    if (statusMatch.name.isNotEmpty) {
      statusProp = statusMatch.name;
      statusOpts = statusMatch.options.map((o) => o.name).toList();
    }

    // 3. Due date: type == 'date', name matching /due|deadline|date/i
    String? dateProp;
    final dateCandidates = properties.values.where((p) => p.type == 'date');
    final dateRegex = RegExp(r'due|deadline|date', caseSensitive: false);
    final dateMatch = dateCandidates.firstWhere(
      (p) => dateRegex.hasMatch(p.name),
      orElse: () => dateCandidates.isNotEmpty ? dateCandidates.first : const NotionPropertySchema(id: '', name: '', type: ''),
    );
    if (dateMatch.name.isNotEmpty) {
      dateProp = dateMatch.name;
    }

    // 4. Priority: type in {select, status}, name matching /priority|prio/i
    String? priorityProp;
    List<String> priorityOpts = [];
    final prioRegex = RegExp(r'priority|prio', caseSensitive: false);
    final prioCandidates = properties.values.where(
      (p) => (p.type == 'select' || p.type == 'status') && p.name != statusProp,
    );
    final prioMatch = prioCandidates.firstWhere(
      (p) => prioRegex.hasMatch(p.name),
      orElse: () => const NotionPropertySchema(id: '', name: '', type: ''),
    );
    if (prioMatch.name.isNotEmpty) {
      priorityProp = prioMatch.name;
      priorityOpts = prioMatch.options.map((o) => o.name).toList();
    }

    // 5. Tags: type == 'multi_select', name matching /tag|label|categor/i
    String? tagsProp;
    List<String> tagsOpts = [];
    final tagRegex = RegExp(r'tag|label|categor', caseSensitive: false);
    final tagCandidates = properties.values.where((p) => p.type == 'multi_select');
    final tagMatch = tagCandidates.firstWhere(
      (p) => tagRegex.hasMatch(p.name),
      orElse: () => tagCandidates.isNotEmpty ? tagCandidates.first : const NotionPropertySchema(id: '', name: '', type: ''),
    );
    if (tagMatch.name.isNotEmpty) {
      tagsProp = tagMatch.name;
      tagsOpts = tagMatch.options.map((o) => o.name).toList();
    }

    final dropped = <String>[];
    if (statusProp == null) dropped.add('Status');
    if (dateProp == null) dropped.add('Due Date');
    if (priorityProp == null) dropped.add('Priority');
    if (tagsProp == null) dropped.add('Tags');

    return NotionResolvedSchema(
      dataSourceId: dataSourceId,
      titleProperty: titleProp,
      statusProperty: statusProp,
      statusOptions: statusOpts,
      dueDateProperty: dateProp,
      priorityProperty: priorityProp,
      priorityOptions: priorityOpts,
      tagsProperty: tagsProp,
      tagsOptions: tagsOpts,
      rawProperties: properties,
      droppedConcepts: dropped,
    );
  }
}
