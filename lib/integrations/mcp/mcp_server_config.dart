enum McpConnectionStatus {
  disconnected,
  connecting,
  connected,
  error;
}

class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.endpointUrl,
    this.bearerToken,
  });

  final String id;
  final String name;
  final String endpointUrl;
  final String? bearerToken;
}
