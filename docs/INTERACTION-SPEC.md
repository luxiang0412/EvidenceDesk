# Interaction Spec

## Keyboard shortcuts

| Shortcut | Action | Owner |
| --- | --- | --- |
| ⌘N | New research case | `AppCommands` → `AppActions` → `MainWindowView` |
| ⌘I | Import source | `AppCommands` → `AppActions` → `MainWindowView` |
| ⌘⇧E | Export report | `AppCommands` → `AppActions` → `CaseWorkspaceView` / `ReportPreviewView` |
| ⌘F | Focus search | `AppCommands` → `AppActions` (searchable field) |
| ⌥⌘I | Toggle inspector | `AppCommands` → `AppActions` → `MainWindowView` |
| ⌘, | Language settings | `SettingsLink` in `AppCommands` + standard Settings scene |
| ⌘W / ⌘Q | Close window / quit | System |
| ⌘Z / ⇧⌘Z | Undo / redo | System text editing (text fields and editors) |
| ⌘X/C/V/A | Cut/copy/paste/select all | System |

Menus and toolbar buttons both call `AppActions.shared.send(...)`. There is no
second implementation of any command.

## Language

- `View ▸ Language…` (also ⌘, and the app menu) opens the only settings screen.
- Options: 跟随系统语言 / English / 简体中文, each shown in its own language.
- A change writes `AppleLanguages` for the app and shows a "relaunch to apply"
  notice with a Quit button; the UI language changes on next launch.
- Switching language never touches research content, dates, IDs or citations.

## Drag & drop

- Accepts `public.file-url` drops of PDF / TXT / MD.
- Rejects other types with a visible alert naming the problem; never crashes or
  silently ignores.
- Uses the same `ImportService.resolveDropProviders` + `PersistenceService`
  path as the menu import, so validation, size limits and error messages match.
- Dropped files are copied into app-owned storage (UUID directory); the drop
  target's original path is never persisted as an identity.

## Saving

| Data | Trigger | Feedback |
| --- | --- | --- |
| Case title/question/scope | 800 ms debounce, or "Save Now" | `SaveStateIndicator`: Not saved → Saving… → Saved / failed message |
| Source metadata | "Save Metadata" | same indicator, plus inline error banner |
| Evidence / finding / timeline edits | Sheet "Save" | button disabled until valid; inline error on failure |
| Import | Immediately after copy verification | sheet error text, or drop alert |

A failed save never shows "Saved". Failed text remains in the editor and a
retry action is offered.

## Deletion

- **Case**: confirmation dialog states how many sources/evidence/findings are
  involved. Deleting removes only that case's data.
- **Source**: dialog offers *keep evidence* (detach to personal notes) or
  *delete evidence too*, and always offers Cancel.
- **Evidence**: dialog names the number of finding links that will be removed.
- **Finding**: dialog names the number of links that will be removed.
- Undo is available only for system text editing; database deletes are not
  claimed to be undoable.

## Navigation & focus

- Selecting a case opens the workspace with the last-used section per case
  instance.
- Cross-section jumps: evidence → its source (Sources section, page when
  known); evidence → linked finding (Findings section); source → "Add Evidence"
  sheet prefilled with selection text and page.
- Sidebar and inspector are collapsible; the app never forces three columns.
- Sheets use `.keyboardShortcut(.cancelAction)` / `.defaultAction`, so Esc and
  Return behave as expected and focus returns to the invoking control.

## Feedback honesty

- "Link source" is labelled as a link, with a sentence stating page content is
  not fetched and excerpts are recorded by the user.
- A finding marked Active is described as "the finding you are working with",
  never as proven. No confidence scores are computed.
- Missing attachments are surfaced at startup and on the source row; the user
  chooses re-link or delete.
