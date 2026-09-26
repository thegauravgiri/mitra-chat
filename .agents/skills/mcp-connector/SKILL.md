---
name: mcp-connector
description: Guide for Antigravity to connect to the Mitra MCP server over HTTP/SSE via Bearer token, discover tools, and invoke Azure DevOps, Clockify, Calendar, and WakaTime tools.
harness: antigravity
---

# MCP Connector Skill

## Objectives
- Connect to the **Mitra MCP Gateway** via HTTP / SSE using Bearer token authentication.
- Provide a unified Dart `McpClient` interface:
  - `listTools()`: Discovers available tools (Azure DevOps, Clockify, Google Calendar, WakaTime, etc.).
  - `callTool(name, arguments)`: Executes a tool on the MCP server and returns the structured JSON result.
- Support Desktop local MCP stdio sub-processes when available, falling back seamlessly to HTTP/SSE.
- Expose tool schemas directly to the LLM agent function-calling engine.

## Authentication & Headers
- Pass `Authorization: Bearer <token>` on all HTTP/SSE MCP requests.
- Persist endpoint URL and Bearer token in `flutter_secure_storage`.
