# Mitra Chat

Mitra Chat is a cross-platform AI assistant that turns handwritten notes and screenshots into executed tasks in Notion, Azure DevOps, and time-tracking tools — directly from your phone, tablet, or desktop.

## Features

- **Multimodal capture** — share a photo or screenshot of handwritten notes and get structured tasks back
- **Notion integration** — creates and links tasks directly in your Notion database
- **MCP gateway** — connects to Azure DevOps, Clockify, Google Calendar, and WakaTime
- **Multi-provider models** — Google Gemini by default, with Claude and OpenAI support
- **Native system share** — appears in the OS share sheet on Android and iOS for instant capture

## Supported Platforms

- Android (phone & tablet)
- iOS / iPadOS
- macOS
- Windows / Linux
- Web

## Tech Stack

- [Flutter](https://flutter.dev) with [Riverpod](https://riverpod.dev) for state management
- [Drift](https://drift.simonbinder.eu) (SQLite) for local persistence
- [go_router](https://pub.dev/packages/go_router) for navigation

## Getting Started

```bash
git clone git@github.com:thegauravgiri/mitra-chat.git
cd mitra-chat
flutter pub get
flutter run
```

### Linux Prerequisites

```bash
sudo apt-get update
sudo apt-get install libsecret-1-dev libjsoncpp-dev
```

## Configuration

Mitra Chat is BYOK (bring your own key) — add your Gemini, Claude, or OpenAI API key and Notion integration token from the in-app Settings.
