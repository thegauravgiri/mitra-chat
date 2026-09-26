import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/domain/models/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Seeds default quick prompts on database creation', () async {
    final prompts = await db.quickPromptDao.getQuickPrompts();
    expect(prompts.length, equals(5));
    expect(prompts.first.label, equals('Create Notion Tasks'));
    expect(prompts.first.builtin, isTrue);
  });

  test('Conversation ordering respects pinned and updatedAt DESC', () async {
    final now = DateTime.now();

    await db.conversationDao.insertConversation(ConversationsCompanion.insert(
      id: 'c1',
      title: const Value('Convo 1'),
      createdAt: now,
      updatedAt: now.subtract(const Duration(minutes: 10)),
      pinned: const Value(false),
    ));

    await db.conversationDao.insertConversation(ConversationsCompanion.insert(
      id: 'c2',
      title: const Value('Convo 2'),
      createdAt: now,
      updatedAt: now.subtract(const Duration(minutes: 5)),
      pinned: const Value(false),
    ));

    await db.conversationDao.insertConversation(ConversationsCompanion.insert(
      id: 'c3',
      title: const Value('Convo 3 (Pinned)'),
      createdAt: now,
      updatedAt: now.subtract(const Duration(minutes: 20)),
      pinned: const Value(true),
    ));

    final list = await db.conversationDao.watchActiveConversations().first;
    expect(list.length, equals(3));
    // Pinned should be first
    expect(list[0].id, equals('c3'));
    // Then newest
    expect(list[1].id, equals('c2'));
    expect(list[2].id, equals('c1'));
  });

  test('Message sequence increments monotonically', () async {
    final now = DateTime.now();
    await db.conversationDao.insertConversation(ConversationsCompanion.insert(
      id: 'c1',
      title: const Value('Test Convo'),
      createdAt: now,
      updatedAt: now,
    ));

    final seq1 = await db.messageDao.getNextSeq('c1');
    expect(seq1, equals(1));

    await db.messageDao.insertMessage(MessagesCompanion.insert(
      id: 'm1',
      conversationId: 'c1',
      role: MessageRole.user,
      status: MessageStatus.complete,
      content: const Value('Hello'),
      seq: seq1,
      createdAt: now,
    ));

    final seq2 = await db.messageDao.getNextSeq('c1');
    expect(seq2, equals(2));

    await db.messageDao.insertMessage(MessagesCompanion.insert(
      id: 'm2',
      conversationId: 'c1',
      role: MessageRole.assistant,
      status: MessageStatus.complete,
      content: const Value('Hi there'),
      seq: seq2,
      createdAt: now,
    ));

    final seq3 = await db.messageDao.getNextSeq('c1');
    expect(seq3, equals(3));
  });

  test('Cascade delete removes messages, attachments, and tool invocations', () async {
    final now = DateTime.now();
    await db.conversationDao.insertConversation(ConversationsCompanion.insert(
      id: 'c1',
      title: const Value('Convo to delete'),
      createdAt: now,
      updatedAt: now,
    ));

    await db.messageDao.insertMessage(MessagesCompanion.insert(
      id: 'm1',
      conversationId: 'c1',
      role: MessageRole.user,
      status: MessageStatus.complete,
      content: const Value('Message with attachments'),
      seq: 1,
      createdAt: now,
    ));

    await db.messageDao.insertAttachment(AttachmentsCompanion.insert(
      id: 'a1',
      messageId: 'm1',
      relativePath: 'test.png',
      mimeType: 'image/png',
      byteSize: 1024,
    ));

    await db.toolDao.insertToolInvocation(ToolInvocationsCompanion.insert(
      id: 't1',
      messageId: 'm1',
      toolName: 'notion.create_tasks',
      source: ToolSource.builtin,
      argumentsJson: '{}',
      status: ToolStatus.ok,
      createdAt: now,
    ));

    // Verify presence before delete
    expect((await db.messageDao.getMessagesForConversation('c1')).length, equals(1));
    expect((await db.messageDao.getAttachmentsForMessage('m1')).length, equals(1));
    expect((await db.toolDao.getToolInvocationsForMessage('m1')).length, equals(1));

    // Delete conversation
    await db.conversationDao.deleteConversation('c1');

    // Verify cascade deletion
    expect((await db.messageDao.getMessagesForConversation('c1')).isEmpty, isTrue);
    expect((await db.messageDao.getAttachmentsForMessage('m1')).isEmpty, isTrue);
    expect((await db.toolDao.getToolInvocationsForMessage('m1')).isEmpty, isTrue);
  });
}
