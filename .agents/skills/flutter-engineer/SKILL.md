---
name: flutter-engineer
description: Guide for Antigravity to implement Flutter UI, Riverpod state management, Drift/SQLite persistence, and responsive multi-pane layouts.
harness: antigravity
---

# Flutter Engineer Skill

## Objectives
- Build robust Flutter widgets adhering to Material 3 design system.
- Implement responsive multi-pane layout:
  - **Desktop / Tablet (>= 768px)**: Collapsible sidebar (conversations list, integrations status), primary chat panel with rich markdown streaming, and collapsible right drawer for tool/task inspector.
  - **Mobile (< 768px)**: Streamlined single-pane chat with bottom sheet menus and sliding drawer.
- Implement Riverpod state management (`StateNotifier` / `AsyncNotifier`) for conversation streams, active tool runs, and settings.
- Implement SQLite local persistence using Drift/sqflite with `flutter_secure_storage` for credentials.

## Quality Standards
- Strict null safety.
- Zero analysis errors (`flutter analyze`).
- Graceful error states and visual indicators for tool loading/streaming.
