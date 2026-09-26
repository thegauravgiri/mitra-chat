import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/theme/color_schemes.dart';

double contrastRatio(Color a, Color b) {
  final lumA = a.computeLuminance();
  final lumB = b.computeLuminance();
  final lighter = math.max(lumA, lumB);
  final darker = math.min(lumA, lumB);
  return (lighter + 0.05) / (darker + 0.05);
}

void assertLightLadder(ColorScheme s) {
  final lowest = s.surfaceContainerLowest.computeLuminance();
  final surface = s.surface.computeLuminance();
  final low = s.surfaceContainerLow.computeLuminance();
  final normal = s.surfaceContainer.computeLuminance();
  final high = s.surfaceContainerHigh.computeLuminance();
  final highest = s.surfaceContainerHighest.computeLuminance();

  expect(lowest, greaterThanOrEqualTo(surface));
  expect(surface, greaterThanOrEqualTo(low));
  expect(low, greaterThanOrEqualTo(normal));
  expect(normal, greaterThanOrEqualTo(high));
  expect(high, greaterThanOrEqualTo(highest));
}

void assertDarkLadder(ColorScheme s) {
  final lowest = s.surfaceContainerLowest.computeLuminance();
  final surface = s.surface.computeLuminance();
  final low = s.surfaceContainerLow.computeLuminance();
  final normal = s.surfaceContainer.computeLuminance();
  final high = s.surfaceContainerHigh.computeLuminance();
  final highest = s.surfaceContainerHighest.computeLuminance();

  expect(lowest, lessThanOrEqualTo(surface));
  expect(surface, lessThanOrEqualTo(low));
  expect(low, lessThanOrEqualTo(normal));
  expect(normal, lessThanOrEqualTo(high));
  expect(high, lessThanOrEqualTo(highest));
}

void assertLightContrast(ColorScheme s) {
  final onSurfaceRatio = contrastRatio(s.onSurface, s.surface);
  final onSurfaceVariantRatio = contrastRatio(s.onSurfaceVariant, s.surface);
  final outlineRatio = contrastRatio(s.outline, s.surface);

  expect(onSurfaceRatio, greaterThanOrEqualTo(4.5), reason: 'onSurface contrast ratio');
  expect(onSurfaceVariantRatio, greaterThanOrEqualTo(4.5), reason: 'onSurfaceVariant contrast ratio');
  expect(outlineRatio, greaterThanOrEqualTo(3.0), reason: 'outline contrast ratio');
}

void assertDarkContrast(ColorScheme s) {
  final onSurfaceRatio = contrastRatio(s.onSurface, s.surface);
  final onSurfaceVariantRatio = contrastRatio(s.onSurfaceVariant, s.surface);
  final outlineRatio = contrastRatio(s.outline, s.surface);

  expect(onSurfaceRatio, greaterThanOrEqualTo(4.5), reason: 'onSurface contrast ratio');
  expect(onSurfaceVariantRatio, greaterThanOrEqualTo(4.5), reason: 'onSurfaceVariant contrast ratio');
  expect(outlineRatio, greaterThanOrEqualTo(3.0), reason: 'outline contrast ratio');
}

void main() {
  group('Brand theme contrast and surface ladder tests', () {
    test('Light theme surface ladder is monotonically decreasing in luminance', () {
      assertLightLadder(AppColorSchemes.light);
    });

    test('Dark theme surface ladder is monotonically increasing in luminance', () {
      assertDarkLadder(AppColorSchemes.dark);
    });

    test('Light theme contrast ratios meet WCAG requirements', () {
      assertLightContrast(AppColorSchemes.light);
    });

    test('Dark theme contrast ratios meet WCAG requirements', () {
      assertDarkContrast(AppColorSchemes.dark);
    });
  });

  group('Dynamic color harmonisation across fixture seeds', () {
    const fixtureSeeds = [
      Color(0xFF4361EE), // Brand Indigo
      Color(0xFF2E7D32), // Forest Green
      Color(0xFFD32F2F), // Crimson Red
      Color(0xFF7B1FA2), // Deep Purple
      Color(0xFFFF6F00), // Amber Orange
      Color(0xFF00838F), // Cyan / Teal
    ];

    for (final seed in fixtureSeeds) {
      test('Light harmonised seed 0x${seed.toARGB32().toRadixString(16)} satisfies ladder & contrast', () {
        final scheme = AppColorSchemes.harmonizedFromSeed(
          seed: seed,
          brightness: Brightness.light,
        );
        assertLightLadder(scheme);
        assertLightContrast(scheme);
      });

      test('Dark harmonised seed 0x${seed.toARGB32().toRadixString(16)} satisfies ladder & contrast', () {
        final scheme = AppColorSchemes.harmonizedFromSeed(
          seed: seed,
          brightness: Brightness.dark,
        );
        assertDarkLadder(scheme);
        assertDarkContrast(scheme);
      });
    }
  });
}
