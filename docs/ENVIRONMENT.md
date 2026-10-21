# Environment

Recorded by `scripts/env.sh` on the implementation machine. Actual values take
precedence over any expectation in the task brief.

| Item | Value |
| --- | --- |
| OS | macOS 27.2 (build 26B5091g) |
| Architecture | arm64 (Apple Silicon) |
| Xcode | 27.1 (27A9275) — stable, matches plan baseline |
| Swift | Apple Swift 6.4 (swiftlang-6.4.0.34.1, clang-2100.3.34.1) |
| Swift language mode | Swift 6 (`SWIFT_VERSION = 6.0`), strict concurrency `complete` |
| macOS SDK | macOS 27.0 (`-sdk macosx27.0`) |
| Deployment target | **macOS 15.0** (`MACOSX_DEPLOYMENT_TARGET = 15.0`) |
| Git | 2.54.0 (Apple Git-157) |
| Homebrew | present at `/opt/homebrew/bin/brew` |
| XcodeGen | 2.46.0 |

## Notes

- The project is generated from `project.yml` by XcodeGen; the `.xcodeproj` is
  not committed.
- Minimum deployment target is 15.0 even though the development OS is newer.
  APIs newer than macOS 15 are avoided; the one encounter with
  `UTType.markdown` (macOS 27+) was replaced with `.plainText` / `.text`
  conformance checks — see `docs/DECISIONS.md`.
- **App Sandbox is enabled in every build**, including Debug and tests. The
  entitlements are declared in `project.yml` (`entitlements.properties`) because
  XcodeGen regenerates the plist (`docs/DECISIONS.md` D-011). Verified with
  `codesign -d --entitlements :- <app>` showing `com.apple.security.app-sandbox`.
- Because the app is sandboxed, its data lives in
  `~/Library/Containers/com.luxiang0412.EvidenceDesk/Data/...`. Tests and QA runs
  use `--test-storage-name <name>`, which resolves inside that container.
- Debug builds use ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`). This is *not*
  a distributable signature; see `docs/RELEASE.md`.
- Hardened runtime is disabled for Debug so the local ad-hoc signed app and
  the XCTest UI runner can load. A distribution build must re-enable it.

## Reproduction

```bash
./scripts/env.sh            # writes artifacts/P0/environment.txt
./scripts/generate-project.sh
./scripts/build.sh
./scripts/test.sh
```
