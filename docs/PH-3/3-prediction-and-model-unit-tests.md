# Prediction and Model Unit Tests

**Epic ID:** PH-3-E3
**Phase:** 3 -- Core Data Layer & Prediction Engine
**Estimated Size:** M
**Status:** Draft

---

## Objective

Write all unit tests required by the cadence-testing skill for Phase 3 deliverables: the 10 mandated `PredictionEngine` edge case tests, the SwiftData model layer tests (syncStatus lifecycle, open-period enforcement, DailyLog uniqueness, prediction trigger), and the `FakeSyncCoordinator` fake implementation. Achieve a verifiable pass rate of 100% on all 10 edge cases before Phase 3 is declared complete. Establish the test file layout and fixtures that Phases 4-14 will extend.

## Problem / Context

The cadence-testing skill mandates 10 specific `PredictionEngine` unit tests and defines their exact inputs and expected outputs. These tests are not advisory -- they are required before Phase 3 is done. Without them, the prediction algorithm's correctness is unverified and every phase that reads predictions could surface incorrect data without detection.

The model layer tests verify invariants that the schema epic establishes but cannot self-test: syncStatus transitions, the single-open-period rule, and DailyLog uniqueness. These are contract-critical -- a missing test here is a release blocker per the cadence-testing skill (§5, §9).

Source authority: cadence-testing skill §2, §3, §4 defines every required test, fixture pattern, and naming convention for this epic.

## Scope

### In Scope

- `CadenceTests/` source directory creation
- `CadenceTests/Domain/PredictionEngineTests.swift` -- all 10 required edge case tests
- `CadenceTests/Models/SwiftDataModelTests.swift` -- syncStatus lifecycle tests, open-period enforcement tests, DailyLog uniqueness tests, prediction recalculation trigger test, SymptomLog association test
- `CadenceTests/Fakes/FakeSyncCoordinator.swift` -- `actor FakeSyncCoordinator: SyncCoordinatorProtocol` with `enqueuedWrites: [PendingWrite]` capture
- Fixed anchor date established as a shared test constant: `Date(timeIntervalSinceReferenceDate: 0)` (Jan 1, 2001 00:00:00 UTC) -- no test uses `Date()`
- `project.yml` additions: `CadenceTests/` source directory bound to the `CadenceTests` test target

### Out of Scope

- Privacy filter unit tests (PH-3 scope does not include privacy filtering logic -- that belongs in Phase 8)
- UI tests (Phase 4 and later, once Log Sheet and chip components exist)
- ViewModel unit tests (ViewModels are Phase 4+)
- `PredictionEngine` 90% line coverage measurement -- measured via Xcode coverage report; verified in Phase 14 gate, not Phase 3

## Dependencies

| Dependency                                                                 | Type | Phase/Epic | Status | Risk |
| -------------------------------------------------------------------------- | ---- | ---------- | ------ | ---- |
| All 5 SwiftData @Model types and enums                                     | FS   | PH-3-E1    | Open   | Low  |
| `PredictionEngine.recalculate(completedPeriods:cycleProfile:)` implemented | FS   | PH-3-E2    | Open   | Low  |
| `writePeriodLog` function (for prediction trigger test)                    | FS   | PH-3-E2-S5 | Open   | Low  |
| `SyncCoordinatorProtocol` interface (FakeSyncCoordinator implements it)    | FS   | PH-3-E4-S1 | Open   | Low  |
| `CadenceTests` target declared in `project.yml`                            | FS   | PH-3-E1-S6 | Open   | Low  |

## Assumptions

- All tests in `PredictionEngineTests.swift` are synchronous `func test_...()` XCTest methods. No `async` tests in this file -- `PredictionEngine.recalculate` is synchronous.
- The fixed anchor date `Date(timeIntervalSinceReferenceDate: 0)` represents Jan 1, 2001 00:00:00 UTC. All test fixtures use `Calendar.current.date(byAdding: .day, value: N, to: anchor)!` offsets from this anchor. Tests may behave differently in time zones far from UTC -- adding `.startOfDay` normalization to fixture construction is required.
- `FakeSyncCoordinator` has zero import of any Supabase SDK type. It imports only `Foundation` and the app module. This is an absolute rule (cadence-testing skill §9).
- `SwiftDataModelTests` creates a fresh `ModelContainer` via `makeTestContainer()` in each test method's setup. No container is shared between test methods.
- The prediction trigger test verifies that `writePeriodLog` inserts a `PredictionSnapshot` into the context -- it does not assert specific date values (those are covered by `PredictionEngineTests`).

## Risks

| Risk                                                                                                                                                   | Likelihood | Impact | Mitigation                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Anchor date `Date(timeIntervalSinceReferenceDate: 0)` resolves to different calendar dates in time zones west of UTC (e.g., Dec 31 2000 in US Pacific) | Medium     | Medium | Use `Calendar.current.startOfDay(for: anchor)` when constructing fixture dates to ensure day-boundary correctness regardless of time zone |
| SwiftData model tests fail non-deterministically when `ModelContainer` is shared between test methods                                                  | Low        | High   | Enforce fresh `makeTestContainer()` call in each test body or `setUp()` -- never store container as a class property                      |
| `FakeSyncCoordinator` accumulates `enqueuedWrites` across tests if the fake is a shared instance                                                       | Low        | Medium | `FakeSyncCoordinator` is instantiated fresh per test -- never stored as a class-level property of the test case                           |

---

## Stories

### S1: FakeSyncCoordinator and test infrastructure

**Story ID:** PH-3-E3-S1
**Points:** 2

Create `FakeSyncCoordinator` and the shared anchor date constant used across all test files. Verify the `CadenceTests` target builds successfully with at least one passing test.

**Acceptance Criteria:**

- [ ] `CadenceTests/Fakes/FakeSyncCoordinator.swift` exists with `actor FakeSyncCoordinator: SyncCoordinatorProtocol`
- [ ] `FakeSyncCoordinator` has `private(set) var enqueuedWrites: [PendingWrite] = []` and `func enqueue(_ write: PendingWrite) async { enqueuedWrites.append(write) }`
- [ ] No Supabase SDK type is imported in `FakeSyncCoordinator.swift` -- only `Foundation` and the app module
- [ ] A shared `TestFixtures.swift` (or equivalent) declares `static let anchorDate = Date(timeIntervalSinceReferenceDate: 0)` in a `enum TestFixtures` (case-less enum as namespace)
- [ ] `CadenceTests` scheme runs successfully in Xcode -- at least one trivial test (e.g., `test_sanity_pass()` asserting `1 == 1`) confirms the target is configured correctly
- [ ] `project.yml` sources for `CadenceTests` target include `CadenceTests/Fakes/` and `CadenceTests/` paths

**Dependencies:** PH-3-E4-S1 (SyncCoordinatorProtocol and PendingWrite types required by FakeSyncCoordinator)
**Notes:** The `TestFixtures` enum namespace pattern is preferred over a struct to prevent instantiation. The anchor date is a constant, not a computed property -- `Date(timeIntervalSinceReferenceDate: 0)` always returns the same value regardless of runtime.

---

### S2: PredictionEngine unit tests -- all 10 edge cases

**Story ID:** PH-3-E3-S2
**Points:** 8

Write all 10 required `PredictionEngine` edge case tests defined in cadence-testing skill §3. Each test is a dedicated function following the naming convention `test_predictionEngine_<scenario>_<expectedOutcome>()`.

**Acceptance Criteria:**

- [ ] `CadenceTests/Domain/PredictionEngineTests.swift` exists with exactly 10 test functions (may have additional helper functions, but the 10 required tests are all present and named correctly)
- [ ] **Test 1 -- zero cycles:** `test_predictionEngine_zeroCycles_usesDefaultsAndLowConfidence()` -- input: empty `[PeriodLog]`, cycleProfile with default averages -- assert `cyclesUsed == 0`, `confidenceLevel == .low`
- [ ] **Test 2 -- one completed cycle:** `test_predictionEngine_oneCompletedCycle_lowConfidence()` -- input: 1 completed PeriodLog (startDate and endDate set) -- assert `cyclesUsed == 1`, `confidenceLevel == .low`
- [ ] **Test 3 -- two completed cycles:** `test_predictionEngine_twoCompletedCycles_mediumConfidence()` -- assert `cyclesUsed == 2`, `confidenceLevel == .medium`
- [ ] **Test 4 -- three completed cycles:** `test_predictionEngine_threeCompletedCycles_mediumConfidence()` -- assert `cyclesUsed == 3`, `confidenceLevel == .medium`
- [ ] **Test 5 -- four cycles SD under 2 days:** `test_predictionEngine_fourCyclesSDUnder2Days_highConfidence()` -- cycle lengths [28, 28, 28, 28] (SD = 0.0) -- assert `confidenceLevel == .high`
- [ ] **Test 6 -- four cycles SD over 2 days:** `test_predictionEngine_fourCyclesSDOver2Days_mediumConfidence()` -- cycle lengths [24, 28, 32, 28] (SD ≈ 3.27) -- assert `confidenceLevel == .medium`
- [ ] **Test 7 -- SD equals 2.0 exactly:** `test_predictionEngine_sdExactly2Days_highConfidence()` -- cycle lengths [27, 27, 27, 31] (mean = 28, sample SD = 2.0 exactly) -- assert `confidenceLevel == .high` (boundary is inclusive at 2.0)
- [ ] **Test 8 -- open period excluded:** `test_predictionEngine_openPeriodExcluded_notCountedAsCycle()` -- input: 1 open PeriodLog (endDate = nil) -- assert `cyclesUsed == 0`, `confidenceLevel == .low`
- [ ] **Test 9 -- more than 6 cycles:** `test_predictionEngine_moreThan6Cycles_usesOnly6MostRecent()` -- input: 8 completed PeriodLogs -- assert `cyclesUsed == 6`
- [ ] **Test 10 -- algorithm spot-check:** `test_predictionEngine_knownInput_correctOutputDates()` -- `lastPeriodStartDate = Jan 1 2001`, `averageCycleLength = 28` -- assert `predictedNextPeriod = Jan 29 2001`, `predictedOvulation = Jan 15 2001`, `fertileWindowStart = Jan 10 2001`, `fertileWindowEnd = Jan 15 2001`
- [ ] All date fixtures use `Calendar.current.date(byAdding: .day, value: N, to: TestFixtures.anchorDate)!` or `Calendar.current.startOfDay(for: ...)` -- no `Date()` call anywhere in the file
- [ ] All tests are synchronous `func test_...()` -- no `async` test methods
- [ ] All 10 tests pass in the Xcode test runner
- [ ] `project.yml` updated with `CadenceTests/Domain/PredictionEngineTests.swift`

**Dependencies:** PH-3-E3-S1, PH-3-E2 (PredictionEngine fully implemented)
**Notes:** Test 7 fixture construction: build 4 PeriodLog records with start-to-start intervals of [27, 27, 27, 31] days. Verify SD by calculation: mean=28, deviations=[-1,-1,-1,3], sum of squared deviations=12, variance=12/3=4.0, SD=2.0 exactly. This is the only integer-cycle-length combination that produces exactly SD=2.0 with 4 values summing to 0 deviation from mean 28. Use `Calendar.current.startOfDay(for: TestFixtures.anchorDate)` as the first period start to avoid time-zone edge cases in date arithmetic.

---

### S3: SwiftData model layer unit tests

**Story ID:** PH-3-E3-S3
**Points:** 5

Write the model layer tests from cadence-testing skill §4: syncStatus lifecycle, open-period enforcement, DailyLog uniqueness, prediction recalculation trigger, and SymptomLog association. Every test uses a fresh in-memory `ModelContainer`.

**Acceptance Criteria:**

- [ ] `CadenceTests/Models/SwiftDataModelTests.swift` exists
- [ ] Every test method calls `makeTestContainer()` and creates a fresh `ModelContext` -- no shared container at class level
- [ ] **syncStatus lifecycle -- insert:** Insert any `@Model` instance → assert `syncStatus == .pending`
- [ ] **syncStatus lifecycle -- synced:** Mutate `syncStatus = .synced` → save → fetch → assert `syncStatus == .synced`
- [ ] **syncStatus lifecycle -- error:** Mutate `syncStatus = .error` → save → fetch → assert `syncStatus == .error`
- [ ] **Open-period enforcement -- single open allowed:** Insert one `PeriodLog` with `endDate == nil` → fetch using `openPeriodPredicate` → assert count == 1
- [ ] **Open-period enforcement -- second open rejected:** Attempt to call a function that enforces the constraint before inserting a second open period → assert the function returns a non-nil error or an empty result (demonstrating the predicate would catch the duplicate); the predicate must return 1 result after the first insert, signaling the caller to reject the second insert
- [ ] **Open-period enforcement -- closed period does not trigger:** Insert a `PeriodLog` with `endDate` set → fetch using `openPeriodPredicate` → assert count == 0
- [ ] **DailyLog uniqueness -- first insert stored:** Insert one `DailyLog` for `(userId, date)` → fetch using `existingLogPredicate` → assert count == 1
- [ ] **DailyLog uniqueness -- duplicate date detected:** Insert second `DailyLog` for the same `(userId, date)` → fetch using `existingLogPredicate` → assert count == 2 (the predicate detects the duplicate; the write-time enforcement in the caller is what prevents it, not SwiftData itself -- the test verifies the predicate works for that enforcement)
- [ ] **Prediction recalculation trigger:** Call `writePeriodLog` with a `FakeSyncCoordinator` and in-memory context → after the call, fetch `PredictionSnapshot` records → assert count >= 1
- [ ] **SymptomLog association:** Insert a `DailyLog`, note its `id`, insert a `SymptomLog` with `dailyLogId = log.id` → fetch `SymptomLog` with `dailyLogId == log.id` predicate → assert count == 1, `symptomType == .cramps` (or whichever type was inserted)
- [ ] All 10+ tests pass in the Xcode test runner
- [ ] `project.yml` updated with `CadenceTests/Models/SwiftDataModelTests.swift`

**Dependencies:** PH-3-E3-S1, PH-3-E1 (all @Model types), PH-3-E2-S5 (`writePeriodLog` function)
**Notes:** The "duplicate date detected" test intentionally inserts two `DailyLog` records for the same date to confirm the predicate returns count 2, which the calling code uses to detect and reject the duplicate. SwiftData has no composite unique constraint -- the enforcement is the predicate + write-time guard in the caller.

---

### S4: Test suite hygiene verification

**Story ID:** PH-3-E3-S4
**Points:** 2

Verify the full `CadenceTests` test suite runs cleanly in CI conditions: no shared state between tests, no `Date()` calls, no Supabase imports, 100% pass rate. Confirm `project.yml` test target is complete.

**Acceptance Criteria:**

- [ ] Running `xcodebuild test -scheme CadenceTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` produces 0 test failures and 0 test errors
- [ ] `grep -r "Date()" CadenceTests/` returns no matches in non-empty test files (all date usage goes through `TestFixtures.anchorDate` or explicit `Date(timeIntervalSinceReferenceDate:)`)
- [ ] `grep -r "import Supabase\|import PostgREST\|import GoTrue" CadenceTests/` returns no matches
- [ ] `grep -r "\.shared\|SupabaseClient" CadenceTests/` returns no matches
- [ ] No `ModelContainer` instance is declared as a `let` or `var` at the `XCTestCase` class level (all containers are created inside individual test methods or `setUp()` with `tearDown()` nil-out)
- [ ] `xcodebuild build-for-testing -scheme CadenceTests` succeeds without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** PH-3-E3-S2, PH-3-E3-S3
**Notes:** This story is explicitly a hygiene gate, not new feature work. Its purpose is to catch test-infrastructure anti-patterns before Phase 4 test files are added. Failures here indicate a structural problem in S1-S3 that must be fixed before declaring Phase 3 done.

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
- [ ] All 10 `PredictionEngine` edge case tests pass
- [ ] All SwiftData model layer tests pass
- [ ] `xcodebuild test -scheme CadenceTests` exits 0 with 0 failures
- [ ] No `Date()` call exists in any test file
- [ ] No Supabase SDK import exists in any test file
- [ ] `FakeSyncCoordinator` has zero Supabase SDK imports
- [ ] Phase objective is advanced: the prediction algorithm is proven correct against all mandatory edge cases; the model layer invariants are verified
- [ ] Applicable skill constraints satisfied: `cadence-testing` (all 10 PredictionEngine tests per §3, model layer tests per §4, no live Supabase per §9, FakeSyncCoordinator per §2, fixed anchor date per §3, fresh container per test per §2), `cadence-xcode-project` (test target properly declared in project.yml)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Source document alignment verified: all 10 edge case tests match cadence-testing skill §3 table exactly

## Source References

- cadence-testing skill §2 (test target architecture, in-memory ModelContainer factory, DI patterns, FakeSyncCoordinator)
- cadence-testing skill §3 (all 10 PredictionEngine edge cases -- inputs, expected outputs, naming convention, date fixture rules)
- cadence-testing skill §4 (SwiftData model layer test coverage areas)
- cadence-testing skill §9 (no live Supabase in any test)
- PHASES.md: Phase 3 -- Core Data Layer & Prediction Engine (In-Scope item 6: "unit tests for all prediction edge cases (10 required per cadence-testing skill)")
