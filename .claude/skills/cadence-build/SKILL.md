---
name: cadence-build
description: "Governs all CLI build, install, launch, and verification operations for Cadence. Encodes xcodebuild scheme selection (scheme: Cadence, test scheme: CadenceTests), simulator targeting via xcrun simctl, xcbeautify output piping (set -o pipefail | xcbeautify), and the full verification loop — build → install → simctl launch → log stream → iterate. Defines when to use clean vs incremental builds. Flags warnings that become errors under SWIFT_TREAT_WARNINGS_AS_ERRORS. Use whenever running xcodebuild commands, selecting simulator destinations, piping through xcbeautify, launching the app in simulator, streaming logs with simctl spawn, or reviewing build warning hygiene for Cadence. Triggers on any question about xcodebuild, xcrun simctl, xcbeautify, scheme names, build destinations, simulator boot/install/launch, log streaming, or warning hygiene in this codebase."
---

# Cadence Build System

Authoritative CLI build and verification governance for Cadence. All build, install, launch, and log workflows are defined here. Do not improvise scheme names, destination strings, or xcodebuild invocations — use the commands in this skill.

---

## Project State Note

The Xcode project has not yet been generated (repository is pre-implementation as of the skill creation date). Scheme names and the target folder are derived from docs. When the project is first created:
- Confirm scheme name matches `Cadence`
- Set the bundle identifier and replace all `<BUNDLE_ID>` placeholders in this skill
- Record the canonical simulator UDID for the iOS 26 development device in your environment

---

## 1. Cadence Build Identity

| Property | Value |
|---|---|
| App scheme | `Cadence` |
| Test scheme | `CadenceTests` |
| App target folder | `Cadence/` (e.g., `Cadence/Views/Splash/SplashView.swift`) |
| Bundle identifier | `<BUNDLE_ID>` — set at project creation; required for `simctl launch` |
| Minimum deployment | iOS 26 |
| Project file | `.xcodeproj` (single project, no workspace unless CocoaPods/SPM workspace needed) |

---

## 2. Build Modes — Clean vs Incremental

**Use incremental builds for all normal iteration.** Clean builds are expensive and should be reserved for specific failure conditions.

```bash
# --- INCREMENTAL BUILD (default) ---
set -o pipefail && \
  xcodebuild \
    -scheme Cadence \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    build \
  | xcbeautify

# --- CLEAN BUILD (when required) ---
set -o pipefail && \
  xcodebuild \
    -scheme Cadence \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    clean build \
  | xcbeautify
```

**Use a clean build when:**
- Incremental build produces stale artifact errors or phantom linker failures
- Switching between significantly different branches
- Preparing a verification build before a TestFlight submission
- A dependency (SPM package, xcassets) has changed structurally

**Never clean on every iteration.** Incremental builds are deterministic for code changes and orders of magnitude faster.

---

## 3. Scheme Selection

| Task | Scheme |
|---|---|
| Build and run the app | `Cadence` |
| Run unit/UI tests | `CadenceTests` |

```bash
# List all available schemes (run from repo root)
xcodebuild -list -project Cadence.xcodeproj
```

Never guess scheme names. If the project file does not exist yet, run `xcodebuild -list` after project generation to confirm the exact scheme string before encoding it anywhere.

---

## 4. Simulator Targeting via xcrun simctl

Always use explicit simulator names or UDIDs — never `id=booted` for build commands, as it is ambiguous when multiple simulators are running.

```bash
# Step 1 — List available iOS 26 simulators and find the UDID
xcrun simctl list devices available | grep "iOS 26"

# Step 2 — Boot the target simulator (idempotent — safe to re-run if already booted)
xcrun simctl boot "<SIMULATOR_UDID>"

# Step 3 — (Optional) Open Simulator.app to display the booted device
open -a Simulator
```

**Recommended development simulator:** iPhone 16 Pro, iOS 26.0 — matches the primary design and testing target. Use `iPhone 16 Pro` as the `-destination name` in xcodebuild until a canonical UDID is established.

```bash
# Destination string for xcodebuild (name-based — works without knowing UDID)
-destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

If `OS=26.0` is not available, omit the `OS=` field and use the latest available:
```bash
-destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

---

## 5. Output Formatting via xcbeautify

All xcodebuild output must be piped through `xcbeautify`. Raw xcodebuild output is acceptable only when debugging a specific xcbeautify filtering issue.

**Install xcbeautify (one-time):**
```bash
# Homebrew (preferred)
brew install xcbeautify

# Mint (if Homebrew unavailable)
mint install cpisciotta/xcbeautify
```

**Required pipe pattern:**
```bash
set -o pipefail && xcodebuild [flags] | xcbeautify
```

`set -o pipefail` is mandatory. Without it, a failing `xcodebuild` exit code is swallowed by the pipe and the shell reports success — this produces silent build failures in scripts and CI.

**xcbeautify flags (optional, context-dependent):**
```bash
xcbeautify --quiet           # suppress passing steps; show only warnings/errors
xcbeautify --renderer github # GitHub Actions annotation format (for CI)
xcbeautify --is-ci           # disables colors; suitable for any CI environment
```

---

## 6. Build Verification Loop

The canonical Cadence verification sequence. Run this in full before declaring a feature complete or a bug fix verified.

```bash
# ── Step 1: Build (incremental) ──────────────────────────────────────
set -o pipefail && \
  xcodebuild \
    -scheme Cadence \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    build \
  | xcbeautify

# ── Step 2: Install to booted simulator ──────────────────────────────
# APP_PATH is the .app bundle produced by the build, found in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Cadence.app" \
  -path "*/Debug-iphonesimulator/*" | head -1)

xcrun simctl install booted "$APP_PATH"

# ── Step 3: Launch ───────────────────────────────────────────────────
xcrun simctl launch booted <BUNDLE_ID>

# ── Step 4: Collect logs ─────────────────────────────────────────────
# (Run in a separate terminal before launch, or pipe after)
xcrun simctl spawn booted log stream \
  --level debug \
  --predicate 'subsystem BEGINSWITH "com.cadence"'

# ── Step 5: Iterate ──────────────────────────────────────────────────
# Make code change → re-run Step 1 (incremental) → install → re-launch
```

**Install step shortcut when simulator is already booted:**
```bash
xcrun simctl install booted "$APP_PATH" && xcrun simctl launch booted <BUNDLE_ID>
```

Do not skip the install step between builds. A launch without a fresh install tests the previous binary.

---

## 7. Log Collection

Stream app logs during development to catch crash-inducing paths before manual test coverage.

```bash
# Stream all debug logs from Cadence subsystem
xcrun simctl spawn booted log stream \
  --level debug \
  --predicate 'subsystem BEGINSWITH "com.cadence" OR process == "Cadence"'

# Stream only errors and faults (quieter, for targeted debugging)
xcrun simctl spawn booted log stream \
  --level error \
  --predicate 'process == "Cadence"'

# Capture a fixed window of logs to file (useful for error reporting)
xcrun simctl spawn booted log collect --output /tmp/cadence-logs.logarchive
```

**Rules:**
- Start log streaming before launching the app — logs from the launch sequence are discarded otherwise.
- Replace `com.cadence` with the actual bundle ID prefix once `<BUNDLE_ID>` is set.
- Do not rely solely on Xcode's console for verification builds. Structured `log stream` captures OS-level events (memory warnings, APNS events, background transitions) that the Xcode console may not surface.

---

## 8. Warning Hygiene

Cadence targets iOS 26, which carries strict Swift concurrency expectations. Treat warnings as pre-errors — they indicate issues that will fail CI or future `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` builds.

**Build with warnings-as-errors to verify clean state:**
```bash
set -o pipefail && \
  xcodebuild \
    -scheme Cadence \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    build \
  | xcbeautify
```

**Warning categories that must be resolved before marking code complete:**

| Category | Why it matters |
|---|---|
| Swift concurrency (`Sendable`, actor isolation) | iOS 26 requires strict concurrency; these will be errors in stricter modes |
| Deprecated API usage | APIs deprecated on iOS 26 will be removed; carry forward tech debt |
| Unused variables / parameters | Often indicates logic errors or dead code |
| Implicit conversions / type coercions | Hide potential precision or data loss bugs |
| `@MainActor` misuse or missing annotations | Correct main-actor attribution is required for SwiftUI + SwiftData correctness |

**Do not suppress warnings with `// swiftlint:disable` or `#warning("TODO")` markers in committed code.** Either fix the underlying issue or open a tracked engineering task.

---

## 9. Anti-Pattern Table

| Anti-pattern | Rule violated |
|---|---|
| Using scheme names other than `Cadence` / `CadenceTests` without verifying with `xcodebuild -list` | Scheme selection rule |
| Omitting `set -o pipefail` before the pipe to `xcbeautify` | Silent build failure risk |
| Using raw `xcodebuild` output (no `xcbeautify`) for normal iteration | Output formatting rule |
| Using `-destination 'id=booted'` with no UDID when multiple simulators are running | Ambiguous destination — non-deterministic |
| Launching without re-installing after a build | Tests previous binary — not the new build |
| Skipping log streaming during verification | Misses OS-level events and launch-path crashes |
| Running `clean build` on every iteration | Unnecessary — clean only for artifact failures or pre-submission |
| Ignoring warnings as "harmless" without checking against `SWIFT_TREAT_WARNINGS_AS_ERRORS` | Deferred build failures in CI or future settings |

---

## 10. Enforcement Checklist

Before marking any build or verification task complete:

- [ ] Scheme is `Cadence` for app builds; `CadenceTests` for test runs — confirmed with `xcodebuild -list`
- [ ] All `xcodebuild` invocations pipe through `xcbeautify` with `set -o pipefail`
- [ ] Simulator destination uses explicit name or UDID — not `id=booted` for build commands
- [ ] Simulator is running iOS 26 — confirm with `xcrun simctl list devices`
- [ ] App is installed (`simctl install`) after every build before launching
- [ ] `simctl launch <BUNDLE_ID>` used to launch — not Xcode's Run button for CLI verification
- [ ] Log streaming started before app launch for full capture
- [ ] Incremental build used for iteration; clean build reserved for artifact failures or pre-submission
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` build passes before marking feature complete
- [ ] No deprecation, concurrency, or implicit-conversion warnings left unresolved
- [ ] `<BUNDLE_ID>` placeholder replaced with the real bundle identifier once project is initialized
