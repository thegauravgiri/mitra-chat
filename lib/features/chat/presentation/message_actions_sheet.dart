import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/db/database.dart';
import '../../../domain/models/enums.dart';

class MessageActionsSheet extends StatelessWidget {
  final Message message;
  final bool hasToolInvocations;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onShowInActivity;

  const MessageActionsSheet({
    super.key,
    required this.message,
    this.hasToolInvocations = false,
    this.onRetry,
    this.onDelete,
    this.onShowInActivity,
  });

  static Future<void> show(
    BuildContext context, {
    required Message message,
    bool hasToolInvocations = false,
    VoidCallback? onRetry,
    VoidCallback? onDelete,
    VoidCallback? onShowInActivity,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => MessageActionsSheet(
        message: message,
        hasToolInvocations: hasToolInvocations,
        onRetry: onRetry,
        onDelete: onDelete,
        onShowInActivity: onShowInActivity,
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final isUser = message.role == MessageRole.user;

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

            // Header snippet
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xs),
              child: Text(
                message.content.isEmpty ? 'Message Actions' : message.content,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 16),

            // Copy
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy text'),
              onTap: () => _copy(context),
            ),

            // Show in Activity (if assistant with tools)
            if (!isUser && hasToolInvocations)
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('Show in Activity'),
                onTap: () {
                  Navigator.pop(context);
                  if (onShowInActivity != null) {
                    onShowInActivity!();
                  } else {
                    context.push('/activity');
                  }
                },
              ),

            // Retry / Regenerate
            if (onRetry != null)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(isUser ? 'Retry message' : 'Regenerate response'),
                onTap: () {
                  Navigator.pop(context);
                  onRetry!();
                },
              ),

            // Delete
            if (onDelete != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: status.danger.color,
                ),
                title: Text(
                  'Delete message',
                  style: TextStyle(color: status.danger.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
