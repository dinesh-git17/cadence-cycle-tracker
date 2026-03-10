# Supabase Project Initialization and CLI Configuration

**Epic ID:** PH-1-E1
**Phase:** 1 -- Supabase Backend
**Estimated Size:** M
**Status:** Draft

---

## Objective

Create the Cadence Supabase project on org `dinbuilds`, link it with the Supabase CLI, and secure the project credentials for handoff to subsequent iOS phases. This epic is the entry condition for every other Phase 1 epic -- no schema migrations, RLS policies, or auth configuration can proceed until the project exists and the CLI is linked.

## Problem / Context

The Cadence Supabase project does not exist as of March 2026. The `dinbuilds` org (ID: `hekdjznkviujumcsbqip`, plan: free) is the verified target org per cadence-supabase skill §1. Every downstream phase -- schema migration, RLS policy deployment, auth provider setup, Edge Function deployment, and the iOS client integration starting in Phase 3 -- depends on the project URL and anon key that this epic produces.

The Supabase CLI link step is required to run `supabase db push` for migrations (Epic 2) and `supabase functions deploy` for Edge Functions (Epic 5). Without `supabase/config.toml` committed to the repo, every engineer and CI runner must re-link manually -- a recurring failure point. The config file captures the project reference without capturing secrets, making it safe to commit.

Credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) must not appear in any committed file. Phase 1 establishes the secure handoff pattern: a gitignored local `.env.supabase` holds the real values; a committed `.env.supabase.example` documents the required format for iOS integration phases (Phase 3+).

**Source references that define scope:**

- cadence-supabase skill §1 (project configuration governance, singleton client, env var loading)
- PHASES.md Phase 1 in-scope: "Supabase project creation on org dinbuilds"
- PHASES.md Phase 1 in-scope: "Edge Function directory scaffold" (requires CLI linkage)
- CLAUDE.md §5 (secrets in env files, gitignored; no hardcoded credentials)

## Scope

### In Scope

- Supabase project creation on org `dinbuilds` via the Supabase MCP or dashboard; project name: `cadence`; region: us-east-1 (nearest to primary beta cohort)
- `supabase/config.toml` at repo root populated with the project reference (committed; contains no secrets)
- `.env.supabase` at repo root containing `SUPABASE_URL` and `SUPABASE_ANON_KEY` real values (gitignored)
- `.env.supabase.example` at repo root with placeholder values documenting the required format (committed)
- `.gitignore` updated to include `.env.supabase` (the Phase 0 `.gitignore` is the base; this entry is additive)
- `supabase/` directory initialization via `supabase init` (creates `supabase/config.toml` and `supabase/migrations/` directory)
- CLI linkage: `supabase link --project-ref [project_ref]` succeeds
- Smoke-query verification: a `SELECT 1` against the live project via the Supabase SQL editor confirms connectivity

### Out of Scope

- Schema migration files (Epic 2)
- RLS policy definitions (Epic 3)
- Auth provider configuration (Epic 4)
- Edge Function files under `supabase/functions/` (Epic 5)
- iOS `SupabaseClient.swift` singleton (Phase 3 -- no Swift source in Phase 1)
- `.xcconfig` credential integration into the Xcode project (Phase 3)
- Supabase extensions beyond what `supabase init` enables by default (extensions required by the MVP schema are addressed in Epic 2)

## Dependencies

| Dependency                                             | Type     | Phase/Epic | Status                                              | Risk                                        |
| ------------------------------------------------------ | -------- | ---------- | --------------------------------------------------- | ------------------------------------------- |
| `dinbuilds` org exists and is accessible               | External | None       | Resolved -- verified March 7, 2026 via Supabase MCP | Low                                         |
| Supabase CLI installed (`supabase` on PATH)            | External | None       | Open                                                | Low -- `brew install supabase/tap/supabase` |
| Phase 0 complete (repo exists, `.gitignore` committed) | FS       | PH-0-E3    | Open                                                | Low                                         |

## Assumptions

- The `dinbuilds` org free plan supports creating one new project. If the free plan limit is hit, Dinesh must upgrade or delete an unused project before this epic can start.
- Region `us-east-1` is the correct region for the beta cohort. If the primary beta cohort is not US-based, Dinesh must confirm the region before project creation -- region cannot be changed after creation without deleting and recreating the project.
- The Supabase CLI version available via Homebrew is compatible with the Supabase platform version used by the project. Verify with `supabase --version` before linking.
- The project reference (from `supabase/config.toml`) and the anon key (from the Supabase dashboard API settings) are the only values needed for the `.env.supabase` file at this stage; the service role key is not required until Edge Function development.

## Risks

| Risk                                                           | Likelihood | Impact | Mitigation                                                                                                      |
| -------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------- |
| Free plan project creation fails or is rate-limited            | Low        | High   | Check org plan limits before starting; upgrade if needed                                                        |
| Region selection cannot be changed post-creation               | Medium     | Medium | Confirm region with Dinesh before creating; document choice in `supabase/config.toml` comment                   |
| `.gitignore` entry missing causes accidental credential commit | Low        | High   | Add `.env.supabase` to `.gitignore` in S3 before writing the file; verify with `git status` before committing   |
| CLI version incompatibility with remote project                | Low        | Medium | Pin Supabase CLI version in `.tool-versions` or engineering runbook; test `supabase link` before declaring done |

---

## Stories

### S1: Create Cadence Supabase project on org dinbuilds

**Story ID:** PH-1-E1-S1
**Points:** 2

Create the `cadence` project on the `dinbuilds` Supabase org. The project is the root resource that all subsequent backend work depends on. Region selection is a one-time, irreversible decision.

**Acceptance Criteria:**

- [ ] A Supabase project named `cadence` exists under org `dinbuilds` in the Supabase dashboard
- [ ] The project region is `us-east-1` (confirmed with Dinesh before creation)
- [ ] The project status is `ACTIVE_HEALTHY` (not `INACTIVE`, `COMING_UP`, or `PAUSED`)
- [ ] `SUPABASE_URL` (format: `https://[project-ref].supabase.co`) is available from the project API settings
- [ ] `SUPABASE_ANON_KEY` (JWT starting with `eyJ`) is available from the project API settings
- [ ] The project database password is recorded securely outside the repository (1Password or equivalent) -- not in any file in the repo
- [ ] The Supabase MCP `mcp__supabase__get_project` call returns the project with `status: "ACTIVE_HEALTHY"`

**Dependencies:** None

**Notes:** The Supabase free plan supports one active project. If `dinbuilds` already has an active project when this story runs, Dinesh must confirm the org capacity before proceeding. Do not create the project with a generic name -- `cadence` is the canonical project name per cadence-supabase skill §1.

---

### S2: Initialize Supabase CLI and link to remote project

**Story ID:** PH-1-E1-S2
**Points:** 2

Run `supabase init` to create the `supabase/` directory structure and `config.toml`, then link the CLI to the remote `cadence` project. The committed `config.toml` is the repo-level record of the project reference, making CLI operations reproducible across machines and CI runners without re-linking manually.

**Acceptance Criteria:**

- [ ] `supabase/` directory exists at the repository root
- [ ] `supabase/config.toml` exists and contains a `project_id` value matching the `cadence` project reference from S1
- [ ] `supabase/migrations/` directory exists (created by `supabase init`)
- [ ] `supabase link --project-ref [project_ref]` exits 0 with no errors
- [ ] `supabase status` exits 0 and shows the linked project URL matching the S1 `SUPABASE_URL`
- [ ] `supabase/config.toml` is committed to the repository (it contains only the project ref, no secrets)
- [ ] `supabase/.gitignore` (if created by `supabase init`) is committed and does not exclude `config.toml`

**Dependencies:** PH-1-E1-S1

**Notes:** `supabase init` creates a `.gitignore` inside the `supabase/` directory that excludes certain files. Review it before committing -- do not blindly override it, but ensure `config.toml` and `migrations/` are not excluded. The `supabase/` directory should be committed except for any auto-generated files that contain secrets (typically `.temp/`).

---

### S3: Commit credential template and update .gitignore

**Story ID:** PH-1-E1-S3
**Points:** 1

Establish the secure credential handoff pattern for iOS integration phases. The `.env.supabase` file holds the real credentials locally; the `.env.supabase.example` file committed to the repo documents the exact format that Phase 3 needs to populate `.xcconfig`.

**Acceptance Criteria:**

- [ ] `.env.supabase` exists at the repository root with real `SUPABASE_URL` and `SUPABASE_ANON_KEY` values from S1
- [ ] `.env.supabase` is listed in `.gitignore` (verify with `git check-ignore -v .env.supabase` returning `.gitignore:.env.supabase`)
- [ ] `git status` does not show `.env.supabase` as a tracked or staged file
- [ ] `.env.supabase.example` exists at the repository root with the following content exactly (no real values):
- [ ] ```bash
      SUPABASE_URL=https://your-project-ref.supabase.co
      SUPABASE_ANON_KEY=eyJ...your-anon-key...
      ```
- [ ] `.env.supabase.example` is committed to the repository
- [ ] No other file in the repository contains the real `SUPABASE_URL` or `SUPABASE_ANON_KEY` values (verify with `git grep` before committing)

**Dependencies:** PH-1-E1-S1

**Notes:** The `.env.supabase` format uses plain `KEY=VALUE` syntax without quotes -- this is what the shell `export $(cat .env.supabase)` pattern expects for local development. The iOS `.xcconfig` integration in Phase 3 will source these values through a different mechanism; the `.env.supabase.example` documents the variable names as the canonical reference.

---

### S4: Verify live project connectivity

**Story ID:** PH-1-E1-S4
**Points:** 1

Confirm the project is accessible and RLS-ready by running a `SELECT 1` smoke query and verifying the Postgres version is compatible with the RLS policies defined in Epic 3.

**Acceptance Criteria:**

- [ ] `SELECT 1` executed in the Supabase SQL editor returns `1` without error
- [ ] `SELECT version()` in the Supabase SQL editor returns a Postgres version of 15 or higher
- [ ] `SELECT current_setting('rls.enable_row_security', true)` does not error (confirms the RLS extension is available)
- [ ] The Supabase dashboard shows the project database as healthy (no replication or connection errors)
- [ ] `supabase db remote commit` exits 0 (confirms the CLI can reach the remote DB and there are no uncommitted remote changes to capture)

**Dependencies:** PH-1-E1-S2

**Notes:** `supabase db remote commit` captures any schema changes made via the Supabase dashboard that are not yet in the local migrations directory. Run this once now, before any migrations are authored in Epic 2, to establish a clean baseline. If it produces a migration file, inspect it carefully -- it should represent only the default Supabase schema (auth, storage, etc.), not any Cadence-specific tables.

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

- [ ] All four stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Supabase project `cadence` on org `dinbuilds` is `ACTIVE_HEALTHY`
- [ ] Phase objective is advanced: a live Supabase project is reachable and CLI-linked
- [ ] cadence-supabase skill §1 constraints satisfied: project name `cadence`, org `dinbuilds`, singleton pattern documented for Phase 3
- [ ] cadence-git skill constraints satisfied: `supabase/config.toml` and `.env.supabase.example` committed; `.env.supabase` gitignored
- [ ] CLAUDE.md §5 satisfied: no secrets in any committed file; `.env.supabase` gitignored
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] No dead code, stubs, or placeholder comments in any committed file
- [ ] Source document alignment verified: project org and naming match cadence-supabase skill §1

## Source References

- PHASES.md: Phase 1 -- Supabase Backend (in-scope: Supabase project creation on org dinbuilds)
- cadence-supabase skill §1 (project configuration governance: name `cadence`, org `dinbuilds`, region, singleton client, env var loading pattern)
- CLAUDE.md §5 (security: secrets in gitignored env files, no hardcoded credentials)
- cadence-git skill (branch naming, commit format)
