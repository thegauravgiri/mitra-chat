import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/ui/mitra_icon_button.dart';

class AttachmentViewerModal extends StatefulWidget {
  final File file;
  final String? heroTag;
  final String? title;

  const AttachmentViewerModal({
    super.key,
    required this.file,
    this.heroTag,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required File file,
    String? heroTag,
    String? title,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (context, animation, secondaryAnimation) => AttachmentViewerModal(
          file: file,
          heroTag: heroTag,
          title: title,
        ),
      ),
    );
  }

  @override
  State<AttachmentViewerModal> createState() => _AttachmentViewerModalState();
}

class _AttachmentViewerModalState extends State<AttachmentViewerModal> {
  double _dragOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.file(
      widget.file,
      fit: BoxFit.contain,
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    final opacity = (1.0 - (_dragOffset.abs() / 300.0)).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 0 || _dragOffset > 0) {
            setState(() {
              _dragOffset += details.primaryDelta ?? 0;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 100 || (details.primaryVelocity != null && details.primaryVelocity! > 500)) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _dragOffset = 0;
            });
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: imageWidget,
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      if (widget.title != null)
                        Expanded(
                          child: Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      MitraIconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        semanticLabel: 'Close attachment viewer',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
