import 'package:flutter/material.dart';
import '../../../app/theme/tokens.dart';
import '../application/share_inbox.dart';
import 'incoming_share_sheet.dart';

Future<void> showAdaptiveShare(
  BuildContext context, {
  required IncomingShareItem item,
  required void Function(String targetId, String prompt) onTargetSelected,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final isCompact = width < 600;

  if (isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IncomingShareSheet(
        shareItem: item,
        onTargetSelected: onTargetSelected,
      ),
    );
  } else {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.space.radiusLg)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: IncomingShareSheet(
            shareItem: item,
            onTargetSelected: onTargetSelected,
          ),
        ),
      ),
    );
  }
}
