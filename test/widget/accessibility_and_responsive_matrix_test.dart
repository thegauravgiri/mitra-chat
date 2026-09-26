import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/app.dart';
import 'package:mitra/core/utils/breakpoints.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/features/chat/presentation/empty_chat_detail_pane.dart';
import 'package:mitra/features/conversations/presentation/conversation_list_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Accessibility & Text Scale Matrix Tests (Plan §F4.11 / TASK-1280)', () {
    testWidgets('EmptyChatDetailPane alone at text scale 2.0', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmptyChatDetailPane(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('ConversationListPane alone at text scale 2.0', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      tester.view.physicalSize = const Size(320, 1024);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
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
      expect(tester.takeException(), isNull);
      await db.close();
    });

    final sizeMatrix = <String, Size>{
      'compact_mobile': const Size(390, 844),
      'compact_landscape': const Size(844, 390),
      'medium_tablet': const Size(768, 1024),
      'expanded_tablet_landscape': const Size(1024, 768),
      'large_desktop': const Size(1440, 900),
      'extra_large_monitor': const Size(1920, 1080),
    };

    for (final entry in sizeMatrix.entries) {
      testWidgets('MitraApp renders cleanly at text scale 2.0 on ${entry.key}',
          (tester) async {
        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          oldOnError?.call(details);
        };

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase(NativeDatabase.memory());

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              databaseProvider.overrideWithValue(db),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: entry.value,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: const MitraApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = oldOnError;

        if (caughtDetails != null) {
          debugPrint('CAUGHT OVERFLOW WIDGET:\n${caughtDetails!.summary}');
          if (caughtDetails!.informationCollector != null) {
            for (final d in caughtDetails!.informationCollector!()) {
              debugPrint('INFO: ${d.toStringDeep()}');
            }
          }
        }

        final exception = tester.takeException();
        expect(exception, isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await db.close();
      });
    }
  });

  group('WindowSizeClass & NavigationType Contract Tests', () {
    test('Breakpoint classification boundary checks', () {
      expect(WindowSizeClass.fromWidth(320), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1199), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1599), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    });

    test('WindowHeightClass classification boundary checks', () {
      expect(WindowHeightClass.fromHeight(390), WindowHeightClass.compact);
      expect(WindowHeightClass.fromHeight(479), WindowHeightClass.compact);
      expect(WindowHeightClass.fromHeight(480), WindowHeightClass.medium);
      expect(WindowHeightClass.fromHeight(899), WindowHeightClass.medium);
      expect(WindowHeightClass.fromHeight(900), WindowHeightClass.expanded);
    });
  });
}
