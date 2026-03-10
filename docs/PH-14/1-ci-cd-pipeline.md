# CI/CD Pipeline Infrastructure

**Epic ID:** PH-14-E1
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** L
**Status:** Draft

---

## Objective

Author and validate the complete Cadence GitHub Actions pipeline: lint, build, unit-tests, ui-tests, and testflight. Deliver a working five-stage CI gate that enforces `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, runs SwiftLint with `--strict`, and promotes to TestFlight only on push to `main`. Every configuration file, lane definition, and secret slot must be production-ready before the first TestFlight build can be attempted.

## Problem / Context

No CI infrastructure exists as of Phase 0. The cadence-ci skill (SKILL.md §§1-11) defines the required five-stage pipeline, four Fastlane lanes (`lint`, `test`, `ui_test`, `beta`), six required secrets, and the exact simulator matrix. Without this epic, the Phase 14 completion standard -- "Buildable and passing CI, deployable via TestFlight" -- cannot be reached. Implementing the pipeline only when the TestFlight upload is needed produces a rushed, untested gate structure. This epic builds the pipeline incrementally, validates each stage independently, and confirms the full gate chain passes before Epic 6 (distribution) attempts an upload.

## Scope

### In Scope

- `.github/workflows/ci.yml` -- five-job dependency graph: `lint -> build -> unit-tests -> ui-tests -> testflight`
- Trigger configuration: `push` and `pull_request` on `main`; `testflight` job gated to `push` to `main` only
- `Gemfile` at repo root -- pins `fastlane ~> 2.227`, `xcbeautify`
- `fastlane/Appfile` -- `app_identifier "com.cadence.tracker"`, `apple_id` and `team_id` from `.env.secret`
- `fastlane/Fastfile` -- four required lanes: `lint`, `test`, `ui_test`, `beta` per cadence-ci skill §8
- `.swiftlint.yml` at repo root -- `included: [Cadence]`, `excluded: [Cadence.xcodeproj]`, `reporter: "github-actions-logging"`
- `.env.secret` file template (gitignored) -- `APPLE_ID`, `APPLE_TEAM_ID` slot definitions with placeholder comments
- `.gitignore` updates -- `fastlane/test_output/`, `.env.secret`
- Six required secrets documented in an internal engineering runbook entry (doc or PR description), not in tracked files
- Smoke test of all five stages on the `main` branch to confirm end-to-end gate chain passes before Epic 6

### Out of Scope

- Match certificates initialization and provisioning profile creation (Epic 6 -- PH-14-E6)
- App Store Connect app record creation (Epic 6 -- PH-14-E6)
- Actual TestFlight upload (Epic 6 -- PH-14-E6)
- Coverage reporting integration in CI (Epic 2 -- PH-14-E2)
- UI test in-memory-store configuration (Epic 3 -- PH-14-E3)
- Adding a secondary simulator (iPhone 16) to the matrix -- deferred until UI test coverage matures per cadence-ci skill §5

## Dependencies

| Dependency                                                                           | Type     | Phase/Epic                   | Status | Risk |
| ------------------------------------------------------------------------------------ | -------- | ---------------------------- | ------ | ---- |
| All prior phases complete (0-13): every Swift file, test target, and xcassets exists | FS       | PH-0 through PH-13           | Open   | Low  |
| `CadenceTests` and `CadenceUITests` targets registered in `project.yml`              | FS       | PH-0-E1 / cadence-testing §1 | Open   | Low  |
| GitHub repository exists and `main` branch is the protected default branch           | FS       | External (GitHub)            | Open   | Low  |
| Ruby 3.3 available on `macos-15` runner (confirmed via `ruby/setup-ruby@v1`)         | External | GitHub Actions runner        | Open   | Low  |

## Assumptions

- The `macos-15` runner is the target runner (Xcode 16 included); `macos-latest` is not used in the final pinned config.
- `xcbeautify` is managed via Bundler (Gemfile), not Homebrew, so the runner does not need a Homebrew install step for it.
- The `CadenceTests` scheme and `CadenceUITests` scheme are both registered in `project.yml` and appear in `xcodebuild -list` output.
- The six required secrets (cadence-ci skill §7) will be provisioned in GitHub repository Settings by Dinesh before the testflight job runs; this epic documents the required names but does not provision them.
- `fastlane/test_output/` directory is created at runtime by Fastlane; no pre-creation needed.

## Risks

| Risk                                                                                               | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `macos-15` runner does not have Xcode 26 installed; simulator `iPhone 16 Pro, OS=26.0` unavailable | Medium     | High   | Verify available Xcode version on `macos-15` runner before writing the destination string; use `xcrun simctl list` in a runner verification step. Adjust OS version in destination string if simulator runtime must be installed separately. |
| `set -o pipefail` not respected in certain shell configurations on macOS runners                   | Low        | Medium | Test the pipeline with an intentionally failing build step and confirm CI reports failure, not success.                                                                                                                                      |
| SwiftLint version incompatibility with the Cadence Swift version                                   | Low        | Medium | Pin SwiftLint in `.swiftlint.yml`; install via `brew install swiftlint@<version>` or add as a Swift Package in dev tools. Confirm locally before CI run.                                                                                     |
| Secret names in YAML differ from provisioned secret names in GitHub                                | Low        | High   | Document the exact secret slot names from cadence-ci skill §7 in the PR description. Verify against the actual provisioned names before first testflight run.                                                                                |

---

## Stories

### S1: GitHub Actions Workflow File

**Story ID:** PH-14-E1-S1
**Points:** 3

Author `.github/workflows/ci.yml` with the complete five-job dependency graph per cadence-ci skill §§1-6. Configure triggers, runner, job ordering, and environment variable scoping. The file must be syntactically valid YAML that GitHub Actions can parse without error on the first push.

**Acceptance Criteria:**

- [ ] `.github/workflows/ci.yml` exists at the repo root and is committed to the feature branch
- [ ] Five jobs defined: `lint`, `build`, `unit-tests`, `ui-tests`, `testflight` in that dependency order -- each job has a `needs:` pointing to the preceding job
- [ ] Trigger block is exactly: `push` to `main` and `pull_request` targeting `main`
- [ ] `testflight` job has `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`
- [ ] No job is marked `continue-on-error: true`
- [ ] Runner is `macos-15` (not `macos-latest`); all five jobs use the same runner value
- [ ] `secrets.*` references appear only in the `testflight` job `env:` block -- not in lint, build, or test jobs
- [ ] `actions/checkout@v4` is used in every job (not v3 or earlier)
- [ ] `ruby/setup-ruby@v1` with `ruby-version: "3.3"` and `bundler-cache: true` is present in `build` and `testflight` jobs
- [ ] `set -o pipefail` precedes every `xcodebuild` command that is piped to `xcbeautify`
- [ ] `scripts/protocol-zero.sh` exits 0 on the committed workflow file
- [ ] `scripts/check-em-dashes.sh` exits 0 on the committed workflow file

**Dependencies:** None
**Notes:** The simulator destination string for all xcodebuild commands is `platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0`. Verify this simulator runtime is available on `macos-15` before writing the final destination string. The `xcbeautify` renderer flag is `--renderer github` (not `--renderer default`) for GitHub Actions PR annotations.

---

### S2: SwiftLint Configuration

**Story ID:** PH-14-E1-S2
**Points:** 2

Author `.swiftlint.yml` at the repo root and confirm SwiftLint passes `--strict` against the full Cadence source tree. This file must gate lint in the Fastlane `lint` lane and the `lint` CI job.

**Acceptance Criteria:**

- [ ] `.swiftlint.yml` exists at the repo root; `included: - Cadence` and `excluded: - Cadence.xcodeproj` are present
- [ ] `reporter: "github-actions-logging"` is set
- [ ] Running `swiftlint lint --strict --config .swiftlint.yml` locally produces zero errors and zero warnings
- [ ] The `lint` Fastlane lane (`sh("swiftlint lint --strict --reporter github-actions-logging")`) completes with exit code 0 locally
- [ ] No SwiftLint rule suppressions (`// swiftlint:disable`) are added to any Swift source file as a workaround to pass this gate -- all violations are fixed in source

**Dependencies:** None
**Notes:** If any existing Swift file in `Cadence/` triggers a SwiftLint rule violation, fix it in this story rather than disabling the rule. The only acceptable suppressions are for rules that are incompatible with SwiftUI patterns and must be documented with a code comment explaining why.

---

### S3: Fastlane Configuration Files

**Story ID:** PH-14-E1-S3
**Points:** 5

Author the three Fastlane configuration files (`Gemfile`, `fastlane/Appfile`, `fastlane/Fastfile`) with all four required lanes. The `beta` lane placeholder is authored here but will not produce a successful upload until Epic 6 provisions code signing. The goal of this story is the lane structure, not a successful TestFlight upload.

**Acceptance Criteria:**

- [ ] `Gemfile` at repo root pins `gem "fastlane", "~> 2.227"` and includes `xcbeautify` as a gem dependency; `bundle install` succeeds with no resolution errors
- [ ] `fastlane/Appfile` contains `app_identifier "com.cadence.tracker"`, `apple_id ENV["APPLE_ID"]`, and `team_id ENV["APPLE_TEAM_ID"]`
- [ ] `fastlane/Fastfile` contains exactly four lanes: `lint`, `test`, `ui_test`, `beta` under `platform :ios do`
- [ ] `before_all` block calls `setup_ci if is_ci` -- this is the first action, not buried inside a lane
- [ ] `lint` lane: `sh("swiftlint lint --strict --reporter github-actions-logging")`
- [ ] `test` lane: `run_tests(scheme: "CadenceTests", devices: ["iPhone 16 Pro (26.0)"], only_testing: ["CadenceTests"], result_bundle: true, output_directory: "fastlane/test_output")`
- [ ] `ui_test` lane: `run_tests(scheme: "CadenceUITests", devices: ["iPhone 16 Pro (26.0)"], only_testing: ["CadenceUITests"], result_bundle: true, output_directory: "fastlane/test_output")`
- [ ] `beta` lane: contains `app_store_connect_api_key(...)`, `match(type: "appstore", readonly: true)`, `increment_build_number(build_number: latest_testflight_build_number + 1)`, `build_app(scheme: "Cadence", configuration: "Release", export_method: "app-store")`, `upload_to_testflight(skip_waiting_for_build_processing: true, groups: ["Internal Testers"])`
- [ ] `bundle exec fastlane lint` runs to completion locally (SwiftLint passes)
- [ ] `bundle exec fastlane test` runs to completion locally (unit tests pass; `fastlane/test_output/` is produced)

**Dependencies:** PH-14-E1-S2
**Notes:** The `beta` lane will fail at `match` if the certificates repo is not yet initialized -- this is expected and acceptable at this story's completion. The lane structure must be correct; the signing configuration is verified in Epic 6. Use `is_key_content_base64: true` in `app_store_connect_api_key` -- the `.p8` content stored as a secret is base64-encoded.

---

### S4: Secrets Inventory and Runbook Entry

**Story ID:** PH-14-E1-S4
**Points:** 2

Document all six required GitHub repository secrets from cadence-ci skill §7 in a PR description or internal engineering runbook. Verify the six secret slots are provisioned in GitHub repository Settings before the `testflight` job is triggered. No secrets are committed to tracked files.

**Acceptance Criteria:**

- [ ] The six required secret names are documented: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`, `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_TOKEN`
- [ ] The source and encoding requirements are documented: `APP_STORE_CONNECT_API_KEY_CONTENT` is the base64-encoded `.p8` file content (`base64 -i AuthKey_XXXX.p8 | tr -d '\n'`)
- [ ] Six secret slots are confirmed present in GitHub repository Settings under Actions secrets (verified by Dinesh before Epic 6 runs)
- [ ] `.env.secret` template file exists locally with placeholder comments for `APPLE_ID` and `APPLE_TEAM_ID`; it is listed in `.gitignore` and is not committed
- [ ] `fastlane/test_output/` is listed in `.gitignore`
- [ ] No secret value appears in any tracked file, PR body, or commit message

**Dependencies:** PH-14-E1-S3
**Notes:** The match certificates repo (`MATCH_GIT_URL`) must be a private GitHub repository. Document this requirement in the runbook. The `MATCH_GIT_TOKEN` is a GitHub Personal Access Token (classic or fine-grained) with read access to the match repo; it does not require write access in CI since `readonly: true`.

---

### S5: CI Lint and Build Gate Verification

**Story ID:** PH-14-E1-S5
**Points:** 3

Trigger the CI pipeline on the feature branch (via PR to `main`) and verify the `lint` and `build` jobs both pass. The `unit-tests`, `ui-tests`, and `testflight` jobs are expected to pass or fail deterministically based on their own scope -- their passing is owned by Epics 2, 3, and 6 respectively. This story's gate is the first two jobs.

**Acceptance Criteria:**

- [ ] A PR from the feature branch to `main` triggers the CI workflow; GitHub Actions shows the pipeline running
- [ ] `lint` job completes with exit code 0 -- SwiftLint `--strict` produces zero errors
- [ ] `build` job completes with exit code 0 -- `xcodebuild` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` compiles the `Cadence` scheme targeting `iPhone 16 Pro, OS=26.0` without warnings or errors
- [ ] `build` job failure produces a clear xcbeautify-formatted error annotation on the PR, not a raw `xcodebuild` log
- [ ] Each job's GitHub Actions log clearly shows the step names from `ci.yml`; no step names are omitted or substituted
- [ ] Lint and build gates are confirmed stable across two consecutive CI runs on the same commit (idempotent)

**Dependencies:** PH-14-E1-S1, PH-14-E1-S2, PH-14-E1-S3
**Notes:** If the `build` job fails due to a Xcode version mismatch on the `macos-15` runner, adjust the OS version in the destination string and re-run. Do not mark this story done until both jobs pass without manual intervention.

---

### S6: Unit Test and UI Test Gate Verification

**Story ID:** PH-14-E1-S6
**Points:** 2

Verify the `unit-tests` and `ui-tests` CI jobs pass after Epics 2 and 3 deliver their test suites. This story is a gate-verification story, not a test-authoring story. It confirms the full four-gate chain (`lint -> build -> unit-tests -> ui-tests`) passes on `main` before Epic 6 triggers the `testflight` job.

**Acceptance Criteria:**

- [ ] `unit-tests` job passes on CI: `xcodebuild test -scheme CadenceTests` exits 0, test results appear in `fastlane/test_output/`
- [ ] `ui-tests` job passes on CI: `xcodebuild test -scheme CadenceUITests` exits 0, all UI tests in `CadenceUITests` pass
- [ ] The `--in-memory-store` launch argument is confirmed active in the `ui-tests` job -- no live Supabase connection is made (verified by checking CI logs for absence of any Supabase host in network traffic, or by confirming the guard in the app entry point is triggered)
- [ ] `xcrun simctl erase` runs before the `ui-tests` job to reset simulator state from the `unit-tests` job
- [ ] After a squash merge to `main`, the `testflight` job appears in the GitHub Actions run with the correct `if:` condition and will execute if secrets are provisioned

**Dependencies:** PH-14-E1-S5, PH-14-E2 (unit tests exist), PH-14-E3 (UI tests exist)
**Notes:** This story cannot be marked complete until Epics 2 and 3 have delivered their test suites. The dependency is an SS (Start-to-Start) in the sense that CI infrastructure must exist (Epics 1 S1-S5) before Epic 2 and 3 can run their tests in CI.

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

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] `lint -> build -> unit-tests -> ui-tests` chain passes on CI for the `main` branch
- [ ] `testflight` job structure is in place and will trigger on the next push to `main` once secrets are provisioned and code signing is configured (Epic 6)
- [ ] Phase objective is advanced: CI infrastructure exists and all non-distribution gates are passing
- [ ] Applicable skill constraints satisfied: cadence-ci §§1-11 (full pipeline spec, gate-removal prevention, anti-pattern table), cadence-git (Conventional Commits, branch naming)
- [ ] `scripts/protocol-zero.sh` exits 0 on all generated files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all generated files
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments
- [ ] `.env.secret` is gitignored and not committed

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: CI/CD pipeline -- GitHub Actions, Fastlane, secrets, simulator matrix)
- cadence-ci skill §§1-11 (full pipeline spec, lane definitions, secret inventory, gate-removal prevention)
- Design Doc §1 (MVP targets a private beta via TestFlight; App Store submission is post-beta)
- MVP Spec Tech Stack table (Distribution beta: TestFlight)
- PHASES.md Completion Standard (Buildable and passing CI; Deployable via TestFlight to the known beta cohort)
