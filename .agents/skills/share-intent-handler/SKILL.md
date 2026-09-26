---
name: share-intent-handler
description: Guide for Antigravity to implement OS-level share extensions, handle incoming screenshot images, and trigger the conversation picker bottom sheet.
harness: antigravity
---

# Share Intent Handler Skill

## Objectives
- Configure native platform share receivers:
  - **iOS/iPadOS**: Set up Share Extension in `Runner.xcworkspace` with App Group (`group.com.mitra.app`) to capture screenshots/images.
  - **Android**: Configure `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intent filters in `AndroidManifest.xml` for `image/*`.
  - **macOS / Desktop**: Support Drag & Drop into chat window and clipboard paste (`Cmd+V` / `Ctrl+V`).
- When an image is received:
  - Present the **Incoming Share Bottom Sheet Modal**:
    1. **Create New Conversation** (attaches image).
    2. **Attach to Existing Conversation** (shows recent conversations list with search).
    3. **Quick Prompt Chips** (e.g., `Create Notion Tasks`, `Extract Action Items`, `Create Azure PBI`).
  - Pre-populate the message composer with the image and selected quick prompt.
