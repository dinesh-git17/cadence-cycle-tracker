# Row Level Security Policy Set

**Epic ID:** PH-1-E3
**Phase:** 1 -- Supabase Backend
**Estimated Size:** L
**Status:** Draft

---

## Objective

Author and apply the complete RLS policy set for all eight Cadence tables: ownership-write policies on all user-owned tables, partner-read policies on `daily_logs`, `period_logs`, and `prediction_snapshots` with all four required conditions enforced, and the access policies for `partner_connections` that prevent Partners from modifying connection state. Pass the cadence-supabase skill §3 RLS policy review checklist on every policy before deployment.

## Problem / Context

The partner sharing model is the defining feature of Cadence. MVP Spec §2 states: "This enforcement lives at the database level. The Partner client cannot receive data the Tracker has not explicitly permitted, regardless of app code." RLS is the enforcement mechanism. Without it, any authenticated user can read any row from any table -- a complete privacy failure that no amount of iOS application code can fix after the fact.

The policy structure is security-critical and cannot be retrofitted without downtime risk. Specific failure modes:

- Missing `is_paused = false` condition: a Tracker who pauses sharing still exposes all data to their Partner.
- Missing `is_private = false` condition on `daily_logs`: entries the Tracker marked private are readable by the Partner.
- Granting Partner read on `symptom_logs` directly: bypasses the `is_private` check on the parent `daily_logs` row.
- Granting Partner write on `partner_connections`: allows a Partner to enable their own sharing flags or re-activate a disconnected relationship.
- Using client-provided user IDs instead of `auth.uid()`: allows a malicious client to impersonate another user.

The RLS policy structure in this epic is the database-side half of the privacy architecture. The iOS service layer (cadence-privacy-architecture skill) enforces the same model at the application layer. Both must agree.

**Source references that define scope:**

- cadence-supabase skill §3 (complete RLS policy structure, exact SQL patterns)
- cadence-supabase skill §3.6 (RLS policy review checklist)
- MVP Spec §2 (4-condition partner read: live connection + is*paused=false + share*\* flag + is_private=false)
- MVP Spec §RLS Policy Summary (ownership-write, partner-read conditions)
- PHASES.md Phase 1 in-scope: "RLS policies: ownership-write on all tables, partner-read conditions on daily_logs, period_logs, prediction_snapshots"
- cadence-privacy-architecture skill (is_private as master override, symptom_logs exclusion from partner queries)

## Scope

### In Scope

- Ownership policies (`owner_read`, `owner_insert`, `owner_update`, `owner_delete`) on: `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings`
- Ownership policies (`user_read`, `user_update`) on `users` (own row only; no insert/delete via RLS -- row created by trigger)
- Partner read policy on `daily_logs` with all four conditions: live connection in `partner_connections`, `is_paused = false`, at least one relevant `share_*` flag is `true` (`share_symptoms OR share_mood OR share_notes`), and `daily_logs.is_private = false`
- Partner read policy on `period_logs` with conditions: live connection, `is_paused = false`, `share_predictions = true`
- Partner read policy on `prediction_snapshots` with conditions: live connection, `is_paused = false`, `share_predictions = true OR share_phase = true`
- `partner_connections` read policy: Tracker reads own row (`tracker_id = auth.uid()`); Partner reads own row (`partner_id = auth.uid()`)
- `partner_connections` insert policy: Tracker only (`tracker_id = auth.uid()`)
- `partner_connections` update policy: Tracker only (`tracker_id = auth.uid()`)
- `partner_connections` delete policy: Tracker only (`tracker_id = auth.uid()`)
- Migration file `supabase/migrations/[timestamp]_rls-policies.sql` containing all policy definitions
- Deployment via `supabase db push` and verification with SQL queries against `pg_policies`

### Out of Scope

- `device_tokens` table policies (table deferred to Phase 10)
- Column-level security (not required for MVP; cadence-privacy-architecture skill handles column projection at the application layer)
- Policies that reference `auth.jwt()` claims for role determination -- role is stored in `users.role` and queried post-sign-in per cadence-supabase skill §8
- Supabase storage bucket policies (no file storage in Cadence MVP)
- Testing RLS policies with real authenticated sessions from iOS (Phase 3 integration testing)

## Dependencies

| Dependency                                             | Type | Phase/Epic | Status | Risk                                                              |
| ------------------------------------------------------ | ---- | ---------- | ------ | ----------------------------------------------------------------- |
| PH-1-E2 complete (all 8 tables exist with RLS enabled) | FS   | PH-1-E2    | Open   | High -- policies cannot be created on non-existent tables         |
| `partner_connections` unique index exists              | FS   | PH-1-E2-S2 | Open   | Medium -- policy correctness depends on the uniqueness constraint |

## Assumptions

- Every `auth.uid()` call in policies returns the authenticated user's UUID from the Supabase JWT. This is the canonical Supabase auth pattern -- no client-provided user IDs are ever used in policy conditions.
- The `daily_logs` partner-read policy uses `OR` across `share_symptoms`, `share_mood`, `share_notes` to grant row access when any of these categories is shared. Column projection (returning only the columns for enabled categories) is enforced at the service layer, not by RLS. This is the correct division of responsibility: RLS controls row access; service layer controls field exposure.
- Partners can read the `users` table for their own row only. No policy grants Partner read on the Tracker's `users` row. The Tracker's display name, if needed by the Partner UI, must be stored in `partner_connections` or fetched via a dedicated RPC.
- `symptom_logs` has no partner-read policy. Partners read symptom data by querying `daily_logs` (where RLS applies) and then fetching `symptom_logs` via an explicit JOIN in the service layer -- RLS on the JOIN source table (`daily_logs`) gates the entire read.
- The `cycle_profiles` table has no partner-read policy. The Partner sees phase and prediction data via `prediction_snapshots`, not raw cycle profile data.

## Risks

| Risk                                                                            | Likelihood | Impact | Mitigation                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Partner-read policy on `daily_logs` misses `is_private = false` condition       | Low        | High   | Acceptance criteria explicitly verify this condition via SQL query on `pg_policies`; cadence-supabase §3.6 checklist is mandatory before merge                                                                                  |
| `symptom_logs` inadvertently gets a partner-read policy in a future phase       | Medium     | High   | Document the exclusion explicitly in this epic; cadence-privacy-architecture skill enforces it at the application layer; add `SELECT * FROM pg_policies WHERE tablename = 'symptom_logs'` to the Phase 1 verification checklist |
| RLS policies cause performance regression on large daily_logs tables            | Low        | Medium | Indexes on `daily_logs(user_id, is_private)` and `partner_connections(tracker_id, partner_id)` mitigate query plan issues; Supabase database advisors flag missing indexes post-deployment                                      |
| Permissive policies (multiple SELECT policies) cause unintended additive access | Low        | High   | Each table uses a single SELECT policy per principal (owner, partner) -- never two SELECT policies on the same table for the same role unless they are strictly exclusive conditions                                            |

---

## Stories

### S1: Apply ownership policies to all user-owned tables

**Story ID:** PH-1-E3-S1
**Points:** 5

Create the four ownership policies (`owner_read`, `owner_insert`, `owner_update`, `owner_delete`) for `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, and `reminder_settings`. Apply ownership read and update policies to `users`. These policies form the security baseline: every user can read and write only their own rows.

**Acceptance Criteria:**

- [ ] Migration file `supabase/migrations/[timestamp]_rls-policies.sql` exists and contains all ownership policies
- [ ] For each of `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings`: exactly four policies exist (`owner_read`, `owner_insert`, `owner_update`, `owner_delete`), all using `auth.uid()` (never client-provided IDs)
- [ ] All `owner_read` policies use `FOR SELECT USING (user_id = auth.uid())`
- [ ] All `owner_insert` policies use `FOR INSERT WITH CHECK (user_id = auth.uid())`
- [ ] All `owner_update` policies use `FOR UPDATE USING (user_id = auth.uid())`
- [ ] All `owner_delete` policies use `FOR DELETE USING (user_id = auth.uid())`
- [ ] `users` table has `user_read` policy: `FOR SELECT USING (id = auth.uid())`
- [ ] `users` table has `user_update` policy: `FOR UPDATE USING (id = auth.uid())`
- [ ] `users` table has NO insert or delete policies (row creation is via trigger; deletion via service role only)
- [ ] `symptom_logs` uses `daily_log_id` to resolve `user_id` via subquery: ownership policy on `symptom_logs` checks `daily_log_id IN (SELECT id FROM daily_logs WHERE user_id = auth.uid())`
- [ ] `SELECT count(*) FROM pg_policies WHERE schemaname = 'public'` returns a count consistent with 4 policies per user-owned table + 2 policies on users (26 total at this stage)
- [ ] `supabase db push` exits 0 with no errors after this migration

**Dependencies:** PH-1-E2-S5

**Notes:** `symptom_logs` does not have a `user_id` column -- it uses `daily_log_id` as the FK to `daily_logs`. The ownership policies for `symptom_logs` must resolve to the owning user via a subquery on `daily_logs`. This is the correct pattern; do not add a `user_id` column to `symptom_logs` to simplify the policy. `WITH CHECK` on insert policies is the critical clause that prevents row injection attacks where a client inserts a row with a different `user_id` value.

---

### S2: Apply partner read policy on daily_logs

**Story ID:** PH-1-E3-S2
**Points:** 3

Create the partner-read SELECT policy on `daily_logs`. This is the most security-critical policy in the schema: it controls what health data a Partner can see on a per-entry basis. All four conditions must be simultaneously true for access to be granted.

**Acceptance Criteria:**

- [ ] Policy `partner_read_daily_logs` exists on `daily_logs` FOR SELECT
- [ ] The policy USING clause contains an EXISTS subquery on `partner_connections pc`
- [ ] The subquery contains `pc.tracker_id = daily_logs.user_id` (correct direction: tracker owns the log)
- [ ] The subquery contains `pc.partner_id = auth.uid()` (Partner is the authenticated user)
- [ ] The subquery contains `pc.is_paused = false` (global pause check)
- [ ] The subquery contains `(pc.share_symptoms = true OR pc.share_mood = true OR pc.share_notes = true)` (at least one relevant category shared)
- [ ] The subquery contains `daily_logs.is_private = false` (per-entry private flag)
- [ ] No policy on `daily_logs` uses `auth.jwt()` claims for role determination
- [ ] `SELECT policyname, qual FROM pg_policies WHERE tablename = 'daily_logs' AND policyname = 'partner_read_daily_logs'` returns the policy with all five conditions visible in the qual column
- [ ] A test in the Supabase SQL editor confirms: when `is_private = true`, a query with a simulated partner `auth.uid()` returns 0 rows even if all share flags are true and `is_paused = false`
- [ ] A test confirms: when `is_paused = true`, a query with a simulated partner `auth.uid()` returns 0 rows even if `is_private = false` and all share flags are true

**Dependencies:** PH-1-E3-S1

**Notes:** The `is_private` check appears inside the EXISTS subquery, not as an outer condition, to keep the entire access decision in one atomic evaluation. Placing `is_private` outside the subquery is semantically equivalent but harder to audit. The `(share_symptoms OR share_mood OR share_notes)` OR condition is intentional: the Row grants access if the Partner can see any part of the row's data. Column projection filtering happens at the service layer per the cadence-privacy-architecture skill -- this is the correct architectural boundary.

---

### S3: Apply partner read policies on period_logs and prediction_snapshots

**Story ID:** PH-1-E3-S3
**Points:** 3

Create partner-read SELECT policies on `period_logs` and `prediction_snapshots`. These two tables require fewer conditions than `daily_logs` (no per-entry `is_private` flag) but must still enforce the live-connection and is_paused checks. `prediction_snapshots` grants access when either `share_predictions` OR `share_phase` is enabled because predictions support both the countdown (share_predictions) and the phase label (share_phase) Partner Dashboard cards.

**Acceptance Criteria:**

- [ ] Policy `partner_read_period_logs` exists on `period_logs` FOR SELECT
- [ ] `partner_read_period_logs` USING clause: EXISTS on `partner_connections pc` with `pc.tracker_id = period_logs.user_id`, `pc.partner_id = auth.uid()`, `pc.is_paused = false`, `pc.share_predictions = true`
- [ ] Policy `partner_read_prediction_snapshots` exists on `prediction_snapshots` FOR SELECT
- [ ] `partner_read_prediction_snapshots` USING clause: EXISTS on `partner_connections pc` with `pc.tracker_id = prediction_snapshots.user_id`, `pc.partner_id = auth.uid()`, `pc.is_paused = false`, `(pc.share_predictions = true OR pc.share_phase = true)`
- [ ] Neither policy includes an `is_private` condition (period_logs and prediction_snapshots do not have an `is_private` column; privacy on these tables is enforced by `is_paused` and the share flags alone)
- [ ] `SELECT policyname FROM pg_policies WHERE tablename IN ('period_logs', 'prediction_snapshots') AND policyname LIKE 'partner_read%'` returns exactly two rows
- [ ] A test confirms: when `is_paused = true`, a query with simulated partner `auth.uid()` returns 0 rows from both `period_logs` and `prediction_snapshots`
- [ ] A test confirms: with `share_phase = true` and `share_predictions = false`, the partner CAN read `prediction_snapshots` (phase-only sharing)

**Dependencies:** PH-1-E3-S1

**Notes:** `period_logs` does not have `is_private`. Period data visibility is controlled entirely by `share_predictions`. If a Tracker shares predictions, their period history is accessible to the Partner because predictions are derived from period history -- withholding period logs while sharing predictions is architecturally inconsistent. The current schema does not support selective period history masking; this is a deliberate MVP scope decision.

---

### S4: Apply partner_connections access policies

**Story ID:** PH-1-E3-S4
**Points:** 2

Create the four access policies on `partner_connections` that enforce the connection ownership model: both Tracker and Partner can read their own connection row; only the Tracker can insert, update, or delete. This prevents a Partner from activating their own sharing flags or disconnecting the relationship unilaterally.

**Acceptance Criteria:**

- [ ] Policy `tracker_read_connection` exists on `partner_connections` FOR SELECT USING `(tracker_id = auth.uid())`
- [ ] Policy `partner_read_connection` exists on `partner_connections` FOR SELECT USING `(partner_id = auth.uid())`
- [ ] Policy `tracker_insert_connection` exists on `partner_connections` FOR INSERT WITH CHECK `(tracker_id = auth.uid())`
- [ ] Policy `tracker_update_connection` exists on `partner_connections` FOR UPDATE USING `(tracker_id = auth.uid())`
- [ ] Policy `tracker_delete_connection` exists on `partner_connections` FOR DELETE USING `(tracker_id = auth.uid())`
- [ ] No policy exists on `partner_connections` that allows a Partner to INSERT, UPDATE, or DELETE any row
- [ ] `SELECT count(*) FROM pg_policies WHERE tablename = 'partner_connections'` returns exactly 5
- [ ] A test confirms: a user authenticated as `partner_id` cannot UPDATE the `partner_connections` row (returns 0 rows affected or permission error)
- [ ] A test confirms: a user authenticated as `tracker_id` can SELECT the row
- [ ] A test confirms: a user authenticated as `partner_id` can SELECT the row

**Dependencies:** PH-1-E3-S1

**Notes:** The `partner_read_connection` policy is required: the Partner's onboarding flow (Phase 2) and the Partner Dashboard (Phase 9) need to read the connection row to determine sharing state and connection metadata. Without this policy, the Partner client cannot confirm their own connection state. The `tracker_insert_connection` policy is what enables invite code creation in Phase 8 -- the Tracker's client inserts a row with `invite_code` set and `partner_id = null`. The `redeem-invite` Edge Function in Phase 8 uses the service role key to update `partner_id`, bypassing RLS -- this is the intended and correct pattern per cadence-supabase skill §5.2.

---

### S5: RLS policy audit and coverage verification

**Story ID:** PH-1-E3-S5
**Points:** 2

Execute the cadence-supabase skill §3.6 RLS policy review checklist against every deployed policy. Verify total policy count, table coverage, and the absence of disallowed access patterns (symptom_logs partner read, cycle_profiles partner read, JWT-based role determination).

**Acceptance Criteria:**

- [ ] `SELECT tablename, policyname, cmd, qual FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname` returns a complete policy listing; reviewed against the expected policy inventory (documented inline in this story's Notes)
- [ ] `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = false` returns 0 rows (RLS enabled on every table)
- [ ] `SELECT policyname FROM pg_policies WHERE tablename = 'symptom_logs' AND policyname LIKE 'partner_read%'` returns 0 rows (no partner-read policy on symptom_logs)
- [ ] `SELECT policyname FROM pg_policies WHERE tablename = 'cycle_profiles' AND policyname LIKE 'partner_read%'` returns 0 rows (no partner-read policy on cycle_profiles)
- [ ] `SELECT policyname FROM pg_policies WHERE tablename = 'reminder_settings' AND policyname LIKE 'partner_read%'` returns 0 rows (no partner-read policy on reminder_settings)
- [ ] No policy USING or WITH CHECK clause contains `auth.jwt()` -- all policies use `auth.uid()`
- [ ] All partner-read policies on `daily_logs`, `period_logs`, `prediction_snapshots` contain `pc.is_paused = false` (verified via `pg_policies.qual` column)
- [ ] `partner_read_daily_logs` policy qual contains `is_private = false` (verified via `pg_policies.qual`)
- [ ] `supabase/migrations/[timestamp]_rls-policies.sql` committed to repository
- [ ] `scripts/protocol-zero.sh` exits 0 on the migration file
- [ ] `scripts/check-em-dashes.sh` exits 0 on the migration file

**Dependencies:** PH-1-E3-S1, PH-1-E3-S2, PH-1-E3-S3, PH-1-E3-S4

**Notes:** Expected policy inventory after this epic (32 total policies):

- `users`: user_read, user_update (2)
- `cycle_profiles`: owner_read, owner_insert, owner_update, owner_delete (4)
- `partner_connections`: tracker_read_connection, partner_read_connection, tracker_insert_connection, tracker_update_connection, tracker_delete_connection (5)
- `period_logs`: owner_read, owner_insert, owner_update, owner_delete, partner_read_period_logs (5)
- `daily_logs`: owner_read, owner_insert, owner_update, owner_delete, partner_read_daily_logs (5)
- `symptom_logs`: owner_read, owner_insert, owner_update, owner_delete (4)
- `prediction_snapshots`: owner_read, owner_insert, owner_update, owner_delete, partner_read_prediction_snapshots (5)
- `reminder_settings`: owner_read, owner_insert, owner_update, owner_delete (4)

Total: 34 policies. If the count differs, identify the discrepancy before declaring this story done.

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
- [ ] 34 RLS policies deployed and verified via pg_policies queries
- [ ] RLS enabled on all 8 tables (zero rows in pg_tables where rowsecurity=false)
- [ ] Phase objective is advanced: data access control enforced at the database layer
- [ ] cadence-supabase skill §3.6 checklist passed on every policy
- [ ] cadence-privacy-architecture skill constraints: is_private on daily_logs verified; symptom_logs has no partner-read policy; no JWT role claims used
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Migration file committed to `supabase/migrations/`; all policies applied via migration, not ad-hoc SQL

## Source References

- PHASES.md: Phase 1 -- Supabase Backend (in-scope: RLS policies ownership-write on all tables, partner-read 4-condition)
- MVP Spec §2 (partner sharing -- Supabase RLS Design; 4-condition partner read)
- MVP Spec §RLS Policy Summary (ownership-write, partner-read conditions per table)
- cadence-supabase skill §3 (complete RLS policy structure and exact SQL patterns)
- cadence-supabase skill §3.3 (is_private as master override)
- cadence-supabase skill §3.4 (is_paused as global override)
- cadence-supabase skill §3.5 (partner_connections write policy)
- cadence-supabase skill §3.6 (RLS policy review checklist)
- cadence-privacy-architecture skill (is_private override, Sex exclusion, Partner query projection, RLS alignment)
