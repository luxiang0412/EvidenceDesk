# Changelog

All notable changes to Evidence Desk are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-10-21

First complete release of the local-first research workspace.

### Added

- **Cases**: create, edit title/question/scope, search, archive and restore,
  delete with impact confirmation. Case codes (`C-001`) are stable.
- **Sources**: `http`/`https` link sources with metadata only (no fetching),
  PDF import with an embedded PDFKit reader (zoom, fit, page indicator, text
  selection), TXT/Markdown import with preview. Drag & drop and menu import use
  the same validated pipeline. 100 MB per-file limit, UUID attachment storage,
  missing-attachment detection and re-link.
- **Evidence**: excerpt, type (`fact`/`interpretation`/`hypothesis`/
  `unresolved`), source + location + page, personal notes, personal-note mode
  for unlinked items. Created from PDF selection with automatic page capture.
- **Findings**: title, body, status (`draft`/`active`/`superseded`), typed
  evidence links (`supports`/`contradicts`/`context`), uncertainty notes,
  per-link relation changes.
- **Timeline**: dated events with day/month/year precision, explicitly undated
  events kept in a separate section, optional source links.
- **Export**: Markdown report with question, scope, findings grouped by
  relation, evidence excerpts with citations (`[E-002, S-001, p. 3]`), timeline,
  source list with clickable URLs and relative attachment paths, plus unresolved
  issues. Portable case bundle with `manifest.json` (`schemaVersion`, stable
  IDs, relative paths) and copied attachments.
- **Data integrity**: explicit saves with `Saving/Saved/Failed` states, startup
  consistency check for missing and orphaned attachments, attachment staging with
  size verification and rollback on failure.
- **macOS integration**: native window/toolbar/split view, menus with keyboard
  shortcuts, drag & drop, App Sandbox with user-selected file access only,
  semantic colors for light/dark, Reduce Motion respected, VoiceOver labels for
  all rows, buttons and statuses.

### Quality

- 55 Swift Testing tests (unit + integration) and 11 XCTest UI tests.
- `scripts/verify-all.sh` runs environment → generate → build → unit tests →
  UI tests.
- Performance baseline recorded (500 sources, 200 evidence/link rows, 100 MB
  import limit path).

### Known limitations

- Web page content is not fetched or archived; link sources are labelled as
  such.
- No cloud sync, accounts, AI features or telemetry.
- Builds are ad-hoc signed for local development; not notarised and not
  distributed.
