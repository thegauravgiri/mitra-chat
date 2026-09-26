# AGENTS.md - Multi-Harness Collaboration Guide for Mitra

## 1. Overview & Dual-Harness Workflow
This project (`mitra`) utilizes a collaborative dual-harness workflow:
- **Claude Code**: High-level system architecture, feature planning, generating and updating `.docs/implementation_plan.md` and `.docs/tasks.md`, and heavy architectural refactor planning.
- **Antigravity (AGY)**: Direct execution and implementation of the tasks outlined in `.docs/tasks.md`, code generation, test-driven validation, bug fixing, and task progress tracking.

```
┌─────────────────────────────────────────────────────────────┐
│                       User Request                          │
└──────────────┬───────────────────────────────┬──────────────┘
               │ (Feature / Architectural Plan) │ (Task Execution / Bugfix)
               ▼                               ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│         Claude Code          │ │        Antigravity         │
│  - Architecture & Design     │ │  - Reads .docs/            │
│  - Generates/Overwrites:     │ │    implementation_plan.md  │
│    • .docs/                  │ │    & .docs/tasks.md        │
│      implementation_plan.md  │ │  - Implements code         │
│    • .docs/tasks.md          │ │  - Runs tests & builds     │
│                              │ │  - Updates .docs/tasks.md  │
└──────────────────────────────┘ └────────────────────────────┘
```

---

## 2. Shared File Protocol (`.docs/`)

All cross-agent communication documents live inside the **`.docs/`** directory:

### `.docs/implementation_plan.md`
- **Owner**: Claude Code (creates and updates when new features or refactors are planned).
- **Consumer**: Antigravity (reads the blueprint, technical specifications, and architectural constraints).
- **Rule**: When Claude Code is asked for a new feature or scope change, it updates/overwrites `.docs/implementation_plan.md` and `.docs/tasks.md`.

### `.docs/tasks.md`
- **Owner**: Claude Code generates initial checklist; Antigravity updates task completion statuses.
- **Format**: Standard Markdown checkboxes (`[ ]` Pending, `[/]` In Progress, `[x]` Completed).
- **Rule**: Antigravity must check off items in `.docs/tasks.md` as work progresses and summarize status.

### Post-Planning Completion Hook
- **Mandatory Action**: Every time Claude Code finishes creating or updating `.docs/implementation_plan.md` and `.docs/tasks.md`, it **MUST** execute the hook:
  ```bash
  .agents/hooks/plan_complete.sh
  ```
  This signals completion of the planning phase and notifies the developer.

---

## 3. Product Vision & Architecture Summary

### Core Objective
Mitra is a cross-platform conversational UI application (Mobile, Tablet, Desktop) built in Flutter that connects directly with the **Mitra Agent**, **Mitra MCP**, and **Notion**.

### The Killer Workflow
1. **Handwritten Notes on Tablet**: User writes/draws todos or notes on their tablet (iPad / Android tablet).
2. **System Share**: User takes a screenshot and selects **Mitra** in the OS Share Sheet.
3. **Incoming Share Sheet**: Mitra opens an interactive bottom sheet modal:
   - **Create New Conversation** (attaches image).
   - **Attach to Existing Conversation** (recent list with search).
   - **Quick Action Chips** (`Create Notion Tasks`, `Extract Todos`, `Log Time`, `Azure DevOps PBI`).
4. **Multimodal Agent Parsing**: Agent analyzes the image using Google Gemini (multimodal vision default, with Claude/OpenAI multi-provider support).
5. **Direct Tool Execution**: Agent creates tasks directly in the configured Notion Database (using schema info from Mitra MCP Notion Dashboard skill with Notion REST API fallback) and returns structured interactive cards with Notion links and undo/edit actions.

---

## 4. Technology Stack & Key Libraries

- **Framework**: Flutter (iOS, iPadOS, Android, macOS, Linux, Windows, Web)
- **State Management**: `flutter_riverpod` + `riverpod_annotation`
- **Local Persistence**: `sqlite` (via `drift` / `sqflite`) for conversations & messages; `flutter_secure_storage` for credentials.
- **Multimodal LLM**: Google Gemini SDK (`google_generative_ai`) / REST client (multi-provider architecture).
- **Sharing & Ingestion**: `receive_sharing_intent` with iOS Share Extension (`com.mitra.app`) and Android `ACTION_SEND` Intent filters.
- **Integrations**:
  - **Mitra MCP Gateway**: HTTP/SSE client with Bearer Token authentication (accesses Azure DevOps, Clockify, Google Calendar, WakaTime).
  - **Notion**: Direct Dart REST client and Notion MCP skill support.
  - **Custom MCP Hub**: Extensible settings to add additional MCP servers and bearer tokens.
- **UI & Layout**: Responsive 2/3-pane layout on Desktop/Tablet, streamlined single-pane + modal bottom sheet on Mobile. Material 3 dark/light design.

---

## 5. Agent & Skill Segregation

### Harness Responsibilities
| Harness | Primary Scope | Assigned Skills (`.agents/skills/`) |
| :--- | :--- | :--- |
| **Claude Code** | Planning, Architectural Specs, Task Breakdown, Refactoring Strategies | `architecture-planner`, `spec-generator` |
| **Antigravity** | Execution, Flutter Engineering, Test Validation, MCP/API Integration, State Mgmt | `flutter-engineer`, `mcp-connector`, `notion-sync`, `share-intent-handler` |

---

## 6. Development Guidelines for Agents
1. **Preserve Documentation**: Never remove `AGENTS.md` rules or erase prior architectural context without user instruction.
2. **Modular Architecture**: Follow clean architecture (Data sources -> Repositories -> Riverpod Providers -> Presentation UI).
3. **Null Safety & Strict Lints**: Maintain clean analysis with Flutter linter.
4. **Secure Token Storage**: Never hardcode API keys or Bearer tokens; always use `flutter_secure_storage`.
