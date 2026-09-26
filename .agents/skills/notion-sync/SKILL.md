---
name: notion-sync
description: Guide for Antigravity to sync tasks and notes into Notion, dynamically detecting database schema from Mitra MCP Notion Dashboard skill with Notion REST API fallback.
harness: antigravity
---

# Notion Sync Skill

## Objectives
- Dynamically detect Notion Database schema:
  1. **Primary**: Query the Notion Dashboard skill schema from Mitra MCP.
  2. **Fallback**: Query Notion API `v1/databases/{database_id}` directly using Notion Integration Token.
- Convert parsed handwritten todos into Notion database pages/tasks with properties:
  - Task title (`title`)
  - Status (`status` / `select`: To Do, In Progress, Done)
  - Due date (`date`)
  - Priority (`select`: High, Medium, Low)
  - Tags / Category (`multi_select`)
- Render interactive task creation preview cards in the Flutter chat UI with direct clickable links to Notion pages and instant edit/undo options.
