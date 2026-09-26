import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import '../application/share_inbox.dart';

class DesktopDropTargetWrapper extends ConsumerWidget {
  const DesktopDropTargetWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux && !Platform.isIOS) {
      return child;
    }

    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (event.session.items.any((item) =>
            item.canProvide(Formats.png) ||
            item.canProvide(Formats.jpeg) ||
            item.canProvide(Formats.fileUri))) {
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onPerformDrop: (event) async {
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;

          if (item.canProvide(Formats.png)) {
            reader.getFile(Formats.png, (file) async {
              final stream = file.getStream();
              final bytesBuilder = BytesBuilder();
              await for (final chunk in stream) {
                bytesBuilder.add(chunk);
              }
              unawaited(ref
                  .read(shareInboxProvider.notifier)
                  .ingestImageBytes(bytesBuilder.toBytes()));
            });
          } else if (item.canProvide(Formats.jpeg)) {
            reader.getFile(Formats.jpeg, (file) async {
              final stream = file.getStream();
              final bytesBuilder = BytesBuilder();
              await for (final chunk in stream) {
                bytesBuilder.add(chunk);
              }
              unawaited(ref
                  .read(shareInboxProvider.notifier)
                  .ingestImageBytes(bytesBuilder.toBytes(), extension: 'jpg'));
            });
          } else if (item.canProvide(Formats.fileUri)) {
            reader.getValue(Formats.fileUri, (Uri? uri) {
              if (uri != null && uri.isScheme('file')) {
                unawaited(ref
                    .read(shareInboxProvider.notifier)
                    .ingestFilePaths([uri.toFilePath()]));
              }
            });
          }
        }
      },
      child: child,
    );
  }
}

class DesktopClipboardService {
  DesktopClipboardService._();

  static Future<bool> handlePaste(WidgetRef ref) async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux && !Platform.isIOS) {
      return false;
    }

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return false;

    final reader = await clipboard.read();
    if (reader.canProvide(Formats.png)) {
      reader.getFile(Formats.png, (file) async {
        final stream = file.getStream();
        final bytesBuilder = BytesBuilder();
        await for (final chunk in stream) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.toBytes();
        unawaited(ref.read(shareInboxProvider.notifier).ingestImageBytes(bytes));
      });
      return true;
    } else if (reader.canProvide(Formats.jpeg)) {
      reader.getFile(Formats.jpeg, (file) async {
        final stream = file.getStream();
        final bytesBuilder = BytesBuilder();
        await for (final chunk in stream) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.toBytes();
        unawaited(ref
            .read(shareInboxProvider.notifier)
            .ingestImageBytes(bytes, extension: 'jpg'));
      });
      return true;
    }

    return false;
  }
}
