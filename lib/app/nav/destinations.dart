import 'package:flutter/material.dart';

class MitraDestination {
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final String route;

  const MitraDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  static const List<MitraDestination> all = [
    MitraDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Chats',
      route: '/chats',
    ),
    MitraDestination(
      icon: Icon(Icons.hub_outlined),
      selectedIcon: Icon(Icons.hub_rounded),
      label: 'Activity',
      route: '/activity',
    ),
    MitraDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
      route: '/settings',
    ),
  ];
}
