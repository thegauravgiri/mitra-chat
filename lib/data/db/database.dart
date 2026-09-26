import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../domain/models/enums.dart';
import 'daos/conversation_dao.dart';
import 'daos/message_dao.dart';
import 'daos/quick_prompt_dao.dart';
import 'daos/tool_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Conversations, Messages, Attachments, ToolInvocations, QuickPrompts],
  daos: [ConversationDao, MessageDao, ToolDao, QuickPromptDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'mitra_db'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultQuickPrompts();
        },
      );

  Future<void> _seedDefaultQuickPrompts() async {
    final defaults = [
      QuickPromptsCompanion.insert(
        id: 'default-create-notion-tasks',
        label: 'Create Notion Tasks',
        promptText:
            'Extract all tasks, action items, and todos from the handwritten notes/image and create them in the Notion database.',
        sortOrder: 0,
        builtin: const Value(true),
      ),
      QuickPromptsCompanion.insert(
        id: 'default-extract-todos',
        label: 'Extract Action Items',
        promptText:
            'Extract all action items, decisions, and notes from this image with clear assignees, dates, and priorities.',
        sortOrder: 1,
        builtin: const Value(true),
      ),
      QuickPromptsCompanion.insert(
        id: 'default-create-pbi',
        label: 'Create Azure DevOps PBI',
        promptText:
            'Extract user stories and tasks from this note and create Azure DevOps PBIs with acceptance criteria.',
        sortOrder: 2,
        builtin: const Value(true),
      ),
      QuickPromptsCompanion.insert(
        id: 'default-log-time',
        label: 'Log Time',
        promptText:
            'Analyze the notes and completed activities described in this image and log the corresponding time entries.',
        sortOrder: 3,
        builtin: const Value(true),
      ),
      QuickPromptsCompanion.insert(
        id: 'default-plan-day',
        label: 'Plan My Day',
        promptText:
            'Summarize my priorities and schedule a structured plan for the day based on these notes.',
        sortOrder: 4,
        builtin: const Value(true),
      ),
    ];

    for (final prompt in defaults) {
      await into(quickPrompts).insert(prompt, mode: InsertMode.insertOrIgnore);
    }
  }
}
