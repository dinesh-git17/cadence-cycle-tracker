# Realtime Data Integration

**Epic ID:** PH-9-E3
**Phase:** 9 -- Partner Navigation Shell & Dashboard
**Estimated Size:** L
**Status:** Draft

---

## Objective

Wire PartnerDashboardViewModel to live Supabase data: implement PartnerDataService with RLS-compliant column projection, manage the Realtime subscription lifecycle, execute the initial data load on view appear, handle the empty-log state, and implement graceful degradation on Realtime disconnection. This epic converts the static Bento grid from PH-9-E2 into a live Partner experience.

## Problem / Context

Without this epic, the Partner Dashboard shows stub or skeleton data indefinitely. The Realtime channels for partner_connections and daily_logs were established in Phase 7's SyncCoordinator -- Phase 9 must consume those channels to render the Tracker's current cycle state as it changes in real time. PartnerDataService enforces the cadence-privacy-architecture column projection rule: Partner-facing queries must never over-expose Tracker fields. The Sex symptom exclusion is structural -- it is enforced at query construction time in PartnerDataService, not by post-fetch filtering, because post-fetch filtering can be bypassed by a future refactor. Realtime disconnection is a production reality; the Dashboard must retain the last known snapshot rather than reverting to a loading or error state that loses context.

Source authority: Design Spec v1.1 §13 (empty and error states); MVP Spec §2 (RLS design, permission model, Sex exclusion), §4 (Partner home empty state); cadence-privacy-architecture skill; cadence-sync skill (Realtime subscription lifecycle).

## Scope

### In Scope

- PartnerDataService: injectable service class (not a global/static); accepts a Supabase client instance via initializer injection; exposes `fetchCurrentSnapshot(trackerUserId: UUID) async throws -> PartnerDashboardSnapshot?`
- Supabase query for daily_logs: column projection using `.select(...)` syntax to request only the columns required for PartnerDashboardSnapshot (excludes any Tracker-only fields); filtered by tracker_user_id = trackerUserId AND log_date = today's date; RLS enforcement on the server side gates the query result by connection, is_paused, share_*, and is_private conditions -- the client does not re-check these conditions
- Sex symptom exclusion in PartnerDataService: query filter on symptom_logs excludes rows where symptom_type = 'sex' at the `.eq("symptom_type", "sex")` neq filter level -- not in post-fetch mapping
- Supabase query for prediction_snapshots: column projection to return phaseLabel and countdownDays fields only; filtered by tracker_user_id = trackerUserId AND prediction_date = today
- PartnerDataService injected into PartnerDashboardViewModel via initializer; ViewModel holds no direct Supabase client reference
- Initial data load: PartnerDashboardViewModel.loadData() called on PartnerDashboardView.onAppear; triggers PartnerDataService.fetchCurrentSnapshot(); transitions state from .loading to .loaded(snapshot) on success or .empty when result is nil
- Realtime channel subscription: PartnerDashboardViewModel subscribes to the Postgres Changes channel established in Phase 7 for daily_logs on PartnerDashboardView.onAppear, after the initial fetch; unsubscribes on PartnerDashboardView.onDisappear
- Realtime INSERT/UPDATE handler: on receiving a daily_logs change event for the connected Tracker, call PartnerDataService.fetchCurrentSnapshot() and update ViewModel.viewState with the fresh snapshot
- Auth session refresh reconnect: on Supabase auth session refresh event, re-subscribe to the Realtime channel if the subscription has been dropped
- "She hasn't logged today yet" empty state: PartnerDashboardViewModel transitions to .empty when fetchCurrentSnapshot returns nil; PartnerDashboardView renders body-style CadenceTextSecondary "She hasn't logged today yet" text centered in the dashboard area
- Realtime disconnection handling: on channel status change to .errored, retain last known .loaded or .empty state (do not reset to .loading); show non-blocking toast at bottom of screen with SF Symbol `warning.fill` in CadenceTextSecondary (per Design Spec §13 error state -- no destructive red)
- Unit tests for PartnerDataService: mock Supabase client; verify Sex symptom exclusion, column projection, and nil return on empty result

### Out of Scope

- partner_connections Realtime subscription for is_paused flag (PH-9-E4)
- Paused state handling in ViewModel (PH-9-E4)
- Local SwiftData caching of Partner data (Partner is read-only; offline state shows last known Realtime snapshot per the retain-on-error behavior above)
- Conflict resolution or write queue (Partner makes no writes; cadence-sync write queue is Tracker-only)
- Any app-layer check of share_* permission flags (RLS on the server enforces these; the client renders what the query returns)

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| PartnerDashboardViewModel state machine with .loading / .loaded / .empty / .error states | FS | PH-9-E2 | Unresolved (same phase) | Low |
| Realtime subscription channels for daily_logs and partner_connections established in SyncCoordinator | FS | PH-7 | Resolved | Medium |
| Partner connection live: partner_connections row exists in Supabase with tracker_id and partner_id | FS | PH-8 | Resolved | Low |
| RLS policies on daily_logs and prediction_snapshots granting partner read under 4-condition check | FS | PH-1 | Resolved | Low |
| supabase-swift typed client available in iOS target | FS | PH-3 | Resolved | Low |
| Sex symptom type defined as SymptomType enum case in SwiftData schema | FS | PH-3 | Resolved | Low |

## Assumptions

- The Realtime channel name/identifier pattern for daily_logs changes in Phase 7 is accessible to PartnerDataService or can be reconstructed from the partner_connection_id; read SyncCoordinator.swift source before implementing to confirm the exact channel key
- supabase-swift `.select("col1,col2")` syntax is the correct column projection mechanism; verify against the supabase-swift SDK version pinned in the project before implementing
- The connected Tracker's user ID is available to PartnerDashboardViewModel from the partner_connections row fetched during Phase 8 onboarding; it is passed in at ViewModel initialization, not re-fetched here
- PartnerDataService is dependency-injected; tests supply a mock Supabase client that returns controlled fixture data without network access
- The "She hasn't logged today yet" empty state covers both the case where no daily_log exists for today and the case where the RLS blocks all rows (permissions off) -- the client cannot distinguish these two cases from the query result alone, and the spec does not require distinguishing them

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Realtime channel name from Phase 7 SyncCoordinator differs from expected pattern | Medium | High | Read SyncCoordinator.swift before writing subscription code; do not assume the channel key |
| Sex symptom exclusion implemented as post-fetch filter rather than query-level filter | Medium | High | Code review AC explicitly requires neq filter at query construction; unit test verifies that a fixture with sex symptom entry returns no sex chip in the snapshot |
| supabase-swift column projection syntax differs from assumed `.select()` format | Low | Medium | Verify against pinned supabase-swift version in Package.swift; consult supabase-swift docs for the exact API |
| Realtime channel drops frequently on weak network, causing repeated toast errors | Low | Medium | Retain last state on error (per spec); only show one toast per disconnection event, not per missed message |

---

## Stories

### S1: PartnerDataService with RLS-compliant column projection

**Story ID:** PH-9-E3-S1
**Points:** 5

Implement PartnerDataService as an injectable class with fetchCurrentSnapshot(). The query must use explicit column projection on daily_logs and prediction_snapshots, and must filter out Sex symptom entries at the query construction level.

**Acceptance Criteria:**

- [ ] PartnerDataService is a class that accepts a Supabase client via initializer injection (no global Supabase client reference inside the service)
- [ ] `fetchCurrentSnapshot(trackerUserId: UUID) async throws -> PartnerDashboardSnapshot?` returns a populated snapshot when a valid daily_logs row exists for today, or nil when the query returns no rows
- [ ] The daily_logs query uses explicit column projection (`.select(...)`) listing only the columns required for PartnerDashboardSnapshot; no wildcard `*` select
- [ ] Sex symptom entries are excluded by a `.neq("symptom_type", "sex")` filter (or equivalent) applied at query construction in PartnerDataService -- not in a post-fetch mapping function
- [ ] The prediction_snapshots query requests only phaseLabel-equivalent and countdownDays-equivalent columns via explicit projection
- [ ] Both queries are filtered by today's date (ISO 8601 format, UTC) at the query level
- [ ] Unit test: given a mock response containing a sex symptom entry, PartnerDataService.fetchCurrentSnapshot returns a PartnerDashboardSnapshot with an empty symptomChipStates array
- [ ] Unit test: given a mock response with nil daily_logs result, fetchCurrentSnapshot returns nil (not a snapshot with empty fields)

**Dependencies:** None (PH-9-E2-S1 PartnerDashboardSnapshot type must exist)
**Notes:** Read the supabase-swift SDK version pinned in Package.swift and verify column projection syntax before writing query code. The unit tests must use a mock Supabase client -- no live network calls in tests.

---

### S2: Realtime channel subscription lifecycle

**Story ID:** PH-9-E3-S2
**Points:** 5

Implement the Realtime channel subscription in PartnerDashboardViewModel. Subscribe on PartnerDashboardView.onAppear (after initial fetch), unsubscribe on .onDisappear, and reconnect on auth session refresh.

**Acceptance Criteria:**

- [ ] PartnerDashboardViewModel subscribes to the daily_logs Postgres Changes channel (established in Phase 7 SyncCoordinator) on PartnerDashboardView.onAppear, after the initial fetchCurrentSnapshot call completes
- [ ] On receiving an INSERT or UPDATE event for a daily_logs row matching the connected Tracker's user ID, ViewModel calls PartnerDataService.fetchCurrentSnapshot() and updates viewState with the fresh snapshot
- [ ] PartnerDashboardViewModel unsubscribes from the Realtime channel on PartnerDashboardView.onDisappear
- [ ] On Supabase auth session refresh event, ViewModel re-subscribes to the channel if the subscription status is .errored or .disconnected
- [ ] The subscription callback executes on the main actor (ViewModel state mutation is main-actor-safe)
- [ ] No retain cycles exist in the Realtime callback closure (weak self capture where ViewModel is referenced)
- [ ] Unit test: given a simulated Realtime INSERT event with a fixture daily_logs payload, ViewModel.viewState transitions from .loaded(oldSnapshot) to .loaded(newSnapshot) with the updated data

**Dependencies:** PH-9-E3-S1
**Notes:** Read SyncCoordinator.swift to determine the exact channel key before implementing. The channel subscription must use the same identifier established in Phase 7 -- do not create a new channel.

---

### S3: Initial data load on view appear

**Story ID:** PH-9-E3-S3
**Points:** 3

Implement PartnerDashboardViewModel.loadData() to execute the initial data fetch on view appear, transitioning the ViewModel from .loading to .loaded or .empty before the Realtime subscription receives its first event.

**Acceptance Criteria:**

- [ ] PartnerDashboardView calls ViewModel.loadData() in its .task modifier (not .onAppear, to correctly handle async/await cancellation)
- [ ] loadData() transitions ViewModel.viewState from .loading to .loaded(snapshot) when PartnerDataService.fetchCurrentSnapshot returns a non-nil result
- [ ] loadData() transitions ViewModel.viewState from .loading to .empty when fetchCurrentSnapshot returns nil
- [ ] loadData() transitions ViewModel.viewState from .loading to .error(message:) when fetchCurrentSnapshot throws; the error message is a user-readable string (not a raw error description)
- [ ] The skeleton loading placeholders (PH-9-E2-S7) are visible during the .loading state and disappear when state transitions to .loaded or .empty
- [ ] loadData() is cancellation-safe: if PartnerDashboardView disappears before the async fetch completes, the task is cancelled and ViewModel state does not update after cancellation

**Dependencies:** PH-9-E3-S1, PH-9-E3-S2

---

### S4: Permission-gated card visibility

**Story ID:** PH-9-E3-S4
**Points:** 3

Implement conditional card rendering in PartnerDashboardView based on the data returned by PartnerDataService. Cards with no data (because RLS blocked the query due to permission flags) render an appropriate empty or absent state rather than crashing or showing stale content.

**Acceptance Criteria:**

- [ ] When PartnerDashboardSnapshot.phaseLabel is nil or empty (RLS blocked prediction_snapshots query), Phase card shows "--" placeholder text rather than crashing or showing an empty string
- [ ] When PartnerDashboardSnapshot.countdownDays is nil (RLS blocked or prediction unavailable), Countdown card shows "--" in place of the numeral (per PH-9-E2-S2 nil handling)
- [ ] When PartnerDashboardSnapshot.symptomChipStates is empty (no symptoms shared or not logged), Symptoms card shows "No symptoms logged today" (per PH-9-E2-S3 empty handling)
- [ ] When PartnerDashboardSnapshot.notes is nil (daily notes not shared or not written), Notes card shows "No notes added today" (per PH-9-E2-S4 empty handling)
- [ ] No card is removed from the layout based on permission flags -- the card structure is always rendered; only the content within the card reflects what was returned

**Dependencies:** PH-9-E3-S3
**Notes:** The decision to always show all 4 cards (with empty states) rather than hiding absent cards is a deliberate UX choice consistent with the spec's Bento grid definition -- the grid is a fixed 4-card layout regardless of what's shared.

---

### S5: "She hasn't logged today yet" empty state

**Story ID:** PH-9-E3-S5
**Points:** 2

Render the empty state when PartnerDashboardViewModel.viewState is .empty (fetchCurrentSnapshot returned nil for today). The empty state replaces the Bento grid with centered body text.

**Acceptance Criteria:**

- [ ] When ViewModel.viewState == .empty, the Bento grid is not shown
- [ ] The empty state renders "She hasn't logged today yet" in body style, CadenceTextSecondary, centered horizontally and vertically within the Her Dashboard tab's content area
- [ ] The empty state does not show any SF Symbol illustration (none specified in Design Spec §13 for this state)
- [ ] Transitioning from .empty to .loaded (when the Tracker logs later in the day via Realtime update) replaces the empty state with the Bento grid without requiring a manual refresh

**Dependencies:** PH-9-E3-S3

---

### S6: Realtime disconnection and error state handling

**Story ID:** PH-9-E3-S6
**Points:** 3

Handle Realtime channel disconnection gracefully: retain last known ViewModel state, show a non-blocking toast with warning.fill SF Symbol, and do not reset to .loading on temporary disconnection.

**Acceptance Criteria:**

- [ ] When the Realtime channel status transitions to .errored, ViewModel.viewState is NOT changed (last .loaded or .empty state is retained)
- [ ] A non-blocking toast appears at the bottom of the screen with SF Symbol `warning.fill` and a CadenceTextSecondary tint (per Design Spec §13 -- no destructive red, no CadenceDestructive color)
- [ ] The toast body text does not contain technical error messages (e.g., no WebSocket error codes); a plain-language string such as "Live updates paused" is used
- [ ] The toast does not block or cover the primary Bento grid content
- [ ] When the channel reconnects (status transitions to .subscribed), the toast dismisses and ViewModel triggers a fresh fetchCurrentSnapshot() to catch any missed updates during the disconnection window
- [ ] Only one toast is shown per disconnection event, not one per missed message

**Dependencies:** PH-9-E3-S2

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
- [ ] Integration verified end-to-end: a Partner user with a live connection sees the Tracker's current daily_logs data in the Bento grid within 2 Realtime update cycles
- [ ] Phase objective is advanced: a connected Partner sees live cycle data or a respectful empty state
- [ ] cadence-privacy-architecture skill constraints satisfied: Sex symptom exclusion enforced at PartnerDataService query level; column projection verified to exclude Tracker-only fields; no app-layer RLS bypass
- [ ] cadence-sync skill constraints satisfied: Realtime subscription lifecycle follows Phase 7 channel patterns; auth session refresh reconnect implemented; disconnection retains last state
- [ ] swiftui-production skill constraints satisfied: no AnyView, no force unwraps, async work uses .task modifier for cancellation safety, ViewModel state mutation on main actor
- [ ] cadence-testing skill constraints satisfied: PartnerDataService unit tests cover Sex exclusion, nil return on empty result, and error propagation; mock Supabase client used -- no live network in tests
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Offline-first behavior verified: Realtime disconnection shows toast and retains last snapshot; no blank screen on channel drop
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: empty state text, error toast spec, and sex exclusion requirement match Design Spec §13 and MVP Spec §2 exactly

## Source References

- PHASES.md: Phase 9 -- Partner Navigation Shell & Dashboard (in-scope items 5, 6, 7)
- Design Spec v1.1 §13 (States & Feedback -- empty Partner state, error/sync failure toast spec)
- MVP Spec §2 (Partner Sharing -- RLS design, permission model, is_private, Sex exclusion)
- MVP Spec §4 (Partner Home Dashboard -- "She hasn't logged today yet" empty state)
- cadence-privacy-architecture skill (isPrivate override, Sex exclusion, Partner query column projection, RLS alignment)
- cadence-sync skill (Realtime subscription lifecycle, channel reconnect, auth session resilience)
- cadence-testing skill (DI on @Observable stores, no live Supabase in tests, mock/fake design)
- swiftui-production skill (@Observable, .task modifier, main actor safety, AnyView ban)
