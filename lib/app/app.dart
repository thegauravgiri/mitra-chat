import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/application/settings_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/color_schemes.dart';
import 'theme/tokens.dart';

class MitraApp extends ConsumerWidget {
  const MitraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.valueOrNull;
    final themeModeStr = settings?.themeMode ?? 'system';
    final useDynamicColor = settings?.useDynamicColor ?? false;

    final themeMode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (useDynamicColor && lightDynamic != null) {
          lightTheme = AppTheme.themeFromScheme(
            AppColorSchemes.dynamicLight(lightDynamic),
            MitraStatusColors.light,
          );
          darkTheme = AppTheme.themeFromScheme(
            AppColorSchemes.dynamicDark(darkDynamic),
            MitraStatusColors.dark,
          );
        } else {
          lightTheme = AppTheme.lightTheme;
          darkTheme = AppTheme.darkTheme;
        }

        return MaterialApp.router(
          title: 'Mitra Chat',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: appRouter,
          builder: (context, child) {
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.85,
              maxScaleFactor: 2.0,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
