import 'package:drift/drift.dart';
import '../../core/utils/id.dart';
import '../db/database.dart';
import '../stores/attachment_store.dart';

class ConversationRepository {
  ConversationRepository({
    required this.db,
    required this.attachmentStore,
  });

  final AppDatabase db;
  final AttachmentStore attachmentStore;

  static bool isDefaultTitle(String? title) {
    if (title == null) return true;
    final t = title.trim();
    return t.isEmpty ||
        t == 'New chat' ||
        t == 'New Conversation' ||
        t == 'Untitled' ||
        t.startsWith('Note:');
  }

  static String derivePreliminaryTitle(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) return 'New chat';
    final words = singleLine.split(' ');
    if (words.length <= 6 && singleLine.length <= 40) {
      return singleLine;
    }
    final truncated = words.take(6).join(' ');
    return truncated.length > 40 ? '${truncated.substring(0, 37)}...' : truncated;
  }

  Stream<List<Conversation>> watchConversations({String? search}) {
    return db.conversationDao.watchActiveConversations(query: search);
  }

  Future<List<Conversation>> getRecentConversations({int limit = 10}) {
    return db.conversationDao.getRecentConversations(limit: limit);
  }

  Future<Conversation?> getConversationById(String id) {
    return db.conversationDao.getConversationById(id);
  }

  Future<Conversation> createConversation({
    String? title,
    String? providerId,
    String? modelId,
  }) async {
    final id = generateId();
    final now = DateTime.now();
    final companion = ConversationsCompanion.insert(
      id: id,
      title: Value(title ?? 'New chat'),
      createdAt: now,
      updatedAt: now,
      providerId: Value(providerId),
      modelId: Value(modelId),
    );
    await db.conversationDao.insertConversation(companion);
    return (await db.conversationDao.getConversationById(id))!;
  }

  Future<void> updateTitle(String id, String title) {
    return db.conversationDao.updateTitle(id, title);
  }

  Future<void> renameConversation(String id, String title) {
    return db.conversationDao.updateTitle(id, title);
  }

  Future<void> setPinned(String id, bool pinned) {
    return db.conversationDao.togglePin(id, pinned);
  }

  Future<void> togglePin(String id, bool pinned) {
    return db.conversationDao.togglePin(id, pinned);
  }

  Future<void> setArchived(String id, bool archived) {
    return db.conversationDao.toggleArchive(id, archived);
  }

  Future<void> toggleArchive(String id, bool archived) {
    return db.conversationDao.toggleArchive(id, archived);
  }

  Future<void> setModelOverride(
      String id, String? providerId, String? modelId) {
    return db.conversationDao.setModelOverride(id, providerId, modelId);
  }

  Future<void> deleteConversation(String id) async {
    // Delete persisted image attachment files
    final attachments =
        await db.messageDao.getAttachmentsForConversation(id);
    for (final att in attachments) {
      await attachmentStore.deleteAttachment(
        att.relativePath,
        thumbRelativePath: att.thumbRelativePath,
      );
    }

    // Cascade delete in sqlite
    await db.conversationDao.deleteConversation(id);
  }
}
