import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../core/ui/mitra_mark.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/presentation/attachment_viewer.dart';
import '../../conversations/application/conversation_list_controller.dart';
import '../application/share_inbox.dart';

class IncomingShareSheet extends ConsumerStatefulWidget {
  const IncomingShareSheet({
    super.key,
    required this.shareItem,
    required this.onTargetSelected,
  });

  final IncomingShareItem shareItem;
  final void Function(String conversationId, String prompt) onTargetSelected;

  @override
  ConsumerState<IncomingShareSheet> createState() => _IncomingShareSheetState();
}

class _IncomingShareSheetState extends ConsumerState<IncomingShareSheet> {
  final TextEditingController _customPromptController = TextEditingController();
  bool _isExistingTarget = false;
  String? _selectedConvoId;

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  Future<void> _dispatch(String prompt) async {
    unawaited(HapticFeedback.lightImpact());
    final listCtrl = ref.read(conversationListControllerProvider);
    String targetId;

    if (!_isExistingTarget || _selectedConvoId == null) {
      final newConvo = await listCtrl.createNewConversation(
        title:
            'Note: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
      targetId = newConvo.id;
    } else {
      targetId = _selectedConvoId!;
    }

    // Send prompt and attachments
    unawaited(
      ref
          .read(chatControllerProvider(targetId).notifier)
          .sendMessage(text: prompt, attachments: widget.shareItem.attachments),
    );

    ref.read(shareInboxProvider.notifier).consume();
    widget.onTargetSelected(targetId, prompt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final recentsAsync = ref.watch(recentConversationsProvider(5));
    final quickPromptsAsync = ref.watch(quickPromptsProvider);
    final firstAtt = widget.shareItem.attachments.isNotEmpty
        ? widget.shareItem.attachments.first
        : null;

    // Simple fixed-height pop-up (no drag-to-resize): bounded by a max
    // height so it never overflows, scrolling internally when content
    // doesn't fit.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(space.radiusLg),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(space.lg, space.sm, space.lg, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      MitraMark(size: 20, color: theme.colorScheme.primary),
                      SizedBox(width: space.sm),
                      Text(
                        'Incoming Note / Share',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      MitraIconButton(
                        icon: const Icon(Icons.close_rounded),
                        semanticLabel: 'Close share sheet',
                        onPressed: () {
                          ref.read(shareInboxProvider.notifier).consume();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),

            // Scrollable content: everything (image + actions) is one
            // CustomScrollView/SliverList, so it all scrolls together as a
            // single surface instead of a fixed block competing with a
            // separate scrollable for space (that split is what caused the
            // overflow when the sheet was short).
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: space.lg,
                      vertical: space.sm,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Hero image preview
                        if (firstAtt != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(space.radiusMd),
                            child: InkWell(
                              onTap: () => AttachmentViewerModal.show(
                                context,
                                file: firstAtt.file,
                                heroTag: 'share_preview_${firstAtt.id}',
                                title: 'Shared Note Preview',
                              ),
                              child: Hero(
                                tag: 'share_preview_${firstAtt.id}',
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 180,
                                  ),
                                  child: Image.file(
                                    firstAtt.thumbFile ?? firstAtt.file,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: space.md),
                        ],

                        // Target Mode SegmentedButton
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.add_comment_outlined),
                              label: Text('New Chat'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.chat_bubble_outline_rounded),
                              label: Text('Existing Chat'),
                            ),
                          ],
                          selected: {_isExistingTarget},
                          onSelectionChanged: (set) =>
                              setState(() => _isExistingTarget = set.first),
                        ),
                        SizedBox(height: space.sm),

                        // Existing chat picker
                        if (_isExistingTarget)
                          recentsAsync.when(
                            data: (convos) {
                              if (convos.isEmpty) {
                                return const Text(
                                  'No recent conversations found.',
                                );
                              }
                              return Column(
                                children: [
                                  for (final c in convos)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        _selectedConvoId == c.id
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: _selectedConvoId == c.id
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        size: 20,
                                      ),
                                      title: Text(c.title, maxLines: 1),
                                      onTap: () => setState(
                                        () => _selectedConvoId = c.id,
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (err, stack) => const SizedBox.shrink(),
                          ),

                        SizedBox(height: space.sm),

                        // Quick action buttons (2-column grid)
                        Text(
                          'Quick Actions',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: space.xs),

                        quickPromptsAsync.when(
                          data: (prompts) {
                            final actions = prompts.isNotEmpty
                                ? prompts
                                : const [
                                    QuickPrompt(
                                      id: '1',
                                      label: 'Create Notion tasks',
                                      promptText:
                                          'Extract all action items and create tasks in Notion',
                                      sortOrder: 0,
                                      builtin: true,
                                    ),
                                    QuickPrompt(
                                      id: '2',
                                      label: 'Extract action items',
                                      promptText:
                                          'Extract all action items from this note into a clean checklist',
                                      sortOrder: 1,
                                      builtin: true,
                                    ),
                                  ];

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.8,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: actions.length,
                              itemBuilder: (context, index) {
                                final p = actions[index];
                                return FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: space.sm,
                                      vertical: space.xs,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        space.radiusSm,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    unawaited(_dispatch(p.promptText));
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          p.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (err, stack) => const SizedBox.shrink(),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom CTA & Custom instruction row docked above viewInsets
            Container(
              padding: EdgeInsets.fromLTRB(
                space.lg,
                space.sm,
                space.lg,
                MediaQuery.of(context).viewInsets.bottom + space.md,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customPromptController,
                      decoration: InputDecoration(
                        hintText: 'Custom instruction...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: space.md,
                          vertical: space.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(space.radiusFull),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: space.sm),
                  FilledButton.icon(
                    onPressed: () {
                      final custom = _customPromptController.text.trim();
                      final prompt = custom.isNotEmpty
                          ? custom
                          : 'Analyze this note and extract tasks';
                      Navigator.pop(context);
                      unawaited(_dispatch(prompt));
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Process'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
