import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(tables: [Conversations, Messages, Attachments, ToolInvocations])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.db);

  Stream<List<Conversation>> watchActiveConversations({String? query}) {
    final selectQuery = select(conversations)
      ..where((tbl) => tbl.archived.equals(false));

    if (query != null && query.trim().isNotEmpty) {
      final clean = '%${query.trim().toLowerCase()}%';
      selectQuery.where((tbl) => tbl.title.lower().like(clean));
    }

    selectQuery.orderBy([
      (tbl) => OrderingTerm(expression: tbl.pinned, mode: OrderingMode.desc),
      (tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc),
    ]);

    return selectQuery.watch();
  }

  Future<List<Conversation>> getRecentConversations({int limit = 10}) {
    final query = select(conversations)
      ..where((tbl) => tbl.archived.equals(false))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
      ..limit(limit);
    return query.get();
  }

  Future<Conversation?> getConversationById(String id) {
    return (select(conversations)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertConversation(ConversationsCompanion companion) {
    return into(conversations).insert(companion);
  }

  Future<bool> updateTitle(String id, String title) async {
    final count = await (update(conversations)..where((tbl) => tbl.id.equals(id)))
        .write(ConversationsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> touchConversation(String id) async {
    final count = await (update(conversations)..where((tbl) => tbl.id.equals(id)))
        .write(ConversationsCompanion(
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> togglePin(String id, bool pinned) async {
    final count = await (update(conversations)..where((tbl) => tbl.id.equals(id)))
        .write(ConversationsCompanion(
      pinned: Value(pinned),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> toggleArchive(String id, bool archived) async {
    final count = await (update(conversations)..where((tbl) => tbl.id.equals(id)))
        .write(ConversationsCompanion(
      archived: Value(archived),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> setModelOverride(String id, String? providerId, String? modelId) async {
    final count = await (update(conversations)..where((tbl) => tbl.id.equals(id)))
        .write(ConversationsCompanion(
      providerId: Value(providerId),
      modelId: Value(modelId),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<int> deleteConversation(String id) {
    return (delete(conversations)..where((tbl) => tbl.id.equals(id))).go();
  }
}
