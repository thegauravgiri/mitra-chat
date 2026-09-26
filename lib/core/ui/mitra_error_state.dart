import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';
import '../failures.dart';

class MitraErrorState extends StatefulWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;

  const MitraErrorState({
    super.key,
    this.error,
    this.message,
    this.onRetry,
  });

  @override
  State<MitraErrorState> createState() => _MitraErrorStateState();
}

class _MitraErrorStateState extends State<MitraErrorState> {
  bool _showDetails = false;

  String _formatError(Object? err) {
    if (widget.message != null && widget.message!.isNotEmpty) {
      return widget.message!;
    }
    if (err is AppFailure) {
      return err.message;
    }
    if (err != null) {
      final str = err.toString();
      if (str.startsWith('Exception: ')) {
        return str.substring('Exception: '.length);
      }
      return str;
    }
    return 'An unexpected error occurred.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final humanMessage = _formatError(widget.error);
    final rawError = widget.error?.toString();

    return Center(
      child: Padding(
        padding: EdgeInsets.all(space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: status.danger.container,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: status.danger.color,
              ),
            ),
            SizedBox(height: space.md),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: space.xs),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: space.readingMeasureMax * 0.7),
              child: Text(
                humanMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.onRetry != null) ...[
              SizedBox(height: space.lg),
              FilledButton.tonalIcon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
            if (rawError != null && rawError != humanMessage) ...[
              SizedBox(height: space.sm),
              TextButton(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                child: Text(_showDetails ? 'Hide details' : 'Show details'),
              ),
              if (_showDetails) ...[
                SizedBox(height: space.xs),
                Container(
                  padding: EdgeInsets.all(space.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(space.radiusMd),
                  ),
                  constraints: BoxConstraints(maxWidth: space.readingMeasureMax),
                  child: SelectableText(
                    rawError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
