import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ui/mitra_pill.dart';
import 'theme/tokens.dart';

class NewConversationIntent extends Intent {
  const NewConversationIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ToggleInspectorIntent extends Intent {
  const ToggleInspectorIntent();
}

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class CancelOrEscapeIntent extends Intent {
  const CancelOrEscapeIntent();
}

class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}

class MitraShortcuts {
  MitraShortcuts._();

  static final Map<ShortcutActivator, Intent> defaultBindings = {
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
        const NewConversationIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
        const NewConversationIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
        const FocusSearchIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
        const FocusSearchIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.backslash):
        const ToggleInspectorIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.backslash):
        const ToggleInspectorIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB):
        const ToggleSidebarIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
        const ToggleSidebarIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.comma):
        const OpenSettingsIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
        const OpenSettingsIntent(),
    LogicalKeySet(LogicalKeyboardKey.escape):
        const CancelOrEscapeIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.slash):
        const ShowShortcutsIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.slash):
        const ShowShortcutsIntent(),
  };

  static void showCheatsheet(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    final shortcuts = [
      ('New Conversation', 'Cmd/Ctrl + N'),
      ('Focus Search', 'Cmd/Ctrl + K'),
      ('Toggle Inspector', 'Cmd/Ctrl + \\'),
      ('Toggle Sidebar', 'Cmd/Ctrl + B'),
      ('Settings', 'Cmd/Ctrl + ,'),
      ('Send Message', 'Cmd/Ctrl + Enter'),
      ('Cancel / Escape', 'Esc'),
      ('Keyboard Shortcuts', 'Cmd/Ctrl + /'),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard_outlined, size: 22),
            SizedBox(width: space.sm),
            const Text('Keyboard Shortcuts'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, keyCombo) in shortcuts) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: space.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: theme.textTheme.bodyMedium),
                      MitraPill(
                        label: keyCombo,
                        compact: true,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
                if (label != shortcuts.last.$1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
