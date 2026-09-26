import '../../domain/models/enums.dart';
import '../llm/llm_types.dart';

class McpPromptArgument {
  const McpPromptArgument({
    required this.name,
    this.description,
    this.required = false,
  });

  final String name;
  final String? description;
  final bool required;

  factory McpPromptArgument.fromJson(Map<String, dynamic> json) =>
      McpPromptArgument(
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        required: json['required'] as bool? ?? false,
      );
}

class McpPromptSummary {
  const McpPromptSummary({
    required this.name,
    required this.description,
    this.arguments = const [],
  });

  final String name;
  final String description;
  final List<McpPromptArgument> arguments;

  factory McpPromptSummary.fromJson(Map<String, dynamic> json) {
    final rawArgs = (json['arguments'] as List<dynamic>?) ?? [];
    return McpPromptSummary(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      arguments: rawArgs
          .whereType<Map<String, dynamic>>()
          .map(McpPromptArgument.fromJson)
          .toList(),
    );
  }
}

class McpPromptMessage {
  const McpPromptMessage({
    required this.role,
    required this.parts,
  });

  final MessageRole role;
  final List<LlmPart> parts;
}

class McpResourceSummary {
  const McpResourceSummary({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
  });

  final String uri;
  final String name;
  final String? description;
  final String? mimeType;

  factory McpResourceSummary.fromJson(Map<String, dynamic> json) =>
      McpResourceSummary(
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        mimeType: json['mimeType'] as String?,
      );
}

class McpResourceContent {
  const McpResourceContent({
    required this.uri,
    this.mimeType,
    this.text,
    this.blob,
  });

  final String uri;
  final String? mimeType;
  final String? text;
  final String? blob;

  factory McpResourceContent.fromJson(Map<String, dynamic> json) =>
      McpResourceContent(
        uri: json['uri'] as String? ?? '',
        mimeType: json['mimeType'] as String?,
        text: json['text'] as String?,
        blob: json['blob'] as String?,
      );
}
