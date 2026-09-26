enum NavigationType {
  bottomBar,
  rail,
  extendedRail,
}

enum WindowSizeClass {
  compact,
  medium,
  expanded,
  large,
  extraLarge;

  static WindowSizeClass fromWidth(double w) =>
      w < 600
          ? compact
          : w < 840
              ? medium
              : w < 1200
                  ? expanded
                  : w < 1600
                      ? large
                      : extraLarge;

  bool get isCompact => this == compact;
  bool get isMedium => this == medium;
  bool get isExpanded => this == expanded;
  bool get isLarge => this == large;
  bool get isExtraLarge => this == extraLarge;

  bool get isTouchFirst => this == compact || this == medium;
  bool get showsListPane => index >= WindowSizeClass.medium.index;
  bool get showsInspectorPane => index >= WindowSizeClass.large.index;

  NavigationType get navigationType => switch (this) {
        compact => NavigationType.bottomBar,
        medium || expanded => NavigationType.rail,
        large || extraLarge => NavigationType.extendedRail,
      };
}

enum WindowHeightClass {
  compact,
  medium,
  expanded;

  static WindowHeightClass fromHeight(double h) =>
      h < 480
          ? compact
          : h < 900
              ? medium
              : expanded;

  bool get isCompact => this == compact;
  bool get isMedium => this == medium;
  bool get isExpanded => this == expanded;
}
