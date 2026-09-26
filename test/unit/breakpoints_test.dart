import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/core/utils/breakpoints.dart';

void main() {
  group('WindowSizeClass breakpoints', () {
    test('boundary testing at n-1 and n for all width breaks', () {
      // < 600 -> compact
      expect(WindowSizeClass.fromWidth(0), equals(WindowSizeClass.compact));
      expect(WindowSizeClass.fromWidth(599), equals(WindowSizeClass.compact));
      expect(WindowSizeClass.fromWidth(599.9), equals(WindowSizeClass.compact));

      // 600 - 839 -> medium
      expect(WindowSizeClass.fromWidth(600), equals(WindowSizeClass.medium));
      expect(WindowSizeClass.fromWidth(839), equals(WindowSizeClass.medium));
      expect(WindowSizeClass.fromWidth(839.9), equals(WindowSizeClass.medium));

      // 840 - 1199 -> expanded
      expect(WindowSizeClass.fromWidth(840), equals(WindowSizeClass.expanded));
      expect(WindowSizeClass.fromWidth(1199), equals(WindowSizeClass.expanded));
      expect(WindowSizeClass.fromWidth(1199.9), equals(WindowSizeClass.expanded));

      // 1200 - 1599 -> large
      expect(WindowSizeClass.fromWidth(1200), equals(WindowSizeClass.large));
      expect(WindowSizeClass.fromWidth(1599), equals(WindowSizeClass.large));
      expect(WindowSizeClass.fromWidth(1599.9), equals(WindowSizeClass.large));

      // >= 1600 -> extraLarge
      expect(WindowSizeClass.fromWidth(1600), equals(WindowSizeClass.extraLarge));
      expect(WindowSizeClass.fromWidth(2000), equals(WindowSizeClass.extraLarge));
    });

    test('helper properties', () {
      // isCompact
      expect(WindowSizeClass.compact.isCompact, isTrue);
      expect(WindowSizeClass.medium.isCompact, isFalse);
      expect(WindowSizeClass.expanded.isCompact, isFalse);
      expect(WindowSizeClass.large.isCompact, isFalse);
      expect(WindowSizeClass.extraLarge.isCompact, isFalse);

      // isTouchFirst (compact and medium)
      expect(WindowSizeClass.compact.isTouchFirst, isTrue);
      expect(WindowSizeClass.medium.isTouchFirst, isTrue);
      expect(WindowSizeClass.expanded.isTouchFirst, isFalse);
      expect(WindowSizeClass.large.isTouchFirst, isFalse);
      expect(WindowSizeClass.extraLarge.isTouchFirst, isFalse);

      // showsListPane (medium, expanded, large, extraLarge)
      expect(WindowSizeClass.compact.showsListPane, isFalse);
      expect(WindowSizeClass.medium.showsListPane, isTrue);
      expect(WindowSizeClass.expanded.showsListPane, isTrue);
      expect(WindowSizeClass.large.showsListPane, isTrue);
      expect(WindowSizeClass.extraLarge.showsListPane, isTrue);

      // showsInspectorPane (large, extraLarge)
      expect(WindowSizeClass.compact.showsInspectorPane, isFalse);
      expect(WindowSizeClass.medium.showsInspectorPane, isFalse);
      expect(WindowSizeClass.expanded.showsInspectorPane, isFalse);
      expect(WindowSizeClass.large.showsInspectorPane, isTrue);
      expect(WindowSizeClass.extraLarge.showsInspectorPane, isTrue);

      // navigationType
      expect(WindowSizeClass.compact.navigationType, equals(NavigationType.bottomBar));
      expect(WindowSizeClass.medium.navigationType, equals(NavigationType.rail));
      expect(WindowSizeClass.expanded.navigationType, equals(NavigationType.rail));
      expect(WindowSizeClass.large.navigationType, equals(NavigationType.extendedRail));
      expect(WindowSizeClass.extraLarge.navigationType, equals(NavigationType.extendedRail));
    });
  });

  group('WindowHeightClass breakpoints', () {
    test('boundary testing at n-1 and n for all height breaks', () {
      // < 480 -> compact
      expect(WindowHeightClass.fromHeight(0), equals(WindowHeightClass.compact));
      expect(WindowHeightClass.fromHeight(479), equals(WindowHeightClass.compact));
      expect(WindowHeightClass.fromHeight(479.9), equals(WindowHeightClass.compact));

      // 480 - 899 -> medium
      expect(WindowHeightClass.fromHeight(480), equals(WindowHeightClass.medium));
      expect(WindowHeightClass.fromHeight(899), equals(WindowHeightClass.medium));
      expect(WindowHeightClass.fromHeight(899.9), equals(WindowHeightClass.medium));

      // >= 900 -> expanded
      expect(WindowHeightClass.fromHeight(900), equals(WindowHeightClass.expanded));
      expect(WindowHeightClass.fromHeight(1200), equals(WindowHeightClass.expanded));
    });

    test('helper properties', () {
      expect(WindowHeightClass.compact.isCompact, isTrue);
      expect(WindowHeightClass.medium.isCompact, isFalse);
      expect(WindowHeightClass.expanded.isCompact, isFalse);
    });
  });
}
