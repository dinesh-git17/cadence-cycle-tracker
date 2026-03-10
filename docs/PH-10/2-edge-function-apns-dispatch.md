# Supabase Edge Function -- APNS Push Dispatch

**Epic ID:** PH-10-E2
**Phase:** 10 -- Notifications
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement the complete server-side APNS push dispatch pipeline: APNs JWT provider token generation, HTTP/2 dispatch to Apple's APNs endpoint, full error code handling with device token cleanup, and all three Partner notification dispatch conditions with their associated share flag and privacy guards. The Edge Function directory was scaffolded in Phase 1; this epic delivers the full implementation.

## Problem / Context

The Edge Function stub created in Phase 1 is a directory entry point with no logic. Partner push notifications -- the mechanism by which a connected Partner receives ambient cycle awareness without opening the app -- cannot fire until this backend system is live. The Edge Function is the only path from Cadence's Supabase backend to Apple's APNs infrastructure. It must authenticate with APNs using provider token authentication (ES256 JWT), correctly evaluate all three dispatch conditions against live share flags and privacy guards from `partner_connections` and `reminder_settings`, construct privacy-safe payloads (no PHI), and handle all documented APNs error codes including device token cleanup on `410 Unregistered`.

The `reminder_settings` schema deployed in Phase 1 lacks an `advance_days` integer column required by the "period expected in X days" notification. This epic applies that schema migration.

Sources: MVP Spec §9 (all three Partner notification types, controls), cadence-supabase skill (Edge Function APNS dispatch pattern), PHASES.md Phase 10 in-scope.

## Scope

### In Scope

- `reminder_settings` schema migration: add `advance_days integer NOT NULL DEFAULT 3` column
- APNs JWT provider token generation in Deno/TypeScript using `djwt` library: ES256 algorithm, 10-char Key ID header, 10-char Team ID issuer claim, `iat` set to current Unix timestamp UTC, module-scoped cache with 55-minute expiry (regenerate 5 minutes before the 1-hour APNs limit)
- APNs p8 private key stored as Supabase secret (`APNS_PRIVATE_KEY`); Team ID as `APNS_TEAM_ID`; Key ID as `APNS_KEY_ID`; bundle ID as `APNS_BUNDLE_ID`; all read from `Deno.env.get()`
- APNS HTTP/2 dispatch: `POST /3/device/<hex-token>` with required headers: `authorization: bearer <JWT>`, `apns-topic: <bundle-id>`, `apns-push-type: alert`, `apns-priority: 10`, `apns-expiration: 0`, `apns-collapse-id: <notification_type>:<tracker_user_id>`, `content-type: application/json`
- Sandbox endpoint: `api.sandbox.push.apple.com`; production endpoint: `api.push.apple.com`; routing based on `environment` column in `device_tokens`
- APNs error code handling: `400 BadDeviceToken` (delete token row), `403 ExpiredProviderToken` (regenerate JWT, retry once), `403 InvalidProviderToken` (log + halt, do not retry), `410 Unregistered` (delete token row, do not retry), `429 TooManyRequests` (exponential backoff, max 3 attempts per cadence-sync retry contract), `503` (exponential backoff, max 3 attempts)
- Payload structure: `{"aps":{"alert":{"title":"...","body":"..."},"sound":"default","thread-id":"<partner_user_id>","badge":1},"cadence_notification_type":"<type_enum>"}` -- zero PHI in payload
- Dispatch condition 1: "period expected in X days" -- triggers when `prediction_snapshots` row is inserted/updated for a Tracker; evaluates `DATEDIFF(next_period_start, NOW()) <= advance_days`; checks `notify_partner_period = true` on Tracker's `reminder_settings`; checks `is_paused = false` and `share_predictions = true` on `partner_connections`; checks Partner's `notify_partner_period = true` (mute check)
- Dispatch condition 2: "symptom logged today" -- triggers on `daily_logs` INSERT; evaluates `is_private = false`; checks `share_symptoms = true` on `partner_connections`; checks `notify_partner_symptoms = true` on Tracker's `reminder_settings`; checks Partner's `notify_partner_symptoms = true` (mute check); Sex symptom (`symptom_type = 'sex'`) is ALWAYS excluded from payload and from dispatch trigger evaluation regardless of share flags
- Dispatch condition 3: "fertile window starts tomorrow" -- triggers when `prediction_snapshots` row is inserted/updated; evaluates `DATEDIFF(fertile_window_start, NOW()) = 1`; checks `notify_partner_fertile = true` on Tracker's `reminder_settings`; checks `share_fertile_window = true` on `partner_connections`; checks Partner's `notify_partner_fertile = true` (mute check)
- Database webhook trigger registration for each condition (on `prediction_snapshots` upsert and `daily_logs` insert)
- Partner `device_tokens` lookup: join `partner_connections.partner_id` to `device_tokens.user_id`; dispatch to all rows for that partner (multi-device support)

### Out of Scope

- Tracker local reminder scheduling (PH-10-E3) -- local notifications use `UNUserNotificationCenter`, not the Edge Function
- Notification content specification beyond the copy patterns defined in MVP Spec §9 and PHASES.md in-scope (grouping logic beyond `thread-id` per `partner_user_id` is the §15 open item; see Notes)
- AlarmKit -- not used; standard APNs `alert` push type is the delivery mechanism for all Partner notification types
- Notification history persistence -- Partner notification history is derived from `UNUserNotificationCenter.getDeliveredNotifications()` on the client (PH-10-E5)
- Any Supabase extension beyond the standard Postgres + Edge Functions stack

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| Edge Function directory scaffold exists in Phase 1 | FS | PH-1 | Resolved | Low |
| `reminder_settings` table deployed (Phase 1) | FS | PH-1 | Resolved | Low |
| `partner_connections` table deployed with share flags (Phase 1) | FS | PH-1 | Resolved | Low |
| `device_tokens` table deployed (PH-10-E1-S3) | FS | PH-10-E1 | Open | Medium |
| APNs p8 key, Team ID, Key ID provisioned in Apple Developer Portal | External | Apple Developer Portal | Open | High |
| Supabase secrets configured: APNS_PRIVATE_KEY, APNS_TEAM_ID, APNS_KEY_ID, APNS_BUNDLE_ID | External | Supabase project config | Open | High |
| Live partner connection with `is_paused = false` (Phase 8) | FS | PH-8 | Open | Low |
| Database webhook support enabled on Supabase project | External | Supabase project config | Open | Medium |

## Assumptions

- Supabase Edge Functions run on Deno 1.x. The `djwt` library (`https://deno.land/x/djwt`) is used for ES256 JWT generation. `jose` is not used due to documented Deno edge environment CryptoKey compatibility issues as of Q1 2026.
- The Partner's `reminder_settings` row is seeded with default values (`notify_partner_period = true`, `notify_partner_symptoms = true`, `notify_partner_fertile = true`) when the Partner accepts a connection invitation in Phase 8. If no row exists for the Partner, the Edge Function treats it as "not muted" (dispatch proceeds).
- Notification copy strings are defined in the Edge Function as constants, not fetched from a database. They match the patterns in MVP Spec §9 exactly: "Her period is expected in {X} days", "She logged {symptom} today", "Her fertile window starts tomorrow".
- The `advance_days` default of 3 is the initial value. Users configure this via E4 UI.
- Multi-device dispatch: if a Partner has tokens for 2 devices, the Edge Function dispatches to both. A failure on one token does not block the other.
- Database webhook events fire within 5 seconds of the originating row mutation under normal Supabase load. This is not a hard guarantee; no SLA is asserted.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| APNs p8 key not available in Supabase secrets at implementation time | High | High | S2 (JWT generation) can be built and unit-tested with a mock key. End-to-end dispatch (S3) requires the real key. Flag to Dinesh at phase start. All APNs calls are gated behind sandbox endpoint for development. |
| `djwt` ES256 signing produces malformed JWT accepted locally but rejected by APNs | Medium | High | Test JWT validity against APNs sandbox before building dispatch conditions. `403 InvalidProviderToken` response is the failure signal. |
| `410 Unregistered` flood on test cohort device reinstalls | Medium | Medium | S4 token cleanup is idempotent (DELETE WHERE apns_token = :token); duplicate deletes are no-ops. |
| Partner has no `reminder_settings` row (connection accepted but row not seeded in Phase 8) | Medium | Low | Edge Function treats absent row as "not muted"; see Assumptions. This is a defensive default that errs toward delivery. |
| Database webhook latency exceeds 30 seconds under Supabase load | Low | Low | Partner notifications are ambient awareness, not time-critical alerts. 30-second delivery delay is acceptable for beta. |
| `notify_partner_symptoms` true but Sex symptom inadvertently included in dispatch condition evaluation | Low | High | S6 includes an explicit `WHERE symptom_type != 'sex'` guard in both the trigger condition and the payload construction. This is covered by a dedicated acceptance criterion. |

---

## Stories

### S1: reminder_settings Schema Migration -- advance_days Column

**Story ID:** PH-10-E2-S1
**Points:** 2

Apply a Supabase migration that adds `advance_days integer NOT NULL DEFAULT 3` to the `reminder_settings` table. This column stores how many days before the predicted period start the "period expected in X days" Tracker reminder and Partner notification fire.

**Acceptance Criteria:**

- [ ] Migration applies cleanly against the live Supabase project with no downtime to existing rows
- [ ] `reminder_settings.advance_days` column exists with type `integer`, NOT NULL constraint, and DEFAULT 3
- [ ] Existing `reminder_settings` rows have `advance_days = 3` after migration
- [ ] Migration is idempotent: running it twice does not error
- [ ] `CHECK (advance_days BETWEEN 1 AND 7)` constraint is present (configurable range matches E4 UI stepper)

**Dependencies:** PH-1 (reminder_settings table exists)
**Notes:** The range 1-7 days is the configurable window defined by PHASES.md in-scope ("configurable advance days"). The UI in E4-S3 enforces this range via a stepper; the DB constraint is a belt-and-suspenders guard.

---

### S2: APNs JWT Provider Token Generation

**Story ID:** PH-10-E2-S2
**Points:** 5

Implement APNs JWT provider token generation in Deno/TypeScript. The JWT must use ES256, include `kid` (Key ID) in the header, `iss` (Team ID) and `iat` (current UTC Unix timestamp) in the payload. Cache the generated token at module scope and regenerate only when within 5 minutes of the 1-hour expiry. Read the p8 key, Team ID, Key ID, and bundle ID from Supabase secrets via `Deno.env.get()`.

**Acceptance Criteria:**

- [ ] JWT header is `{"alg":"ES256","kid":"<10-char-key-id>"}`
- [ ] JWT payload is `{"iss":"<10-char-team-id>","iat":<unix-timestamp-utc>}`
- [ ] JWT is signed using the ES256 algorithm with the p8 private key content from `Deno.env.get("APNS_PRIVATE_KEY")`
- [ ] A module-scoped variable caches `{token: string, generatedAt: number}`. On each invocation, if `Date.now() - generatedAt < 55 * 60 * 1000` (55 minutes), the cached token is returned without regeneration
- [ ] If the cached token is absent or older than 55 minutes, a new JWT is generated and the cache is updated
- [ ] `APNS_PRIVATE_KEY`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_BUNDLE_ID` are read exclusively from `Deno.env.get()`; no hardcoded values
- [ ] Unit test (Deno test): generated JWT decodes correctly (header `alg=ES256`, `kid` matches env var, `iss` matches env var, `iat` within 5 seconds of `Date.now() / 1000`)

**Dependencies:** PH-10-E1-S3 (device_tokens migration establishes context; JWT generation itself has no runtime dependency on device tokens)
**Notes:** Do not use `jose` for APNS JWT signing in Deno. Use `djwt` (`https://deno.land/x/djwt`). The p8 key content includes the `-----BEGIN PRIVATE KEY-----` header/footer; strip these before passing to the signing function per `djwt` requirements.

---

### S3: APNS HTTP/2 Dispatch Core

**Story ID:** PH-10-E2-S3
**Points:** 5

Implement the `dispatchAPNS(token: string, environment: string, payload: APNSPayload): Promise<APNSResult>` function. Construct the request with all required headers, POST to the correct APNs endpoint based on `environment`, and return a typed result containing the HTTP status code and parsed response body.

**Acceptance Criteria:**

- [ ] `dispatchAPNS` POSTs to `https://api.sandbox.push.apple.com/3/device/<token>` when `environment === 'sandbox'`
- [ ] `dispatchAPNS` POSTs to `https://api.push.apple.com/3/device/<token>` when `environment === 'production'`
- [ ] Request includes headers: `authorization: bearer <JWT>` (from S2), `apns-topic: <APNS_BUNDLE_ID>`, `apns-push-type: alert`, `apns-priority: 10`, `apns-expiration: 0`, `content-type: application/json`
- [ ] `apns-collapse-id` header is set to `<notification_type>:<tracker_user_id>` (max 64 bytes; values that exceed 64 bytes are truncated)
- [ ] Payload JSON structure: `{"aps":{"alert":{"title":"Cadence","body":"<message>"},"sound":"default","thread-id":"<partner_user_id>","badge":1},"cadence_notification_type":"<type_enum>"}` -- no PHI fields present
- [ ] Payload does NOT include cycle phase name, period dates, symptom names, sex log data, fertility scores, or any field from the privacy-protected domain
- [ ] `dispatchAPNS` returns `{status: number, reason?: string}` for all response codes
- [ ] Function does not throw on HTTP 4xx/5xx; caller handles errors via returned status

**Dependencies:** PH-10-E2-S2
**Notes:** `fetch()` in Deno supports HTTP/2 natively. No third-party HTTP client is required. The `badge` value is set to `1` as a static increment signal; the client resets badge count on app open (PH-10-E5-S4 handles badge reset).

---

### S4: APNs Error Code Handling and Device Token Cleanup

**Story ID:** PH-10-E2-S4
**Points:** 3

Implement `handleAPNSResponse(result: APNSResult, token: string, userId: string)` that acts on the APNs HTTP response. Token cleanup operations use the Supabase service role client (bypasses RLS). Retry logic follows the cadence-sync retry contract: max 3 attempts, exponential backoff with jitter.

**Acceptance Criteria:**

- [ ] HTTP `200`: no action; function returns successfully
- [ ] HTTP `400` with reason `BadDeviceToken`: issues `DELETE FROM device_tokens WHERE apns_token = :token AND user_id = :userId`; does not retry dispatch
- [ ] HTTP `403` with reason `ExpiredProviderToken`: calls JWT regeneration (clears module-scope cache, forces S2 to regenerate), retries the dispatch exactly once; if the retry also returns `403`, logs the error and halts
- [ ] HTTP `403` with reason `InvalidProviderToken`: logs the specific reason string, halts without retry (indicates a misconfigured p8 key -- retrying is futile)
- [ ] HTTP `410` with reason `Unregistered`: issues `DELETE FROM device_tokens WHERE apns_token = :token`; does not retry dispatch
- [ ] HTTP `429`: waits `min(attempt * 2, 8)` seconds with jitter `(Math.random() * 0.5)`, retries up to 3 total attempts; if all 3 fail with `429`, logs and halts
- [ ] HTTP `503`: same backoff pattern as `429`; 3 total attempts max
- [ ] Unit test: mock `dispatchAPNS` returning `410` -- verify `device_tokens` DELETE is called with correct token value

**Dependencies:** PH-10-E2-S3, PH-10-E1-S3 (device_tokens table exists for DELETE operations)
**Notes:** The Supabase service role key is stored as `APNS_SUPABASE_SERVICE_KEY` in Edge Function secrets. Token cleanup uses `supabase-js` initialized with service role key -- NOT the user-scoped anon key.

---

### S5: "Period Expected in X Days" Dispatch Condition

**Story ID:** PH-10-E2-S5
**Points:** 5

Implement the dispatch condition that fires a Partner push notification when the Tracker's period is predicted to start within `advance_days` days. Triggered by database webhook on `prediction_snapshots` INSERT or UPDATE. Evaluates all required conditions before calling `dispatchAPNS`.

**Acceptance Criteria:**

- [ ] Webhook fires on `prediction_snapshots` INSERT and UPDATE
- [ ] Function evaluates: `DATE_PART('day', next_period_start - NOW()::date) = advance_days` (integer equality, not a range)
- [ ] Function looks up Tracker's `reminder_settings.notify_partner_period` -- if `false`, dispatch is skipped
- [ ] Function looks up `partner_connections` for the Tracker: checks `is_paused = false` AND `share_predictions = true`; if either condition fails, dispatch is skipped
- [ ] Function looks up Partner user ID from `partner_connections.partner_id`
- [ ] Function looks up Partner's `reminder_settings.notify_partner_period` -- if `false`, dispatch is skipped (Partner mute check)
- [ ] If no `partner_connections` row exists for the Tracker, function exits without error
- [ ] Notification body is: `"Her period is expected in {advance_days} days"` where `{advance_days}` is the integer value from the Tracker's `reminder_settings.advance_days`
- [ ] `cadence_notification_type` in payload is `"period_prediction"`
- [ ] Dispatch is called for each `device_tokens` row associated with the Partner user ID (multi-device)
- [ ] Unit test: mock `prediction_snapshots` row with `next_period_start = TODAY + 3`, Tracker `advance_days = 3`, all flags true -- verify `dispatchAPNS` is called with correct payload

**Dependencies:** PH-10-E2-S3, PH-10-E2-S4, PH-10-E2-S1 (advance_days column)
**Notes:** The condition uses integer equality (`= advance_days`) not `<=`. This prevents duplicate notifications on consecutive days. The webhook fires daily on prediction updates -- if the prediction updates and the day delta matches `advance_days`, exactly one notification fires.

---

### S6: "Symptom Logged Today" Dispatch Condition

**Story ID:** PH-10-E2-S6
**Points:** 5

Implement the dispatch condition that fires a Partner push notification when the Tracker logs a symptom. Triggered by database webhook on `daily_logs` INSERT. The Sex symptom type is unconditionally excluded from dispatch evaluation regardless of any share flag state. This is a privacy enforcement requirement, not a configuration option.

**Acceptance Criteria:**

- [ ] Webhook fires on `daily_logs` INSERT
- [ ] If `daily_logs.is_private = true`, dispatch is skipped regardless of all other conditions
- [ ] Symptom type `'sex'` is excluded from dispatch: if the only logged symptom(s) are of type `'sex'`, the function exits without dispatch; if a mix of symptoms includes `'sex'`, `'sex'` is excluded from the notification body and the remaining symptoms trigger dispatch normally
- [ ] Function checks `partner_connections.share_symptoms = true` -- if false, dispatch is skipped
- [ ] Function checks `partner_connections.is_paused = false` -- if true (paused), dispatch is skipped
- [ ] Function checks Tracker's `reminder_settings.notify_partner_symptoms = true` -- if false, dispatch is skipped
- [ ] Function checks Partner's `reminder_settings.notify_partner_symptoms = true` -- if false, dispatch is skipped (mute check)
- [ ] Notification body is: `"She logged {symptom_name} today"` where `{symptom_name}` is the first non-sex symptom name in the logged set (plain language, not a medical term)
- [ ] `cadence_notification_type` in payload is `"symptom_logged"`
- [ ] Payload body does NOT contain the string "sex" or any sex-derived term under any code path
- [ ] Unit test: mock `daily_logs` row with `symptom_type = 'sex'` -- verify `dispatchAPNS` is never called
- [ ] Unit test: mock `daily_logs` row with mixed symptoms including `'sex'` and `'cramps'` -- verify `dispatchAPNS` is called with body mentioning `'cramps'` only

**Dependencies:** PH-10-E2-S3, PH-10-E2-S4
**Notes:** The Sex symptom exclusion is a cadence-privacy-architecture enforcement rule, not a user preference. It cannot be overridden by any Tracker setting. The acceptance criteria for the sex exclusion must be tested explicitly.

---

### S7: "Fertile Window Starts Tomorrow" Dispatch Condition

**Story ID:** PH-10-E2-S7
**Points:** 3

Implement the dispatch condition that fires a Partner push notification when the Tracker's predicted fertile window starts the following day. Triggered by database webhook on `prediction_snapshots` INSERT or UPDATE.

**Acceptance Criteria:**

- [ ] Webhook fires on `prediction_snapshots` INSERT and UPDATE
- [ ] Function evaluates: `DATE_PART('day', fertile_window_start - NOW()::date) = 1` (fires exactly 1 day before)
- [ ] Function checks `partner_connections.share_fertile_window = true` -- if false, dispatch is skipped
- [ ] Function checks `partner_connections.is_paused = false` -- if true, dispatch is skipped
- [ ] Function checks Tracker's `reminder_settings.notify_partner_fertile = true` -- if false, dispatch is skipped
- [ ] Function checks Partner's `reminder_settings.notify_partner_fertile = true` -- if false, dispatch is skipped (mute check)
- [ ] Notification body is exactly: `"Her fertile window starts tomorrow"`
- [ ] `cadence_notification_type` in payload is `"fertile_window"`
- [ ] If `prediction_snapshots.fertile_window_start` is null (prediction confidence insufficient), function exits without dispatch
- [ ] Unit test: mock `prediction_snapshots` row with `fertile_window_start = TOMORROW`, all flags true -- verify `dispatchAPNS` is called with correct body

**Dependencies:** PH-10-E2-S3, PH-10-E2-S4
**Notes:** The `fertile_window_start` null guard is required because the prediction engine (Phase 3) only populates fertile window when prediction confidence is `medium` or `high`. A `low` confidence snapshot may have a null `fertile_window_start`.

---

## Story Point Reference

| Points | Meaning |
| --- | --- |
| 1 | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour. |
| 2 | Small. One component or function, minimal unknowns. Half a day. |
| 3 | Medium. Multiple files, some integration. One day. |
| 5 | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8 | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days. |
| 13 | Very large. Should rarely appear. If it does, consider splitting the story. A week. |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration with dependencies verified end-to-end
- [ ] Phase objective is advanced: all three Partner notification types dispatch correctly when conditions are met; none dispatch when conditions are not met
- [ ] Applicable skill constraints satisfied: cadence-supabase (Edge Function pattern, service role access, RLS alignment), cadence-privacy-architecture (Sex symptom exclusion verified by acceptance tests, is_private guard present, no PHI in payload), cadence-sync (retry contract: 3 attempts, exponential backoff with jitter)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Sex symptom exclusion verified by at least two unit tests (sex-only log, mixed log)
- [ ] APNs sandbox end-to-end test: a real Partner device receives all three notification types when conditions are met
- [ ] 410 Unregistered token cleanup verified: stale token row is deleted after simulated 410 response
- [ ] No hardcoded p8 key, Team ID, Key ID, or bundle ID in source
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §9, cadence-privacy-architecture skill Sex exclusion rule, cadence-supabase skill Edge Function pattern

## Source References

- PHASES.md: Phase 10 -- Notifications (in-scope: Supabase Edge Function implementation, all three Partner notification types, all dispatch conditions, privacy-safe payloads, Partner mute controls)
- MVP Spec §9: Reminders and Notifications (Partner notification types and copy patterns, Tracker controls, Partner mute controls)
- MVP Spec Data Model: `reminder_settings` table schema (advance_days migration), `partner_connections` share flags, `prediction_snapshots` columns
- cadence-supabase skill: Edge Function APNS dispatch pattern, service role key usage
- cadence-privacy-architecture skill: isPrivate master override, Sex symptom exclusion, Partner-facing query column projection
- Design Spec v1.1 §15: Notification content specification (open item -- grouping logic; copy patterns are specified in MVP Spec §9 and PHASES.md in-scope; `thread-id` per `partner_user_id` is used as grouping key pending designer confirmation of §15 resolution)
