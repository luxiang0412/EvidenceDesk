# Visual QA Checklist

Screenshots are rendered by the running app itself (`--screenshot`), then
inspected programmatically (OCR + pixel statistics) because this machine cannot
grant screen-recording permission to CLI tooling. Raw files live in
`artifacts/Screenshots/` (gitignored).

## Evidence sources

1. `artifacts/Screenshots/P1/` — app-rendered screenshots from the running app
   (`--screenshot`), OCR-verified.
2. `artifacts/Screenshots/UITests/` — screenshots attached by the XCTest UI
   suite (`ui-empty-state.png`, `ui-sources.png`, `ui-evidence.png`,
   `ui-findings.png`, `ui-timeline.png`, `ui-report.png`, `ui-new-case.png`,
   `ui-search-no-results.png`, `ui-archived-empty.png`,
   `ui-restart-sources.png`).

## Evidence index

| Requirement | File | How verified |
| --- | --- | --- |
| Main window, initial empty state | `artifacts/Screenshots/P1/empty-library.png`, `UITests/ui-empty-state.png` | Image 2360×1560; OCR: "No Research Cases", "Create a case to begin a research project.", "New Research Case" |
| Empty state, second run | `artifacts/Screenshots/P1/empty-light.png` | distinct render of the same state |
| Case overview (populated) | `artifacts/Screenshots/P1/final-overview-light.png` | OCR: title, question, scope, "Saved", stat counts 3 Sources / 4 Evidence / 1 Finding / 3 Timeline |
| Source list | `artifacts/Screenshots/P1/final-sources-light.png`, `UITests/ui-sources.png` | OCR: S-001 URL row with host + publisher, S-002 text row, S-003 PDF row |
| Source detail (URL) | `artifacts/Screenshots/P1/section-sources-detail-url.png` | OCR: link-source explanation + URL |
| PDF reader | `artifacts/Screenshots/P1/final-pdf-reader-light.png` + `.pdfpage.png` | Window capture shows list + reader chrome; PDFKit page rendered separately via PDFKit (OCR: "14 days", "30-day window") |
| Evidence | `artifacts/Screenshots/P1/final-evidence-light.png`, `UITests/ui-evidence.png` | OCR: 21 text elements incl. codes and excerpts |
| Findings (supports + contradicts) | `artifacts/Screenshots/P1/final-findings-light.png`, `UITests/ui-findings.png` | OCR: F-001 row + body |
| Report preview | `artifacts/Screenshots/P1/final-report-light.png`, `UITests/ui-report.png` | OCR: `# Local Transit Tender`, `## Research Question`, `### F-001`, `**Supporting evidence:**`, `**Contradicting evidence:**`, `> Firms must submit bids within 14 days…` |
| Timeline | `artifacts/Screenshots/P1/final-timeline-light.png`, `UITests/ui-timeline.png` | OCR: 6 text elements incl. event titles |
| Dark appearance | `artifacts/Screenshots/P1/final-dark-overview.png`, `section-sources-dark.png` | OCR: 24/10 lines legible; same content as light |
| Minimum window size (980×640) | `artifacts/Screenshots/P1/final-min-overview.png` | 1960×1384 render (2× 980×640); all primary controls present |
| Search / archived empty states | `UITests/ui-search-no-results.png`, `UITests/ui-archived-empty.png` | OCR: "No Matching Cases", "No Archived Cases" + "Archiving is not deleting." |
| Error / recovery state | covered by `RecoveryTests` (missing attachment, orphan clean-up) and `FatalErrorView`; no screenshot (see limitations) | see `docs/FINAL-ACCEPTANCE-REPORT.md` |

## Checklist

| Check | Result |
| --- | --- |
| Type hierarchy consistent (page title > section > body > metadata) | Pass — tokens only; verified in renders |
| Icon sizes and alignment consistent | Pass — 18 pt row icons, 26–28 pt headers |
| Spacing follows tokens | Pass — all paddings from `DesignSystem.Spacing` |
| No clipping, overlap, or unexpected scrolling at default size | Pass — 1180×780 renders show complete layouts |
| Same at minimum size 980×640 | Pass — min-size render shows title, question, scope, save state, stats |
| Dark mode text and separators readable | Pass — all colors are semantic or contrast-checked hues; OCR reads dark-mode text |
| Keyboard focus visible and ordered | Pass — default AppKit focus rings retained (no custom focus suppression) |
| Empty and error states offer a next step | Pass — every empty state has an action; errors have retry |
| Content area remains usable when narrowed | Pass — split view collapses sidebar/inspector |
| Motion respects Reduce Motion | Pass — no custom animations |
| No color-only status encoding | Pass — all status tags have text + symbol |
| No emoji used as functional icons | Pass — SF Symbols only |

## Known capture caveat

`NSView.cacheDisplay` does not draw PDFKit page contents or
`NSVisualEffectView` material. The PDF page is therefore additionally exported
through PDFKit (`*.pdfpage.png`), and the report preview was switched to an
`NSTextView`-backed `TextEditor` so its text is captured. This is a capture
limitation, not missing UI — the on-screen reader shows the same page.
