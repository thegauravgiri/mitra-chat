import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/app.dart';
import 'package:mitra/app/nav/destinations.dart';
import 'package:mitra/app/nav/navigation_scaffold.dart';
import 'package:mitra/core/utils/breakpoints.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:mitra/features/chat/presentation/chat_screen.dart';
import 'package:mitra/features/conversations/presentation/conversation_list_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MitraNavigationScaffold renders NavigationBar on compact',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MitraNavigationScaffold(
          sizeClass: WindowSizeClass.compact,
          destinations: MitraDestination.all,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('Body Content'),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body Content'), findsOneWidget);
  });

  testWidgets(
      'MitraNavigationScaffold renders collapsed NavigationRail on medium and expanded',
      (WidgetTester tester) async {
    for (final size in [WindowSizeClass.medium, WindowSizeClass.expanded]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MitraNavigationScaffold(
            sizeClass: size,
            destinations: MitraDestination.all,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            body: const Text('Body Content'),
          ),
        ),
      );

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      final NavigationRail rail = tester.widget(railFinder);
      expect(rail.extended, isFalse);
    }
  });

  testWidgets(
      'MitraNavigationScaffold renders extended NavigationRail on large and extraLarge',
      (WidgetTester tester) async {
    for (final size in [WindowSizeClass.large, WindowSizeClass.extraLarge]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MitraNavigationScaffold(
            sizeClass: size,
            destinations: MitraDestination.all,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            body: const Text('Body Content'),
          ),
        ),
      );

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      final NavigationRail rail = tester.widget(railFinder);
      expect(rail.extended, isTrue);
    }
  });

  testWidgets(
      'Navigating to /chats/:id and popping returns to /chats without exiting app',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    // Create a mock conversation in DB
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: 'convo-test-1',
            title: const Value('Test Conversation 1'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MitraApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify on /chats with ConversationListPane
    expect(find.byType(ConversationListPane), findsOneWidget);
    expect(find.text('Test Conversation 1'), findsOneWidget);

    // Tap on the conversation to navigate to /chats/convo-test-1
    await tester.tap(find.text('Test Conversation 1'));
    await tester.pumpAndSettle();

    // Verify now on ChatScreen
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(ConversationListPane), findsNothing);

    // Simulate platform back action (handlePopRoute)
    final popHandled = await tester.binding.handlePopRoute();
    expect(popHandled, isTrue);
    await tester.pumpAndSettle();

    // Verify back on /chats and app is not popped
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(ConversationListPane), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });
}
