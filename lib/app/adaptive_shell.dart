import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/breakpoints.dart';
import '../data/providers.dart';
import '../features/chat/presentation/chat_header.dart';
import '../features/chat/presentation/chat_pane.dart';
import '../features/chat/presentation/empty_chat_detail_pane.dart';
import '../features/conversations/application/conversation_list_controller.dart';
import '../features/conversations/presentation/conversation_list_pane.dart';
import '../features/inspector/presentation/tool_inspector_pane.dart';
import '../features/settings/presentation/settings_dialog.dart';
import '../features/share/application/share_inbox.dart';
import '../features/share/platform/desktop_share_source.dart';
import '../features/share/presentation/share_presenter.dart';
import '../core/ui/mitra_icon_button.dart';
import 'shortcuts.dart';
import 'theme/motion.dart';
import 'theme/tokens.dart';

class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key, this.navigationShell, this.conversationId});

  final StatefulNavigationShell? navigationShell;
  final String? conversationId;

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  double? _listPaneWidth;
  bool? _showInspector;
  bool? _sidebarCollapsed;
  Timer? _debounceResizeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = ref.read(prefsStoreProvider);
      setState(() {
        _listPaneWidth = prefs.listPaneWidth;
        _showInspector = prefs.inspectorVisible;
        _sidebarCollapsed = prefs.sidebarCollapsed;
      });
    });
  }

  @override
  void dispose() {
    _debounceResizeTimer?.cancel();
    super.dispose();
  }

  void _onResize(double delta, MitraSpacing space) {
    final currentWidth = _listPaneWidth ?? space.listPaneDefault;
    final newWidth = (currentWidth + delta).clamp(
      space.listPaneMin,
      space.listPaneMax,
    );
    setState(() => _listPaneWidth = newWidth);

    _debounceResizeTimer?.cancel();
    _debounceResizeTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(prefsStoreProvider).setListPaneWidth(newWidth));
    });
  }

  // The sidebar and inspector are only guaranteed to both fit expanded on a
  // genuinely wide window; below that, opening one collapses the other
  // (matching the conversation sidebar's existing rail-collapse rather than
  // silently refusing to open either pane).
  bool _fitsBothExpanded(double width) =>
      WindowSizeClass.fromWidth(width).showsInspectorPane;

  void _toggleInspector() {
    final opening = !(_showInspector ?? true);
    final width = MediaQuery.sizeOf(context).width;
    final shouldCollapseSidebar =
        opening && !(_sidebarCollapsed ?? false) && !_fitsBothExpanded(width);

    setState(() {
      _showInspector = opening;
      if (shouldCollapseSidebar) _sidebarCollapsed = true;
    });

    ref.read(prefsStoreProvider).setInspectorVisible(opening);
    if (shouldCollapseSidebar) {
      ref.read(prefsStoreProvider).setSidebarCollapsed(true);
    }
  }

  void _toggleSidebar() {
    final currentlyCollapsed = _sidebarCollapsed ?? false;
    final nextCollapsed = !currentlyCollapsed;
    final isExpanding = currentlyCollapsed;
    final width = MediaQuery.sizeOf(context).width;
    final shouldCloseInspector =
        isExpanding && (_showInspector ?? true) && !_fitsBothExpanded(width);

    setState(() {
      _sidebarCollapsed = nextCollapsed;
      if (shouldCloseInspector) _showInspector = false;
    });

    ref.read(prefsStoreProvider).setSidebarCollapsed(nextCollapsed);
    if (shouldCloseInspector) {
      ref.read(prefsStoreProvider).setInspectorVisible(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to incoming shares and show adaptive dialog/sheet
    ref.listen<IncomingShareItem?>(shareInboxProvider, (previous, next) {
      if (next != null) {
        showAdaptiveShare(
          context,
          item: next,
          onTargetSelected: (targetId, prompt) {
            ref.read(activeConversationIdProvider.notifier).state = targetId;
            context.push('/chats/$targetId');
          },
        );
      }
    });

    return Shortcuts(
      shortcuts: MitraShortcuts.defaultBindings,
      child: Actions(
        actions: {
          NewConversationIntent: CallbackAction<NewConversationIntent>(
            onInvoke: (_) async {
              final convo = await ref
                  .read(conversationListControllerProvider)
                  .createNewConversation();
              ref.read(activeConversationIdProvider.notifier).state = convo.id;
              if (context.mounted) {
                unawaited(context.push('/chats/${convo.id}'));
              }
              return null;
            },
          ),
          ToggleInspectorIntent: CallbackAction<ToggleInspectorIntent>(
            onInvoke: (_) {
              _toggleInspector();
              return null;
            },
          ),
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              _toggleSidebar();
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              unawaited(showSettingsDialog(context));
              return null;
            },
          ),
          ShowShortcutsIntent: CallbackAction<ShowShortcutsIntent>(
            onInvoke: (_) {
              MitraShortcuts.showCheatsheet(context);
              return null;
            },
          ),
        },
        child: DesktopDropTargetWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
              final heightClass = WindowHeightClass.fromHeight(
                constraints.maxHeight,
              );
              final density = sizeClass.isCompact
                  ? MitraDensity.comfortable
                  : (sizeClass.showsInspectorPane
                        ? MitraDensity.compact
                        : MitraDensity.standard);
              final spacing = MitraSpacing.forDensity(density);
              final outerTheme = Theme.of(context);
              final resolvedTheme = outerTheme.copyWith(
                extensions: [
                  spacing,
                  outerTheme.extension<MitraStatusColors>() ??
                      MitraStatusColors.light,
                ],
              );

              return Theme(
                data: resolvedTheme,
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final space = context.space;
                    final activeConvoId =
                        widget.conversationId ??
                        ref.watch(activeConversationIdProvider);

                    // 1. Compact Layout (<600px) or phone landscape (height compact)
                    if (sizeClass.isCompact || heightClass.isCompact) {
                      if (widget.navigationShell != null) {
                        return Scaffold(body: widget.navigationShell!);
                      }

                      if (activeConvoId != null) {
                        return Scaffold(
                          body: Column(
                            children: [
                              ChatHeader(
                                conversationId: activeConvoId,
                                isCompact: true,
                                onBack: () {
                                  ref
                                          .read(
                                            activeConversationIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                  if (context.canPop()) {
                                    context.pop();
                                  }
                                },
                              ),
                              Expanded(
                                child: ChatPane(conversationId: activeConvoId),
                              ),
                            ],
                          ),
                        );
                      }

                      return Scaffold(
                        body: ConversationListPane(
                          selectedConversationId: null,
                          onSelectConversation: (id) {
                            ref
                                    .read(activeConversationIdProvider.notifier)
                                    .state =
                                id;
                            context.push('/chats/$id');
                          },
                          onOpenSettings: () => showSettingsDialog(context),
                        ),
                      );
                    }

                    // 2. Multi-pane (Tablet / Desktop): Single Sidebar Layout
                    final double paneWidth = sizeClass.showsInspectorPane
                        ? (_listPaneWidth ?? space.listPaneDefault)
                        : (sizeClass == WindowSizeClass.medium ? 300.0 : 320.0);
                    final isSidebarCollapsed = _sidebarCollapsed ?? false;
                    const double collapsedRailWidth = 56.0;
                    final isInspectorOpen = _showInspector ?? true;

                    // Safety net for the passive case (rotation, cold start
                    // with default prefs): if both the sidebar and inspector
                    // would render expanded on a window too narrow for both
                    // (see _fitsBothExpanded), collapse the sidebar right
                    // after this frame. The explicit toggle handlers
                    // (_toggleInspector / _toggleSidebar) handle the
                    // interactive case immediately; this just keeps things
                    // consistent if the window changes size out from under
                    // an already-settled layout. It self-corrects in one
                    // frame and never loops, since the condition is false
                    // again once the sidebar is collapsed.
                    if (isInspectorOpen &&
                        !isSidebarCollapsed &&
                        !_fitsBothExpanded(constraints.maxWidth)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _sidebarCollapsed = true);
                        unawaited(
                          ref
                              .read(prefsStoreProvider)
                              .setSidebarCollapsed(true),
                        );
                      });
                    }

                    final isNonChatBranch =
                        widget.navigationShell != null &&
                        widget.navigationShell!.currentIndex != 0;

                    return Scaffold(
                      body: Row(
                        children: [
                          // Single Unified Sidebar: Top New Chat & Search, Scrollable History, Bottom Settings
                          // ConversationListPane always lays out at its full `paneWidth` (via
                          // OverflowBox) so its header/search/list never see a narrow width mid
                          // -animation; ClipRect handles the visual reveal/hide instead. Swapping
                          // its `child` for a type that can't tolerate narrow widths while the
                          // container's width is still animating caused RenderFlex overflow storms
                          // (and an ANR) on real devices.
                          ClipRect(
                            child: AnimatedContainer(
                              duration: MitraMotion.of(
                                context,
                                MitraMotion.standard,
                              ),
                              curve: MitraMotion.emphasized,
                              width: isSidebarCollapsed
                                  ? collapsedRailWidth
                                  : paneWidth,
                              child: Stack(
                                children: [
                                  OverflowBox(
                                    alignment: Alignment.centerLeft,
                                    minWidth: paneWidth,
                                    maxWidth: paneWidth,
                                    child: IgnorePointer(
                                      ignoring: isSidebarCollapsed,
                                      child: AnimatedOpacity(
                                        duration: MitraMotion.of(
                                          context,
                                          MitraMotion.fast,
                                        ),
                                        opacity: isSidebarCollapsed ? 0.0 : 1.0,
                                        child: ConversationListPane(
                                          selectedConversationId:
                                              isNonChatBranch
                                              ? null
                                              : activeConvoId,
                                          onSelectConversation: (id) {
                                            if (widget.navigationShell !=
                                                    null &&
                                                widget
                                                        .navigationShell!
                                                        .currentIndex !=
                                                    0) {
                                              widget.navigationShell!.goBranch(
                                                0,
                                              );
                                            }
                                            ref
                                                    .read(
                                                      activeConversationIdProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                id;
                                          },
                                          onOpenSettings: () =>
                                              showSettingsDialog(context),
                                          onToggleCollapse: _toggleSidebar,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: collapsedRailWidth,
                                      child: IgnorePointer(
                                        ignoring: !isSidebarCollapsed,
                                        child: AnimatedOpacity(
                                          duration: MitraMotion.of(
                                            context,
                                            MitraMotion.fast,
                                          ),
                                          opacity: isSidebarCollapsed
                                              ? 1.0
                                              : 0.0,
                                          child: _CollapsedSidebarRail(
                                            onExpand: _toggleSidebar,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Resizable Handle (pointer / large+ only, sidebar expanded)
                          if (isSidebarCollapsed)
                            const VerticalDivider(width: 1, thickness: 1)
                          else if (sizeClass.showsInspectorPane)
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (details) =>
                                    _onResize(details.delta.dx, space),
                                child: Container(
                                  width: 8,
                                  color: Colors.transparent,
                                  child: Center(
                                    child: Container(
                                      width: 1,
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const VerticalDivider(width: 1, thickness: 1),

                          // Center Pane: Non-chat branch (Settings/Activity) OR Active Chat OR Empty State
                          Expanded(
                            child: isNonChatBranch
                                ? widget.navigationShell!
                                : (activeConvoId != null
                                      ? Column(
                                          children: [
                                            ChatHeader(
                                              conversationId: activeConvoId,
                                              isExpanded: true,
                                              showInspector: isInspectorOpen,
                                              onToggleInspector:
                                                  _toggleInspector,
                                            ),
                                            Expanded(
                                              child: ChatPane(
                                                conversationId: activeConvoId,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const EmptyChatDetailPane()),
                          ),

                          // Right Pane: Tool Inspector (toggled by the button on top right of conversation)
                          if (!isNonChatBranch &&
                              isInspectorOpen &&
                              activeConvoId != null) ...[
                            const VerticalDivider(width: 1, thickness: 1),
                            SizedBox(
                              width: space.inspectorWidth,
                              child: ToolInspectorPane(
                                conversationId: activeConvoId,
                                onClose: _toggleInspector,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CollapsedSidebarRail extends StatelessWidget {
  const _CollapsedSidebarRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MitraIconButton(
              icon: const Icon(Icons.menu_rounded),
              semanticLabel: 'Expand sidebar',
              tooltip: 'Expand sidebar',
              onPressed: onExpand,
            ),
          ),
        ),
      ),
    );
  }
}
