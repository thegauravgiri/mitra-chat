import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/theme/app_theme.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/domain/models/enums.dart';
import 'package:mitra/features/chat/presentation/message_composer.dart';
import 'package:mitra/features/chat/presentation/notion_task_card.dart';
import 'package:mitra/features/chat/presentation/tool_call_tile.dart';
import 'package:mitra/features/conversations/presentation/conversation_actions_sheet.dart';
import 'package:mitra/integrations/notion/notion_task_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

void main() {
  group('Widget Component Rendering Tests (Light & Dark)', () {
    late SharedPreferences prefs;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('ToolCallTile renders with tokens in light and dark mode',
        (WidgetTester tester) async {
      final sampleInvocation = ToolInvocation(
        id: 'inv_1',
        messageId: 'msg_1',
        toolName: 'notion.search_databases',
        source: ToolSource.builtin,
        argumentsJson: '{"query": "Tasks"}',
        resultJson: '{"databases": [{"id": "db_123", "title": "Tasks"}]}',
        status: ToolStatus.ok,
        durationMs: 240,
        createdAt: DateTime.now(),
      );

      // Light mode test
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ToolCallTile(
              invocation: sampleInvocation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('notion.search_databases (240ms)'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);

      // Dark mode test
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ToolCallTile(
              invocation: sampleInvocation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('notion.search_databases (240ms)'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('NotionTaskCard renders with tokens in light and dark mode',
        (WidgetTester tester) async {
      final sampleTask = NotionCreatedTaskResult(
        id: 'page_123',
        url: 'https://notion.so/page_123',
        title: 'Review Q3 roadmap',
        status: 'In Progress',
        dueDate: '2026-09-15',
        priority: 'High',
        tags: ['Planning', 'Mitra'],
        droppedConcepts: ['Reminder at 9am'],
      );

      // Light mode
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NotionTaskCard(task: sampleTask),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review Q3 roadmap'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('2026-09-15'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Unmapped: Reminder at 9am'), findsOneWidget);

      // Dark mode
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: NotionTaskCard(task: sampleTask),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review Q3 roadmap'), findsOneWidget);
      expect(find.text('Unmapped: Reminder at 9am'), findsOneWidget);
    });

    testWidgets('MessageComposer renders with tokens in light and dark mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: MessageComposer(
                isStreaming: false,
                onSend: (text, atts) async {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Dark mode
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MessageComposer(
                isStreaming: false,
                onSend: (text, atts) async {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('ConversationActionsSheet renders in light and dark mode',
        (WidgetTester tester) async {
      final convo = Conversation(
        id: 'c1',
        title: 'Project Roadmap',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pinned: false,
        archived: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ConversationActionsSheet.show(context,
                      conversation: convo),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Project Roadmap'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Pin to top'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete conversation'), findsOneWidget);
    });
  });
}
