import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class MitraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const MitraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: space.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              SizedBox(height: space.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: space.readingMeasureMax * 0.6),
                child: Text(
                  body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: space.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
