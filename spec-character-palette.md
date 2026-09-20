# Character Palette — Specification and Handover

Status: specification only. Do not implement from this file without the user's go-ahead.
Audience: Codex, or any agent that picks this up with no session context.
Written 2026-09-20 against `main` at `269c7b92`; revalidated after the handover integration at `1b63a8f2`.
The referenced files and symbols still exist, although line numbers may have shifted. Re-resolve anchors
before implementation.

## Context

`alt-tab+` is a macOS companion app. The user asked whether PopChar-like functionality can be
rebuilt as a GUI that the menubar menu opens.

The answer is yes. The costly parts already exist in this repo:

- A paste path with clipboard snapshot and restore: `src/logic/system-actions/SystemUtilities.swift:20-58`.
- A menu-and-shortcut registration path that needs two lines per action.
- Two panel patterns: a non-key HUD panel and a key-taking floating panel.

What is missing is a character index, a ranking over it, and a focusable picker panel.

Research on comparable projects produced these verified facts. They shaped the design.

| Project | Licence | Fact that matters |
|---|---|---|
| `wr/mojito` | AGPL-3.0, Swift | Best UX model. Do not copy code: AGPL. |
| `RickLiu1203/FujiMoji` | MIT, Swift | Picker opens after 2 characters. Configurable trigger keys. |
| `ChristopherChifor/jetmoji` | none stated | Degrades to copy-only when Accessibility is absent. |
| `izyumkin/MCEmojiPicker` | MIT | **iOS only.** Not usable here. |
| `EyrisCrafts/retro_emojis` | none stated | Flutter, clipboard only. Not a reference. |
| `PunctoDock` | — | **Does not exist.** An earlier research pass invented it. |

UX ideas taken from Mojito and FujiMoji: keyboard-only operation, arrow keys plus Return,
named symbol groups such as `:cmd:` for `⌘`, and text-arrow conversion.

## Decisions already made by the user

1. Scope of the first step: a **curated technical symbol set**, about 300 to 600 characters.
   Emoji are out of scope for now.
2. Clipboard behaviour: **restore the previous clipboard**, like `pasteAsPlainText`.
3. When no text field has focus: **copy only and show a notice**. Do not paste blindly.

Out of scope for the first step, by the same decision: inline `:shortcode:` triggers, emoji,
skin tones, GIFs, per-app profiles. An inline trigger needs a permanent event tap and the
*Input Monitoring* right, which this app does not hold today. That is a separate decision.

## Hard constraints of this codebase

Read `AGENTS.md` first. The rules that bite here:

- Pure Swift 5.8 AppKit. **No SwiftUI. No Interface Builder.** This rules out every SwiftUI
  picker component found in the research.
- No blank-line groups inside a method. Split into sub-methods instead.
- Guard clauses, happy path below them.
- Group files by feature in their own folder.
- Do not drive Xcode. Copy the commands from `ai/build.sh` and run them.

The unit-tests target is **not** a host-app test bundle. It compiles a hand-picked file list.
Pure logic that tests need therefore goes into a `*Testable.swift` file, which is added to
**both** targets. The rule is stated at `src/logic/Preferences.swift:568-569`.

## Design

### New files

```
src/logic/character-palette/CharacterCatalogTestable.swift   both targets
src/logic/character-palette/CharacterCatalog.swift           app target
src/logic/character-palette/CharacterPalette.swift           app target
src/ui/CharacterPalettePanel.swift                           app target
unit-tests/CharacterPaletteTests.swift                       test target
```

`CharacterCatalogTestable.swift` holds only Foundation-level logic:

- `struct CharacterEntry { let text: String; let name: String; let aliases: [String]; let group: CharacterGroup }`
- `enum CharacterGroup: String, CaseIterable` — `arrows`, `boxDrawing`, `math`, `status`,
  `currency`, `greek`, `punctuation`, `keys`.
- `static func rank(_ entries: [CharacterEntry], query: String, recents: [String]) -> [CharacterEntry]`
- `static func decodeList` / `encodeList` for the recents list.

`CharacterCatalog.swift` holds the curated table as a Swift array literal. It is a source file,
not a bundled resource, on purpose: the repo has **no precedent for a bundled JSON or TXT data
table**, and adding one needs a new `PBXFileReference`, a `PBXBuildFile` and a Resources-phase
entry in `project.pbxproj`. A Swift literal of this size avoids that plumbing and needs no
file I/O at launch. If the catalog later grows past a few thousand entries, revisit this.

Unicode names do not need a shipped table. `kCFStringTransformToUnicodeName` is public API and
is present in the SDK — verified at `CFString.h:727`. Use it to derive a display name lazily,
and keep only hand-written aliases in the table.

### Ranking

Reuse the existing scorer. Do not write a second one.

- `Search.smithWatermanHighlightsIgnoringSpaces(query:text:topK:allowOverlaps:)` —
  `src/logic/search/Search.swift:49`.
- `SearchTestable.acronymBonus(query:text:)` — `src/logic/search/SearchTestable.swift:4-47`.

`Search.matches` and `Search.relevance` are bound to `Window` and cache into
`window.swBestSimilarity`. **Do not extend `Window`.** Call the two stateless helpers above
directly from `CharacterCatalogTestable.rank`, and score against name, aliases and group name.
Recents get a fixed bonus so a repeated character stays at the top.

### Action registration

Two lines, plus nothing else. Everything downstream derives from `SystemAction.allCases`.

1. `src/logic/system-actions/SystemActionTestable.swift:5-37` — add
   `case characterPalette = "tools.characterPalette"`. The raw value is the persisted stable id.
   Do not change it later; Leader and FlickRing bindings key off it.
2. `src/logic/system-actions/SystemActions.swift:48-54` — add one `make(...)` row to
   `toolActions`, group `.tools`, SF symbol `character.textbox`, title
   `NSLocalizedString("Character Palette", comment: "")`.

These derive automatically and need no edit:

| Derived thing | Where |
|---|---|
| Action registry entry | `src/logic/actions/Actions.swift:89-91` |
| Empty default shortcut | `src/logic/Preferences.swift:116-118` |
| Shortcut dispatch closure | `src/ui/settings-window/tabs/controls/ControlsTab.swift:169-171` |
| Global hot-key id | `src/logic/events/KeyboardEventsTestable.swift:38-40` |
| Menubar menu entry | `src/ui/menubar-menu/MenubarMenu.swift:114-122` |
| Shortcuts overview row | `src/ui/settings-window/tabs/ShortcutOverviewTab.swift:223-229` |
| Leader and FlickRing popup | `src/ui/settings-window/LabelAndControl.swift:366` |

Use the existing `.tools` group. A **new** `MenuGroup` case would force edits in
`MenuLayoutTestable.swift:5-24`, the exhaustive `switch` in `MenubarMenu.groupTitle`
(`MenubarMenu.swift:98-110`) and the ordering assertions in `unit-tests/MenuLayoutTests.swift:65-74`.
Avoid that.

Localisation needs no manual key file edit. `scripts/l10n/extract_l10n_strings.sh:10` runs
`genstrings` over `src/**/*.swift`.

### Panel

Model it on `TilesPanel` (`src/ui/main-window/TilesPanel.swift:3-30`), not on `LeaderPanel`.
`LeaderPanel` sets `canBecomeKey = false` and cannot host a search field.

Required configuration:

- `override var canBecomeKey: Bool { true }`
- `styleMask: .nonactivatingPanel`, `isFloatingPanel = true`, `hidesOnDeactivate = false`
- `level = .popUpMenu`, `collectionBehavior = .canJoinAllSpaces`
- `setAccessibilitySubrole(.unknown)` so the panel does not show up in AltTab's own thumbnails
- An `NSVisualEffectView` with `.hudWindow` material and corner radius, as in
  `LeaderPanel.render` (`src/ui/LeaderPanel.swift:47-70`)

`TilesView.searchField` is a **static singleton bound to `TilesPanel.shared`**
(`src/ui/main-window/TilesView.swift:19-29`). It is not reusable. Create a plain `NSSearchField`
inside the new panel and observe `NSControl.textDidChangeNotification`, the same way
`TilesView.configureSearchField` does at `TilesView.swift:145-162`.

Key handling stays in the responder chain. The global CGEvent tap only absorbs keys while
`App.appIsBeingUsed` is true — see `KeyboardEventsTestable.shouldAbsorbSearchEditingKeyDown`
at `KeyboardEventsTestable.swift:225-230`. The palette is a separate panel and is not the
switcher, so a normal `keyDown` override plus the field's delegate is enough. **Verify this on
the running app.** If the tap does interfere, mirror the `shouldAbsorbSearchEditingKeyDown`
gate instead of widening the tap.

Keys: arrows move the selection, `Return` inserts, `Escape` closes, `Tab` is swallowed.

A known trap, recorded in `LeaderPanel.swift:62-64`: set the window size **before** assigning
`contentView`. Assigning first fits the view to a 0×0 window and the panel shows with no size.

### Insert path

Refactor, do not duplicate. `SystemUtilities.pasteAsPlainText` (`SystemUtilities.swift:20-38`)
already does snapshot, set, 0.05 s delay, `Cmd-V`, then restore after 0.5 s if `changeCount`
is unchanged. Extract that body into:

```
static func pasteText(_ text: String)
```

and let `pasteAsPlainText` call it. `postCommandV()` is `private static` at
`SystemUtilities.swift:51-58` and must become internal, or stay private and be reached only
through `pasteText`. Prefer the latter: keep the CGEvent detail private.

The 0.05 s delay exists so the menubar menu closes before the key event is posted. The palette
panel must likewise be ordered out before the paste, or the event goes to the panel.

Focus check, for the copy-only fallback:

```
AXUIElementCreateSystemWide() → kAXFocusedUIElementAttribute → kAXRoleAttribute
```

Treat `AXTextField`, `AXTextArea` and `AXComboBox` as insertable. Anything else, or an error,
means copy only. There is **no existing focused-element helper** in this repo; the closest
wrapper is `AXUIElement.attributes(_:)` at `src/api-wrappers/AXUIElement.swift:65`. Put the new
helper next to the palette code, not into the AX wrapper, until a second caller appears.

On the copy-only path call `TransientNotice.show(_:)`
(`src/ui/generic-components/TransientNotice.swift:12-20`). Its whole API is that one call.

### Persistence

Recents only in the first step. Favourites can wait for a second pass.

Follow the Auto-Quit list precedent, which stores a JSON array in a string:

- default `"[]"` in `Preferences.defaultValues` — see `Preferences.swift:124-125`
- accessor `static var characterPaletteRecents: String { CachedUserDefaults.string("characterPaletteRecents") }`
  — see `Preferences.swift:202-203`
- encode and decode with the pattern of `AutoQuitPolicy.decodeList` / `.encodeList`
  (`SystemActionTestable.swift:138-146`)

`Preferences.set` JSON-encodes only for the hardcoded key `"exceptions"`
(`Preferences.swift:367-373`). Encode in the caller.

`PreferencesMigrations.swift` needs **no** entry. Migrations exist only to retire old keys.

Cap the recents list at 30 entries. Store the character text, not an index, so a catalog
reorder does not corrupt the list.

## Build integration

Every new Swift file must be added to the `alt-tab-macos` target's `PBXSourcesBuildPhase` in
`alt-tab-macos.xcodeproj/project.pbxproj`. `CharacterCatalogTestable.swift` must also be added
to the `unit-tests` target's phase.

Check for pbxproj id collisions after any rebase. That has bitten this repo before.

`Podfile` and `build.sh` need no change.

## Verification

1. `./build.sh --test` — a clean run, from the repo root. CI uses Xcode 16.4.
2. New tests in `unit-tests/CharacterPaletteTests.swift`:
   - a query matches by name, by alias and by acronym;
   - a recent entry ranks above an equally scoring non-recent one;
   - `decodeList` on malformed input returns an empty list, not a crash;
   - the recents list stays capped at 30 and keeps most-recent-first order;
   - every catalog entry has a unique `text`, mirroring the uniqueness test at
     `unit-tests/SystemActionTests.swift:9-13`.
3. Manual run on this Mac, through the `install-local-build` skill:
   - open the palette from the menubar menu; it takes key focus and the caret is in the field;
   - type `arrow`, press `Return` in TextEdit; the character appears and the previous clipboard
     comes back after about half a second;
   - repeat with Finder in front and no text field; the notice appears and nothing is pasted;
   - bind the action to a shortcut in Settings and to a Leader slot; both open the palette;
   - confirm the palette does not appear among AltTab's own thumbnails.

## Open points for whoever implements this

- The exact catalog content is not fixed. Start from the Mojito groups: arrows, box drawing,
  maths, status, currency, Greek, punctuation, Mac keys.
- Mojito's text conversion (`->` becomes `→`) is attractive but needs the inline trigger and
  therefore *Input Monitoring*. Leave it out.
- Whether the panel should sit near the caret or in the middle of the screen is untested.
  `LeaderPanel.positionOnScreenUnderCursor` (`LeaderPanel.swift:107`) gives the middle-of-screen
  variant for free. Start there.

Documentation check: on implementation, add the action to `README.md` and `backlog.md`, and
note the new `Preferences` key.
