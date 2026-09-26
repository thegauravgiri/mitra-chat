import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../data/stores/attachment_store.dart';

class AttachSheet extends ConsumerWidget {
  final ValueChanged<StoredAttachmentInfo> onAttachmentAdded;

  const AttachSheet({
    super.key,
    required this.onAttachmentAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<StoredAttachmentInfo> onAttachmentAdded,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => AttachSheet(onAttachmentAdded: onAttachmentAdded),
    );
  }

  Future<void> _pickCamera(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final store = ref.read(attachmentStoreProvider);
      final stored = await store.saveImageFile(File(image.path));
      onAttachmentAdded(stored);
      navigator.pop();
    }
  }

  Future<void> _pickGallery(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final store = ref.read(attachmentStoreProvider);
      final stored = await store.saveImageFile(File(image.path));
      onAttachmentAdded(stored);
      navigator.pop();
    }
  }

  Future<void> _pickFiles(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final store = ref.read(attachmentStoreProvider);
        final stored = await store.saveImageFile(File(path));
        onAttachmentAdded(stored);
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final space = context.space;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: space.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xs),
              child: Text(
                'Attach Image or Note',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture notes or whiteboard drawings'),
              onTap: () => _pickCamera(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              subtitle: const Text('Pick screenshot or photo from device'),
              onTap: () => _pickGallery(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Browse Files'),
              subtitle: const Text('Select image file from storage'),
              onTap: () => _pickFiles(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
