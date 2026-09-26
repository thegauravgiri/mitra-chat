import 'package:drift/drift.dart';
import '../../../domain/models/enums.dart';
import '../database.dart';
import '../tables.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages, Attachments, Conversations])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  Stream<List<Message>> watchMessagesForConversation(String conversationId) {
    return (select(messages)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.seq)]))
        .watch();
  }

  Future<List<Message>> getMessagesForConversation(String conversationId) {
    return (select(messages)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.seq)]))
        .get();
  }

  Future<int> getNextSeq(String conversationId) async {
    final query = selectOnly(messages)
      ..addColumns([messages.seq.max()])
      ..where(messages.conversationId.equals(conversationId));
    final result = await query.map((row) => row.read(messages.seq.max())).getSingleOrNull();
    return (result ?? 0) + 1;
  }

  Future<int> insertMessage(MessagesCompanion companion) async {
    return into(messages).insert(companion);
  }

  Future<bool> updateMessageContentAndStatus(
    String id,
    String content,
    MessageStatus status, {
    String? errorMessage,
  }) async {
    final count = await (update(messages)..where((tbl) => tbl.id.equals(id)))
        .write(MessagesCompanion(
      content: Value(content),
      status: Value(status),
      errorMessage: Value(errorMessage),
    ));
    return count > 0;
  }

  Future<bool> updateMessageStatus(
    String id,
    MessageStatus status, {
    String? errorMessage,
  }) async {
    final count = await (update(messages)..where((tbl) => tbl.id.equals(id)))
        .write(MessagesCompanion(
      status: Value(status),
      errorMessage: Value(errorMessage),
    ));
    return count > 0;
  }

  Future<int> insertAttachment(AttachmentsCompanion companion) {
    return into(attachments).insert(companion);
  }

  Future<List<Attachment>> getAttachmentsForMessage(String messageId) {
    return (select(attachments)..where((tbl) => tbl.messageId.equals(messageId)))
        .get();
  }

  Stream<List<Attachment>> watchAttachmentsForMessage(String messageId) {
    return (select(attachments)..where((tbl) => tbl.messageId.equals(messageId)))
        .watch();
  }

  Future<List<Attachment>> getAttachmentsForConversation(
      String conversationId) async {
    final query = select(attachments).join([
      innerJoin(messages, messages.id.equalsExp(attachments.messageId)),
    ])..where(messages.conversationId.equals(conversationId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(attachments)).toList();
  }

  Future<void> cleanUpStaleStreamingMessages([String? conversationId]) async {
    final updateQuery = update(messages)
      ..where((tbl) => tbl.status.equals(MessageStatus.streaming.name));
    if (conversationId != null) {
      updateQuery.where((tbl) => tbl.conversationId.equals(conversationId));
    }
    await updateQuery.write(const MessagesCompanion(
      status: Value(MessageStatus.complete),
    ));
  }

  Future<Map<String, String>> getLastMessagePreviews(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return {};
    final query = select(messages)
      ..where((tbl) => tbl.conversationId.isIn(conversationIds))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.seq)]);
    final rows = await query.get();
    final result = <String, String>{};
    for (final row in rows) {
      result.putIfAbsent(row.conversationId, () => row.content);
    }
    return result;
  }

  Future<int> deleteMessage(String id) {
    return (delete(messages)..where((tbl) => tbl.id.equals(id))).go();
  }
}
