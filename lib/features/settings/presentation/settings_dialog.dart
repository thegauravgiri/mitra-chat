import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../application/settings_controller.dart';
import 'sections/appearance_section.dart';
import 'sections/mcp_section.dart';
import 'sections/models_section.dart';
import 'sections/notion_section.dart';
import 'sections/quick_prompts_section.dart';
import 'settings_section_nav.dart';

/// Shows Settings as a modal pop-up rather than a navigation destination:
/// a fixed-size centered dialog on tablet/desktop, a near-full-height
/// bottom sheet on phones -- the same adaptive pop-up pattern already used
/// for the incoming-share sheet.
Future<void> showSettingsDialog(BuildContext context) {
  final space = context.space;
  final isCompact = WindowSizeClass.fromWidth(
    MediaQuery.sizeOf(context).width,
  ).isCompact;

  if (isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
        ),
        child: Material(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(space.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: const SettingsDialog(),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(space.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: const SizedBox(width: 900, height: 640, child: SettingsDialog()),
      ),
    ),
  );
}

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  SettingsSection? _selectedSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final settingsAsync = ref.watch(settingsControllerProvider);
    final quickPromptsAsync = ref.watch(quickPromptsProvider);
    final prefs = ref.watch(prefsStoreProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 640;
    final drilledIn = !isWide && _selectedSection != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(space.lg, space.sm, space.sm, space.sm),
          child: Row(
            children: [
              if (drilledIn)
                MitraIconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  semanticLabel: 'Back to settings',
                  onPressed: () => setState(() => _selectedSection = null),
                ),
              Expanded(
                child: Text(
                  drilledIn ? _selectedSection!.label : 'Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MitraIconButton(
                icon: const Icon(Icons.close_rounded),
                semanticLabel: 'Close settings',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: settingsAsync.when(
            data: (settings) {
              final sectionWidget = switch (_selectedSection ??
                  SettingsSection.models) {
                SettingsSection.models => ModelsSection(settings: settings),
                SettingsSection.notion => NotionSection(settings: settings),
                SettingsSection.mcp => McpSection(settings: settings),
                SettingsSection.quickPrompts => const QuickPromptsSection(),
                SettingsSection.appearance => AppearanceSection(
                  settings: settings,
                ),
              };

              if (isWide) {
                return Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: SettingsSectionNav(
                        selectedSection:
                            _selectedSection ?? SettingsSection.models,
                        onSelectSection: (s) =>
                            setState(() => _selectedSection = s),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(space.xl),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: space.readingMeasureMax,
                          ),
                          child: sectionWidget,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (drilledIn) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(space.md),
                  child: sectionWidget,
                );
              }

              return _SettingsIndexList(
                settings: settings,
                mcpSummary: prefs.mcpBaseUrl.isNotEmpty
                    ? prefs.mcpBaseUrl
                    : 'Not configured',
                promptCount: quickPromptsAsync.valueOrNull?.length ?? 0,
                onSelectSection: (s) => setState(() => _selectedSection = s),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}

class _SettingsIndexList extends StatelessWidget {
  const _SettingsIndexList({
    required this.settings,
    required this.mcpSummary,
    required this.promptCount,
    required this.onSelectSection,
  });

  final AppSettings settings;
  final String mcpSummary;
  final int promptCount;
  final ValueChanged<SettingsSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.status;

    final modelSummary =
        settings.hasGeminiKey ||
            settings.hasAnthropicKey ||
            settings.hasOpenAiKey
        ? '${settings.modelId} · Key configured'
        : 'No API keys configured';
    final notionSummary = settings.hasNotionToken
        ? 'Token configured & connected'
        : 'Not connected (BYOK)';
    final appearanceSummary =
        'Theme: ${settings.themeMode.toUpperCase()} · Dynamic color: ${settings.useDynamicColor ? "On" : "Off"}';

    return ListView(
      padding: EdgeInsets.symmetric(vertical: context.space.sm),
      children: [
        ListTile(
          leading: Icon(
            Icons.psychology_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text(
            'AI Models',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(modelSummary),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onSelectSection(SettingsSection.models),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.table_chart_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text(
            'Notion Integration',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            notionSummary,
            style: TextStyle(
              color: settings.hasNotionToken ? status.success.color : null,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onSelectSection(SettingsSection.notion),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
          title: const Text(
            'Mitra MCP Gateway',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(mcpSummary),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onSelectSection(SettingsSection.mcp),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.bolt_outlined, color: theme.colorScheme.primary),
          title: const Text(
            'Quick Action Prompts',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$promptCount prompt${promptCount == 1 ? "" : "s"} configured',
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onSelectSection(SettingsSection.quickPrompts),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.palette_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text(
            'Appearance & Behavior',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(appearanceSummary),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onSelectSection(SettingsSection.appearance),
        ),
      ],
    );
  }
}
