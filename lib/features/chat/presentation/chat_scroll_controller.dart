import 'package:flutter/material.dart';

class ChatScrollCoordinator {
  final ScrollController scrollController = ScrollController();
  bool _userPinnedToBottom = true;
  int _unreadCountWhileAway = 0;
  VoidCallback? onStateChanged;

  bool get userPinnedToBottom => _userPinnedToBottom;
  int get unreadCountWhileAway => _unreadCountWhileAway;

  void attach() {
    scrollController.addListener(_handleScroll);
  }

  void dispose() {
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final max = scrollController.position.maxScrollExtent;
    final current = scrollController.offset;
    final isAtBottom = (max - current) <= 120;

    if (isAtBottom != _userPinnedToBottom) {
      _userPinnedToBottom = isAtBottom;
      if (isAtBottom) {
        _unreadCountWhileAway = 0;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => onStateChanged?.call());
    }
  }

  void onNewContentArrived({bool isStreaming = false}) {
    if (_userPinnedToBottom) {
      _unreadCountWhileAway = 0;
      _scrollToBottom(isStreaming: isStreaming);
    } else {
      _unreadCountWhileAway++;
      WidgetsBinding.instance.addPostFrameCallback((_) => onStateChanged?.call());
    }
  }

  void jumpToLatest() {
    _userPinnedToBottom = true;
    _unreadCountWhileAway = 0;
    _scrollToBottom(isStreaming: false, forceAnimate: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => onStateChanged?.call());
  }

  void _scrollToBottom({bool isStreaming = false, bool forceAnimate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final max = scrollController.position.maxScrollExtent;
      final current = scrollController.offset;
      final distance = max - current;

      if (forceAnimate || (!isStreaming && distance > 200)) {
        scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(max);
      }
    });
  }
}
