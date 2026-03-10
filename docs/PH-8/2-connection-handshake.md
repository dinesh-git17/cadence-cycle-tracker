# Connection Handshake & Confirmation Screen

**Epic ID:** PH-8-E2
**Phase:** 8 -- Partner Connection & Privacy Architecture
**Estimated Size:** L
**Status:** Draft

---

## Objective

Wire the Phase 2 Partner onboarding code entry screen to the live Supabase `partner_connections` table: validate the entered code against the database, write the Partner's user ID to the pending row, surface the Tracker a confirmation screen that lists exactly what the Partner will and will not see, and finalize or deny the connection on Tracker action. After this epic, a Partner can complete their onboarding and a Tracker-Partner pair is provably connected with a live `connected_at` timestamp in Supabase.

## Problem / Context

Phase 2 built the Partner onboarding code entry screen (`PartnerOnboardingCodeEntryView`) as a navigational stub. Without this epic, entering a valid code produces no Supabase state change -- no connection is established and no data flows. The Phase 9 Partner Dashboard cannot render anything meaningful until a row with `connected_at IS NOT NULL` exists, because every RLS read policy on `daily_logs`, `period_logs`, and `prediction_snapshots` requires a live connection row as its first condition.

The confirmation screen is a product-level informed-consent mechanism. MVP Spec §2 states: "Before connection finalises, Tracker sees a confirmation screen: 'Dinesh will be able to see: [list]. He will not see: [restricted categories].' Tracker confirms. Connection is live." Since all `share_*` flags default to false (Phase 8 E1 invariant), the confirmation screen will always show all six categories in the "will not see" list on first connection. The Tracker explicitly accepts this before the Partner gains any access -- even empty access.

The bilateral nature of the flow (Partner acts first, Tracker must respond) requires the Tracker's client to detect when a Partner has written their `partner_id` to the pending row. Phase 7 established a Realtime subscription channel on `partner_connections`. This epic subscribes to that channel specifically for the connection confirmation trigger.

**Source references that define scope:**

- MVP Spec §2 (Partner Sharing -- Connection Flow, step-by-step bilateral handshake; confirmation screen copy)
- MVP Spec §2 (Data Model: `partner_connections` -- `invite_code`, `partner_id`, `connected_at` semantics)
- cadence-privacy-architecture skill §1 and §6 (RLS policy requires live connection row; connection proof is `connected_at IS NOT NULL`)
- Design Spec v1.1 §8 (Information Architecture -- Partner navigation shell context)
- cadence-sync skill (Realtime subscription lifecycle -- `partner_connections` channel)
- PHASES.md Phase 8 in-scope: "Partner onboarding code validation (wired to Phase 2 Partner onboarding screen); pre-connection confirmation screen (lists what Partner will and will not see per current permission state)"

## Scope

### In Scope

- `PartnerConnectionStore.validateInviteCode(_ code: String) async throws -> PartnerCodeValidationResult` (extends store from E1): queries `partner_connections` with `.eq("invite_code", code).gt("expires_at", ISO8601Now).is("partner_id", nil)` (case-insensitive code match); returns `PartnerCodeValidationResult` enum: `.valid(trackerUserId: UUID)`, `.expired`, `.alreadyUsed`, `.notFound`
- `PartnerOnboardingCodeEntryView` (Phase 2 stub) wired to `PartnerConnectionStore.validateInviteCode`: on `.valid`, proceed to pending state; inline error text per validation failure case (no toast -- inline form error per Design Spec §13 pattern for input validation)
- `PartnerConnectionStore.submitCode(_ code: String) async throws` (Partner-side method): updates `partner_connections SET partner_id = auth.uid() WHERE invite_code = code AND partner_id IS NULL`; on success, sets `connectionStatus = .pendingConfirmation`; Partner client transitions to a "Waiting for confirmation" view
- Partner "Waiting for confirmation" view: renders a `DataCard` with "Waiting for [your partner] to confirm" body text in `body` + `CadenceTextSecondary`; animated `ProgressView` (gated on `!accessibilityReduceMotion`); no timeout UI in this phase (beta assumption: Tracker will open the app promptly)
- Tracker-side Realtime detection: `PartnerConnectionStore` (Tracker role) subscribes to the `partner_connections` Realtime channel (Phase 7) filtering on `tracker_id = auth.uid()`; on receiving an UPDATE event where the payload has `partner_id != null` and `connected_at == null`, routes to `ConnectionConfirmationView` -- either by presenting a sheet or by updating a `pendingConfirmationPartnerUserId` published property that `TrackerShell` observes
- `Cadence/Views/Settings/ConnectionConfirmationView.swift`: heading "Your partner wants to connect" in `title2` + CadenceTextPrimary; two sections rendered from `PartnerConnectionStore.activePermissions` -- "They will see:" (enabled `share_*` categories, empty if all off) and "They will not see:" (disabled categories); each item displays the category `displayName` from `PermissionCategory` (E3 builds that enum; E2 can hardcode the names inline with a TODO note for E3 replacement, or implement the string table directly); "Confirm" Primary CTA Button + "Deny" plain text destructive link
- `PartnerConnectionStore.finalizeConnection() async throws` (Tracker-side): updates `partner_connections SET connected_at = now(), invite_code = null WHERE tracker_id = auth.uid() AND partner_id IS NOT NULL AND connected_at IS NULL`; sets `connectionStatus = .active`
- `PartnerConnectionStore.denyConnection() async throws` (Tracker-side): deletes `partner_connections` row where `tracker_id = auth.uid()` and `partner_id IS NOT NULL` and `connected_at IS NULL`; resets `connectionStatus = .none`; clears `pendingConfirmationPartnerUserId`
- Partner client handles Realtime row deletion (denial): when the subscribed `partner_connections` row is deleted while in `.pendingConfirmation` status, the Partner's `connectionStatus` reverts to `.none`; the waiting view transitions to "Connection was not accepted. Please check with your partner and try again." with a "Start over" CTA
- Error handling: network failure during `validateInviteCode` shows a non-blocking toast (Design Spec §13 error pattern: `CadenceTextSecondary` + `warning.fill` SF Symbol); network failure during `submitCode` or `finalizeConnection` reverts local state and shows the same toast pattern
- `project.yml` updated with entries for `ConnectionConfirmationView.swift` and any new supporting files; `xcodegen generate` exits 0

### Out of Scope

- Partner Dashboard UI rendering after connection is live -- PH-9
- Permission toggles on the confirmation screen (the screen shows current share\_\* state but provides no editing UI in-flow -- Tracker uses the permission management surface from E3 post-connection)
- Push notification to Tracker when Partner enters the code -- Phase 10 (beta: Realtime or app-open detection is sufficient)
- Partner's "Notifications" tab content -- Phase 9
- The Settings navigation tree that deep-links to the confirmation screen -- Phase 12 (the view is built here; routing is Phase 12)

## Dependencies

| Dependency                                                                         | Type | Phase/Epic | Status | Risk                                                                                                            |
| ---------------------------------------------------------------------------------- | ---- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------- |
| `PartnerConnectionStore` initial shape and invite code row exist                   | FS   | PH-8-E1    | Open   | Low -- E1 is a hard prerequisite                                                                                |
| Realtime channel subscribed to `partner_connections` changes                       | FS   | PH-7       | Open   | Medium -- if Phase 7 Realtime is incomplete, Tracker-side detection must fall back to polling on app foreground |
| `PartnerOnboardingCodeEntryView` exists as navigational stub                       | FS   | PH-2       | Open   | Low                                                                                                             |
| Auth session for both Tracker and Partner producing `auth.uid()`                   | FS   | PH-2       | Open   | Low                                                                                                             |
| RLS policy: Partner can update `partner_connections` to set their own `partner_id` | FS   | PH-1       | Open   | Low                                                                                                             |

## Assumptions

- The Phase 7 Realtime subscription on `partner_connections` delivers UPDATE events to the Tracker client within a few seconds of the Partner writing their `partner_id`. In a degraded Realtime connection, the Tracker sees the confirmation on next app foreground (acceptable for beta).
- The confirmation screen shows the Partner's display name if available from the `users` table. If not available, falls back to "Your partner". No profile photo or additional Partner metadata is needed.
- A denied connection is fully terminal -- the Partner must start over with a new code from the Tracker. There is no "retry" path from the Partner's existing pending state; they re-enter onboarding with a new code.
- `invite_code` is set to null on finalization as a one-time-use enforcement mechanism. RLS must allow Tracker to null this field -- confirm with Phase 1 RLS policy.

## Risks

| Risk                                                                                | Likelihood | Impact                                                 | Mitigation                                                                                                                                                                                                |
| ----------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 7 Realtime not yet active when Phase 8 begins                                 | Medium     | Medium -- Tracker-side confirmation trigger is delayed | Implement polling fallback: on `PartnerConnectionStore` init with `.pendingCode` status, re-query the row on every app foreground event to detect `partner_id` population                                 |
| Race condition: Tracker finalizes and Partner's `submitCode` arrives simultaneously | Low        | Medium -- two competing writes on the same row         | The `submitCode` write is conditional on `partner_id IS NULL`; the `finalizeConnection` write sets `connected_at` -- only one sequencing produces a valid state; database constraint handles the conflict |
| Confirmation screen name display requires an extra `users` table query              | Low        | Low                                                    | Query `users.display_name` (or similar) for the `partner_id` after `submitCode` succeeds; cache on `PartnerConnectionStore.pendingPartnerName`                                                            |

---

## Stories

### S1: Code Validation Service + PartnerOnboarding Wire-Up

**Story ID:** PH-8-E2-S1
**Points:** 3

Implement `PartnerConnectionStore.validateInviteCode(_ code: String) async throws -> PartnerCodeValidationResult` and wire it to the Phase 2 `PartnerOnboardingCodeEntryView` "Continue" CTA. The view must show inline error messages for each validation failure case.

**Acceptance Criteria:**

- [ ] `PartnerCodeValidationResult` enum has exactly four cases: `.valid(trackerUserId: UUID)`, `.expired`, `.alreadyUsed`, `.notFound`
- [ ] `validateInviteCode` queries `partner_connections` with conditions `invite_code = input`, `expires_at > now()`, `partner_id IS NULL`; a row that fails the `expires_at` condition returns `.expired`; a row with `partner_id IS NOT NULL` returns `.alreadyUsed`; no row returns `.notFound`
- [ ] `PartnerOnboardingCodeEntryView` "Continue" CTA becomes active only when the text field contains exactly 6 decimal digits
- [ ] Inline error text appears below the text field for each failure case: "Code expired" for `.expired`, "Code already used" for `.alreadyUsed`, "Code not found" for `.notFound`
- [ ] Network failure during validation shows a non-blocking toast (not an inline error); local validation state resets to allow re-attempt
- [ ] Unit test: mock returning a valid row for code "042781" produces `.valid(trackerUserId: UUID)`
- [ ] Unit test: mock returning a row with `expires_at` in the past produces `.expired`

**Dependencies:** PH-8-E1-S2 (PartnerConnectionStore exists)
**Notes:** The query uses `gt("expires_at", ISO8601DateFormatter().string(from: Date()))`. The Partner's code entry view strips spaces and ignores case before sending to `validateInviteCode`.

---

### S2: Pending partner_id Write + Partner Waiting State

**Story ID:** PH-8-E2-S2
**Points:** 3

Implement `PartnerConnectionStore.submitCode(_ code: String) async throws` (Partner-side): updates the `partner_connections` row to set `partner_id = auth.uid()`, transitions `connectionStatus` to `.pendingConfirmation`, and renders the "Waiting for confirmation" view.

**Acceptance Criteria:**

- [ ] `submitCode` issues `supabase.from("partner_connections").update(["partner_id": auth.uid()]).eq("invite_code", code).is("partner_id", nil)` -- the conditional `is("partner_id", nil)` prevents a second Partner from overwriting an already-submitted `partner_id`
- [ ] On success, `connectionStatus` transitions to `.pendingConfirmation` on the main actor
- [ ] Partner navigates to a "Waiting for confirmation" view: `DataCard` with "Waiting for your partner to confirm" in `body` + `CadenceTextSecondary`, animated `ProgressView` (suppressed to static under `accessibilityReduceMotion`)
- [ ] On Supabase write failure, `connectionStatus` remains unchanged, error toast is shown, and Partner can re-tap "Continue" to retry
- [ ] Unit test: mock returning a successful update produces `connectionStatus == .pendingConfirmation`
- [ ] Unit test: mock returning zero rows affected (race: another Partner claimed the code first) throws `PartnerConnectionError.codeConflict`

**Dependencies:** PH-8-E2-S1
**Notes:** `submitCode` is called from the Partner context only. `PartnerConnectionStore` must detect role context (or use a separate Partner-scoped store subclass / method group) to avoid calling this method from a Tracker session.

---

### S3: Tracker Realtime Detection of Pending Connection

**Story ID:** PH-8-E2-S3
**Points:** 3

Subscribe the Tracker's `PartnerConnectionStore` to the `partner_connections` Realtime channel (Phase 7) and route the Tracker to `ConnectionConfirmationView` when an UPDATE event arrives with `partner_id != null` and `connected_at == null` on their row.

**Acceptance Criteria:**

- [ ] `PartnerConnectionStore` subscribes to the Phase 7 Realtime channel on `partner_connections` filtered to `tracker_id = auth.uid()` when `connectionStatus == .pendingCode(...)` (only subscribe while waiting; unsubscribe on state change)
- [ ] On receiving an UPDATE Realtime event where the payload contains `partner_id != null` and `connected_at == null`, `PartnerConnectionStore` sets `pendingConfirmationDetected = true` (or equivalent published state that triggers routing)
- [ ] `TrackerShell` observes `pendingConfirmationDetected` and presents `ConnectionConfirmationView` as a `.sheet` with `.presentationDetents([.large])`
- [ ] Fallback: if the Tracker opens the app (foreground transition) while `connectionStatus == .pendingCode(...)`, `PartnerConnectionStore` re-queries the row and transitions to pending confirmation state if `partner_id IS NOT NULL`
- [ ] Realtime subscription is torn down (channel unsubscribed) when `connectionStatus` transitions out of `.pendingCode(...)` -- prevents memory leak

**Dependencies:** PH-7 (Realtime channel must be active), PH-8-E1-S2 (store shape)
**Notes:** If Phase 7 Realtime is unavailable in the test environment, the fallback (app-foreground re-query) must be verified independently. Do not suppress the fallback when Realtime is working -- both paths must be present.

---

### S4: ConnectionConfirmationView with Dynamic Permission Summary

**Story ID:** PH-8-E2-S4
**Points:** 5

Implement `ConnectionConfirmationView` with two sections derived from `PartnerConnectionStore.activePermissions`: a "They will see:" section listing enabled categories and a "They will not see:" section listing disabled categories. Include the Confirm CTA and Deny link.

**Acceptance Criteria:**

- [ ] Heading "Your partner wants to connect" in `title2` + `CadenceTextPrimary`, centered
- [ ] "They will see:" section header in `caption2` + `CadenceTextSecondary` uppercase; if zero categories are enabled, section body reads "Nothing yet -- you can turn on sharing after they connect." in `body` + `CadenceTextSecondary`
- [ ] "They will not see:" section header in `caption2` + `CadenceTextSecondary` uppercase; lists all disabled categories with `CadenceTextSecondary` bullet copy
- [ ] Each category in both sections uses its human-readable name from the permission model (e.g. "Period predictions and countdown", "Current cycle phase", etc. -- matches MVP Spec §2 table exactly)
- [ ] "Confirm" CTA is a `PrimaryButton` (Phase 4 component) with CadenceTerracotta background; calls `PartnerConnectionStore.finalizeConnection()` on tap; shows loading state during async call
- [ ] "Deny" is a plain text link button in `footnote` + `CadenceDestructive`; calls `PartnerConnectionStore.denyConnection()` on tap; no loading state (fast operation)
- [ ] View dismisses automatically when `connectionStatus` transitions to `.active` (confirm path) or `.none` (deny path)
- [ ] All hardcoded strings are non-AI-sloppy, human-terse phrasing

**Dependencies:** PH-8-E2-S3 (routing triggers presentation of this view)
**Notes:** Since E3 (PermissionCategory enum) is not yet built, inline the 6 category display names as a local constant array in this view with a `// Replace with PermissionCategory.allCases in E3` comment. This is the only permitted placeholder reference -- the strings themselves must be final and correct.

---

### S5: Finalization Mutation, Denial Mutation, and Error Handling

**Story ID:** PH-8-E2-S5
**Points:** 3

Implement `PartnerConnectionStore.finalizeConnection()` and `PartnerConnectionStore.denyConnection()`. Handle Partner-side row deletion detection (denial response). Cover all error states with typed throws and UI feedback.

**Acceptance Criteria:**

- [ ] `finalizeConnection()` issues `UPDATE partner_connections SET connected_at = now(), invite_code = null WHERE tracker_id = auth.uid() AND partner_id IS NOT NULL AND connected_at IS NULL`; on success, `connectionStatus` transitions to `.active`
- [ ] `denyConnection()` issues `DELETE FROM partner_connections WHERE tracker_id = auth.uid() AND partner_id IS NOT NULL AND connected_at IS NULL`; on success, `connectionStatus` resets to `.none`; `pendingConfirmationDetected` resets to `false`
- [ ] Partner client: when the subscribed `partner_connections` row is deleted while `connectionStatus == .pendingConfirmation`, the Partner's store transitions to `.none` and the waiting view displays "Connection was not accepted. Please ask your partner for a new code." with a "Try again" CTA that routes back to the code entry screen
- [ ] Network failure on `finalizeConnection()` shows error toast; `connectionStatus` remains `.pendingConfirmation`; Confirm CTA re-enables for retry
- [ ] Network failure on `denyConnection()` shows error toast; Deny link re-enables for retry
- [ ] Unit test: successful `finalizeConnection()` mock produces `connectionStatus == .active`
- [ ] Unit test: successful `denyConnection()` mock produces `connectionStatus == .none` with `pendingConfirmationDetected == false`

**Dependencies:** PH-8-E2-S4
**Notes:** `invite_code` nulled on finalization prevents replay attacks. Confirm the Phase 1 RLS policy allows the Tracker to null the `invite_code` column on their own row.

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

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] End-to-end verified: Tracker generates code (E1), Partner enters code, `partner_connections` row shows `partner_id` set, Tracker confirms, row shows `connected_at` set and `invite_code` null, `connectionStatus == .active` on both clients
- [ ] Phase objective is advanced: a Tracker-Partner pair can complete the full connection handshake against the live Supabase project
- [ ] Applicable skill constraints satisfied: cadence-privacy-architecture (connection proof is `connected_at IS NOT NULL`; RLS read policies confirmed against live connection row), swiftui-production, cadence-design-system, cadence-sync (Realtime subscription teardown on state change), cadence-navigation (sheet detents per spec)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility requirements verified per cadence-accessibility skill (44pt targets on Confirm and Deny)
- [ ] No dead code, stubs, or placeholder comments (exception: the E3 category name inline constant comment from S4 is permitted until E3 replaces it)
- [ ] Source document alignment verified: confirmation screen copy matches MVP Spec §2 flow description

## Source References

- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (in-scope: Partner onboarding code validation, confirmation screen)
- MVP Spec §2 (Partner Sharing -- Connection Flow steps 4-6, confirmation screen copy, Data Model)
- cadence-sync skill (Realtime subscription lifecycle on `partner_connections`)
- cadence-privacy-architecture skill §6 (RLS policy alignment -- connection proof requirement)
- Design Spec v1.1 §13 (States & Feedback -- error toast pattern, loading state pattern)
- Design Spec v1.1 §11 (Motion -- sheet presentation, reduced motion gating)
