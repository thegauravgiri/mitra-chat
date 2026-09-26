import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/logging/logger.dart';

/// Central store for all sensitive credentials.
/// This is the ONLY file in the codebase permitted to import flutter_secure_storage.
/// Includes an automatic local sandboxed vault fallback if platform Keychain access is restricted.
class SecretStore {
  SecretStore([FlutterSecureStorage? storage, Directory? fallbackDir])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _customFallbackDir = fallbackDir;

  final FlutterSecureStorage _storage;
  final Directory? _customFallbackDir;

  static const String keyGeminiApiKey = 'mitra.llm.gemini.apiKey';
  static const String keyAnthropicApiKey = 'mitra.llm.anthropic.apiKey';
  static const String keyOpenAiApiKey = 'mitra.llm.openai.apiKey';
  static const String keyNotionToken = 'mitra.notion.token';
  static const String _keyMcpTokenPrefix = 'mitra.mcp.';

  static String keyMcpToken(String serverId) =>
      '$_keyMcpTokenPrefix$serverId.token';

  Future<String?> getGeminiApiKey() => _readSafe(keyGeminiApiKey);
  Future<void> setGeminiApiKey(String? key) => _writeSafe(keyGeminiApiKey, key);

  Future<String?> getAnthropicApiKey() => _readSafe(keyAnthropicApiKey);
  Future<void> setAnthropicApiKey(String? key) =>
      _writeSafe(keyAnthropicApiKey, key);

  Future<String?> getOpenAiApiKey() => _readSafe(keyOpenAiApiKey);
  Future<void> setOpenAiApiKey(String? key) => _writeSafe(keyOpenAiApiKey, key);

  Future<String?> getNotionToken() => _readSafe(keyNotionToken);
  Future<void> setNotionToken(String? token) =>
      _writeSafe(keyNotionToken, token);

  Future<String?> getMcpToken(String serverId) =>
      _readSafe(keyMcpToken(serverId));
  Future<void> setMcpToken(String serverId, String? token) =>
      _writeSafe(keyMcpToken(serverId), token);

  Future<void> deleteMcpToken(String serverId) async {
    final key = keyMcpToken(serverId);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    await _writeFallback(key, null);
  }

  Future<File?> _getFallbackFile() async {
    if (_customFallbackDir != null) {
      return File(p.join(_customFallbackDir.path, '.secure_vault.json'));
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, '.secure_vault.json'));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _readFallbackMap() async {
    try {
      final file = await _getFallbackFile();
      if (file == null || !file.existsSync()) return {};
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeFallback(String key, String? value) async {
    try {
      final file = await _getFallbackFile();
      if (file == null) return;
      final map = await _readFallbackMap();
      if (value == null || value.trim().isEmpty) {
        map.remove(key);
      } else {
        map[key] = value.trim();
      }
      if (!file.parent.existsSync()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(map), flush: true);
    } catch (e) {
      AppLogger.error('Fallback vault write failed for key "$key"', e);
    }
  }

  Future<String?> _readSafe(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null && val.isNotEmpty) {
        return val;
      }
    } catch (e) {
      AppLogger.warning(
        'SecretStore Keychain read unavailable for "$key", using fallback vault: $e',
      );
    }

    final fallbackMap = await _readFallbackMap();
    return fallbackMap[key];
  }

  Future<void> _writeSafe(String key, String? value) async {
    try {
      if (value == null || value.trim().isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value.trim());
      }
    } catch (e) {
      AppLogger.warning(
        'SecretStore Keychain write unavailable for "$key", saving to sandboxed fallback vault: $e',
      );
    }

    // Always mirror to sandboxed fallback vault
    await _writeFallback(key, value);
  }
}
