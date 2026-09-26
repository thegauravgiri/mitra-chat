import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers.dart';
import '../../../data/stores/attachment_store.dart';

class IncomingShareItem {
  const IncomingShareItem({
    required this.attachments,
    this.sharedText,
  });

  final List<StoredAttachmentInfo> attachments;
  final String? sharedText;
}

final shareInboxProvider =
    StateNotifierProvider<ShareInboxNotifier, IncomingShareItem?>((ref) {
  final attachmentStore = ref.watch(attachmentStoreProvider);
  return ShareInboxNotifier(attachmentStore);
});

class ShareInboxNotifier extends StateNotifier<IncomingShareItem?> {
  ShareInboxNotifier(this._attachmentStore) : super(null);

  final AttachmentStore _attachmentStore;

  Future<void> ingestFilePaths(
    List<String> filePaths, {
    String? text,
  }) async {
    final timeline = developer.TimelineTask()..start('ShareInbox.ingestFilePaths');
    final attachments = <StoredAttachmentInfo>[];
    for (final path in filePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final stored = await _attachmentStore.saveImageFile(file);
        attachments.add(stored);
      }
    }

    if (attachments.isNotEmpty || (text != null && text.isNotEmpty)) {
      state = IncomingShareItem(
        attachments: attachments,
        sharedText: text,
      );
    }
    timeline.finish();
  }

  Future<void> ingestImageBytes(
    Uint8List bytes, {
    String extension = 'png',
    String? text,
  }) async {
    final timeline = developer.TimelineTask()..start('ShareInbox.ingestImageBytes');
    final stored = await _attachmentStore.saveImageBytes(bytes, extension: extension);
    state = IncomingShareItem(
      attachments: [stored],
      sharedText: text,
    );
    timeline.finish();
  }

  void consume() {
    state = null;
  }
}
