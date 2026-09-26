import 'dart:convert';
import 'package:drift/drift.dart';
import '../../core/utils/id.dart';
import '../db/database.dart';
import '../stores/prefs_store.dart';
import '../stores/secret_store.dart';

class CustomMcpServerEntry {
  const CustomMcpServerEntry({
    required this.id,
    required this.name,
    required this.url,
    this.bearerToken,
  });

  factory CustomMcpServerEntry.fromJson(Map<String, dynamic> json) {
    return CustomMcpServerEntry(
      id: json['id'] as String? ?? generateId(),
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      bearerToken: json['bearerToken'] as String?,
    );
  }

  final String id;
  final String name;
  final String url;
  final String? bearerToken;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
      };
}

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.providerId = 'gemini',
    this.modelId = 'gemini-1.5-flash',
    this.autoRunTools = true,
    this.selectedNotionDatabaseId,
    this.selectedNotionDataSourceId,
    this.customMcpServers = const [],
    this.useDynamicColor = false,
    this.enterSendsMessage = true,
    this.hasGeminiKey = false,
    this.hasAnthropicKey = false,
    this.hasOpenAiKey = false,
    this.hasNotionToken = false,
  });

  final String themeMode; // system|light|dark
  final String providerId;
  final String modelId;
  final bool autoRunTools;
  final String? selectedNotionDatabaseId;
  final String? selectedNotionDataSourceId;
  final List<CustomMcpServerEntry> customMcpServers;
  final bool useDynamicColor;
  final bool enterSendsMessage;

  // Key presence indicators (do not leak raw keys in state)
  final bool hasGeminiKey;
  final bool hasAnthropicKey;
  final bool hasOpenAiKey;
  final bool hasNotionToken;

  AppSettings copyWith({
    String? themeMode,
    String? providerId,
    String? modelId,
    bool? autoRunTools,
    String? selectedNotionDatabaseId,
    String? selectedNotionDataSourceId,
    List<CustomMcpServerEntry>? customMcpServers,
    bool? useDynamicColor,
    bool? enterSendsMessage,
    bool? hasGeminiKey,
    bool? hasAnthropicKey,
    bool? hasOpenAiKey,
    bool? hasNotionToken,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        providerId: providerId ?? this.providerId,
        modelId: modelId ?? this.modelId,
        autoRunTools: autoRunTools ?? this.autoRunTools,
        selectedNotionDatabaseId:
            selectedNotionDatabaseId ?? this.selectedNotionDatabaseId,
        selectedNotionDataSourceId:
            selectedNotionDataSourceId ?? this.selectedNotionDataSourceId,
        customMcpServers: customMcpServers ?? this.customMcpServers,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
        enterSendsMessage: enterSendsMessage ?? this.enterSendsMessage,
        hasGeminiKey: hasGeminiKey ?? this.hasGeminiKey,
        hasAnthropicKey: hasAnthropicKey ?? this.hasAnthropicKey,
        hasOpenAiKey: hasOpenAiKey ?? this.hasOpenAiKey,
        hasNotionToken: hasNotionToken ?? this.hasNotionToken,
      );
}

class SettingsRepository {
  SettingsRepository({
    required this.secretStore,
    required this.prefsStore,
    required this.db,
  });

  final SecretStore secretStore;
  final PrefsStore prefsStore;
  final AppDatabase db;

  Future<AppSettings> getSettings() async {
    final geminiKey = await secretStore.getGeminiApiKey();
    final anthropicKey = await secretStore.getAnthropicApiKey();
    final openAiKey = await secretStore.getOpenAiApiKey();
    final notionToken = await secretStore.getNotionToken();

    List<CustomMcpServerEntry> servers = [];
    final serversJson = prefsStore.customMcpServersJson;
    if (serversJson != null) {
      try {
        final decoded = jsonDecode(serversJson) as List<dynamic>;
        servers = decoded
            .map((e) =>
                CustomMcpServerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return AppSettings(
      themeMode: prefsStore.themeMode,
      providerId: prefsStore.providerId,
      modelId: prefsStore.modelId,
      autoRunTools: prefsStore.autoRunTools,
      selectedNotionDatabaseId: prefsStore.notionDatabaseId,
      selectedNotionDataSourceId: prefsStore.notionDataSourceId,
      customMcpServers: servers,
      useDynamicColor: prefsStore.useDynamicColor,
      enterSendsMessage: prefsStore.enterSendsMessage,
      hasGeminiKey: geminiKey != null && geminiKey.isNotEmpty,
      hasAnthropicKey: anthropicKey != null && anthropicKey.isNotEmpty,
      hasOpenAiKey: openAiKey != null && openAiKey.isNotEmpty,
      hasNotionToken: notionToken != null && notionToken.isNotEmpty,
    );
  }

  // Appearance & General
  Future<void> setThemeMode(String mode) => prefsStore.setThemeMode(mode);
  Future<void> setUseDynamicColor(bool value) => prefsStore.setUseDynamicColor(value);
  Future<void> setEnterSendsMessage(bool value) => prefsStore.setEnterSendsMessage(value);

  // API Keys
  Future<void> setGeminiApiKey(String? key) => secretStore.setGeminiApiKey(key);
  Future<String?> getGeminiApiKey() => secretStore.getGeminiApiKey();

  Future<void> setAnthropicApiKey(String? key) =>
      secretStore.setAnthropicApiKey(key);
  Future<String?> getAnthropicApiKey() => secretStore.getAnthropicApiKey();

  Future<void> setOpenAiApiKey(String? key) => secretStore.setOpenAiApiKey(key);
  Future<String?> getOpenAiApiKey() => secretStore.getOpenAiApiKey();

  // Notion Config
  Future<void> setNotionToken(String? token) =>
      secretStore.setNotionToken(token);
  Future<String?> getNotionToken() => secretStore.getNotionToken();
  Future<void> setNotionDatabaseId(String? dbId) =>
      prefsStore.setNotionDatabaseId(dbId);
  Future<void> setNotionDataSourceId(String? dsId) =>
      prefsStore.setNotionDataSourceId(dsId);

  // MCP Config
  Future<void> setMcpBaseUrl(String url) => prefsStore.setMcpBaseUrl(url);
  Future<void> setMcpToken(String serverId, String? token) =>
      secretStore.setMcpToken(serverId, token);
  Future<String?> getMcpToken(String serverId) =>
      secretStore.getMcpToken(serverId);

  Future<void> saveCustomMcpServers(List<CustomMcpServerEntry> servers) async {
    final encoded = jsonEncode(servers.map((s) => s.toJson()).toList());
    await prefsStore.setCustomMcpServersJson(encoded);
  }

  Future<void> addCustomMcpServer(String name, String url,
      {String? token}) async {
    final id = generateId();
    final settings = await getSettings();
    final updated = List<CustomMcpServerEntry>.from(settings.customMcpServers)
      ..add(CustomMcpServerEntry(id: id, name: name, url: url));
    await saveCustomMcpServers(updated);
    if (token != null && token.isNotEmpty) {
      await setMcpToken(id, token);
    }
  }

  Future<void> removeCustomMcpServer(String serverId) async {
    final settings = await getSettings();
    final updated =
        settings.customMcpServers.where((s) => s.id != serverId).toList();
    await saveCustomMcpServers(updated);
    await secretStore.deleteMcpToken(serverId);
  }

  // Appearance & General
  Future<void> setProviderAndModel(String providerId, String modelId) async {
    await prefsStore.setProviderId(providerId);
    await prefsStore.setModelId(modelId);
  }
  Future<void> setDefaultModel(String providerId, String modelId) =>
      setProviderAndModel(providerId, modelId);
  Future<void> setAutoRunTools(bool autoRun) =>
      prefsStore.setAutoRunTools(autoRun);

  // Quick Prompts
  Stream<List<QuickPrompt>> watchQuickPrompts() =>
      db.quickPromptDao.watchQuickPrompts();

  Future<void> addQuickPrompt(String label, String promptText) async {
    final prompts = await db.quickPromptDao.getQuickPrompts();
    final companion = QuickPromptsCompanion.insert(
      id: generateId(),
      label: label,
      promptText: promptText,
      sortOrder: prompts.length,
      builtin: const Value(false),
    );
    await db.quickPromptDao.insertQuickPrompt(companion);
  }

  Future<void> updateQuickPrompt(String id, String label, String promptText) =>
      db.quickPromptDao.updateQuickPrompt(id, label, promptText);

  Future<void> deleteQuickPrompt(String id) =>
      db.quickPromptDao.deleteQuickPrompt(id);

  Future<void> reorderQuickPrompts(List<String> orderedIds) =>
      db.quickPromptDao.reorderPrompts(orderedIds);
}
