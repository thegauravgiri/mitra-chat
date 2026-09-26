import 'dart:async';
import '../../core/logging/logger.dart';
import '../../integrations/llm/llm_types.dart';
import '../../integrations/mcp/mcp_client.dart';
import '../../integrations/mcp/mcp_prompt.dart';

class _CachedPrompt {
  _CachedPrompt({required this.text, required this.fetchedAt});
  final String text;
  final DateTime fetchedAt;

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(fetchedAt) > ttl;
}

class SkillContextBuilder {
  SkillContextBuilder({
    this.cacheTtl = const Duration(minutes: 15),
    this.maxCharBudget = 24000,
  });

  final Duration cacheTtl;
  final int maxCharBudget;
  final Map<String, _CachedPrompt> _cache = {};

  void clearCache() {
    _cache.clear();
  }

  Future<String?> buildSkillContext({
    required List<McpClient> mcpClients,
    List<String> userSelectedPromptNames = const [],
  }) async {
    if (mcpClients.isEmpty) return null;

    final skillBlocks = <String>[];
    var currentChars = 0;
    final droppedPrompts = <String>[];

    for (final client in mcpClients) {
      try {
        final listRes = await client.listPrompts();
        if (listRes.isErr) continue;

        final allPrompts = listRes.valueOrNull ?? [];
        final selectedPrompts = allPrompts.where((p) {
          if (userSelectedPromptNames.isNotEmpty) {
            return userSelectedPromptNames.contains(p.name);
          }
          return isSkillPrompt(p);
        }).toList();

        for (final prompt in selectedPrompts) {
          final cacheKey = '${client.config.id}::${prompt.name}';
          String? promptBody;

          final cached = _cache[cacheKey];
          if (cached != null && !cached.isExpired(cacheTtl)) {
            promptBody = cached.text;
          } else {
            try {
              final getRes = await client.getPrompt(prompt.name, {});
              if (getRes.isOk) {
                final messages = getRes.valueOrNull ?? [];
                final buffer = StringBuffer();
                for (final msg in messages) {
                  for (final part in msg.parts) {
                    if (part is TextPart && part.text.isNotEmpty) {
                      buffer.writeln(part.text);
                    }
                  }
                }
                promptBody = buffer.toString().trim();
                if (promptBody.isNotEmpty) {
                  _cache[cacheKey] = _CachedPrompt(
                    text: promptBody,
                    fetchedAt: DateTime.now(),
                  );
                }
              }
            } catch (e) {
              AppLogger.warning('Failed to fetch skill prompt "${prompt.name}" from ${client.config.id}: $e');
            }
          }

          if (promptBody != null && promptBody.isNotEmpty) {
            final block = '''
--- BEGIN SKILL: ${prompt.name} (${client.config.id}) ---
$promptBody
--- END SKILL: ${prompt.name} ---''';

            if (currentChars + block.length <= maxCharBudget) {
              skillBlocks.add(block);
              currentChars += block.length;
            } else {
              droppedPrompts.add('${client.config.id}/${prompt.name}');
            }
          }
        }
      } catch (e) {
        AppLogger.warning('Error fetching prompts from ${client.config.id}: $e');
      }
    }

    if (droppedPrompts.isNotEmpty) {
      AppLogger.warning(
        'Skill context character budget ($maxCharBudget chars) reached. Dropped skills: ${droppedPrompts.join(', ')}',
      );
    }

    if (skillBlocks.isEmpty) return null;

    return '''
### CONNECTED SKILLS
The following skill definitions were loaded from your connected MCP servers. They are authoritative: they contain the database IDs, schemas, field names, and conventions you must use. Prefer them over asking the user for IDs or URLs.

${skillBlocks.join('\n\n')}''';
  }

  bool isSkillPrompt(McpPromptSummary prompt) {
    final nameAndDesc = '${prompt.name} ${prompt.description}'.toLowerCase();
    final hasKeyword = RegExp(r'(skill|dashboard|notion|instructions|guide|context)').hasMatch(nameAndDesc);
    final hasNoRequiredArgs = prompt.arguments.every((arg) => !arg.required);

    return hasKeyword || hasNoRequiredArgs;
  }
}
