import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_empty_state.dart';
import '../../../core/ui/mitra_error_state.dart';
import '../../../core/ui/mitra_skeleton.dart';
import '../../../data/db/database.dart';
import '../../../data/stores/attachment_store.dart';
import '../application/chat_controller.dart';
import 'chat_scroll_controller.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'message_group_header.dart';

class ChatPane extends ConsumerStatefulWidget {
  const ChatPane({
    super.key,
    required this.conversationId,
    this.initialAttachments = const [],
    this.initialPrompt,
  });

  final String conversationId;
  final List<StoredAttachmentInfo> initialAttachments;
  final String? initialPrompt;

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  late final ChatScrollCoordinator _scrollCoordinator;
  final GlobalKey _composerKey = GlobalKey();
  double _composerHeight = 120.0;

  @override
  void initState() {
    super.initState();
    _scrollCoordinator = ChatScrollCoordinator()
      ..onStateChanged = () {
        if (mounted) setState(() {});
      }
      ..attach();

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureComposer());
  }

  void _measureComposer() {
    final renderBox = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      if ((renderBox.size.height - _composerHeight).abs() > 1.0) {
        setState(() {
          _composerHeight = renderBox.size.height;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollCoordinator.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversationId));
    final invocationsAsync = ref.watch(conversationToolInvocationsProvider(widget.conversationId));
    final chatState = ref.watch(chatControllerProvider(widget.conversationId));
    final chatController = ref.read(chatControllerProvider(widget.conversationId).notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Listen to message updates to trigger auto-scroll reactively
    ref.listen<AsyncValue<List<Message>>>(
      conversationMessagesProvider(widget.conversationId),
      (prev, next) {
        if (next.hasValue) {
          _scrollCoordinator.onNewContentArrived(isStreaming: chatState.isStreaming);
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureComposer());

    return Material(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const MitraEmptyState(
                        icon: Icons.auto_awesome_rounded,
                        title: 'How can I help you today?',
                        body:
                            'Drop handwritten notes, screenshots, or type instructions to execute work in Notion & tools.',
                      );
                    }

                    final invocations = invocationsAsync.valueOrNull ?? [];

                    return CustomScrollView(
                      controller: _scrollCoordinator.scrollController,
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(
                            top: space.md,
                            bottom: space.md + bottomInset,
                          ),
                          sliver: SliverList.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final msgInvocations = invocations
                                  .where((i) => i.messageId == msg.id)
                                  .toList();

                              final showDateHeader = index == 0 ||
                                  !_isSameDay(
                                    messages[index - 1].createdAt,
                                    msg.createdAt,
                                  );

                              final bubble = MessageBubble(
                                key: ValueKey(msg.id),
                                message: msg,
                                toolInvocations: msgInvocations,
                                onUndoTool: (inv) =>
                                    chatController.undoToolInvocation(inv),
                                onRetry: () =>
                                    chatController.retryMessage(msg.id),
                                onDelete: () =>
                                    chatController.deleteMessage(msg.id),
                              );

                              if (showDateHeader) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MessageGroupHeader(date: msg.createdAt),
                                    bubble,
                                  ],
                                );
                              }

                              return bubble;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: MitraMessageSkeleton()),
                  error: (err, _) => MitraErrorState(
                    error: err,
                    onRetry: () => ref.invalidate(
                        conversationMessagesProvider(widget.conversationId)),
                  ),
                ),
              ),

              NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _measureComposer());
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  child: KeyedSubtree(
                    key: _composerKey,
                    child: MessageComposer(
                      initialAttachments: widget.initialAttachments,
                      initialPrompt: widget.initialPrompt,
                      isStreaming: chatState.isStreaming,
                      onSend: (text, atts) => chatController.sendMessage(
                          text: text, attachments: atts),
                      onCancel: () => chatController.cancelRun(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Jump to latest floating pill (dynamically positioned off the measured dock height)
          if (!_scrollCoordinator.userPinnedToBottom)
            Positioned(
              bottom: _composerHeight + space.sm,
              right: space.lg,
              child: AnimatedOpacity(
                duration: MitraMotion.of(context, MitraMotion.fast),
                opacity: _scrollCoordinator.userPinnedToBottom ? 0.0 : 1.0,
                child: Material(
                  elevation: 4,
                  shape: const StadiumBorder(),
                  color: theme.colorScheme.primaryContainer,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _scrollCoordinator.jumpToLatest,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: space.md, vertical: space.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          SizedBox(width: space.xs),
                          Text(
                            _scrollCoordinator.unreadCountWhileAway > 0
                                ? '${_scrollCoordinator.unreadCountWhileAway} new messages'
                                : 'Jump to latest',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
