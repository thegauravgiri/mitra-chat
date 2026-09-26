import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../core/ui/mitra_pill.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../data/providers.dart';
import '../../../data/stores/attachment_store.dart';
import 'attach_sheet.dart';
import 'attachment_chip.dart';
import 'model_picker_sheet.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onCancel,
    required this.isStreaming,
    this.initialAttachments = const [],
    this.initialPrompt,
  });

  final Future<void> Function(
    String text,
    List<StoredAttachmentInfo> attachments,
  )
  onSend;
  final VoidCallback onCancel;
  final bool isStreaming;
  final List<StoredAttachmentInfo> initialAttachments;
  final String? initialPrompt;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<StoredAttachmentInfo> _attachments = [];
  bool _isTextEmpty = true;
  bool _showQuickPrompts = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _textController.text = widget.initialPrompt!;
      _isTextEmpty = widget.initialPrompt!.trim().isEmpty;
    }
    _attachments.addAll(widget.initialAttachments);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final empty = _textController.text.trim().isEmpty;
    if (empty != _isTextEmpty) {
      setState(() => _isTextEmpty = empty);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    unawaited(HapticFeedback.lightImpact());

    final atts = List<StoredAttachmentInfo>.from(_attachments);
    final promptText = text.isEmpty && atts.isNotEmpty
        ? 'Analyze this note'
        : text;

    _textController.clear();
    setState(() {
      _attachments.clear();
      _isTextEmpty = true;
    });

    await widget.onSend(promptText, atts);
  }

  void _handleCancel() {
    unawaited(HapticFeedback.mediumImpact());
    widget.onCancel();
  }

  bool _isImeComposing() {
    final textVal = _textController.value;
    return textVal.isComposingRangeValid && !textVal.composing.isCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final prefs = ref.watch(prefsStoreProvider);
    final quickPromptsAsync = ref.watch(quickPromptsProvider);
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    final canSend =
        (!_isTextEmpty || _attachments.isNotEmpty) && !widget.isStreaming;

    // Quick prompts auto-expand when text is empty and attachments are present
    final shouldShowQuickPrompts =
        _showQuickPrompts || (_isTextEmpty && _attachments.isNotEmpty);

    // The on-screen keyboard's own return/action button is driven purely by
    // textInputAction/onSubmitted -- tapping it never reaches the
    // CallbackShortcuts below (those only see physical key events). So it
    // stays newline-only on touch platforms regardless of the "Enter sends
    // message" preference, which (per its own description) is specifically
    // about a hardware keyboard. Window-width size classes aren't a
    // reliable signal here either: a tablet in landscape is still
    // on-screen-keyboard input despite the wider layout.
    final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final softKeyboardSendsMessage =
        !isMobilePlatform && prefs.enterSendsMessage;
    final hardwareEnterSendsMessage = prefs.enterSendsMessage;
    final sendButtonSize = sizeClass.isTouchFirst ? 44.0 : 36.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: space.readingMeasureMax),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              space.lg,
              space.xs,
              space.lg,
              space.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick prompts floating chip row above composer
                if (shouldShowQuickPrompts)
                  quickPromptsAsync.when(
                    data: (prompts) {
                      if (prompts.isEmpty) return const SizedBox.shrink();
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.only(bottom: space.sm),
                        child: Row(
                          children: [
                            for (final p in prompts)
                              Padding(
                                padding: EdgeInsets.only(right: space.xs),
                                child: ActionChip(
                                  label: Text(p.label),
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      space.radiusSm,
                                    ),
                                  ),
                                  onPressed: widget.isStreaming
                                      ? null
                                      : () {
                                          _textController.text = p.promptText;
                                          _focusNode.requestFocus();
                                        },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),

                // Unified Card Input Capsule
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.5 : 0.7,
                      ),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Attachment thumbnails row inside top of card
                      if (_attachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Wrap(
                            spacing: space.sm,
                            runSpacing: space.xs,
                            children: [
                              for (int i = 0; i < _attachments.length; i++)
                                AttachmentChip(
                                  info: _attachments[i],
                                  onRemove: () {
                                    setState(() {
                                      _attachments.removeAt(i);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),

                      // Text Field with generous padding
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _attachments.isNotEmpty ? 4 : 14,
                          16,
                          8,
                        ),
                        child: CallbackShortcuts(
                          bindings: hardwareEnterSendsMessage
                              ? {
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                  ): () {
                                    if (!HardwareKeyboard
                                            .instance
                                            .isShiftPressed &&
                                        !_isImeComposing()) {
                                      _handleSend();
                                    }
                                  },
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                    meta: true,
                                  ): () {
                                    if (!_isImeComposing()) {
                                      _handleSend();
                                    }
                                  },
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                    control: true,
                                  ): () {
                                    if (!_isImeComposing()) {
                                      _handleSend();
                                    }
                                  },
                                }
                              : {
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                    meta: true,
                                  ): () {
                                    if (!_isImeComposing()) {
                                      _handleSend();
                                    }
                                  },
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                    control: true,
                                  ): () {
                                    if (!_isImeComposing()) {
                                      _handleSend();
                                    }
                                  },
                                },
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 8,
                            textInputAction: softKeyboardSendsMessage
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            onSubmitted: softKeyboardSendsMessage
                                ? (_) => _handleSend()
                                : null,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.isStreaming
                                  ? 'Agent is working...'
                                  : 'Ask Mitra, type instructions, or drop notes...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.65),
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),

                      // Dock Action Toolbar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          children: [
                            // Attach button (+)
                            MitraIconButton(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 20,
                              ),
                              semanticLabel: 'Attach note, screenshot, or file',
                              tooltip: 'Attach',
                              onPressed: widget.isStreaming
                                  ? null
                                  : () => AttachSheet.show(
                                      context,
                                      onAttachmentAdded: (att) {
                                        setState(() => _attachments.add(att));
                                      },
                                    ),
                            ),

                            // Quick prompts toggle button (bolt)
                            MitraIconButton(
                              icon: Icon(
                                _showQuickPrompts
                                    ? Icons.bolt_rounded
                                    : Icons.bolt_outlined,
                                size: 20,
                                color: _showQuickPrompts
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              semanticLabel: 'Toggle quick prompts',
                              tooltip: 'Quick prompts',
                              onPressed: () {
                                setState(
                                  () => _showQuickPrompts = !_showQuickPrompts,
                                );
                              },
                            ),

                            const SizedBox(width: 4),

                            // Model picker pill
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  space.radiusFull,
                                ),
                                onTap: () => ModelPickerSheet.show(context),
                                child: MitraPill(
                                  label: prefs.modelId,
                                  icon: Icons.auto_awesome,
                                  compact: true,
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Send / Stop button
                            if (widget.isStreaming)
                              FilledButton(
                                onPressed: _handleCancel,
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.status.danger.color,
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.square(sendButtonSize),
                                  maximumSize: Size.square(sendButtonSize),
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            else
                              FilledButton(
                                onPressed: canSend ? _handleSend : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: canSend
                                      ? theme.colorScheme.primary
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  foregroundColor: canSend
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.35),
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.square(sendButtonSize),
                                  maximumSize: Size.square(sendButtonSize),
                                  elevation: 0,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
