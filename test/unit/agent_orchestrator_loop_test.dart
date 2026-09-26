import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('Multi-step loop history retains assistant ToolCallPart paired with ToolResponsePart', () async {
    final convo = await conversationRepo.createConversation(title: 'Loop test');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'What are my cards for project jarvis?',
    );

    toolRegistry.register(ToolDescriptor(
      name: 'mcp.mitra.azure_devops_list_work_items',
      description: 'List work items',
      inputSchema: const {},
      source: ToolSource.mcp,
      serverId: 'mitra',
      handler: (args) async => const Result.ok({'items': ['Card 1', 'Card 2']}),
    ));

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_step1_0_azure_devops_list_work_items',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            arguments: {'project': 'jarvis', 'sprint': '70'},
          ));
          yield const LlmDoneEvent();
        } else if (step == 2) {
          yield const LlmTextDeltaEvent('You have 2 cards: Card 1, Card 2.');
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

    expect(fakeProvider.recordedHistories.length, greaterThanOrEqualTo(2));
    final step2History = fakeProvider.recordedHistories[1];

    // Assert history contains an assistant message with ToolCallPart
    final assistantMsgs = step2History.where((m) => m.role == MessageRole.assistant).toList();
    expect(assistantMsgs, isNotEmpty, reason: 'Step 2 history must contain an assistant message');

    final assistantMsg = assistantMsgs.last;
    final toolCallParts = assistantMsg.parts.whereType<ToolCallPart>().toList();
    expect(toolCallParts, isNotEmpty, reason: 'Assistant message must contain ToolCallPart');

    final toolCall = toolCallParts.first;
    expect(toolCall.toolName, equals('mcp.mitra.azure_devops_list_work_items'));
    expect(toolCall.arguments, equals({'project': 'jarvis', 'sprint': '70'}));

    // Assert that the subsequent tool response message matches the callId
    final toolResponseMsgs = step2History.where((m) => m.role == MessageRole.tool).toList();
    expect(toolResponseMsgs, isNotEmpty);
    final toolResponsePart = toolResponseMsgs.last.parts.whereType<ToolResponsePart>().first;
    expect(toolResponsePart.callId, equals(toolCall.callId));

    // Assert AgentDone carries step 2 final text
    final doneEvents = events.whereType<AgentDone>().toList();
    expect(doneEvents.length, equals(1));
    expect(doneEvents.first.finalText, equals('You have 2 cards: Card 1, Card 2.'));
  });
}
