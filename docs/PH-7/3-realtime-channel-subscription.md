# Realtime Channel Subscription Setup

**Epic ID:** PH-7-E3
**Phase:** 7 -- Sync Layer
**Estimated Size:** M
**Status:** Draft

---

## Objective

Establish the Supabase Realtime channel subscriptions that Phase 9 (Partner Dashboard) requires for live updates. This epic implements `subscribePartnerDashboard()` and `unsubscribePartnerDashboard()` on `SyncCoordinator`, wires all incoming Realtime payloads through `applyRemote()`, and enforces channel deduplication so the app never holds duplicate active subscriptions. After this epic, `SyncCoordinator` is the exclusive owner of all Realtime lifecycle; no ViewModel or View touches the Supabase Realtime SDK directly.

## Problem / Context

Phase 9 requires that when a Tracker logs new data, the Partner Dashboard reflects that change without a manual app refresh. This requires a Realtime WebSocket subscription on the `daily_logs` and `partner_connections` tables, filtered to the linked Tracker's `user_id`. Without this epic, Phase 9's dashboard is static -- it renders the state at launch time and never updates.

The Realtime subscription is owned by Phase 7 (not Phase 9) because it is a sync-layer concern, not a UI concern. The Partner Dashboard view in Phase 9 simply calls `subscribePartnerDashboard(trackerUserId:)` when it appears and `unsubscribePartnerDashboard()` when it disappears. All WebSocket lifecycle, payload parsing, and SwiftData writes are owned here.

Source authority: cadence-sync skill §4 (Realtime Subscription Management), cadence-supabase skill §6 (Realtime Channel Setup), PHASES.md Phase 7 In-Scope (Realtime channel subscription for partner_connections and daily_logs).

## Scope

### In Scope

- `private var partnerChannel: RealtimeChannelV2?` property on `SyncCoordinator`
- `func subscribePartnerDashboard(trackerUserId: UUID) async` on `SyncCoordinator`: removes any existing `partnerChannel` via `supabase.removeChannel` before creating a new one; subscribes to `daily_logs` filtered to `user_id = trackerUserId`; subscribes to `partner_connections` filtered to `tracker_id = trackerUserId`; both event types use `.all` (INSERT, UPDATE, DELETE)
- `func unsubscribePartnerDashboard() async` on `SyncCoordinator`: calls `supabase.removeChannel(partnerChannel)` and sets `partnerChannel = nil`
- Channel naming convention: `"partner-dashboard-\(trackerUserId.uuidString.lowercased())"` (consistent, deterministic, deduplication-safe)
- `private func handleRemoteChange(_ payload: RealtimeChangeV2) async` on `SyncCoordinator`: dispatches incoming Realtime events to the correct SwiftData model lookup and calls `applyRemote()` for UPDATE payloads; handles INSERT (create new local model, mark `.synced`); handles DELETE (mark local model for deletion)
- `func subscribePartnerDashboard` and `func unsubscribePartnerDashboard` added to `SyncCoordinatorProtocol` so the Partner Dashboard ViewModel can call them through the protocol
- `FakeSyncCoordinator` stubs for both new protocol methods
- Subscription lifecycle unit tests (subscribe, unsubscribe, deduplication, payload routing)

### Out of Scope

- Partner Dashboard UI (Phase 9 -- this epic provides the subscription API; Phase 9 calls it)
- Tracker-side Realtime subscription for the Tracker's own data (Tracker reads from local SwiftData; Realtime is for pushing data to the Partner -- per cadence-sync skill §4)
- Push notification dispatch triggered by Realtime events (Phase 10)
- Channel state handling for `.channelError` and `.closed` reconnect UI (PH-7-E4 handles the NWPathMonitor reconnect path; Supabase SDK auto-reconnects WebSocket on network restore per cadence-sync skill §4 rule "do not manually recreate the channel on network restore")
- Partner connection establishment and RLS-gated data access (Phase 8)

## Dependencies

| Dependency                                                                         | Type | Phase/Epic | Status | Risk   |
| ---------------------------------------------------------------------------------- | ---- | ---------- | ------ | ------ |
| applyRemote() on SyncCoordinator (handleRemoteChange routes to it)                 | FS   | PH-7-E2-S1 | Open   | Low    |
| FakeSyncCoordinator with applyRemote stub (test target must compile)               | FS   | PH-7-E2-S5 | Open   | Low    |
| SyncCoordinator has SupabaseClient reference (required to call supabase.channel()) | FS   | PH-7-E1-S3 | Open   | Low    |
| Supabase project live with Realtime enabled on daily_logs and partner_connections  | FS   | PH-1-E1    | Open   | Medium |
| supabase-swift SPM package (RealtimeChannelV2 type availability)                   | FS   | PH-1-E4    | Open   | Low    |

## Assumptions

- The Supabase Realtime feature is enabled on the project for the `daily_logs` and `partner_connections` tables. Enabling Realtime for a table in Supabase requires checking the table in the Supabase Dashboard -> Database -> Replication section. This is a one-time project configuration owned by Phase 1.
- The Supabase Swift SDK (`supabase-swift`) handles WebSocket reconnection automatically on network restore. `SyncCoordinator` does NOT tear down and recreate channels after a network drop -- only after an explicit `unsubscribePartnerDashboard()` call or a `signedOut` auth event (PH-7-E4).
- `handleRemoteChange` must look up the local SwiftData model by `id` from the Realtime payload before calling `applyRemote`. If no local model exists (INSERT event from the server), a new model is created and inserted into SwiftData with `syncStatus = .synced`.
- DELETE events from Realtime are handled by marking the local model for deletion in SwiftData (using `modelContext.delete(model)`) if found, or no-op if not found locally.
- The Partner Dashboard view in Phase 9 calls `subscribePartnerDashboard(trackerUserId: connection.trackerId)` inside a `.task {}` modifier and `unsubscribePartnerDashboard()` inside `.task {}` cancellation cleanup, not in `onDisappear`. This calling convention is enforced by Phase 9; this epic documents it in the method's contract.

## Risks

| Risk                                                                                                         | Likelihood | Impact | Mitigation                                                                                                                                                  |
| ------------------------------------------------------------------------------------------------------------ | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Duplicate channel subscription (subscribePartnerDashboard called twice without unsubscribe)                  | Medium     | Medium | removeChannel call at the top of subscribePartnerDashboard ensures deduplication; verified by S5 test                                                       |
| Realtime payload arrives with an unknown model ID (row created on another device not yet in local SwiftData) | Low        | Low    | INSERT handler creates the model locally; this is the expected flow for initial data after a connection is established                                      |
| Realtime connection drops and SDK reconnect window leaves Partner Dashboard stale                            | Low        | Low    | SDK auto-reconnects; NWPathMonitor (PH-7-E4) triggers a fresh pullInitialData-style fetch if offline duration exceeds a threshold -- post-beta optimization |
| RealtimeChangeV2 payload schema changes between supabase-swift minor versions                                | Low        | Medium | Pin supabase-swift to an exact version in Package.resolved; do not accept minor version float                                                               |

---

## Stories

### S1: SyncCoordinatorProtocol -- subscribe and unsubscribe methods

**Story ID:** PH-7-E3-S1
**Points:** 2

Add `subscribePartnerDashboard(trackerUserId:)` and `unsubscribePartnerDashboard()` to `SyncCoordinatorProtocol` and add stub implementations to `FakeSyncCoordinator`. This is a prerequisite for all downstream stories in this epic -- the protocol must be updated before any call sites in Phase 9 can be written.

**Acceptance Criteria:**

- [ ] `SyncCoordinatorProtocol` declares:
- [ ] ````swift
          func subscribePartnerDashboard(trackerUserId: UUID) async
          func unsubscribePartnerDashboard() async
          ```
      ````
- [ ] `FakeSyncCoordinator` implements both methods; each records its call count: `private(set) var subscribeCallCount: Int = 0` and `private(set) var unsubscribeCallCount: Int = 0`
- [ ] All existing tests continue to pass after the protocol change
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E2-S5 (FakeSyncCoordinator must be up to date before adding more stubs)

---

### S2: subscribePartnerDashboard() -- channel creation and subscription

**Story ID:** PH-7-E3-S2
**Points:** 5

Implement the concrete `subscribePartnerDashboard(trackerUserId: UUID) async` on `SyncCoordinator`. This story covers channel naming, the deduplication guard (removeChannel before subscribe), and subscription to both `daily_logs` and `partner_connections` with correct row-level filters.

**Acceptance Criteria:**

- [ ] `subscribePartnerDashboard(trackerUserId: UUID) async` exists on `SyncCoordinator`
- [ ] If `partnerChannel != nil`, `await supabase.removeChannel(partnerChannel!)` is called before creating a new channel; `partnerChannel` is then set to `nil` before proceeding
- [ ] New channel is created with name `"partner-dashboard-\(trackerUserId.uuidString.lowercased())"`
- [ ] Channel subscribes to `daily_logs` with `ChannelFilter(event: "*", schema: "public", table: "daily_logs", filter: "user_id=eq.\(trackerUserId)")` (server-side filter, not client-side)
- [ ] Channel subscribes to `partner_connections` with `ChannelFilter(event: "*", schema: "public", table: "partner_connections", filter: "tracker_id=eq.\(trackerUserId)")` (server-side filter)
- [ ] Each subscription's closure calls `Task { await self?.handleRemoteChange(payload) }` (weak capture, dispatched asynchronously inside SyncCoordinator's actor context)
- [ ] The channel `.subscribe()` call is awaited before the function returns
- [ ] `partnerChannel` is assigned the result of the channel creation
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E3-S1, PH-7-E1-S3 (SupabaseClient reference on SyncCoordinator)
**Notes:** The `weak self` capture in the Realtime closure is mandatory to prevent a retain cycle between the channel and `SyncCoordinator`. The `Task { }` dispatch ensures the Realtime event is handled inside the actor's concurrency domain.

---

### S3: unsubscribePartnerDashboard() -- channel teardown

**Story ID:** PH-7-E3-S3
**Points:** 3

Implement `unsubscribePartnerDashboard() async` to cleanly remove the Realtime channel from the Supabase client and nil out the local reference. This story is critical for preventing subscription leaks when the Partner Dashboard view is dismissed.

**Acceptance Criteria:**

- [ ] `unsubscribePartnerDashboard() async` exists on `SyncCoordinator`
- [ ] If `partnerChannel != nil`: calls `await supabase.removeChannel(partnerChannel!)`; sets `partnerChannel = nil`
- [ ] If `partnerChannel == nil`: function is a no-op (safe to call on an already-unsubscribed coordinator)
- [ ] `unsubscribePartnerDashboard` is documented (inline comment) with the expected call site: ".task {} cancellation cleanup in the Partner Dashboard root view, not in onDisappear"
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E3-S2

---

### S4: handleRemoteChange() -- payload dispatcher

**Story ID:** PH-7-E3-S4
**Points:** 5

Implement `handleRemoteChange(_ payload: RealtimeChangeV2) async` as the single entry point for all Realtime events. This function parses the event type (INSERT/UPDATE/DELETE), finds the corresponding local SwiftData model, and dispatches to `applyRemote()` for UPDATE or creates/deletes the local model for INSERT/DELETE.

**Acceptance Criteria:**

- [ ] `private func handleRemoteChange(_ payload: RealtimeChangeV2) async` exists on `SyncCoordinator`
- [ ] For UPDATE payloads on `daily_logs`: deserializes `payload.record` into `DailyLogRow`; looks up the local `DailyLog` by `id` from `ModelContext`; calls `await applyRemote(remote: remoteModel, to: localModel)` if found; logs a debug warning and returns if not found (do not crash)
- [ ] For UPDATE payloads on `partner_connections`: deserializes `payload.record` into a `PartnerConnectionRow` struct (define this struct in `SupabaseModels.swift` -- tracker*id, partner_id, is_paused, share*\* flags, updated_at); updates the local `PartnerConnection` SwiftData model via `applyRemote`
- [ ] For INSERT payloads on `daily_logs`: deserializes `payload.record` into `DailyLogRow`; creates a new `DailyLog` @Model with `syncStatus = .synced`; inserts into `ModelContext`
- [ ] For DELETE payloads on `daily_logs`: looks up the local `DailyLog` by `id`; calls `modelContext.delete(model)` if found; no-op if not found
- [ ] For INSERT/DELETE on `partner_connections`: mirrors the same pattern as `daily_logs`
- [ ] No raw SwiftData writes occur anywhere in this function outside of the `applyRemote` call path (for UPDATE) or the explicit INSERT/DELETE handlers; all UPDATE writes go through `applyRemote`
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E3-S2 (subscribePartnerDashboard wires handleRemoteChange as the closure), PH-7-E2-S1 (applyRemote must exist)
**Notes:** `PartnerConnectionRow` is a new transport struct added to `SupabaseModels.swift` in this story. It is not a writable domain model in Phase 7 (partner*connections writes are Phase 8's responsibility) -- it is added here as a read-only deserialization target for Realtime events. The struct must include `is_paused` and all `share*\*`flag columns because`partner_connections`Realtime events drive the Partner Dashboard's pause state (Phase 9 reads the local`PartnerConnection` model).

---

### S5: Channel deduplication and lifecycle unit tests

**Story ID:** PH-7-E3-S5
**Points:** 5

Write unit tests covering the full Realtime subscription lifecycle: channel creation, deduplication guard, clean teardown, and handleRemoteChange routing. Tests use a mock Supabase Realtime client to avoid live network connections.

**Acceptance Criteria:**

- [ ] `CadenceTests/Sync/RealtimeSubscriptionTests.swift` exists
- [ ] **Test 1 -- subscribe creates channel with correct name:** Call `subscribePartnerDashboard(trackerUserId: uuid)` on a coordinator with a mock Realtime client -> assert channel was created with name `"partner-dashboard-\(uuid.uuidString.lowercased())"`
- [ ] **Test 2 -- deduplication:** Call `subscribePartnerDashboard` twice with the same `trackerUserId` -> assert `removeChannel` was called once (before the second subscribe) and exactly one channel exists after both calls
- [ ] **Test 3 -- unsubscribe clears channel:** Subscribe then `unsubscribePartnerDashboard()` -> assert `removeChannel` called once, `partnerChannel == nil` after
- [ ] **Test 4 -- unsubscribe on nil channel is no-op:** Call `unsubscribePartnerDashboard()` on a coordinator that never subscribed -> assert no crash, `removeChannel` not called
- [ ] **Test 5 -- handleRemoteChange UPDATE routes to applyRemote:** Deliver a mock UPDATE payload for `daily_logs` -> assert `applyRemote` was called exactly once with the correct model
- [ ] **Test 6 -- handleRemoteChange INSERT creates new model:** Deliver a mock INSERT payload for `daily_logs` with a UUID not present in SwiftData -> assert a new `DailyLog` is inserted into the in-memory `ModelContext` with `syncStatus == .synced`
- [ ] **Test 7 -- handleRemoteChange DELETE removes model:** Deliver a mock DELETE payload with an ID matching an existing local `DailyLog` -> assert the model is deleted from `ModelContext`
- [ ] All tests use in-memory `ModelContainer`; no live Supabase or WebSocket connections
- [ ] Test file added to `project.yml` under `CadenceTests/Sync/`

**Dependencies:** PH-7-E3-S4, PH-7-E2-S5 (FakeSyncCoordinator applyRemote stub)

---

### S6: Subscription lifecycle integration with auth events

**Story ID:** PH-7-E3-S6
**Points:** 3

Ensure that `unsubscribePartnerDashboard()` is called when the auth session ends (`signedOut` event) so that Realtime channels are not left alive after logout. Wire this into the `authStateChanges` handler established in PH-7-E4 with a documented call contract. Because PH-7-E4 has not been merged when this story is written, the wiring is a `TODO` placeholder in `SyncCoordinator` with an explicit comment that PH-7-E4-S6 implements it. The story's AC focuses on the contract documentation and the channel cleanup call existing in a testable, callable form.

**Acceptance Criteria:**

- [ ] `unsubscribePartnerDashboard()` is the correct cleanup call for `signedOut` -- this is documented in a code comment on the method: "Called by auth observer on signedOut to prevent stale channels after logout"
- [ ] `SyncCoordinator` has a private `func cancelAllSync() async` method (referenced in PH-7-E4 auth handling) that includes a call to `unsubscribePartnerDashboard()` as its first step
- [ ] `cancelAllSync()` also empties the in-memory queue and marks all in-queue models as `.error` (state machine allows this: sign-out with pending writes means writes are lost; the user must re-authenticate and the initial pull will recover server state)
- [ ] `func cancelAllSync() async` is tested: after calling it with a coordinator that has one queued write and an active subscription -> assert `pendingCount == 0`, queued model `syncStatus == .error`, `partnerChannel == nil`
- [ ] Test added to `RealtimeSubscriptionTests.swift`

**Dependencies:** PH-7-E3-S3 (unsubscribePartnerDashboard must exist), PH-7-E2 (syncStatus .error transition valid)
**Notes:** PH-7-E4-S6 wires `cancelAllSync()` into the `authStateChanges` observer. This story ensures `cancelAllSync()` exists and is tested before that wiring. Ordering: this story's AC is satisfiable before PH-7-E4 starts because the wiring call site is a `TODO` comment. The `cancelAllSync()` function itself is complete and tested.

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
- [ ] `SyncCoordinator` is the exclusive owner of all Realtime channel lifecycle -- no ViewModel or View imports or calls the Supabase Realtime SDK
- [ ] `handleRemoteChange` routes all UPDATE payloads through `applyRemote` -- no direct SwiftData write from a Realtime closure bypasses conflict resolution
- [ ] Channel deduplication verified by Test 2 in S5: `removeChannel` called before every re-subscribe
- [ ] `partnerChannel` is nil after `unsubscribePartnerDashboard()` -- verified by Test 3 in S5
- [ ] `cancelAllSync()` exists, calls `unsubscribePartnerDashboard()`, and empties the queue -- verified by S6 test
- [ ] `PartnerConnectionRow` transport struct exists in `SupabaseModels.swift` with all permission flag columns
- [ ] All 7 tests in `RealtimeSubscriptionTests.swift` pass
- [ ] Phase 9 has a documented, testable API (`subscribePartnerDashboard` / `unsubscribePartnerDashboard` on `SyncCoordinatorProtocol`) to call when the Partner Dashboard appears and disappears
- [ ] Applicable skill constraints satisfied: `cadence-sync` (§4 Realtime -- removeChannel before re-subscribe; unsubscribe in .task cleanup; SDK auto-reconnects, do not recreate channels on network restore); `cadence-supabase` (§6 channel lifecycle, server-side filters, typed payload deserialization)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments (the PH-7-E4 wiring comment in S6 is explicitly permitted as a documented contract marker, not an unresolved TODO)

## Source References

- PHASES.md: Phase 7 -- Sync Layer (In-Scope: Realtime channel subscription for partner_connections and daily_logs, consumed by Phase 9)
- cadence-sync skill §4 (Realtime Subscription Management -- subscribePartnerDashboard pattern, removeChannel before re-subscribe, SDK auto-reconnect, applyRemote routing from Realtime closure)
- cadence-supabase skill §6 (Realtime Channel Setup -- channel naming, lifecycle rules, typed filter construction, one channel per purpose)
- cadence-supabase skill §6.3 (Tracker-side Realtime: partner_connections change drives Partner Dashboard refresh)
- MVP Spec §4 (Partner view -- "she shared today", real-time awareness)
- PH-7-E2 (applyRemote -- required by handleRemoteChange; this epic consumes it)
- PH-9 (Partner Dashboard -- will call subscribePartnerDashboard/unsubscribePartnerDashboard)
