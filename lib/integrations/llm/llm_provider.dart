import 'dart:async';
import 'package:dio/dio.dart';
import '../../domain/agent/tool_descriptor.dart';
import 'llm_types.dart';

abstract interface class LlmProvider {
  String get id;
  List<ModelOption> get models;
  bool get supportsVision;
  bool get supportsTools;

  Stream<LlmStreamEvent> streamChat({
    required List<LlmMessage> history,
    required List<ToolDescriptor> tools,
    required String systemPrompt,
    required String modelId,
    CancelToken? cancelToken,
  });
}
