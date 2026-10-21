# Decisions

Deviations from the task brief, and deliberate choices made during
implementation. Each entry records the reason, impact and how it was verified.

---

## D-001 — `UTType.markdown` is macOS 27+, replaced with `.plainText`/`.text`

**Context.** The brief names `UniformTypeIdentifiers` for PDF/TXT/Markdown
recognition. In the installed SDK, `UTType.markdown` is annotated
`@available(macOS 27.0, *)`.

**Decision.** Do not raise the deployment target. Markdown files are recognised
by extension (`md`, `markdown`) and by conformance to `.plainText`/`.text`.
File panels request `[.pdf, .plainText, .text]`.

**Impact.** Markdown `.md` files are accepted and read as UTF-8 text. No
Markdown-specific UTI features are used.

**Verification.** `EvidenceDeskTests/FileValidationTests.supportsPdfTxtMd`
asserts `.md` and `.markdown` are supported; `rejectsUnsupportedType` asserts
`.exe` is rejected. Build succeeds with `-target arm64-apple-macos15.0`.

---

## D-002 — Debounced case text editing saves through `PersistenceService`

**Context.** The brief allows debounce for continuous text editing but requires
that "Saved" appear only after a successful write.

**Decision.** `CaseOverviewView` debounces 800 ms, then calls
`PersistenceService.updateCase` on the main actor. The indicator only moves to
`.saved` after `ModelContext.save()` returns without throwing; failures become
`.failed(message)` and leave the edited text in place.

**Impact.** No background contexts are used for writes, so Swift 6 isolation is
respected and no interleaved save can silently drop input. `autosaveEnabled` is
`false` everywhere, so every mutation is explicit.

**Verification.** `PersistenceTests.updateCaseRefreshesUpdatedAt`,
`PersistenceRestartTests.caseEvidenceFindingAndPDFPageSurviveRestart`.

---

## D-003 — Source deletion never cascades silently

**Context.** The brief forbids losing evidence without a prompt. SwiftData's
`deleteRule` cannot express "keep the evidence but detach it" while showing a
confirmation.

**Decision.** `PersistenceService.deleteSource(_:keepEvidence:)` first detaches
(or deletes) evidence, then removes the record. The UI shows a
`confirmationDialog` whose options depend on `DeletionGuard.impact(of:)`:
"delete source and keep evidence", "delete source and its evidence", "cancel".
Evidence itself cascades its `FindingEvidenceLink` rows so no dangling links
survive.

**Impact.** Deleting a source with linked findings cannot leave a half-deleted
graph.

**Verification.** `PersistenceTests.deleteSourceKeepingEvidenceDetaches`,
`deleteEvidenceRemovesItsLinks`, `deletionGuardReportsImpact`.

---

## D-004 — Case library selects the most recent case on launch

**Context.** The brief asks for a useful first-run state and for the workspace
to be immediately usable. A permanently empty detail pane after relaunch is
hostile.

**Decision.** `MainWindowView.onAppear` selects the most recently updated
non-archived case when nothing is selected. The detail pane still has its own
empty state for the genuinely empty library.

**Impact.** Restart lands the user in their current work. Pure empty-state
behaviour is preserved when no cases exist.

**Verification.** `P1` screenshots show the empty state; the seeded screenshots
show the workspace after auto-selection.

---

## D-005 — QA-only launch flags for screenshots and fixtures

**Context.** Visual acceptance requires screenshots of a real running app. The
implementation machine could not grant screen-recording/accessibility
permission to CLI tooling, so `screencapture` and XCUITest automation mode are
unavailable.

**Decision.** Add explicitly gated launch flags, inert without them:

- `--test-storage <dir>` — isolated Application Support root (used by tests and
  all QA runs; never touches real user data).
- `--seed-demo` — writes a synthetic case with a generated PDF and text
  attachment into that isolated storage.
- `--screenshot <path>` — renders the live window's content view to PNG, then
  exits.
- `--appearance light|dark`, `--window-size W,H`, `--ed-section <name>`,
  `--ed-select <short code>` — set state for that render.
- `--ed-trace` — append startup milestones to `/tmp/ed-trace.txt`.

**Impact.** Product behaviour is unchanged without the flags. Screenshots are
real renders of the running app (not mockups), with a known caveat: PDFKit
canvas content and `NSTextView`-backed areas are not captured by
`cacheDisplay`, so the PDF page is additionally rendered through PDFKit to a
sidecar PNG (`*.pdfpage.png`), and the report preview was moved to a
`TextEditor` which *is* captured.

**Verification.** Screenshots in `artifacts/Screenshots/P1/` were OCR-checked
(see `docs/VISUAL-QA-CHECKLIST.md`), including `final-report-light.png`
(report body) and `final-pdf-reader-light.png.pdfpage.png` (PDF page with the
14-day clause). XCTest UI screenshots are extracted to
`artifacts/Screenshots/UITests/` as additional evidence.

---

## D-006 — UI tests use an app-resolved isolated storage name

**Context.** UI automation initially failed with
`Timed out while enabling automation mode`, and in a later attempt it ran. Two
real problems were found and fixed rather than worked around:

1. **Sandbox path mismatch.** UI tests originally created a storage folder in
   the *test runner's* temp directory and passed it via `--test-storage`.
   The sandboxed app cannot write there; the app correctly showed its
   `FatalErrorView`. Tests now pass `--test-storage-name <name>` and the app
   resolves that name inside **its own** container temp directory, so the store
   is always writable and still isolated from the real library.
2. **Flaky automation authorisation.** The first `xcodebuild test` run of the
   UI target timed out while enabling automation mode; subsequent runs were
   authorised and executed. This is an environment property (TCC), not a test
   defect. CI exposes UI tests behind the `RUN_UI_TESTS` repository variable
   instead of silently skipping them.

**Impact.** UI tests are genuine and pass locally (11 tests). They never touch
the real user library, and they assert against stable accessibility
identifiers rather than screen coordinates.

**Verification.** `artifacts/P0/ui-tests.log` / `artifacts/P6/ui-tests.txt`
record `Executed 11 tests, with 0 failures`. Screenshots extracted from the
`.xcresult` are in `artifacts/Screenshots/UITests/`.

---

## D-006b — Accessibility: explicit labels instead of `combine`

**Context.** UI automation dumps showed `staticTexts` with **empty labels**.
Cause: `.accessibilityElement(children: .combine)` on rows and
`.accessibilityElement(children: .contain)` on section headers caused SwiftUI to
expose label-less elements.

**Decision.** Rows use `.accessibilityElement(children: .ignore)` plus an
explicit, meaningful `.accessibilityLabel(...)` and a stable
`.accessibilityIdentifier(...)`. `SectionHeader` applies no accessibility
modifiers (plain `Text` is already exposed) and marks itself as a heading.
Empty states, save-state indicators and error banners expose identifiers
(`emptyState.title`, `saveState.saved`, `errorBanner.message`).

**Impact.** VoiceOver now reads real content ("S-001, City announces transit
tender for Line 7, Web Link, example.gov"), and UI tests can assert on stable
IDs instead of fragile visual structure.

**Verification.** UI test dumps (`artifacts/P1`) and the passing
`EvidenceDeskUITests` suite; `testSeededCaseRendersAllSections` asserts on
`sourceRow.*`, `evidenceRow.*`, `findingRow.*`, `timelineRow.*` identifiers.

---

## D-007 — Ad-hoc signing, hardened runtime off for Debug

**Context.** With `ENABLE_HARDENED_RUNTIME = YES` and ad-hoc signing, the UI
test bundle failed to load (`mapping process and mapped file have different
Team IDs`).

**Decision.** Debug builds use `CODE_SIGN_STYLE = Manual`,
`CODE_SIGN_IDENTITY = "-"`, `ENABLE_HARDENED_RUNTIME = NO`. Release/distribution
configuration must use Developer ID and hardened runtime (documented in
`docs/RELEASE.md`, not executed — no credentials were used).

**Impact.** Debug app runs locally and under XCTest. Nothing about this
configuration is described as a distributable build.

**Verification.** `scripts/build.sh` succeeds; `docs/RELEASE.md` records the
difference; no signing secrets are stored in the repo.

---

## D-008 — Report preview is a read-only `TextEditor`

**Context.** The Markdown preview must render long documents without blocking
and must be visually verifiable.

**Decision.** Preview uses `TextEditor(text: .constant(markdown))` with a
monospaced font. It is a *preview of the exported Markdown source*, not a
rendered-Markdown editor, which matches the brief ("导出 Markdown 报告" and
"preview").

**Impact.** Large reports page efficiently via `NSTextView`. Users see exactly
what will be written to `report.md`.

**Verification.** `ExportTests.reportContainsCoreSections` exercises generation;
`final-report-light.png` shows the rendered preview.

---

## D-009 — Timeline ordering extracted into a shared helper

**Context.** The timeline view and the exporter must agree on ordering,
especially for undated events and same-day events.

**Decision.** `TimelineSorting.partition` / `sortSameDayStably` are used by the
view; the exporter sorts dated events and appends an explicit
"Date undetermined" section. Undated events are never given a fabricated date.

**Impact.** One ordering rule, testable without UI.

**Verification.** `PersistenceTests.timelineEventsSortByDateWithUndatedSecluded`.

---

## D-010 — No CloudKit, no network entitlement

**Context.** The brief requires `http`/`https` link sources but no fetching.

**Decision.** The app sandbox entitlements request only user-selected file
read/write. Opening a link uses `NSWorkspace`/`openURL`, which hands the URL to
the user's browser and needs no network entitlement. No URLSession code exists.

**Impact.** The app cannot fetch page content even accidentally, matching the
"link source, not a snapshot" requirement.

**Verification.** `grep -R "URLSession" EvidenceDesk/` returns nothing;
`EvidenceDesk.entitlements` contains no network key.
