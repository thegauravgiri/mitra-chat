import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import 'mitra_icon_button.dart';

class MitraCodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final int maxLinesCollapsed;

  const MitraCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.maxLinesCollapsed = 12,
  });

  @override
  State<MitraCodeBlock> createState() => _MitraCodeBlockState();
}

class _MitraCodeBlockState extends State<MitraCodeBlock> {
  bool _expanded = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final lines = widget.code.split('\n');
    final hasOverflow = lines.length > widget.maxLinesCollapsed;

    final displayCode = (!hasOverflow || _expanded)
        ? widget.code
        : lines.take(widget.maxLinesCollapsed).join('\n');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(space.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.xs),
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            child: Row(
              children: [
                if (widget.language != null && widget.language!.isNotEmpty)
                  Text(
                    widget.language!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: AppTypography.monoFamily,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'CODE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: AppTypography.monoFamily,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                MitraIconButton(
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                    color: _copied ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  semanticLabel: _copied ? 'Copied' : 'Copy code',
                  tooltip: _copied ? 'Copied!' : 'Copy',
                  onPressed: _copy,
                ),
              ],
            ),
          ),
          // Code content with horizontal scroll
          Padding(
            padding: EdgeInsets.all(space.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                displayCode,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppTypography.monoFamily,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),
          // Show more / less button
          if (hasOverflow)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: space.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show all (${lines.length} lines)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
