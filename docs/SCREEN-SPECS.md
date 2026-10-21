# Screen Specs

Every screen below implements: empty state, populated state, error state,
search-empty state (where search exists), narrow-window behaviour, dark
appearance, and keyboard/VoiceOver labels.

---

## 1. Library (sidebar + detail shell)

**Structure.** `NavigationSplitView`: library sidebar (240 pt) + detail.
Optional inspector (280 pt) toggled with ⌥⌘I, hidden by default.

**Empty (no cases).** "No Research Cases" / "Create a case to begin a research
project." with a *New Research Case* button. Detail pane shows "Select a
Research Case" with the same primary action.

**Populated.** Rows show short code (`C-001`), title, and research question
(one line). Selection drives the detail pane. Footer has *Archived* toggle and
*New Case*.

**Search.** `.searchable` over code, title and question. No-match state:
magnifier icon, "No Matching Cases", hint to try a different search.

**Archived mode.** Same list, filter switches to archived cases; archive ≠
delete, and restoring is one click.

**Narrow.** Sidebar collapses via the system split view; detail keeps its own
empty state.

---

## 2. Case Overview

**Sections.** Title field, code + created date, Research Question editor,
Research Scope editor, save indicator + Save Now, four stat cards
(Sources / Evidence / Findings / Timeline).

**Empty.** Fresh case shows empty question/scope editors with helper text
("What are you trying to resolve?"), not blank boxes with no guidance.

**Saving.** "Not saved" → "Saving…" → "Saved" only after a real write; failure
shows a red label plus an error banner with Retry.

**Error.** Banner: what failed, data still in the editor, retry offered.

---

## 3. Sources

**Layout.** Source list (260–340 pt) + detail.

**Empty.** "No Sources" / "Import a link, PDF, TXT or Markdown file."

**Detail variants.**

- *URL*: explicit "Link source" chip and a paragraph stating content is not
  fetched; the URL is selectable; *Open in Browser*; *Add Evidence from This
  Source*.
- *PDF*: embedded PDFKit reader with zoom −/+ / fit, page indicator
  ("Page n of m"), and *New Evidence from Selection* (disabled until text is
  selected). Locked and unreadable PDFs show dedicated messages.
- *Text/MD*: first ~200 KB preview with a note that the full original is
  preserved.

**Missing attachment.** Orange banner at the top of the detail and a warning
glyph on the row; *Re-link File…* opens the system panel; metadata deletion is
also available.

**Metadata form.** Title, publisher, published date (+ "no date known"),
notes, Save Metadata.

**Delete.** Dialog with evidence/link counts; keep-vs-delete evidence choice.

**Drop.** Dashed accent outline while targeting. Invalid types produce a named
alert after the drop.

**Search-empty.** "No Matching Sources" + "Try a different search."

---

## 4. Evidence

**List.** Short code, type name, source ref (`→ S-003`), 3-line excerpt.

**Detail.** Type icon + code + type label; excerpt block; type/page details;
source jump button; location note; user notes; linked findings with relation
tags; created/updated timestamps; Edit and Delete.

**Editor.** Excerpt (required, ≤ 50,000 chars, live counter), type picker,
source picker or explicit "Personal note / no source (unverified)" toggle,
location, page, notes. Saves only when text is non-empty.

**Empty.** "No Evidence Selected" with *New Evidence*, or list-level "No
Evidence" explaining excerpts need a source and location.

**Delete.** Dialog names affected finding links.

---

## 5. Findings

**List.** Code, title, body excerpt, status word.

**Detail.** Status icon + code; body or an explicit "no analysis yet" note;
uncertainty block; linked evidence grouped by **Supports / Contradicts /
Background** with relation icons; per-link menu to change relation or unlink;
Edit and Delete.

**Editor.** Title (required), body, status radio group with the explanatory
sentence that Active ≠ proven, uncertainty.

**Empty.** "No Finding Selected" explaining findings combine evidence;
list-level "No Findings".

**Link picker.** Relation segmented control, searchable list of *unlinked*
evidence only, Link button disabled until a row is chosen.

---

## 6. Timeline

**Dated events.** Vertical rail with dot per event, date column (90 pt),
title, detail, source/notes metadata, edit pencil.

**Undated events.** Separate "Date Undetermined" section listing events with
no fabricated date.

**Empty.** "No Timeline Events" explaining unknown dates stay separate, with
*New Event*.

**Editor.** Title (required), description, precision radio group
(exact / month-year / year / unknown), date picker hidden when unknown, optional
linked source, notes.

---

## 7. Report Preview

**Empty.** "Report Preview" explanation + *Generate Preview*.

**Populated.** Monospaced read-only preview of the exact Markdown that will be
exported, with a generated-at timestamp, *Regenerate*, *Export as Markdown…*
(system save panel, `.md`) and *Export Case Bundle…* (folder panel →
`manifest.json`, `report.md`, `attachments/`).

**Exporting.** "Exporting…" state; success shows the file/folder name; failure
shows an error banner explaining that original data is untouched.

---

## 8. Settings (language)

**Reachable from.** App menu / `View ▸ Language…` / ⌘, — the app now has a real
settings screen, which is the only reason the shortcut is bound.

**Contents.** Section title "Language", one-paragraph explanation that the
change applies after relaunch and that research data is never translated, a
radio group (`跟随系统语言` / `English` / `简体中文`, each in its own language),
a pending-change notice with a *Quit Evidence Desk* button, and a short privacy
note.

**States.** No pending change (notice hidden) / pending change (notice visible).

## 9. Language behaviour

Every screen is specified above in both `en` and `zh-Hans`; strings come from
`Localizable.xcstrings` and are never concatenated by hand. Layout is checked in
both languages at 980 × 640 (Chinese labels are shorter; English is the
constraint). Empty states, save feedback, dialogs, menu titles and the exported
Markdown headings are all translated; user-entered text, short codes and
citations are not.

## 10. Fatal startup error

Only when the data store cannot open: title explaining the store failed, the
underlying message, and Quit / Retry. Never a silent blank window.
