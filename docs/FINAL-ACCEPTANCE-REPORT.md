# Final Acceptance Report — Evidence Desk 1.0.0

Status: **PASS** for the delivered scope, with the limitations listed in §9.
Date of record: 2026-10-21. Every statement below corresponds to a command or
artifact produced during this implementation; nothing is claimed that was not
executed.

---

## 1. Product completion

| Definition of Done item | Status | Evidence |
| --- | --- | --- |
| Create, edit, search, archive cases | PASS | `CaseOverviewView`, `LibrarySidebarView`, `PersistenceTests`, `UITests/testCreateCaseEndToEnd` |
| Import URL / PDF / TXT / MD sources | PASS | `ImportService`, `PersistenceService.importFileSource`, `FileValidationTests`, `UITests/testSeededCaseRendersAllSections` |
| PDF reading, selection, evidence creation | PASS | `PDFReaderView` (PDFKit), `PDFSelectionService`, `PDFTests`, `final-pdf-reader-light.png.pdfpage.png` |
| Findings link supports / contradicts / background evidence | PASS | `FindingEvidenceLink`, `FindingDetailView`, `PersistenceTests.findingSupportsMultipleLinkedEvidence` |
| Timeline | PASS | `TimelineSectionView`, `TimelineSorting`, `PersistenceTests.timelineEventsSortByDateWithUndatedSecluded` |
| Markdown report + portable case bundle export | PASS | `MarkdownReportExporter`, `CaseArchiveExporter`, `ExportTests` (incl. manifest schemaVersion + relative paths) |
| Data intact after quit/relaunch | PASS | `PersistenceRestartTests`, `UITests/testRestartPreservesData` |
| Attachment/DB consistency check | PASS | `RecoveryService`, `RecoveryTests` |
| Save failures reported, never faked | PASS | `SaveStateIndicator` + `PersistenceService.save()` throwing; `CaseOverviewView` only shows Saved after success |
| Deletions never silently lose linked research | PASS | `DeletionGuard` + confirmation dialogs with keep/delete options; `PersistenceTests.deleteSourceKeepingEvidenceDetaches` |
| Export paths independent of sandbox absolutes | PASS | `ExportTests.urlSourcesBecomeClickableLinksAndAttachmentsUseRelativePaths`, `PerformanceTests.reportDoesNotLeakAbsolutePathsAtScale` |
| Native window / toolbar / menu / sidebar | PASS | Screenshots; `UITests/testMenuCommandsExistAndInspectorToggles` |
| Light, dark, window-size visual acceptance | PASS | `P1` screenshots (light, dark, 980×640) |
| Empty / error / loading states | PASS | `UITests/testEmptyStateOffersFirstAction`, `testSearchNoResultState`, `testArchivedEmptyStateIsNotDeletion`; `ErrorBannerView`; `StartupView` progress state |
| Keyboard navigation and shortcuts | PASS | `AppCommands`; `UITests/testMenuCommandsExistAndInspectorToggles`, `testEditMenuIsStandard` |
| VoiceOver labels for controls | PASS (with one manual caveat, §9) | Explicit labels/identifiers on rows, statuses, save state, errors; verified via accessibility-tree dumps |
| Real running screenshots for core flows | PASS | `artifacts/Screenshots/P1/`, `artifacts/Screenshots/UITests/` |

## 2. Toolchain and test machine

| Item | Actual value |
| --- | --- |
| Machine | Apple M1, 16 GB RAM |
| OS | macOS 27.2 (26B5091g) |
| Xcode | 27.1 (27A9275) |
| Swift | 6.4 (swiftlang-6.4.0.34.1), Swift 6 language mode, strict concurrency `complete` |
| macOS SDK | macOS 27.0 (`macosx27.0`) |
| Deployment target | macOS 15.0 |
| XcodeGen | 2.46.0 |
| Git | 2.54.0 |

Recorded at `artifacts/P0/environment.txt`; summary in `docs/ENVIRONMENT.md`.

## 3. Commands and results

| Command | Exit | Result |
| --- | --- | --- |
| `./scripts/env.sh` | 0 | Environment captured |
| `./scripts/generate-project.sh` | 0 | `EvidenceDesk.xcodeproj` generated |
| `./scripts/build.sh` | 0 | `** BUILD SUCCEEDED **` (Debug, macOS 15.0 target) |
| `./scripts/test.sh` | 0 | `Test run with 58 tests in 13 suites passed` |
| `./scripts/ui-test.sh` | 0 | `Executed 11 tests, with 0 failures` |
| `./scripts/verify-all.sh` | 0 | environment PASS → generate PASS → build PASS → tests PASS → ui-tests PASS |
| `./scripts/perf-baseline.sh` | 0 | Scale tests passed; baseline recorded |
| `git clone` → `./scripts/build.sh` → `./scripts/test.sh` in `/tmp/ed-clean` | 0 | Clean checkout builds and the full test suite passes |

Logs: `artifacts/P0/*.log`, `artifacts/verify-*/`, `artifacts/TestResults/`.

## 4. Test counts

| Suite | Count | Result |
| --- | --- | --- |
| Swift Testing (unit + integration) | 58 tests / 13 suites | 58 passed, 0 failed, 0 skipped |
| XCTest UI automation | 11 tests / 3 classes | 11 passed, 0 failed |

Note: `SmokeTests` (3 of the 58) overlaps `URLValidationTests` and
`ShortCodeTests` from the P0 bootstrap. They were retained deliberately rather
than deleted once the fuller suites landed; they still pass.

Breakdown by area:

- URL validation (4), file validation (4), short codes (3)
- Persistence model/relations/deletion (19)
- Restart persistence (2), recovery (3)
- Attachments + read-only failure (5), PDF (3)
- Export/report (8), export failure paths incl. unopenable store (2)
- Performance/scale (3)

## 5. Visual acceptance

All screenshots are real renders of the running app or XCTest attachments.

| Item | Path |
| --- | --- |
| Empty library | `artifacts/Screenshots/P1/empty-library.png` |
| Overview (light) | `artifacts/Screenshots/P1/final-overview-light.png` |
| Sources | `artifacts/Screenshots/P1/final-sources-light.png` |
| PDF reader (+ PDFKit page) | `artifacts/Screenshots/P1/final-pdf-reader-light.png`, `...png.pdfpage.png` |
| Evidence | `artifacts/Screenshots/P1/final-evidence-light.png` |
| Findings | `artifacts/Screenshots/P1/final-findings-light.png` |
| Timeline | `artifacts/Screenshots/P1/final-timeline-light.png` |
| Report preview | `artifacts/Screenshots/P1/final-report-light.png` |
| Dark appearance | `artifacts/Screenshots/P1/final-dark-overview.png` |
| Minimum window 980×640 | `artifacts/Screenshots/P1/final-min-overview.png` |
| UI-test captures | `artifacts/Screenshots/UITests/ui-*.png` |

Verification method: OCR of each render plus pixel analysis (see
`docs/VISUAL-QA-CHECKLIST.md`). Example OCR from the report render:
`# Local Transit Tender - Sources Review`, `## Research Question`,
`### F-001 … (Active)`, `**Supporting evidence:** - E-001`,
`**Contradicting evidence:** - E-002`, `> Firms must submit bids within 14 days…`.

## 6. Performance

See `docs/PERFORMANCE-BASELINE.md` and `artifacts/P6/performance-baseline.txt`.

| Measurement | Result |
| --- | --- |
| 500 sources created (in-memory, explicit saves) | 3.45 s |
| 200 evidence + 200 links + report build | 0.79 s |
| Report generation (200 evidence) | 0.004 s |
| 100 MB file | accepted at the limit; 101 MB rejected before copy |
| RSS with seeded case | 133 MB at +3 s, 133 MB at +15 s, 144 MB at +18 s (plateau) |
| RSS across 3 relauches | 136 MB / 136 MB / 136 MB |

No unbounded memory growth observed. No attachment bodies read at case-open
time; text preview reads at most 200 KB.

## 7. Sandbox, recovery, export

- **Sandbox**: enabled; entitlements are app-sandbox + user-selected read/write
  only. No network entitlement. Verified by inspecting
  `EvidenceDesk/EvidenceDesk.entitlements` and the built app.
- **File access**: all imports go through `NSOpenPanel` / drop then are copied
  into Application Support; exports go through `NSSavePanel` / `NSOpenPanel`.
- **Recovery**: startup check flags missing attachments (`source.attachmentIsMissing`)
  and lists orphan directories; it never deletes unconfirmed files.
  `RecoveryTests` covers both.
- **Export**: `report.md` + `manifest.json` (`schemaVersion: 1`, stable IDs,
  relative attachment paths) + `attachments/`; originals are copied, never
  moved; missing attachments abort with a clear error.

## 8. CI

`.github/workflows/ci.yml`:

- Pinned runner image `macos-27` and an explicit Xcode `27.1` version check that
  **fails** (not warns) on a mismatch.
- Pinned XcodeGen (warns if the resolved version differs).
- Generates the project, builds, runs unit/integration tests, uploads
  `.xcresult` + logs; UI tests are opt-in via `RUN_UI_TESTS` because hosted
  runners often cannot authorise automation.
- No signing credentials, no publishing step.

CI status: **not run** in this environment (no remote configured, and the brief
forbids publishing). The workflow is structurally validated by running the same
commands locally, which all pass.

## 9. Known limitations and unresolved risks

1. **UI tests and TCC.** The very first UI automation attempt timed out
   enabling automation mode; later runs were authorised and passed 11/11. If a
   machine cannot authorise the runner, use `SKIP_UI_TESTS=1`. CI keeps UI
   tests opt-in for this reason.
2. **VoiceOver was validated structurally, not by listening.** Labels,
   identifiers and hints are present and non-empty (verified through the
   accessibility tree), but a human VoiceOver session was not performed.
3. **Instruments traces were not captured.** Blocked by the same automation
   gating; the performance evidence is process-RSS sampling plus scale tests.
   The command to run interactively is documented in
   `docs/PERFORMANCE-BASELINE.md`.
4. **PDFKit canvas is not captured by the app's window renderer.** A PDFKit
   page render is exported as a sidecar PNG; the on-screen reader itself is a
   real `PDFView`.
5. **Link sources are not archived.** Page content is never fetched, by design;
   link rot is a real risk and the UI says so.
6. **No undo for database deletions.** Only text editing uses system Undo, and
   the app does not claim otherwise.
7. **Not notarised, not published.** Debug builds are ad-hoc signed with
   hardened runtime disabled so the local test runner can load; this is not a
   distributable configuration. `docs/RELEASE.md` records the verified vs
   not-executed steps.
8. **Schema migrations untested beyond v1.** There is one schema version; the
   brief's migration-test requirement starts "when schema changes", and no
   change has been made.

## 10. Reproducing from a clean checkout

```bash
git clone <repo> && cd EvidenceDesk
brew install xcodegen          # 2.46.0
./scripts/generate-project.sh
./scripts/build.sh
./scripts/test.sh
./scripts/ui-test.sh           # or SKIP_UI_TESTS=1 ./scripts/verify-all.sh
./scripts/perf-baseline.sh
```

This exact sequence was executed in `/tmp/ed-clean` from a fresh clone: build
succeeded and the unit/integration suite passed.

## 11. Release readiness

| Item | Status |
| --- | --- |
| Local Debug build + sandbox | Verified |
| Unit + UI tests green | Verified |
| Clean-checkout build | Verified |
| README / LICENSE / CONTRIBUTING / CHANGELOG / privacy + data location | Complete |
| CI workflow | Written, not executed on a remote |
| Developer ID signing / notarisation / stapling | **Not executed** (no credentials) |
| App Store submission | **Not executed** (not authorised) |
| GitHub public release | **Not executed** (not authorised) |
