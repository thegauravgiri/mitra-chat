import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../conversations/application/conversation_list_controller.dart';
import 'tool_inspector_pane.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeConversationIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: ToolInspectorPane(
        conversationId: activeId,
      ),
    );
  }
}
