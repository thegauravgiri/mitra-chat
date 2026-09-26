import '../../core/failures.dart';
import '../../core/result.dart';
import 'tool_descriptor.dart';

class ToolRegistry {
  final Map<String, ToolDescriptor> _tools = {};

  void register(ToolDescriptor descriptor) {
    _tools[descriptor.name] = descriptor;
  }

  void registerAll(Iterable<ToolDescriptor> descriptors) {
    for (final tool in descriptors) {
      register(tool);
    }
  }

  void unregister(String name) {
    _tools.remove(name);
  }

  void unregisterServer(String serverId) {
    _tools.removeWhere((name, tool) => tool.serverId == serverId);
  }

  void clear() {
    _tools.clear();
  }

  ToolDescriptor? get(String name) => _tools[name];

  List<ToolDescriptor> get all => _tools.values.toList();
  List<ToolDescriptor> getAll() => _tools.values.toList();

  List<String> suggestRelated(String failedToolName, [String? errorKind]) {
    final failedTool = _tools[failedToolName];
    final serverId = failedTool?.serverId;
    final source = failedTool?.source;

    // Extract namespace and raw base name
    String baseName(String name) {
      final parts = name.split('.');
      return parts.isNotEmpty ? parts.last : name;
    }

    List<String> tokenize(String name) {
      return baseName(name)
          .toLowerCase()
          .split(RegExp(r'[_.\-\s]+'))
          .where((t) => t.isNotEmpty)
          .toList();
    }

    final targetTokens = tokenize(failedToolName).toSet();
    const discoveryVerbs = {'list', 'search', 'get', 'find', 'query', 'resolve', 'describe', 'fetch', 'lookup'};

    final scored = <(String name, double score)>[];

    for (final candidate in _tools.values) {
      if (candidate.name == failedToolName) continue;
      if (serverId != null && candidate.serverId != serverId) continue;
      if (serverId == null && source != null && candidate.source != source) continue;

      final candBase = baseName(candidate.name).toLowerCase();
      final candTokens = tokenize(candidate.name).toSet();

      // Calculate token overlap
      final overlap = targetTokens.intersection(candTokens).length;
      double score = overlap * 2.0;

      // Discovery verb bonus
      final hasDiscoveryPrefix = discoveryVerbs.any((v) => candBase.startsWith('${v}_') || candBase.startsWith('$v-') || candBase == v);
      final hasDiscoveryToken = candTokens.any((t) => discoveryVerbs.contains(t));

      if (hasDiscoveryPrefix) {
        score += 5.0;
      } else if (hasDiscoveryToken) {
        score += 3.0;
      }

      // Shared domain prefix bonus (e.g. azure_devops_)
      final targetBase = baseName(failedToolName).toLowerCase();
      final targetPrefix = targetBase.contains('_') ? targetBase.substring(0, targetBase.lastIndexOf('_')) : '';
      if (targetPrefix.isNotEmpty && candBase.startsWith(targetPrefix)) {
        score += 4.0;
      }

      if (score > 0) {
        scored.add((candidate.name, score));
      }
    }

    scored.sort((a, b) {
      final cmp = b.$2.compareTo(a.$2);
      if (cmp != 0) return cmp;
      return a.$1.compareTo(b.$1);
    });

    return scored.take(5).map((e) => e.$1).toList();
  }

  Future<Result<Map<String, dynamic>>> invoke(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      return Result.err(ToolFailure(
        toolName: name,
        message: 'Tool "$name" is not registered in ToolRegistry.',
      ));
    }

    try {
      return await tool.invoke(arguments);
    } catch (e) {
      return Result.err(ToolFailure(
        toolName: name,
        message: 'Tool "$name" execution failed: $e',
        cause: e,
      ));
    }
  }
}
