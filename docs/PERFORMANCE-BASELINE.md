# Performance Baseline

## Machine

| Item | Value |
| --- | --- |
| Mac | MacBook Air (Apple M1), 16 GB RAM |
| OS | macOS 27.2 (26B5091g) |
| Xcode | 27.1 (27A9275) |
| Swift | 6.4 |
| Build | Debug, XcodeGen-generated project, `-derivedDataPath artifacts/DerivedData` |

Debug builds are intentionally used for acceptance; they are not optimised, so
numbers are an upper bound, not a marketing figure.

## Dataset

Synthetic fixtures generated in isolated in-memory stores (no user data):

- 500 sources in one case
- 200 evidence items, each linked to one finding (200 `FindingEvidenceLink` rows)
- Report generation over the full 200-item evidence set
- A 100 MB and a 101 MB sparse file to exercise the size limit path

## Results

| Measurement | Result | Note |
| --- | --- | --- |
| Create 500 sources (in-memory) | 3.45 s total | ~6.9 ms per insert including explicit `save()` per item |
| 200 evidence + 200 links + report generation | 0.79 s | includes building `ReportPayload` and Markdown |
| Report generation only (200 items) | 0.004 s | pure function, no I/O |
| 100 MB file | accepted (== limit) | size read via `attributesOfItem`, file never fully read into memory |
| 101 MB file | rejected before copy | `FileValidationError.tooLarge` |

Raw log: `artifacts/P6/performance-baseline.txt`.

## Architectural guarantees that back the numbers

- **No attachment bodies are read at case-open time.** Case open reads only
  SwiftData metadata; text preview reads at most 200 KB lazily, PDFs are opened
  by URL through PDFKit.
- **Imports stream through the file system**, using `FileManager.copyItem`
  (kernel copy), not `Data(contentsOf:)`. Peak memory therefore does not scale
  with file size.
- **Lists are SwiftUI `List` over sorted arrays**; 500 rows render lazily.
- **Writes are explicit and serialised on the main actor** (`autosaveEnabled =
  false`), so there is no background-context churn or unbounded memory growth
  from pending saves.
- **PDF reader is created per selection** and torn down on `onDisappear`
  (`dismantleNSView` clears the delegate), avoiding retained document graphs.

## Instruments (Time Profiler)

Recorded with `xctrace` against a Debug build with the sandbox enabled:

```bash
xcrun xctrace record --template 'Time Profiler' --launch --time-limit 6s \
  --output <trace> -- <App>/Contents/MacOS/EvidenceDesk \
  --test-storage-name perf-trace2 --reset-test-storage --seed-demo
```

Workload: process launch → SwiftData store creation → synthetic case seeding
(two attachment imports, one generated PDF) → first window render.

Result: **612 samples over 6 s**. Busiest leaf frames:

| Share | Frame |
| --- | --- |
| 4.2% | `objc_msgSend` |
| 3.3% | `getMethodNoSuper_nolock` |
| 2.9% | `<deduplicated_symbol>` |
| 2.0% | `mach_msg2_trap` |
| 1.3% | `_platform_memmove` |
| 1.1% | Swift metadata cache lookup |
| 1.0% | `AG::Graph::UpdateStack::update()` (SwiftUI layout) |

No Evidence Desk business-logic frame appears among the top leaves: nothing on
the launch path parses attachment bodies or generates reports synchronously.
Summary saved as `artifacts/P6/instruments-summary.txt`; raw `.trace` bundles
were deleted because they embed the recording process's environment variables.

Limitations: the Allocations template in this Xcode exposes no exportable
allocation table, so memory evidence is the RSS sampling below. Interactive
workloads could not be driven during recording (see D-013).

## Manual checks performed

- Launch with the seeded 3-source case, sampled RSS every 3 s for 18 s:
  133 MB at +3 s … 133 MB at +15 s, 144 MB at +18 s (first PDF/text render warm-up).
  Plateau, no continuing growth.
- Three consecutive launches on the same store: 136 MB / 136 MB / 136 MB RSS at
  +7 s each — no accumulation between runs.
- Section switching across Overview → Sources → Evidence → Findings → Timeline
  → Report with the seeded case: no hangs or stalls; the same single-process
  RSS band (≈133–144 MB) throughout.
- 100 MB import path exercised through validation; the copy path is the same
  kernel-level copy used for all sizes.

Command used for the RSS samples:

```bash
"$APP/Contents/MacOS/EvidenceDesk" --test-storage /tmp/qaseed &
for i in 1 2 3 4 5 6; do sleep 3; ps -o rss= -p $! ; done
```

## Not measured here

- Interactive Instruments sessions (clicking through sections while recording):
  synthetic clicks are unreliable on this hardware, see `docs/DECISIONS.md`
  D-013. The launch/seed trace above is the recorded substitute.
- Absolute frame timings on older hardware. The brief forbids promising
  cross-Mac millisecond targets; only this machine is characterised.
