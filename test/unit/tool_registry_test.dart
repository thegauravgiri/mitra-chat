import 'package:flutter_test/flutter_test.dart';
import 'package:mitra/core/result.dart';
import 'package:mitra/domain/agent/tool_descriptor.dart';
import 'package:mitra/domain/agent/tool_registry.dart';
import 'package:mitra/domain/models/enums.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = ToolRegistry();
  });

  test('Registers and retrieves tools', () {
    final tool = ToolDescriptor(
      name: 'test_tool',
      description: 'A test tool',
      inputSchema: const {'type': 'object'},
      source: ToolSource.builtin,
      handler: (args) async => const Result.ok({'success': true}),
    );

    registry.register(tool);
    expect(registry.get('test_tool'), isNotNull);
    expect(registry.getAll().length, equals(1));
  });

  test('Namespaced tools from different servers coexist without collision', () async {
    final toolA = ToolDescriptor(
      name: 'mcp.serverA.create_task',
      description: 'Server A task creator',
      inputSchema: const {'type': 'object'},
      source: ToolSource.mcp,
      serverId: 'serverA',
      handler: (args) async => const Result.ok({'server': 'A'}),
    );

    final toolB = ToolDescriptor(
      name: 'mcp.serverB.create_task',
      description: 'Server B task creator',
      inputSchema: const {'type': 'object'},
      source: ToolSource.mcp,
      serverId: 'serverB',
      handler: (args) async => const Result.ok({'server': 'B'}),
    );

    registry.registerAll([toolA, toolB]);
    expect(registry.getAll().length, equals(2));

    final resA = await registry.invoke('mcp.serverA.create_task', {});
    expect(resA.valueOrNull?['server'], equals('A'));

    final resB = await registry.invoke('mcp.serverB.create_task', {});
    expect(resB.valueOrNull?['server'], equals('B'));
  });

  test('Unregistering server tools removes only matching tools', () {
    final tool1 = ToolDescriptor(
      name: 'mcp.server1.tool1',
      description: 'tool 1',
      inputSchema: const {},
      source: ToolSource.mcp,
      serverId: 'server1',
      handler: (args) async => const Result.ok({}),
    );

    final tool2 = ToolDescriptor(
      name: 'mcp.server2.tool2',
      description: 'tool 2',
      inputSchema: const {},
      source: ToolSource.mcp,
      serverId: 'server2',
      handler: (args) async => const Result.ok({}),
    );

    registry.registerAll([tool1, tool2]);
    registry.unregisterServer('server1');

    expect(registry.get('mcp.server1.tool1'), isNull);
    expect(registry.get('mcp.server2.tool2'), isNotNull);
  });

  test('Invoking unknown tool returns ToolFailure', () async {
    final res = await registry.invoke('non_existent', {});
    expect(res.isErr, isTrue);
    expect(res.failureOrNull?.message, contains('not registered'));
  });

  test('suggestRelated ranks discovery tools from same server in top 3 on failure', () {
    registry.registerAll([
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_list_work_items',
        description: 'List work items',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async => const Result.ok({}),
      ),
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_create_work_item',
        description: 'Create work item',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async => const Result.ok({}),
      ),
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_list_projects',
        description: 'List projects',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async => const Result.ok({}),
      ),
      ToolDescriptor(
        name: 'mcp.mitra.azure_devops_get_work_item',
        description: 'Get work item',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async => const Result.ok({}),
      ),
      ToolDescriptor(
        name: 'mcp.mitra.clockify_add_time_entry',
        description: 'Clockify time entry',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'mitra',
        handler: (args) async => const Result.ok({}),
      ),
      ToolDescriptor(
        name: 'mcp.other.azure_devops_list_projects',
        description: 'Other server',
        inputSchema: const {},
        source: ToolSource.mcp,
        serverId: 'other',
        handler: (args) async => const Result.ok({}),
      ),
    ]);

    final suggestions = registry.suggestRelated('mcp.mitra.azure_devops_list_work_items', 'not_found');

    expect(suggestions, isNotEmpty);
    expect(suggestions.length, lessThanOrEqualTo(5));
    // Must be from server 'mitra' only
    expect(suggestions.every((s) => s.startsWith('mcp.mitra.')), isTrue);
    // 'mcp.mitra.azure_devops_list_projects' must be in top 3
    final top3 = suggestions.take(3).toList();
    expect(top3, contains('mcp.mitra.azure_devops_list_projects'));
  });
}
