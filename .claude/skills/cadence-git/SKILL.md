---
name: cadence-git
description: "Enforces Conventional Commits format, Cadence branch naming (feat/, fix/, chore/, exp/), and the strict .pbxproj isolation rule — standalone Cadence.xcodeproj regenerations are always their own isolated chore(project): commit and must never be bundled with Swift feature logic changes. Flags and prevents mixed commits that combine product code with generated project file churn. Use this skill whenever writing a commit message, naming a git branch, staging files for a commit, deciding whether to split a commit, reviewing a PR's commit history, or making any git workflow decision in the Cadence project. Triggers on any question about commit format, branch naming, .pbxproj commit isolation, atomic commits, mixed commits, git hygiene, PR title format, staging strategy, squash merge, or XcodeGen regeneration commit timing in this codebase."
---

# Cadence Git — Commit Hygiene and Branch Governance

**Authority:** This skill is the authoritative governance layer for all Git workflow decisions in the Cadence iOS project. It owns commit message format, branch naming discipline, and isolation rules for generated project files. All other Cadence skills defer to this one for source-control decisions.

**Source of authority:**
- Commit format and branch naming: `/Users/Dinesh/CLAUDE.md` §7.2–§7.3 (parent repo governance, inherited by Cadence — no project-local CLAUDE.md override exists)
- XcodeGen workflow and `.pbxproj` semantics: `cadence-xcode-project` skill §1–§3
- `.pbxproj` isolation rule: this skill (formalized from XcodeGen-only workflow contract)

---

## 1. Conventional Commits — Format

Every Cadence commit must conform to Conventional Commits v1.0.0 as interpreted by the parent governance.

**Required subject line format:**
```
<type>(<scope>): <imperative description>
```

**Optional multi-line format:**
```
<type>(<scope>): <imperative description>

<body — wrap at 72 chars, explain why not what>

<footer — BREAKING CHANGE: or issue references>
```

**Allowed types — no others are valid:**

| Type | Purpose |
|---|---|
| `feat` | New user-facing functionality |
| `fix` | Bug fix |
| `refactor` | Restructuring without behavior change |
| `test` | Test additions or modifications |
| `chore` | Config, tooling, build settings, project file generation |
| `docs` | Documentation changes |
| `exp` | Experimental or exploratory code |

**Scope — required for `feat:` and `fix:`, encouraged for all others:**

| Scope | Use for |
|---|---|
| `tracker` | Tracker-role views, Tracker ViewModels |
| `partner` | Partner-role views, Partner ViewModels |
| `log` | LogSheetView, log entry flow |
| `auth` | Auth flow, onboarding, role selection |
| `sync` | SyncCoordinator, Supabase write queue |
| `models` | SwiftData models, enums, value types, route enums |
| `services` | SupabaseClient, NWPathMonitor wrapper |
| `viewmodels` | @Observable ViewModels |
| `design` | Color tokens, typography, spacing, asset catalogs |
| `project` | XcodeGen spec, Cadence.xcodeproj, asset catalog structure |
| `build` | xcodebuild config, xcbeautify, build settings |
| `splash` | SplashView, CadenceMark |
| `navigation` | NavigationStack, TabView structure, deep links |
| `privacy` | isPrivate flag, share_* flags, RLS-adjacent logic |

**Description rules:**
- Imperative mood: "add", "fix", "remove", "update", "implement" — not "added", "fixes", "removing"
- No period at end of subject line
- Subject line (type + scope + description) under 72 characters
- Specific: "add LogSheetView medium detent" not "update log"

**Valid examples:**
```
feat(tracker): add TrackerHomeView with 5-tab NavigationStack
fix(auth): resolve Supabase session token refresh after backgrounding
chore(project): add Views/Log group to project.yml and regenerate
refactor(sync): extract SyncCoordinator flush into isolated method
docs(spec): add cadence-git governance skill notes
```

**Rejection criteria — flag immediately:**
- No type: `"update tracker home"` → reject
- Wrong mood: `"fixed the auth bug"` → reject; use `"fix(auth): resolve ..."`
- Vague subject: `"chore: stuff"`, `"fix: bug"`, `"feat: new feature"` → reject
- Type not in allowed set: `"update(tracker): ..."`, `"build: ..."` → `build` is not valid; use `chore`
- Scope is a filename: `"feat(TrackerHomeView.swift): ..."` → use concept scope

---

## 2. Branch Naming Convention

Branch naming is governed by `/Users/Dinesh/CLAUDE.md` §7.2. The four valid patterns are:

| Pattern | Purpose | Examples |
|---|---|---|
| `feat/<description>` | New feature work | `feat/tracker-home-view`, `feat/log-sheet-detents` |
| `fix/<description>` | Bug fixes | `fix/auth-token-refresh`, `fix/sync-offline-queue` |
| `chore/<description>` | Tooling, config, project file work | `chore/xcodegen-init`, `chore/asset-catalog-setup` |
| `exp/<description>` | Experimental or exploratory work | `exp/realtime-subscription-prototype` |

**`main` is protected.** All changes reach `main` via pull request only. Direct commits to `main` are prohibited per `/Users/Dinesh/CLAUDE.md` §7.1. If instructed to commit directly to `main`, halt and offer to create a branch + PR instead.

**Description rules:**
- Lowercase, hyphen-separated: `feat/tracker-home-view` not `feat/TrackerHomeView`
- Concise but specific: `feat/log-sheet-medium-detent` not `feat/log`
- Describes the change: no author names, no dates, no ticket numbers in branch name (those belong in commit bodies)
- Squash merge preferred; delete branch after merge per §7.2

**Rejection criteria:**
- Ad hoc names: `bugfix`, `test-branch`, `new-feature`, `temp`, `wip`, `dev` → reject
- Wrong prefix: `feature/tracker-home` → `feat/tracker-home`; `bugfix/auth` → `fix/auth`
- Missing description: `feat/` → incomplete, reject
- Camel case or underscores: `feat/trackerHomeView`, `feat/tracker_home` → use hyphens

---

## 3. `.pbxproj` Isolation Rule

`Cadence.xcodeproj` contains a `.pbxproj` generated by XcodeGen. It is a **build artifact** — machine-generated, not human-authored, not useful to review on its own. XcodeGen is the only sanctioned way to produce it (per `cadence-xcode-project` skill §1). Direct edits to `.pbxproj` are prohibited.

The isolation rule exists because `.pbxproj` churn inside feature commits makes PRs unreadable, blame history noisy, and rollbacks unpredictable. A reviewer cannot distinguish intentional project structure changes from incidental XcodeGen output noise when they are bundled with logic changes.

**Three cases — each has a defined commit shape:**

**Case 1 — New Swift source file addition (feat or chore):**
When `xcodegen generate` runs because a new `.swift` file was added, the `.xcodeproj` change is the inseparable registration artifact for that file. Commit them together. This is the only case where `.xcodeproj` may appear in a `feat:` or feature-scoped `chore:` commit.

```
feat(tracker): add TrackerHomeView skeleton
```
Staged: `Cadence/Views/Tracker/TrackerHomeView.swift` + `Cadence.xcodeproj`

```
feat(partner): add PartnerHomeView and PartnerShell
```
Staged: `Cadence/Views/Partner/PartnerHomeView.swift` + `Cadence/Views/Partner/PartnerShell.swift` + `Cadence.xcodeproj`

**Case 2 — Project structure change (XcodeGen config edit):**
Any `project.yml` edit that changes XcodeGen configuration — deployment target, build settings, new group exclusions, sources options — produces a `.xcodeproj` change that is purely structural. This is always an isolated `chore(project):` commit.

```
chore(project): add Views/Log group exclusion pattern to project.yml
```
Staged: `project.yml` + `Cadence.xcodeproj` — nothing else

```
chore(project): initialize XcodeGen project.yml and generate Cadence.xcodeproj
```
Staged: `project.yml` + `Cadence.xcodeproj` — nothing else

**Case 3 — Standalone regeneration (sync, conflict recovery):**
When `.xcodeproj` must be regenerated independently — after resolving a merge conflict, after pulling a teammate's `project.yml` change, after manual recovery — the regeneration commit stands alone.

```
chore(project): regenerate Cadence.xcodeproj from current project.yml
```
Staged: `Cadence.xcodeproj` only

**The anti-pattern — reject immediately:**
```
feat(tracker): implement TrackerHomeView + CalendarView
```
Staged: `Cadence/Views/Tracker/TrackerHomeView.swift` + `Cadence/Views/Tracker/CalendarView.swift` + `Cadence.xcodeproj` + `project.yml` (with new group config)

This mixes two Swift source files with a `project.yml` structural change. The `project.yml` edit and its `.xcodeproj` output must be in a preceding `chore(project):` commit. The feature files and their `.xcodeproj` registration belong in the `feat:` commit.

---

## 4. Mixed-Commit Prevention

A mixed commit bundles logically unrelated changes under one subject line. In a project with XcodeGen, the most common form is Swift feature logic + project file churn.

**Three commit categories — never cross them in a single commit:**

| Category | Files | Commit type |
|---|---|---|
| Product logic | `.swift` files in `Cadence/Views/`, `ViewModels/`, `Models/`, `Services/` | `feat:`, `fix:`, `refactor:` |
| Project structure | `project.yml`, `Cadence.xcodeproj` (when config-driven or standalone) | `chore(project):` |
| Infrastructure / tooling | `.xcassets/` contents, `Info.plist`, `.gitignore`, CI config | `chore:` |

**How to split a mixed commit before staging:**

1. Stage only the Swift source changes: `git add Cadence/Views/... Cadence/ViewModels/...`
2. Commit the feature: `feat(tracker): add TrackerHomeView skeleton`
3. Stage the `project.yml` and `Cadence.xcodeproj`: `git add project.yml Cadence.xcodeproj`
4. Commit the structure: `chore(project): add Tracker/Views group config to project.yml`

**Review heuristic:** If a reviewer seeing the diff would need to context-switch between "what does this feature do?" and "what did XcodeGen regenerate?", the commit should have been split before the PR was opened.

---

## 5. Atomic Commit Hygiene

Every Cadence commit must be a single, coherent, reviewable, and reversible unit of change.

**What atomicity requires:**
- One logical concern per commit
- Reverting the commit does not create an inconsistent build or runtime state
- A reviewer understands the entire change from the subject line alone
- The commit can be cherry-picked to a hotfix branch without unintended side effects

**Split when:**
- Two distinct features are staged together
- Logic changes and standalone project file changes are staged together
- A bug fix touches both a view and a model where the model fix is independently useful

**Do not split when:**
- A new Swift file and its `Cadence.xcodeproj` file registration are staged together (atomic per §3, Case 1)
- A view and its ViewModel are introduced together for the first time (single logical unit)

---

## 6. Pull Request Structure

Squash merge is preferred per parent governance. The squash commit message lands on `main` — it must conform to Conventional Commits. The PR title is the squash commit message.

**PR title format:** same as commit subject line — `type(scope): imperative description`

**Valid PR titles:**
```
feat(tracker): implement TrackerShell with 5-tab NavigationStack
fix(auth): resolve session token refresh race condition on backgrounding
chore(project): initialize XcodeGen project.yml and generate Cadence.xcodeproj
```

Do not open a PR where the branch contains unreviewed `.pbxproj` churn bundled into feature commits. Split before opening.

---

## 7. Anti-Pattern Reference

| Anti-pattern | Rule | Correction |
|---|---|---|
| `"update tracker home"` — no type | §1 | `"feat(tracker): update TrackerHomeView layout"` |
| `"chore: stuff"` — vague | §1 | `"chore(project): add Views/Splash group to project.yml"` |
| `"fixed auth bug"` — past tense | §1 | `"fix(auth): resolve session refresh after app backgrounding"` |
| `"build: ..."` — invalid type | §1 | Use `chore` |
| `"feat(TrackerHomeView.swift): ..."` — filename as scope | §1 | `"feat(tracker): ..."` |
| `wip`, `test-branch`, `bugfix` branch names | §2 | `fix/<description>` or `feat/<description>` |
| `feature/tracker-home` — wrong prefix | §2 | `feat/tracker-home` |
| `feat/TrackerHomeView` — camel case | §2 | `feat/tracker-home-view` |
| Direct commit to `main` | §2 | Create branch + open PR |
| `feat(tracker): add view` staged with `project.yml` config change | §3 | Split: feature commit + `chore(project):` commit |
| `Cadence.xcodeproj` inside a pure logic `refactor:` commit | §3 | Isolated `chore(project): regenerate Cadence.xcodeproj` |
| 5 new views + project file + xcassets in one commit | §5 | Per-view `feat:` commits + `chore(project):` + `chore(design):` |
| PR title not Conventional Commits format | §6 | PR title = squash commit message, must conform |

---

## 8. Commit Checklist

Before every Cadence commit:

- [ ] Subject line: `type(scope): imperative description`
- [ ] Type is one of: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `exp`
- [ ] Scope is present for `feat:` and `fix:` commits; matches a concept not a filename
- [ ] Description is imperative, specific, under 72 chars total subject line
- [ ] No `project.yml` config changes staged alongside Swift source changes
- [ ] If `Cadence.xcodeproj` is staged: either (a) a new Swift file is also staged and they are directly paired (Case 1), or (b) this is an isolated `chore(project):` commit (Case 2 or 3)
- [ ] Branch name matches `feat/`, `fix/`, `chore/`, or `exp/` pattern with a hyphenated description
- [ ] Branch does not target `main` directly
- [ ] PR title (if applicable) matches Conventional Commits format
