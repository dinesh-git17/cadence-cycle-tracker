# Code Quality Enforcement

**Epic ID:** PH-0-E4
**Phase:** 0 -- Project Foundation
**Estimated Size:** S
**Status:** Draft

---

## Objective

Complete the code quality enforcement chain for Phase 0 by authoring `.swiftlint.yml`, validating that `scripts/protocol-zero.sh` and `scripts/check-em-dashes.sh` are executable and scan-correct, confirming all `.claude/hooks/` scripts are executable with valid response formats, and running an end-to-end enforcement pass on the Phase 0 codebase to establish a clean baseline. After this epic, every future commit is enforced by the full chain before it can be declared done.

## Problem / Context

Three of the four enforcement artifacts for Phase 0 already exist: `scripts/protocol-zero.sh`, `scripts/check-em-dashes.sh`, and all hooks in `.claude/hooks/`. What is missing is `.swiftlint.yml`, which the `swiftlint-on-edit.sh` hook and the Fastlane `lint` lane both require. Without it, SwiftLint operates with implicit defaults that may not match the project's source layout, exclude the generated `.xcodeproj`, or apply the correct reporter format for CI.

The enforcement scripts were committed as part of the initial project setup. This epic does not rewrite them -- it validates that they are correctly configured for the Phase 0 project state and establishes a known-good baseline (all scripts exit 0) that every subsequent phase can verify regression against.

**Source references that define scope:**

- CLAUDE.md §3 Protocol Zero enforcement contract and §5 (workflow: protocol-zero.sh and check-em-dashes.sh required before declaring any task complete)
- cadence-ci skill §2 (`.swiftlint.yml` must exist at repo root; must include `Cadence/`, exclude `Cadence.xcodeproj`)
- PHASES.md Phase 0 in-scope: "SwiftLint configuration; Protocol Zero scan script; em-dash scan script"

## Scope

### In Scope

- `.swiftlint.yml` at repo root with `included: [Cadence]`, `excluded: [Cadence.xcodeproj]`, `reporter: "github-actions-logging"`, and a minimum viable rule configuration appropriate for an empty SwiftUI scaffold
- Verification that `scripts/protocol-zero.sh` has execute permission (`chmod 755`) and exits 0 when run against the Phase 0 source tree
- Verification that `scripts/check-em-dashes.sh` has execute permission (`chmod 755`) and exits 0 when run against the Phase 0 source tree
- Verification that all 7 hook scripts in `.claude/hooks/` have execute permission
- Verification that PostToolUse hook scripts that emit JSON block responses use valid JSON format that Claude Code accepts
- End-to-end smoke test: `.swiftlint.yml` produces zero violations on the Phase 0 codebase, `protocol-zero.sh` exits 0, `check-em-dashes.sh` exits 0

### Out of Scope

- Authoring new enforcement scripts (both scan scripts already exist)
- Adding SwiftLint rules for feature code patterns not yet in the codebase (e.g., rules about `@Observable`, ForEach identity, or AnyView -- these are validated when those patterns first appear in Phase 2+)
- Modifying `.claude/hooks/` scripts (they are correct as committed; this epic validates, not rewrites)
- Setting up SwiftLint as a pre-commit git hook (the `swiftlint-on-edit.sh` Claude Code hook covers in-session enforcement)

## Dependencies

| Dependency                                          | Type | Phase/Epic | Status | Risk                                                                                                                                                |
| --------------------------------------------------- | ---- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| PH-0-E1 (Cadence/ source tree and .xcodeproj exist) | FS   | PH-0-E1    | Open   | Medium -- .swiftlint.yml `included: Cadence` and `excluded: Cadence.xcodeproj` require both paths to exist for the lint invocation to be meaningful |
| PH-0-E3-S3 (Fastlane lint lane exists)              | SS   | PH-0-E3-S3 | Open   | Low -- S5 of this epic validates the full Fastlane lint lane; S3 in E3 must be complete first                                                       |

## Assumptions

- SwiftLint is installed locally (`swiftlint version` exits 0). The CI job installs it via Homebrew; local development assumes Homebrew installation.
- The Phase 0 `Cadence/` source tree contains only `CadenceApp.swift`, `ContentView.swift`, and the `CadenceTests.swift` test stub -- SwiftLint will find no real violations on this minimal codebase.
- The existing hook scripts in `.claude/hooks/` are functionally correct and require no content changes -- only permission verification.
- `.claude/` is excluded from `protocol-zero.sh` scans per the CLAUDE.md Protocol Zero hard-exempt paths list. Running the scan on `.claude/` would produce false positives against the skill and hook documentation.

## Risks

| Risk                                                                                                                              | Likelihood | Impact | Mitigation                                                                                                                                                                          |
| --------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.swiftlint.yml` missing `excluded: Cadence.xcodeproj` causes SwiftLint to scan generated code and produce hundreds of violations | Medium     | High   | Always include `Cadence.xcodeproj` in the `excluded` list. Validate by running `swiftlint lint --strict` locally before committing.                                                 |
| Hook script missing execute permission causes silent failures in Claude Code sessions                                             | Low        | Medium | Run `ls -la .claude/hooks/` and verify all 7 scripts show `-rwxr-xr-x`. Run `chmod 755 .claude/hooks/*.sh` if any are missing execute permission.                                   |
| `protocol-zero.sh` exits 1 on Phase 0 source due to an existing violation                                                         | Low        | High   | If it fails, the violation must be fixed before Phase 0 is declared done -- do not bypass or add the file to the exempt list unless the CLAUDE.md hard-exempt path rules permit it. |

---

## Stories

### S1: Author .swiftlint.yml with Cadence rule configuration

**Story ID:** PH-0-E4-S1
**Points:** 2

Author `.swiftlint.yml` at the repository root. The configuration must include the `Cadence/` source directory, exclude the generated project file, set the CI reporter format, and disable or configure any rules that conflict with the Phase 0 minimal codebase (e.g., `file_length`, `type_body_length` rules that would fire on a nearly-empty file are not a concern at this stage -- no overrides needed unless a default rule fails on the existing stub files).

**Acceptance Criteria:**

- [ ] `.swiftlint.yml` exists at repo root
- [ ] `included` key lists `Cadence` as the only included path
- [ ] `excluded` key includes `Cadence.xcodeproj`
- [ ] `reporter` key is `"github-actions-logging"`
- [ ] `swiftlint lint --strict --config .swiftlint.yml` exits 0 on the Phase 0 `Cadence/` source tree (no violations)
- [ ] `swiftlint lint --strict --config .swiftlint.yml` does not scan any file inside `Cadence.xcodeproj/` (verified by adding a deliberate violation inside a `.pbxproj` comment and confirming no violation is reported -- then revert the deliberate violation)
- [ ] `bundle exec fastlane lint` exits 0 (Fastlane lint lane uses this config file)

**Dependencies:** PH-0-E1 (Cadence/ source tree and Cadence.xcodeproj must exist)

**Notes:** The `reporter: "github-actions-logging"` setting is used by the CI `lint` job. It has no effect on local runs -- SwiftLint will still print to stdout locally. Do not add `reporter: "xcode"` as an additional override; a single reporter string is sufficient. If any default SwiftLint rule fires on `CadenceApp.swift` or `ContentView.swift`, add a targeted `disabled_rules` entry rather than a global rule override.

---

### S2: Validate protocol-zero.sh permissions and exit behavior

**Story ID:** PH-0-E4-S2
**Points:** 1

Verify that `scripts/protocol-zero.sh` is executable, produces the correct exit codes on clean and violating input, and correctly excludes the hard-exempt paths defined in CLAUDE.md Protocol Zero (docs/, .claude/, CLAUDE.md, \*.md files).

**Acceptance Criteria:**

- [ ] `ls -la scripts/protocol-zero.sh` shows execute permission for owner (`-rwxr-xr-x` or equivalent)
- [ ] `scripts/protocol-zero.sh` exits 0 when run against the Phase 0 codebase with no violations
- [ ] `scripts/protocol-zero.sh` exits 1 when run on a temporary file containing the string "generated by claude" (verify by creating a temp file, running the script, then deleting the temp file)
- [ ] `scripts/protocol-zero.sh` does not scan any file under `docs/` (confirmed: running the script with a prohibited pattern inside a docs file produces exit 0)
- [ ] `scripts/protocol-zero.sh` does not scan any file under `.claude/` (confirmed: running the script with a prohibited pattern inside a `.claude/` file produces exit 0)

**Dependencies:** PH-0-E1 (Phase 0 source tree must exist for a meaningful clean-state scan)

---

### S3: Validate check-em-dashes.sh permissions and exit behavior

**Story ID:** PH-0-E4-S3
**Points:** 1

Verify that `scripts/check-em-dashes.sh` is executable, produces the correct exit codes on clean and violating input, and correctly excludes the hard-exempt paths.

**Acceptance Criteria:**

- [ ] `ls -la scripts/check-em-dashes.sh` shows execute permission for owner
- [ ] `scripts/check-em-dashes.sh` exits 0 when run against the Phase 0 codebase with no violations
- [ ] `scripts/check-em-dashes.sh` exits 1 when run on a temporary Swift file containing a U+2014 em dash character (verify by creating a temp file with the character, running the script, then deleting the temp file)
- [ ] `scripts/check-em-dashes.sh` exits 1 when run on a temporary Swift file containing a U+2013 en dash character
- [ ] `scripts/check-em-dashes.sh` does not scan files under `docs/` or `.claude/` (consistent with protocol-zero.sh exempt path rules)

**Dependencies:** PH-0-E1

---

### S4: Validate .claude/hooks/ script permissions and response format

**Story ID:** PH-0-E4-S4
**Points:** 2

Verify that all 7 hook scripts in `.claude/hooks/` have execute permission and that the hooks using JSON block responses emit syntactically valid JSON. An incorrectly formatted hook response is silently ignored by Claude Code or causes unexpected behavior.

**Acceptance Criteria:**

- [ ] All 7 scripts in `.claude/hooks/` have execute permission: `build-health-check.sh`, `commit-message-lint.sh`, `no-hex-in-swift.sh`, `pbxproj-isolated-commit.sh`, `protect-pbxproj.sh`, `swiftlint-on-edit.sh`, `xcodegen-on-project-yml.sh`
- [ ] `protect-pbxproj.sh` (PreToolUse hard-block hook) emits valid JSON to stdout when triggered: `python3 -c "import json,sys; json.loads(sys.stdin.read())"` passes on the output -- specifically the `{"decision": "block", "reason": "..."}` format
- [ ] `swiftlint-on-edit.sh` exits 2 with stderr output when a `.swift` file containing a SwiftLint violation is passed as the file_path in the hook input -- and exits 0 with no output on a clean file
- [ ] `no-hex-in-swift.sh` exits 2 with stderr output when a `.swift` file containing a bare hex literal (e.g., `Color(hex: "#C07050")`) is passed -- and exits 0 on a clean file
- [ ] `build-health-check.sh` runs without error and produces output visible in Claude Code's session startup output

**Dependencies:** PH-0-E1 (hooks that scan `.swift` files need at least one `.swift` file to test against)

**Notes:** PostToolUse hooks that use the "warn" contract (exit 2 + stderr) do not require JSON -- they write the warning message to stderr directly. PreToolUse hooks that block (exit 2 + JSON to stdout) require the `{"decision": "block", "reason": "..."}` format. Verify the correct contract is used for each hook by reading the hook file header comment, which documents whether it uses the warn or block contract.

---

### S5: End-to-end enforcement smoke test on Phase 0 codebase

**Story ID:** PH-0-E4-S5
**Points:** 2

Run all enforcement tools against the complete Phase 0 codebase state to establish a clean baseline. This confirms the enforcement chain is functional before any feature work begins. If any tool exits non-zero, the failure must be investigated and resolved -- not bypassed.

**Acceptance Criteria:**

- [ ] `scripts/protocol-zero.sh` exits 0 on the full Phase 0 source tree
- [ ] `scripts/check-em-dashes.sh` exits 0 on the full Phase 0 source tree
- [ ] `swiftlint lint --strict --config .swiftlint.yml` exits 0 on the full `Cadence/` source tree
- [ ] `bundle exec fastlane lint` exits 0
- [ ] `bundle exec fastlane build` exits 0
- [ ] `xcodebuild -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build` exits 0 (run via xcbeautify pipe with set -o pipefail)
- [ ] None of the above commands are passed any `--skip`, `--only`, or `--except` flags that narrow their scope below the full Phase 0 codebase

**Dependencies:** PH-0-E4-S1, PH-0-E4-S2, PH-0-E4-S3, PH-0-E4-S4, PH-0-E1-S5 (build passes baseline), PH-0-E3-S3 (Fastlane lanes exist)

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
- [ ] `.swiftlint.yml` is present, includes `Cadence/`, excludes `Cadence.xcodeproj`, and lints clean with `--strict`
- [ ] `scripts/protocol-zero.sh` and `scripts/check-em-dashes.sh` are both executable and exit 0 on the Phase 0 codebase
- [ ] All 7 `.claude/hooks/` scripts are executable
- [ ] The full enforcement chain (`swiftlint lint`, `protocol-zero.sh`, `check-em-dashes.sh`, `fastlane lint`, `fastlane build`) exits 0 on Phase 0 state
- [ ] Phase objective is advanced: enforcement hooks are active and the Phase 0 codebase is clean against all enforced rules
- [ ] cadence-ci skill constraints satisfied: .swiftlint.yml includes correct paths and reporter format per §2
- [ ] CLAUDE.md §3 (Protocol Zero) satisfied: scan scripts are functional, clean-state baseline established
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] No dead code, stubs, or placeholder comments in `.swiftlint.yml`
- [ ] Source document alignment verified: .swiftlint.yml matches cadence-ci skill §2 requirements; hook contracts match CLAUDE.md §10 hook compliance table

## Source References

- PHASES.md: Phase 0 -- Project Foundation (in-scope: SwiftLint configuration, Protocol Zero scan script, em-dash scan script)
- CLAUDE.md §3 (Protocol Zero: prohibited patterns, enforcement scripts, hard-exempt paths)
- CLAUDE.md §5 (workflow: run protocol-zero.sh and check-em-dashes.sh before declaring any task complete)
- CLAUDE.md §10 (hook compliance table: all 7 hooks with their trigger events and expected Claude response)
- cadence-ci skill §2 (lint gate: .swiftlint.yml structure, included/excluded paths, reporter key, --strict flag)
