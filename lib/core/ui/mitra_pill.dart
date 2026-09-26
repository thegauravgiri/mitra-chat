import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class MitraPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final MitraStatusColor? status;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;
  final bool compact;

  const MitraPill({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.status,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    final bg = backgroundColor ?? status?.container ?? theme.colorScheme.surfaceContainerHigh;
    final fg = foregroundColor ?? status?.onContainer ?? theme.colorScheme.onSurfaceVariant;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          SizedBox(width: space.xs),
        ] else if (icon != null) ...[
          Icon(icon, size: compact ? 12 : 14, color: status?.color ?? fg),
          SizedBox(width: space.xs),
        ],
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final padding = compact
        ? EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs * 0.5)
        : EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs);

    if (onTap != null) {
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(space.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(space.radiusSm),
          child: Padding(
            padding: padding,
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(space.radiusSm),
      ),
      child: content,
    );
  }
}
