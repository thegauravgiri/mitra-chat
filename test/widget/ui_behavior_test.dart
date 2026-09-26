import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/theme/app_theme.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/domain/models/enums.dart';
import 'package:mitra/features/chat/presentation/message_actions_sheet.dart';
import 'package:mitra/features/chat/presentation/message_bubble.dart';
import 'package:mitra/features/chat/presentation/message_composer.dart';
import 'package:mitra/features/conversations/presentation/conversation_list_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UI Behavioural Widget Tests (Plan §F3.9)', () {
    testWidgets('Search field: clear button appears when text is typed and clears on tap',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ConversationListPane(
                selectedConversationId: null,
                onSelectConversation: (_) {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear button should not be present initially
      expect(find.byTooltip('Clear search'), findsNothing);

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'test query');
      await tester.pumpAndSettle();

      // Clear button should now be visible
      expect(find.byTooltip('Clear search'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      // Clear button should disappear and text should be empty
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    });

    testWidgets('MessageComposer: Send button is disabled when text and attachments are empty',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      bool sendCalled = false;

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
                onSend: (text, atts) async {
                  sendCalled = true;
                },
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send button should have null onPressed when empty
      final sendButtonFinder = find.byType(FilledButton);
      expect(sendButtonFinder, findsOneWidget);
      final FilledButton initialButton = tester.widget(sendButtonFinder);
      expect(initialButton.onPressed, isNull);

      // Tapping send button should NOT trigger onSend
      await tester.tap(sendButtonFinder);
      await tester.pumpAndSettle();
      expect(sendCalled, isFalse);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello Mitra');
      await tester.pumpAndSettle();

      // Send button should now be enabled
      final FilledButton activeSendButton = tester.widget(sendButtonFinder);
      expect(activeSendButton.onPressed, isNotNull);

      // Tapping active send button should trigger onSend
      await tester.tap(sendButtonFinder);
      await tester.pumpAndSettle();
      expect(sendCalled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    });

    testWidgets(
        'MessageBubble: long-press opens MessageActionsSheet',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      final message = Message(
        id: 'msg-1',
        conversationId: 'convo-1',
        seq: 1,
        role: MessageRole.assistant,
        content: 'Here is the response from Mitra',
        status: MessageStatus.complete,
        createdAt: DateTime.now(),
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
              body: MessageBubble(
                message: message,
                toolInvocations: const [],
                onUndoTool: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press the message bubble
      await tester.longPress(find.text('Here is the response from Mitra'));
      await tester.pumpAndSettle();

      // MessageActionsSheet should now be open
      expect(find.byType(MessageActionsSheet), findsOneWidget);
      expect(find.text('Copy text'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await db.close();
    });
  });
}
