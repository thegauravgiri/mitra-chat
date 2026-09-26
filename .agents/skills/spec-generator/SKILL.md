---
name: spec-generator
description: Guide for Claude Code to generate .docs/implementation_plan.md and .docs/tasks.md with clear acceptance criteria and atomic task breakdowns.
harness: claude_code
---

# Spec Generator Skill

## Objectives
- Generate unambiguous, actionable `.docs/implementation_plan.md` documents.
- Generate structured, checkable `.docs/tasks.md` checklists that Antigravity can execute step-by-step.

## Rules for `.docs/implementation_plan.md`
1. Include Architecture Overview, Component Diagrams, Data Models, Interface Definitions, and Error Handling strategies.
2. Specify exact file paths and dependencies.
3. Detail how each requirement from user interviews/grilling is addressed.

## Rules for `.docs/tasks.md`
1. Group tasks logically into phases (e.g., Setup & Core -> Local Database & Riverpod -> Integrations & MCP -> Share Intent & Multimodal Agent -> UI & Polish).
2. Each task must have a checkbox `[ ]`, task ID, clear description, and target files.
3. Antigravity will mark items as `[x]` upon completion.

## Mandatory Hook Call
- Immediately execute the completion hook via shell every time planning/spec generation finishes:
  ```bash
  .agents/hooks/plan_complete.sh
  ```

