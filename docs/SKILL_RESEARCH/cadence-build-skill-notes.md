# cadence-build Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-build/SKILL.md`
**Skill-creator path:** `.claude/skills/skill-creator/`

---

## Local Files Read

| File | Purpose |
|------|---------|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure conventions, YAML frontmatter format, 1024-char description limit, 500-line limit, validate/package scripts |
| `docs/Cadence-design-doc.md` | App name "Cadence", iOS 26 minimum, SwiftUI + SwiftData, TestFlight distribution, no HealthKit |
| `docs/Cadence_Design_Spec_v1.1.md` | iOS 26 platform assumptions, standard TabView/NavigationStack (no custom chrome) |
| `docs/Cadence_SplashScreen_Spec.md` | File path `Cadence/Views/Splash/SplashView.swift` — establishes `Cadence` as the app target folder name |
| `docs/Cadence_MVP_Spec.md` | Confirms iOS/SwiftUI target, TestFlight beta distribution |
| `.claude/settings.local.json` | Confirmed no special build tool permissions; no CI configuration present |

---

## Skill-Creator Usage

Invoked via `Skill` tool (`skill-creator`). Full SKILL.md read before authoring. Direct authoring path (no eval loop) — spec was fully defined. Validated with `quick_validate.py` (pass).

---

## Anthropic Sources Used for Skill Standards

Project-local `skill-creator` at `.claude/skills/skill-creator/SKILL.md`. Key conventions applied:
- Quoted YAML description (≤1024 chars) to avoid bare-colon YAML parse errors
- All "when to use" in description frontmatter
- Body under 500 lines, imperative form
- No auxiliary documentation files

---

## Apple / xcbeautify / Authoritative Sources Used

| Source | Used for |
|--------|---------|
| `developer.apple.com/library/archive/technotes/tn2339/` | TN2339 — Building from Command Line with Xcode FAQ; xcodebuild scheme + destination flags |
| `developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project` | Scheme customization and `-list` discovery |
| Apple Developer Forums — simctl threads | `xcrun simctl boot`, `install`, `launch`, `spawn booted log stream` commands and flags |
| `developer.apple.com/documentation/xcode/build-settings-reference` | `SWIFT_TREAT_WARNINGS_AS_ERRORS`, `GCC_TREAT_WARNINGS_AS_ERRORS` build settings |
| `github.com/cpisciotta/xcbeautify` | xcbeautify usage — `set -o pipefail` requirement, renderer flags, Homebrew install |
| `swiftpackageindex.com/cpisciotta/xcbeautify` | xcbeautify package reference |

---

## Cadence-Specific Build Facts Extracted

### From Repository Inspection

**Critical finding: No Xcode project exists.** The repository is pre-implementation (docs + assets only as of March 7, 2026). No `.xcodeproj`, `.xcworkspace`, `project.yml`, Makefile, or build script was found.

**What exists:**
- `docs/` — design documents only
- `assets/` — `logo-light.png`, `logo-dark.png`, `logo-tinted.png`
- `.claude/skills/` — governance skills
- `.mypy_cache/` — Python tool cache from skill creation

**No xcbeautify configuration, no scheme definitions, no bundle identifier — all are pre-creation placeholders.**

### Inferred Build Facts (from docs, not invented)

| Property | Value | Source |
|---|---|---|
| App target / scheme | `Cadence` | Splash spec file path `Cadence/Views/Splash/SplashView.swift` establishes `Cadence/` as the target folder, which conventionally becomes the scheme name |
| Test scheme | `CadenceTests` | iOS convention — standard XCTest scheme naming for a project named `Cadence` |
| iOS minimum | iOS 26 | Design spec §2, design doc §5 |
| Bundle identifier | `<BUNDLE_ID>` — NOT DEFINED | No project file exists; must be set at project creation |
| Simulator | iPhone 16 Pro, iOS 26.0 | Derived from iOS 26 minimum deployment target |
| xcbeautify | Not yet installed/configured | No references in repo |

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|-----------|-----------|
| No Xcode project exists — scheme names and bundle ID cannot be confirmed | Scheme `Cadence` derived from `Cadence/Views/Splash/SplashView.swift` path prefix (design spec §0 brand asset reference). This is the conventional iOS scheme name when target folder matches app name. Clearly flagged as requiring confirmation at project initialization. `<BUNDLE_ID>` placeholder used throughout for bundle identifier. |
| No existing xcbeautify installation or configuration in the repo | Skill documents installation via Homebrew as the default; Mint as alternative. No existing convention to preserve. |
| No canonical simulator UDID is established | Skill uses name-based destination (`name=iPhone 16 Pro,OS=26.0`) as the default — this is deterministic without knowing a specific UDID. Skill documents the `xcrun simctl list devices` command to find and establish a canonical UDID. |
| `OS=26.0` may not match the exact iOS 26 SDK string available in a given Xcode 26 installation | Skill documents the fallback: omit `OS=` field to use the latest available runtime. |
| No `GCC_TREAT_WARNINGS_AS_ERRORS` posture established in repo | Cadence is Swift-only (SwiftUI) — `SWIFT_TREAT_WARNINGS_AS_ERRORS` is the relevant flag. `GCC_TREAT_WARNINGS_AS_ERRORS` noted but not the primary focus for this all-Swift codebase. |

---

## Key Enforcement Rules Encoded

1. All xcodebuild invocations use scheme `Cadence`; test runs use `CadenceTests`
2. All xcodebuild output piped through xcbeautify with `set -o pipefail` prefix
3. `set -o pipefail` is mandatory — without it, xcodebuild failures are silently swallowed
4. Destination uses explicit simulator name or UDID — never ambiguous `id=booted` for build commands
5. Incremental build is the default; clean build reserved for artifact failures and pre-submission
6. Full verification loop: build → `simctl install` → `simctl launch` → `simctl spawn log stream` → iterate
7. `simctl install` required before every launch — launching without install tests the previous binary
8. Log streaming started before app launch to capture launch-path events
9. `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` build must pass before marking any feature complete
10. Warning categories requiring resolution: Swift concurrency, deprecations, unused vars, implicit conversions, `@MainActor` misuse
11. `<BUNDLE_ID>` is a tracked placeholder — must be replaced at project initialization
12. xcbeautify installed via Homebrew (`brew install xcbeautify`) as the primary path
