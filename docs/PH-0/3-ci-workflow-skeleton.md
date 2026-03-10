# CI Workflow Skeleton

**Epic ID:** PH-0-E3
**Phase:** 0 -- Project Foundation
**Estimated Size:** L
**Status:** Draft

---

## Objective

Establish the repository's CI infrastructure skeleton: a `.gitignore` that prevents build artifacts and secrets from reaching version control, a Fastlane installation with lint and build lanes, a GitHub Actions workflow file with lint and build jobs, and branch protection rules on `main`. After this epic, every commit to a PR targeting `main` is automatically linted and built before merge is permitted.

## Problem / Context

Without a `.gitignore`, `Cadence.xcodeproj/xcuserdata/`, `DerivedData/`, and `.env.secret` are one `git add .` away from polluting the repository permanently. Without branch protection, a direct push to `main` bypasses the entire review and CI gate chain.

The CI skeleton in Phase 0 is intentionally minimal: only `lint` and `build` jobs. Unit test and UI test jobs are added in later phases (Phase 3 and Phase 4 respectively) when the first tests are authored. The full 5-stage pipeline defined in the cadence-ci skill (`lint -> build -> unit-tests -> ui-tests -> testflight`) must not be partially implemented here -- introducing test job stubs that reference non-existent test targets will fail CI immediately and block all subsequent PR work.

The cadence-ci skill §1 defines the trigger rules, job dependency graph, and exact `xcodebuild` command structure. This epic must conform to those rules exactly for the two jobs it introduces.

**Source references that define scope:**

- cadence-ci skill §1 (pipeline overview, trigger rules)
- cadence-ci skill §2 (lint gate: SwiftLint `--strict`, `--reporter github-actions-logging`)
- cadence-ci skill §3 (build gate: scheme Cadence, `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, `set -o pipefail`, xcbeautify)
- cadence-ci skill §7 (required secrets inventory -- for documentation, not implementation at this stage)
- cadence-ci skill §8 (Fastlane configuration files: Gemfile, Appfile, Fastfile)
- PHASES.md Phase 0 in-scope: "CI GitHub Actions workflow skeleton (lint + build jobs); branch protection configuration; gitignore"

## Scope

### In Scope

- `.gitignore` at repo root covering: Xcode build artifacts, DerivedData, xcuserdata, `.DS_Store`, `.env.secret`, Fastlane test output, Bundler vendor directory, `.tool-versions` local overrides, `fastlane/report.xml`
- `Gemfile` at repo root with `fastlane` gem pinned
- `fastlane/Appfile` with `app_identifier "com.cadence.tracker"` and environment variable references for `APPLE_ID` and `APPLE_TEAM_ID`
- `fastlane/Fastfile` with two lanes: `lint` (SwiftLint `--strict --reporter github-actions-logging`) and `build` (xcodebuild Cadence scheme with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `xcbeautify`)
- `.github/workflows/ci.yml` with two jobs: `lint` (no `needs:`) and `build` (`needs: [lint]`), triggered on `push` to `main` and `pull_request` targeting `main`, runner `macos-latest`
- GitHub repository branch protection rule on `main`: require PR before merging, require status checks (`lint`, `build`) to pass before merging, require branches to be up to date before merging, disallow force push
- `fastlane/` directory added to `.gitignore` exclusion list for `test_output/` subdirectory only (the `Fastfile`, `Appfile`, and `Gemfile` are committed)

### Out of Scope

- `unit-tests`, `ui-tests`, and `testflight` CI jobs -- introduced in Phases 3 and 4 when tests are first authored
- Fastlane `test`, `ui_test`, and `beta` lanes -- same reason; stubs are not added now
- `APP_STORE_CONNECT_*`, `MATCH_*` secret configuration -- not needed for lint + build
- `match` certificate setup -- deferred to TestFlight phase
- macOS runner version pinning (`macos-15`, etc.) -- deferred until a stable Xcode 26 runner tag is confirmed available on GitHub-hosted runners
- `xcbeautify` installed via Bundler -- use Homebrew in the CI job step to keep the Gemfile minimal

## Dependencies

| Dependency                                           | Type     | Phase/Epic | Status | Risk                                                                                                                                   |
| ---------------------------------------------------- | -------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| PH-0-E1 (Cadence.xcodeproj and Cadence scheme exist) | FS       | PH-0-E1    | Open   | High -- the build job must reference a valid scheme; running ci.yml against a project that does not exist will fail immediately        |
| PH-0-E4-S1 (.swiftlint.yml exists)                   | FS       | PH-0-E4-S1 | Open   | High -- the lint job invokes SwiftLint; without .swiftlint.yml the run succeeds but the configuration is implicit and non-reproducible |
| GitHub repository created with remote configured     | External | None       | Open   | Low -- repository must exist on GitHub before branch protection rules can be applied                                                   |

## Assumptions

- The GitHub repository remote is configured (`git remote get-url origin` returns a valid URL) before S5 (branch protection) is executed.
- `macos-latest` on GitHub-hosted runners provides a macOS version with a Homebrew-available SwiftLint and xcbeautify. If `macos-latest` does not resolve to a macOS version compatible with Xcode 26, the runner tag must be updated before the first PR is opened.
- Fastlane is consumed as a gem via Bundler (`bundle exec fastlane`). The CI job uses `ruby/setup-ruby@v1` with `bundler-cache: true`.
- `APPLE_ID` and `APPLE_TEAM_ID` are not needed for lint + build jobs and are not set as GitHub secrets at this phase.
- Branch protection rules are applied manually via the GitHub UI or `gh` CLI after the repository is pushed. This story cannot be tested in a pre-push state.

## Risks

| Risk                                                                      | Likelihood | Impact | Mitigation                                                                                                                                                                                          |
| ------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `macos-latest` runner does not have Xcode 26 installed                    | High       | High   | Add an explicit `xcode-select` step in the `build` job to switch to Xcode 26 if multiple Xcode versions are installed on the runner. Document the expected Xcode version in a comment in ci.yml.    |
| SwiftLint not available via Homebrew on the CI runner image               | Low        | Medium | Add `brew install swiftlint` as a step in the `lint` job. Use `brew install --quiet` to reduce noise in CI logs.                                                                                    |
| xcbeautify not available on the CI runner                                 | Low        | Medium | Add `brew install xcbeautify` in the `build` job.                                                                                                                                                   |
| Branch protection rules block the initial infrastructure commit to `main` | Low        | High   | Push the initial project scaffold to `main` before enabling branch protection, or create the branch protection after the first direct push lands. Document the ordering in the engineering runbook. |

---

## Stories

### S1: Create .gitignore for iOS / Xcode / Fastlane project

**Story ID:** PH-0-E3-S1
**Points:** 1

Create `.gitignore` at the repository root covering all standard iOS/Xcode, Fastlane, Ruby/Bundler, and macOS artifacts that must not be committed. The file must cover `DerivedData`, `xcuserdata`, `.env.secret`, and `fastlane/test_output/` at minimum.

**Acceptance Criteria:**

- [ ] `.gitignore` exists at repo root
- [ ] `.gitignore` includes `DerivedData/`
- [ ] `.gitignore` includes `*.xcuserstate` and `xcuserdata/`
- [ ] `.gitignore` includes `.DS_Store`
- [ ] `.gitignore` includes `.env.secret` and `.env.local`
- [ ] `.gitignore` includes `fastlane/test_output/` and `fastlane/report.xml`
- [ ] `.gitignore` includes `vendor/bundle` (Bundler local install directory)
- [ ] `.gitignore` includes `*.ipa` and `*.dSYM.zip`
- [ ] `.gitignore` does NOT exclude `Cadence.xcodeproj` (the generated project file is committed per cadence-xcode-project rules)
- [ ] `git status` shows no untracked Xcode or macOS system files after the `.gitignore` is committed

**Dependencies:** None

---

### S2: Author Gemfile and install Fastlane

**Story ID:** PH-0-E3-S2
**Points:** 2

Create the `Gemfile` at the repository root with the `fastlane` gem and run `bundle install` to generate `Gemfile.lock`. The `Gemfile.lock` is committed so CI uses identical gem versions without network resolution.

**Acceptance Criteria:**

- [ ] `Gemfile` exists at repo root with `source "https://rubygems.org"` and `gem "fastlane"` (no version pin is required at skeleton stage -- pin after confirming a working version)
- [ ] `Gemfile.lock` exists at repo root and is committed (not in `.gitignore`)
- [ ] `bundle install` exits 0 on a clean Ruby environment using the committed `Gemfile.lock`
- [ ] `bundle exec fastlane --version` exits 0 and prints a version string
- [ ] `.bundle/` directory is excluded by `.gitignore` (the local Bundler config directory must not be committed)

**Dependencies:** PH-0-E3-S1 (.gitignore must be in place so `vendor/bundle/` is not inadvertently staged)

---

### S3: Author fastlane/Appfile and fastlane/Fastfile with lint and build lanes

**Story ID:** PH-0-E3-S3
**Points:** 3

Create the `fastlane/` directory, `fastlane/Appfile`, and `fastlane/Fastfile` with exactly two lanes: `lint` (SwiftLint with `--strict`) and `build` (xcodebuild Cadence scheme with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`). No stubs for future lanes are added.

**Acceptance Criteria:**

- [ ] `fastlane/Appfile` exists with `app_identifier "com.cadence.tracker"`, `apple_id ENV["APPLE_ID"]`, and `team_id ENV["APPLE_TEAM_ID"]`
- [ ] `fastlane/Fastfile` exists with a `lint` lane that runs `sh("swiftlint lint --strict --reporter github-actions-logging")`
- [ ] `fastlane/Fastfile` `build` lane runs `sh("set -o pipefail && xcodebuild -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build | xcbeautify --renderer github")`
- [ ] `fastlane/Fastfile` contains exactly two lanes (`lint` and `build`) -- no placeholder lanes for `test`, `ui_test`, or `beta`
- [ ] `bundle exec fastlane lint` exits 0 against the Phase 0 codebase (requires PH-0-E4-S1 `.swiftlint.yml` to be present)
- [ ] `bundle exec fastlane build` exits 0 against the Phase 0 codebase (requires PH-0-E1 build-passes baseline)
- [ ] `fastlane/test_output/` is excluded by `.gitignore`

**Dependencies:** PH-0-E3-S2, PH-0-E1 (Cadence scheme must exist for the build lane to pass)

**Notes:** The `--renderer github` flag on `xcbeautify` produces GitHub Actions-native annotations. It has no effect when run locally but does not cause errors either. The `set -o pipefail` before the xcodebuild pipe is required per cadence-ci §3 -- without it, xcodebuild failure is silently swallowed by xcbeautify and the Fastlane lane exits 0.

---

### S4: Author .github/workflows/ci.yml with lint and build jobs

**Story ID:** PH-0-E3-S4
**Points:** 3

Create `.github/workflows/ci.yml` with two jobs: `lint` (no `needs:`) and `build` (`needs: [lint]`). Both jobs install dependencies from the committed `Gemfile.lock` and invoke the corresponding Fastlane lanes. The workflow triggers on push to `main` and pull_request targeting `main`.

**Acceptance Criteria:**

- [ ] `.github/workflows/ci.yml` exists
- [ ] Workflow trigger includes `push: branches: [main]` and `pull_request: branches: [main]`
- [ ] `lint` job has no `needs:` declaration (it is the first gate)
- [ ] `lint` job uses `runs-on: macos-latest`
- [ ] `lint` job steps: `actions/checkout@v4`, `ruby/setup-ruby@v1` with `ruby-version: '3.3'` and `bundler-cache: true`, `brew install swiftlint`, `bundle exec fastlane lint`
- [ ] `build` job has `needs: [lint]`
- [ ] `build` job steps: `actions/checkout@v4`, `ruby/setup-ruby@v1` with `bundler-cache: true`, `brew install xcbeautify`, `bundle exec fastlane build`
- [ ] Workflow does not contain `unit-tests`, `ui-tests`, or `testflight` job definitions
- [ ] No job has `continue-on-error: true`
- [ ] The `build` job does not reference `MATCH_*` or `APP_STORE_CONNECT_*` secrets
- [ ] YAML is valid: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` exits 0

**Dependencies:** PH-0-E3-S3 (Fastlane lanes must exist before the workflow references them), PH-0-E3-S2 (Gemfile.lock must be committed for `bundler-cache: true` to function)

**Notes:** `bundler-cache: true` on `ruby/setup-ruby@v1` caches the installed gems between CI runs, reducing job startup time. It requires `Gemfile.lock` to be committed -- confirmed in S2. The `brew install swiftlint` and `brew install xcbeautify` steps are in each respective job rather than a shared setup job to keep jobs independently runnable if job-level re-runs are needed.

---

### S5: Configure GitHub repository branch protection for main

**Story ID:** PH-0-E3-S5
**Points:** 2

Apply branch protection rules to the `main` branch via the GitHub UI or `gh` CLI. After this story, direct pushes to `main` are blocked, status checks from the `lint` and `build` jobs are required to pass before a PR can merge, and force push to `main` is disallowed.

**Acceptance Criteria:**

- [ ] `main` branch has "Require a pull request before merging" enabled
- [ ] "Require status checks to pass before merging" is enabled with `lint` and `build` as required checks
- [ ] "Require branches to be up to date before merging" is enabled
- [ ] "Allow force pushes" is disabled for all users including administrators
- [ ] "Allow deletions" is disabled for `main`
- [ ] A test PR from a feature branch that introduces a SwiftLint violation causes the `lint` check to fail and GitHub blocks the merge button
- [ ] Direct `git push origin main` from a local branch is rejected by GitHub with a "protected branch" error

**Dependencies:** PH-0-E3-S4 (the `lint` and `build` check names used in branch protection must match the job names in ci.yml exactly)

**Notes:** GitHub requires at least one CI run to complete before a status check name can be added to the required checks list. Push ci.yml to a branch and open a PR against `main` to trigger the first run, confirm the check names appear in the "Add status checks" dropdown, then add them. If `macos-latest` does not have SwiftLint available via Homebrew and the first run fails, update the `brew install` step before finalizing branch protection on these check names.

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
- [ ] `.gitignore` prevents all Xcode, macOS, Fastlane, and secret artifacts from being tracked
- [ ] `bundle exec fastlane lint` exits 0 on the Phase 0 codebase
- [ ] `bundle exec fastlane build` exits 0 on the Phase 0 codebase
- [ ] GitHub Actions CI runs on every PR to `main` and both `lint` and `build` jobs pass
- [ ] Branch protection on `main` blocks direct pushes and requires `lint` + `build` to pass
- [ ] Phase objective is advanced: a passing CI lint + build check exists and is enforced on main
- [ ] cadence-ci skill constraints satisfied: `set -o pipefail` present, `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in build lane, `--strict` in lint lane, no test job stubs, `continue-on-error` absent
- [ ] cadence-git skill constraints satisfied: no mixed commits between ci.yml changes and Swift source changes
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] No dead code, stubs, or placeholder lanes in Fastfile
- [ ] Source document alignment verified: ci.yml trigger rules, job ordering, and xcodebuild flags match cadence-ci skill §1-3

## Source References

- PHASES.md: Phase 0 -- Project Foundation (in-scope: CI GitHub Actions workflow skeleton (lint + build jobs), branch protection configuration, gitignore)
- cadence-ci skill §1 (pipeline overview: five-stage order, trigger rules, runner)
- cadence-ci skill §2 (lint gate: SwiftLint --strict, --reporter github-actions-logging, .swiftlint.yml requirement)
- cadence-ci skill §3 (build gate: scheme Cadence, SWIFT_TREAT_WARNINGS_AS_ERRORS=YES, set -o pipefail, xcbeautify --renderer github)
- cadence-ci skill §7 (required secrets inventory: documented here for awareness, not implemented in Phase 0)
- cadence-ci skill §8 (Fastlane configuration files: Gemfile, Appfile, Fastfile structure)
- cadence-ci skill §10 (anti-pattern table: testflight job stubs, continue-on-error, missing set -o pipefail)
