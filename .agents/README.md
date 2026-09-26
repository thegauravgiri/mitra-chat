# .agents Directory Overview

This directory contains skills, workflow definitions, and agent roles for both **Claude Code** and **Antigravity (AGY)** harnesses working on the **Mitra** project.

## Directory Structure

```
.agents/
├── README.md
├── harnesses/
│   ├── claude_code.md         # Instructions and role definition for Claude Code
│   └── antigravity.md         # Instructions and role definition for Antigravity
└── skills/
    ├── architecture-planner/  # Claude Skill: Architecture design & system modeling
    ├── spec-generator/        # Claude Skill: implementation_plan.md & tasks.md generator
    ├── flutter-engineer/      # Antigravity Skill: Flutter code implementation & Riverpod state
    ├── mcp-connector/         # Antigravity Skill: Mitra MCP (Bearer Token HTTP/SSE) & Desktop stdio
    ├── notion-sync/           # Antigravity Skill: Notion REST API & Schema Detection
    └── share-intent-handler/  # Antigravity Skill: iOS Share Extension & Android Send Intent
```

## Harness Matrix

| Skill Name | Target Harness | Description |
| :--- | :--- | :--- |
| `architecture-planner` | **Claude Code** | Designs system architecture, state flow, and cross-platform layers. |
| `spec-generator` | **Claude Code** | Generates/updates `implementation_plan.md` and atomic `tasks.md`. |
| `flutter-engineer` | **Antigravity** | Implements widgets, Riverpod providers, repositories, and SQLite/Drift. |
| `mcp-connector` | **Antigravity** | Handles MCP client protocol, Bearer token auth, HTTP/SSE streaming, and tool execution. |
| `notion-sync` | **Antigravity** | Parses handwritten tasks, queries Notion schemas, creates tasks via REST/MCP fallback. |
| `share-intent-handler` | **Antigravity** | Configures iOS Share Extension, Android Intent filters, and incoming image bottom sheet. |
