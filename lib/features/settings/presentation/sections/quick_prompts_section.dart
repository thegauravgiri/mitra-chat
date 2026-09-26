import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/ui/mitra_icon_button.dart';
import '../../../../core/ui/mitra_section.dart';
import '../../../../data/db/database.dart';
import '../../../../data/providers.dart';

class QuickPromptsSection extends ConsumerWidget {
  const QuickPromptsSection({super.key});

  void _showAddPromptDialog(BuildContext context, WidgetRef ref) {
    final labelCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final space = context.space;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Quick Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Chip Label'),
            ),
            SizedBox(height: space.md),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Prompt Template'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && textCtrl.text.isNotEmpty) {
                ref
                    .read(settingsRepositoryProvider)
                    .addQuickPrompt(labelCtrl.text.trim(), textCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = context.status;
    final settingsRepo = ref.watch(settingsRepositoryProvider);

    return MitraSection(
      title: 'Quick Action Prompts',
      subtitle:
          'Shortcuts shown above the chat composer for one-tap execution',
      trailing: FilledButton.tonalIcon(
        onPressed: () => _showAddPromptDialog(context, ref),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Prompt'),
      ),
      child: StreamBuilder<List<QuickPrompt>>(
        stream: settingsRepo.watchQuickPrompts(),
        builder: (context, snapshot) {
          final prompts = snapshot.data ?? [];
          if (prompts.isEmpty) {
            return const Text('No quick prompts configured.');
          }
          return Column(
            children: [
              for (final p in prompts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.promptText, maxLines: 2),
                  trailing: MitraIconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: status.danger.color),
                    semanticLabel: 'Delete prompt',
                    onPressed: () =>
                        settingsRepo.deleteQuickPrompt(p.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
