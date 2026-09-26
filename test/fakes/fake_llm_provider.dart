import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mitra/domain/agent/tool_descriptor.dart';
import 'package:mitra/integrations/llm/llm_provider.dart';
import 'package:mitra/integrations/llm/llm_types.dart';

class FakeLlmProvider implements LlmProvider {
  FakeLlmProvider({
    required this.id,
    this.scriptedEvents = const [],
    this.onStreamChat,
    this.neverCloses = false,
  });

  @override
  final String id;

  final List<LlmStreamEvent> scriptedEvents;
  final Stream<LlmStreamEvent> Function({
    required List<LlmMessage> history,
    required List<ToolDescriptor> tools,
    required String modelId,
  })? onStreamChat;

  final bool neverCloses;

  @override
  List<ModelOption> get models => [
        ModelOption(
          id: '$id-test-model',
          name: 'Test Model',
          providerId: id,
        ),
      ];

  @override
  bool get supportsVision => true;

  @override
  bool get supportsTools => true;

  final List<List<LlmMessage>> recordedHistories = [];

  @override
  Stream<LlmStreamEvent> streamChat({
    required List<LlmMessage> history,
    required List<ToolDescriptor> tools,
    required String systemPrompt,
    required String modelId,
    CancelToken? cancelToken,
  }) {
    recordedHistories.add(List<LlmMessage>.from(history));
    if (onStreamChat != null) {
      return onStreamChat!(history: history, tools: tools, modelId: modelId);
    }

    final controller = StreamController<LlmStreamEvent>();
    cancelToken?.whenCancel.then((_) {
      if (!controller.isClosed) {
        controller.close();
      }
    });

    scheduleMicrotask(() async {
      for (final event in scriptedEvents) {
        if (controller.isClosed) break;
        controller.add(event);
      }
      if (!neverCloses && !controller.isClosed) {
        await controller.close();
      }
    });

    return controller.stream;
  }
}
