import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_mark.dart';
import '../../conversations/application/conversation_list_controller.dart';

class EmptyChatDetailPane extends ConsumerWidget {
  const EmptyChatDetailPane({super.key});

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final space = context.space;
    final convosAsync = ref.watch(conversationListProvider);
    final convos = convosAsync.valueOrNull ?? [];
    final recentThree = convos.take(3).toList();

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(space.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: space.readingMeasureMax),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: MitraMark(
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(height: space.lg),
              Text(
                'Mitra Assistant',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: space.xs),
              Text(
                'Turn handwritten notes into executed tasks and actions.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: space.xl),
              FilledButton.icon(
                onPressed: () async {
                  final convo = await ref
                      .read(conversationListControllerProvider)
                      .createNewConversation();
                  ref.read(activeConversationIdProvider.notifier).state =
                      convo.id;
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'New conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: space.lg,
                    vertical: space.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(space.radiusMd),
                  ),
                ),
              ),
              if (recentThree.isNotEmpty) ...[
                SizedBox(height: space.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Conversations',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: space.sm),
                for (final c in recentThree) ...[
                  Card(
                    margin: EdgeInsets.only(bottom: space.sm),
                    child: ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      title: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Updated ${_formatRelativeTime(c.updatedAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () {
                        ref.read(activeConversationIdProvider.notifier).state =
                            c.id;
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
