import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/ui/mitra_code_block.dart';
import '../../../core/ui/mitra_pill.dart';
import '../../../data/db/database.dart';
import '../../../domain/models/enums.dart';

class ToolCallTile extends StatefulWidget {
  const ToolCallTile({
    super.key,
    required this.invocation,
    this.onUndo,
  });

  final ToolInvocation invocation;
  final VoidCallback? onUndo;

  @override
  State<ToolCallTile> createState() => _ToolCallTileState();
}

class _ToolCallTileState extends State<ToolCallTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final inv = widget.invocation;

    final (statusIcon, statusColor, statusLabel) = switch (inv.status) {
      ToolStatus.pending => (
          Icons.schedule_rounded,
          status.warning,
          'Pending',
        ),
      ToolStatus.running => (
          Icons.autorenew_rounded,
          status.info,
          'Running',
        ),
      ToolStatus.ok => (
          Icons.check_circle_rounded,
          status.success,
          'Success',
        ),
      ToolStatus.error => (
          Icons.error_rounded,
          status.danger,
          'Failed',
        ),
      ToolStatus.undone => (
          Icons.undo_rounded,
          status.neutral,
          'Undone',
        ),
    };

    final durationText = inv.durationMs != null ? ' (${inv.durationMs}ms)' : '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: space.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(space.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(space.radiusMd),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.sm),
              child: Row(
                children: [
                  if (inv.status == ToolStatus.running)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: status.info.color,
                      ),
                    )
                  else
                    Icon(statusIcon, size: 16, color: statusColor.color),
                  SizedBox(width: space.sm),
                  Expanded(
                    child: Text(
                      '${inv.toolName}$durationText',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTypography.monoFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MitraPill(
                    label: statusLabel,
                    status: statusColor,
                    compact: true,
                  ),
                  SizedBox(width: space.xs),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: MitraMotion.of(context, MitraMotion.standard),
            curve: MitraMotion.standardCurve,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: EdgeInsets.all(space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ARGUMENTS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontFamily: AppTypography.monoFamily,
                              ),
                            ),
                            SizedBox(height: space.xs),
                            MitraCodeBlock(
                              code: _prettyJson(inv.argumentsJson),
                              language: 'json',
                            ),
                            if (inv.resultJson != null) ...[
                              SizedBox(height: space.md),
                              Text(
                                'RESULT',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontFamily: AppTypography.monoFamily,
                                ),
                              ),
                              SizedBox(height: space.xs),
                              MitraCodeBlock(
                                code: _prettyJson(inv.resultJson!),
                                language: 'json',
                              ),
                            ],
                            if (inv.errorMessage != null) ...[
                              SizedBox(height: space.md),
                              Text(
                                'ERROR',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: status.danger.color,
                                  fontFamily: AppTypography.monoFamily,
                                ),
                              ),
                              SizedBox(height: space.xs),
                              MitraCodeBlock(
                                code: inv.errorMessage!,
                                language: 'text',
                              ),
                            ],
                            if (inv.status == ToolStatus.ok && widget.onUndo != null) ...[
                              SizedBox(height: space.md),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: widget.onUndo,
                                  icon: const Icon(Icons.undo_rounded, size: 16),
                                  label: const Text('Undo action'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: status.danger.color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _prettyJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return jsonStr;
    }
  }
}
