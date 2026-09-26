import 'dart:async';
import 'dart:convert';
import '../../core/logging/logger.dart';
import '../../data/stores/prefs_store.dart';
import '../../data/stores/secret_store.dart';
import '../../integrations/mcp/mcp_client.dart';
import '../../integrations/mcp/mcp_server_config.dart';
import '../../integrations/notion/notion_client.dart';
import '../../integrations/notion/notion_schema.dart';
import '../../integrations/notion/notion_tools.dart';
import 'skill_context_builder.dart';
import 'tool_registry.dart';

class AgentRuntime {
  AgentRuntime({
    required this.secretStore,
    required this.prefsStore,
  });

  final SecretStore secretStore;
  final PrefsStore prefsStore;

  final ToolRegistry toolRegistry = ToolRegistry();
  final Map<String, McpClient> _mcpClients = {};
  final NotionSchemaCache notionSchemaCache = NotionSchemaCache();
  final SkillContextBuilder skillContextBuilder = SkillContextBuilder();

  String? _skillContext;
  DateTime? _lastInitialized;

  String? get skillContext => _skillContext;
  List<McpClient> get mcpClients => _mcpClients.values.toList();

  Future<void> ensureReady({bool force = false}) async {
    final isStale = _lastInitialized == null ||
        DateTime.now().difference(_lastInitialized!) > const Duration(minutes: 15);

    if (!force && !isStale) {
      return;
    }

    toolRegistry.clear();

    // 1. Configure and connect MCP servers
    final serverConfigs = <McpServerConfig>[];

    // Primary Mitra MCP
    final mitraUrl = prefsStore.mcpBaseUrl;
    if (mitraUrl.isNotEmpty) {
      final token = await secretStore.getMcpToken('mitra');
      serverConfigs.add(McpServerConfig(
        id: 'mitra',
        name: 'Mitra MCP',
        endpointUrl: mitraUrl,
        bearerToken: token,
      ));
    }

    // Custom MCP servers
    final customJson = prefsStore.customMcpServersJson;
    if (customJson != null && customJson.isNotEmpty) {
      try {
        final list = jsonDecode(customJson) as List<dynamic>? ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String? ?? '';
            final name = item['name'] as String? ?? 'Custom MCP';
            final url = item['endpointUrl'] as String? ?? '';
            if (id.isNotEmpty && url.isNotEmpty) {
              final token = await secretStore.getMcpToken(id);
              serverConfigs.add(McpServerConfig(
                id: id,
                name: name,
                endpointUrl: url,
                bearerToken: token,
              ));
            }
          }
        }
      } catch (e) {
        AppLogger.warning('Failed to parse custom MCP servers: $e');
      }
    }

    // Sync MCP client instances (reusing active ones where possible)
    final newClients = <String, McpClient>{};
    for (final cfg in serverConfigs) {
      final existing = _mcpClients[cfg.id];
      if (existing != null &&
          existing.config.endpointUrl == cfg.endpointUrl &&
          existing.config.bearerToken == cfg.bearerToken) {
        newClients[cfg.id] = existing;
      } else {
        await existing?.dispose();
        newClients[cfg.id] = McpClient(config: cfg);
      }
    }

    // Dispose removed clients
    for (final entry in _mcpClients.entries) {
      if (!newClients.containsKey(entry.key)) {
        await entry.value.dispose();
      }
    }
    _mcpClients
      ..clear()
      ..addAll(newClients);

    // Discover tools from each MCP client with a 10s per-server timeout
    for (final client in _mcpClients.values) {
      try {
        final toolRes = await client
            .getToolDescriptors()
            .timeout(const Duration(seconds: 10));
        if (toolRes.isOk) {
          toolRegistry.registerAll(toolRes.valueOrNull!);
        }
      } catch (e) {
        AppLogger.warning(
          'MCP server "${client.config.name}" tools unavailable (10s timeout or error): $e',
        );
      }
    }

    // 2. Discover MCP Skill Prompts and build Skill Context
    try {
      _skillContext = await skillContextBuilder
          .buildSkillContext(
            mcpClients: _mcpClients.values.toList(),
            userSelectedPromptNames: prefsStore.mcpSkillPromptNames,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      AppLogger.warning('Failed to build MCP skill context: $e');
      _skillContext = null;
    }

    // 3. Configure Notion Tools (Token-only registration gate per Plan §F2.3.7)
    final notionToken = await secretStore.getNotionToken();
    if (notionToken != null && notionToken.isNotEmpty) {
      final notionClient = NotionClient(apiKey: notionToken);
      NotionResolvedSchema? defaultSchema;

      final dbId = prefsStore.notionDatabaseId;
      final dsId = prefsStore.notionDataSourceId;

      if (dbId != null && dbId.isNotEmpty) {
        try {
          final schemaRes = await notionClient
              .resolveSchema(dbId, preferredDataSourceId: dsId)
              .timeout(const Duration(seconds: 10));
          if (schemaRes.isOk) {
            defaultSchema = schemaRes.valueOrNull;
          }
        } catch (e) {
          AppLogger.warning('Eager Notion schema resolution skipped: $e');
        }
      }

      final notionDescriptors = NotionTools.createDescriptors(
        client: notionClient,
        schema: defaultSchema,
        schemaCache: notionSchemaCache,
      );
      toolRegistry.registerAll(notionDescriptors);
    }

    _lastInitialized = DateTime.now();
  }

  Future<void> dispose() async {
    for (final client in _mcpClients.values) {
      await client.dispose();
    }
    _mcpClients.clear();
    toolRegistry.clear();
    notionSchemaCache.clear();
    skillContextBuilder.clearCache();
    _lastInitialized = null;
  }
}
