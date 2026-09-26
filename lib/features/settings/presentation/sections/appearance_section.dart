import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/ui/mitra_section.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../application/settings_controller.dart';

class AppearanceSection extends ConsumerWidget {
  final AppSettings settings;

  const AppearanceSection({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final space = context.space;
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);

    return MitraSection(
      title: 'Appearance & Behavior',
      subtitle: 'Theme modes, dynamic colors, and keyboard shortcuts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Theme Mode',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: space.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'system',
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('System'),
              ),
              ButtonSegment(
                value: 'light',
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: 'dark',
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Dark'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) => settingsCtrl.setThemeMode(set.first),
          ),
          SizedBox(height: space.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dynamic Color (Material You)'),
            subtitle: const Text(
              'Harmonise UI colors with your system wallpaper palette on supported devices',
            ),
            value: settings.useDynamicColor,
            onChanged: (val) => settingsCtrl.setUseDynamicColor(val),
          ),
          const Divider(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enter sends message'),
            subtitle: const Text(
              'Pressing Enter on a hardware keyboard sends the message instead of adding a new line',
            ),
            value: settings.enterSendsMessage,
            onChanged: (val) => settingsCtrl.setEnterSendsMessage(val),
          ),
          const Divider(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-run Safe Tools'),
            subtitle: const Text(
              'Directly execute read and task creations in Notion without confirmation prompt',
            ),
            value: settings.autoRunTools,
            onChanged: (val) => settingsCtrl.setAutoRunTools(val),
          ),
        ],
      ),
    );
  }
}
