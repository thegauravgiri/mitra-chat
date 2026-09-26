import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/theme/app_theme.dart';
import 'package:mitra/core/ui/mitra_icon_button.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/features/chat/presentation/message_composer.dart';
import 'package:mitra/features/conversations/presentation/conversation_list_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

void main() {
  group('Tap Target & Semantics Audit (Plan §F3.7 / TASK-1160)', () {
    testWidgets('MitraIconButton enforces minimum tap target and required Semantics',
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
              body: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: ConversationListPane(
                      selectedConversationId: null,
                      onSelectConversation: (_) {},
                      onOpenSettings: () {},
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: MessageComposer(
                        isStreaming: false,
                        onSend: (text, atts) async {},
                        onCancel: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconButtons = tester.widgetList<MitraIconButton>(find.byType(MitraIconButton));
      expect(iconButtons, isNotEmpty);

      for (final btn in iconButtons) {
        expect(btn.semanticLabel, isNotEmpty, reason: 'Semantic label must not be empty');
      }

      // Check rendered RenderBox sizes for all MitraIconButton widgets
      final elements = find.byType(MitraIconButton).evaluate();
      for (final el in elements) {
        final renderBox = el.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          expect(
            renderBox.size.width,
            greaterThanOrEqualTo(32.0),
            reason: 'Interactive target width must be >= 32 (standard 48)',
          );
          expect(
            renderBox.size.height,
            greaterThanOrEqualTo(32.0),
            reason: 'Interactive target height must be >= 32 (standard 48)',
          );
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
    });
  });
}
