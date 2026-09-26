import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class MitraIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? tooltip;
  final double iconSize;
  final Color? color;
  final Color? hoverColor;
  final EdgeInsetsGeometry? padding;
  final double? minTapTarget;

  const MitraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
    this.iconSize = 20.0,
    this.color,
    this.hoverColor,
    this.padding,
    this.minTapTarget,
  });

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final targetSize = minTapTarget ?? space.minTapTarget;
    final tipText = tooltip ?? semanticLabel;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tipText,
        waitDuration: const Duration(milliseconds: 600),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: targetSize,
            minHeight: targetSize,
          ),
          child: IconButton(
            icon: icon,
            iconSize: iconSize,
            color: color,
            hoverColor: hoverColor,
            padding: padding ?? EdgeInsets.all(space.sm),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
