---
name: cadence-ci
description: "Enforces the Cadence GitHub Actions pipeline: lint → build → unit tests → UI tests → TestFlight on main. Knows the required secrets, Fastlane lane configuration, and simulator matrix. Flags any workflow change that removes a gate before TestFlight. Use this skill whenever writing, reviewing, or modifying any GitHub Actions workflow, Fastfile, Gemfile, Appfile, or CI/CD configuration for Cadence. Triggers on any question about pipeline jobs, job ordering, release gates, TestFlight promotion, required secrets, Fastlane lanes, simulator matrix, xcodebuild in CI, SwiftLint in CI, workflow triggers, branch protection, or any change to .github/workflows/ in this codebase."
---

# Cadence CI/CD

Authoritative governance for Cadence's GitHub Actions pipeline, Fastlane lane structure, secret inventory, simulator matrix, and TestFlight promotion rules. This skill owns the required job ordering, release gates, and pre-TestFlight quality bar. No workflow change that weakens a gate is a minor refactor — it is a release-governance violation.

**Repository state note:** No CI infrastructure exists as of the initial docs phase. This skill formalizes the required pipeline. When `.github/workflows/ci.yml` and `fastlane/Fastfile` are first created, they must conform exactly to this spec.

---

## 1. Pipeline Overview

The Cadence pipeline has **five ordered stages**. Every stage is a hard gate — no stage may begin before the previous stage exits with status 0.

```
lint → build → unit-tests → ui-tests → testflight (main only)
```

```yaml
# .github/workflows/ci.yml — job dependency graph
jobs:
  lint:
    # no needs — first stage
  build:
    needs: [lint]
  unit-tests:
    needs: [build]
  ui-tests:
    needs: [unit-tests]
  testflight:
    needs: [ui-tests]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

**Trigger rules:**

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

All PRs targeting `main` run lint through ui-tests. The `testflight` job runs only on direct push to `main` (i.e., after a squash merge). This prevents TestFlight promotion from feature branches.

**Runner:** `macos-latest` — but pin to a specific macOS version once Xcode 26 is available on a stable macOS runner tag (e.g., `macos-15`). Do not use `macos-latest` in a pinned production pipeline without documenting the macOS/Xcode version pairing.

---

## 2. Lint Gate

**Job name:** `lint`
**Purpose:** Enforce SwiftLint rules across all Swift source files before any build artifact is created.
**Failure behaviour:** Any SwiftLint error exits non-zero and blocks the `build` job.

```yaml
lint:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4

    - name: Install SwiftLint
      run: brew install swiftlint

    - name: Run SwiftLint
      run: swiftlint lint --strict --reporter github-actions-logging
```

**Fastlane lane:**

```ruby
lane :lint do
  sh("swiftlint lint --strict --reporter github-actions-logging")
end
```

**Rules:**
- `--strict` is required. SwiftLint warnings are lint errors in CI. Never run CI lint without `--strict`.
- `--reporter github-actions-logging` produces GitHub-native inline annotations on PRs.
- A `.swiftlint.yml` config file must exist at the repo root when this lane is active.
- SwiftLint is the sole lint tool for Swift sources. Do not add Periphery, SwiftFormat, or other tools without explicit CI spec update.

**A `.swiftlint.yml` must at minimum configure:**
```yaml
# .swiftlint.yml
included:
  - Cadence
excluded:
  - Cadence.xcodeproj
reporter: "github-actions-logging"
```

---

## 3. Build Gate

**Job name:** `build`
**Needs:** `lint`
**Purpose:** Confirm the app compiles clean with warnings-as-errors before running tests.

```yaml
build:
  runs-on: macos-latest
  needs: [lint]
  steps:
    - uses: actions/checkout@v4

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.3'
        bundler-cache: true

    - name: Build (warnings as errors)
      run: |
        set -o pipefail && \
          xcodebuild \
            -scheme Cadence \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
            SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
            build \
          | xcbeautify --renderer github
```

**Rules:**
- Scheme is `Cadence`. Never use an ad hoc scheme name — run `xcodebuild -list` to confirm after project initialization.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` is mandatory. A build that succeeds only with warnings is not a passing build gate.
- `set -o pipefail` is mandatory. Without it, `xcodebuild` failure is silently swallowed by the `xcbeautify` pipe.
- `xcbeautify --renderer github` produces GitHub Actions annotations. Install xcbeautify via Homebrew in the job or via Gemfile/Bundler if using as a Ruby gem.
- Build artifact is not explicitly archived here — it is rebuilt in the `testflight` job with `build_app`. This is intentional: the test jobs verify compilation; the release job creates the signed IPA.

---

## 4. Unit Test Gate

**Job name:** `unit-tests`
**Needs:** `build`
**Purpose:** Run all unit tests in `CadenceTests` before UI tests or release.

```yaml
unit-tests:
  runs-on: macos-latest
  needs: [build]
  steps:
    - uses: actions/checkout@v4

    - name: Boot simulator
      run: xcrun simctl boot "iPhone 16 Pro" || true

    - name: Run unit tests
      run: |
        set -o pipefail && \
          xcodebuild test \
            -scheme CadenceTests \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
            -only-testing:CadenceTests \
          | xcbeautify --renderer github
```

**Fastlane lane:**

```ruby
lane :test do
  run_tests(
    scheme: "CadenceTests",
    devices: ["iPhone 16 Pro (26.0)"],
    only_testing: ["CadenceTests"],
    result_bundle: true,
    output_directory: "fastlane/test_output"
  )
end
```

**Rules:**
- Test scheme is `CadenceTests`. Never run tests against the `Cadence` app scheme directly.
- `-only-testing:CadenceTests` scopes execution to unit tests. This prevents UI tests from running in this job.
- `|| true` on the `simctl boot` step is acceptable — it is idempotent (succeeds if already booted). Do not mark it `continue-on-error: true` because other failures in the step block would be silently ignored.
- Test results are written to `fastlane/test_output/`. This directory should be added to `.gitignore`.
- `result_bundle: true` produces an `.xcresult` bundle usable with `xccov` for coverage verification.

---

## 5. UI Test Gate

**Job name:** `ui-tests`
**Needs:** `unit-tests`
**Purpose:** Run all UI tests in `CadenceUITests` against a clean simulator state before TestFlight promotion.

```yaml
ui-tests:
  runs-on: macos-latest
  needs: [unit-tests]
  steps:
    - uses: actions/checkout@v4

    - name: Boot simulator
      run: xcrun simctl boot "iPhone 16 Pro" || true

    - name: Run UI tests
      run: |
        set -o pipefail && \
          xcodebuild test \
            -scheme CadenceUITests \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
            -only-testing:CadenceUITests \
          | xcbeautify --renderer github
```

**Simulator matrix** (enforce this exact matrix — do not drift):

| Device | OS | Purpose |
|---|---|---|
| iPhone 16 Pro | iOS 26.0 | Primary — matches design and development target |
| iPhone 16 | iOS 26.0 | Secondary — verifies non-Pro screen size rendering |

Add the secondary device when UI test coverage is mature enough to justify the CI time cost. Do not add devices speculatively. Do not use `id=booted` — always specify the device name explicitly.

**Rules:**
- The `--in-memory-store` launch argument must be injected by CI via the scheme's test action `Arguments Passed On Launch` or via `testPlan`. Never depend on previously persisted app state in CI UI tests. See `cadence-testing` skill §6 for the full isolation contract.
- UI tests must not require a live Supabase connection. Any test that depends on network state is a flaky test and a gate violation.
- Simulator state is reset between runs via `xcrun simctl erase` before the UI test job if persistent state from a previous run could affect results.

---

## 6. TestFlight Gate

**Job name:** `testflight`
**Needs:** `ui-tests`
**Condition:** `github.ref == 'refs/heads/main' && github.event_name == 'push'`
**Purpose:** Build the release IPA and upload to TestFlight for the internal beta group.

```yaml
testflight:
  runs-on: macos-latest
  needs: [ui-tests]
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  env:
    APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
    APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}
    APP_STORE_CONNECT_API_KEY_CONTENT: ${{ secrets.APP_STORE_CONNECT_API_KEY_CONTENT }}
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
    MATCH_GIT_TOKEN: ${{ secrets.MATCH_GIT_TOKEN }}
  steps:
    - uses: actions/checkout@v4

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.3'
        bundler-cache: true

    - name: Upload to TestFlight
      run: bundle exec fastlane beta
```

**Fastlane `beta` lane:**

```ruby
lane :beta do
  setup_ci                          # temporary keychain — required on CI, never skip

  app_store_connect_api_key(
    key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
    issuer_id: ENV["APP_STORE_CONNECT_API_ISSUER_ID"],
    key_content: ENV["APP_STORE_CONNECT_API_KEY_CONTENT"],
    is_key_content_base64: true
  )

  match(
    type: "appstore",
    app_identifier: "com.cadence.tracker",
    readonly: true                  # CI never creates new certs — readonly only
  )

  increment_build_number(
    build_number: latest_testflight_build_number + 1
  )

  build_app(
    scheme: "Cadence",
    configuration: "Release",
    export_method: "app-store"
  )

  upload_to_testflight(
    skip_waiting_for_build_processing: true,
    groups: ["Internal Testers"]
  )
end
```

**Rules:**
- `setup_ci` must be the first action in the `beta` lane. Without it, `match` freezes waiting for keychain interaction in CI.
- `match(readonly: true)` is mandatory in CI. Never create or update certificates from a pipeline run.
- `app_identifier` is `com.cadence.tracker`. Do not hardcode differently.
- `upload_to_testflight(groups: ["Internal Testers"])` limits distribution to the internal TestFlight group only during the beta phase per the PRD §1.
- The `testflight` job never runs on feature branches or PRs. Only `main` after a passing test suite promotes to TestFlight.

---

## 7. Required Secrets

All six secrets must be present in GitHub repository Settings → Secrets and Variables → Actions before the `testflight` job can run. Missing any secret produces a silent env variable absence that causes the lane to fail at the first Fastlane action that consumes it.

| Secret Name | Purpose | Where to obtain |
|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | ASC API key identifier | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_API_ISSUER_ID` | ASC team issuer ID | Same page — displayed next to key list |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `.p8` key file content, base64-encoded | Download once at key creation — cannot be re-downloaded |
| `MATCH_PASSWORD` | Passphrase for match certificate encryption | Set at `fastlane match init` time |
| `MATCH_GIT_URL` | HTTPS URL of private match certificates repo | The private Git repo where match stores encrypted certs |
| `MATCH_GIT_TOKEN` | GitHub PAT or deploy key for match repo read access | GitHub Settings → Developer Settings → Tokens |

**Rules:**
- `APP_STORE_CONNECT_API_KEY_CONTENT` must be base64-encoded before storing as a secret: `base64 -i AuthKey_XXXX.p8 | tr -d '\n'`
- The match certificates repo must be private. Never use a public repository for match.
- Secrets are accessed in the workflow via `${{ secrets.SECRET_NAME }}` and injected as `env:` on the `testflight` job only. Do not expose secrets to earlier jobs that do not require them.
- Document all six secrets in the repo's internal engineering runbook before the first TestFlight build. A missing secret discovered during release is a pipeline governance failure.

---

## 8. Fastlane Configuration Files

Three configuration files must exist under `fastlane/`:

**`fastlane/Gemfile`** (at repo root, not inside `fastlane/`):
```ruby
source "https://rubygems.org"
gem "fastlane"
gem "xcbeautify"   # if consumed via Bundler rather than Homebrew
```

**`fastlane/Appfile`:**
```ruby
app_identifier "com.cadence.tracker"
apple_id ENV["APPLE_ID"]            # loaded from .env.secret (gitignored)
team_id ENV["APPLE_TEAM_ID"]        # loaded from .env.secret (gitignored)
```

**`fastlane/Fastfile`** — contains the four required lanes:

| Lane | Called by | Purpose |
|---|---|---|
| `lint` | `ci.yml` lint job | SwiftLint --strict |
| `test` | `ci.yml` unit-tests job | `run_tests` for `CadenceTests` |
| `ui_test` | `ci.yml` ui-tests job | `run_tests` for `CadenceUITests` |
| `beta` | `ci.yml` testflight job | `match` + `build_app` + `upload_to_testflight` |

**`.env.secret`** (gitignored, never committed):
```
APPLE_ID=<developer@example.com>
APPLE_TEAM_ID=<TEAM_ID>
```

---

## 9. Gate-Removal Prevention

Any pull request that modifies `.github/workflows/ci.yml` or `fastlane/Fastfile` must be treated as a release-governance change and requires explicit review of the gate structure.

**A gate is removed or weakened when any of these occur:**

- A `needs:` dependency is deleted or changed to point to an earlier job
- A job's `if:` condition is loosened (e.g., removing `github.ref == 'refs/heads/main'`)
- A job is marked `continue-on-error: true` without documented justification
- A test stage is replaced by a build-only stage
- `--strict` is removed from the SwiftLint invocation
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` is removed from the build command
- `match(readonly: true)` is changed to `match(readonly: false)` without a documented cert rotation justification
- The `testflight` job gains a trigger that fires on non-`main` branches

**These changes are release-governance violations.** They must not be accepted as incidental workflow edits. Every such change requires a comment in the PR explaining why the gate was modified and who approved the change.

---

## 10. Anti-Pattern Table

| Anti-pattern | Verdict |
|---|---|
| `testflight` job has no `needs:` or depends only on `build` | Reject — tests must gate TestFlight |
| `if: always()` or no `if:` on `testflight` job | Reject — TestFlight must be `main`-push-only |
| SwiftLint run without `--strict` | Reject — warnings are errors in CI |
| `xcodebuild build` without `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` | Reject — build warnings are not a passing gate |
| `xcodebuild` without `set -o pipefail` before the pipe | Reject — silent build failure |
| Unit tests and UI tests collapsed into a single job | Reject — stages must be independently gated |
| `match(readonly: false)` in CI | Reject — CI never creates certs |
| `setup_ci` omitted from the `beta` lane | Reject — freezes CI waiting for keychain interaction |
| Secrets referenced in lint or build jobs | Reject — expose secrets only to jobs that require them |
| UI tests without `--in-memory-store` launch argument | Reject — non-deterministic state; cadence-testing §6 |
| Simulator specified as `id=booted` in CI commands | Reject — non-deterministic in multi-simulator CI environments |
| `testflight` job triggered on pull_request events | Reject — only `push` to `main` triggers release |
| Missing any of the 6 required secrets at release time | Reject — Fastlane lane fails; document before first run |
| Fastlane lanes not following the four-lane structure (lint / test / ui_test / beta) | Reject — lane structure must match this spec |
| `.env.secret` committed to version control | Reject — security violation |
| `app_identifier` value other than `com.cadence.tracker` | Reject — must match project.yml and provisioning profile |

---

## 11. Workflow Review Checklist

Before merging any change to `.github/workflows/ci.yml` or `fastlane/Fastfile`:

**Pipeline structure**
- [ ] Five-stage order maintained: lint → build → unit-tests → ui-tests → testflight
- [ ] Every stage has a `needs:` pointing to the previous stage
- [ ] `testflight` has `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`
- [ ] No job marked `continue-on-error: true` without documented justification

**Lint gate**
- [ ] SwiftLint runs with `--strict`
- [ ] `--reporter github-actions-logging` present
- [ ] `.swiftlint.yml` exists and includes `Cadence/`, excludes `Cadence.xcodeproj`

**Build gate**
- [ ] Scheme is `Cadence`
- [ ] `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` present
- [ ] `set -o pipefail` before `xcbeautify` pipe

**Unit test gate**
- [ ] Scheme is `CadenceTests`, `-only-testing:CadenceTests`
- [ ] Simulator is `iPhone 16 Pro, iOS 26.0` (or matrix-specified)
- [ ] Test results output to `fastlane/test_output/`

**UI test gate**
- [ ] Scheme is `CadenceUITests`, `-only-testing:CadenceUITests`
- [ ] `--in-memory-store` launch argument active
- [ ] No live Supabase dependency in any test

**TestFlight gate**
- [ ] `setup_ci` is first action in `beta` lane
- [ ] `match(readonly: true)` — never false in CI
- [ ] `app_identifier` is `com.cadence.tracker`
- [ ] All 6 secrets are set in repository settings
- [ ] `APP_STORE_CONNECT_API_KEY_CONTENT` is base64-encoded
- [ ] `upload_to_testflight(groups: ["Internal Testers"])` — internal only
- [ ] Match repo is private

**Security**
- [ ] Secrets exposed only to `testflight` job via `env:`
- [ ] No secrets in lint, build, or test job environments
- [ ] `.env.secret` is gitignored — never committed
