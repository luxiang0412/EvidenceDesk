# Contributing

Thanks for helping improve Evidence Desk.

## Ground rules

This project is intentionally small. Please keep it that way:

1. **No scope creep.** No scraping, monitoring, AI conclusions, cloud sync,
   accounts, telemetry, plugins, or knowledge graphs.
2. **No new runtime dependencies** without a written justification in
   `docs/DECISIONS.md` (why Apple APIs cannot do it, maintenance risk, licence,
   test plan).
3. **No silent data loss.** Any destructive operation must show its impact and
   offer a way out.
4. **Honest UI.** Never show "Saved" before a successful write. Never present a
   finding as proven. Never label a link as an archived snapshot.
5. **Privacy.** Do not log research content, URLs, filenames or paths. Test
   fixtures must be synthetic.

## Development loop

```bash
./scripts/generate-project.sh
./scripts/build.sh
./scripts/test.sh
./scripts/ui-test.sh
```

`project.yml` is the source of truth. Do not hand-edit `EvidenceDesk.xcodeproj`
(and do not commit it — it is generated and gitignored).

## Code layout

| Path | Responsibility |
| --- | --- |
| `App/` | entry point, environment, commands, startup/error views |
| `DesignSystem/` | tokens, shared components |
| `Domain/` | SwiftData models, enums, validation, sorting rules |
| `Features/` | SwiftUI screens, one folder per section |
| `Persistence/` | container factory, `PersistenceService`, `AttachmentStore`, recovery |
| `Services/` | import, PDF selection, report generation, archive export, logging |

Rules of thumb:

- Views render and collect input; they do not do file I/O or report building.
- Every mutation goes through `PersistenceService`; every file operation goes
  through `AttachmentStore`.
- Pure logic (validation, ordering, Markdown) belongs in `Domain/` or
  `Services/` so it can be tested without a UI.

## Tests

- Unit/integration: Swift Testing (`EvidenceDeskTests`). Use isolated in-memory
  or UUID-scoped on-disk stores.
- UI: XCTest (`EvidenceDeskUITests`). Always launch with
  `--test-storage-name <stable-per-class-name> --reset-test-storage` so each run
  starts from an empty library inside the app's sandbox container; never touch
  the real library. `scripts/ui-test.sh` cleans those stores afterwards.
- Add a test for every bug fix. Do not delete, skip, or weaken a test to make a
  run green.

## Pull requests

- Describe the user-visible change and how you verified it.
- Include the commands you ran and their results.
- Update `docs/DECISIONS.md` if you deviate from the plan, and `CHANGELOG.md`
  for user-visible changes.
- Screenshots are welcome for UI changes (they must not contain personal paths
  or private research data).

## Commit messages

Conventional-ish, imperative, scoped where useful:

```
feat(sources): re-link a missing attachment
fix(export): keep attachment paths relative
test(timeline): cover same-day ordering
docs(decisions): record UTType.markdown availability
```
