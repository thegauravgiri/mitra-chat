import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../core/ui/mitra_pill.dart';
import '../../../data/providers.dart';
import '../../conversations/application/conversation_list_controller.dart';
import '../../conversations/presentation/conversation_actions_sheet.dart';
import '../../inspector/presentation/tool_inspector_pane.dart';

class ChatHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String conversationId;
  final bool isCompact;
  final bool isExpanded;
  final bool showInspector;
  final VoidCallback? onToggleInspector;
  final VoidCallback? onBack;

  const ChatHeader({
    super.key,
    required this.conversationId,
    this.isCompact = false,
    this.isExpanded = false,
    this.showInspector = false,
    this.onToggleInspector,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  void _showRenameDialog(BuildContext context, WidgetRef ref, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
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
              ref.read(conversationListControllerProvider).renameConversation(conversationId, val.trim());
              Navigator.pop(dialogCtx);
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
                ref.read(conversationListControllerProvider).renameConversation(conversationId, controller.text.trim());
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

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
    final prefs = ref.watch(prefsStoreProvider);
    final convosAsync = ref.watch(conversationListProvider);

    final convo = convosAsync.valueOrNull?.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw StateError('Not found'),
    );

    final title = convo?.title ?? 'Conversation';
    final subtitle = convo != null ? 'Updated ${_formatRelativeTime(convo.updatedAt)}' : null;
    final modelName = prefs.modelId;

    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.symmetric(horizontal: space.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isCompact && onBack != null)
            MitraIconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              semanticLabel: 'Back to conversations',
              onPressed: onBack,
            ),
          SizedBox(width: space.xs),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () => _showRenameDialog(context, ref, title),
              onLongPress: () {
                if (convo != null) {
                  ConversationActionsSheet.show(context, conversation: convo);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: space.xs),
                      Tooltip(
                        message: 'Double tap or long-press to rename',
                        child: Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: space.xs * 0.25),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isCompact) ...[
            SizedBox(width: space.sm),
            MitraPill(
              label: modelName,
              icon: Icons.auto_awesome,
              compact: true,
            ),
          ],
          if (convo != null) ...[
            SizedBox(width: space.xs),
            MitraIconButton(
              icon: const Icon(Icons.more_vert_rounded),
              semanticLabel: 'Conversation actions',
              tooltip: 'More actions',
              onPressed: () => ConversationActionsSheet.show(context, conversation: convo),
            ),
          ],
          SizedBox(width: space.xs),
          MitraIconButton(
            icon: Icon(
              showInspector ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
              color: showInspector ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            semanticLabel: 'Toggle Tool Inspector',
            tooltip: 'Tool Inspector',
            onPressed: () {
              if (onToggleInspector != null) {
                onToggleInspector!();
              } else {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => ToolInspectorPane(
                    conversationId: conversationId,
                    onClose: () => Navigator.pop(ctx),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
