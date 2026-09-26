import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/db/database.dart';
import '../application/conversation_list_controller.dart';

class ConversationActionsSheet extends ConsumerWidget {
  final Conversation conversation;
  final VoidCallback? onAfterAction;

  const ConversationActionsSheet({
    super.key,
    required this.conversation,
    this.onAfterAction,
  });

  static Future<void> show(
    BuildContext context, {
    required Conversation conversation,
    VoidCallback? onAfterAction,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => ConversationActionsSheet(
        conversation: conversation,
        onAfterAction: onAfterAction,
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: conversation.title);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              ref
                  .read(conversationListControllerProvider)
                  .renameConversation(conversation.id, val.trim());
              Navigator.pop(dialogCtx);
              onAfterAction?.call();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(conversationListControllerProvider)
                    .renameConversation(conversation.id, controller.text.trim());
                Navigator.pop(dialogCtx);
                onAfterAction?.call();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final isPinned = conversation.pinned;
    final isArchived = conversation.archived;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xs),
              child: Text(
                conversation.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 16),

            // Rename
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref);
              },
            ),

            // Pin / Unpin
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? status.warning.color : null,
              ),
              title: Text(isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(conversationListControllerProvider)
                    .togglePinned(conversation.id);
                onAfterAction?.call();
              },
            ),

            // Archive / Unarchive
            ListTile(
              leading: Icon(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              title: Text(isArchived ? 'Unarchive' : 'Archive'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(conversationListControllerProvider)
                    .toggleArchived(conversation.id);
                onAfterAction?.call();
              },
            ),

            // Delete
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: status.danger.color,
              ),
              title: Text(
                'Delete conversation',
                style: TextStyle(color: status.danger.color),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(conversationListControllerProvider)
                    .deleteConversation(conversation.id);
                onAfterAction?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
