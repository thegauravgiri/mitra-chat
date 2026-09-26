import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mitra/data/stores/secret_store.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecretStore', () {
    test('Can store and retrieve secrets using in-memory mock storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecretStore(const FlutterSecureStorage());

      expect(await store.getGeminiApiKey(), isNull);

      await store.setGeminiApiKey('AIzaSyTest123');
      expect(await store.getGeminiApiKey(), equals('AIzaSyTest123'));

      await store.setAnthropicApiKey('sk-ant-test');
      expect(await store.getAnthropicApiKey(), equals('sk-ant-test'));

      await store.setOpenAiApiKey('sk-openai-test');
      expect(await store.getOpenAiApiKey(), equals('sk-openai-test'));

      await store.setNotionToken('secret_notion_test');
      expect(await store.getNotionToken(), equals('secret_notion_test'));

      await store.setMcpToken('mitra', 'mcp_token_test');
      expect(await store.getMcpToken('mitra'), equals('mcp_token_test'));

      // Test clearing key
      await store.setGeminiApiKey('');
      expect(await store.getGeminiApiKey(), isNull);
    });

    test('Falls back to sandboxed vault when Keychain throws -34018', () async {
      final mockStorage = MockFlutterSecureStorage();
      final tempDir = Directory.systemTemp.createTempSync('mitra_vault_test');

      // Simulate Keychain failure with code -34018
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).thenThrow(PlatformException(
        code: '-34018',
        message: "A required entitlement isn't present.",
      ));

      when(() => mockStorage.read(
            key: any(named: 'key'),
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).thenThrow(PlatformException(
        code: '-34018',
        message: "A required entitlement isn't present.",
      ));

      final store = SecretStore(mockStorage, tempDir);

      // Should write to fallback without throwing
      await store.setGeminiApiKey('AIzaSyFallbackKey456');

      // Should read from fallback vault
      final key = await store.getGeminiApiKey();
      expect(key, equals('AIzaSyFallbackKey456'));

      // Clean up
      tempDir.deleteSync(recursive: true);
    });
  });
}
