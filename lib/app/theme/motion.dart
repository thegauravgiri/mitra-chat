import 'package:flutter/material.dart';

class MitraMotion {
  MitraMotion._();

  // Durations
  static const Duration fast = Duration(milliseconds: 120); // hover, press, chip
  static const Duration standard = Duration(milliseconds: 220); // pane swap, expand
  static const Duration slow = Duration(milliseconds: 380); // route, sheet

  // M3 Durations aliases
  static const Duration short4 = Duration(milliseconds: 200);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration long2 = Duration(milliseconds: 500);

  // Curves
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standardCurve = Curves.easeOut;
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// Honour the OS "reduce motion" setting. Every animated widget in the app
  /// takes its duration from here, never from a literal.
  static Duration of(BuildContext c, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(c) == true ? Duration.zero : d;
}
