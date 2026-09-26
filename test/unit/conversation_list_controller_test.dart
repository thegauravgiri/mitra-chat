import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/data/repositories/conversation_repository.dart';
import 'package:mitra/data/repositories/message_repository.dart';
import 'package:mitra/features/conversations/application/conversation_list_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late ConversationRepository conversationRepo;
  late MessageRepository messageRepo;
  late ConversationListController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );

    conversationRepo = container.read(conversationRepositoryProvider);
    messageRepo = container.read(messageRepositoryProvider);
    controller = container.read(conversationListControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('Calling createNewConversation when already in an empty conversation reuses it', () async {
    // 1. Create first new conversation
    final convo1 = await controller.createNewConversation();
    expect(container.read(activeConversationIdProvider), equals(convo1.id));

    // 2. Calling createNewConversation again while convo1 is empty (0 messages)
    final convo2 = await controller.createNewConversation();
    expect(convo2.id, equals(convo1.id));

    final allConvos = await conversationRepo.getRecentConversations(limit: 10);
    expect(allConvos.length, equals(1));

    // 3. Append a user message to convo1
    await messageRepo.appendUserMessage(
      conversationId: convo1.id,
      text: 'Hello Mitra!',
    );

    // 4. Now calling createNewConversation should create a new conversation
    final convo3 = await controller.createNewConversation();
    expect(convo3.id, isNot(equals(convo1.id)));
    expect(container.read(activeConversationIdProvider), equals(convo3.id));

    final updatedAllConvos = await conversationRepo.getRecentConversations(limit: 10);
    expect(updatedAllConvos.length, equals(2));
  });
}
