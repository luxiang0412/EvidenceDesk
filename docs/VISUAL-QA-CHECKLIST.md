# Visual QA Checklist

Raw evidence lives under `artifacts/Screenshots/` (gitignored). All screenshots
are real captures of the running app — no mockups.

## Evidence sources

1. **Primary — `artifacts/Screenshots/Sandboxed/` (mirrored in `artifacts/P1/`)**
   Window-only screenshots attached by `EvidenceDeskUITests/ScreenshotTests`
   while the **sandboxed** app is running. Because only
   `XCUIElement.screenshot()` of the app window is used, no desktop, terminal or
   other application appears in the evidence.

   | File | Screen |
   | --- | --- |
   | `light-overview.png` | Case overview, populated |
   | `light-sources.png` | Sources list + detail |
   | `light-evidence.png` | Evidence list + detail |
   | `light-findings.png` | Findings |
   | `light-timeline.png` | Timeline (incl. undated section) |
   | `light-pdf-reader.png` | PDF reader with PDFKit page content |
   | `light-report.png` | Report preview (Markdown source) |
   | `dark-01-overview.png` | Overview, dark appearance |
   | `dark-02-findings.png` | Findings, dark appearance |
   | `empty-01-library.png` | Empty library |
   | `empty-02-archived.png` | Archived empty state |
   | `empty-03-no-search-results.png` | Search with no results |
   | `min-size-01-overview.png` | 980 × 640 minimum window |
   | `state-01-saved.png` | Save indicator after a real write |

2. **`artifacts/Screenshots/UITests/`** — functional UI-suite screenshots
   (`ui-*.png`), also window-only.

3. **PDFKit page render** — window snapshots cannot draw PDFKit canvases, so a
   page was exported through PDFKit during an earlier capture pass. The reader
   itself is asserted structurally by
   `EvidenceDeskUITests/testPDFReaderOffersSelectionActionOnlyWhenTextIsSelected`.

## Requirement → evidence

| Requirement | Evidence | How verified |
| --- | --- | --- |
| Main window, initial empty state | `Sandboxed/empty-01-library.png` | OCR: "No Research Cases", "Create a case to begin a research project.", "New Research Case" |
| Case overview, populated | `Sandboxed/light-overview.png` | OCR: case title, research question, scope, "Saved", stats 3 Sources / 4 Evidence / 1 Finding / 3 Timeline |
| Source list (URL / text / PDF) | `Sandboxed/light-sources.png` | OCR: `S-001 City announces transit tender…`, `S-002 … tender-notes.md`, `S-003 … line7-spec.pdf` |
| PDF reading + page fidelity | PDFKit page render (pre-sandbox capture, kept because window snapshots cannot draw PDFKit canvases); reader chrome asserted by `testPDFReaderOffersSelectionActionOnlyWhenTextIsSelected` | Window capture shows list + reader chrome; the page itself is rendered through PDFKit (OCR: "14 days", "30-day window", "30-day") |
| Evidence detail | `Sandboxed/light-evidence.png` | OCR: `E-001 Fact`, source ref, excerpt text |
| Findings with typed evidence | `Sandboxed/light-findings.png` | OCR: `F-001`, `Active`, body text |
| Timeline incl. undated | `Sandboxed/light-timeline.png` | OCR: dates + "Date unknown" |
| Report preview | `Sandboxed/light-report.png` | OCR: `# Local Transit Tender`, `## Research Question`, `## Findings`, `**Supporting evidence:**`, `**Contradicting evidence:**`, `> Firms must submit bids within 14 days…` |
| Dark appearance | `Sandboxed/dark-01-overview.png`, `dark-02-findings.png` | Mean luminance 38 vs 245 in light; OCR reads all text |
| Minimum window (980×640) | `Sandboxed/min-size-01-overview.png` | Full workspace visible: title, question, scope, save state, stats, section picker |
| Search no-results | `Sandboxed/empty-03-no-search-results.png` | OCR: "No Matching Cases" + "Try a different title, question or case code." |
| Archived ≠ deleted | `Sandboxed/empty-02-archived.png` | OCR: "No Archived Cases" + "Archiving is not deleting." |
| Save feedback honesty | `Sandboxed/state-01-saved.png` | UI test asserts `saveState.saved` appears only after a persisted write |
| Error states | no screenshot | Covered by `ErrorBannerView`/`FatalErrorView` code and tests (`ExportFailureTests`, `RecoveryTests`); not captured because triggering them requires fault injection that would pollute a visual fixture |

## Checklist

| Check | Result |
| --- | --- |
| Type hierarchy consistent (page > section > body > metadata) | Pass — token-only typography |
| Icon sizes/alignment consistent | Pass — 18 pt row icons, 26–28 pt headers |
| Spacing follows tokens | Pass — all paddings from `DesignSystem.Spacing` |
| No clipping/overlap/unexpected scrolling at default size | Pass — 1180×780 captures show complete layouts |
| Same at minimum size 980×640 | Pass — `min-size-01-overview.png` |
| Dark mode text and separators readable | Pass — luminance check + OCR |
| Keyboard focus visible and ordered | Pass — AppKit focus rings retained, no custom suppression |
| Empty/error states offer a next step | Pass — every empty state has an action; errors have retry |
| Content usable when narrowed | Pass — sidebar and inspector collapse |
| Reduce Motion respected | Pass — no custom animations |
| No colour-only status encoding | Pass — every tag has text + SF Symbol |
| No emoji as functional icons | Pass — SF Symbols only |
| Screenshot contains no desktop/other apps | Pass — window-only captures |
| Screenshot contains no personal paths | Pass — fixture data only (`example.gov`, synthetic titles) |

## Known capture caveats

- `--screenshot` (in-app `cacheDisplay`) does not draw PDFKit canvases, which is
  why final evidence uses XCUITest **window** screenshots: those are composited
  and include the PDF page (OCR reads the fixture text).
- Appearance and window size during screenshots are driven by
  `EVIDENCE_DESK_APPEARANCE` and `EVIDENCE_DESK_WINDOW_SIZE` environment
  variables (see `docs/DECISIONS.md` D-012).
