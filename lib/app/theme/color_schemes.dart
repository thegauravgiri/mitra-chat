import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

class AppColorSchemes {
  AppColorSchemes._();

  /// The exact blue from the Mitra mark/app icon. `ColorScheme.fromSeed`
  /// alone desaturates this into a muted grey-blue (~#515b92) for its
  /// algorithmic `primary` tone, which reads as noticeably duller than the
  /// logo -- so primary (and the container tones built from it) are pinned
  /// to this hue explicitly below instead of left to the seed algorithm.
  static const Color brandSeed = Color(0xFF4361EE); // Mitra Blue

  // Light theme: the brand blue used as-is (5.0:1 against white -- passes
  // AA for text/icons), with a pale tint/deep tint pair for containers.
  static const Color _primaryLight = brandSeed;
  static const Color _onPrimaryLight = Color(0xFFFFFFFF);
  static const Color _primaryContainerLight = Color(0xFFE5E9FD);
  static const Color _onPrimaryContainerLight = Color(0xFF2A3C94);

  // Dark theme: a lightened tint of the same blue for primary (5.8:1
  // against the dark surface -- the raw brand blue only manages ~3.8:1,
  // too low for body text/labels), with matching container tones.
  static const Color _primaryDark = Color(0xFF7288F2);
  static const Color _onPrimaryDark = Color(0xFF0B1120);
  static const Color _primaryContainerDark = Color(0xFF1F2D68);
  static const Color _onPrimaryContainerDark = Color(0xFFD0D8FB);

  static final ColorScheme light =
      ColorScheme.fromSeed(
        seedColor: brandSeed,
        brightness: Brightness.light,
      ).copyWith(
        primary: _primaryLight,
        onPrimary: _onPrimaryLight,
        primaryContainer: _primaryContainerLight,
        onPrimaryContainer: _onPrimaryContainerLight,
        // Only used app-wide for the selected-item highlight in nav lists; keep
        // it in the same brand-blue family instead of the algorithmic grey.
        secondaryContainer: _primaryContainerLight,
        onSecondaryContainer: _onPrimaryContainerLight,
        surface: const Color(0xFFFBFCFD),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF6F8FA),
        surfaceContainer: const Color(0xFFF0F3F7),
        surfaceContainerHigh: const Color(0xFFE8EDF3),
        surfaceContainerHighest: const Color(0xFFE1E7EF),
        onSurface: const Color(0xFF101828),
        onSurfaceVariant: const Color(0xFF4A5568),
        outline: const Color(0xFF78889B),
        outlineVariant: const Color(0xFFDCE3EB),
      );

  static final ColorScheme dark =
      ColorScheme.fromSeed(
        seedColor: brandSeed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _primaryDark,
        onPrimary: _onPrimaryDark,
        primaryContainer: _primaryContainerDark,
        onPrimaryContainer: _onPrimaryContainerDark,
        secondaryContainer: _primaryContainerDark,
        onSecondaryContainer: _onPrimaryContainerDark,
        surface: const Color(0xFF0B1120),
        surfaceContainerLowest: const Color(0xFF070C17),
        surfaceContainerLow: const Color(0xFF111A2E),
        surfaceContainer: const Color(0xFF16223A),
        surfaceContainerHigh: const Color(0xFF1D2B47),
        surfaceContainerHighest: const Color(0xFF243554),
        onSurface: const Color(0xFFF8FAFC),
        onSurfaceVariant: const Color(0xFFA3B0C2),
        outline: const Color(0xFF5B6E8C),
        outlineVariant: const Color(0xFF26334D),
      );

  static ColorScheme dynamicLight(ColorScheme? dynamicScheme) {
    if (dynamicScheme == null) return light;
    return dynamicScheme.harmonized();
  }

  static ColorScheme dynamicDark(ColorScheme? dynamicScheme) {
    if (dynamicScheme == null) return dark;
    return dynamicScheme.harmonized();
  }

  static ColorScheme harmonizedFromSeed({
    required Color seed,
    required Brightness brightness,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return scheme.harmonized();
  }
}
