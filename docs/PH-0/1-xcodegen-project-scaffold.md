# XcodeGen Project Scaffold and Target Configuration

**Epic ID:** PH-0-E1
**Phase:** 0 -- Project Foundation
**Estimated Size:** L
**Status:** Draft

---

## Objective

Author a complete `project.yml` spec, generate a valid `Cadence.xcodeproj`, and verify that both the `Cadence` application target and the `CadenceTests` unit test target compile clean against the iOS 26 simulator under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. The generated project is the foundational artifact that every subsequent Swift file addition and CI build depends on.

## Problem / Context

Without a correct `project.yml`, every file addition in subsequent phases risks corrupting the `.pbxproj` or creating source files invisible to the build system. XcodeGen's `createIntermediateGroups: true` option means the source tree layout is the contract -- deviating from the prescribed group structure in any phase creates unresolvable merge conflicts in the generated `.pbxproj`.

The cadence-xcode-project skill defines the required `project.yml` schema, source group hierarchy, and asset catalog organization. Errors introduced here compound through all 14 subsequent phases. Design Spec v1.1 §2 fixes the minimum deployment target (iOS 26), Swift version, and framework constraint (SwiftUI throughout, no UIKit custom views) -- these must be locked in build settings from the first commit.

The locked brand mark PNGs (`logo-light.png`, `logo-dark.png`, `logo-tinted.png`) already exist in `assets/` and must be copied into `Images.xcassets/AppIcon.appiconset/` so the App Icon is resolvable at first build time. Deferring this risks a build warning that becomes a CI error under strict settings.

**Source references that define scope:**

- cadence-xcode-project skill §2 (required project.yml structure)
- cadence-xcode-project skill §4 (source group conventions)
- cadence-xcode-project skill §5 (asset catalog organization)
- cadence-xcode-project skill §6.3 (App Icon Contents.json format)
- Design Spec v1.1 §2 (platform and framework assumptions)
- PHASES.md Phase 0 in-scope: "XcodeGen project.yml with Cadence target and CadenceTests target"

## Scope

### In Scope

- `project.yml` at repo root: `name: Cadence`, `options.deploymentTarget.iOS: "26.0"`, `options.createIntermediateGroups: true`, `options.groupSortPosition: bottom`, `SWIFT_VERSION: "5.0"`, `IPHONEOS_DEPLOYMENT_TARGET: "26.0"`
- `targets.Cadence` application target: `type: application`, `platform: iOS`, `sources: Cadence`, `PRODUCT_BUNDLE_IDENTIFIER: com.cadence.tracker`, `INFOPLIST_FILE: Cadence/App/Info.plist`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- `targets.CadenceTests` unit test target: `type: bundle.unit-test`, `platform: iOS`, host app reference to `Cadence`
- Complete `Cadence/` source directory hierarchy per cadence-xcode-project §4 (App, Views, ViewModels, Models, Services, Resources subdirectories)
- `Cadence/App/CadenceApp.swift` -- `@main` entry point with empty `WindowGroup { ContentView() }`, no feature logic
- `Cadence/Views/Shared/ContentView.swift` -- `Text("Cadence")` body only, no feature logic
- `Cadence/App/Info.plist` -- standard iOS app Info.plist with required keys
- `CadenceTests/CadenceTests.swift` -- single empty `XCTestCase` subclass so the test target has a source file and compiles
- `Cadence/Resources/Images.xcassets` with `AppIcon.appiconset/Contents.json` containing light, dark, and tinted App Icon entries using the locked PNGs from `assets/`
- Execution of `xcodegen generate --spec project.yml` and commit of `project.yml` + `Cadence.xcodeproj` together
- Build verification: `xcodebuild build` and `xcodebuild build-for-testing` both exit 0

### Out of Scope

- `Cadence/Resources/Colors.xcassets` -- owned by PH-0-E2
- Feature SwiftUI views (Phase 2 onward) -- ContentView.swift contains only a Text placeholder
- SwiftData model definitions (Phase 3 onward)
- `CadenceUITests` target -- introduced in Phase 4 when UI tests are first authored
- `.github/workflows/ci.yml` and Fastlane configuration -- owned by PH-0-E3
- `.gitignore` -- owned by PH-0-E3
- `.swiftlint.yml` -- owned by PH-0-E4
- Individual brand mark imagesets for SplashView (Phase 2) -- only `AppIcon.appiconset` is required now
- `CadencePrimary` color asset -- blocked pending designer confirmation per Phase 0 known blocker

## Dependencies

| Dependency                            | Type     | Phase/Epic | Status                                                                                               | Risk                                                     |
| ------------------------------------- | -------- | ---------- | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| XcodeGen installed (Homebrew)         | External | None       | Open                                                                                                 | Low -- standard iOS toolchain                            |
| Xcode 26 + iOS 26 simulator installed | External | None       | Open                                                                                                 | Medium -- Xcode 26 is required; verify before S5         |
| Locked brand mark PNGs at `assets/`   | External | None       | Resolved -- files exist at `assets/logo-light.png`, `assets/logo-dark.png`, `assets/logo-tinted.png` | Low                                                      |
| PH-0-E2 (Colors.xcassets populated)   | FS       | PH-0-E2    | Open                                                                                                 | Low -- S5 build verification must run after E2 completes |

## Assumptions

- XcodeGen is available via `xcodegen` on PATH or at `/opt/homebrew/bin/xcodegen`.
- Xcode 26 is the active Xcode installation (`xcode-select -p` points to Xcode 26).
- The iOS 26 simulator for `iPhone 16 Pro` is installed and available to `xcrun simctl`.
- The cadence-xcode-project skill §2 project.yml structure is final -- no deviations without an explicit spec update from the designer or engineer.
- `SWIFT_VERSION: "5.0"` is correct for the Swift version bundled with Xcode 26. Verify against `swift --version` before locking.
- The `assets/` brand mark PNGs are the final locked assets (Design Spec v1.1 §0 confirms this).

## Risks

| Risk                                                                    | Likelihood | Impact | Mitigation                                                                                                                                                                                               |
| ----------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Xcode 26 simulator unavailable on CI runner at Phase 0                  | Medium     | High   | Phase 0 build verification runs locally; CI skeleton (E3) can use `macos-latest` until a pinned macOS/Xcode 26 runner tag is confirmed available                                                         |
| XcodeGen version incompatibility with iOS 26 project format             | Low        | Medium | Pin XcodeGen version in a `.tool-versions` or engineering runbook entry; test with current Homebrew release before committing                                                                            |
| `CadenceTests` target fails to build if no source files exist in target | Low        | Medium | Include `CadenceTests/CadenceTests.swift` with a minimal `XCTestCase` stub so the target always has at least one compilable source file                                                                  |
| `protect-pbxproj.sh` hook fires during XcodeGen invocation              | Low        | Low    | XcodeGen writes to `.pbxproj` via its own file handle, not through Claude's Write/Edit tools. The hook only fires on Claude tool use. If the hook fires incorrectly, inspect the hook input filter logic |

---

## Stories

### S1: Author project.yml with Cadence and CadenceTests targets

**Story ID:** PH-0-E1-S1
**Points:** 3

Author the complete `project.yml` file at the repo root per cadence-xcode-project §2. The file must define both the `Cadence` application target and the `CadenceTests` unit test target with all required build settings. This is the spec file from which `Cadence.xcodeproj` is generated -- every structural decision made here propagates to all subsequent phases.

**Acceptance Criteria:**

- [ ] `project.yml` exists at the repository root
- [ ] `xcodegen generate --spec project.yml --dry-run` exits 0 with no errors
- [ ] `project.yml` contains `name: Cadence` at the top level
- [ ] `options.deploymentTarget.iOS` is `"26.0"`
- [ ] `options.createIntermediateGroups` is `true`
- [ ] `options.groupSortPosition` is `bottom`
- [ ] `targets.Cadence.type` is `application`
- [ ] `targets.Cadence.platform` is `iOS`
- [ ] `targets.Cadence.settings.base.PRODUCT_BUNDLE_IDENTIFIER` is `"com.cadence.tracker"`
- [ ] `targets.Cadence.settings.base.INFOPLIST_FILE` is `"Cadence/App/Info.plist"`
- [ ] `targets.Cadence.settings.base.ASSETCATALOG_COMPILER_APPICON_NAME` is `"AppIcon"`
- [ ] `targets.CadenceTests` is present with `type: bundle.unit-test`
- [ ] `targets.CadenceTests` declares `Cadence` as its host app via `settings.base.TEST_HOST` or XcodeGen's `dependencies` field
- [ ] `settings.base.SWIFT_VERSION` is `"5.0"` in the top-level or per-target settings
- [ ] `settings.base.IPHONEOS_DEPLOYMENT_TARGET` is `"26.0"` in top-level base settings
- [ ] `project.yml` includes a top-level `schemes:` section declaring `Cadence` with `shared: true` and test targets listing `CadenceTests` in the test action
- [ ] No `.pbxproj` file exists at the time this story's commit is made (generation happens in S4)

**Dependencies:** None

**Notes:** `CadenceUITests` is intentionally absent -- it is introduced in a later phase when UI tests are first authored. The cadence-xcode-project skill's note about "no test targets" refers to extension and framework targets, not unit test targets. PHASES.md explicitly lists "CadenceTests target" in the Phase 0 in-scope column and that overrides the skill's advisory note.

XcodeGen does not create shared schemes by default. A scheme that is not declared with `shared: true` is a local scheme -- it exists only on the machine that generated it and is invisible to `xcodebuild -list` on any other machine, including CI runners. Without `shared: true`, the CI `build` job in E3 will fail with "xcodebuild: error: The project 'Cadence' does not contain a scheme named 'Cadence'." The `schemes:` block must be present in `project.yml` before the first `xcodegen generate` run.

---

### S2: Create Cadence/ source directory structure and entry-point Swift files

**Story ID:** PH-0-E1-S2
**Points:** 2

Create the complete `Cadence/` source directory hierarchy per cadence-xcode-project §4 and write the minimal Swift entry-point files required for the `Cadence` target to compile. No feature code is introduced -- only the skeleton that XcodeGen's `createIntermediateGroups: true` picks up automatically.

**Acceptance Criteria:**

- [ ] `Cadence/App/CadenceApp.swift` exists and contains an `@main` struct conforming to `App` with `WindowGroup { ContentView() }` as its scene body -- no other code
- [ ] `Cadence/App/Info.plist` exists with `CFBundleDisplayName: Cadence`, `UILaunchScreen` key present, and `UISupportedInterfaceOrientations` containing at least `UIInterfaceOrientationPortrait`
- [ ] `Cadence/Views/Shared/ContentView.swift` exists and contains only `struct ContentView: View { var body: some View { Text("Cadence") } }` -- no imports beyond SwiftUI, no feature logic
- [ ] The following directories exist (each with a `.gitkeep` if empty): `Cadence/Views/Splash/`, `Cadence/Views/Auth/`, `Cadence/Views/Tracker/`, `Cadence/Views/Partner/`, `Cadence/Views/Log/`, `Cadence/ViewModels/`, `Cadence/Models/`, `Cadence/Services/`, `Cadence/Resources/`
- [ ] `CadenceTests/CadenceTests.swift` exists and contains a single `XCTestCase` subclass with an empty `testPlaceholder()` method that contains only `// intentionally empty`
- [ ] No Swift file in `Cadence/` contains `print()`, `debugPrint()`, force unwraps (`!`), or hardcoded hex string literals

**Dependencies:** PH-0-E1-S1

**Notes:** The `.gitkeep` placeholder ensures empty directories are tracked by git. Remove `.gitkeep` files when real source files are added to the directory in later phases. The `testPlaceholder()` comment `// intentionally empty` is the only comment allowed in the test stub -- it explains the intent without restating the code.

---

### S3: Create Images.xcassets with App Icon variants

**Story ID:** PH-0-E1-S3
**Points:** 3

Create `Cadence/Resources/Images.xcassets` and populate `AppIcon.appiconset` with the three locked brand mark PNGs from `assets/`, per cadence-xcode-project §6.3. This makes the App Icon resolvable at build time and prevents asset catalog warnings from blocking CI under strict settings.

**Acceptance Criteria:**

- [ ] `Cadence/Resources/Images.xcassets/Contents.json` exists with `{"info": {"author": "xcode", "version": 1}}`
- [ ] `Cadence/Resources/Images.xcassets/AppIcon.appiconset/` directory exists
- [ ] `Cadence/Resources/Images.xcassets/AppIcon.appiconset/Contents.json` contains exactly three image entries: one with no `appearances` key (light -- `logo-light.png`), one with `appearances: [{appearance: luminosity, value: dark}]` (`logo-dark.png`), one with `appearances: [{appearance: luminosity, value: tinted}]` (`logo-tinted.png`)
- [ ] All three image entries have `idiom: "universal"`, `platform: "ios"`, `size: "1024x1024"` and a `filename` key referencing the correct PNG filename
- [ ] `logo-light.png`, `logo-dark.png`, `logo-tinted.png` are present in `Cadence/Resources/Images.xcassets/AppIcon.appiconset/`
- [ ] No color assets exist in `Images.xcassets` (color assets belong in `Colors.xcassets` per cadence-xcode-project §5)
- [ ] `xcodebuild build` does not emit `ASSETCATALOG_COMPILER_ERROR` or `assetcatalog` warnings after this story is complete

**Dependencies:** PH-0-E1-S1

**Notes:** Copy the PNGs from `assets/` -- do not move them. The `assets/` directory may serve as a source-of-truth reference for brand marks in documentation contexts. The three PNG filenames in `Contents.json` must exactly match the filenames present in the `appiconset/` directory, including case. `logo-light.png`, not `Logo-Light.png`.

---

### S4: Run XcodeGen and commit generated Cadence.xcodeproj

**Story ID:** PH-0-E1-S4
**Points:** 1

Execute `xcodegen generate --spec project.yml`, verify the generated `Cadence.xcodeproj` is valid and contains both target schemes, then commit `project.yml` and `Cadence.xcodeproj` together in a single `chore(project):` commit per cadence-git rules.

**Acceptance Criteria:**

- [ ] `xcodegen generate --spec project.yml` exits 0 with no errors or warnings
- [ ] `Cadence.xcodeproj/project.pbxproj` exists and is non-empty after generation
- [ ] `xcodebuild -list -project Cadence.xcodeproj` output includes both `Cadence` and `CadenceTests` in the Schemes section
- [ ] The git commit that introduces `Cadence.xcodeproj` also includes the current `project.yml` in the same commit (never committed separately)
- [ ] The commit message matches the pattern `chore(project): generate Cadence.xcodeproj from project.yml` or equivalent Conventional Commits format
- [ ] The `pbxproj-isolated-commit.sh` hook does not warn about mixed staging

**Dependencies:** PH-0-E1-S1, PH-0-E1-S2, PH-0-E1-S3

**Notes:** The `protect-pbxproj.sh` hook blocks direct `.pbxproj` edits via Claude's Write/Edit tools. XcodeGen writes to `.pbxproj` via its own file handle, so the hook will not fire during `xcodegen generate`. If the hook fires unexpectedly, the Write/Edit tool is being used to modify `.pbxproj` directly -- stop and investigate.

---

### S5: Verify xcodebuild compiles clean with warnings-as-errors

**Story ID:** PH-0-E1-S5
**Points:** 2

Run `xcodebuild build` against the `Cadence` scheme and `xcodebuild build-for-testing` against `CadenceTests` on the `iPhone 16 Pro (iOS 26.0)` simulator, both with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, establishing the Phase 0 build-passes baseline. This story runs after PH-0-E2 is complete so that `Colors.xcassets` is present and the asset catalog compiles without missing-asset warnings.

**Acceptance Criteria:**

- [ ] `set -o pipefail && xcodebuild -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build | xcbeautify` exits 0
- [ ] The build output contains zero Swift compiler warnings
- [ ] The build output contains no `assetcatalog` errors or warnings about missing color assets
- [ ] `set -o pipefail && xcodebuild -scheme CadenceTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build-for-testing | xcbeautify` exits 0
- [ ] The `build-health-check.sh` hook reports `PASSED` on the next Claude Code SessionStart after this story is complete
- [ ] `scripts/protocol-zero.sh` exits 0 on the full source tree (no AI attribution artifacts in any committed Swift file)
- [ ] `scripts/check-em-dashes.sh` exits 0 on the full source tree

**Dependencies:** PH-0-E1-S4, PH-0-E2 (Colors.xcassets must be populated before this build verification runs)

**Notes:** `xcbeautify` must be installed (`brew install xcbeautify`). If `xcbeautify` is not available, run the raw `xcodebuild` command without piping and inspect the output directly. The `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` flag must not be removed to work around a warning -- fix the underlying warning instead.

---

## Story Point Reference

| Points | Meaning                                                                              |
| ------ | ------------------------------------------------------------------------------------ |
| 1      | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour.         |
| 2      | Small. One component or function, minimal unknowns. Half a day.                      |
| 3      | Medium. Multiple files, some integration. One day.                                   |
| 5      | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8      | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days.      |
| 13     | Very large. Should rarely appear. If it does, consider splitting the story. A week.  |

## Definition of Done

- [ ] All five stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] `Cadence.xcodeproj` is regenerated from `project.yml` -- no manual `.pbxproj` edits present
- [ ] Phase objective is advanced: a valid, buildable Xcode project exists with the correct target structure
- [ ] cadence-xcode-project skill constraints satisfied: project.yml structure, source group hierarchy, asset catalog separation, Contents.json format
- [ ] cadence-build skill constraints satisfied: `xcodebuild` command uses correct scheme, destination, and `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] cadence-git skill constraints satisfied: `project.yml` and `Cadence.xcodeproj` committed together in isolated `chore(project):` commit
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No dead code, stubs, or placeholder comments in any committed Swift file (ContentView.swift placeholder Text view is functional scaffolding, not a stub)
- [ ] Source document alignment verified: project.yml deployment target, bundle identifier, and source structure match Design Spec v1.1 §2 and cadence-xcode-project skill

## Source References

- PHASES.md: Phase 0 -- Project Foundation (in-scope: XcodeGen project.yml with Cadence target and CadenceTests target)
- Design Spec v1.1 §2 (platform and framework assumptions: iOS 26, SwiftUI, no UIKit)
- Design Spec v1.1 §0 (brand asset lock: logo-light.png, logo-dark.png, logo-tinted.png)
- cadence-xcode-project skill §2 (required project.yml structure)
- cadence-xcode-project skill §4 (source group conventions)
- cadence-xcode-project skill §5 (asset catalog governance: two catalogs, Colors vs Images)
- cadence-xcode-project skill §6.3 (App Icon appiconset Contents.json format)
- cadence-build skill (xcodebuild command structure, xcbeautify pipe, SWIFT_TREAT_WARNINGS_AS_ERRORS)
- cadence-git skill (chore(project): commit isolation rule for .xcodeproj regenerations)
