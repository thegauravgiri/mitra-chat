import 'package:flutter/material.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/mitra_icon_button.dart';
import '../../../data/stores/attachment_store.dart';
import 'attachment_viewer.dart';

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    super.key,
    required this.info,
    required this.onRemove,
  });

  final StoredAttachmentInfo info;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final targetFile = info.file;

    return InkWell(
      borderRadius: BorderRadius.circular(space.radiusMd),
      onTap: () => AttachmentViewerModal.show(
        context,
        file: targetFile,
        title: 'Attachment (${(info.byteSize / 1024).toStringAsFixed(0)} KB)',
      ),
      child: Container(
        margin: EdgeInsets.only(right: space.sm),
        padding: EdgeInsets.fromLTRB(space.xs, space.xs, space.xs, space.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(space.radiusMd),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(space.radiusSm),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Image.file(
                  info.thumbFile ?? info.file,
                  cacheWidth: (36 * pixelRatio).round(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            SizedBox(width: space.sm),
            Text(
              'Image (${(info.byteSize / 1024).toStringAsFixed(0)} KB)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: space.xs),
            MitraIconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              minTapTarget: 32,
              padding: EdgeInsets.all(space.xs * 0.5),
              semanticLabel: 'Remove attachment',
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
