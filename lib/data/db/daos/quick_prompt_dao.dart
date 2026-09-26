import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'quick_prompt_dao.g.dart';

@DriftAccessor(tables: [QuickPrompts])
class QuickPromptDao extends DatabaseAccessor<AppDatabase>
    with _$QuickPromptDaoMixin {
  QuickPromptDao(super.db);

  Stream<List<QuickPrompt>> watchQuickPrompts() {
    return (select(quickPrompts)..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .watch();
  }

  Future<List<QuickPrompt>> getQuickPrompts() {
    return (select(quickPrompts)..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .get();
  }

  Future<int> insertQuickPrompt(QuickPromptsCompanion companion) {
    return into(quickPrompts).insert(companion);
  }

  Future<bool> updateQuickPrompt(String id, String label, String promptText) async {
    final count = await (update(quickPrompts)..where((tbl) => tbl.id.equals(id)))
        .write(QuickPromptsCompanion(
      label: Value(label),
      promptText: Value(promptText),
    ));
    return count > 0;
  }

  Future<int> deleteQuickPrompt(String id) {
    return (delete(quickPrompts)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> reorderPrompts(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(quickPrompts)..where((tbl) => tbl.id.equals(orderedIds[i])))
            .write(QuickPromptsCompanion(sortOrder: Value(i)));
      }
    });
  }
}
