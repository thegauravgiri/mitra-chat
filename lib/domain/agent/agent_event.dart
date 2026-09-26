import 'package:meta/meta.dart';
import '../../core/failures.dart';
import '../models/enums.dart';
import '../../integrations/llm/llm_types.dart';

@immutable
sealed class AgentEvent {
  const AgentEvent();
}

class AgentTextDelta extends AgentEvent {
  const AgentTextDelta(this.delta);
  final String delta;
}

class AgentToolCallProposed extends AgentEvent {
  const AgentToolCallProposed(this.proposal);
  final ToolCallProposal proposal;
}

class AgentToolStarted extends AgentEvent {
  const AgentToolStarted({
    required this.invocationId,
    required this.toolName,
    required this.source,
  });
  final String invocationId;
  final String toolName;
  final ToolSource source;
}

class AgentToolCompleted extends AgentEvent {
  const AgentToolCompleted({
    required this.invocationId,
    required this.toolName,
    required this.result,
  });
  final String invocationId;
  final String toolName;
  final Map<String, dynamic> result;
}

class AgentToolFailed extends AgentEvent {
  const AgentToolFailed({
    required this.invocationId,
    required this.toolName,
    required this.failure,
  });
  final String invocationId;
  final String toolName;
  final AppFailure failure;
}

class AgentStepStarted extends AgentEvent {
  const AgentStepStarted({
    required this.step,
    required this.maxSteps,
  });
  final int step;
  final int maxSteps;
}

class AgentToolRetrying extends AgentEvent {
  const AgentToolRetrying({
    required this.toolName,
    required this.attempt,
    required this.reason,
  });
  final String toolName;
  final int attempt;
  final String reason;
}

class AgentToolAwaitingConfirmation extends AgentEvent {
  const AgentToolAwaitingConfirmation({
    required this.invocationId,
    required this.toolName,
    required this.arguments,
  });
  final String invocationId;
  final String toolName;
  final Map<String, dynamic> arguments;
}

class AgentDone extends AgentEvent {
  const AgentDone({
    required this.messageId,
    required this.finalText,
  });
  final String messageId;
  final String finalText;
}

class AgentFailed extends AgentEvent {
  const AgentFailed({
    required this.messageId,
    required this.errorMessage,
  });
  final String messageId;
  final String errorMessage;
}
