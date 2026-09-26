import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_empty_state.dart';
import '../../../core/ui/mitra_error_state.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../core/ui/mitra_mark.dart';
import '../../../core/ui/mitra_skeleton.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../data/db/database.dart';
import '../application/conversation_list_controller.dart';
import 'conversation_actions_sheet.dart';

class ConversationListPane extends ConsumerStatefulWidget {
  const ConversationListPane({
    super.key,
    required this.selectedConversationId,
    required this.onSelectConversation,
    required this.onOpenSettings,
    this.onToggleCollapse,
  });

  final String? selectedConversationId;
  final void Function(String id) onSelectConversation;
  final VoidCallback onOpenSettings;
  final VoidCallback? onToggleCollapse;

  @override
  ConsumerState<ConversationListPane> createState() =>
      _ConversationListPaneState();
}

class _ConversationListPaneState extends ConsumerState<ConversationListPane> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(conversationSearchQueryProvider.notifier).state =
            _searchController.text;
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  void _showRenameDialog(BuildContext context, Conversation convo) {
    final controller = TextEditingController(text: convo.title);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (val) {
            final newTitle = val.trim();
            if (newTitle.isNotEmpty) {
              ref
                  .read(conversationListControllerProvider)
                  .renameConversation(convo.id, newTitle);
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
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref
                    .read(conversationListControllerProvider)
                    .renameConversation(convo.id, newTitle);
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, Conversation convo) {
    final listController = ref.read(conversationListControllerProvider);
    listController.deleteConversation(convo.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${convo.title}"'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            listController.createNewConversation(title: convo.title);
          },
        ),
      ),
    );
  }

  void _archiveWithUndo(BuildContext context, Conversation convo) {
    final listController = ref.read(conversationListControllerProvider);
    listController.toggleArchive(convo.id, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archived "${convo.title}"'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            listController.toggleArchive(convo.id, false);
          },
        ),
      ),
    );
  }

  Map<String, List<Conversation>> _groupConversations(List<Conversation> list) {
    final pinned = <Conversation>[];
    final today = <Conversation>[];
    final yesterday = <Conversation>[];
    final prevWeek = <Conversation>[];
    final older = <Conversation>[];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));

    for (final c in list) {
      if (c.pinned) {
        pinned.add(c);
      } else if (c.updatedAt.isAfter(todayStart)) {
        today.add(c);
      } else if (c.updatedAt.isAfter(yesterdayStart)) {
        yesterday.add(c);
      } else if (c.updatedAt.isAfter(weekStart)) {
        prevWeek.add(c);
      } else {
        older.add(c);
      }
    }

    final result = <String, List<Conversation>>{};
    if (pinned.isNotEmpty) result['Pinned'] = pinned;
    if (today.isNotEmpty) result['Today'] = today;
    if (yesterday.isNotEmpty) result['Yesterday'] = yesterday;
    if (prevWeek.isNotEmpty) result['Previous 7 days'] = prevWeek;
    if (older.isNotEmpty) result['Older'] = older;

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final conversationsAsync = ref.watch(conversationListProvider);
    final previewsAsync = ref.watch(lastMessagePreviewsProvider);
    final listController = ref.read(conversationListControllerProvider);
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header / App Title
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: space.md,
                vertical: space.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(space.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(space.radiusSm),
                    ),
                    child: MitraMark(
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: space.sm),
                  Flexible(
                    child: Text(
                      'Mitra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onToggleCollapse != null)
                    MitraIconButton(
                      icon: const Icon(Icons.menu_open_rounded),
                      semanticLabel: 'Collapse sidebar',
                      tooltip: 'Collapse sidebar',
                      onPressed: widget.onToggleCollapse,
                    ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: space.lg,
                vertical: space.xs,
              ),
              child: FilledButton(
                onPressed: () async {
                  final convo = await listController.createNewConversation();
                  widget.onSelectConversation(convo.id);
                },
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(space.minTapTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(space.radiusMd),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'New Conversation',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: space.lg,
                vertical: space.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _hasSearchText
                      ? MitraIconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          semanticLabel: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            ref
                                    .read(
                                      conversationSearchQueryProvider.notifier,
                                    )
                                    .state =
                                '';
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: space.md,
                    vertical: space.sm,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Conversations List with date headers
            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    if (_hasSearchText) {
                      return MitraEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No conversations found',
                        body: 'No results matched "${_searchController.text}".',
                        action: TextButton(
                          onPressed: () {
                            _searchController.clear();
                            ref
                                    .read(
                                      conversationSearchQueryProvider.notifier,
                                    )
                                    .state =
                                '';
                          },
                          child: const Text('Clear search'),
                        ),
                      );
                    }
                    return const MitraEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No conversations yet',
                      body:
                          'Create a new conversation or drop handwritten notes to get started.',
                    );
                  }

                  final grouped = _groupConversations(conversations);
                  final previews = previewsAsync.valueOrNull ?? {};

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: space.xs),
                    itemCount: grouped.length,
                    itemBuilder: (context, groupIndex) {
                      final groupTitle = grouped.keys.elementAt(groupIndex);
                      final items = grouped[groupTitle]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              space.lg,
                              space.sm,
                              space.md,
                              space.xs,
                            ),
                            child: Text(
                              groupTitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final convo in items)
                            _buildConversationRow(
                              context,
                              convo: convo,
                              lastMessagePreview: previews[convo.id],
                              isSelected:
                                  convo.id == widget.selectedConversationId,
                              theme: theme,
                              space: space,
                              status: status,
                              isTouch: sizeClass.isTouchFirst,
                              listController: listController,
                            ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const MitraListSkeleton(),
                error: (err, _) => MitraErrorState(
                  error: err,
                  onRetry: () => ref.invalidate(conversationListProvider),
                ),
              ),
            ),

            // Bottom Pinned Settings Section
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: space.md,
                vertical: space.xs,
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(space.radiusSm),
                ),
                leading: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Settings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onTap: widget.onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationRow(
    BuildContext context, {
    required Conversation convo,
    required String? lastMessagePreview,
    required bool isSelected,
    required ThemeData theme,
    required MitraSpacing space,
    required MitraStatusColors status,
    required bool isTouch,
    required ConversationListController listController,
  }) {
    final subtitleText =
        lastMessagePreview != null && lastMessagePreview.isNotEmpty
        ? lastMessagePreview
        : 'Updated ${_formatTimestamp(convo.updatedAt)}';

    return Dismissible(
      key: ValueKey('convo_${convo.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: space.lg),
        color: status.warning.color.withValues(alpha: 0.8),
        child: Icon(
          convo.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: space.lg),
        color: theme.colorScheme.error,
        child: const Icon(Icons.archive_outlined, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        unawaited(HapticFeedback.mediumImpact());
        if (direction == DismissDirection.startToEnd) {
          // Pin / Unpin
          await listController.togglePin(convo.id, !convo.pinned);
          return false;
        } else {
          // Archive
          _archiveWithUndo(context, convo);
          return false;
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: 2),
        child: Ink(
          // `Ink` (not `Container`) so this selection background paints onto
          // the ListTile's own Material ancestor instead of hiding its ink
          // splashes underneath an opaque DecoratedBox.
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(space.radiusSm),
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(space.radiusFull),
                    ),
                  ),
                ),
              Semantics(
                customSemanticsActions: {
                  CustomSemanticsAction(
                    label: convo.pinned ? 'Unpin' : 'Pin',
                  ): () {
                    unawaited(
                      listController.togglePin(convo.id, !convo.pinned),
                    );
                  },
                  const CustomSemanticsAction(label: 'Archive'): () {
                    _archiveWithUndo(context, convo);
                  },
                  const CustomSemanticsAction(label: 'Delete'): () {
                    _deleteWithUndo(context, convo);
                  },
                },
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(space.radiusSm),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: space.md,
                    vertical: space.xs,
                  ),
                  leading: Icon(
                    convo.pinned
                        ? Icons.push_pin_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (convo.pinned
                              ? status.warning.color
                              : theme.colorScheme.onSurfaceVariant),
                  ),
                  title: Text(
                    convo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isTouch
                      ? null
                      : PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (action) {
                            switch (action) {
                              case 'rename':
                                _showRenameDialog(context, convo);
                              case 'pin':
                                listController.togglePin(
                                  convo.id,
                                  !convo.pinned,
                                );
                              case 'archive':
                                listController.toggleArchive(convo.id, true);
                              case 'delete':
                                _deleteWithUndo(context, convo);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    convo.pinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(convo.pinned ? 'Unpin' : 'Pin to top'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(Icons.archive_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Archive'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: status.danger.color,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: status.danger.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  onTap: () => widget.onSelectConversation(convo.id),
                  onLongPress: () => ConversationActionsSheet.show(
                    context,
                    conversation: convo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
