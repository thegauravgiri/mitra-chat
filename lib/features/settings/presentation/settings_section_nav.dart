import 'package:flutter/material.dart';
import '../../../app/theme/tokens.dart';

enum SettingsSection {
  models(label: 'AI Models', icon: Icons.psychology_outlined),
  notion(label: 'Notion', icon: Icons.table_chart_outlined),
  mcp(label: 'MCP Gateway', icon: Icons.hub_outlined),
  quickPrompts(label: 'Quick Prompts', icon: Icons.bolt_outlined),
  appearance(label: 'Appearance', icon: Icons.palette_outlined);

  final String label;
  final IconData icon;

  const SettingsSection({required this.label, required this.icon});
}

class SettingsSectionNav extends StatelessWidget {
  final SettingsSection selectedSection;
  final ValueChanged<SettingsSection> onSelectSection;

  const SettingsSectionNav({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    return ListView(
      padding: EdgeInsets.all(space.sm),
      children: [
        for (final s in SettingsSection.values) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Ink(
              decoration: BoxDecoration(
                color: s == selectedSection
                    ? theme.colorScheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(space.radiusSm),
              ),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(space.radiusSm),
                ),
                leading: Icon(
                  s.icon,
                  size: 20,
                  color: s == selectedSection
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: s == selectedSection ? FontWeight.w600 : FontWeight.normal,
                    color: s == selectedSection
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                onTap: () => onSelectSection(s),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
