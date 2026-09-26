---
name: architecture-planner
description: Guide for Claude Code to design Flutter multi-platform architecture, Riverpod state models, and integration bridges.
harness: claude_code
---

# Architecture Planner Skill

## Objectives
- Design modular, scalable Flutter application architectures targeting Mobile, Tablet, and Desktop.
- Model data flows between local SQLite persistence, Riverpod state providers, Multimodal LLMs, and MCP/REST connectors.

## Key Design Patterns
1. **Clean Architecture / Feature-First Layering**:
   - `core/`: Themes, utilities, errors, network clients, secure storage.
   - `features/chat/`: Conversation state, message bubbles, markdown renderer, prompt input, quick chips.
   - `features/agent/`: LLM abstraction (Gemini, Claude, OpenAI), tool orchestration, prompt templates.
   - `features/integrations/`: Mitra MCP connector, Notion API sync, custom MCP client.
   - `features/share_receiver/`: Incoming share sheet listener, bottom sheet picker modal.
   - `features/settings/`: API keys, MCP endpoint URLs, Notion Database ID, appearance.
2. **State Management**:
   - Riverpod `AsyncNotifier` for async streams, tool executions, and conversation states.
   - Immutable data models using `@freezed` / `dart_mappable` or pure Dart dataclasses.
