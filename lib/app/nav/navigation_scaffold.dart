import 'package:flutter/material.dart';
import '../../core/utils/breakpoints.dart';
import 'destinations.dart';

class MitraNavigationScaffold extends StatelessWidget {
  final WindowSizeClass sizeClass;
  final List<MitraDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? railLeading;
  final Widget? railTrailing;
  final Widget? floatingActionButton;

  const MitraNavigationScaffold({
    super.key,
    required this.sizeClass,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.railLeading,
    this.railTrailing,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    if (sizeClass.navigationType == NavigationType.bottomBar) {
      return Scaffold(
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations
              .map(
                (d) => NavigationDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: d.label,
                ),
              )
              .toList(),
        ),
      );
    }

    final isExtended = sizeClass.navigationType == NavigationType.extendedRail;
    final scaler = MediaQuery.textScalerOf(context);
    final minExtendedWidth = scaler.scale(160).clamp(256.0, 380.0);

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          SafeArea(
            bottom: false,
            child: NavigationRail(
              extended: isExtended,
              minExtendedWidth: minExtendedWidth,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              leading: railLeading,
              trailing: railTrailing,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(
                        d.label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
