import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_pill.dart';
import '../../../integrations/notion/notion_task_mapper.dart';

class NotionTaskCard extends StatelessWidget {
  const NotionTaskCard({
    super.key,
    required this.task,
    this.isUndone = false,
    this.onUndo,
  });

  final NotionCreatedTaskResult task;
  final bool isUndone;
  final VoidCallback? onUndo;

  Future<void> _openUrl(BuildContext context) async {
    if (task.url.isEmpty) return;
    final uri = Uri.parse(task.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;

    return Container(
      margin: EdgeInsets.symmetric(vertical: space.xs),
      decoration: BoxDecoration(
        color: isUndone
            ? status.neutral.container.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(space.radiusMd),
        border: Border.all(
          color: isUndone
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(space.xs),
                  decoration: BoxDecoration(
                    color: isUndone
                        ? status.neutral.container
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(space.radiusSm),
                  ),
                  child: Icon(
                    isUndone ? Icons.archive_rounded : Icons.task_alt_rounded,
                    size: 18,
                    color: isUndone
                        ? status.neutral.onContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              isUndone ? TextDecoration.lineThrough : null,
                          color: isUndone
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: space.xs),
                      Wrap(
                        spacing: space.xs,
                        runSpacing: space.xs * 0.5,
                        children: [
                          if (task.status != null && task.status!.isNotEmpty)
                            MitraPill(
                              icon: Icons.flag_outlined,
                              label: task.status!,
                              status: status.info,
                              compact: true,
                            ),
                          if (task.dueDate != null && task.dueDate!.isNotEmpty)
                            MitraPill(
                              icon: Icons.calendar_today_rounded,
                              label: task.dueDate!,
                              status: status.warning,
                              compact: true,
                            ),
                          if (task.priority != null && task.priority!.isNotEmpty)
                            MitraPill(
                              icon: Icons.priority_high_rounded,
                              label: task.priority!,
                              status: status.danger,
                              compact: true,
                            ),
                          for (final tag in task.tags)
                            MitraPill(
                              icon: Icons.label_outline_rounded,
                              label: tag,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (task.droppedConcepts.isNotEmpty) ...[
              SizedBox(height: space.sm),
              Container(
                padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs * 0.5),
                decoration: BoxDecoration(
                  color: status.warning.container,
                  borderRadius: BorderRadius.circular(space.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: status.warning.color),
                    SizedBox(width: space.xs),
                    Flexible(
                      child: Text(
                        'Unmapped: ${task.droppedConcepts.join(", ")}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: status.warning.onContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: space.sm),
            const Divider(height: 1),
            SizedBox(height: space.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isUndone && onUndo != null) ...[
                  TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: const Text('Undo'),
                    style: TextButton.styleFrom(
                      foregroundColor: status.danger.color,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  SizedBox(width: space.sm),
                ],
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open in Notion'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
