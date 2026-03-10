# SyncCoordinator Write Queue Skeleton

**Epic ID:** PH-3-E4
**Phase:** 3 -- Core Data Layer & Prediction Engine
**Estimated Size:** S
**Status:** Draft

---

## Objective

Define `SyncCoordinatorProtocol`, the `PendingWrite` sum type, and the `SyncCoordinator` actor with an in-memory write queue. The queue accepts `PendingWrite` entries from the offline-first write path and holds them in FIFO order for Phase 7 to drain to Supabase. No Supabase write occurs in Phase 3. The actor isolation guarantees thread-safe queue mutations. The protocol enables `FakeSyncCoordinator` substitution in all unit tests.

## Problem / Context

The `PeriodLogService.writePeriodLog` function (PH-3-E2-S5) must enqueue writes via a protocol-typed coordinator to remain testable. Without `SyncCoordinatorProtocol` and the `PendingWrite` type, the write path cannot compile. Without the concrete `SyncCoordinator` actor, the app has no runtime queue implementation for Phase 4+ to wire in.

Phase 3 establishes the write queue contract. Phase 7 implements the flush: the drain loop, Supabase calls, conflict resolution, exponential backoff, and `NWPathMonitor` integration. Phase 3 must not pre-implement any of those concerns.

Source authority: cadence-data-layer skill §4 (Offline-First Write Contract) and cadence-sync skill (write queue pattern -- Phase 3 scope only). cadence-testing skill §2 (DI requirement: `SyncCoordinatorProtocol` enables `FakeSyncCoordinator`).

## Scope

### In Scope

- `SyncCoordinatorProtocol.swift` -- Swift protocol that `SyncCoordinator` and `FakeSyncCoordinator` both implement
- `PendingWrite.swift` -- enum covering all five writable model types
- `SyncCoordinator.swift` -- `actor SyncCoordinator: SyncCoordinatorProtocol` with an in-memory `[PendingWrite]` queue
- `SyncCoordinator.enqueue(_ write: PendingWrite)` -- actor method that appends to the queue
- `SyncCoordinator.pendingCount: Int` -- actor property returning the current queue depth (used in tests and debugging)
- `project.yml` additions for all three new files under `Cadence/Services/`

### Out of Scope

- Supabase writes (Phase 7)
- Queue drain loop and flush logic (Phase 7)
- Conflict resolution / last-write-wins (Phase 7)
- Exponential backoff retry (Phase 7)
- `NWPathMonitor` connectivity monitoring (Phase 7)
- Realtime subscription setup (Phase 7)
- `is_online` state (Phase 7) -- the protocol stub may declare the property but it is not wired to a real monitor in Phase 3
- Auth session refresh handling (Phase 7)
- `syncStatus` update from `.pending` to `.synced` or `.error` (Phase 7 -- the flush loop owns this)

## Dependencies

| Dependency                                                                                    | Type | Phase/Epic | Status | Risk |
| --------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---- |
| All 5 SwiftData @Model types (required by PendingWrite enum cases)                            | FS   | PH-3-E1    | Open   | Low  |
| PH-3-E3-S1 requires SyncCoordinatorProtocol and PendingWrite to implement FakeSyncCoordinator | SS   | PH-3-E3    | Open   | Low  |

## Assumptions

- `SyncCoordinator` is a Swift `actor`. Actor isolation guarantees that `enqueue` and `pendingCount` are accessed serially, preventing data races on the in-memory queue array.
- The `[PendingWrite]` queue is purely in-memory. It does not persist to disk in Phase 3. Records lost in memory (e.g., on app kill) will be re-queued when the app relaunches and detects `.pending` syncStatus records in SwiftData. Phase 7 implements this recovery path.
- `PendingWrite` is a simple enum. Each case wraps one model instance. The enum is not `Codable` in Phase 3 -- no serialization is needed until Phase 7 requires a persistent queue.
- `SyncCoordinatorProtocol` declares `var isOnline: Bool { get }` as a property. `SyncCoordinator` hardcodes it to `true` in Phase 3. Phase 7 wires it to `NWPathMonitor`.
- The `SyncCoordinator` actor instance is a singleton created at app launch and injected into the SwiftUI environment. The wiring (environment injection) is Phase 4's responsibility. Phase 3 defines the type only.

## Risks

| Risk                                                                                                       | Likelihood | Impact | Mitigation                                                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Swift actor reentrancy: tasks awaiting `enqueue` are not guaranteed FIFO by the runtime priority scheduler | Low        | Low    | Phase 3's queue is append-only with no ordering dependency in this phase. Phase 7 will document the FIFO guarantee requirement for the flush loop and use an explicit ordered array drain. |
| `PendingWrite` enum grows unwieldy as more model types are added in Phase 7                                | Low        | Low    | Phase 7 may refactor `PendingWrite` into a protocol-based approach if needed. Phase 3 locks only the 5 known writable types.                                                               |

---

## Stories

### S1: SyncCoordinatorProtocol and PendingWrite type

**Story ID:** PH-3-E4-S1
**Points:** 3

Define the protocol and sum type that form the write queue's public interface. These two types are the prerequisite for both `FakeSyncCoordinator` (PH-3-E3-S1) and `SyncCoordinator` (S2).

**Acceptance Criteria:**

- [ ] `Cadence/Services/SyncCoordinatorProtocol.swift` exists with:
- [ ] `````swift
              protocol SyncCoordinatorProtocol: Actor {
                  func enqueue(_ write: PendingWrite) async
                  var isOnline: Bool { get }
              }
              ```
          ````
      `````
- [ ] `Cadence/Services/PendingWrite.swift` exists with:
- [ ] ````swift
          enum PendingWrite {
              case cycleProfile(CycleProfile)
              case periodLog(PeriodLog)
              case dailyLog(DailyLog)
              case symptomLog(SymptomLog)
              case predictionSnapshot(PredictionSnapshot)
          }
          ```
      ````
- [ ] `PendingWrite` conforms to no protocols beyond being a plain Swift enum -- no `Codable`, no `Equatable` unless needed for tests
- [ ] Both files compile without errors or warnings
- [ ] `project.yml` updated with both files under `Cadence/Services/`

**Dependencies:** PH-3-E1 (all 5 @Model types referenced in PendingWrite cases)
**Notes:** The protocol inherits from `Actor` so that conforming types (both the real and fake) are actors, ensuring mutual exclusion on `enqueuedWrites`. The `isOnline: Bool` property is in the protocol for Phase 7 compatibility. Hardcode it to `true` on the concrete type in S2 -- no NWPathMonitor in Phase 3.

---

### S2: SyncCoordinator actor with write queue

**Story ID:** PH-3-E4-S2
**Points:** 5

Implement the concrete `SyncCoordinator` actor. The queue is an in-memory `[PendingWrite]` array. The `enqueue` method appends to it. No flush logic, no Supabase calls.

**Acceptance Criteria:**

- [ ] `Cadence/Services/SyncCoordinator.swift` exists with `actor SyncCoordinator: SyncCoordinatorProtocol`
- [ ] `private var queue: [PendingWrite] = []` is the backing store
- [ ] `func enqueue(_ write: PendingWrite) async { queue.append(write) }` is the implementation
- [ ] `var isOnline: Bool { true }` hardcoded -- no NWPathMonitor wiring in Phase 3
- [ ] `var pendingCount: Int { queue.count }` is accessible for debugging and test assertions
- [ ] No `import` of Supabase SDK, URLSession, or Network framework
- [ ] `SyncCoordinator` can be instantiated with `SyncCoordinator()` -- no required parameters
- [ ] Enqueueing 3 `PendingWrite` values in sequence produces `pendingCount == 3` (verified in S3)
- [ ] `project.yml` updated with `SyncCoordinator.swift`

**Dependencies:** PH-3-E4-S1
**Notes:** The lack of flush logic is intentional -- Phase 7 adds the drain method, Supabase client reference, and NWPathMonitor. The Phase 3 skeleton must be designed so Phase 7 can add these without changing the protocol or the public enqueue interface.

---

### S3: Write queue integration verification

**Story ID:** PH-3-E4-S3
**Points:** 3

Write a unit test that verifies the offline-first write path works end-to-end: a `writePeriodLog` call writes to an in-memory SwiftData context and enqueues exactly the expected `PendingWrite` entries via `FakeSyncCoordinator`. Confirm queue ordering (FIFO).

**Acceptance Criteria:**

- [ ] `CadenceTests/Domain/SyncCoordinatorTests.swift` exists with at least 3 test functions
- [ ] **Test 1 -- enqueue ordering:** Call `FakeSyncCoordinator().enqueue(.periodLog(log))` then `.enqueue(.predictionSnapshot(snapshot))` → assert `enqueuedWrites[0]` is `.periodLog` and `enqueuedWrites[1]` is `.predictionSnapshot` (FIFO order preserved)
- [ ] **Test 2 -- writePeriodLog enqueues correct writes:** Call `writePeriodLog` with a fresh in-memory `ModelContext` and `FakeSyncCoordinator` → assert `enqueuedWrites.count == 3` (`.periodLog`, `.predictionSnapshot`, `.cycleProfile` -- the three records modified by the write path)
- [ ] **Test 3 -- pendingCount accuracy:** Enqueue 5 writes to `SyncCoordinator()` via `await` calls → assert `await syncCoordinator.pendingCount == 5`
- [ ] All tests are `async func test_...()` (required because actor methods are `async`)
- [ ] All tests use `FakeSyncCoordinator` for tests 1 and 2; test 3 uses the real `SyncCoordinator`
- [ ] `project.yml` updated with `CadenceTests/Domain/SyncCoordinatorTests.swift`

**Dependencies:** PH-3-E4-S2, PH-3-E3-S1 (FakeSyncCoordinator), PH-3-E2-S5 (writePeriodLog)
**Notes:** Test 3 instantiates `SyncCoordinator()` directly (not via protocol) to access `pendingCount`. No Supabase calls are made. These tests verify the write queue structure is correct -- the flush logic's correctness is Phase 7's test responsibility.

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
- [ ] `SyncCoordinator.swift` contains zero imports of Supabase, URLSession, or Network framework
- [ ] `writePeriodLog` enqueues exactly 3 `PendingWrite` entries in the correct order, verified by `SyncCoordinatorTests`
- [ ] `SyncCoordinatorProtocol` and `PendingWrite` are the complete interface that Phase 7 will extend (no breaking changes needed in Phase 7 to add the flush loop)
- [ ] Phase objective is advanced: the write queue contract is established and the offline-first write path is verifiable end-to-end without any network dependency
- [ ] Applicable skill constraints satisfied: `cadence-data-layer` (SyncCoordinator is sole Supabase gateway, no prediction logic in SyncCoordinator, offline-first contract enforced), `cadence-sync` (write queue pattern, local write first, no UI blocking), `cadence-testing` (FakeSyncCoordinator implements the protocol, test uses FakeSyncCoordinator not real coordinator for isolation), `swiftui-production` (no force unwraps, actor isolation used correctly)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No Supabase SDK import in any file produced by this epic
- [ ] Source document alignment verified: Phase 3 scope is queue structure only; no Supabase write calls exist anywhere in this epic's output

## Source References

- cadence-data-layer skill §4 (Offline-First Write Contract -- write path example, sync status lifecycle)
- cadence-data-layer skill §6 (Architectural Boundaries -- SyncCoordinator as sole Supabase gateway)
- cadence-sync skill (write queue pattern description -- Phase 3 scope only; flush, conflict resolution, NWPathMonitor are Phase 7)
- cadence-testing skill §2 (DI requirement: SyncCoordinatorProtocol, FakeSyncCoordinator pattern)
- PHASES.md: Phase 3 -- Core Data Layer & Prediction Engine (In-Scope item 5: "SyncCoordinator class skeleton with write queue structure")
- PHASES.md: Phase 7 -- Sync Layer (Out of Scope for Phase 3: full implementation, Realtime, conflict resolution)
