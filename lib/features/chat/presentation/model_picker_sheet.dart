import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../integrations/llm/llm_types.dart';
import '../../settings/application/settings_controller.dart';

class ModelPickerSheet extends ConsumerWidget {
  const ModelPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => const ModelPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final space = context.space;
    final prefs = ref.watch(prefsStoreProvider);
    final currentModelId = prefs.modelId;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: space.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xs),
              child: Text(
                'Select AI Model',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kAvailableModels.length,
                itemBuilder: (context, index) {
                  final model = kAvailableModels[index];
                  final isSelected = model.id == currentModelId;

                  return ListTile(
                    leading: Icon(
                      Icons.auto_awesome,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      model.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    subtitle: model.description != null
                        ? Text(
                            model.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                        : null,
                    onTap: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .setProviderAndModel(model.providerId, model.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
