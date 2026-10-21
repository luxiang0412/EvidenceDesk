# Release Notes (process)

This document records how Evidence Desk would be distributed. It distinguishes
clearly between **verified locally** and **not executed** (no credentials were
used, and no public release was performed).

## Current status

| Item | Status |
| --- | --- |
| Debug build with App Sandbox | Verified locally |
| Ad-hoc code signing (`CODE_SIGN_IDENTITY = "-"`) | Verified locally |
| Unit + UI tests | Verified locally |
| Developer ID signing | **Not executed** — no certificate available |
| Notarisation / stapling | **Not executed** — no credentials used |
| App Store submission | **Not executed** — deliberately not attempted |
| GitHub Release publication | **Not executed** |

Nothing in this repository claims a distributable or notarised artifact.

## App Sandbox

`EvidenceDesk/EvidenceDesk.entitlements` requests exactly:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-only</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```

- No network entitlement: the app never fetches anything.
- File access comes from the system panels (`NSOpenPanel` / `NSSavePanel`) or
  drag & drop, then files are **copied** into the app's Application Support
  directory so no long-lived security-scoped access is required.
- `get-task-allow` appears only in Debug builds via Xcode's debug entitlements;
  a Release build must not contain it. Verify with:

```bash
codesign -d --entitlements :- <App>.app
```

## Direct distribution (Developer ID)

Commands to run **when credentials exist**:

```bash
# 1. Archive
xcodebuild archive \
  -project EvidenceDesk.xcodeproj \
  -scheme EvidenceDesk \
  -configuration Release \
  -archivePath build/EvidenceDesk.xcarchive \
  DEVELOPMENT_TEAM=<TEAM_ID> \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  ENABLE_HARDENED_RUNTIME=YES

# 2. Export a Developer ID, hardened-runtime app
xcodebuild -exportArchive \
  -archivePath build/EvidenceDesk.xcarchive \
  -exportOptionsPlist ExportOptions-DeveloperID.plist \
  -exportPath build/export

# 3. Notarise and staple
xcrun notarytool submit build/export/EvidenceDesk.zip \
  --keychain-profile <profile> --wait
xcrun stapler staple build/export/EvidenceDesk.app

# 4. Verify
spctl -a -vvv -t install build/export/EvidenceDesk.app
codesign -dv --verbose=4 build/export/EvidenceDesk.app
```

`ExportOptions-DeveloperID.plist` needs `method = developer-id`,
`signingCertificate = Developer ID Application`, and `hardenedRuntime = true`.

Acceptance for a direct-download build would additionally require: successful
notary log review, Gatekeeper acceptance on a clean machine, and a first-launch
walkthrough. None of that has been performed here.

## Mac App Store

- Requires an App Store distribution certificate/profile, `com.apple.security.app-sandbox`
  (already present) and compliance with current App Review Guidelines.
- Sandboxed architecture and user-selected file access are already compatible.
- Submission is **explicitly out of scope** until the project owner approves it.

## Secret hygiene

- No certificates, private keys, provisioning profiles, App Store Connect keys
  or `.p8` files are committed (see `.gitignore`).
- CI must not use personal signing credentials; it builds and tests unsigned /
  ad-hoc only.
- `git status` and `git ls-files` were checked for accidental secrets before
  delivery.
