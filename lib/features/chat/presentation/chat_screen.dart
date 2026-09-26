import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'chat_header.dart';
import 'chat_pane.dart';

class ChatScreen extends ConsumerWidget {
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: ChatHeader(
        conversationId: conversationId,
        isCompact: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/chats');
          }
        },
      ),
      body: ChatPane(conversationId: conversationId),
    );
  }
}
