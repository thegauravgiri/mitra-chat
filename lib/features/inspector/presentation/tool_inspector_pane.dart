import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_empty_state.dart';
import '../../../core/ui/mitra_error_state.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../domain/models/enums.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/presentation/tool_call_tile.dart';

enum InspectorFilter { all, running, failed }

class ToolInspectorPane extends ConsumerStatefulWidget {
  const ToolInspectorPane({
    super.key,
    this.conversationId,
    this.onClose,
  });

  final String? conversationId;
  final VoidCallback? onClose;

  @override
  ConsumerState<ToolInspectorPane> createState() => _ToolInspectorPaneState();
}

class _ToolInspectorPaneState extends ConsumerState<ToolInspectorPane> {
  InspectorFilter _filter = InspectorFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    if (widget.conversationId == null) {
      return Material(
        color: theme.colorScheme.surfaceContainerLowest,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.sm),
                child: Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 20, color: theme.colorScheme.primary),
                    SizedBox(width: space.sm),
                    Text(
                      'Tool Inspector',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (widget.onClose != null)
                      MitraIconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        semanticLabel: 'Close tool inspector',
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(
                child: MitraEmptyState(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'No active conversation',
                  body: 'Select a conversation to view its tool invocations.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final convoId = widget.conversationId!;
    final invocationsAsync = ref.watch(conversationToolInvocationsProvider(convoId));
    final chatController = ref.read(chatControllerProvider(convoId).notifier);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.sm),
              child: Row(
                children: [
                  Icon(Icons.hub_outlined, size: 20, color: theme.colorScheme.primary),
                  SizedBox(width: space.sm),
                  Text(
                    'Tool Inspector',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onClose != null)
                    MitraIconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      semanticLabel: 'Close tool inspector',
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Invocations & Filters
            Expanded(
              child: invocationsAsync.when(
                data: (invocations) {
                  if (invocations.isEmpty) {
                    return const MitraEmptyState(
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'No tool calls yet',
                      body: 'Tool invocations from Notion and MCP will appear here in real-time.',
                    );
                  }

                  final runningCount = invocations.where((i) => i.status == ToolStatus.running).length;
                  final failedCount = invocations.where((i) => i.status == ToolStatus.error).length;
                  final totalDurationMs = invocations.fold<int>(0, (sum, i) => sum + (i.durationMs ?? 0));

                  final filteredInvocations = switch (_filter) {
                    InspectorFilter.all => invocations,
                    InspectorFilter.running => invocations.where((i) => i.status == ToolStatus.running).toList(),
                    InspectorFilter.failed => invocations.where((i) => i.status == ToolStatus.error).toList(),
                  };

                  return Column(
                    children: [
                      // Summary strip
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.xs),
                        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${invocations.length} calls · $failedCount failed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(totalDurationMs / 1000).toStringAsFixed(1)}s total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Segmented Filter
                      Padding(
                        padding: EdgeInsets.all(space.sm),
                        child: SegmentedButton<InspectorFilter>(
                          segments: [
                            const ButtonSegment(
                              value: InspectorFilter.all,
                              label: Text('All'),
                            ),
                            ButtonSegment(
                              value: InspectorFilter.running,
                              label: Text('Running ($runningCount)'),
                            ),
                            ButtonSegment(
                              value: InspectorFilter.failed,
                              label: Text('Failed ($failedCount)'),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (set) => setState(() => _filter = set.first),
                        ),
                      ),

                      Expanded(
                        child: filteredInvocations.isEmpty
                            ? Center(
                                child: Text(
                                  'No ${_filter.name} tool calls',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(space.sm),
                                itemCount: filteredInvocations.length,
                                itemBuilder: (context, index) {
                                  final inv = filteredInvocations[index];
                                  return ToolCallTile(
                                    invocation: inv,
                                    onUndo: () => chatController.undoToolInvocation(inv),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => MitraErrorState(
                  error: err,
                  onRetry: () => ref.invalidate(conversationToolInvocationsProvider(convoId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
