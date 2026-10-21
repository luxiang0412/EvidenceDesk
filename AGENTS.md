# AGENTS.md — Evidence Desk

Native macOS research workspace (SwiftUI + SwiftData + PDFKit), local-first, no
network. Read `README.md` for the product, `docs/DECISIONS.md` before changing
anything behavioural, and `docs/FINAL-ACCEPTANCE-REPORT.md` for current status.

## Commands

```bash
./scripts/generate-project.sh   # XcodeGen → EvidenceDesk.xcodeproj (never commit it)
./scripts/build.sh              # Debug build → artifacts/DerivedData
./scripts/test.sh               # Swift Testing: unit + integration
./scripts/ui-test.sh            # XCTest UI automation (+ screenshots)
./scripts/verify-all.sh         # env → generate → build → tests → ui-tests
SKIP_UI_TESTS=1 ./scripts/verify-all.sh
./scripts/perf-baseline.sh      # scale/perf → artifacts/P6
python3 scripts/build-localization.py   # regenerate Localizable.xcstrings
./scripts/run-debug.sh          # build + open the app
```

`project.yml` is the single source of truth. After editing it (or adding files),
run `generate-project.sh`; new Swift files are not compiled until you do.

Environment: macOS 15.0 deployment target, Swift 6 mode, strict concurrency,
MainActor-by-default for the app target. Toolchain details: `docs/ENVIRONMENT.md`.

## Layout

| Path | Responsibility |
| --- | --- |
| `App/` | entry, `AppSetup`, `AppEnvironment`, commands, `LanguageSettings`, `L10n` |
| `DesignSystem/` | `DesignTokens` (all spacing/colour/type), shared components |
| `Domain/` | SwiftData `@Model`s, enums, validation, `CaseFilter`, `TimelineSorting` |
| `Features/` | one folder per screen (Library, CaseWorkspace, Sources, Evidence, Findings, Timeline, ReportPreview, Settings) |
| `Persistence/` | `ModelContainerFactory`, `PersistenceService`, `AttachmentStore`, `RecoveryService` |
| `Services/` | import, PDF selection, report generation/export, logging |

## Invariants (do not break)

1. **Every mutation goes through `PersistenceService`**; every file operation
   through `AttachmentStore`. Views never touch `ModelContext` for writes;
   `autosaveEnabled` is `false`.
2. **No silent data loss.** Deleting a source must offer “keep evidence” vs
   “delete evidence”; `DeletionGuard` computes the impact for the dialog.
3. **Honest UI.** “Saved” only after a successful `save()`; a link source is
   labelled as a link (content is never fetched); a finding is never presented as
   proven. No confidence scores.
4. **No network.** No `URLSession`, no network entitlement. Opening a URL hands
   it to the browser.
5. **Sandbox is real.** Entitlements are declared in `project.yml`
   (`entitlements.properties`); XcodeGen **regenerates** the plist, so never
   hand-edit `EvidenceDesk.entitlements`. Verify with
   `codesign -d --entitlements :- <app>` → expect `app-sandbox`.
6. **Export paths are relative**; never write sandbox-absolute paths into
   `manifest.json` or the report.
7. **Strings are localised** via `Localizable.xcstrings`; add keys to
   `scripts/build-localization.py` and regenerate. `String`-typed UI values go
   through `L10n.t(_:)` — `Text("literal")` alone does not cover them.

## Testing rules

- Unit/integration: Swift Testing in `EvidenceDeskTests`. Use
  `PersistenceService.makeInMemory()` or a UUID-scoped on-disk store.
- UI: XCTest in `EvidenceDeskUITests`. Always launch with
  `--test-storage-name <stable-name> --reset-test-storage` (resolved inside the
  app's sandbox container) and pin the language with
  `Self.languageArguments("en")`. Never touch the real library.
- Fixing a bug means adding a test. Never delete, skip, weaken or `try?`-away a
  failing assertion to get green. If a flow cannot be automated, cover the logic
  at a lower layer and document why (see D-013).

## Environment gotchas (already cost time — don't rediscover)

- **Touch Bar + CJK IME.** Synthetic clicks on mirrored controls (segmented
  picker, `confirmationDialog` buttons) and typed text are unreliable. Tests
  therefore select sections with `--ed-section`, set empty states with
  `--ed-show-archived` / `--ed-search`, and assert dialog *contracts* only.
- **`.environment(\.locale, …)` on the root scene prevents the window from
  appearing** on this SDK. Language is applied via `AppleLanguages` + relaunch
  (D-015).
- **`Text` + `.accessibilityIdentifier` can expose an empty label**, and a
  container with `.accessibilityElement(children: .ignore)` swallows buttons.
  Use explicit `.accessibilityLabel` and keep buttons outside combined wrappers
  (D-014).
- **Saving from an editor sheet can crash SwiftUI's accessibility layer** when an
  accessibility client is attached; mitigations applied, still a known risk
  (D-014). Don't add a UI test that depends on sheet dismissal.
- **Sandboxed app**: data lives in
  `~/Library/Containers/com.luxiang0412.EvidenceDesk/Data/`; leftovers under
  `Data/tmp/EvidenceDeskUITest` are cleaned by `ui-test.sh`.

## Debug hooks (inert without the flag)

`--test-storage <dir>`, `--test-storage-name <name>`, `--reset-test-storage`,
`--seed-demo`, `--ed-section <overview|sources|evidence|findings|timeline|report>`,
`--ed-select S-003`, `--ed-show-archived`, `--ed-search <text>`,
`--appearance light|dark`, `--window-size W,H`, `--screenshot <path>`,
`--ed-trace`. Env equivalents: `EVIDENCE_DESK_APPEARANCE`,
`EVIDENCE_DESK_WINDOW_SIZE`. UI tests set the language with
`-AppleLanguages (en|zh-Hans)`.

## Git / delivery

- Never commit `EvidenceDesk.xcodeproj`, `artifacts/`, `DerivedData`, or any
  credentials. `.gitignore` already covers them.
- Do not push, publish releases, notarise or submit to App Store without an
  explicit instruction from the user.
- Record any deliberate deviation in `docs/DECISIONS.md` (reason, impact, how it
  was verified), and update `CHANGELOG.md` for user-visible changes.
