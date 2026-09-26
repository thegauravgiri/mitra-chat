import 'package:drift/drift.dart';
import '../../core/utils/id.dart';
import '../../domain/models/enums.dart';
import '../db/database.dart';
import '../stores/attachment_store.dart';

class MessageRepository {
  MessageRepository({
    required this.db,
  });

  final AppDatabase db;

  Stream<List<Message>> watchMessages(String conversationId) {
    return db.messageDao.watchMessagesForConversation(conversationId);
  }

  Future<List<Message>> getMessages(String conversationId) {
    return db.messageDao.getMessagesForConversation(conversationId);
  }

  Future<Message> appendUserMessage({
    required String conversationId,
    required String text,
    List<StoredAttachmentInfo> attachments = const [],
  }) async {
    final now = DateTime.now();
    final messageId = generateId();
    final seq = await db.messageDao.getNextSeq(conversationId);

    final msgCompanion = MessagesCompanion.insert(
      id: messageId,
      conversationId: conversationId,
      role: MessageRole.user,
      status: MessageStatus.complete,
      content: Value(text),
      seq: seq,
      createdAt: now,
    );
    await db.messageDao.insertMessage(msgCompanion);

    for (final att in attachments) {
      final attCompanion = AttachmentsCompanion.insert(
        id: att.id,
        messageId: messageId,
        relativePath: att.relativePath,
        thumbRelativePath: Value(att.thumbRelativePath),
        mimeType: att.mimeType,
        byteSize: att.byteSize,
        width: Value(att.width),
        height: Value(att.height),
      );
      await db.messageDao.insertAttachment(attCompanion);
    }

    await db.conversationDao.touchConversation(conversationId);
    return (await db.messageDao.getMessagesForConversation(conversationId))
        .firstWhere((m) => m.id == messageId);
  }

  Future<Message> createPendingAssistantMessage(String conversationId) async {
    final now = DateTime.now();
    final messageId = generateId();
    final seq = await db.messageDao.getNextSeq(conversationId);

    final companion = MessagesCompanion.insert(
      id: messageId,
      conversationId: conversationId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      content: const Value(''),
      seq: seq,
      createdAt: now,
    );
    await db.messageDao.insertMessage(companion);
    await db.conversationDao.touchConversation(conversationId);
    return (await db.messageDao.getMessagesForConversation(conversationId))
        .firstWhere((m) => m.id == messageId);
  }

  Future<void> updateMessageStreaming(String messageId, String text) async {
    await db.messageDao.updateMessageContentAndStatus(
      messageId,
      text,
      MessageStatus.streaming,
    );
  }

  Future<void> completeAssistantMessage(String messageId, String finalText) async {
    await db.messageDao.updateMessageContentAndStatus(
      messageId,
      finalText,
      MessageStatus.complete,
    );
  }

  Future<void> failAssistantMessage(String messageId, String errorMessage) async {
    await db.messageDao.updateMessageStatus(
      messageId,
      MessageStatus.failed,
      errorMessage: errorMessage,
    );
  }

  Future<void> cleanUpStaleStreamingMessages([String? conversationId]) {
    return db.messageDao.cleanUpStaleStreamingMessages(conversationId);
  }

  Future<ToolInvocation> recordToolInvocation({
    required String messageId,
    required String toolName,
    required ToolSource source,
    String? serverId,
    required String argumentsJson,
  }) async {
    final id = generateId();
    final now = DateTime.now();
    final companion = ToolInvocationsCompanion.insert(
      id: id,
      messageId: messageId,
      toolName: toolName,
      source: source,
      serverId: Value(serverId),
      argumentsJson: argumentsJson,
      status: ToolStatus.running,
      createdAt: now,
    );
    await db.toolDao.insertToolInvocation(companion);
    return (await db.toolDao.getToolInvocationById(id))!;
  }

  Future<void> updateToolInvocationResult({
    required String invocationId,
    required ToolStatus status,
    String? resultJson,
    String? errorMessage,
    int? durationMs,
  }) async {
    await db.toolDao.updateToolResult(
      id: invocationId,
      status: status,
      resultJson: resultJson,
      errorMessage: errorMessage,
      durationMs: durationMs,
    );
  }

  Future<void> markToolUndone(String invocationId) async {
    await db.toolDao.markUndone(invocationId);
  }

  Stream<List<ToolInvocation>> watchToolInvocationsForConversation(
      String conversationId) {
    return db.toolDao.watchToolInvocationsForConversation(conversationId);
  }

  Stream<List<ToolInvocation>> watchToolInvocationsForMessage(String messageId) {
    return db.toolDao.watchToolInvocationsForMessage(messageId);
  }

  Future<List<ToolInvocation>> getToolInvocationsForMessage(String messageId) {
    return db.toolDao.getToolInvocationsForMessage(messageId);
  }

  Future<List<Attachment>> getAttachmentsForMessage(String messageId) {
    return db.messageDao.getAttachmentsForMessage(messageId);
  }

  Future<Map<String, String>> lastMessagePreviewFor(List<String> conversationIds) {
    return db.messageDao.getLastMessagePreviews(conversationIds);
  }
}
