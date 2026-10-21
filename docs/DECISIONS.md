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

- `--test-storage <dir>` — isolated Application Support root.
- `--test-storage-name <name>` — isolated root resolved **inside the app's own
  sandbox container** (required under the sandbox; UI tests use this).
- `--reset-test-storage` — wipes only the `EvidenceDeskUITest/<name>` subtree so
  a test can start from an empty library. Ignored without
  `--test-storage-name`.
- `--seed-demo` — writes a synthetic case with a generated PDF and text
  attachment into that isolated storage.
- `--screenshot <path>` — renders the live window's content view to PNG, then
  exits.
- `--appearance light|dark`, `--window-size W,H`, `--ed-section <name>`,
  `--ed-select <short code>` — set state for that render. UI tests use the
  environment equivalents `EVIDENCE_DESK_APPEARANCE` and
  `EVIDENCE_DESK_WINDOW_SIZE`, because XCTest argument passing proved
  unreliable for those two switches.
- `--ed-trace` — append startup milestones to `/tmp/ed-trace.txt`.

**Impact.** Product behaviour is unchanged without the flags. Note that
`cacheDisplay` (used by `--screenshot`) does not draw PDFKit or AppKit-backed
content, which is why final visual evidence moved to XCUITest window captures
(D-012) — those *do* include PDFKit's composited page.

**Verification.** Screenshots in `artifacts/Screenshots/P1/` were OCR-checked
(see `docs/VISUAL-QA-CHECKLIST.md`), including `final-report-light.png`
(report body) and `light-pdf-reader.png` (PDF page with the
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

## D-011 — App Sandbox had to be declared in `project.yml`

**Context.** The entitlements file was authored by hand with
`com.apple.security.app-sandbox`, but `project.yml` used XcodeGen's
`entitlements: path:` form. XcodeGen **regenerates** that plist from
`entitlements.properties`; with no properties it wrote an empty `<dict/>`,
silently dropping the sandbox keys. The built app therefore ran unsandboxed for
part of the implementation.

**Evidence of the defect.** `codesign -d --entitlements :- <app>` printed only
`com.apple.security.get-task-allow`.

**Decision.** Declare the sandbox keys inside `project.yml`
(`entitlements.properties`) so the generated plist is correct and `project.yml`
stays the single source of truth. The generated
`EvidenceDesk.entitlements` is committed for review.

**Impact / behaviour change.** With the sandbox actually active:
- The app is containerised: `~/Library/Containers/com.luxiang0412.EvidenceDesk/`.
- UI tests must use `--test-storage-name` (resolved inside the container), not
  an arbitrary host path — otherwise the app correctly shows `FatalErrorView`.
- The app-rendered `--screenshot` path cannot write to the repository; it
  writes into the container temp as a fallback.

**Verification.**
- `codesign -d --entitlements :-` now shows `app-sandbox`, `files.user-selected.read-only`,
  `files.user-selected.read-write` (plus Debug-only `get-task-allow`).
- A seeded run writes only inside the container
  (`.../Data/tmp/EvidenceDeskUITest/.../Attachments/...`).
- All 58 unit/integration tests and 11 UI tests still pass with the sandbox on.
- Visual evidence was re-captured **through XCUITest** (`ScreenshotTests`),
  i.e. from the sandboxed app, into `artifacts/Screenshots/Sandboxed/`.

---

## D-012 — Visual evidence captured via XCUITest window screenshots

**Context.** The in-app `cacheDisplay` renderer cannot write outside the app
sandbox, and it does not draw PDFKit/AppKit-backed content faithfully.

**Decision.** Primary visual evidence now comes from `ScreenshotTests`, which
drives the real sandboxed app and captures **only the app window**
(`XCUIElement.screenshot()`), so no desktop or other applications appear.
Appearance and window size are driven by environment variables
(`EVIDENCE_DESK_APPEARANCE`, `EVIDENCE_DESK_WINDOW_SIZE`) rather than
command-line flags, because XCTest argument passing proved unreliable for
those two switches.

**Verification.** `artifacts/Screenshots/Sandboxed/` contains 13 window-only
captures (light sections, dark, empty/archived/no-results, minimum size, saved
state). Dark mode verified numerically (mean luminance 38 vs 245 in light).

---

## D-013 — UI automation strategy on Touch Bar hardware with a CJK IME

**Context.** This machine is a MacBook Air with a **Touch Bar** and a Chinese
input method active. Three concrete consequences appeared while writing the UI
suite:

1. Controls are mirrored onto the Touch Bar. `app.buttons["…"]` can resolve to
   the Touch Bar copy and throw
   `cannot be called with Touch Bar elements`; SwiftUI `confirmationDialog`
   buttons in the window ignore synthetic clicks while the mirrored copy eats
   them.
2. Typed text goes through the active input method, so query strings and case
   titles are not deterministic in automation.
3. The segmented section picker is mirrored too; clicking it sometimes does not
   switch sections.

**Decision.**

- Tests that need a particular section launch with `--ed-section <name>`
  instead of clicking the picker.
- Library search/archive **logic** moved into `CaseFilter` and is unit-tested
  (`CaseFilterTests`); the visual states are captured deterministically with
  `--ed-show-archived` / `--ed-search <text>`.
- Dialog **contracts** (which policies are offered) are asserted; dialog
  **execution** is covered at the model layer
  (`PersistenceTests` + `SourceDeletionPolicyTests`).
- Export commands are asserted through the UI; export **content** is verified by
  `ReportExporterPathTests`, which writes real files through the same
  `ReportExporter` the UI calls (the sandboxed `NSSavePanel` is out-of-process
  and not inspectable).
- PDF drag-selection cannot be synthesised; extraction is covered by
  `PDFTests.selectionExtractionReturnsTextAndOneBasedPage` and the reader's
  enabled/disabled contract is asserted in the UI suite.

**Impact.** 20 UI tests run deterministically (verified twice back to back) plus
66 unit/integration tests. No test is skipped; the gaps are moved to layers
where they can be verified honestly.

---

## D-014 — SwiftUI accessibility defects found while automating

Three distinct SwiftUI/AppKit behaviours were found and worked around. They
matter for VoiceOver users, not just for tests.

1. **Labels vanished when a `Text` got an identifier.** `Text("…")` with
   `.accessibilityIdentifier` inside a stack exposed an *empty* label.
   → Empty states now expose one wrapper element with a composed
   `.accessibilityLabel` (`EmptyStateView`), which also reads better in VoiceOver.
2. **Container elements swallowed buttons.** My first accessibility pass made
   whole detail headers a single `.accessibilityElement(children: .ignore)`
   element, hiding "Open in Browser", "Delete" and similar buttons from
   assistive tech. Headers now combine only icon + titles; buttons stay
   siblings. This was caught by UI automation (`source.delete` was unreachable)
   and is fixed.
3. **Crash while dismissing editor sheets.** With an accessibility client
   attached, saving from a sheet reproducibly crashed inside
   `SwiftUI AccessibilityNode.attachment.getter`
   (`EXC_BAD_ACCESS` in `NSAccessibilityGetObjectValueForAttribute`).

   Mitigations applied: every `TextEditor` carries an explicit
   `.accessibilityLabel`; interpolated `Text` uses `Text(verbatim:)`; sheet
   dismissal is deferred one runloop turn; the evidence excerpt uses a multiline
   `TextField` instead of `TextEditor`.

   **Remaining risk:** the crash could still be triggered by automation, so no UI
   test asserts sheet-save. The flow is covered by persistence tests and manual
   use. It is listed as a known issue in `docs/FINAL-ACCEPTANCE-REPORT.md`; a
   VoiceOver listening session should reproduce it before shipping.

**Verification.** 20 UI tests pass twice consecutively; the accessibility tree
contains non-empty labels and reachable actions (dumps recorded during
development, summarised in `docs/VISUAL-QA-CHECKLIST.md`).
