# Implementation Plan — Mitra · Mobile & Tablet-first UI Redesign

> **Owner:** Claude Code (architecture) · **Executor:** Antigravity (implementation)
> **Feature:** FEATURE-004 · **Created:** 2026-08-30
> **Baseline verified against:** the tree at 2026-08-30 — Flutter 3.44.6 / Dart 3.12.2.
> **Companion:** [`tasks.md`](./tasks.md) — the executable checklist for this plan.

> **Scope:** presentation + navigation layer — `lib/app/**`, `lib/core/ui/**`,
> `lib/core/utils/breakpoints.dart`, `lib/features/**/presentation/**`, `lib/main.dart`,
> `pubspec.yaml` (two new UI packages), `android/app/src/main/**` (edge-to-edge + launch
> theme), `ios/Runner/Info.plist` (orientation).
> **Non-goals:** no change to the agent loop, MCP protocol, Notion client, Drift schema,
> repositories, or any `application/` controller **API** — controllers may gain
> *additive* methods only (§F4.7.3).

---

## Baseline — what already exists

Mitra is a functionally complete cross-platform Flutter assistant. Everything below is
**built and working**; this plan changes none of it except where §F4 says so explicitly.

| Layer | State |
|---|---|
| Persistence | Drift (`drift_flutter`), conversations / messages / attachments / tool invocations with cascade deletes; `SecretStore` (secure storage) and `PrefsStore` |
| Agent | `AgentOrchestrator` autonomous tool loop, `ToolRegistry`, structured tool-result envelopes, session-scoped `AgentRuntime`, MCP prompts/resources as skills |
| Integrations | `LlmProvider` → Gemini / Anthropic / OpenAI (REST over `dio`); `McpClient` over a hand-rolled Streamable HTTP channel; `NotionClient` on API `2025-09-03` (data-source aware) |
| Ingestion | `receive_sharing_intent` on Android/iOS, `super_drag_and_drop` + `super_clipboard` on desktop, both funnelling into one `ShareInbox` |
| Design system | `MitraSpacing` / `MitraStatusColors` theme extensions, `MitraMotion` (reduce-motion aware), bundled Inter + JetBrains Mono, seeded light/dark `ColorScheme`s with a contrast-tested surface ladder, shared primitives in `lib/core/ui/` |
| Tests | Unit (db, agent, providers, theme contrast/tokens), widget (adaptive shell, tap targets, UI behaviour), goldens |

**Architecture (unchanged):** Presentation → Riverpod state → Domain/Agent →
Data/Integrations. No layer imports upward; integrations never import Flutter widgets.

**The killer workflow (unchanged):** handwrite on a tablet → screenshot → OS share sheet
→ Mitra's incoming-share sheet → multimodal transcription → the agent *executes*, creating
real Notion tasks and rendering interactive cards with deep links and undo.

**v1 targets:** iOS, iPadOS, Android (phone + tablet), macOS. **v1.1:** Windows, Linux.
**Out of scope:** Web.

---

## F4.0 Why this pass exists

The previous refinement pass fixed the *styling*. It did not change the *shape* of the app, and the shape
is desktop-shaped: the layout was designed at 1040 px and then folded down for phones.
Mitra's killer workflow — handwrite on a tablet, screenshot, share into Mitra — happens
on a phone or tablet, in one hand, often outdoors, usually one-handed. That surface is
currently the least considered one in the codebase.

This pass inverts the default: **compact is the reference design, tablet is the second
target, desktop inherits.**

### Audit findings (verified against the tree at 2026-08-30)

**A. Compact has no navigation stack.**
`/` and `/chat/:id` both render `AdaptiveShell`; on compact the shell chooses list-vs-chat
from `activeConversationIdProvider`, and "back" is a manual `context.go('/')`
(`adaptive_shell.dart` compact branch, `chat_header.dart` `onBack`). Consequences, all
reproducible: the Android system back button **exits the app** from an open chat instead
of returning to the list; the iOS interactive edge-swipe does nothing; there is no
predictive-back preview on Android 14+; and `go()` replaces rather than pushes, so no
transition communicates hierarchy.

**B. The chat header renders under the status bar.**
The compact branch puts `ChatHeader` (a fixed-height `Container`, no `SafeArea`) directly
into `Scaffold.body`. A `Scaffold` with no `appBar:` applies no top padding.
`ConversationListPane` does wrap in `SafeArea(bottom: false)`, so the *list* is correct
and the *chat* is not — the bug is invisible on desktop and on every golden.

**C. No edge-to-edge.**
`main.dart` never calls `SystemChrome.setEnabledSystemUIMode`, and no
`SystemUiOverlayStyle` is ever set. Android 15 (`targetSdk 35`) draws edge-to-edge
unconditionally and ignores the legacy opt-out, so system bars will sit on top of app
content. This is a shipping blocker for Android, not a polish item.

**D. The tablet tier is the worst layout in the app.**
Medium (600–1039) renders a `NavigationRail` whose "Chats" destination does nothing but
`openDrawer()`. An iPad in portrait is 834 pt wide — enough for a permanent 320 pt list
plus a 500 pt chat — and instead gets a hidden drawer, while a 1040 pt desktop window
gets three visible panes. The breakpoints themselves are stale: M3 defines window size
classes at **600 / 840 / 1200 / 1600**, not 600 / 1040.

**E. Touch targets and touch gestures are missing in the conversation list.**
Rows are `ListTile(dense: true)` with an 18 px `PopupMenuButton` as the only route to
rename / pin / archive / delete. There is no swipe action and no long-press menu, so
every management action on a phone is a sub-40 dp hit target. (`tap_target_test.dart`
covers `MitraIconButton`, which is why this passed.)

**F. Message affordances are hover-era.**
`MessageActionBar` renders permanently under **every** message — a pattern that exists
because desktop reveals it on hover. On a 360 pt phone it is a persistent row of icons
after every bubble, costing vertical space and adding noise. Renaming a conversation is
bound to a **double-tap** on the header title, which is undiscoverable by touch and has
no long-press equivalent.

**G. The composer is a desktop input row.**
Always-on quick-prompt chip rail above the field (permanent ~40 px tax on a phone);
attach offers gallery only — no camera, no files, which is odd for an app whose premise
is photographing handwritten notes; no haptics; the jump-to-latest pill is hard-coded at
`bottom: 80` (`chat_pane.dart`), so it overlaps a two-line composer and, on a gesture-nav
phone, the home indicator.

**H. The inspector on compact is a fixed-height modal.**
`showModalBottomSheet` at exactly `height * 0.75` — not draggable, no snap points, no
drag handle, and JSON inside it cannot be expanded to full screen.

**I. Settings is one 683-line screen.**
Five sections inline in a single scroll on compact, including every secret field. No
per-section route, so no deep link, no back-within-settings, and a text field near the
bottom of the scroll fights the keyboard.

**J. The share sheet — the killer workflow's front door — is the least finished surface.**
Non-draggable `Container` in a modal; a `FutureBuilder` that re-queries recent
conversations on every `setState`; radio `ListTile`s at `dense: true`; a "Process" button
in a `Row` with the text field, so on a small phone with the keyboard up the primary CTA
is pushed off-screen; and copy like *"Quick Actions (tap to execute directly)"*.

**K. Density and type do not respond to size class.**
`MitraSpacing` is a single const instance. A 360 pt phone and a 1440 pt desktop window
get identical padding. User text renders `bodyMedium`, assistant text `bodyLarge` — the
same message content in two sizes.

**L. Text scaling is clamped at 1.4.**
`app.dart` clamps to `maxScaleFactor: 1.4`. iOS accessibility sizes and the Android font
scale slider both reach 2.0; above 1.4 the app silently ignores the user's setting.

**M. No dynamic color.** Android 12+ users get the brand seed only; there is no
`dynamicColorScheme` path and no way to opt in.

**N. No route transitions on mobile.** `router.dart` returns a plain `MaterialPage` on
Android/iOS and reserves the (fade) transition for desktop — the inverse of where
motion carries the most meaning.

---

## F4.1 What "modern standard" means in this plan

Concretely, and in priority order:

1. **Material 3 adaptive** window size classes and the canonical navigation type per
   class (bottom bar → rail → expanded rail / permanent pane).
2. **List-detail** as the tablet pattern, with a real "no selection" pane — not a drawer.
3. **A real route stack on compact**, so platform back (button, gesture, predictive)
   behaves the way the OS promises.
4. **Edge-to-edge everywhere**, with insets consumed deliberately per surface.
5. **Touch-first affordances**: swipe actions, long-press context sheets, drag handles,
   snapping sheets, haptics on commit actions.
6. **Density and motion that scale with the window**, not one geometry for all.
7. **Accessibility to platform limits**: 48 dp targets, text scale to 2.0, reduce-motion,
   full semantics on every interactive element.

Explicitly *not* in scope: a visual re-brand. Colors, fonts, and the token names already in the codebase
stay. This is about structure and ergonomics.

---

## F4.2 Window size classes and the navigation model

Replace `WindowSizeClass` (`lib/core/utils/breakpoints.dart`) with the M3 set, keeping the
existing enum name so imports do not churn:

| Class | Width | Typical device | Navigation | Panes |
|---|---|---|---|---|
| `compact` | `< 600` | Phone portrait | Bottom `NavigationBar` | 1 |
| `medium` | `600 – 839` | Phone landscape, small tablet, iPad portrait (834) | `NavigationRail` (collapsed, 80) | 2 (list 320 + detail) |
| `expanded` | `840 – 1199` | iPad landscape (1194), small desktop | `NavigationRail` (collapsed) | 2 (list 360 + detail) |
| `large` | `1200 – 1599` | Desktop | `NavigationRail` (expanded, 220) | 3 (list + chat + inspector) |
| `extraLarge` | `≥ 1600` | Large desktop | `NavigationRail` (expanded) | 3, chat capped at `readingMeasureMax` |

```dart
enum WindowSizeClass {
  compact, medium, expanded, large, extraLarge;

  static WindowSizeClass fromWidth(double w) =>
      w < 600 ? compact
    : w < 840 ? medium
    : w < 1200 ? expanded
    : w < 1600 ? large
    : extraLarge;

  bool get isCompact => this == compact;
  bool get isTouchFirst => this == compact || this == medium;
  bool get showsListPane => index >= WindowSizeClass.medium.index;
  bool get showsInspectorPane => index >= WindowSizeClass.large.index;

  NavigationType get navigationType => switch (this) {
        compact => NavigationType.bottomBar,
        medium || expanded => NavigationType.rail,
        large || extraLarge => NavigationType.extendedRail,
      };
}
```

Also add a **height** class so a phone in landscape (e.g. 844 × 390) does not get the
tablet two-pane treatment with 200 px of usable vertical space:

```dart
enum WindowHeightClass { compact, medium, expanded }  // <480 / 480–899 / ≥900
```

The shell must use `medium`+ two-pane **only** when
`heightClass != WindowHeightClass.compact`; otherwise it falls back to the compact
single-pane behaviour with the rail. This is what makes a phone in landscape usable.

**Sizing stays driven by `LayoutBuilder` on the shell's own constraints**, never
`MediaQuery.sizeOf` — what makes iPad Slide Over and
Split View correct for free.

### F4.2.1 `MitraNavigationScaffold` (new, `lib/app/nav/navigation_scaffold.dart`)

Flutter has no `NavigationSuiteScaffold`. Build the equivalent so exactly one widget
knows the nav-type mapping:

```dart
MitraNavigationScaffold({
  required WindowSizeClass sizeClass,
  required List<MitraDestination> destinations,   // icon, selectedIcon, label, route
  required int selectedIndex,
  required ValueChanged<int> onDestinationSelected,
  required Widget body,
})
```

It renders a `NavigationBar` (compact), a `NavigationRail` (medium/expanded), or an
extended `NavigationRail` (large+), and it is the **only** place any of those three
widgets is constructed. Destinations, for all classes:

| # | Destination | Compact route | Notes |
|---|---|---|---|
| 0 | **Chats** | `/chats` | Conversation list → push `/chats/:id` |
| 1 | **Activity** | `/activity` | The tool inspector, promoted from a hidden drawer to a first-class destination (all conversations' invocations, newest first) |
| 2 | **Settings** | `/settings` | Section index on compact (F4.8) |

Promoting the inspector to a destination is what removes the awkward
`endDrawer`-on-tablet and the fixed-height sheet on phone (findings D and H).

---

## F4.3 Compact shell — the reference design

### F4.3.1 Routing (fixes A, N)

Rebuild `router.dart` around `StatefulShellRoute.indexedStack` (go_router 18):

```
StatefulShellRoute.indexedStack
├── branch 0  /chats          → ChatsListScreen
│                /chats/:id   → ChatScreen        (pushed — real stack entry)
├── branch 1  /activity       → ActivityScreen
└── branch 2  /settings       → SettingsIndexScreen
                 /settings/:section → SettingsSectionScreen
```

Each branch keeps its own `Navigator` and scroll position across tab switches. `/chat/:id`
is kept as a **redirect** to `/chats/:id` so existing share-intent deep links, the
`activeConversationIdProvider` writers, and any persisted route survive.

`activeConversationIdProvider` stops being the source of truth for *which screen is
visible* and becomes what it should be: the selection state for the **detail pane on
medium+**. On compact, the route stack is the truth.

Transitions: `MaterialPage` on iOS (gives the interactive edge-swipe back for free) and,
on Android, the platform predictive-back page transition — enable it once at the theme
level rather than per route:

```dart
pageTransitionsTheme: const PageTransitionsTheme(builders: {
  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  // desktop keeps the existing desktop fade
}),
```

Tab switches inside the shell use a **fade-through** (M3 container transform is overkill
here); duration from `MitraMotion`, so reduce-motion still zeroes it.

### F4.3.2 Chat screen chrome (fixes B, F)

`ChatHeader` becomes a real `SliverAppBar.medium`-style header on compact:

- Wrapped by the `Scaffold`'s `appBar:` slot, so insets are handled by the framework —
  the F4.3 rule is that **no bespoke header `Container` ever sits in `Scaffold.body`**.
- Leading: `BackButton()` (automatic — it now has a route to pop).
- Title: conversation title, single line, ellipsised. **Long-press or overflow → Rename.**
  The double-tap binding stays for pointer devices but is no longer the only path.
- Trailing: an overflow `MitraIconButton` opening a bottom sheet with Rename / Pin /
  Archive / Delete / Model picker — the same sheet the list's long-press opens (F4.7.2),
  built once in `lib/features/conversations/presentation/conversation_actions_sheet.dart`.
- The model pill moves **out** of the header into the composer dock (F4.6), where it is
  adjacent to the action it modifies.
- `scrolledUnderElevation` gives the tonal separation; drop the manual bottom `Border`.

### F4.3.3 Edge-to-edge (fixes C)

In `main.dart`, before `runApp`:

```dart
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
));
```

Then the per-surface inset contract, which must be followed exactly or content will be
double-padded:

| Surface | Insets |
|---|---|
| `Scaffold.appBar` | framework-handled — do nothing |
| Message list | `SliverPadding` with `MediaQuery.paddingOf(context).bottom` added to the bottom, so the last message clears the composer + home indicator |
| Composer dock | `SafeArea(top: false)` **plus** `viewInsets.bottom` for the keyboard |
| Bottom sheets | `useSafeArea: true`, `isScrollControlled: true` |
| List pane / rail | `SafeArea(bottom: false)` — the nav bar owns the bottom inset |

Android also needs `android:windowLayoutInDisplayCutoutMode="shortEdges"` and transparent
system bars in `android/app/src/main/res/values*/styles.xml` so the *launch* theme matches
the app theme and there is no white flash band.

---

## F4.4 Tablet — list-detail, not drawers (fixes D)

Delete the `Drawer` / `endDrawer` from the shell entirely. `medium` and `expanded` render:

```
┌──────┬──────────────────────┬───────────────────────────────┐
│ rail │  ConversationList    │   ChatPane (or empty state)   │
│ 80dp │  320 (m) / 360 (e)   │   centred, readingMeasureMax  │
└──────┴──────────────────────┴───────────────────────────────┘
```

- The list pane is **permanent**, not a drawer. Selecting a row updates
  `activeConversationIdProvider` and the detail pane swaps in place with a fade-through —
  no route push, so the tablet never loses the list.
- The list pane stays resizable and persisted on `large`+ only (pointer-driven; keep the
  existing pointer-only drag handle there, drop it on touch classes where an 8 px handle is not
  hittable).
- The inspector on `medium` / `expanded` opens as a **side sheet** (a right-anchored
  `Material` panel animating in over the detail pane, 360 wide, scrim on medium only), not
  an `endDrawer` and not a bottom sheet. On `large`+ it is the third pane, as today.
- **Empty detail pane**: `MitraEmptyState` with a primary "New conversation" action and
  the three most recent conversations as tappable cards — an empty half-screen on a tablet
  should still offer the next action.

### F4.4.1 Tablet-specific input

The killer workflow is a tablet workflow, so these are requirements, not polish:

- **Drag-and-drop of an image onto the chat pane** already exists on desktop via
  `DesktopDropTargetWrapper`; extend the same `ShareInbox` path to iPadOS drag-and-drop
  (`super_drag_and_drop` supports it) so a screenshot can be dragged from Split View.
- **Hardware keyboard**: the existing shortcuts (`lib/app/shortcuts.dart`) are already
  registered on the shell — verify each one on iPadOS with a Magic Keyboard and add
  `Cmd+[` / `Cmd+]` for back/forward within the chats branch.
- **Pointer/trackpad**: hover states on list rows and message action affordances are
  enabled when `sizeClass.isTouchFirst == false` **or** a pointer device is detected;
  never rely on width alone for this.

---

## F4.5 Chat surface for touch (fixes F, K)

1. **`ListView.builder` → `CustomScrollView` + `SliverList.builder`**, so the header can
   collapse on scroll and the bottom inset can be applied as a sliver. Keep
   `ChatScrollCoordinator` and its pin-to-bottom semantics unchanged; it is the
   one piece of this screen that is already right.
2. **Message actions become long-press.** `MessageActionBar` stops rendering inline on
   `sizeClass.isTouchFirst`. Long-press (with `HapticFeedback.selectionClick()`) opens
   `MessageActionsSheet`: Copy, Select text, Retry, Delete, and — for assistant messages
   with tool invocations — "Show in Activity". On pointer classes the inline bar returns
   on hover only. Net effect on a phone: roughly 40 px reclaimed per message and a much
   quieter column.
3. **One type ramp for message content.** Both roles render `bodyLarge` (15/1.55). The
   user bubble keeps `primaryContainer`; the assistant keeps the flat, bubble-less column
   in the current build but drops the 30 px avatar on compact (it costs 46 px of a 360 pt line width)
   in favour of a 2 px leading accent rule.
4. **Attachments**: on compact, a single attachment renders full-bleed to the reading
   measure (max 220 h) instead of a 140 × 140 square; 2+ render as a 2-column grid. The
   hero-to-fullscreen viewer in the current build is unchanged, plus pinch-to-zoom and a swipe-down
   dismiss, which is the expected gesture for a photo viewer on both platforms.
5. **Streaming affordance**: keep the `▌` cursor, and add a subtle "Agent is working"
   status row *inside the composer dock* rather than as a hint-text swap, so the user can
   still see what they typed.

### F4.5.1 Density scales with the window

Add a `MitraDensity` field to the token layer rather than a second `MitraSpacing`:

```dart
enum MitraDensity { comfortable, standard, compact }
// compact window  → comfortable (bigger targets, more padding — one-handed use)
// medium/expanded → standard
// large+          → compact (information density for pointer input)
```

`AdaptiveShell` resolves it from the size class and injects the matching `MitraSpacing`
via a `Theme(data: theme.copyWith(extensions: [...]))` wrapper. Every widget already
reads `context.space`, so **no widget changes** — this is the payoff for the existing token layer.
Multipliers: comfortable `×1.15` on `md/lg/xl` and `minTapTarget = 48`; standard `×1.0`;
compact `×0.85` and `minTapTarget = 40` (pointer classes only).

---

## F4.6 The composer dock (fixes G)

Rewrite `message_composer.dart` as a single **dock** — the M3 expressive input pattern —
rather than an unstructured row:

```
┌───────────────────────────────────────────────────────┐
│  [attachment thumbnails, if any]                      │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Message Mitra…                                 │  │   ← field grows 1→6 lines
│  └─────────────────────────────────────────────────┘  │
│  ⊕  ⚡           gemini-3.7-flash ▾            ( ↑ )  │   ← action row, 48dp targets
└───────────────────────────────────────────────────────┘
```

- **`⊕` attach** opens a bottom sheet: **Camera** (`ImageSource.camera` — the natural way
  to capture a handwritten page), **Photos**, **Files**. Camera is listed first; it is the
  workflow's actual entry point on a phone and is currently unreachable.
- **`⚡` quick prompts** replaces the always-on chip rail. Tapping it expands the chips
  inline (animated, `MitraMotion.standard`); they also auto-expand when the field is empty
  **and** attachments are present — i.e. exactly the share-sheet-lands-in-chat moment.
  This reclaims the permanent 40 px.
- **Model pill** moves here from the header; tapping opens the model picker sheet.
- **Send** is a 48 dp `FilledButton`-style circular target (currently an 18 px icon inside
  a `MitraIconButton`). `HapticFeedback.lightImpact()` on send; `mediumImpact()` on stop.
- Keyboard: the dock is inside `Scaffold(resizeToAvoidBottomInset: true)` and pads by
  `viewInsets.bottom`; `TextField` gets `textInputAction: TextInputAction.newline` on
  touch (Enter must insert a newline on a phone — never send) and keeps the
  Enter-to-send / Shift-Enter-newline bindings on pointer classes only. The IME-composing
  guard stays.
- **Jump-to-latest pill** is positioned relative to the dock's measured height
  (`ValueListenableBuilder` on a `GlobalKey` size, or a `LayoutBuilder` in the same
  `Stack`), never the literal `bottom: 80`.

---

## F4.7 Conversation list for touch (fixes E)

1. **Rows**: drop `dense: true`; two lines (title + last-message snippet or relative
   time), min height 64 (`comfortable`) / 56 (`standard`), leading avatar-style icon.
2. **Swipe actions** via `Dismissible` with `confirmDismiss`:
   - swipe **right** → Pin/Unpin (`status.warning`, `push_pin` icon)
   - swipe **left** → Archive (`status.neutral`); a second, past-threshold drag → Delete
     with the existing undo `SnackBar`.
   Haptic on threshold crossing. Overflow menu remains for pointer classes.
3. **Long-press** → `ConversationActionsSheet` (the same sheet as F4.3.2), with the
   conversation title as the sheet header.
4. **Search** becomes a `SearchBar` pinned in a `SliverAppBar` that hides on scroll-down
   and returns on scroll-up. On compact, tapping it opens a full-screen search view
   (`SearchAnchor.bar`) — the platform pattern, and it gives the results the whole screen.
5. **New conversation** on compact moves from a full-width `FilledButton` to a
   `FloatingActionButton.extended` docked above the `NavigationBar`; the button currently
   occupies prime real estate above the fold on every launch.
6. **Section headers** (Pinned / Today / …) become pinned `SliverPersistentHeader`s.

### F4.7.3 Repository additions (additive only)

Rows want a snippet. `MessageRepository` gains
`Future<Map<String, String>> lastMessagePreviewFor(List<String> conversationIds)` — a
single grouped query, **not** an N+1 per row — and `ConversationListController` exposes it
as a derived provider. No existing signature changes.

---

## F4.8 Settings restructure (fixes I)

- `SettingsIndexScreen` (`/settings`) on compact: a grouped list of the five sections from
  `SettingsSection`, each row showing a **status summary** ("Gemini · key set",
  "Notion · not connected", "MCP · 12 tools") — the information the user actually opens
  settings to check.
- `SettingsSectionScreen` (`/settings/:section`) renders one section with its own app bar
  and back button. Deep-linkable, which also gives the agent a way to say "open Notion
  settings" and land the user in the right place.
- On `medium`+, the same two objects render side by side (nav list 280 + detail), which is
  what `SettingsSectionNav` already does — keep it, and make `SettingsScreen` a thin
  size-class switch between the two compositions.
- Secret fields: obscured by default with a reveal toggle, `autofillHints: []`,
  `enableSuggestions: false`, `keyboardType: TextInputType.visiblePassword`, and a
  "Paste" affordance — pasting a 90-character API key into a phone field is otherwise
  genuinely painful.
- `settings_screen.dart` (683 lines) splits into
  `presentation/sections/{models,notion,mcp,quick_prompts,appearance}_section.dart`. Pure
  extraction; no behaviour change beyond the above.

---

## F4.9 Share sheet — the killer workflow's front door (fixes J)

Rewrite `incoming_share_sheet.dart` as a `DraggableScrollableSheet` with
`snapSizes: [0.55, 0.92]`, `initialChildSize: 0.55`, a drag handle, and a **docked** CTA
row that is pinned to the bottom of the sheet and rides above `viewInsets`.

Layout, top to bottom:

1. **Hero preview** of the shared image(s) — full sheet width, max 200 h, tap to zoom.
   The image *is* the context; a 120 px thumbnail strip buries it.
2. **Quick actions as a 2-column grid of `FilledButton.tonal` cards** (icon + label), not
   a `Wrap` of chips. One tap executes and dismisses. Label copy: "Create Notion tasks",
   "Extract action items", … — no parenthetical instructions.
3. **Target**: a segmented control — **New conversation** | **Existing** — where
   "Existing" reveals the recent list. Default is New. The `FutureBuilder` is replaced by
   a `recentConversationsProvider(limit: 5)` so it does not re-query on every `setState`.
4. **Custom instruction** field with the Process button **below** it, full width.

Performance contract from §8.5 is unchanged and now testable: sheet visible within 400 ms
of foreground. Add a `TimelineTask` trace around `ShareInbox` → first frame so this can be
measured rather than asserted.

---

## F4.10 Theme evolution (fixes M, and the token gaps)

1. **Dynamic color (opt-in).** Add `dynamic_color`. On Android 12+, if
   `settings.useDynamicColor` (new pref, **default off**) is set, harmonise the platform
   `CorePalette` with `AppColorSchemes.brandSeed` via `ColorScheme.harmonized()`; otherwise
   use the existing brand schemes verbatim. The surface-ladder and contrast assertions from
   `theme_contrast_test.dart` must hold for **both** paths — harmonisation can break the
   ladder, so the test runs over a fixture of several seed colors.
2. **Shape scale.** `MitraSpacing` gains `radiusXs = 4` and `radiusXl = 28` (the M3
   expressive large-container radius used by the composer dock and sheets). Existing radii
   keep their values and names.
3. **Motion.** `MitraMotion` gains M3 easing sets — `emphasizedDecelerate`,
   `emphasizedAccelerate`, `standardDecelerate` — plus `Durations`-aligned
   `short4/medium2/long2` names alongside `fast/standard/slow` (keep both; the old names
   are used in ~14 files). `MitraMotion.of()` reduce-motion behaviour is unchanged and
   remains mandatory.
4. **Elevation.** Sheets, the composer dock, and the FAB use `surfaceContainerHigh` +
   `shadowColor` rather than `elevation:` alone, so dark mode does not wash out.
5. Register `pageTransitionsTheme` (F4.3.1) and `navigationBarTheme` /
   `navigationRailTheme` in both `ThemeData`s, so `MitraNavigationScaffold` carries no
   inline styling.

---

## F4.11 Accessibility & input (fixes L)

- Raise the text-scale clamp in `app.dart` to `maxScaleFactor: 2.0` (keep the 0.85 floor)
  and fix the resulting overflows. This *will* surface layout bugs — that is the point.
  Every fixed-height `Container` in the presentation layer must become
  min-height-constrained.
- Every interactive element keeps a `semanticLabel`; swipe actions get
  `CustomSemanticsAction` equivalents so screen-reader users can reach Pin/Archive/Delete
  without the gesture.
- Reduce-motion: every new animation goes through `MitraMotion.of`. The
  `DraggableScrollableSheet` snap animation and the fade-through both honour it.
- Haptics only on **commit** actions (send, delete threshold, quick-action dispatch) and
  `selectionClick` on long-press — never on scroll or hover.
- Test the whole surface with TalkBack and VoiceOver once, at 2.0 text scale, in dark
  mode. This is a checklist item, not an automated test.

---

## F4.12 Testing

| Level | What |
|---|---|
| Unit | `WindowSizeClass.fromWidth` at 599/600/839/840/1199/1200/1599/1600; `WindowHeightClass`; `MitraDensity` resolution; `MitraSpacing` lerp identity for each density |
| Unit | `theme_contrast_test.dart` extended to run its four assertions over the harmonised dynamic-color path for ≥5 fixture seeds |
| Widget | Back from `/chats/:id` pops to `/chats` and does **not** exit (`tester.binding.handlePopRoute`) |
| Widget | Compact renders `NavigationBar`; medium/expanded render `NavigationRail`; large renders three panes; **phone-landscape (844×390) renders the compact body with a rail**, not two panes |
| Widget | Long-press on a message opens `MessageActionsSheet`; the inline action bar is absent on compact |
| Widget | Swipe-left on a conversation row archives it and shows the undo `SnackBar` |
| Widget | Composer: Enter inserts a newline on touch classes and sends on pointer classes; quick-prompt chips auto-expand when attachments are present and the field is empty |
| Widget | Every screen renders without overflow at `textScaleFactor: 2.0` — parameterised over the five size classes |
| Golden | Re-shoot the existing goldens for `{compact, medium, expanded} × {light, dark}`; **delete the stale compact goldens** rather than accepting drift. Add new goldens for the composer dock, the share sheet at both snap points, and a conversation row mid-swipe |
| Manual | Android 15 phone (edge-to-edge, gesture nav, predictive back), iPhone (notch + home indicator), iPad portrait **and** landscape, iPad Split View at 1/3 and 1/2, one Android tablet. Light and dark, each |

`test/widget/adaptive_shell_test.dart` will fail on the new breakpoints — that is expected
and its expectations are updated as part of TASK-1201, not worked around.

---

## F4.13 Sequencing

1. **F4.2 + F4.10** — breakpoints, density, nav scaffold, theme registrations. Blocking:
   everything below is written in this vocabulary.
2. **F4.3.1 + F4.3.3** — routing rebuild and edge-to-edge. Highest blast radius; land it
   second, alone, and verify back-navigation on both platforms before continuing.
3. **F4.3.2 + F4.4** — compact chrome and the tablet list-detail shell.
4. **F4.5 + F4.6** — chat surface and composer dock. Parallel with 5.
5. **F4.7** — conversation list. Parallel with 4.
6. **F4.8** — settings split.
7. **F4.9** — share sheet. Deliberately last among the features: it depends on the sheet
   conventions, the chip components, and the routing established above.
8. **F4.11 + F4.12** — a11y sweep, then goldens and the device matrix, once the visuals
   have stopped moving.

## F4.14 Open questions

1. **Promoting the inspector to a top-level "Activity" destination** (F4.2.1) is the
   biggest conceptual change here. It is what frees the tablet from `endDrawer` and the
   phone from a fixed-height sheet, and it makes tool history browsable across
   conversations — but it also means the inspector is no longer visually tied to the chat
   that produced it. **Assumed: do it**, with a "Show in Activity" action on each message
   preserving the link. Say so if you would rather keep it conversation-scoped.
2. **Dynamic color default.** Assumed **off**, opt-in per user, because Mitra has a
   deliberate brand palette and harmonisation can move the surface ladder. Easy to flip.
3. **Enter-to-send on tablets with a hardware keyboard.** The plan keys this off size
   class (`isTouchFirst`), but an iPad with a Magic Keyboard is `expanded` and should send
   on Enter, while the same iPad undocked should not. Correct fix is to key it off
   *keyboard presence*, which Flutter does not expose portably. **Assumed:** key off size
   class, and add an explicit "Enter sends message" toggle in Settings → Appearance.
4. **Three new packages** (`dynamic_color`, plus `image_picker` camera source needs no new
   dep, plus `file_picker` for the attach → Files option). If adding `file_picker` is
   unwelcome, the Files entry is dropped and attach offers Camera + Photos only.
5. **Golden churn.** This pass invalidates most compact goldens by design. Confirm that
   re-baselining is acceptable rather than treating a golden diff as a regression.
