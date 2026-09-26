import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../../core/logging/logger.dart';
import '../application/share_inbox.dart';

class MobileShareSource {
  MobileShareSource(this._container);

  final ProviderContainer _container;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  void initialize() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // 1. Warm share stream (when app is in background or running)
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          if (files.isNotEmpty) {
            _handleSharedFiles(files);
          }
        },
        onError: (Object e) {
          AppLogger.error('Error on mobile share stream', e);
        },
      );

      // 2. Cold start share (when app was launched via share sheet)
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) {
          _handleSharedFiles(files);
          ReceiveSharingIntent.instance.reset();
        }
      });
    } catch (e) {
      AppLogger.warning('MobileShareSource init failed: $e');
    }
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    final paths = files.map((f) => f.path).toList();
    _container.read(shareInboxProvider.notifier).ingestFilePaths(paths);
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
