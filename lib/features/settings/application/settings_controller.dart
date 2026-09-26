import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/failures.dart';
import '../../../core/result.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../integrations/mcp/mcp_client.dart';
import '../../../integrations/mcp/mcp_server_config.dart';
import '../../../integrations/notion/notion_client.dart';
import '../../../integrations/notion/notion_schema.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSettings>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsController(repo);
});

class SettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsController(this._repo) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  final SettingsRepository _repo;

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setProviderAndModel(String providerId, String modelId) async {
    await _repo.setProviderAndModel(providerId, modelId);
    await loadSettings();
  }

  Future<void> setGeminiApiKey(String? key) async {
    await _repo.setGeminiApiKey(key);
    await loadSettings();
  }

  Future<void> setAnthropicApiKey(String? key) async {
    await _repo.setAnthropicApiKey(key);
    await loadSettings();
  }

  Future<void> setOpenAiApiKey(String? key) async {
    await _repo.setOpenAiApiKey(key);
    await loadSettings();
  }

  Future<void> setNotionToken(String? token) async {
    await _repo.setNotionToken(token);
    await loadSettings();
  }

  Future<void> setNotionDatabaseId(String? id) async {
    await _repo.setNotionDatabaseId(id);
    await loadSettings();
  }

  Future<void> setNotionDataSourceId(String? id) async {
    await _repo.setNotionDataSourceId(id);
    await loadSettings();
  }

  Future<void> setMcpBaseUrl(String url) async {
    await _repo.setMcpBaseUrl(url);
    await loadSettings();
  }

  Future<void> setMcpToken(String serverId, String? token) async {
    await _repo.setMcpToken(serverId, token);
    await loadSettings();
  }

  Future<void> addCustomMcpServer(String name, String url, {String? token}) async {
    await _repo.addCustomMcpServer(name, url, token: token);
    await loadSettings();
  }

  Future<void> removeCustomMcpServer(String id) async {
    await _repo.removeCustomMcpServer(id);
    await loadSettings();
  }

  Future<void> setThemeMode(String mode) async {
    await _repo.setThemeMode(mode);
    await loadSettings();
  }

  Future<void> setUseDynamicColor(bool value) async {
    await _repo.setUseDynamicColor(value);
    await loadSettings();
  }

  Future<void> setEnterSendsMessage(bool value) async {
    await _repo.setEnterSendsMessage(value);
    await loadSettings();
  }

  Future<void> setAutoRunTools(bool autoRun) async {
    await _repo.setAutoRunTools(autoRun);
    await loadSettings();
  }

  // Live connection tests
  Future<Result<String>> testNotionConnection() async {
    final token = await _repo.getNotionToken();
    if (token == null || token.isEmpty) {
      return Result.err(AuthFailure(
        service: 'notion',
        message: 'Please enter a Notion API token first.',
      ));
    }

    final client = NotionClient(apiKey: token);
    final res = await client.testConnection();
    if (res.isOk) {
      final user = res.valueOrNull?['name'] ?? 'Notion Integration';
      return Result.ok('Connected successfully as "$user"');
    }
    return Result.err(res.failureOrNull!);
  }

  Future<Result<NotionResolvedSchema>> discoverNotionSchema(String databaseId) async {
    final token = await _repo.getNotionToken();
    if (token == null || token.isEmpty) {
      return Result.err(AuthFailure(
        service: 'notion',
        message: 'Notion token not set.',
      ));
    }

    final client = NotionClient(apiKey: token);
    return client.resolveSchema(databaseId);
  }

  Future<Result<String>> testMcpConnection(String endpointUrl, {String? token}) async {
    var rawUrl = endpointUrl.trim();
    if (rawUrl.isEmpty) {
      return Result.err(const NetworkFailure(message: 'Please provide an MCP server URL.'));
    }
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'http://$rawUrl';
    }
    final normalized = rawUrl.endsWith('/mcp') || rawUrl.endsWith('/sse')
        ? rawUrl
        : (rawUrl.endsWith('/') ? '${rawUrl}mcp' : '$rawUrl/mcp');

    final client = McpClient(
      config: McpServerConfig(
        id: 'test',
        name: 'Test Server',
        endpointUrl: normalized,
        bearerToken: token,
      ),
    );

    final res = await client.listTools();
    await client.dispose();

    if (res.isOk) {
      final count = res.valueOrNull?.length ?? 0;
      return Result.ok('Connected! Discovered $count tools.');
    }
    return Result.err(res.failureOrNull!);
  }
}
