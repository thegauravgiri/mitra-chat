import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/id.dart';

class StoredAttachmentInfo {
  const StoredAttachmentInfo({
    required this.id,
    required this.file,
    required this.relativePath,
    this.thumbFile,
    this.thumbRelativePath,
    required this.mimeType,
    required this.byteSize,
    this.width,
    this.height,
  });

  final String id;
  final File file;
  final String relativePath;
  final File? thumbFile;
  final String? thumbRelativePath;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
}

class AttachmentStore {
  AttachmentStore([Directory? baseDir]) : _customBaseDir = baseDir;

  final Directory? _customBaseDir;

  Future<Directory> _getAttachmentsDir() async {
    if (_customBaseDir != null) {
      final dir = Directory(p.join(_customBaseDir.path, 'attachments'));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appSupport.path, 'attachments'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves raw image bytes to disk, generates a thumbnail (<=512px),
  /// and caps resolution to <=4096px if larger.
  Future<StoredAttachmentInfo> saveImageBytes(
    Uint8List bytes, {
    String extension = 'png',
    String mimeType = 'image/png',
  }) async {
    final id = generateId();
    final dir = await _getAttachmentsDir();
    final ext = extension.replaceAll('.', '');

    // Decode image dimensions using Flutter engine codec
    int? originalWidth;
    int? originalHeight;
    Uint8List processedBytes = bytes;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      originalWidth = frame.image.width;
      originalHeight = frame.image.height;

      // Downsize if long edge > 4096
      final maxEdge = originalWidth > originalHeight ? originalWidth : originalHeight;
      if (maxEdge > 4096) {
        final scale = 4096.0 / maxEdge;
        final targetW = (originalWidth * scale).round();
        final targetH = (originalHeight * scale).round();
        final scaledCodec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: targetW,
          targetHeight: targetH,
        );
        final scaledFrame = await scaledCodec.getNextFrame();
        final byteData = await scaledFrame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          processedBytes = byteData.buffer.asUint8List();
          originalWidth = targetW;
          originalHeight = targetH;
        }
      }
    } catch (_) {
      // Fallback to raw bytes if decoding fails
    }

    final fileName = '$id.$ext';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(processedBytes);

    // Generate thumbnail <=512px
    String? thumbRelativePath;
    File? thumbFile;
    try {
      final thumbCodec = await ui.instantiateImageCodec(
        processedBytes,
        targetWidth: 512,
      );
      final thumbFrame = await thumbCodec.getNextFrame();
      final thumbByteData =
          await thumbFrame.image.toByteData(format: ui.ImageByteFormat.png);
      if (thumbByteData != null) {
        final thumbName = '${id}_thumb.png';
        thumbFile = File(p.join(dir.path, thumbName));
        await thumbFile.writeAsBytes(thumbByteData.buffer.asUint8List());
        thumbRelativePath = thumbName;
      }
    } catch (_) {
      // Thumbnail optional fallback
    }

    return StoredAttachmentInfo(
      id: id,
      file: file,
      relativePath: fileName,
      thumbFile: thumbFile,
      thumbRelativePath: thumbRelativePath,
      mimeType: mimeType,
      byteSize: processedBytes.length,
      width: originalWidth,
      height: originalHeight,
    );
  }

  /// Saves an existing image file from a path (e.g. from share sheet or picker).
  Future<StoredAttachmentInfo> saveImageFile(File sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final ext = p.extension(sourceFile.path).replaceAll('.', '');
    final mime = switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
    return saveImageBytes(bytes, extension: ext.isEmpty ? 'png' : ext, mimeType: mime);
  }

  Future<File> resolveFile(String relativePath) async {
    final dir = await _getAttachmentsDir();
    return File(p.join(dir.path, relativePath));
  }

  Future<void> deleteAttachment(String relativePath, {String? thumbRelativePath}) async {
    try {
      final file = await resolveFile(relativePath);
      if (file.existsSync()) {
        await file.delete();
      }
      if (thumbRelativePath != null) {
        final thumb = await resolveFile(thumbRelativePath);
        if (thumb.existsSync()) {
          await thumb.delete();
        }
      }
    } catch (_) {}
  }
}
