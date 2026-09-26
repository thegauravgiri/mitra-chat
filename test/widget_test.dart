import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/adaptive_shell.dart';
import 'package:mitra/app/app.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Mitra app boots without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    // Use compact size so ConversationListPane is rendered on root
    tester.view.physicalSize = const Size(500, 800);
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

    expect(find.byType(AdaptiveShell), findsOneWidget);
    expect(find.text('Mitra'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
  });
}
