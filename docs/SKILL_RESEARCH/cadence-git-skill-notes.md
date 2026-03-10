# cadence-git Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-git/SKILL.md`
**Package path:** `.claude/skills/skill-creator/cadence-git.skill`

---

## Local Files Read

| File                                                 | Purpose                                                                                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `.claude/skills/skill-creator/SKILL.md`              | Skill structure conventions, YAML frontmatter, 500-line limit, description as primary trigger mechanism            |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schemas for evals — referenced for context                                                                    |
| `.claude/skills/cadence-xcode-project/SKILL.md`      | **Primary source** for XcodeGen workflow, `.pbxproj` as generated artifact, when `.xcodeproj` changes are expected |
| `docs/cadence-xcode-project-skill-notes.md`          | Confirmed skill creation pattern (manual + quick_validate + package_skill)                                         |
| `docs/cadence-build-skill-notes.md`                  | Confirmed no Xcode project exists yet; no CI config; no git hooks                                                  |
| `docs/Cadence-design-doc.md`                         | Product context: iOS 26, SwiftUI, TestFlight beta, no engineering/git workflow sections                            |
| `/Users/Dinesh/CLAUDE.md` §7.2–§7.3                  | **Primary source** for branch naming convention and Conventional Commits format + types                            |

---

## skill-creator Location Used

`.claude/skills/skill-creator/` (project-local install)

- `init_skill.py` is NOT present in this install — consistent with all prior Cadence skills
- Skill directory created manually
- Validated with `python -m scripts.quick_validate ../cadence-git` → `Skill is valid!`
- Packaged with `python -m scripts.package_skill ../cadence-git` → `cadence-git.skill`

---

## Official Anthropic Sources Used for Skill Standards

| Source                                                  | Used For                                                                                                                                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/skill-creator/SKILL.md` (project-local) | Canonical skill structure, YAML frontmatter format, 500-line limit, description as primary trigger mechanism, "pushy" description guidance, `skill-name/SKILL.md` anatomy |

The local skill-creator is the Anthropic-aligned governance standard for this project. No external Anthropic URLs required.

---

## Conventional Commits / Git Authoritative Sources Used

| Source                                                              | Used For                                                                                                                                        |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Conventional Commits v1.0.0 specification (conventionalcommits.org) | Formal spec structure: `<type>[optional scope]: <description>`, footer format, BREAKING CHANGE semantics                                        |
| `/Users/Dinesh/CLAUDE.md` §7.2–§7.3                                 | Cadence-inherited branch naming patterns, allowed Conventional Commits types (including `exp`), squash merge preference, `main` protection rule |
| `.claude/skills/cadence-xcode-project/SKILL.md` §1–§3               | XcodeGen-only workflow, `.pbxproj` as generated artifact semantics, commit atomicity for new file additions                                     |

---

## Cadence-Specific Git and Project-Regeneration Facts Extracted

### Repository State

- Pre-implementation as of March 7, 2026: no git history, no branches, no `.xcodeproj`, no Swift source files
- No project-local CLAUDE.md in `cadence-cycle-tracker/` — parent governance at `/Users/Dinesh/CLAUDE.md` applies in full
- No commitlint, no git hooks, no CI configuration present

### Branch Naming (inherited from `/Users/Dinesh/CLAUDE.md` §7.2)

Four defined patterns: `feat/`, `fix/`, `exp/`, and implicitly `chore/` (consistent with parent governance commit types — `chore` type is listed in §7.3 but `chore/<description>` branch pattern is a formalization; documented as such in skill)

### Commit Types (from `/Users/Dinesh/CLAUDE.md` §7.3)

Seven types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `exp`. `exp` is a Cadence parent-repo extension to standard Conventional Commits.

### XcodeGen Workflow (from `cadence-xcode-project` skill §1–§3)

- `project.yml` → `xcodegen generate` → `Cadence.xcodeproj` (generated artifact)
- `.pbxproj` is never edited directly; XcodeGen overwrites it on every run
- When adding a new Swift file: commit the new `.swift` file + `Cadence.xcodeproj` together (per cadence-xcode-project §3 "Anti-pattern — file added on disk without regenerating")
- When changing `project.yml` structure: isolated `chore(project):` commit

---

## Ambiguities Found and Resolutions

| Ambiguity                                                                                                                                    | Resolution                                                                                                                                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chore/<description>` branch pattern not explicitly listed in `/Users/Dinesh/CLAUDE.md` §7.2                                                 | Formalized as a Cadence extension: `chore` is a listed commit type in §7.3, so `chore/<description>` is the natural branch pattern for project-file and tooling work. Documented as a Cadence extension rather than pretending it was already written.                                                                                                                                                      |
| Tension between cadence-xcode-project §3 ("commit new .swift file + Cadence.xcodeproj together") and the requested `.pbxproj` isolation rule | Resolved by defining three explicit cases: (1) new Swift file — commit together with its `.xcodeproj` registration (inseparable artifact); (2) `project.yml` config change — isolated `chore(project):`; (3) standalone regeneration — isolated `chore(project):`. The isolation rule targets config-driven and standalone regenerations, not file-addition artifacts. This is consistent with both skills. |
| No git history to inspect for existing commit patterns                                                                                       | Repository is pre-implementation. No convention existed to preserve or conflict with. All rules formalized from written governance documents only.                                                                                                                                                                                                                                                          |
| `docs/<description>` branch pattern not defined in CLAUDE.md §7.2                                                                            | Not added — only the four explicitly defined patterns are encoded. `docs:` changes can land on `feat/` or `chore/` branches depending on context. Noted as a potential gap if pure-docs branches become common.                                                                                                                                                                                             |

---

## Key Enforcement Rules Encoded

1. **Conventional Commits format** — `type(scope): imperative description`; 7 allowed types; scope required for `feat:`/`fix:`
2. **Branch naming** — 4 patterns: `feat/`, `fix/`, `chore/`, `exp/` (hyphenated lowercase descriptions)
3. **`main` protection** — no direct commits; PR-only per parent governance §7.1
4. **`.pbxproj` isolation** — 3 defined cases; standalone regeneration and config-driven changes always isolated in `chore(project):` commits
5. **Mixed-commit prevention** — 3 commit categories (product logic / project structure / infrastructure) must not cross in a single commit
6. **Atomic commits** — split guidance for staging; do-not-split guidance for inseparable pairs
7. **PR title = squash commit message** — must conform to Conventional Commits; split before opening PR
8. **Anti-pattern table** — 13 specific rejection cases with corrections
9. **8-point commit checklist** — self-verification gate before every commit
