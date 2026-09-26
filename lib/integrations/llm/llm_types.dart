import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../../domain/models/enums.dart';

class ModelOption {
  const ModelOption({
    required this.id,
    required this.name,
    required this.providerId,
    this.description,
    this.isDefault = false,
    this.isCheap = false,
  });

  final String id;
  final String name;
  final String providerId;
  final String? description;
  final bool isDefault;
  final bool isCheap;
}

const List<ModelOption> kAvailableModels = [
  // Google Gemini
  ModelOption(
    id: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    providerId: 'gemini',
    description: 'Fast, multimodal reasoning with high accuracy (Default)',
    isDefault: true,
  ),
  ModelOption(
    id: 'gemini-2.0-flash',
    name: 'Gemini 2.0 Flash',
    providerId: 'gemini',
    description: 'Next-gen multimodal reasoning and tool execution',
  ),
  ModelOption(
    id: 'gemini-2.0-flash-lite',
    name: 'Gemini 2.0 Flash Lite',
    providerId: 'gemini',
    description: 'Ultra-fast and cost-efficient for quick tasks & titling',
    isCheap: true,
  ),
  ModelOption(
    id: 'gemini-1.5-flash',
    name: 'Gemini 1.5 Flash',
    providerId: 'gemini',
    description: 'Production-grade high speed multimodal model',
  ),
  ModelOption(
    id: 'gemini-1.5-pro',
    name: 'Gemini 1.5 Pro',
    providerId: 'gemini',
    description: 'Complex analytical reasoning, vision, and large context',
  ),
  // Anthropic Claude
  ModelOption(
    id: 'claude-3-7-sonnet-latest',
    name: 'Claude 3.7 Sonnet',
    providerId: 'anthropic',
    description: 'Hybrid reasoning and high-capability coding model',
    isDefault: true,
  ),
  ModelOption(
    id: 'claude-3-5-sonnet-latest',
    name: 'Claude 3.5 Sonnet',
    providerId: 'anthropic',
    description: 'High-capability reasoning and vision',
  ),
  ModelOption(
    id: 'claude-3-5-haiku-latest',
    name: 'Claude 3.5 Haiku',
    providerId: 'anthropic',
    description: 'Fast and lightweight Claude model',
    isCheap: true,
  ),
  // OpenAI
  ModelOption(
    id: 'gpt-4o',
    name: 'GPT-4o',
    providerId: 'openai',
    description: 'Omni-model for vision, reasoning and tool calling',
    isDefault: true,
  ),
  ModelOption(
    id: 'gpt-4o-mini',
    name: 'GPT-4o Mini',
    providerId: 'openai',
    description: 'Fast, lightweight cost-efficient OpenAI model',
    isCheap: true,
  ),
];

@immutable
sealed class LlmPart {
  const LlmPart();
}

class TextPart extends LlmPart {
  const TextPart(this.text);
  final String text;
}

class ImagePart extends LlmPart {
  const ImagePart({
    required this.bytes,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String mimeType;
}

class ToolCallProposal {
  const ToolCallProposal({
    required this.callId,
    required this.toolName,
    required this.arguments,
  });
  final String callId;
  final String toolName;
  final Map<String, dynamic> arguments;
}

class ToolCallPart extends LlmPart {
  const ToolCallPart({
    required this.callId,
    required this.toolName,
    required this.arguments,
  });
  final String callId;
  final String toolName;
  final Map<String, dynamic> arguments;
}

class ToolResponsePart extends LlmPart {
  const ToolResponsePart({
    required this.callId,
    required this.toolName,
    required this.response,
  });
  final String callId;
  final String toolName;
  final Map<String, dynamic> response;
}

class LlmMessage {
  const LlmMessage({
    required this.role,
    required this.parts,
  });

  final MessageRole role;
  final List<LlmPart> parts;
}

@immutable
sealed class LlmStreamEvent {
  const LlmStreamEvent();
}

class LlmTextDeltaEvent extends LlmStreamEvent {
  const LlmTextDeltaEvent(this.delta);
  final String delta;
}

class LlmToolCallEvent extends LlmStreamEvent {
  const LlmToolCallEvent(this.proposal);
  final ToolCallProposal proposal;
}

class LlmDoneEvent extends LlmStreamEvent {
  const LlmDoneEvent();
}

class LlmErrorEvent extends LlmStreamEvent {
  const LlmErrorEvent(this.error);
  final Object error;
}
