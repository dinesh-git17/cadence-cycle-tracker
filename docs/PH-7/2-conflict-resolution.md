# Last-Write-Wins Conflict Resolution

**Epic ID:** PH-7-E2
**Phase:** 7 -- Sync Layer
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `applyRemote()` and the complete `syncStatus` lifecycle so that incoming Supabase data -- whether from Realtime events (PH-7-E3) or from future multi-device scenarios -- never silently overwrites a fresher local write. After this epic, the rule "stale remote never overwrites fresher local" is enforced in a single, tested, deterministic function that all sync paths route through.

## Problem / Context

The `flush()` drain loop from PH-7-E1 resolves local-to-remote writes. But when the Supabase backend has a row that is newer than the local SwiftData model (possible after a sign-in on a new device), writing it blindly into SwiftData corrupts the user's history. The MVP uses a single-device assumption, but the auth system does permit sign-out/sign-in cycles where local SwiftData may have been cleared and remote data must flow in without clobbering any local writes that occurred in the same session.

The critical guard is even more important for Realtime: if a `partner_connections` permission change arrives over Realtime while a local `daily_log` write is in-flight with `syncStatus == .pending`, applying the Realtime payload must not touch the pending model. Without this guard, a race condition causes the Realtime event to mark the model `.synced` prematurely, and the in-flight write may then be skipped by the flush loop (which only processes `.pending` entries).

Source authority: cadence-sync skill §3 (conflict resolution), §4 (Realtime -- "always pass received payloads through applyRemote, never write directly to SwiftData from a Realtime closure").

## Scope

### In Scope

- `func applyRemote<T: SyncableModel>(_ remote: T, to local: T)` on `SyncCoordinator`: compares `remote.updatedAt > local.updatedAt` and applies field-level updates from remote to local only when remote is strictly fresher
- Equal-timestamp tie-breaking: `remote.updatedAt == local.updatedAt` is treated as local-wins (no-op)
- `.pending` guard: if `local.syncStatus == .pending`, `applyRemote` is unconditionally a no-op regardless of timestamps (a pending local write is always fresher by contract)
- `syncStatus` lifecycle enforcement: `flush()` transition `.pending` -> `.synced` on success, `.pending` -> `.error` on failure; `applyRemote` transition (when applied) -> `.synced`; no other code paths mutate `syncStatus`
- `SyncableModel` conformance enforcement: compile-time requirement that all five `@Model` types conform (conformance verified by S1 in PH-7-E1; this epic adds enforcement via `applyRemote` generic constraint)
- Unit tests for all conflict resolution scenarios (12+ test cases)

### Out of Scope

- Realtime channel setup and event delivery (PH-7-E3 -- `applyRemote` is called by PH-7-E3's `handleRemoteChange`)
- Per-field merge strategies (the MVP contract is last-write-wins at row level, not field level -- post-beta if needed)
- Multi-user conflict resolution across two concurrent Trackers (out of scope for MVP per PRD)
- `syncStatus == .error` retry triggering (PH-7-E4 -- this epic defines the `.error` state, PH-7-E4 handles it)

## Dependencies

| Dependency                                                                           | Type | Phase/Epic | Status | Risk |
| ------------------------------------------------------------------------------------ | ---- | ---------- | ------ | ---- |
| SyncableModel protocol (updatedAt: Date, syncStatus: SyncStatus on all @Model types) | FS   | PH-7-E1-S1 | Open   | Low  |
| flush() implementation with syncStatus transitions for success/error                 | FS   | PH-7-E1-S4 | Open   | Low  |
| FakeSyncCoordinator with flush() stub (test target must compile)                     | FS   | PH-7-E1-S5 | Open   | Low  |

## Assumptions

- `applyRemote` performs a full row-level replacement: when `remote.updatedAt > local.updatedAt`, all non-identity fields on `local` are updated from `remote`. Partial field updates are not supported in this epic.
- The generic constraint `<T: SyncableModel>` is the only type gate. The caller is responsible for passing matched local/remote pairs (same `id`). `applyRemote` does not perform an identity check -- it trusts the caller.
- `SyncCoordinator` is an `actor`. `applyRemote` is an actor method, ensuring mutual exclusion between concurrent calls from Realtime event handlers.
- The test suite uses an in-memory `ModelContainer`. No real SwiftData store on disk is created in tests.

## Risks

| Risk                                                                                                                | Likelihood | Impact | Mitigation                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `applyRemote` called with mismatched entity IDs (e.g. remote DailyLog applied to a local PeriodLog)                 | Low        | High   | Typed generic constraint `<T: SyncableModel>` prevents cross-type calls at compile time; same-type ID mismatch is a programming error, not a runtime edge case for MVP                    |
| Race: Realtime event delivers remote payload while local model is transitioning from .pending to .synced in flush() | Low        | Medium | Actor isolation on SyncCoordinator serializes both paths; the .pending guard in applyRemote covers the window where flush() has not yet marked .synced                                    |
| `updatedAt` clock skew between device and Supabase server timestamps                                                | Low        | Low    | MVP single-device assumption; server-side `updated_at` is set by the Supabase upsert (Postgres `now()` or trigger), not by the iOS clock -- post-beta multi-device work should audit this |

---

## Stories

### S1: applyRemote() with freshness guard

**Story ID:** PH-7-E2-S1
**Points:** 5

Implement the core conflict resolution function. This is the single point where all remote data enters local SwiftData. No remote data may bypass this function.

**Acceptance Criteria:**

- [ ] `func applyRemote<T: SyncableModel>(_ remote: T, to local: T) async` exists on `SyncCoordinator`
- [ ] When `remote.updatedAt > local.updatedAt`: `local` fields are updated from `remote` via the `apply(to:)` converter from `SupabaseModels.swift`; `local.syncStatus` is set to `.synced`
- [ ] When `remote.updatedAt <= local.updatedAt`: function returns immediately without modifying `local` (no field updates, no `syncStatus` change)
- [ ] When `local.syncStatus == .pending`: function returns immediately without modifying `local`, regardless of the `updatedAt` comparison result (the `.pending` guard runs before the timestamp comparison)
- [ ] The function is `async` and called within `SyncCoordinator`'s actor isolation (no `@MainActor` annotation)
- [ ] No direct SwiftData writes outside of this function for remote-origin data -- all Realtime closures must call `applyRemote` (enforcement is by convention; this story establishes the function; PH-7-E3 enforces the call pattern)
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S1 (SyncableModel protocol), PH-7-E1-S2 (apply(to:) on *Row structs)
**Notes:** The generic constraint `<T: SyncableModel>` means one implementation covers all five model types. No switch statement on type is needed. The `apply(to:)` method on each `*Row`transport struct (defined in PH-7-E1-S2) does the field copy.`applyRemote`orchestrates the freshness decision and the`syncStatus` update.

---

### S2: syncStatus lifecycle invariants

**Story ID:** PH-7-E2-S2
**Points:** 3

Document and enforce the complete `syncStatus` state machine: which transitions are valid, which code paths own each transition, and what each state means at runtime. This story is primarily a code audit and commentary update -- it produces a `SyncStatusLifecycle.md` note in `docs/PH-7/` and adds inline assertions to `SyncCoordinator` for invalid transitions in `DEBUG` builds.

**Acceptance Criteria:**

- [ ] The three valid state transitions are enforced in `SyncCoordinator` via `DEBUG`-only `assert` calls:
  - `.pending` -> `.synced` (flush success path in PH-7-E1-S4)
  - `.pending` -> `.error` (flush failure path in PH-7-E1-S4)
  - `.synced` or `.error` -> `.pending` (re-enqueue path in PH-7-E1-S3, when a model is mutated and re-enqueued)
- [ ] No code path outside `SyncCoordinator` sets `syncStatus` to `.synced` or `.error` (enforced by code review and the `assert` statements catching violations in debug builds)
- [ ] `enqueue(_ write: PendingWrite)` sets `write.model.syncStatus = .pending` before appending to the queue (explicitly verified -- this was implicit in Phase 3, now required to be explicit per PH-7-E1-S3)
- [ ] `applyRemote` sets `local.syncStatus = .synced` only in the "remote is fresher" branch (confirmed by S1 AC; this story adds a `DEBUG` assert that `local.syncStatus != .pending` was not violated)
- [ ] `docs/PH-7/SyncStatusLifecycle.md` is created with a state diagram in ASCII and the ownership table (which function owns each transition)

**Dependencies:** PH-7-E2-S1, PH-7-E1-S4
**Notes:** The `assert` calls are `#if DEBUG` gated and are not compiled into release builds. They exist solely to catch mis-use during development. The `SyncStatusLifecycle.md` file is a developer reference -- it is not scanned by `protocol-zero.sh` or `check-em-dashes.sh` (markdown files are excluded by both scripts per CLAUDE.md hard-exempt paths).

---

### S3: .pending guard integration test

**Story ID:** PH-7-E2-S3
**Points:** 3

Verify the `.pending` guard functions correctly when a Realtime-style remote delivery races with an in-flight local write. This story tests the guard in isolation using `applyRemote` directly, without requiring a live Realtime connection.

**Acceptance Criteria:**

- [ ] `CadenceTests/Sync/ConflictResolutionTests.swift` exists
- [ ] **Test 1 -- remote fresher, local not pending:** Local model `updatedAt = t1`, remote `updatedAt = t2 > t1`, local `syncStatus = .synced` -> after `applyRemote`, local fields updated, `syncStatus == .synced`
- [ ] **Test 2 -- remote stale:** Local `updatedAt = t2`, remote `updatedAt = t1 < t2` -> after `applyRemote`, local fields unchanged, `syncStatus` unchanged
- [ ] **Test 3 -- equal timestamps:** Local and remote `updatedAt` equal -> after `applyRemote`, local fields unchanged (local-wins)
- [ ] **Test 4 -- pending guard:** Local `syncStatus = .pending`, remote `updatedAt` is any value including fresher than local -> after `applyRemote`, local fields unchanged, `syncStatus` still `.pending`
- [ ] **Test 5 -- pending guard survives fresher remote:** Local `syncStatus = .pending`, remote `updatedAt` is 1 year ahead of local -> local fields unchanged (the guard is unconditional, not timestamp-gated)
- [ ] All tests use in-memory `ModelContainer`; no live Supabase or Realtime connection
- [ ] All tests are `async func test_...()` due to actor isolation on `applyRemote`
- [ ] Test file added to `project.yml` under `CadenceTests/Sync/`

**Dependencies:** PH-7-E2-S1
**Notes:** Tests 4 and 5 directly validate the safety contract that protects in-flight writes from Realtime races. These are the highest-value tests in the epic -- a regression here causes silent data loss.

---

### S4: Complete conflict resolution test suite

**Story ID:** PH-7-E2-S4
**Points:** 5

Extend `ConflictResolutionTests.swift` with the remaining edge cases: syncStatus transitions through the full lifecycle, re-enqueue resets to `.pending`, and multi-model applyRemote calls in sequence produce correct final state.

**Acceptance Criteria:**

- [ ] **Test 6 -- flush success transition:** Enqueue a model, flush with succeeding mock -> model `syncStatus == .synced`, queue empty
- [ ] **Test 7 -- flush failure transition:** Enqueue a model, flush with failing mock -> model `syncStatus == .error`, queue empty
- [ ] **Test 8 -- re-enqueue resets to .pending:** Model with `syncStatus == .error` is mutated and re-enqueued -> model `syncStatus == .pending`, `pendingCount == 1`
- [ ] **Test 9 -- sequential applyRemote:** Apply remote v2 to local v1 (updates); then apply remote v1 to local v2 (no-op) -> local remains at v2 values
- [ ] **Test 10 -- applyRemote on .error model:** Local `syncStatus = .error`, remote is fresher -> applyRemote updates local and sets `syncStatus = .synced` (`.error` does not block remote application, only `.pending` does)
- [ ] **Test 11 -- concurrent enqueue ordering:** Two async `enqueue` calls in rapid succession -> `pendingCount == 2`, both entries in FIFO order (actor serialization guarantees this)
- [ ] **Test 12 -- applyRemote for DailyLogRow:** Type-specific test verifying all DailyLog fields are correctly copied (isPrivate, flowLevel, mood, notes, updatedAt) when remote is fresher
- [ ] All 12+ tests in `ConflictResolutionTests.swift` pass
- [ ] Test file builds without warnings

**Dependencies:** PH-7-E2-S3, PH-7-E1-S4 (flush success/failure path needed for tests 6-8)

---

### S5: FakeSyncCoordinator applyRemote stub

**Story ID:** PH-7-E2-S5
**Points:** 2

Add `applyRemote` to `SyncCoordinatorProtocol` and implement a stub on `FakeSyncCoordinator` so test targets that use the fake can call `applyRemote` in later epic tests (PH-7-E3) without a live actor.

**Acceptance Criteria:**

- [ ] `func applyRemote<T: SyncableModel>(_ remote: T, to local: T) async` added to `SyncCoordinatorProtocol`
- [ ] `FakeSyncCoordinator` implements `applyRemote`: records the call count in `private(set) var applyRemoteCallCount: Int = 0`; does not mutate `local`
- [ ] All existing tests in `ConflictResolutionTests.swift` and `SyncCoordinatorTests.swift` continue to pass
- [ ] Test target builds without errors

**Dependencies:** PH-7-E2-S1 (applyRemote concrete implementation), PH-7-E1-S5 (FakeSyncCoordinator must already have flush() stub)

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
- [ ] `applyRemote` is the single entry point for all remote data writes into SwiftData -- no Realtime closure writes directly to SwiftData bypassing this function
- [ ] The `.pending` guard is verified by at least two independent test cases (Tests 4 and 5 from S3)
- [ ] All 12 conflict resolution tests pass in `ConflictResolutionTests.swift`
- [ ] `SyncCoordinatorProtocol` includes `applyRemote` and both conforming types (real and fake) implement it
- [ ] No state machine transition occurs outside of `SyncCoordinator` (enforcement via DEBUG asserts)
- [ ] Integration with PH-7-E1 verified: `flush()` and `applyRemote` do not race to modify the same model (actor isolation prevents this)
- [ ] Applicable skill constraints satisfied: `cadence-sync` (§3 conflict resolution, last-write-wins on updated_at; stale remote never overwrites fresher local; .pending guard)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 7 -- Sync Layer (In-Scope: last-write-wins conflict resolution keyed on updated_at; stale remote never overwrites fresher local)
- cadence-sync skill §3 (Conflict Resolution -- last-write-wins on updated_at; .pending guard; equal timestamps are local-wins)
- cadence-sync skill §4 (Realtime -- "always pass received payloads through applyRemote -- never write directly to SwiftData from a Realtime closure")
- cadence-sync skill Enforcement Checklist (applyRemote compares remote.updatedAt > local.updatedAt; .pending models never overwritten by Realtime events)
- PH-7-E1 (SyncableModel protocol, flush() lifecycle -- this epic extends both)
