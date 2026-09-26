import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/data/repositories/conversation_repository.dart';
import 'package:mitra/data/repositories/message_repository.dart';
import 'package:mitra/data/stores/prefs_store.dart';
import 'package:mitra/data/stores/secret_store.dart';
import 'package:mitra/features/chat/application/chat_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late ConversationRepository conversationRepo;
  late MessageRepository messageRepo;
  late SecretStore secretStore;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefsStore.keyProviderId: 'gemini',
      PrefsStore.keyModelId: 'gemini-3.7-flash',
      PrefsStore.keyMcpBaseUrl: '',
    });
    prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());
    secretStore = SecretStore();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secretStore),
      ],
    );

    conversationRepo = container.read(conversationRepositoryProvider);
    messageRepo = container.read(messageRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ChatState copyWith', () {
    test('Preserves errorMessage unless clearError is true or new message is passed', () {
      const state1 = ChatState(isStreaming: false, inFlightText: '', errorMessage: 'An error occurred');
      
      // Unrelated copyWith without errorMessage preserves it
      final state2 = state1.copyWith(inFlightText: 'typing...');
      expect(state2.errorMessage, equals('An error occurred'));
      expect(state2.inFlightText, equals('typing...'));

      // Explicit clearError clears it
      final state3 = state2.copyWith(clearError: true);
      expect(state3.errorMessage, isNull);

      // Overriding errorMessage updates it
      final state4 = state1.copyWith(errorMessage: 'New error');
      expect(state4.errorMessage, equals('New error'));
    });
  });

  group('ChatController', () {
    test('When API key is missing, terminates run, sets error, and unlocks composer for next message', () async {
      final convo = await conversationRepo.createConversation(title: 'Chat 1');
      final controller = container.read(chatControllerProvider(convo.id).notifier);

      // Send first message without API key
      await controller.sendMessage(text: 'Hello');

      // Wait for stream to finish processing
      for (var i = 0; i < 50; i++) {
        await pumpEventQueue();
        if (!container.read(chatControllerProvider(convo.id)).isStreaming) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // State should not be stuck in streaming
      final stateAfterFirst = container.read(chatControllerProvider(convo.id));
      expect(stateAfterFirst.isStreaming, isFalse);
      expect(stateAfterFirst.errorMessage, contains('API Key is not configured'));

      // Second sendMessage must be accepted because isStreaming is false
      await controller.sendMessage(text: 'Second attempt');

      for (var i = 0; i < 50; i++) {
        await pumpEventQueue();
        if (!container.read(chatControllerProvider(convo.id)).isStreaming) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final stateAfterSecond = container.read(chatControllerProvider(convo.id));
      expect(stateAfterSecond.isStreaming, isFalse);

      final messages = await messageRepo.getMessages(convo.id);
      expect(messages.length, equals(4)); // 2 user msgs + 2 failed assistant msgs
    });

    test('cancelRun clears isStreaming and inFlightText immediately', () async {
      final convo = await conversationRepo.createConversation(title: 'Chat 2');
      final controller = container.read(chatControllerProvider(convo.id).notifier);

      controller.cancelRun();

      final state = container.read(chatControllerProvider(convo.id));
      expect(state.isStreaming, isFalse);
      expect(state.inFlightText, isEmpty);
    });

    test('sendMessage sets preliminary title immediately if conversation has default title', () async {
      final convo = await conversationRepo.createConversation(title: 'New chat');
      final controller = container.read(chatControllerProvider(convo.id).notifier);

      await controller.sendMessage(text: 'Extract action items from team sprint notes');

      for (var i = 0; i < 50; i++) {
        await pumpEventQueue();
        if (!container.read(chatControllerProvider(convo.id)).isStreaming) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final updated = await conversationRepo.getConversationById(convo.id);
      expect(updated?.title, equals('Extract action items from team sprint'));
    });
  });
}
