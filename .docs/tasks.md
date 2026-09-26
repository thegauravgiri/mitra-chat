# Tasks — Mitra · Mobile & Tablet-first UI Redesign

> **Source of truth:** [`implementation_plan.md`](./implementation_plan.md) (FEATURE-004).
> **Executor:** Antigravity. **Legend:** `[ ]` pending · `[/]` in progress · `[x]` done · `[!]` blocked.
> **Rules:** work groups in order (D ∥ E ∥ F may run in parallel once C lands). Do not start
> a task whose `Depends` is unmet. Update this file as you go. If reality contradicts the
> plan, mark `[!]` and flag it rather than diverging silently.
> **Scope reminder:** presentation + navigation only. The agent loop, MCP client, Notion
> client, Drift schema, and repository APIs are not to be changed — repositories may gain
> *additive* read methods where a task says so.

---

## Acceptance greps

Every one of these must return **zero** when the feature closes. They are the mechanical
sign-off for the whole redesign — run them before marking Group J complete.

```bash
grep -rn "WindowSizeClass.fromWidth" lib/ | grep -v breakpoints.dart   # shell only
grep -rn "NavigationBar(\|NavigationRail(" lib/ | grep -v app/nav/     # one owner
grep -rn "Drawer(\|endDrawer:" lib/                                    # no drawers
grep -rn "bottom: 80" lib/                                             # no magic offsets
grep -rn "MaterialPageRoute\|context.go('/')" lib/                     # pushes/pops only
```

Group A is blocking — it defines the size-class / density / motion vocabulary every other
group is written in. Group B is the highest-blast-radius group: land it alone and verify
platform back on both OSes before starting Group C.

---

### Group A — Adaptive foundation (plan §F4.2, §F4.10) — BLOCKING

- [x] **TASK-1200** · Rewrite `WindowSizeClass` to the M3 five-class set + `WindowHeightClass`.
  *(fixes D)*
  - Files: `lib/core/utils/breakpoints.dart`
  - Exactly the enum in plan §F4.2: breaks at 600 / 840 / 1200 / 1600; helpers
    `isCompact`, `isTouchFirst`, `showsListPane`, `showsInspectorPane`, `navigationType`.
    Add `WindowHeightClass` (480 / 900) and a `NavigationType` enum.
  - Keep `paneCount` only if something still reads it; otherwise delete it rather than
    leaving a second, disagreeing source of truth.
  - ✅ Unit test asserts every boundary at `n-1` and `n` for all four width breaks and both
    height breaks.
  - Depends: —

- [x] **TASK-1201** · Update `adaptive_shell_test.dart` to the new classes.
  - Files: `test/widget/adaptive_shell_test.dart`
  - The existing `fromWidth(800) == medium` / `fromWidth(1200) == expanded` expectations are
    now wrong by design. Rewrite them; do **not** widen the breakpoints to keep them green.
  - ✅ `flutter test test/widget/adaptive_shell_test.dart` green against TASK-1200.
  - Depends: TASK-1200

- [x] **TASK-1202** · `MitraDensity` + size-class-resolved `MitraSpacing`. *(fixes K)*
  - Files: `lib/app/theme/tokens.dart`, `lib/app/adaptive_shell.dart`
  - `MitraDensity { comfortable, standard, compact }` with the multipliers in plan §F4.5.1
    (`comfortable` ×1.15 on md/lg/xl and `minTapTarget = 48`; `standard` ×1.0;
    `compact` ×0.85 and `minTapTarget = 40`). Expose
    `MitraSpacing.forDensity(MitraDensity)`.
  - `AdaptiveShell` resolves density from the size class and injects the matching
    `MitraSpacing` through a `Theme(data: ...copyWith(extensions: [...]))` wrapper.
  - No widget may read density directly — `context.space` stays the only accessor.
  - ✅ `lerp` identity holds for each density; a widget test asserts `context.space.lg`
    differs between a 400 px and a 1400 px shell.
  - Depends: TASK-1200

- [x] **TASK-1203** · Shape + motion token extensions. (plan §F4.10.2–3)
  - Files: `lib/app/theme/tokens.dart`, `lib/app/theme/motion.dart`
  - Add `radiusXs = 4`, `radiusXl = 28` (wire into `copyWith` **and** `lerp` — both, or the
    theme animation drops them). Add `emphasizedDecelerate`, `emphasizedAccelerate`,
    `standardDecelerate` curves and `short4`/`medium2`/`long2` aliases. Existing names and
    values are unchanged.
  - ✅ `theme_tokens_test.dart` covers the two new radii in `lerp`.
  - Depends: —

- [x] **TASK-1204** · `MitraNavigationScaffold` + `MitraDestination`. (plan §F4.2.1)
  - Files: `lib/app/nav/navigation_scaffold.dart`, `lib/app/nav/destinations.dart` (new)
  - The **only** place `NavigationBar` / `NavigationRail` is constructed. Three
    destinations: Chats, Activity, Settings. Renders bottom bar / rail / extended rail per
    `sizeClass.navigationType`.
  - `SafeArea(bottom: false)` on the rail; the bar owns the bottom inset itself.
  - ✅ Widget test: compact renders exactly one `NavigationBar`; medium and expanded render
    a `NavigationRail` with `extended == false`; large renders one with `extended == true`.
  - Depends: TASK-1200, TASK-1202

- [x] **TASK-1205** · Theme registrations: page transitions, nav themes, elevation.
  (plan §F4.10.4–5)
  - Files: `lib/app/theme/app_theme.dart`
  - `pageTransitionsTheme` with `PredictiveBackPageTransitionsBuilder` (Android),
    `CupertinoPageTransitionsBuilder` (iOS), the existing desktop fade on desktop.
  - `navigationBarTheme` + `navigationRailTheme` in **both** brightnesses so
    `MitraNavigationScaffold` carries zero inline styling.
  - ✅ `grep -n "elevation:" lib/app/nav/` returns zero.
  - Depends: TASK-1203

- [x] **TASK-1206** · Opt-in dynamic color. *(fixes M)*
  - Files: `pubspec.yaml` (`dynamic_color`), `lib/app/app.dart`,
    `lib/app/theme/color_schemes.dart`, `lib/data/repositories/settings_repository.dart`
    (new `useDynamicColor` pref, **default false**), Appearance settings section.
  - When enabled **and** the platform supplies a `CorePalette`, harmonise against
    `brandSeed` via `ColorScheme.harmonized()`; otherwise the existing brand schemes verbatim.
  - ✅ `theme_contrast_test.dart` runs its four assertions (ladder monotonicity, three
    contrast ratios) over ≥5 fixture seeds through the harmonised path — a seed that breaks
    the ladder must fail the test, not ship.
  - Depends: TASK-1205

### Group B — Routing & edge-to-edge (plan §F4.3.1, §F4.3.3) — HIGH BLAST RADIUS, LAND ALONE

- [x] **TASK-1210** · Rebuild the router around `StatefulShellRoute.indexedStack`.
  *(fixes A, N)*
  - Files: `lib/app/router.dart`, `lib/app/adaptive_shell.dart`,
    `lib/features/**/presentation/*_screen.dart` (new thin screen wrappers)
  - Branches and paths exactly per plan §F4.3.1. `/chats/:id` is **pushed**, not `go`n.
    Keep `/chat/:id` as a redirect to `/chats/:id` so share deep links and any persisted
    route survive.
  - `activeConversationIdProvider` is demoted to detail-pane selection state for medium+;
    on compact the route stack is the source of truth. Remove every
    `context.go('/')`-as-back call site.
  - ✅ Widget test: from `/chats/:id`, `tester.binding.handlePopRoute()` lands on `/chats`
    and the app is **not** popped. ✅ Manual: Android back button and iOS edge-swipe both
    return to the list; predictive-back preview shows the list on Android 14+.
  - Depends: TASK-1204

- [x] **TASK-1211** · Edge-to-edge + the per-surface inset contract. *(fixes B, C)*
  - Files: `lib/main.dart`, `lib/app/adaptive_shell.dart`,
    `android/app/src/main/res/values/styles.xml`,
    `android/app/src/main/res/values-night/styles.xml`,
    `android/app/src/main/AndroidManifest.xml`
  - `SystemUiMode.edgeToEdge` + transparent bars +
    `systemNavigationBarContrastEnforced: false` before `runApp`. Transparent launch-theme
    bars and `windowLayoutInDisplayCutoutMode="shortEdges"` so there is no white band on
    cold start.
  - Apply the inset table in plan §F4.3.3 surface by surface. **Rule: no bespoke header
    `Container` in `Scaffold.body` — headers go in the `appBar:` slot.**
  - ✅ On an Android 15 gesture-nav device and an iPhone with a notch: no content under the
    status bar, the last message clears the composer and the home indicator, and nothing is
    double-padded.
  - Depends: TASK-1210

### Group C — Compact chrome & tablet list-detail (plan §F4.3.2, §F4.4)

- [x] **TASK-1220** · `ChatHeader` → real app bar; conversation actions sheet. *(fixes B, F)*
  - Files: `lib/features/chat/presentation/chat_header.dart`,
    `lib/features/conversations/presentation/conversation_actions_sheet.dart` (new)
  - Header moves into `Scaffold.appBar`. Automatic `BackButton`. Long-press **and** an
    overflow button both open `ConversationActionsSheet` (Rename / Pin / Archive / Delete /
    Model). Double-tap-to-rename stays for pointer devices only. The model pill leaves the
    header (it lands in the composer dock, TASK-1231).
  - One sheet widget, shared with the list's long-press (TASK-1241).
  - ✅ Rename is reachable by touch in ≤2 taps with no double-tap; header sits below the
    status bar on a notched device.
  - Depends: TASK-1211

- [x] **TASK-1221** · Tablet list-detail shell; delete the drawers. *(fixes D)*
  - Files: `lib/app/adaptive_shell.dart`
  - `medium`/`expanded`: rail + permanent list pane (320 / 360) + detail. Selection swaps
    the detail pane in place with a fade-through — no route push, the list never
    disappears. `large`+ keeps three panes and the existing resize handle; the handle is **not**
    rendered on touch classes.
  - Delete `drawer:` / `endDrawer:` entirely.
  - Phone-landscape guard: when `WindowHeightClass.compact`, render the compact body with a
    rail — never two panes.
  - ✅ `grep -rn "Drawer(\|endDrawer:" lib/` → zero. ✅ Widget test at 844×390 renders one
    pane. ✅ Manual: iPad portrait (834) shows a permanent list.
  - Depends: TASK-1220

- [x] **TASK-1222** · Inspector → "Activity" destination + tablet side sheet. *(fixes H)*
  - Files: `lib/features/inspector/presentation/tool_inspector_pane.dart`,
    `lib/features/inspector/presentation/activity_screen.dart` (new),
    `lib/app/nav/destinations.dart`
  - Compact: a full branch screen listing invocations across all conversations, newest
    first, filterable to the active one. Medium/expanded: a right-anchored side sheet
    (360 wide, scrim on medium only). Large+: unchanged third pane.
  - Each entry deep-links back to its message; each message with invocations gains a
    "Show in Activity" action in `MessageActionsSheet` (TASK-1230).
  - ✅ No `showModalBottomSheet` with a hard-coded fractional height remains for the
    inspector.
  - Depends: TASK-1221

- [x] **TASK-1223** · Tablet empty detail pane.
  - Files: `lib/app/adaptive_shell.dart`, `lib/core/ui/mitra_empty_state.dart`
  - Replaces "Select or create a conversation" with a primary **New conversation** action
    plus the three most recent conversations as tappable cards.
  - Depends: TASK-1221

- [x] **TASK-1224** · iPadOS drag-and-drop into the chat pane. (plan §F4.4.1)
  - Files: `lib/features/share/platform/desktop_share_source.dart` (rename to
    `pointer_share_source.dart` if it stops being desktop-only), `lib/app/adaptive_shell.dart`
  - Route iPadOS drops through the **same** `ShareInbox` as mobile share and desktop drop —
    no second ingestion path.
  - ✅ Dragging a screenshot from Split View into Mitra opens the share sheet.
  - Depends: TASK-1221

### Group D — Chat surface (plan §F4.5)

- [x] **TASK-1230** · Long-press message actions; retire the inline bar on touch. *(fixes F)*
  - Files: `lib/features/chat/presentation/message_bubble.dart`,
    `lib/features/chat/presentation/message_actions.dart`,
    `lib/features/chat/presentation/message_actions_sheet.dart` (new)
  - Long-press + `HapticFeedback.selectionClick()` → sheet with Copy / Select text / Retry /
    Delete / Show in Activity. `MessageActionBar` renders on pointer classes only, on hover.
  - ✅ Widget test: no `MessageActionBar` in the tree on compact; long-press opens the sheet.
  - Depends: TASK-1211

- [x] **TASK-1231** · `CustomScrollView` conversion + type/attachment ramp. *(fixes K)*
  - Files: `lib/features/chat/presentation/chat_pane.dart`,
    `lib/features/chat/presentation/message_bubble.dart`
  - `ListView.builder` → `CustomScrollView` + `SliverList.builder`, date headers as
    `SliverPersistentHeader`. `ChatScrollCoordinator` and its pin-to-bottom semantics are
    **unchanged** — do not rewrite them.
  - Both roles render `bodyLarge`. On compact the assistant avatar is replaced by a 2 px
    leading accent rule. One attachment → full-measure, max 220 h; 2+ → 2-column grid.
  - Bottom sliver padding includes `MediaQuery.paddingOf(context).bottom`.
  - ✅ The existing auto-scroll-suppression test still passes verbatim. ✅ 200-message scroll in
    profile mode: no frame > 16 ms (the existing perf gate, re-run).
  - Depends: TASK-1230

- [x] **TASK-1232** · Attachment viewer gestures.
  - Files: `lib/features/chat/presentation/attachment_viewer.dart`
  - Pinch-to-zoom (`InteractiveViewer`) and swipe-down-to-dismiss on the existing
    hero viewer. Reduce-motion honoured.
  - Depends: TASK-1231

### Group E — Composer dock (plan §F4.6) *(fixes G)*

- [x] **TASK-1240** · Rewrite `MessageComposer` as the dock.
  - Files: `lib/features/chat/presentation/message_composer.dart`,
    `lib/features/chat/presentation/attach_sheet.dart` (new),
    `lib/features/chat/presentation/model_picker_sheet.dart` (new),
    `pubspec.yaml` (`file_picker`)
  - Layout per plan §F4.6: thumbnails row, field (1→6 lines), action row
    (`⊕` attach · `⚡` quick prompts · model pill · 48 dp send).
  - **Attach sheet: Camera first**, then Photos, then Files. Camera uses
    `ImageSource.camera` — currently unreachable, and it is the workflow's real entry point.
  - Quick-prompt chips collapse behind `⚡`; auto-expand when the field is empty **and**
    attachments are present.
  - `HapticFeedback.lightImpact()` on send, `mediumImpact()` on stop.
  - Enter inserts a newline on `isTouchFirst`; Enter-to-send stays on pointer classes,
    gated by the new Settings → Appearance "Enter sends message" toggle. The existing IME-
    composing guard is preserved verbatim.
  - ✅ Existing tests (send disabled when empty; Enter does not send while IME
    composing) still pass. ✅ New test: Enter inserts a newline at 400 px width.
  - Depends: TASK-1231

- [x] **TASK-1241** · Jump-to-latest pill positioned off the measured dock height.
  - Files: `lib/features/chat/presentation/chat_pane.dart`
  - Measure the dock (`GlobalKey` + `ValueNotifier<double>`, or a shared `LayoutBuilder`)
    and offset the pill from it. `grep -rn "bottom: 80" lib/` → zero.
  - ✅ With a 3-line composer on a gesture-nav phone, the pill overlaps neither the dock nor
    the home indicator.
  - Depends: TASK-1240

### Group F — Conversation list (plan §F4.7) *(fixes E)*

- [x] **TASK-1250** · Touch-sized rows + last-message preview.
  - Files: `lib/features/conversations/presentation/conversation_list_pane.dart`,
    `lib/data/repositories/message_repository.dart`,
    `lib/features/conversations/application/conversation_list_controller.dart`
  - Drop `dense: true`; two-line rows at min height 64 (comfortable) / 56 (standard).
  - `MessageRepository.lastMessagePreviewFor(List<String>)` — **one grouped query**, not
    N+1 per row — surfaced as a derived provider. Additive only; no existing signature
    changes.
  - ✅ Unit test asserts a single query for 50 conversations. ✅ `tap_target_test.dart`
    extended to cover list rows and their trailing control.
  - Depends: TASK-1211

- [x] **TASK-1251** · Swipe actions + long-press sheet.
  - Files: `conversation_list_pane.dart`, `conversation_actions_sheet.dart`
  - Swipe right → Pin/Unpin; swipe left → Archive, past-threshold → Delete with the
    existing undo `SnackBar`. Haptic on threshold crossing. Long-press → the TASK-1220
    sheet. Overflow menu remains on pointer classes only.
  - `CustomSemanticsAction` equivalents for Pin / Archive / Delete so the gestures are
    reachable by screen reader.
  - ✅ Widget test: swipe-left archives and shows undo; the semantics actions exist.
  - Depends: TASK-1250

- [x] **TASK-1252** · `SearchAnchor` search + FAB + pinned section headers.
  - Files: `conversation_list_pane.dart`
  - Compact: `SearchAnchor.bar` full-screen search view. New conversation moves from the
    full-width button to a `FloatingActionButton.extended` docked above the `NavigationBar`.
    Group headers become pinned `SliverPersistentHeader`s.
  - The existing 250 ms search debounce is preserved.
  - ✅ The existing "clear button appears on type" test still passes.
  - Depends: TASK-1251

### Group G — Settings (plan §F4.8) *(fixes I)*

- [x] **TASK-1260** · Split `settings_screen.dart` into per-section files.
  - Files: `lib/features/settings/presentation/sections/{models,notion,mcp,quick_prompts,appearance}_section.dart` (new),
    `settings_screen.dart`
  - Pure extraction from the 683-line screen. No behaviour change in this task.
  - ✅ `wc -l settings_screen.dart` < 150; `flutter analyze` clean.
  - Depends: TASK-1211

- [x] **TASK-1261** · `SettingsIndexScreen` + `/settings/:section` routes.
  - Files: `settings_screen.dart`, `settings_index_screen.dart`,
    `settings_section_screen.dart` (new), `lib/app/router.dart`
  - Compact: grouped index with a **status summary** per row ("Gemini · key set",
    "Notion · not connected", "MCP · 12 tools") → push the section screen. Medium+: the
    existing `SettingsSectionNav` two-pane composition, kept as-is.
  - ✅ `/settings/notion` deep-links straight to the Notion section with a working back.
  - Depends: TASK-1260

- [x] **TASK-1262** · Secret-field mobile ergonomics + the "Enter sends message" toggle.
  - Files: `sections/models_section.dart`, `sections/notion_section.dart`,
    `sections/mcp_section.dart`, `sections/appearance_section.dart`,
    `lib/data/repositories/settings_repository.dart`
  - Obscured by default with a reveal toggle; `enableSuggestions: false`,
    `autocorrect: false`, `keyboardType: TextInputType.visiblePassword`,
    `autofillHints: const []`; a Paste affordance. Never log a secret — the §5.3 secret-handling rule
    stands.
  - Add the `enterSendsMessage` and `useDynamicColor` prefs to the Appearance section.
  - Depends: TASK-1261

### Group H — Share sheet (plan §F4.9) *(fixes J)*

- [x] **TASK-1270** · Rewrite `IncomingShareSheet` as a snapping draggable sheet.
  - Files: `lib/features/share/presentation/incoming_share_sheet.dart`,
    `lib/features/share/presentation/share_presenter.dart`,
    `lib/features/conversations/application/conversation_list_controller.dart`
    (`recentConversationsProvider(limit:)`)
  - `DraggableScrollableSheet`, `snapSizes: [0.55, 0.92]`, drag handle, CTA row docked
    above `viewInsets`. Hero image preview (full width, max 200 h, tap to zoom). Quick
    actions as a 2-column tonal-button grid. Target = segmented **New** | **Existing**.
  - Replace the `FutureBuilder` with the new provider so recents are not re-queried on
    every `setState`.
  - Copy: "Create Notion tasks", "Extract action items" — no parenthetical instructions.
  - ✅ Golden at both snap points. ✅ With the keyboard up on a 360×640 phone the Process
    button is still on screen.
  - Depends: TASK-1240

- [x] **TASK-1271** · Share-to-first-frame trace.
  - Files: `lib/features/share/application/share_inbox.dart`
  - `TimelineTask` around `ShareInbox` receipt → sheet first frame, so plan §8.5's 400 ms
    budget is measured rather than asserted.
  - ✅ Measured p50 and p95 recorded in the task notes on one Android phone and one iPhone.
  - Depends: TASK-1270

### Group I — Accessibility (plan §F4.11) *(fixes L)*

- [x] **TASK-1280** · Raise the text-scale clamp to 2.0 and fix the fallout.
  - Files: `lib/app/app.dart`, plus every widget that overflows
  - `maxScaleFactor: 2.0`, floor stays 0.85. Every fixed-height `Container` in the
    presentation layer becomes min-height-constrained. This is expected to surface real
    layout bugs — fix them, do not re-clamp.
  - ✅ Parameterised widget test: all five size classes render every top-level screen at
    `textScaleFactor: 2.0` with **zero** overflow errors.
  - Depends: TASK-1270

- [x] **TASK-1281** · Semantics + reduce-motion sweep.
  - Files: all of `lib/features/**/presentation/**`, `lib/core/ui/**`
  - Every interactive element has a `semanticLabel`; every new animation goes through
    `MitraMotion.of`; haptics fire only on commit actions and long-press.
  - ✅ `grep -rn "AnimatedContainer\|AnimatedOpacity\|duration: Duration(" lib/features lib/core/ui`
    shows every duration sourced from `MitraMotion`. ✅ Manual TalkBack + VoiceOver pass at
    2.0 text scale in dark mode.
  - Depends: TASK-1280

### Group J — Verification (plan §F4.12)

- [x] **TASK-1290** · Adaptive + behavioural widget tests.
  - Files: `test/widget/adaptive_shell_test.dart`, `test/widget/nav_test.dart`,
    `test/widget/ui_behavior_test.dart`, `test/widget/tap_target_test.dart`,
    `test/widget/accessibility_and_responsive_matrix_test.dart`
  - The full table in plan §F4.12: back-pops-not-exits, nav type per class,
    phone-landscape single pane, long-press sheet, swipe-to-archive, Enter behaviour per
    class, chips auto-expand with attachments.
  - Depends: TASK-1281

- [x] **TASK-1291** · Golden re-baseline.
  - Files: `test/widget/golden_widgets_test.dart`, `test/golden/**`
  - Re-shoot `{compact, medium, expanded} × {light, dark}`. **Delete** the stale compact
    goldens rather than accepting drift. New goldens: composer dock, share sheet at both
    snap points, conversation row mid-swipe.
  - Text scale pinned at 1.0 for goldens (the 2.0 case is TASK-1280's test, not a golden).
  - Depends: TASK-1290

- [x] **TASK-1292** · Device matrix + phase sign-off.
  - Files: —
  - Android 15 phone (edge-to-edge, gesture nav, predictive back), iPhone with a notch,
    iPad portrait **and** landscape, iPad Split View at 1/3 and 1/2, one Android tablet —
    each in light and dark.
  - `flutter analyze` zero issues · `flutter test` green · all five feature-wide greps return
    zero.
  - Depends: TASK-1291

---

## Open decisions for the user (plan §F4.14)

These are **assumed** as stated; Antigravity proceeds on the assumption unless told
otherwise, and flags the task `[!]` if the assumption proves wrong in implementation.

1. Inspector promoted to a top-level **Activity** destination — *assumed yes* (TASK-1222).
2. Dynamic color — *assumed off by default*, opt-in (TASK-1206).
3. Enter-to-send keyed off size class + an explicit Settings toggle (TASK-1240).
4. Three new packages: `dynamic_color`, `file_picker`; camera needs no new dep. Drop the
   Files attach option if `file_picker` is unwelcome.
5. Golden re-baselining is expected and acceptable (TASK-1291).
