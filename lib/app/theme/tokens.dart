import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum MitraDensity {
  comfortable,
  standard,
  compact,
}

@immutable
class MitraSpacing extends ThemeExtension<MitraSpacing> {
  // 4pt base grid
  final double xs; // 4
  final double sm; // 8
  final double md; // 12
  final double lg; // 16
  final double xl; // 24
  final double xxl; // 32

  // Radii
  final double radiusXs; // 4 - micro tags
  final double radiusSm; // 8 - pills, chips, inline code
  final double radiusMd; // 12 - cards, tiles, fields
  final double radiusLg; // 16 - bubbles, sheets
  final double radiusXl; // 28 - dock, large sheets
  final double radiusFull; // 999 - composer field, avatars

  // Layout constants
  final double listPaneMin; // 240
  final double listPaneDefault; // 280
  final double listPaneMax; // 420
  final double inspectorWidth; // 360
  final double readingMeasureMax; // 720 - max text column width
  final double minTapTarget; // 48 / 40

  const MitraSpacing({
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 12.0,
    this.lg = 16.0,
    this.xl = 24.0,
    this.xxl = 32.0,
    this.radiusXs = 4.0,
    this.radiusSm = 8.0,
    this.radiusMd = 12.0,
    this.radiusLg = 16.0,
    this.radiusXl = 28.0,
    this.radiusFull = 999.0,
    this.listPaneMin = 240.0,
    this.listPaneDefault = 280.0,
    this.listPaneMax = 420.0,
    this.inspectorWidth = 360.0,
    this.readingMeasureMax = 720.0,
    this.minTapTarget = 48.0,
  });

  static const MitraSpacing standard = MitraSpacing();

  static MitraSpacing forDensity(MitraDensity density) => switch (density) {
        MitraDensity.comfortable => const MitraSpacing(
            xs: 4.0,
            sm: 8.0,
            md: 12.0 * 1.15,
            lg: 16.0 * 1.15,
            xl: 24.0 * 1.15,
            xxl: 32.0 * 1.15,
            minTapTarget: 48.0,
          ),
        MitraDensity.standard => const MitraSpacing(
            minTapTarget: 48.0,
          ),
        MitraDensity.compact => const MitraSpacing(
            xs: 4.0,
            sm: 8.0,
            md: 12.0 * 0.85,
            lg: 16.0 * 0.85,
            xl: 24.0 * 0.85,
            xxl: 32.0 * 0.85,
            minTapTarget: 40.0,
          ),
      };

  @override
  MitraSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    double? listPaneMin,
    double? listPaneDefault,
    double? listPaneMax,
    double? inspectorWidth,
    double? readingMeasureMax,
    double? minTapTarget,
  }) {
    return MitraSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      listPaneMin: listPaneMin ?? this.listPaneMin,
      listPaneDefault: listPaneDefault ?? this.listPaneDefault,
      listPaneMax: listPaneMax ?? this.listPaneMax,
      inspectorWidth: inspectorWidth ?? this.inspectorWidth,
      readingMeasureMax: readingMeasureMax ?? this.readingMeasureMax,
      minTapTarget: minTapTarget ?? this.minTapTarget,
    );
  }

  @override
  MitraSpacing lerp(ThemeExtension<MitraSpacing>? other, double t) {
    if (other is! MitraSpacing) return this;
    if (t == 0.0) return this;
    if (t == 1.0) return other;
    return MitraSpacing(
      xs: ui.lerpDouble(xs, other.xs, t) ?? xs,
      sm: ui.lerpDouble(sm, other.sm, t) ?? sm,
      md: ui.lerpDouble(md, other.md, t) ?? md,
      lg: ui.lerpDouble(lg, other.lg, t) ?? lg,
      xl: ui.lerpDouble(xl, other.xl, t) ?? xl,
      xxl: ui.lerpDouble(xxl, other.xxl, t) ?? xxl,
      radiusXs: ui.lerpDouble(radiusXs, other.radiusXs, t) ?? radiusXs,
      radiusSm: ui.lerpDouble(radiusSm, other.radiusSm, t) ?? radiusSm,
      radiusMd: ui.lerpDouble(radiusMd, other.radiusMd, t) ?? radiusMd,
      radiusLg: ui.lerpDouble(radiusLg, other.radiusLg, t) ?? radiusLg,
      radiusXl: ui.lerpDouble(radiusXl, other.radiusXl, t) ?? radiusXl,
      radiusFull: ui.lerpDouble(radiusFull, other.radiusFull, t) ?? radiusFull,
      listPaneMin: ui.lerpDouble(listPaneMin, other.listPaneMin, t) ?? listPaneMin,
      listPaneDefault: ui.lerpDouble(listPaneDefault, other.listPaneDefault, t) ?? listPaneDefault,
      listPaneMax: ui.lerpDouble(listPaneMax, other.listPaneMax, t) ?? listPaneMax,
      inspectorWidth: ui.lerpDouble(inspectorWidth, other.inspectorWidth, t) ?? inspectorWidth,
      readingMeasureMax: ui.lerpDouble(readingMeasureMax, other.readingMeasureMax, t) ?? readingMeasureMax,
      minTapTarget: ui.lerpDouble(minTapTarget, other.minTapTarget, t) ?? minTapTarget,
    );
  }
}

@immutable
class MitraStatusColor {
  final Color color;
  final Color container;
  final Color onContainer;

  const MitraStatusColor({
    required this.color,
    required this.container,
    required this.onContainer,
  });

  MitraStatusColor copyWith({
    Color? color,
    Color? container,
    Color? onContainer,
  }) {
    return MitraStatusColor(
      color: color ?? this.color,
      container: container ?? this.container,
      onContainer: onContainer ?? this.onContainer,
    );
  }

  static MitraStatusColor lerp(MitraStatusColor a, MitraStatusColor b, double t) {
    if (t == 0.0) return a;
    if (t == 1.0) return b;
    return MitraStatusColor(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      container: Color.lerp(a.container, b.container, t) ?? a.container,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t) ?? a.onContainer,
    );
  }
}

@immutable
class MitraStatusColors extends ThemeExtension<MitraStatusColors> {
  final MitraStatusColor success; // tool ok, task created
  final MitraStatusColor warning; // pending, unmapped concepts
  final MitraStatusColor danger; // failed (also the Delete button)
  final MitraStatusColor info; // running, streaming
  final MitraStatusColor neutral; // undone, archived

  const MitraStatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  static const MitraStatusColors light = MitraStatusColors(
    success: MitraStatusColor(
      color: Color(0xFF16A34A),
      container: Color(0xFFDCFCE7),
      onContainer: Color(0xFF14532D),
    ),
    warning: MitraStatusColor(
      color: Color(0xFFD97706),
      container: Color(0xFFFEF3C7),
      onContainer: Color(0xFF78350F),
    ),
    danger: MitraStatusColor(
      color: Color(0xFFDC2626),
      container: Color(0xFFFEE2E2),
      onContainer: Color(0xFF7F1D1D),
    ),
    info: MitraStatusColor(
      color: Color(0xFF2563EB),
      container: Color(0xFFDBEAFE),
      onContainer: Color(0xFF1E3A8A),
    ),
    neutral: MitraStatusColor(
      color: Color(0xFF64748B),
      container: Color(0xFFF1F5F9),
      onContainer: Color(0xFF1E293B),
    ),
  );

  static const MitraStatusColors dark = MitraStatusColors(
    success: MitraStatusColor(
      color: Color(0xFF4ADE80),
      container: Color(0xFF052E16),
      onContainer: Color(0xFFBBF7D0),
    ),
    warning: MitraStatusColor(
      color: Color(0xFFFBBF24),
      container: Color(0xFF451A03),
      onContainer: Color(0xFFFDE68A),
    ),
    danger: MitraStatusColor(
      color: Color(0xFFF87171),
      container: Color(0xFF450A0A),
      onContainer: Color(0xFFFECACA),
    ),
    info: MitraStatusColor(
      color: Color(0xFF60A5FA),
      container: Color(0xFF172554),
      onContainer: Color(0xFFBFDBFE),
    ),
    neutral: MitraStatusColor(
      color: Color(0xFF94A3B8),
      container: Color(0xFF1E293B),
      onContainer: Color(0xFFE2E8F0),
    ),
  );

  @override
  MitraStatusColors copyWith({
    MitraStatusColor? success,
    MitraStatusColor? warning,
    MitraStatusColor? danger,
    MitraStatusColor? info,
    MitraStatusColor? neutral,
  }) {
    return MitraStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  MitraStatusColors lerp(ThemeExtension<MitraStatusColors>? other, double t) {
    if (other is! MitraStatusColors) return this;
    if (t == 0.0) return this;
    if (t == 1.0) return other;
    return MitraStatusColors(
      success: MitraStatusColor.lerp(success, other.success, t),
      warning: MitraStatusColor.lerp(warning, other.warning, t),
      danger: MitraStatusColor.lerp(danger, other.danger, t),
      info: MitraStatusColor.lerp(info, other.info, t),
      neutral: MitraStatusColor.lerp(neutral, other.neutral, t),
    );
  }
}

extension MitraTheme on BuildContext {
  MitraSpacing get space => Theme.of(this).extension<MitraSpacing>() ?? MitraSpacing.standard;
  MitraStatusColors get status => Theme.of(this).extension<MitraStatusColors>() ?? MitraStatusColors.light;
}
