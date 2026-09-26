import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String keyProviderId = 'mitra.pref.providerId';
  static const String keyModelId = 'mitra.pref.modelId';
  static const String keyMcpBaseUrl = 'mitra.pref.mcp.baseUrl';
  static const String keyCustomMcpServers = 'mitra.pref.mcp.customServersJson';
  static const String keyNotionDatabaseId = 'mitra.pref.notion.databaseId';
  static const String keyNotionDataSourceId = 'mitra.pref.notion.dataSourceId';
  static const String keyThemeMode = 'mitra.pref.themeMode';
  static const String keyAutoRunTools = 'mitra.pref.autoRunTools';
  static const String keyMcpSkillPromptNames = 'mitra.pref.mcp.skillPromptNames';

  // UI preferences (F3.6.2, F4.10)
  static const String keyUiListPaneWidth = 'mitra.pref.ui.listPaneWidth';
  static const String keyUiInspectorVisible = 'mitra.pref.ui.inspectorVisible';
  static const String keyUiSidebarCollapsed = 'mitra.pref.ui.sidebarCollapsed';
  static const String keyUiTextScale = 'mitra.pref.ui.textScale';
  static const String keyUiDensity = 'mitra.pref.ui.density';
  static const String keyUseDynamicColor = 'mitra.pref.ui.useDynamicColor';
  static const String keyEnterSendsMessage = 'mitra.pref.ui.enterSendsMessage';

  String get providerId => _prefs.getString(keyProviderId) ?? 'gemini';
  Future<bool> setProviderId(String value) => _prefs.setString(keyProviderId, value);

  String get modelId => _prefs.getString(keyModelId) ?? 'gemini-2.5-flash';
  Future<bool> setModelId(String value) => _prefs.setString(keyModelId, value);

  String get mcpBaseUrl => _prefs.getString(keyMcpBaseUrl) ?? 'http://localhost:8080';
  Future<bool> setMcpBaseUrl(String value) => _prefs.setString(keyMcpBaseUrl, value);

  String? get customMcpServersJson => _prefs.getString(keyCustomMcpServers);
  Future<bool> setCustomMcpServersJson(String? json) =>
      json != null ? _prefs.setString(keyCustomMcpServers, json) : _prefs.remove(keyCustomMcpServers);

  String? get notionDatabaseId => _prefs.getString(keyNotionDatabaseId);
  Future<bool> setNotionDatabaseId(String? id) =>
      id != null ? _prefs.setString(keyNotionDatabaseId, id) : _prefs.remove(keyNotionDatabaseId);

  String? get notionDataSourceId => _prefs.getString(keyNotionDataSourceId);
  Future<bool> setNotionDataSourceId(String? id) =>
      id != null ? _prefs.setString(keyNotionDataSourceId, id) : _prefs.remove(keyNotionDataSourceId);

  String get themeMode => _prefs.getString(keyThemeMode) ?? 'system';
  Future<bool> setThemeMode(String mode) => _prefs.setString(keyThemeMode, mode);

  bool get autoRunTools => _prefs.getBool(keyAutoRunTools) ?? true;
  Future<bool> setAutoRunTools(bool autoRun) => _prefs.setBool(keyAutoRunTools, autoRun);

  List<String> get mcpSkillPromptNames =>
      _prefs.getStringList(keyMcpSkillPromptNames) ?? [];
  Future<bool> setMcpSkillPromptNames(List<String> names) =>
      _prefs.setStringList(keyMcpSkillPromptNames, names);

  double get listPaneWidth => _prefs.getDouble(keyUiListPaneWidth) ?? 280.0;
  Future<bool> setListPaneWidth(double width) => _prefs.setDouble(keyUiListPaneWidth, width);

  bool get inspectorVisible => _prefs.getBool(keyUiInspectorVisible) ?? true;
  Future<bool> setInspectorVisible(bool visible) => _prefs.setBool(keyUiInspectorVisible, visible);

  bool get sidebarCollapsed => _prefs.getBool(keyUiSidebarCollapsed) ?? false;
  Future<bool> setSidebarCollapsed(bool collapsed) => _prefs.setBool(keyUiSidebarCollapsed, collapsed);

  double get textScale => _prefs.getDouble(keyUiTextScale) ?? 1.0;
  Future<bool> setTextScale(double scale) => _prefs.setDouble(keyUiTextScale, scale);

  double get density => _prefs.getDouble(keyUiDensity) ?? 0.0;
  Future<bool> setDensity(double d) => _prefs.setDouble(keyUiDensity, d);

  bool get useDynamicColor => _prefs.getBool(keyUseDynamicColor) ?? false;
  Future<bool> setUseDynamicColor(bool value) => _prefs.setBool(keyUseDynamicColor, value);

  bool get enterSendsMessage => _prefs.getBool(keyEnterSendsMessage) ?? true;
  Future<bool> setEnterSendsMessage(bool value) => _prefs.setBool(keyEnterSendsMessage, value);
}
