import 'dart:async';
import 'dart:convert';
import '../../core/failures.dart';
import '../../core/logging/logger.dart';
import '../../core/result.dart';
import '../../domain/agent/tool_descriptor.dart';
import '../../domain/models/enums.dart';
import '../llm/llm_types.dart';
import 'mcp_content_decoder.dart';
import 'mcp_prompt.dart';
import 'mcp_server_config.dart';
import 'streamable_http_channel.dart';

class McpToolSummary {
  const McpToolSummary({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.destructiveHint,
    this.readOnlyHint,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final bool? destructiveHint;
  final bool? readOnlyHint;

  factory McpToolSummary.fromJson(Map<String, dynamic> json) {
    final annotations = json['annotations'] as Map<String, dynamic>?;
    return McpToolSummary(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      inputSchema:
          (json['inputSchema'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      destructiveHint: annotations?['destructiveHint'] as bool?,
      readOnlyHint: annotations?['readOnlyHint'] as bool?,
    );
  }
}

class McpClient {
  McpClient({
    required this.config,
    StreamableHttpChannel? channel,
  }) : _channel = channel ??
            StreamableHttpChannel(
              endpointUrl: config.endpointUrl,
              bearerToken: config.bearerToken,
            );

  final McpServerConfig config;
  final StreamableHttpChannel _channel;

  McpConnectionStatus _status = McpConnectionStatus.disconnected;
  String? _lastError;
  int _rpcId = 0;
  final Map<int, Completer<dynamic>> _pendingRpc = {};
  StreamSubscription<String>? _channelSub;
  Map<String, dynamic> _serverCapabilities = {};

  McpConnectionStatus get status => _status;
  String? get lastError => _lastError;
  Map<String, dynamic> get serverCapabilities => _serverCapabilities;

  bool hasCapability(String capability) =>
      _serverCapabilities.containsKey(capability);

  Future<Result<bool>> connect() async {
    if (_status == McpConnectionStatus.connected) {
      return const Result.ok(true);
    }

    _status = McpConnectionStatus.connecting;
    _lastError = null;

    try {
      _channelSub = _channel.stream.listen(
        _handleIncomingMessage,
        onError: (Object error) {
          _status = McpConnectionStatus.error;
          _lastError = error.toString();
          AppLogger.warning('MCP stream error for "${config.id}": $error');
          for (final completer in _pendingRpc.values) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          }
          _pendingRpc.clear();
        },
      );

      // Initialize MCP session (protocol 2025-06-18, Plan §F2.3.6)
      final initResult = await _callRpc('initialize', <String, dynamic>{
        'protocolVersion': '2025-06-18',
        'capabilities': <String, dynamic>{
          'roots': <String, dynamic>{'listChanged': false},
          'sampling': <String, dynamic>{},
          'prompts': <String, dynamic>{},
          'resources': <String, dynamic>{},
        },
        'clientInfo': <String, dynamic>{
          'name': 'mitra-flutter',
          'version': '1.0.0',
        },
      });

      if (initResult.isErr) {
        _status = McpConnectionStatus.error;
        _lastError = initResult.failureOrNull?.message;
        return Result.err(initResult.failureOrNull!);
      }

      final initData = initResult.valueOrNull;
      if (initData is Map<String, dynamic>) {
        _serverCapabilities =
            (initData['capabilities'] as Map<String, dynamic>?) ?? {};
      }

      // Notify initialized
      await _sendNotification('notifications/initialized', {});

      _status = McpConnectionStatus.connected;
      return const Result.ok(true);
    } catch (e) {
      _status = McpConnectionStatus.error;
      _lastError = e.toString();
      return Result.err(NetworkFailure(
        message: 'Failed to connect to MCP server "${config.name}": $e',
        cause: e,
      ));
    }
  }

  Future<Result<List<McpToolSummary>>> listTools() async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    final allTools = <McpToolSummary>[];
    String? cursor;

    do {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;

      final res = await _callRpc('tools/list', params);
      if (res.isErr) {
        if (_isMethodNotFound(res.failureOrNull)) {
          return const Result.ok([]);
        }
        return Result.err(res.failureOrNull!);
      }

      final data = res.valueOrNull;
      if (data is Map<String, dynamic>) {
        final toolsList = (data['tools'] as List<dynamic>?) ?? [];
        allTools.addAll(
          toolsList
              .whereType<Map<String, dynamic>>()
              .map(McpToolSummary.fromJson),
        );
        cursor = data['nextCursor'] as String?;
      } else {
        cursor = null;
      }
    } while (cursor != null && cursor.isNotEmpty);

    return Result.ok(allTools);
  }

  Future<Result<Map<String, dynamic>>> callTool(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    final res = await _callRpc('tools/call', {
      'name': toolName,
      'arguments': arguments,
    });

    if (res.isErr) {
      return Result.err(res.failureOrNull!);
    }

    return McpContentDecoder.decodeToolCallResult(res.valueOrNull);
  }

  Future<Result<List<McpPromptSummary>>> listPrompts() async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    if (_serverCapabilities.isNotEmpty && !hasCapability('prompts')) {
      return const Result.ok([]);
    }

    final allPrompts = <McpPromptSummary>[];
    String? cursor;

    do {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;

      final res = await _callRpc('prompts/list', params);
      if (res.isErr) {
        if (_isMethodNotFound(res.failureOrNull)) {
          return const Result.ok([]);
        }
        return Result.err(res.failureOrNull!);
      }

      final data = res.valueOrNull;
      if (data is Map<String, dynamic>) {
        final promptsList = (data['prompts'] as List<dynamic>?) ?? [];
        allPrompts.addAll(
          promptsList
              .whereType<Map<String, dynamic>>()
              .map(McpPromptSummary.fromJson),
        );
        cursor = data['nextCursor'] as String?;
      } else {
        cursor = null;
      }
    } while (cursor != null && cursor.isNotEmpty);

    return Result.ok(allPrompts);
  }

  Future<Result<List<McpPromptMessage>>> getPrompt(
    String name, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    final res = await _callRpc('prompts/get', {
      'name': name,
      if (arguments != null && arguments.isNotEmpty) 'arguments': arguments,
    });

    if (res.isErr) {
      if (_isMethodNotFound(res.failureOrNull)) {
        return const Result.ok([]);
      }
      return Result.err(res.failureOrNull!);
    }

    final data = res.valueOrNull;
    if (data is Map<String, dynamic>) {
      final rawMessages = (data['messages'] as List<dynamic>?) ?? [];
      final messages = <McpPromptMessage>[];

      for (final rawMsg in rawMessages) {
        if (rawMsg is Map<String, dynamic>) {
          final roleStr = rawMsg['role'] as String? ?? 'user';
          final role =
              roleStr == 'assistant' ? MessageRole.assistant : MessageRole.user;
          final content = rawMsg['content'];
          final parts = content is List
              ? McpContentDecoder.decodeContentBlocks(content)
              : content is Map<String, dynamic>
                  ? McpContentDecoder.decodeContentBlocks([content])
                  : <LlmPart>[];

          messages.add(McpPromptMessage(role: role, parts: parts));
        }
      }

      return Result.ok(messages);
    }

    return const Result.ok([]);
  }

  Future<Result<List<McpResourceSummary>>> listResources() async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    if (_serverCapabilities.isNotEmpty && !hasCapability('resources')) {
      return const Result.ok([]);
    }

    final allResources = <McpResourceSummary>[];
    String? cursor;

    do {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;

      final res = await _callRpc('resources/list', params);
      if (res.isErr) {
        if (_isMethodNotFound(res.failureOrNull)) {
          return const Result.ok([]);
        }
        return Result.err(res.failureOrNull!);
      }

      final data = res.valueOrNull;
      if (data is Map<String, dynamic>) {
        final resList = (data['resources'] as List<dynamic>?) ?? [];
        allResources.addAll(
          resList
              .whereType<Map<String, dynamic>>()
              .map(McpResourceSummary.fromJson),
        );
        cursor = data['nextCursor'] as String?;
      } else {
        cursor = null;
      }
    } while (cursor != null && cursor.isNotEmpty);

    return Result.ok(allResources);
  }

  Future<Result<List<McpResourceContent>>> readResource(String uri) async {
    if (_status != McpConnectionStatus.connected) {
      final connRes = await connect();
      if (connRes.isErr) {
        return Result.err(connRes.failureOrNull!);
      }
    }

    final res = await _callRpc('resources/read', {'uri': uri});
    if (res.isErr) {
      if (_isMethodNotFound(res.failureOrNull)) {
        return const Result.ok([]);
      }
      return Result.err(res.failureOrNull!);
    }

    final data = res.valueOrNull;
    if (data is Map<String, dynamic>) {
      final contents = (data['contents'] as List<dynamic>?) ?? [];
      final result = contents
          .whereType<Map<String, dynamic>>()
          .map(McpResourceContent.fromJson)
          .toList();
      return Result.ok(result);
    }

    return const Result.ok([]);
  }

  /// Converts discovered MCP tools into namespaced ToolDescriptors.
  Future<Result<List<ToolDescriptor>>> getToolDescriptors() async {
    final listRes = await listTools();
    if (listRes.isErr) {
      return Result.err(listRes.failureOrNull!);
    }

    final tools = listRes.valueOrNull!;
    final descriptors = tools.map((tool) {
      final namespacedName = 'mcp.${config.id}.${tool.name}';
      final isDestructive = (tool.destructiveHint == true) ||
          ((tool.readOnlyHint != true) && _isDestructiveName(tool.name));

      return ToolDescriptor(
        name: namespacedName,
        description: '[${config.name}] ${tool.description}',
        inputSchema: tool.inputSchema,
        source: ToolSource.mcp,
        serverId: config.id,
        requiresConfirmation: isDestructive,
        handler: (args) => callTool(tool.name, args),
      );
    }).toList();

    return Result.ok(descriptors);
  }

  bool _isDestructiveName(String toolName) {
    final lower = toolName.toLowerCase();
    return lower.contains('delete') ||
        lower.contains('remove') ||
        lower.contains('stop') ||
        lower.contains('drop') ||
        lower.contains('archive') ||
        lower.contains('close') ||
        lower.contains('cancel') ||
        lower.contains('purge') ||
        lower.contains('revoke') ||
        lower.contains('merge');
  }

  bool _isMethodNotFound(AppFailure? failure) {
    final msg = failure?.message.toLowerCase() ?? '';
    return msg.contains('-32601') || msg.contains('method not found');
  }

  Future<Result<dynamic>> _callRpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = ++_rpcId;
    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    final completer = Completer<dynamic>();
    _pendingRpc[id] = completer;

    try {
      _channel.sink.add(jsonEncode(payload));
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingRpc.remove(id);
          throw TimeoutException('MCP RPC call "$method" timed out.');
        },
      );
      return Result.ok(result);
    } catch (e) {
      _pendingRpc.remove(id);
      return Result.err(ToolFailure(
        toolName: method,
        message: 'MCP RPC call failed: $e',
        cause: e,
      ));
    }
  }

  Future<void> _sendNotification(
    String method,
    Map<String, dynamic> params,
  ) async {
    final payload = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    };
    _channel.sink.add(jsonEncode(payload));
  }

  void _handleIncomingMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id'];
        if (id is int && _pendingRpc.containsKey(id)) {
          final completer = _pendingRpc.remove(id)!;
          if (decoded.containsKey('error')) {
            final errorMap = decoded['error'] as Map<String, dynamic>?;
            final code = errorMap?['code'];
            final message = errorMap?['message'] ?? 'Unknown MCP error';
            completer.completeError(
              Exception('[$code] $message'),
            );
          } else {
            completer.complete(decoded['result']);
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to parse incoming MCP message: $raw', e);
    }
  }

  Future<void> dispose() async {
    _status = McpConnectionStatus.disconnected;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel.close();
    for (final completer in _pendingRpc.values) {
      if (!completer.isCompleted) {
        completer.completeError(const CancelledFailure());
      }
    }
    _pendingRpc.clear();
  }
}
