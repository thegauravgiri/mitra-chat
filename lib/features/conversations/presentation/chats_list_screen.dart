import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../application/conversation_list_controller.dart';
import 'conversation_list_pane.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConversationListPane(
      selectedConversationId: null,
      onSelectConversation: (id) {
        ref.read(activeConversationIdProvider.notifier).state = id;
        context.push('/chats/$id');
      },
      onOpenSettings: () => showSettingsDialog(context),
    );
  }
}
