# Evidence Desk

**Native macOS Research Workspace** — a local-first research desk for turning a
question into a traceable Markdown report.

Evidence Desk keeps the whole research loop in one place: create a case, add
sources (links, PDFs, text/Markdown), record evidence excerpts with their
source and location, group that evidence under findings as *supports /
contradicts / background*, add a simple timeline, and export a report where
every claim can be traced back to a source.

Everything is stored on your Mac. There is no account, no cloud sync, no
telemetry, and no AI service.

## Screenshots

Real renders of the running app (captured via the app's own QA renderer; see
`docs/VISUAL-QA-CHECKLIST.md`):

| Screen | File |
| --- | --- |
| Empty library | `artifacts/Screenshots/Sandboxed/empty-01-library.png` |
| Archived empty state | `artifacts/Screenshots/Sandboxed/empty-02-archived.png` |
| Search, no results | `artifacts/Screenshots/Sandboxed/empty-03-no-search-results.png` |
| Case overview | `artifacts/Screenshots/Sandboxed/light-overview.png` |
| Sources | `artifacts/Screenshots/Sandboxed/light-sources.png` |
| Evidence | `artifacts/Screenshots/Sandboxed/light-evidence.png` |
| Findings | `artifacts/Screenshots/Sandboxed/light-findings.png` |
| Timeline | `artifacts/Screenshots/Sandboxed/light-timeline.png` |
| Report preview | `artifacts/Screenshots/Sandboxed/light-report.png` |
| Dark appearance | `artifacts/Screenshots/Sandboxed/dark-01-overview.png` |
| Minimum window (980×640) | `artifacts/Screenshots/Sandboxed/min-size-01-overview.png` |
| PDF reader page (PDFKit render) | `artifacts/Screenshots/Sandboxed/light-pdf-reader.png` |

`artifacts/` is gitignored. Regenerate the screenshots with:

```bash
xcodebuild test -project EvidenceDesk.xcodeproj -scheme EvidenceDesk \
  -destination 'platform=macOS' -derivedDataPath artifacts/DerivedData \
  -only-testing:EvidenceDeskUITests/ScreenshotTests \
  -resultBundlePath artifacts/TestResults/screenshots.xcresult
xcrun xcresulttool export attachments \
  --path artifacts/TestResults/screenshots.xcresult \
  --output-path artifacts/Screenshots/Sandboxed
```

## Scope (v1)

Included:

- Research cases: title, research question, scope, search, archive, delete with
  impact warnings.
- Sources: `http`/`https` links (metadata only — page content is **not**
  fetched), PDF (read, zoom, select text, page numbers), TXT/Markdown (preview,
  full original preserved). Drag & drop and menu import share one pipeline.
- Evidence: excerpt, type (`fact` / `interpretation` / `hypothesis` /
  `unresolved`), source link, location, page, personal notes.
- Findings: title, body, status (`draft` / `active` / `superseded`), typed
  evidence links, uncertainty notes.
- Timeline: dated and explicitly undated events.
- Export: Markdown report, plus a portable case bundle
  (`manifest.json` + `report.md` + `attachments/`).

Deliberately excluded: web scraping, automatic monitoring, AI summarisation or
verdicts, cloud sync, accounts, plugins, knowledge graphs, and any telemetry.

## Requirements

- macOS 15.0 or newer
- Xcode 27.1 (Swift 6.4) — the toolchain used for acceptance
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46.0 (`brew install xcodegen`)

Exact recorded versions: `docs/ENVIRONMENT.md`.

## Build

The Xcode project is generated from `project.yml`; the `.xcodeproj` is not
committed.

```bash
./scripts/generate-project.sh     # xcodegen generate
./scripts/build.sh                # Debug build into artifacts/DerivedData
open artifacts/DerivedData/Build/Products/Debug/EvidenceDesk.app
# or
./scripts/run-debug.sh
```

## Test

```bash
./scripts/test.sh      # Swift Testing: unit + integration (66 tests)
./scripts/ui-test.sh   # XCTest UI automation + screenshots (20 tests)
./scripts/verify-all.sh  # env → generate → build → unit tests → UI tests
SKIP_UI_TESTS=1 ./scripts/verify-all.sh   # if UI automation is unavailable
./scripts/perf-baseline.sh                # scale/perf baseline → artifacts/P6
```

Both test targets use an isolated storage directory (a UUID-scoped folder
inside the app's own sandbox container), never your real library. App Sandbox
is enabled in every build, including tests.

## Where your data lives

```
~/Library/Containers/com.luxiang0412.EvidenceDesk/Data/Library/Application Support/EvidenceDesk/
├── EvidenceDesk.store            # SwiftData database
└── Attachments/<source-uuid>/original.<ext>
```

- Uninstalling or trashing the app does **not** necessarily delete this folder.
  To remove all research data, quit the app and delete that directory.
- To back up or move a case portably, use **Export Case Bundle…** — it writes
  `manifest.json`, `report.md` and copies of the attachments with **relative**
  paths (no sandbox-absolute paths).

## Privacy

- All research data stays on this Mac.
- No network requests are made by the app. Opening a link hands the URL to your
  default browser.
- No telemetry, analytics, ads, or crash uploads.
- Logs contain operation categories, stable IDs and error codes only — never
  research text, URLs or file paths.
- Test fixtures are synthetic and generated at runtime.

## Languages

The interface ships in **English** and **简体中文**.

- **Language…** (View menu, or ⌘,) offers *Follow System Language / English /
  简体中文*. The choice is stored per app; the UI applies it after you quit and
  reopen (macOS resolves the app's localisation at launch). The settings screen
  says so and offers a Quit button.
- Exported Markdown headings follow the chosen language; case titles, short
  codes (`S-001`), citations (`[E-002, S-001, p. 3]`) and your own text are
  never translated.
- Translations live in `EvidenceDesk/Resources/Localizable.xcstrings` and are
  regenerated from `scripts/build-localization.py`.

## Keyboard shortcuts

`⌘N` new case · `⌘I` import source · `⇧⌘E` export report · `⌘F` focus search ·
`⌥⌘I` toggle inspector · `⌘,` language settings. Standard text editing shortcuts
apply inside editors.

## Known limitations

- Web sources store the link plus metadata you provide. The page body is never
  fetched or archived, so link rot is possible; exported reports label them
  plainly as links.
- Deleting a source asks whether to keep or delete its evidence; there is no
  undo for database deletions (system Undo applies to text editing only).
- The app is not notarised. Debug builds are ad-hoc signed and are **not**
  distributable. See `docs/RELEASE.md`.
- Under an accessibility client (VoiceOver, UI automation), SwiftUI can crash
  while an editor sheet is dismissed. Mitigations are in place, but reproduce it
  in a VoiceOver session before shipping — see `docs/DECISIONS.md` D-014.
- Final screenshots come from XCUITest window captures (sandboxed app, window
  only); they include PDFKit's page content.

## Documentation

| Document | Purpose |
| --- | --- |
| `docs/ENVIRONMENT.md` | recorded toolchain and machine |
| `docs/DECISIONS.md` | every deviation and why it was made |
| `docs/DESIGN-SYSTEM.md` | tokens, components, accessibility contract |
| `docs/INTERACTION-SPEC.md` | shortcuts, drag & drop, saving, deletion |
| `docs/SCREEN-SPECS.md` | per-screen states |
| `docs/VISUAL-QA-CHECKLIST.md` | visual acceptance evidence |
| `docs/PERFORMANCE-BASELINE.md` | scale and memory baseline |
| `docs/DECISIONS.md` | including D-015 (why language switching needs a relaunch) |
| `docs/RELEASE.md` | direct distribution vs Mac App Store |
| `docs/FINAL-ACCEPTANCE-REPORT.md` | final delivery report |

## License

MIT — see `LICENSE`.
