import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_mark.dart';
import '../../../core/ui/mitra_skeleton.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../domain/models/enums.dart';
import '../../../integrations/notion/notion_task_mapper.dart';
import '../application/chat_controller.dart';
import 'attachment_viewer.dart';
import 'message_actions_sheet.dart';
import 'notion_task_card.dart';
import 'tool_call_tile.dart';

class MessageBubble extends ConsumerStatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.toolInvocations,
    required this.onUndoTool,
    this.onRetry,
    this.onDelete,
    this.onShowInActivity,
  });

  final Message message;
  final List<ToolInvocation> toolInvocations;
  final void Function(ToolInvocation invocation) onUndoTool;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onShowInActivity;

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  void _showActionsSheet(BuildContext context) {
    MessageActionsSheet.show(
      context,
      message: widget.message,
      hasToolInvocations: widget.toolInvocations.isNotEmpty,
      onRetry: widget.onRetry,
      onDelete: widget.onDelete,
      onShowInActivity: widget.onShowInActivity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    final isCompact = sizeClass.isCompact;
    final isUser = widget.message.role == MessageRole.user;
    final chatState = ref.watch(
      chatControllerProvider(widget.message.conversationId),
    );
    final attachmentsAsync = ref.watch(
      messageAttachmentsProvider(widget.message.id),
    );

    final isActivelyStreaming =
        widget.message.status == MessageStatus.streaming &&
        chatState.isStreaming;
    final isPreFirstToken =
        isActivelyStreaming &&
        widget.message.content.isEmpty &&
        widget.toolInvocations.isEmpty;

    Widget attachmentWidget = attachmentsAsync.when(
      data: (atts) {
        if (atts.isEmpty) return const SizedBox.shrink();
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;

        if (atts.length == 1) {
          final item = atts.first;
          return Padding(
            padding: EdgeInsets.only(bottom: space.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(space.radiusSm),
              child: InkWell(
                onTap: () => AttachmentViewerModal.show(
                  context,
                  file: item.file,
                  heroTag: 'att_${item.attachment.id}',
                  title:
                      'Attachment (${(item.attachment.byteSize / 1024).toStringAsFixed(0)} KB)',
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 220,
                    minWidth: 160,
                  ),
                  child: Hero(
                    tag: 'att_${item.attachment.id}',
                    child: Image.file(
                      item.thumbnailFile ?? item.file,
                      cacheWidth: (320 * pixelRatio).round(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 2+ attachments: 2-column grid
        return Padding(
          padding: EdgeInsets.only(bottom: space.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = ((constraints.maxWidth - space.xs) / 2).clamp(
                80.0,
                160.0,
              );
              return Wrap(
                spacing: space.xs,
                runSpacing: space.xs,
                children: [
                  for (final item in atts)
                    InkWell(
                      borderRadius: BorderRadius.circular(space.radiusSm),
                      onTap: () => AttachmentViewerModal.show(
                        context,
                        file: item.file,
                        heroTag: 'att_${item.attachment.id}',
                        title:
                            'Attachment (${(item.attachment.byteSize / 1024).toStringAsFixed(0)} KB)',
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(space.radiusSm),
                        child: Hero(
                          tag: 'att_${item.attachment.id}',
                          child: SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: Image.file(
                              item.thumbnailFile ?? item.file,
                              cacheWidth: (itemWidth * pixelRatio).round(),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );

    Widget messageContent = Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Attachments
        attachmentWidget,

        // Message text (both user and assistant use bodyLarge 15/1.55)
        if (widget.message.content.isNotEmpty) ...[
          if (isUser)
            SelectableText(
              widget.message.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.55,
              ),
            )
          else ...[
            GptMarkdown(
              isActivelyStreaming
                  ? '${widget.message.content} ▌'
                  : widget.message.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.55,
              ),
            ),
          ],
        ] else if (isPreFirstToken) ...[
          const MitraSkeleton(width: double.infinity, height: 14),
          SizedBox(height: space.xs),
          const MitraSkeleton(width: double.infinity, height: 14),
          SizedBox(height: space.xs),
          MitraSkeleton(width: space.readingMeasureMax * 0.4, height: 14),
        ],

        // Tool Invocations & Interactive Notion Cards
        if (widget.toolInvocations.isNotEmpty) ...[
          SizedBox(height: space.sm),
          for (final inv in widget.toolInvocations) ...[
            ToolCallTile(
              invocation: inv,
              onUndo: inv.status == ToolStatus.ok
                  ? () => widget.onUndoTool(inv)
                  : null,
            ),
            if (_hasNotionTasks(inv)) ...[
              for (final task in _extractNotionTasks(inv))
                NotionTaskCard(
                  task: task,
                  isUndone: inv.status == ToolStatus.undone,
                  onUndo: inv.status == ToolStatus.ok
                      ? () => widget.onUndoTool(inv)
                      : null,
                ),
            ],
          ],
        ],

        // Error Message
        if (widget.message.status == MessageStatus.failed &&
            widget.message.errorMessage != null) ...[
          SizedBox(height: space.sm),
          Container(
            padding: EdgeInsets.all(space.sm),
            decoration: BoxDecoration(
              color: status.danger.container,
              borderRadius: BorderRadius.circular(space.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: status.danger.color,
                ),
                SizedBox(width: space.xs),
                Expanded(
                  child: Text(
                    widget.message.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: status.danger.onContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: space.xs,
            horizontal: space.lg,
          ),
          child: GestureDetector(
            onLongPress: () => _showActionsSheet(context),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width > 800
                    ? space.readingMeasureMax
                    : MediaQuery.sizeOf(context).width * 0.8,
              ),
              padding: EdgeInsets.all(space.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(space.radiusLg),
                  topRight: Radius.circular(space.radiusLg),
                  bottomLeft: Radius.circular(space.radiusLg),
                  bottomRight: Radius.circular(space.xs),
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: messageContent,
            ),
          ),
        ),
      );
    } else {
      // Assistant message: left-aligned per the ChatGPT/Gemini/Claude
      // convention (user messages right, assistant messages left, both
      // capped at a max reading width but anchored to their edge rather
      // than floating centered).
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: space.readingMeasureMax),
          padding: EdgeInsets.symmetric(
            vertical: space.sm,
            horizontal: space.lg,
          ),
          child: GestureDetector(
            onLongPress: () => _showActionsSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompact) ...[
                  // Avatar on tablet/desktop where there's room to spare
                  Container(
                    width: 30,
                    height: 30,
                    margin: EdgeInsets.only(top: 2, right: space.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(space.radiusSm),
                    ),
                    child: MitraMark(
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [messageContent],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  bool _hasNotionTasks(ToolInvocation inv) {
    if (inv.toolName != 'notion.create_tasks' || inv.resultJson == null) {
      return false;
    }
    return true;
  }

  List<NotionCreatedTaskResult> _extractNotionTasks(ToolInvocation inv) {
    try {
      final decoded = jsonDecode(inv.resultJson!) as Map<String, dynamic>;
      final tasksRaw = decoded['created_tasks'] as List<dynamic>? ?? [];
      return tasksRaw
          .whereType<Map<String, dynamic>>()
          .map(NotionCreatedTaskResult.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
