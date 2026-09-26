import 'dart:convert';
import '../../core/failures.dart';
import '../../core/result.dart';
import '../llm/llm_types.dart';

class McpContentDecoder {
  const McpContentDecoder._();

  static List<LlmPart> decodeContentBlocks(List<dynamic> rawBlocks) {
    final parts = <LlmPart>[];

    for (final block in rawBlocks) {
      if (block is! Map<String, dynamic>) continue;
      final type = block['type'] as String? ?? 'text';

      switch (type) {
        case 'text':
          final text = block['text'] as String? ?? '';
          if (text.isNotEmpty) parts.add(TextPart(text));
        case 'image':
          final data = block['data'] as String? ?? '';
          final mimeType = block['mimeType'] as String? ?? 'image/png';
          if (data.isNotEmpty) {
            try {
              final bytes = base64Decode(data);
              parts.add(ImagePart(bytes: bytes, mimeType: mimeType));
            } catch (_) {}
          }
        case 'resource':
          final resource = block['resource'] as Map<String, dynamic>?;
          if (resource != null) {
            final text = resource['text'] as String?;
            if (text != null && text.isNotEmpty) {
              parts.add(TextPart(text));
            } else {
              final uri = resource['uri'] as String? ?? '';
              parts.add(TextPart('[Resource: $uri]'));
            }
          }
      }
    }

    return parts;
  }

  static Result<Map<String, dynamic>> decodeToolCallResult(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return Result.ok({'result': data});
    }

    final isError = data['isError'] as bool? ?? false;
    final content = data['content'] as List<dynamic>? ?? [];

    final textParts = <String>[];
    for (final block in content) {
      if (block is Map<String, dynamic>) {
        if (block['type'] == 'text') {
          textParts.add(block['text'] as String? ?? '');
        } else if (block['type'] == 'resource') {
          final res = block['resource'] as Map<String, dynamic>?;
          if (res?['text'] != null) {
            textParts.add(res!['text'] as String);
          }
        }
      }
    }

    final combinedText = textParts.join('\n').trim();

    if (isError) {
      final errorMsg = combinedText.isNotEmpty
          ? combinedText
          : 'MCP tool returned error (isError=true)';
      return Result.err(ToolFailure(
        toolName: 'mcp_tool',
        message: errorMsg,
      ));
    }

    // Attempt to parse json from text if structured
    if (combinedText.startsWith('{') && combinedText.endsWith('}')) {
      try {
        final parsed = jsonDecode(combinedText);
        if (parsed is Map<String, dynamic>) {
          return Result.ok(parsed);
        }
      } catch (_) {}
    } else if (combinedText.startsWith('[') && combinedText.endsWith(']')) {
      try {
        final parsed = jsonDecode(combinedText);
        if (parsed is List) {
          return Result.ok({'items': parsed});
        }
      } catch (_) {}
    }

    if (combinedText.isNotEmpty) {
      return Result.ok({'text': combinedText, 'raw': data});
    }

    return Result.ok(data);
  }
}
