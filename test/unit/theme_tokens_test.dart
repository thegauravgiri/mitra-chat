import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/app/theme/tokens.dart';

void main() {
  group('MitraSpacing lerp identity', () {
    test('lerp at t=0 returns this and t=1 returns other', () {
      const a = MitraSpacing.standard;
      final b = a.copyWith(
        xs: 10,
        sm: 20,
        radiusXs: 6,
        radiusMd: 30,
        radiusXl: 36,
      );

      final at0 = a.lerp(b, 0.0);
      expect(at0.xs, equals(a.xs));
      expect(at0.sm, equals(a.sm));
      expect(at0.radiusXs, equals(a.radiusXs));
      expect(at0.radiusMd, equals(a.radiusMd));
      expect(at0.radiusXl, equals(a.radiusXl));

      final at1 = a.lerp(b, 1.0);
      expect(at1.xs, equals(b.xs));
      expect(at1.sm, equals(b.sm));
      expect(at1.radiusXs, equals(b.radiusXs));
      expect(at1.radiusMd, equals(b.radiusMd));
      expect(at1.radiusXl, equals(b.radiusXl));
    });

    test('lerp midway interpolates values', () {
      const a = MitraSpacing(xs: 0, sm: 10, radiusXs: 2, radiusXl: 20);
      const b = MitraSpacing(xs: 10, sm: 30, radiusXs: 6, radiusXl: 40);

      final atMid = a.lerp(b, 0.5);
      expect(atMid.xs, equals(5.0));
      expect(atMid.sm, equals(20.0));
      expect(atMid.radiusXs, equals(4.0));
      expect(atMid.radiusXl, equals(30.0));
    });

    test('lerp identity holds for each density', () {
      for (final density in MitraDensity.values) {
        final space = MitraSpacing.forDensity(density);
        final other = space.copyWith(
          xs: 12,
          radiusXs: 10,
          radiusXl: 32,
        );

        final at0 = space.lerp(other, 0.0);
        expect(at0.md, equals(space.md));
        expect(at0.lg, equals(space.lg));
        expect(at0.minTapTarget, equals(space.minTapTarget));

        final at1 = space.lerp(other, 1.0);
        expect(at1.xs, equals(12.0));
        expect(at1.radiusXs, equals(10.0));
        expect(at1.radiusXl, equals(32.0));
      }
    });

    test('density multipliers match specification', () {
      final comfortable = MitraSpacing.forDensity(MitraDensity.comfortable);
      final standard = MitraSpacing.forDensity(MitraDensity.standard);
      final compact = MitraSpacing.forDensity(MitraDensity.compact);

      expect(comfortable.minTapTarget, equals(48.0));
      expect(standard.minTapTarget, equals(48.0));
      expect(compact.minTapTarget, equals(40.0));

      expect(comfortable.lg, closeTo(16.0 * 1.15, 0.001));
      expect(standard.lg, equals(16.0));
      expect(compact.lg, closeTo(16.0 * 0.85, 0.001));
    });
  });

  group('MitraStatusColors lerp identity', () {
    test('lerp at t=0 returns this and t=1 returns other', () {
      const a = MitraStatusColors.light;
      const b = MitraStatusColors.dark;

      final at0 = a.lerp(b, 0.0);
      expect(at0.success.color, equals(a.success.color));
      expect(at0.danger.container, equals(a.danger.container));

      final at1 = a.lerp(b, 1.0);
      expect(at1.success.color, equals(b.success.color));
      expect(at1.danger.container, equals(b.danger.container));
    });
  });
}
