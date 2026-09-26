import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/core/failures.dart';
import 'package:mitra/core/result.dart';
import 'package:mitra/data/db/database.dart';
import 'package:mitra/data/repositories/conversation_repository.dart';
import 'package:mitra/data/repositories/message_repository.dart';
import 'package:mitra/data/stores/attachment_store.dart';
import 'package:mitra/domain/agent/agent_event.dart';
import 'package:mitra/domain/agent/agent_orchestrator.dart';
import 'package:mitra/domain/agent/tool_descriptor.dart';
import 'package:mitra/domain/agent/tool_registry.dart';
import 'package:mitra/domain/models/enums.dart';
import 'package:mitra/integrations/llm/llm_types.dart';
import '../fakes/fake_llm_provider.dart';

void main() {
  late AppDatabase db;
  late MessageRepository messageRepo;
  late ConversationRepository conversationRepo;
  late AttachmentStore attachmentStore;
  late ToolRegistry toolRegistry;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    attachmentStore = AttachmentStore();
    messageRepo = MessageRepository(db: db);
    conversationRepo = ConversationRepository(
      db: db,
      attachmentStore: attachmentStore,
    );
    toolRegistry = ToolRegistry();
  });

  tearDown(() async {
    await db.close();
  });

  test('Plain text stream without tools completes assistant message', () async {
    final convo = await conversationRepo.createConversation(title: 'Chat 1');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Hello assistant',
    );

    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      scriptedEvents: [
        const LlmTextDeltaEvent('Hello '),
        const LlmTextDeltaEvent('there!'),
        const LlmDoneEvent(),
      ],
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).toList();

    expect(events.whereType<AgentTextDelta>().length, equals(2));
    expect(events.whereType<AgentDone>().length, equals(1));

    final msgs = await messageRepo.getMessages(convo.id);
    expect(msgs.length, equals(2));
    expect(msgs.last.role, equals(MessageRole.assistant));
    expect(msgs.last.content, equals('Hello there!'));
    expect(msgs.last.status, equals(MessageStatus.complete));
  });

  test('Single tool call triggers execution and completes response', () async {
    final convo = await conversationRepo.createConversation(title: 'Chat with tool');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Create a task for PR review',
    );

    var toolExecuted = false;
    toolRegistry.register(ToolDescriptor(
      name: 'notion.create_tasks',
      description: 'Create tasks',
      inputSchema: const {},
      source: ToolSource.builtin,
      handler: (args) async {
        toolExecuted = true;
        return const Result.ok({'created_count': 1});
      },
    ));

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_1',
            toolName: 'notion.create_tasks',
            arguments: {'title': 'PR Review'},
          ));
          yield const LlmDoneEvent();
        } else {
          yield const LlmTextDeltaEvent('Task created successfully in Notion!');
          yield const LlmDoneEvent();
        }
      },
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).toList();

    expect(toolExecuted, isTrue);
    expect(events.whereType<AgentToolCallProposed>().length, equals(1));
    expect(events.whereType<AgentToolCompleted>().length, equals(1));
    expect(events.whereType<AgentDone>().length, equals(1));

    final invocations = await messageRepo.watchToolInvocationsForConversation(convo.id).first;
    expect(invocations.length, equals(1));
    expect(invocations.first.status, equals(ToolStatus.ok));
  });

  test('Tool failure is fed back into history and does not crash the run', () async {
    final convo = await conversationRepo.createConversation();
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Do failing action',
    );

    toolRegistry.register(ToolDescriptor(
      name: 'failing_tool',
      description: 'Failing tool',
      inputSchema: const {},
      source: ToolSource.builtin,
      handler: (args) async => const Result.err(ToolFailure(
        toolName: 'failing_tool',
        message: 'Database unavailable',
      )),
    ));

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'c1',
            toolName: 'failing_tool',
            arguments: {},
          ));
          yield const LlmDoneEvent();
        } else {
          yield const LlmTextDeltaEvent('Sorry, the database was unavailable.');
          yield const LlmDoneEvent();
        }
      },
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).toList();

    expect(events.whereType<AgentToolFailed>().length, equals(1));
    expect(events.whereType<AgentDone>().length, equals(1));
  });

  test('Mid-stream cancellation halts execution immediately', () async {
    final convo = await conversationRepo.createConversation();
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Long running task',
    );

    final cancelToken = CancelToken();

    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        yield const LlmTextDeltaEvent('Starting...');
        cancelToken.cancel();
        yield const LlmTextDeltaEvent('Should not appear');
      },
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
      cancelToken: cancelToken,
    ).toList();

    expect(events.whereType<AgentFailed>().length, equals(1));
  });

  test('Orchestrator emits AgentDone even if provider stream never closes after LlmDoneEvent', () async {
    final convo = await conversationRepo.createConversation(title: 'Never Close Test');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Hello',
    );

    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      scriptedEvents: [
        const LlmTextDeltaEvent('Hi there!'),
        const LlmDoneEvent(),
      ],
      neverCloses: true,
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).timeout(const Duration(seconds: 3)).toList();

    expect(events.whereType<AgentTextDelta>().length, equals(1));
    expect(events.whereType<AgentDone>().length, equals(1));
    expect(events.whereType<AgentDone>().first.finalText, equals('Hi there!'));

    final msgs = await messageRepo.getMessages(convo.id);
    expect(msgs.last.status, equals(MessageStatus.complete));
  });

  test('Orchestrator watchdog triggers AgentFailed when stream stalls', () async {
    final convo = await conversationRepo.createConversation(title: 'Stall Test');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Hello',
    );

    // Emits 1 delta and then hangs without LlmDoneEvent
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      scriptedEvents: [
        const LlmTextDeltaEvent('Partial response...'),
      ],
      neverCloses: true,
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
      watchdogTimeout: const Duration(milliseconds: 300),
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).timeout(const Duration(seconds: 2)).toList();

    expect(events.whereType<AgentTextDelta>().length, equals(1));
    expect(events.whereType<AgentFailed>().length, equals(1));

    final msgs = await messageRepo.getMessages(convo.id);
    expect(msgs.last.status, equals(MessageStatus.failed));
  });

  test('Confirmation gating: user decline feeds back error_kind=declined without executing tool', () async {
    final convo = await conversationRepo.createConversation(title: 'Decline Test');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Delete everything',
    );

    var toolExecuted = false;
    toolRegistry.register(ToolDescriptor(
      name: 'delete_resource',
      description: 'Destructive delete',
      inputSchema: const {},
      source: ToolSource.builtin,
      requiresConfirmation: true,
      handler: (args) async {
        toolExecuted = true;
        return const Result.ok({'deleted': true});
      },
    ));

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_del',
            toolName: 'delete_resource',
            arguments: {},
          ));
          yield const LlmDoneEvent();
        } else {
          final lastToolMsg = history.where((m) => m.role == MessageRole.tool).last;
          final part = lastToolMsg.parts.whereType<ToolResponsePart>().first;
          expect(part.response['error_kind'], equals('declined'));
          expect(part.response['recoverable'], isFalse);

          yield const LlmTextDeltaEvent('Cancelled deletion since you declined.');
          yield const LlmDoneEvent();
        }
      },
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
      autoRunTools: false,
      confirmationHandler: ({required invocationId, required toolName, required arguments}) async {
        return false; // User declines
      },
    ).toList();

    expect(toolExecuted, isFalse);
    expect(events.whereType<AgentDone>().first.finalText, contains('Cancelled deletion'));
  });

  test('Automatically generates and sets conversation title after first exchange', () async {
    final convo = await conversationRepo.createConversation(title: 'New chat');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Find all sprint cards for project jarvis',
    );

    var callCount = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        callCount++;
        if (callCount == 1) {
          // Assistant response to main prompt
          yield const LlmTextDeltaEvent('Here are your sprint cards.');
          yield const LlmDoneEvent();
        } else {
          // Auto-titling call
          yield const LlmTextDeltaEvent('Title: Jarvis Sprint Cards');
          yield const LlmDoneEvent();
        }
      },
    );

    final orchestrator = AgentOrchestrator(
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
      attachmentStore: attachmentStore,
      toolRegistry: toolRegistry,
      providers: {'fake': fakeProvider},
    );

    final events = await orchestrator.run(
      conversationId: convo.id,
      providerId: 'fake',
      modelId: 'test-model',
    ).toList();

    expect(events.whereType<AgentDone>().length, equals(1));

    // Allow the unawaited auto-title future to settle
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final updatedConvo = await conversationRepo.getConversationById(convo.id);
    expect(updatedConvo?.title, equals('Jarvis Sprint Cards'));
  });
}
