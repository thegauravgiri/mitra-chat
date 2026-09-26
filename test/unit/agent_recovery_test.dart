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

  test('The jarvis scenario: Autonomous recovery via list_projects when list_work_items fails not_found', () async {
    final convo = await conversationRepo.createConversation(title: 'Jarvis Recovery');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'get sprint cards for 70 for jarvis project',
    );

    var listWorkItemsCalledCount = 0;
    var listProjectsCalled = false;

    toolRegistry.registerAll([
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_list_work_items',
        description: 'List work items',
        inputSchema: const {'type': 'object'},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async {
          listWorkItemsCalledCount++;
          final project = args['project'] as String?;
          if (project == 'jarvis') {
            return const Result.err(ToolFailure(
              toolName: 'mcp.mitra.azure_devops_list_work_items',
              message: "Project 'jarvis' not found.",
            ));
          } else if (project == 'gl-rg-we-jarvis-agent') {
            return const Result.ok({
              'work_items': [
                {'id': 101, 'title': 'Implement autonomous recovery'}
              ]
            });
          }
          return const Result.err(ToolFailure(
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            message: 'Unknown project',
          ));
        },
      ),
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_list_projects',
        description: 'List projects',
        inputSchema: const {'type': 'object'},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async {
          listProjectsCalled = true;
          return const Result.ok({
            'projects': ['gl-rg-we-jarvis-agent', 'mitra-core']
          });
        },
      ),
    ]);

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          // Step 1: Model tries list_work_items with shorthand "jarvis"
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_1',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            arguments: {'project': 'jarvis', 'sprint': '70'},
          ));
          yield const LlmDoneEvent();
        } else if (step == 2) {
          // Inspect that the previous tool error was delivered with recoverable=true and related_tools
          final lastToolMsg = history.where((m) => m.role == MessageRole.tool).last;
          final part = lastToolMsg.parts.whereType<ToolResponsePart>().first;
          expect(part.response['ok'], isFalse);
          expect(part.response['error_kind'], equals('not_found'));
          expect(part.response['recoverable'], isTrue);
          final related = (part.response['related_tools'] as List<dynamic>).cast<String>();
          expect(related, contains('mcp.mitra.azure_devops_list_projects'));

          // Step 2: Model calls the suggested discovery tool
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_2',
            toolName: 'mcp.mitra.azure_devops_list_projects',
            arguments: {},
          ));
          yield const LlmDoneEvent();
        } else if (step == 3) {
          // Step 3: Model sees list_projects succeeded with 'gl-rg-we-jarvis-agent' and retries list_work_items
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_3',
            toolName: 'mcp.mitra.azure_devops_list_work_items',
            arguments: {'project': 'gl-rg-we-jarvis-agent', 'sprint': '70'},
          ));
          yield const LlmDoneEvent();
        } else if (step == 4) {
          // Step 4: Model summarizes the work items
          yield const LlmTextDeltaEvent('Found work item: Implement autonomous recovery (ID: 101) in gl-rg-we-jarvis-agent.');
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

    expect(listWorkItemsCalledCount, equals(2));
    expect(listProjectsCalled, isTrue);

    final doneEvents = events.whereType<AgentDone>().toList();
    expect(doneEvents.length, equals(1));
    expect(doneEvents.first.finalText, contains('Implement autonomous recovery'));
  });

  test('Repetition guard: Refuses 3rd identical failing call and marks non-recoverable', () async {
    final convo = await conversationRepo.createConversation(title: 'Repetition Guard Test');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'Do failing action repeatedly',
    );

    var rawToolExecutionCount = 0;
    toolRegistry.register(ToolDescriptor(
      name: 'failing_action',
      description: 'Always fails',
      inputSchema: const {},
      source: ToolSource.builtin,
      handler: (args) async {
        rawToolExecutionCount++;
        return const Result.err(ToolFailure(
          toolName: 'failing_action',
          message: 'Persistent server error',
        ));
      },
    ));

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step <= 3) {
          // Propose the exact same failing call 3 times in a row
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_rep',
            toolName: 'failing_action',
            arguments: {'param': 'static_value'},
          ));
          yield const LlmDoneEvent();
        } else {
          // On step 4, inspect the 3rd tool response and summarize
          final lastToolMsg = history.where((m) => m.role == MessageRole.tool).last;
          final part = lastToolMsg.parts.whereType<ToolResponsePart>().first;
          expect(part.response['recoverable'], isFalse);
          expect(part.response['message'], contains('already attempted twice'));

          yield const LlmTextDeltaEvent('Could not proceed after repeated failures.');
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

    // The tool handler should only have been executed twice; the 3rd was intercepted by the guard!
    expect(rawToolExecutionCount, equals(2));

    final done = events.whereType<AgentDone>().first;
    expect(done.finalText, contains('Could not proceed'));
  });

  test('Metadata-aware search fallback: Recovers from empty search results via broad query & client-side filtering', () async {
    final convo = await conversationRepo.createConversation(title: 'Sprint 70 Full Recovery');
    await messageRepo.appendUserMessage(
      conversationId: convo.id,
      text: 'find me sprint cards for sprint 70 for jarvis project',
    );

    var listProjectsCalled = false;
    var specificSearchCalled = false;
    var broadSearchCalled = false;

    toolRegistry.registerAll([
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_list_projects',
        description: 'List Azure DevOps projects',
        inputSchema: const {'type': 'object'},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async {
          listProjectsCalled = true;
          return const Result.ok({
            'projects': ['gl-rg-we-jarvis-agents', 'mitra-core']
          });
        },
      ),
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_search_work_items',
        description: 'Search work items in Azure DevOps',
        inputSchema: const {'type': 'object'},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async {
          final project = args['project'] as String?;
          final searchText = args['search_text'] as String?;
          final top = args['top'] as int?;

          if (searchText == 'Sprint 70') {
            specificSearchCalled = true;
            // Empty list because sprint/iteration path is not indexed in title/description
            return const Result.ok({'items': <Map<String, dynamic>>[]});
          }

          if (project == 'gl-rg-we-jarvis-agents' && (top == null || top >= 50)) {
            broadSearchCalled = true;
            return const Result.ok({
              'items': <Map<String, dynamic>>[
                {
                  'id': 21649,
                  'title': 'Disable Interrupt while step processing is happening',
                  'type': 'Task',
                  'state': 'In Progress',
                  'iteration_path': r'gl-rg-we-jarvis-agents\Sprint 70',
                  'assigned_to': 'Gaurav Giri',
                },
                {
                  'id': 21581,
                  'title': 'Fix TTS white noise on initial voice activation',
                  'type': 'Bug',
                  'state': 'Done',
                  'iteration_path': r'gl-rg-we-jarvis-agents\Sprint 70',
                  'assigned_to': 'Gaurav Giri',
                },
                {
                  'id': 20110,
                  'title': 'Legacy task from older sprint',
                  'type': 'Task',
                  'state': 'Done',
                  'iteration_path': r'gl-rg-we-jarvis-agents\Sprint 68',
                  'assigned_to': 'Other User',
                },
              ]
            });
          }

          return const Result.ok({'items': <Map<String, dynamic>>[]});
        },
      ),
    ]);

    var step = 0;
    final fakeProvider = FakeLlmProvider(
      id: 'fake',
      onStreamChat: ({required history, required tools, required modelId}) async* {
        step++;
        if (step == 1) {
          // Step 1: Model resolves shorthand "jarvis" to canonical project
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_proj',
            toolName: 'mcp.mitra.azure_devops_list_projects',
            arguments: {},
          ));
          yield const LlmDoneEvent();
        } else if (step == 2) {
          // Step 2: Model tries search_text: "Sprint 70" with resolved project name
          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_search_1',
            toolName: 'mcp.mitra.azure_devops_search_work_items',
            arguments: {
              'project': 'gl-rg-we-jarvis-agents',
              'search_text': 'Sprint 70',
            },
          ));
          yield const LlmDoneEvent();
        } else if (step == 3) {
          // Step 3: Model sees empty search items -> falls back to broad fetch with top: 50
          final lastToolMsg = history.where((m) => m.role == MessageRole.tool).last;
          final part = lastToolMsg.parts.whereType<ToolResponsePart>().first;
          final resultData = part.response['result'] as Map<String, dynamic>;
          expect((resultData['items'] as List).isEmpty, isTrue);

          yield const LlmToolCallEvent(ToolCallProposal(
            callId: 'call_search_2',
            toolName: 'mcp.mitra.azure_devops_search_work_items',
            arguments: {
              'project': 'gl-rg-we-jarvis-agents',
              'top': 50,
            },
          ));
          yield const LlmDoneEvent();
        } else if (step == 4) {
          // Step 4: Model processes iteration_path client-side and formats structured response
          yield const LlmTextDeltaEvent(
            '### Sprint 70 Cards (gl-rg-we-jarvis-agents)\n\n'
            '**Active / In Progress:**\n'
            '- #21649: Disable Interrupt while step processing is happening (Task, Gaurav Giri)\n\n'
            '**Resolved / Done:**\n'
            '- #21581: Fix TTS white noise on initial voice activation (Bug, Gaurav Giri)\n',
          );
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

    expect(listProjectsCalled, isTrue);
    expect(specificSearchCalled, isTrue);
    expect(broadSearchCalled, isTrue);

    final done = events.whereType<AgentDone>().first;
    expect(done.finalText, contains('Sprint 70 Cards'));
    expect(done.finalText, contains('21649'));
    expect(done.finalText, contains('21581'));
    expect(done.finalText, isNot(contains('20110'))); // Sprint 68 item excluded by client-side filter
  });
}
