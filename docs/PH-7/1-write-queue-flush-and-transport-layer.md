# Write Queue Flush, Typed Transport Layer, and Initial Data Pull

**Epic ID:** PH-7-E1
**Phase:** 7 -- Sync Layer
**Estimated Size:** L
**Status:** Draft

---

## Objective

Promote `SyncCoordinator` from the Phase 3 in-memory skeleton to a live Supabase-backed service. This epic delivers: typed Codable transport models for all five writable tables, a persistent write queue that survives app termination, a `flush()` drain loop that upserts the queue to Supabase in insertion order, and an initial data pull that populates SwiftData from Supabase on first authenticated launch. After this epic, every user write that occurred offline is durably queued and will reach Supabase; the app no longer loses queued writes on process kill.

## Problem / Context

Phase 3 (PH-3-E4) established `SyncCoordinator` with an in-memory `[PendingWrite]` queue and a no-op `flush()` stub. The queue was intentionally non-persistent -- Phase 3 notes state "records lost in memory will be re-queued when the app relaunches and detects `.pending` syncStatus records in SwiftData; Phase 7 implements this recovery path." Similarly, the Phase 3 `SyncCoordinator` holds no `SupabaseClient` reference and makes no network calls.

Without this epic, every write after a force-quit is permanently lost. The user's medical history (period logs, symptom logs, prediction snapshots) exists only in local SwiftData with no path to the backend. No other Phase 7 epic (conflict resolution, Realtime, retry) can function without the flush path and typed models this epic establishes.

Source authority: cadence-sync skill §2 (write queue pattern), §8 (UI-thread safety); cadence-supabase skill §4 (typed client enforcement); MVP Spec §NFR (reliability: no data loss on termination, sync on reconnect); Design Spec v1.1 §13 (sync failure states).

## Scope

### In Scope

- `SyncableModel` Swift protocol: `updatedAt: Date`, `syncStatus: SyncStatus` (shared with PH-7-E2)
- `SyncStatus` enum: `.pending`, `.synced`, `.error` (used by all downstream epics)
- `SupabaseModels.swift`: typed `Codable` transport structs for `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots` -- explicit `CodingKeys` for snake_case columns; no `select("*")` anywhere
- Queue persistence: `SyncCoordinator.init` scans SwiftData for all models with `syncStatus == .pending` and re-enqueues them as `PendingWrite` entries, restoring the queue across termination
- `SupabaseClient` reference injected into `SyncCoordinator` at construction
- `func flush() async` on `SyncCoordinator`: iterates the queue in insertion order, calls `supabase.from(table).upsert(payload).execute()` for each entry, updates `syncStatus` to `.synced` on success and `.error` on failure (retry logic is PH-7-E4)
- `func flush() async` added to `SyncCoordinatorProtocol` so `FakeSyncCoordinator` (PH-3-E3) must implement a stub
- `FakeSyncCoordinator.flush()` stub: records calls, does not call Supabase
- `func pullInitialData() async throws` on `SyncCoordinator`: fetches all rows for the authenticated user from Supabase and writes them into SwiftData, marking each `.synced`; guarded by a check that local SwiftData is empty (no double-pull)
- `SyncCoordinator` environment injection update: pass `SupabaseClient` singleton at app launch
- `project.yml` additions for all new Swift files

### Out of Scope

- Exponential backoff retry on failed upserts (PH-7-E4)
- 401 auth error handling (PH-7-E4)
- `applyRemote()` freshness check before SwiftData writes (PH-7-E2)
- Realtime subscriptions (PH-7-E3)
- `NWPathMonitor` and `isOnline` wiring (PH-7-E4 -- `isOnline` remains hardcoded `true` from Phase 3)
- Offline UI indicators (PH-7-E4)
- `authStateChanges` observation (PH-7-E4)
- partner-specific RLS-gated data reads on behalf of the Partner client (PH-8)

## Dependencies

| Dependency                                                                                   | Type | Phase/Epic | Status | Risk   |
| -------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ------ |
| SyncCoordinator actor skeleton (in-memory queue, PendingWrite, SyncCoordinatorProtocol)      | FS   | PH-3-E4    | Open   | Low    |
| 5 SwiftData @Model types (CycleProfile, PeriodLog, DailyLog, SymptomLog, PredictionSnapshot) | FS   | PH-3-E1    | Open   | Low    |
| FakeSyncCoordinator (must be updated to add flush() stub)                                    | SS   | PH-3-E3    | Open   | Low    |
| Supabase project live with tables created, RLS enabled, anon key in xcconfig                 | FS   | PH-1-E1    | Open   | Medium |
| Schema migration (all 8 tables exist in Supabase)                                            | FS   | PH-1-E2    | Open   | Medium |
| supabase-swift SPM package available in the Xcode project                                    | FS   | PH-1-E4    | Open   | Low    |

## Assumptions

- The Phase 3 `SyncCoordinator` `isOnline: Bool` property remains hardcoded `true` for this epic. `NWPathMonitor` wiring is PH-7-E4's responsibility.
- `pullInitialData()` uses a simple emptiness guard on SwiftData: if `ModelContext` returns zero `PeriodLog` rows for the current user, pull is performed. This is the MVP single-device assumption -- multi-device conflict merge is post-beta.
- The `flush()` drain loop in this epic calls `supabase.from(table).upsert(payload).execute()` directly without retry. A single transient failure marks the entry `.error` and moves on. PH-7-E4 wraps this in `attempt()` with backoff.
- `SupabaseModels.swift` defines transport-layer types only. Domain models in `Cadence/Models/` remain distinct. Service layer converts between them.
- The queue recovery on launch scans for `.pending` models across all five writable tables in insertion order (approximated by SwiftData fetch sort on `updatedAt` ascending). Perfect FIFO ordering across app restarts is best-effort; causal consistency is maintained per-entity.
- `SupabaseClient` is initialized once at app startup in `CadenceApp.swift` and passed to `SyncCoordinator` at construction. No ViewModel or View initializes `SupabaseClient` directly.

## Risks

| Risk                                                                                                     | Likelihood | Impact | Mitigation                                                                                                  |
| -------------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------- |
| Adding `flush()` to `SyncCoordinatorProtocol` breaks existing test conformances on `FakeSyncCoordinator` | High       | Low    | S5 explicitly updates `FakeSyncCoordinator` as part of this epic; the story fails its AC if build is broken |
| `pullInitialData()` races with a concurrent `flush()` on launch, causing duplicate upserts               | Low        | Low    | Both paths upsert (idempotent by primary key); last upsert wins; no data corruption possible                |
| SwiftData `@Model` types do not yet have `updatedAt` and `syncStatus` fields defined in Phase 3          | High       | High   | S1 adds these fields to the @Model types and the schema migration; this is the first story in the epic      |
| Supabase project not yet created (Phase 1 incomplete)                                                    | Medium     | High   | Phase 1 must be complete before this epic starts; dependency listed; do not begin S4+ without Phase 1 live  |

---

## Stories

### S1: SyncableModel protocol and SyncStatus enum

**Story ID:** PH-7-E1-S1
**Points:** 2

Define the `SyncableModel` protocol and `SyncStatus` enum that all five SwiftData `@Model` types must conform to. Add `updatedAt: Date` and `syncStatus: SyncStatus` fields to each existing `@Model` type. These fields are the foundation for conflict resolution (PH-7-E2) and queue persistence.

**Acceptance Criteria:**

- [ ] `Cadence/Services/SyncableModel.swift` exists containing:
- [ ] ```swift
      protocol SyncableModel: AnyObject {
          var updatedAt: Date { get set }
          var syncStatus: SyncStatus { get set }
      }
      enum SyncStatus: String, Codable {
          case pending, synced, error
      }
      ```
- [ ] `CycleProfile`, `PeriodLog`, `DailyLog`, `SymptomLog`, and `PredictionSnapshot` each declare `var updatedAt: Date` and `var syncStatus: SyncStatus` as stored properties with default `syncStatus = .pending`
- [ ] All five `@Model` types conform to `SyncableModel` in their respective source files
- [ ] `SyncStatus` is `Codable` so it persists through SwiftData automatically
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] `project.yml` updated with `SyncableModel.swift` under `Cadence/Services/`

**Dependencies:** PH-3-E1 (the five @Model types)
**Notes:** `updatedAt` must be set to `Date()` in every write path that creates or mutates one of these models. This is enforced at the call sites (service layer), not in the model itself. The field enables the last-write-wins comparison in PH-7-E2.

---

### S2: Typed Supabase transport models

**Story ID:** PH-7-E1-S2
**Points:** 5

Create `SupabaseModels.swift` containing typed `Codable` transport structs for all five Supabase tables this epic writes to. These structs are the serialization boundary between SwiftData domain models and the Supabase wire format.

**Acceptance Criteria:**

- [ ] `Cadence/Services/SupabaseModels.swift` exists with five `Codable` structs: `CycleProfileRow`, `PeriodLogRow`, `DailyLogRow`, `SymptomLogRow`, `PredictionSnapshotRow`
- [ ] Each struct has explicit `CodingKeys` mapping Swift camelCase to Postgres snake_case (e.g. `userId = "user_id"`, `flowLevel = "flow_level"`, `isPrivate = "is_private"`, `updatedAt = "updated_at"`, `syncStatus = "sync_status"`)
- [ ] `DailyLogRow` includes `id`, `userId`, `date`, `flowLevel`, `mood`, `sleepQuality`, `notes`, `isPrivate`, `updatedAt` -- no extra columns
- [ ] `PeriodLogRow` includes `id`, `userId`, `startDate`, `endDate`, `source`, `updatedAt`
- [ ] `SymptomLogRow` includes `id`, `dailyLogId`, `symptomType`, `updatedAt`
- [ ] `PredictionSnapshotRow` includes `id`, `userId`, `dateGenerated`, `predictedNextPeriod`, `predictedOvulation`, `fertileWindowStart`, `fertileWindowEnd`, `confidenceLevel`, `updatedAt`
- [ ] `CycleProfileRow` includes `userId`, `averageCycleLength`, `averagePeriodLength`, `goalMode`, `predictionsEnabled`, `updatedAt`
- [ ] No struct uses `[String: Any]` or raw JSON dictionary types
- [ ] A static `func from(_ model: T) -> Self` converter exists on each struct (converts domain model to transport row)
- [ ] A `func apply(to model: T)` method exists on each struct (applies transport row fields to the domain model)
- [ ] File compiles without errors or warnings
- [ ] `project.yml` updated with `SupabaseModels.swift`

**Dependencies:** PH-7-E1-S1 (updatedAt and syncStatus must exist on domain models before converter functions compile)
**Notes:** `symptom_type` in `SymptomLogRow` maps to the `SymptomType` enum defined in PH-3-E1. Sex symptom is present in the struct but excluded at the query layer in PH-8 (privacy-architecture enforcement). Transport structs are not domain models -- do not add business logic here.

---

### S3: Queue persistence via SwiftData syncStatus recovery

**Story ID:** PH-7-E1-S3
**Points:** 5

Implement the queue recovery path in `SyncCoordinator.init` so that any write that was enqueued before a process kill (and thus survived as a `.pending` record in SwiftData) is re-enqueued on the next launch. After this story, the in-memory queue is never the only record of a pending write -- the backing `.pending` `syncStatus` in SwiftData serves as the durable receipt.

**Acceptance Criteria:**

- [ ] `SyncCoordinator.init(supabase: SupabaseClient, modelContext: ModelContext)` accepts both the Supabase client and the shared `ModelContext` as parameters (replacing the no-argument initializer from Phase 3)
- [ ] On `init`, `SyncCoordinator` performs a synchronous SwiftData fetch across all five writable @Model types filtered to `syncStatus == .pending`, sorted ascending by `updatedAt`
- [ ] Each recovered model is converted to a `PendingWrite` entry and appended to `queue` in the fetched sort order
- [ ] `SyncCoordinator.pendingCount` after a recovery init with 3 pre-existing `.pending` models returns `3`
- [ ] The existing `enqueue()` method sets `model.syncStatus = .pending` before appending to the queue (this was implicit in Phase 3; make it explicit here as the durable receipt)
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S1 (syncStatus field on @Model types), PH-3-E4 (existing SyncCoordinator actor structure)
**Notes:** The sort on `updatedAt` ascending is the best available approximation of original insertion order across a process restart. True FIFO is maintained within a single session by the existing `queue.append` order. Cross-session ordering is best-effort and sufficient for the MVP single-device assumption.

---

### S4: flush() drain loop implementation

**Story ID:** PH-7-E1-S4
**Points:** 8

Implement `SyncCoordinator.flush() async` as an ordered queue drain that upserts each `PendingWrite` entry to the correct Supabase table using the typed transport structs from S2. Queue entries process in insertion order. A failed upsert marks the model `.error` and the entry is removed from the queue to prevent blocking subsequent entries. Successful upserts mark the model `.synced`. This is the baseline flush without exponential backoff -- PH-7-E4-S3 wraps this with `attempt()`.

**Acceptance Criteria:**

- [ ] `SyncCoordinator.flush() async` iterates `queue` in insertion order (index 0 first)
- [ ] For each `PendingWrite` entry, the correct Supabase table is targeted based on the enum case: `.cycleProfile` -> `cycle_profiles`, `.periodLog` -> `period_logs`, `.dailyLog` -> `daily_logs`, `.symptomLog` -> `symptom_logs`, `.predictionSnapshot` -> `prediction_snapshots`
- [ ] Each upsert uses the corresponding `*Row` struct from `SupabaseModels.swift` and calls `.upsert(row).execute()`; no `[String: Any]` dictionary payloads anywhere
- [ ] On success: `entry.model.syncStatus = .synced`; entry is removed from `queue`
- [ ] On failure (any `Error` thrown): `entry.model.syncStatus = .error`; entry is removed from `queue`; no rethrow to caller (non-blocking)
- [ ] After `flush()` completes, `queue` contains only entries that were added while `flush()` was running (the drain is non-destructive to new arrivals)
- [ ] `flush()` is never called on the main actor directly; all call sites use `Task { await syncCoordinator.flush() }`
- [ ] `func flush() async` is added to `SyncCoordinatorProtocol`
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S2 (typed transport models), PH-7-E1-S3 (queue with model references), PH-1-E2 (tables exist in Supabase)
**Notes:** The queue drain loop must capture a snapshot of the current queue at the start of `flush()` to avoid iterating a concurrently-modified array. New entries enqueued during a flush are not processed in the same flush call -- they are picked up on the next `flush()` invocation (triggered by NWPathMonitor in PH-7-E4).

---

### S5: FakeSyncCoordinator flush() stub

**Story ID:** PH-7-E1-S5
**Points:** 2

Update `FakeSyncCoordinator` (from PH-3-E3) to satisfy the updated `SyncCoordinatorProtocol` after `flush()` is added to the protocol in S4. Without this story, the test target does not compile.

**Acceptance Criteria:**

- [ ] `FakeSyncCoordinator` in `CadenceTests/` implements `func flush() async` (no Supabase calls)
- [ ] `FakeSyncCoordinator.flush()` records that it was called: `private(set) var flushCallCount: Int = 0`; increments on each invocation
- [ ] All existing `SyncCoordinatorTests` from PH-3-E4-S3 continue to pass after this change
- [ ] Test target builds without errors or warnings

**Dependencies:** PH-7-E1-S4 (flush() added to SyncCoordinatorProtocol), PH-3-E3 (FakeSyncCoordinator source file)
**Notes:** `flushCallCount` enables assertions like `XCTAssertEqual(fake.flushCallCount, 1)` in downstream test stories. Do not add logic to the fake; it must remain a minimal stub.

---

### S6: Initial data pull on first authenticated launch

**Story ID:** PH-7-E1-S6
**Points:** 5

Implement `SyncCoordinator.pullInitialData(userId: UUID) async throws` to fetch all existing Supabase rows for the authenticated user and write them into SwiftData. This path fires once per account, guarded by a SwiftData emptiness check, and marks all written models `.synced`. It enables a user who authenticated on a fresh device (or after a data wipe) to recover their history without re-entering it.

**Acceptance Criteria:**

- [ ] `func pullInitialData(userId: UUID) async throws` exists on `SyncCoordinator`
- [ ] The emptiness guard: if `ModelContext` fetch for `PeriodLog` filtered to `userId` returns any results, `pullInitialData` is a no-op and returns immediately without making any Supabase requests
- [ ] If guard passes, fetch all five tables for `userId` in parallel using Swift `async let` bindings
- [ ] Each fetched row is converted from its `*Row` transport struct to the corresponding `@Model` type via `apply(to:)` and inserted into `ModelContext`
- [ ] All inserted models have `syncStatus = .synced` after insert (they are already on the server)
- [ ] `pullInitialData` is called from `AppCoordinator` or the auth completion handler immediately after a successful `signedIn` event, before the main tab view is shown
- [ ] Supabase queries use explicit column projection (no `.select("*")` on any fetch)
- [ ] `pullInitialData` is `throws` -- any Supabase fetch failure propagates to the call site; the caller surfaces a non-blocking offline indicator (PH-7-E4) rather than crashing
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S2 (typed transport structs with `apply(to:)` converter), PH-7-E1-S3 (ModelContext available in SyncCoordinator), PH-1-E2 (tables exist)
**Notes:** Parallel fetches use `async let` not `TaskGroup` -- five independent queries, fixed arity. Insertion order into SwiftData is not significant for the initial pull since no local data exists to conflict with. Do not call `applyRemote()` here -- that method is for live Realtime events where local data may exist. PH-7-E2 implements `applyRemote()`.

---

### S7: Flush path unit tests

**Story ID:** PH-7-E1-S7
**Points:** 5

Write unit tests covering: queue drain ordering, flush removes entries from queue on success, flush marks model `.error` on failure, queue persistence recovery on init, and initial data pull emptiness guard.

**Acceptance Criteria:**

- [ ] `CadenceTests/Sync/WriteQueueFlushTests.swift` exists with at least 6 test functions
- [ ] **Test 1 -- ordered drain:** Enqueue `.periodLog(log1)` then `.dailyLog(log2)` -> call `flush()` on a fake Supabase -> assert log1 upserted before log2 (verify via call order on the mock)
- [ ] **Test 2 -- success clears queue:** After `flush()` with a succeeding mock, `syncCoordinator.pendingCount == 0` and both models have `syncStatus == .synced`
- [ ] **Test 3 -- failure marks error, clears entry:** Inject a mock that throws on the second upsert -> assert second model has `syncStatus == .error`, first has `.synced`, `pendingCount == 0` after flush
- [ ] **Test 4 -- recovery from pending models:** Create an in-memory `ModelContext` with one `PeriodLog` at `syncStatus == .pending` -> `SyncCoordinator(supabase: ..., modelContext: context)` -> assert `pendingCount == 1`
- [ ] **Test 5 -- recovery sort order:** Two `.pending` models with different `updatedAt` values -> assert queue order matches ascending `updatedAt`
- [ ] **Test 6 -- pullInitialData emptiness guard:** `ModelContext` with one existing `PeriodLog` -> call `pullInitialData()` -> assert zero Supabase fetch calls were made
- [ ] All tests use in-memory `ModelContainer` (no real SwiftData store on disk)
- [ ] All tests use a mock or stub for `SupabaseClient` -- no live Supabase calls in tests
- [ ] All tests are `async func test_...()` because `SyncCoordinator` methods are actor-isolated async functions
- [ ] Test target builds and all tests pass

**Dependencies:** PH-7-E1-S4, PH-7-E1-S5, PH-7-E1-S6

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
- [ ] `SyncCoordinator.flush()` is present in `SyncCoordinatorProtocol` and both the real and fake conformances compile
- [ ] `SupabaseModels.swift` contains zero `[String: Any]` payloads and zero `.select("*")` calls
- [ ] Every `@Model` type declares `updatedAt: Date` and `syncStatus: SyncStatus`
- [ ] Queue persistence recovery verified by Test 4 and Test 5 in S7
- [ ] `SupabaseClient` is never initialized outside `CadenceApp.swift`
- [ ] No Supabase calls on the main actor (verified: all `flush()` call sites use `Task { await ... }`)
- [ ] Integration with Phase 1 dependencies verified: tables exist, RLS active, anon key loaded from xcconfig
- [ ] Phase objective advanced: at least one offline write survives a simulated process kill and reaches Supabase on relaunch (manually verified in Simulator)
- [ ] Applicable skill constraints satisfied: `cadence-sync` (write queue pattern §2, UI-thread safety §8), `cadence-supabase` (typed client §4, singleton §1), `swiftui-production` (no force unwraps, actor isolation)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 7 -- Sync Layer (In-Scope: write queue with local-first guarantee; initial data pull on first authenticated launch; background async queue processing)
- PHASES.md: Phase 3 -- Core Data Layer (Out-of-Scope note: "Supabase writes (Phase 7)", "queue drain loop (Phase 7)", "SyncCoordinator.init reloads and resumes the queue")
- cadence-sync skill §2 (Write Queue Pattern -- Local First: enqueue returns before network, flush drain logic)
- cadence-sync skill §8 (UI-Thread Safety: flush must be called via Task from main actor, not awaited directly)
- cadence-supabase skill §4 (Typed Swift Client Enforcement: Codable structs, CodingKeys, no .select("\*"), transport vs domain boundary)
- cadence-supabase skill §1 (SupabaseClient singleton, xcconfig env var loading)
- Design Spec v1.1 §13 (Reliability: no data loss on app termination mid-log)
- MVP Spec §NFR (Reliability: offline logging, sync on reconnect, no data loss on termination)
- PH-3-E4 (SyncCoordinator skeleton -- defines the contract this epic implements)
