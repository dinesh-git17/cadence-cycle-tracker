# cadence-ci Skill — Creation Notes

**Date:** March 7, 2026
**Skill location:** `.claude/skills/cadence-ci/SKILL.md`
**Packaged to:** `.claude/skills/skill-creator/cadence-ci.skill`

---

## Local Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure conventions, YAML frontmatter, eval schema, packaging workflow |
| `.claude/skills/skill-creator/references/schemas.md` | evals.json / grading.json schemas |
| `docs/Cadence-design-doc.md` | PRD — TestFlight distribution target, tech stack, bundle ID context |
| `docs/Cadence_Design_Spec_v1.1.md` | Platform assumptions (iOS 26), SwiftUI-only stack |
| `.claude/skills/cadence-build/SKILL.md` | Schemes (`Cadence`, `CadenceTests`), simulator (`iPhone 16 Pro, iOS 26.0`), `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, `xcbeautify --renderer github` |
| `.claude/skills/cadence-git/SKILL.md` | Branch protection (`main` protected, PR-only), branch naming conventions |
| `.claude/skills/cadence-xcode-project/SKILL.md` | Bundle identifier `com.cadence.tracker`, single-target structure |
| `.claude/skills/cadence-testing/SKILL.md` | Test targets (`CadenceTests`, `CadenceUITests`), `--in-memory-store` launch arg, no live Supabase in tests |
| `docs/cadence-build-skill-notes.md` | Confirmed: no existing CI infrastructure; all CI must be created from scratch |

---

## skill-creator Location

`.claude/skills/skill-creator/` — project-local install.

Process followed: skill-creator SKILL.md reviewed (prior session) → repo fully inspected → research completed → SKILL.md written → `evals/evals.json` created (3 cases) → `python -m scripts.package_skill` run and validated.

---

## Official Anthropic Sources Used (Skill Standards)

- Local `skill-creator/SKILL.md` (project-canonical authority)
- Local `skill-creator/references/schemas.md`
- `package_skill.py` run: `✅ Skill is valid!` → `✅ Successfully packaged`

---

## Authoritative Sources Used (GitHub Actions / Fastlane / Apple)

| Source | Used for |
|---|---|
| Official Fastlane docs (`docs.fastlane.tools`) | `match`, `setup_ci`, `app_store_connect_api_key`, `upload_to_testflight` action signatures and required parameters |
| Official Fastlane GitHub Actions guide | `ruby/setup-ruby@v1`, `bundler-cache: true`, env injection pattern |
| Bright Inventions 2025 tutorial (brightinventions.pl) | `match(readonly: true)` CI requirement; `setup_ci` keychain freeze issue; base64 encoding for `.p8` |
| Runway CI/CD guide (runway.team) | Lane structure: lint / test / beta pattern; job ordering |
| GitHub Actions official docs (github.com/marketplace) | `actions/checkout@v4`, `ruby/setup-ruby@v1`, `needs:` job dependency, `if:` condition syntax, secrets injection via `env:` |
| Polpiella.dev Fastlane ASC API guide | `app_store_connect_api_key` three-parameter structure; base64 encoding requirement |

---

## Cadence-Specific CI Facts Extracted

### Repository State
- **No `.github/workflows/`** — no CI workflows exist
- **No Fastfile, Gemfile, Appfile** — no Fastlane configuration exists
- **No `project.yml`** — XcodeGen spec not yet created
- **No Swift files** — fully pre-implementation repository

### Established Facts (from existing skills, not invented)

| Property | Value | Source |
|---|---|---|
| App scheme | `Cadence` | cadence-build §1 |
| Test scheme (unit) | `CadenceTests` | cadence-build §1, cadence-testing §1 |
| Test target (UI) | `CadenceUITests` | cadence-testing §1 |
| Bundle identifier | `com.cadence.tracker` | cadence-xcode-project §2 |
| Simulator | iPhone 16 Pro, iOS 26.0 | cadence-build §4 |
| Branch protection | `main` protected, all changes via PR | cadence-git §2 |
| Distribution target | TestFlight internal group | PRD §1, §4 |
| Warnings-as-errors flag | `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` | cadence-build §8 |
| xcbeautify renderer | `--renderer github` | cadence-build §5 |
| UI test isolation | `--in-memory-store` launch arg | cadence-testing §6 |
| No live Supabase in tests | Absolute rule | cadence-testing §9 |

### Derived / Formalized (not pre-existing in repo)

| Element | Derivation basis |
|---|---|
| `.github/workflows/ci.yml` | Standard GitHub Actions iOS convention; does not exist yet |
| `fastlane/Fastfile` with 4 lanes (lint, test, ui_test, beta) | Standard iOS Fastlane lane structure; derived from PRD TestFlight target + cadence-testing test targets |
| SwiftLint as lint tool | Industry standard iOS linting; no alternative configured |
| 6 required secrets | Derived from App Store Connect API key model + Fastlane match requirements |
| Simulator matrix (iPhone 16 Pro primary + iPhone 16 secondary) | iPhone 16 Pro from cadence-build; iPhone 16 added for screen-size breadth |
| `macos-latest` runner | Standard GitHub Actions iOS runner |

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|---|---|
| No `.github/workflows/` exists — pipeline structure is entirely hypothetical | Formalized from cadence-build established schemes + cadence-testing targets + Fastlane best practices. Documented as formalization, not pretending it pre-existed. |
| No Fastfile exists — lane names are not established | Derived four lanes (lint, test, ui_test, beta) from standard iOS CI pattern. Names chosen for clarity and convention. Documented as derived. |
| `CadenceUITests` scheme: may be separate from `CadenceTests` or combined under one scheme | Treated as separate, per cadence-testing §1 which establishes two distinct targets. Each has its own job in CI for independent gating. |
| iOS 26 / Xcode 26 runner availability: `macos-latest` may not yet include Xcode 26 toolchain | Noted in §1 — pin to specific macOS version once Xcode 26 is available on a stable runner tag. `macos-latest` is acceptable only until a pinned version is available. |
| `MATCH_GIT_TOKEN` vs deploy key for match repo access | Both patterns are valid; `MATCH_GIT_TOKEN` (GitHub PAT) chosen as the simpler option for documentation. Deploy key is equally acceptable and noted implicitly. |
| Whether `run_tests` Fastlane action or raw `xcodebuild` should be canonical in CI | Provided both: raw `xcodebuild` in GitHub Actions YAML for transparency; `run_tests` in Fastlane lane for when CI is Fastlane-driven. Both produce equivalent results. |

---

## Key Enforcement Rules Encoded in the Skill

1. **Five-stage ordering is immutable:** lint → build → unit-tests → ui-tests → testflight. Every stage uses `needs:` pointing to the prior stage.
2. **TestFlight is `main`-push-only:** `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`. PRs run all stages except testflight.
3. **SwiftLint with `--strict` is mandatory** — warnings are CI errors.
4. **`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` mandatory on build job** — build gate must catch warning-only failures.
5. **`set -o pipefail` mandatory before xcbeautify pipe** — prevents silent build failure swallowing.
6. **`match(readonly: true)` in CI** — CI never creates or rotates certificates.
7. **`setup_ci` is the first action in the `beta` lane** — prevents keychain freeze.
8. **All 6 secrets required and documented before first TestFlight run.**
9. **`APP_STORE_CONNECT_API_KEY_CONTENT` must be base64-encoded** — `.p8` content as raw bytes fails JSON encoding.
10. **`upload_to_testflight(groups: ["Internal Testers"])` — beta-only distribution per PRD.**
11. **Secrets exposed only to the `testflight` job** — lint/build/test jobs have no secret access.
12. **Gate-removal in any workflow PR is a release-governance violation** — requires explicit documented justification, not incidental acceptance.
13. **UI tests use `--in-memory-store`** — consistent with cadence-testing §6 isolation contract.
14. **Simulator specified by explicit device name** — never `id=booted` in CI (non-deterministic).
