import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/tokens.dart';

class MessageGroupHeader extends StatelessWidget {
  final DateTime date;

  const MessageGroupHeader({super.key, required this.date});

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    if (now.difference(dt).inDays < 7) {
      return DateFormat.EEEE().format(dt);
    }
    return DateFormat('MMMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.md),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: space.md),
            child: Text(
              _formatDate(date),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
