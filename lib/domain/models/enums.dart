enum MessageRole {
  user,
  assistant,
  tool,
  system;
}

enum MessageStatus {
  pending,
  streaming,
  complete,
  failed;
}

enum ToolSource {
  builtin,
  mcp;
}

enum ToolStatus {
  pending,
  running,
  ok,
  error,
  undone;
}
