# 8-Table Schema Migration

**Epic ID:** PH-1-E2
**Phase:** 1 -- Supabase Backend
**Estimated Size:** L
**Status:** Draft

---

## Objective

Author and apply a complete SQL migration that creates all eight Cadence tables with their exact column definitions, constraints, defaults, and performance indexes. The schema produced by this epic is the permanent data contract for the entire application -- every iOS phase, RLS policy, sync layer, and prediction algorithm reads from and writes to exactly these tables.

## Problem / Context

The Cadence data model is specified in MVP Spec §Data Model and locked in cadence-supabase skill §2. Eight tables -- `users`, `cycle_profiles`, `partner_connections`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings` -- form the full persistence layer for the MVP. Every table name, column name, type, constraint, and default is load-bearing: the RLS policies in Epic 3 reference specific column names; the SyncCoordinator in Phase 7 keys conflict resolution on `updated_at`; the prediction engine in Phase 3 reads `period_logs` and `prediction_snapshots` by exact column name; the privacy architecture in Phase 8 enforces `is_private` as a hard gate.

Schema changes after Phase 1 are costly: they require new migration files, RLS policy updates, SwiftData model updates, and SyncCoordinator payload updates in lock-step. Getting the schema right in Phase 1 -- including the `updated_at` columns required by the Phase 7 sync layer and the `invited_at` column required by the invite code expiry logic -- avoids additive migrations in downstream phases.

The migration must use `text CHECK(...)` constraints rather than Postgres ENUM types. ENUMs are schema objects that require `ALTER TYPE` to extend -- a higher-overhead operation than updating a CHECK constraint. For a pre-App Store beta with a known value set, CHECK constraints provide equivalent safety with lower migration cost.

RLS must be enabled on every table at creation time, before any data is written. Enabling RLS retroactively on a table that already contains data is a window during which data is unprotected.

**Source references that define scope:**

- cadence-supabase skill §2 (canonical 8-table schema with column types and defaults)
- MVP Spec §Data Model (all 8 tables with column names and types)
- PHASES.md Phase 1 in-scope: "8 tables: users, cycle_profiles, partner_connections, period_logs, daily_logs, symptom_logs, prediction_snapshots, reminder_settings (exact schemas from MVP Spec data model section)"
- PHASES.md Phase 7 in-scope: "last-write-wins conflict resolution keyed on updated_at" -- requires `updated_at` columns on user-owned tables
- cadence-supabase skill §5.1 (invite code expiry requires `invited_at` on partner_connections)
- cadence-supabase skill §5.1 (unique index: one connection per tracker_id)

## Scope

### In Scope

- Single migration file at `supabase/migrations/[timestamp]_initial-schema.sql` covering all 8 tables
- `users` table: `id uuid PRIMARY KEY` (Supabase Auth UID), `created_at timestamptz DEFAULT now()`, `role text NOT NULL CHECK(role IN ('tracker', 'partner'))`, `timezone text NOT NULL DEFAULT 'UTC'`
- `cycle_profiles` table: `user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE`, `average_cycle_length int NOT NULL DEFAULT 28`, `average_period_length int NOT NULL DEFAULT 5`, `goal_mode text NOT NULL DEFAULT 'track' CHECK(goal_mode IN ('track', 'conceive'))`, `predictions_enabled bool NOT NULL DEFAULT true`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `partner_connections` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `tracker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `partner_id uuid REFERENCES users(id) ON DELETE SET NULL`, `invite_code text`, `invited_at timestamptz NOT NULL DEFAULT now()`, `connected_at timestamptz`, `is_paused bool NOT NULL DEFAULT false`, `share_predictions bool NOT NULL DEFAULT false`, `share_phase bool NOT NULL DEFAULT false`, `share_symptoms bool NOT NULL DEFAULT false`, `share_mood bool NOT NULL DEFAULT false`, `share_fertile_window bool NOT NULL DEFAULT false`, `share_notes bool NOT NULL DEFAULT false`
- `period_logs` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `start_date date NOT NULL`, `end_date date`, `source text NOT NULL DEFAULT 'manual' CHECK(source IN ('manual', 'predicted'))`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `daily_logs` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `date date NOT NULL`, `flow_level text CHECK(flow_level IN ('spotting', 'light', 'medium', 'heavy'))`, `mood text`, `sleep_quality int CHECK(sleep_quality BETWEEN 1 AND 5)`, `notes text`, `is_private bool NOT NULL DEFAULT true`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `symptom_logs` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `daily_log_id uuid NOT NULL REFERENCES daily_logs(id) ON DELETE CASCADE`, `symptom_type text NOT NULL CHECK(symptom_type IN ('cramps', 'headache', 'bloating', 'mood_changes', 'fatigue', 'acne', 'discharge', 'sex', 'exercise', 'sleep_quality'))`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `prediction_snapshots` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `date_generated timestamptz NOT NULL DEFAULT now()`, `predicted_next_period date NOT NULL`, `predicted_ovulation date`, `fertile_window_start date`, `fertile_window_end date`, `confidence_level text NOT NULL CHECK(confidence_level IN ('high', 'medium', 'low'))`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `reminder_settings` table: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `remind_period bool NOT NULL DEFAULT false`, `remind_ovulation bool NOT NULL DEFAULT false`, `remind_daily_log bool NOT NULL DEFAULT false`, `notify_partner_period bool NOT NULL DEFAULT false`, `notify_partner_symptoms bool NOT NULL DEFAULT false`, `notify_partner_fertile bool NOT NULL DEFAULT false`, `reminder_time time NOT NULL DEFAULT '08:00:00'`, `updated_at timestamptz NOT NULL DEFAULT now()`
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` on every table immediately after creation
- `UNIQUE` constraint on `(user_id, date)` in `daily_logs` (one log per user per day)
- `UNIQUE` constraint on `(user_id, start_date)` in `period_logs` (no duplicate period starts)
- Unique index on `partner_connections(tracker_id)` enforcing one connection row per tracker
- Performance indexes: `daily_logs(user_id, date)`, `daily_logs(user_id, is_private)`, `period_logs(user_id)`, `partner_connections(tracker_id)`, `partner_connections(partner_id)`, `prediction_snapshots(user_id, date_generated DESC)`, `symptom_logs(daily_log_id)`
- `updated_at` trigger function `set_updated_at()` and trigger on each table that has an `updated_at` column (cycle_profiles, period_logs, daily_logs, symptom_logs, prediction_snapshots, reminder_settings)
- Migration applied to the remote project via `supabase db push`
- Schema verified against the cadence-supabase skill §2 canonical definition

### Out of Scope

- RLS policy bodies (Epic 3 -- tables have RLS enabled but no policies in this epic)
- Device tokens table (`device_tokens`) referenced in cadence-supabase skill §7.4 -- deferred to Phase 10 (notifications)
- Any table not in the 8-table canonical set
- Seed data or test fixtures
- SwiftData model files (no Swift source in Phase 1)
- `cycle_profiles` rows populated (rows are created via Tracker onboarding in Phase 2)

## Dependencies

| Dependency                                    | Type | Phase/Epic | Status | Risk                                     |
| --------------------------------------------- | ---- | ---------- | ------ | ---------------------------------------- |
| PH-1-E1 complete (project exists, CLI linked) | FS   | PH-1-E1    | Open   | High -- no project = no migration target |
| `supabase/migrations/` directory exists       | FS   | PH-1-E1-S2 | Open   | Low -- created by `supabase init`        |

## Assumptions

- `gen_random_uuid()` is available without extension (Postgres 14+ includes it natively as an alias for `uuid_generate_v4` via `pgcrypto`, which Supabase enables by default).
- `ON DELETE CASCADE` on `partner_connections.tracker_id` is correct: deleting a user deletes their connection row. This is the desired behavior for account deletion (Phase 12).
- `is_private DEFAULT true` on `daily_logs` is intentional and correct per cadence-supabase skill §2: sharing must be explicitly enabled, not explicitly disabled.
- All `share_*` columns on `partner_connections` default to `false` per MVP Spec §2: "All categories are off by default."
- `symptom_type` values are the exhaustive set from MVP Spec §7. Adding a new symptom type post-migration requires a new migration to update the CHECK constraint.
- The `invited_at` column on `partner_connections` is additive to the MVP Spec schema; it is required by the 24h expiry enforcement in the `generate-invite` Edge Function (Phase 8 + cadence-supabase skill §5.1) and does not conflict with any spec constraint.

## Risks

| Risk                                                                                      | Likelihood | Impact | Mitigation                                                                                                                                      |
| ----------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `supabase db push` fails with a constraint violation on an existing remote schema         | Low        | Medium | Run `supabase db remote commit` first (PH-1-E1-S4) to capture the clean baseline; the initial schema migration should apply to a clean database |
| CHECK constraint on `symptom_type` is too restrictive if the symptom set evolves          | Medium     | Low    | Symptom set is locked in MVP Spec §7 for beta; a `CHECK` update migration is low-effort if needed pre-App Store                                 |
| `updated_at` trigger function body is incorrect and silently fails to update the column   | Low        | High   | Verify trigger with a direct `UPDATE` test query after applying the migration; confirm `updated_at` changes on each table                       |
| Missing unique index on `partner_connections(tracker_id)` allows data integrity violation | Low        | High   | The unique index is explicitly in S4 scope; RLS alone does not prevent multiple rows at the DB layer                                            |

---

## Stories

### S1: Define users, cycle_profiles tables and set_updated_at trigger

**Story ID:** PH-1-E2-S1
**Points:** 3

Author the first section of the migration covering the `users` and `cycle_profiles` tables, along with the reusable `set_updated_at()` trigger function that enforces automatic `updated_at` maintenance across all tables that carry the column. Both tables have RLS enabled immediately after creation.

**Acceptance Criteria:**

- [ ] Migration file `supabase/migrations/[timestamp]_initial-schema.sql` exists (timestamp format: YYYYMMDDHHMMSS)
- [ ] `CREATE TABLE users` is the first DDL statement in the migration (before any other table); `id uuid PRIMARY KEY` uses Supabase Auth UID as the primary key
- [ ] `users.role` has `CHECK(role IN ('tracker', 'partner'))` and `NOT NULL`
- [ ] `users.timezone` has `NOT NULL DEFAULT 'UTC'`
- [ ] `ALTER TABLE users ENABLE ROW LEVEL SECURITY` appears immediately after the users table CREATE
- [ ] `CREATE TABLE cycle_profiles` uses `user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE`
- [ ] `cycle_profiles.goal_mode` has `CHECK(goal_mode IN ('track', 'conceive'))` and `NOT NULL DEFAULT 'track'`
- [ ] `cycle_profiles.updated_at` column is present with type `timestamptz NOT NULL DEFAULT now()`
- [ ] `ALTER TABLE cycle_profiles ENABLE ROW LEVEL SECURITY` appears immediately after the cycle_profiles CREATE
- [ ] `CREATE OR REPLACE FUNCTION set_updated_at()` is present in the migration and sets `NEW.updated_at = now()` then `RETURN NEW`
- [ ] A `CREATE TRIGGER` statement applies `set_updated_at()` BEFORE UPDATE on `cycle_profiles`
- [ ] `supabase db push --dry-run` exits 0 with no SQL errors for this section of the migration

**Dependencies:** PH-1-E1-S2

**Notes:** The `set_updated_at()` function is defined once and reused as a trigger on all tables with `updated_at`. Define it early in the migration so subsequent table sections can reference it without forward-reference errors. Confirm `gen_random_uuid()` availability with `SELECT gen_random_uuid()` in the Supabase SQL editor before the migration is written -- if the function is unavailable, add `CREATE EXTENSION IF NOT EXISTS pgcrypto;` at the top of the migration.

---

### S2: Define partner_connections table and unique constraint

**Story ID:** PH-1-E2-S2
**Points:** 3

Author the `partner_connections` table section of the migration. This table is the most structurally complex in the schema: it carries the invite code, the 24h expiry timestamp, all six permission flags, the pause state, and the uniqueness constraint that enforces one connection per Tracker. It is the central table that Epic 3's RLS policies protect.

**Acceptance Criteria:**

- [ ] `CREATE TABLE partner_connections` is present with all columns: `id`, `tracker_id`, `partner_id`, `invite_code`, `invited_at`, `connected_at`, `is_paused`, `share_predictions`, `share_phase`, `share_symptoms`, `share_mood`, `share_fertile_window`, `share_notes`
- [ ] `tracker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`
- [ ] `partner_id uuid REFERENCES users(id) ON DELETE SET NULL` (nullable -- null when invite is pending)
- [ ] `invite_code text` is nullable (null after redemption, populated when invite is active)
- [ ] `invited_at timestamptz NOT NULL DEFAULT now()`
- [ ] `connected_at timestamptz` is nullable (null until invite is redeemed)
- [ ] `is_paused bool NOT NULL DEFAULT false`
- [ ] All six `share_*` columns (`share_predictions`, `share_phase`, `share_symptoms`, `share_mood`, `share_fertile_window`, `share_notes`) are `bool NOT NULL DEFAULT false`
- [ ] `ALTER TABLE partner_connections ENABLE ROW LEVEL SECURITY` appears immediately after the CREATE
- [ ] `CREATE UNIQUE INDEX idx_one_connection_per_tracker ON partner_connections(tracker_id)` is present -- enforces one connection row per Tracker at the DB layer
- [ ] `supabase db push --dry-run` exits 0 with no SQL errors for the migration up to this point

**Dependencies:** PH-1-E2-S1

**Notes:** `ON DELETE SET NULL` on `partner_id` is intentional: if the Partner deletes their account, the connection row persists in a pending/disconnected state rather than silently disappearing from the Tracker's view. The Tracker's Settings screen (Phase 12) must handle the `partner_id IS NULL` state as "partner account deleted." `ON DELETE CASCADE` on `tracker_id` is correct: if the Tracker deletes their account, all connection rows are removed, revoking all Partner access immediately.

---

### S3: Define period_logs, daily_logs, and symptom_logs tables

**Story ID:** PH-1-E2-S3
**Points:** 3

Author the three logging tables that form the core of the Tracker's daily interaction. `daily_logs` carries the `is_private` flag that the privacy architecture enforces as a master override. `symptom_logs` is a child of `daily_logs` and must never be directly readable by the Partner at the DB layer.

**Acceptance Criteria:**

- [ ] `CREATE TABLE period_logs` is present with columns: `id`, `user_id`, `start_date`, `end_date`, `source`, `updated_at`
- [ ] `period_logs.source` has `CHECK(source IN ('manual', 'predicted'))` and `NOT NULL DEFAULT 'manual'`
- [ ] `period_logs.end_date date` is nullable (a period in progress has no end date yet)
- [ ] `UNIQUE(user_id, start_date)` constraint on `period_logs` prevents duplicate period start records
- [ ] `ALTER TABLE period_logs ENABLE ROW LEVEL SECURITY` appears immediately after the period_logs CREATE
- [ ] `CREATE TABLE daily_logs` is present with columns: `id`, `user_id`, `date`, `flow_level`, `mood`, `sleep_quality`, `notes`, `is_private`, `updated_at`
- [ ] `daily_logs.is_private bool NOT NULL DEFAULT true` -- default is private, opt-in sharing
- [ ] `daily_logs.flow_level` has `CHECK(flow_level IN ('spotting', 'light', 'medium', 'heavy'))` and is nullable (not all log entries have flow data)
- [ ] `daily_logs.sleep_quality int CHECK(sleep_quality BETWEEN 1 AND 5)` is nullable
- [ ] `UNIQUE(user_id, date)` constraint on `daily_logs` prevents duplicate log entries per day per user
- [ ] `ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY` appears immediately after the daily_logs CREATE
- [ ] `CREATE TABLE symptom_logs` is present with columns: `id`, `daily_log_id`, `symptom_type`, `updated_at`
- [ ] `symptom_logs.symptom_type` has `CHECK(symptom_type IN ('cramps', 'headache', 'bloating', 'mood_changes', 'fatigue', 'acne', 'discharge', 'sex', 'exercise', 'sleep_quality'))` and `NOT NULL`
- [ ] `symptom_logs.daily_log_id uuid NOT NULL REFERENCES daily_logs(id) ON DELETE CASCADE`
- [ ] `ALTER TABLE symptom_logs ENABLE ROW LEVEL SECURITY` appears immediately after the symptom_logs CREATE
- [ ] `updated_at` triggers are applied to all three tables using the `set_updated_at()` function from S1
- [ ] `supabase db push --dry-run` exits 0 with no SQL errors for the migration up to this point

**Dependencies:** PH-1-E2-S1, PH-1-E2-S2

**Notes:** `daily_logs.is_private DEFAULT true` is the cornerstone of the opt-in sharing model. Every entry is private until the Tracker explicitly toggles it off. This default must never be changed to `false` without explicit sign-off from Dinesh. The `sex` symptom_type is included in the CHECK constraint but is excluded from Partner-facing query projections at the service layer by the cadence-privacy-architecture skill -- the DB CHECK constraint does not and should not enforce this exclusion; that is application-layer responsibility.

---

### S4: Define prediction_snapshots, reminder_settings tables and performance indexes

**Story ID:** PH-1-E2-S4
**Points:** 3

Author the final two tables and all performance indexes for the schema. The prediction_snapshots table carries the pre-computed prediction output that the Phase 3 engine writes and that the Phase 5/6/9 surfaces read. The reminder_settings table carries the per-user notification preferences that the Phase 10 Edge Function reads.

**Acceptance Criteria:**

- [ ] `CREATE TABLE prediction_snapshots` is present with columns: `id`, `user_id`, `date_generated`, `predicted_next_period`, `predicted_ovulation`, `fertile_window_start`, `fertile_window_end`, `confidence_level`, `updated_at`
- [ ] `prediction_snapshots.confidence_level` has `CHECK(confidence_level IN ('high', 'medium', 'low'))` and `NOT NULL`
- [ ] `prediction_snapshots.predicted_next_period date NOT NULL` (required; all other prediction date fields are nullable to allow partial predictions at low confidence)
- [ ] `ALTER TABLE prediction_snapshots ENABLE ROW LEVEL SECURITY` appears immediately after the prediction_snapshots CREATE
- [ ] `CREATE TABLE reminder_settings` is present with all columns: `id`, `user_id`, `remind_period`, `remind_ovulation`, `remind_daily_log`, `notify_partner_period`, `notify_partner_symptoms`, `notify_partner_fertile`, `reminder_time`, `updated_at`
- [ ] `reminder_settings.reminder_time time NOT NULL DEFAULT '08:00:00'`
- [ ] All boolean reminder columns in `reminder_settings` are `NOT NULL DEFAULT false`
- [ ] `ALTER TABLE reminder_settings ENABLE ROW LEVEL SECURITY` appears immediately after the reminder_settings CREATE
- [ ] `updated_at` triggers applied to both tables using `set_updated_at()` from S1
- [ ] `CREATE INDEX` statements present for: `daily_logs(user_id, date)`, `daily_logs(user_id, is_private)`, `period_logs(user_id)`, `partner_connections(tracker_id)`, `partner_connections(partner_id)`, `prediction_snapshots(user_id, date_generated DESC)`, `symptom_logs(daily_log_id)`
- [ ] `supabase db push --dry-run` exits 0 with no SQL errors for the complete migration

**Dependencies:** PH-1-E2-S1, PH-1-E2-S2, PH-1-E2-S3

**Notes:** `predicted_ovulation`, `fertile_window_start`, and `fertile_window_end` are nullable because at `confidence_level = 'low'` (0-1 cycles logged), the prediction engine may not have enough data to compute ovulation or fertile window. Requiring these columns as `NOT NULL` would force the engine to write placeholder values, which is worse than nullable. The Phase 3 prediction engine spec (cadence-data-layer skill) handles this case.

---

### S5: Apply migration and verify schema against canonical definition

**Story ID:** PH-1-E2-S5
**Points:** 2

Apply the complete migration to the remote Supabase project and verify every table's column set, types, constraints, and RLS enablement match the cadence-supabase skill §2 canonical definition.

**Acceptance Criteria:**

- [ ] `supabase db push` exits 0 with no errors
- [ ] `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name` returns exactly: `cycle_profiles`, `daily_logs`, `partner_connections`, `period_logs`, `prediction_snapshots`, `reminder_settings`, `symptom_logs`, `users` -- no extra tables, no missing tables
- [ ] `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public'` confirms `rowsecurity = true` for all 8 tables
- [ ] `SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name = 'daily_logs' ORDER BY ordinal_position` confirms `is_private` has `column_default = 'true'` and `is_nullable = 'NO'`
- [ ] `SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'partner_connections' ORDER BY ordinal_position` confirms all six `share_*` columns have `column_default = 'false'`
- [ ] `SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'partner_connections'` confirms `idx_one_connection_per_tracker` is present
- [ ] `SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname LIKE 'set_updated_at%'` returns one trigger entry for each of: `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings`
- [ ] `supabase/migrations/[timestamp]_initial-schema.sql` is committed to the repository
- [ ] `scripts/protocol-zero.sh` exits 0 on the migration file
- [ ] `scripts/check-em-dashes.sh` exits 0 on the migration file

**Dependencies:** PH-1-E2-S1, PH-1-E2-S2, PH-1-E2-S3, PH-1-E2-S4

**Notes:** The verification queries in the acceptance criteria are SQL-executable checks, not visual dashboard checks. Run each one in the Supabase SQL editor and confirm the results. If any column is missing, has the wrong type, or RLS is disabled on any table, the migration file must be corrected and a new migration applied -- do not fix schema issues by modifying tables directly in the dashboard.

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
- [ ] All 8 tables exist in the remote Supabase project with RLS enabled
- [ ] Schema verified against cadence-supabase skill §2 canonical definition via SQL queries
- [ ] Phase objective is advanced: complete, RLS-enabled schema is live on Supabase
- [ ] cadence-supabase skill §2 constraints satisfied: all column names, types, defaults match canonical definition
- [ ] cadence-privacy-architecture skill constraints: `is_private DEFAULT true` confirmed; `sex` in symptom_type CHECK constraint confirmed
- [ ] cadence-sync skill constraint: `updated_at` columns present on all synced tables; triggers applied
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Migration file committed to `supabase/migrations/`; no schema changes made outside migration files

## Source References

- PHASES.md: Phase 1 -- Supabase Backend (in-scope: 8 tables with exact schemas from MVP Spec data model section)
- MVP Spec §Data Model (canonical 8 tables: all column names and types)
- MVP Spec §2 (partner sharing: all `share_*` columns default off; `is_private` semantics)
- cadence-supabase skill §2 (exact DDL column types, defaults, CHECK constraints)
- cadence-supabase skill §5.1 (`invited_at` column and unique index on partner_connections)
- cadence-sync skill (last-write-wins requires `updated_at` on user-owned tables)
- cadence-privacy-architecture skill (`is_private DEFAULT true`; `sex` symptom exclusion from Partner payloads)
