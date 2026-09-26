import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/adaptive_shell.dart';
import 'package:mitra/app/theme/app_theme.dart';
import 'package:mitra/app/theme/tokens.dart';
import 'package:mitra/core/utils/breakpoints.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/features/conversations/presentation/conversation_list_pane.dart';
import 'package:mitra/features/inspector/presentation/tool_inspector_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

void main() {
  test('WindowSizeClass breakpoint tests', () {
    expect(WindowSizeClass.fromWidth(500), equals(WindowSizeClass.compact));
    expect(WindowSizeClass.fromWidth(800), equals(WindowSizeClass.medium));
    expect(WindowSizeClass.fromWidth(1000), equals(WindowSizeClass.expanded));
    expect(WindowSizeClass.fromWidth(1400), equals(WindowSizeClass.large));
    expect(WindowSizeClass.fromWidth(1800), equals(WindowSizeClass.extraLarge));

    expect(WindowSizeClass.compact.showsListPane, isFalse);
    expect(WindowSizeClass.medium.showsListPane, isTrue);
    expect(WindowSizeClass.expanded.showsListPane, isTrue);
    expect(WindowSizeClass.large.showsListPane, isTrue);
    expect(WindowSizeClass.extraLarge.showsListPane, isTrue);

    expect(WindowSizeClass.compact.showsInspectorPane, isFalse);
    expect(WindowSizeClass.medium.showsInspectorPane, isFalse);
    expect(WindowSizeClass.expanded.showsInspectorPane, isFalse);
    expect(WindowSizeClass.large.showsInspectorPane, isTrue);
    expect(WindowSizeClass.extraLarge.showsInspectorPane, isTrue);
  });

  testWidgets('AdaptiveShell renders responsive layout per window size',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    // 1. Compact (500px width) -> 1 pane
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.byType(ToolInspectorPane), findsNothing);

    // 2. Medium (800px width) -> Single Sidebar + Center Pane
    tester.view.physicalSize = const Size(800, 800);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('New conversation'), findsOneWidget);

    // 3. Expanded/Large (1400px width) -> Single Sidebar + Center Pane
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('New conversation'), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });

  testWidgets(
      'AdaptiveShell renders single pane on phone landscape (844x390)',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In phone landscape, renders full single sidebar (ConversationListPane)
    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('New conversation'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });

  testWidgets('AdaptiveShell injects MitraSpacing matching size class density',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    double? compactLg;
    double? largeLg;

    // 400px shell
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => AdaptiveShell(
              // Helper to read context space
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final compactContext = tester.element(find.byType(ConversationListPane));
    compactLg = compactContext.space.lg;

    // 1400px shell
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final largeContext = tester.element(find.byType(ConversationListPane));
    largeLg = largeContext.space.lg;

    expect(compactLg, isNotNull);
    expect(largeLg, isNotNull);
    // Compact uses comfortable density (x1.15), large uses compact density (x0.85)
    expect(compactLg, isNot(equals(largeLg)));
    expect(compactLg, greaterThan(largeLg));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });
}
