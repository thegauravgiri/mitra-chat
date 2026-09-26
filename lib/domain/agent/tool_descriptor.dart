import '../../core/result.dart';
import '../models/enums.dart';

typedef ToolHandler = Future<Result<Map<String, dynamic>>> Function(
  Map<String, dynamic> arguments,
);

class ToolDescriptor {
  const ToolDescriptor({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.source,
    this.serverId,
    this.requiresConfirmation = false,
    required this.handler,
  });

  final String name; // e.g. 'notion.create_tasks', 'mcp.mitra.azure_devops_create_work_item'
  final String description;
  final Map<String, dynamic> inputSchema; // Standard JSON Schema
  final ToolSource source;
  final String? serverId;
  final bool requiresConfirmation;
  final ToolHandler handler;

  Future<Result<Map<String, dynamic>>> invoke(Map<String, dynamic> args) =>
      handler(args);
}
