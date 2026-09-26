import 'package:drift/drift.dart';
import '../../../domain/models/enums.dart';
import '../database.dart';
import '../tables.dart';

part 'tool_dao.g.dart';

@DriftAccessor(tables: [ToolInvocations, Messages])
class ToolDao extends DatabaseAccessor<AppDatabase> with _$ToolDaoMixin {
  ToolDao(super.db);

  Stream<List<ToolInvocation>> watchToolInvocationsForMessage(String messageId) {
    return (select(toolInvocations)
          ..where((tbl) => tbl.messageId.equals(messageId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  Stream<List<ToolInvocation>> watchToolInvocationsForConversation(
      String conversationId) {
    final query = select(toolInvocations).join([
      innerJoin(messages, messages.id.equalsExp(toolInvocations.messageId)),
    ])
      ..where(messages.conversationId.equals(conversationId))
      ..orderBy([OrderingTerm.desc(toolInvocations.createdAt)]);

    return query.watch().map((rows) =>
        rows.map((row) => row.readTable(toolInvocations)).toList());
  }

  Future<List<ToolInvocation>> getToolInvocationsForMessage(String messageId) {
    return (select(toolInvocations)
          ..where((tbl) => tbl.messageId.equals(messageId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  Future<ToolInvocation?> getToolInvocationById(String id) {
    return (select(toolInvocations)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertToolInvocation(ToolInvocationsCompanion companion) {
    return into(toolInvocations).insert(companion);
  }

  Future<bool> updateToolResult({
    required String id,
    required ToolStatus status,
    String? resultJson,
    String? errorMessage,
    int? durationMs,
  }) async {
    final count = await (update(toolInvocations)..where((tbl) => tbl.id.equals(id)))
        .write(ToolInvocationsCompanion(
      status: Value(status),
      resultJson: Value(resultJson),
      errorMessage: Value(errorMessage),
      durationMs: durationMs != null ? Value(durationMs) : const Value.absent(),
    ));
    return count > 0;
  }

  Future<bool> markUndone(String id) async {
    final count = await (update(toolInvocations)..where((tbl) => tbl.id.equals(id)))
        .write(const ToolInvocationsCompanion(
      status: Value(ToolStatus.undone),
    ));
    return count > 0;
  }
}
