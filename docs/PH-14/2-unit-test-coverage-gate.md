# Unit Test Coverage Gate

**Epic ID:** PH-14-E2
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement all required unit tests across the prediction engine, SwiftData model layer, and privacy filter logic, and enforce a minimum coverage gate of 80% line coverage on data and domain layers before TestFlight. The coverage gate is a release blocker -- no TestFlight build may ship unless per-file thresholds defined in cadence-testing skill §10 are met.

## Problem / Context

Phases 3, 7, and 8 implemented `PredictionEngine`, the SwiftData schema, and the privacy architecture respectively. No unit tests were written during those phases -- they were deferred to Phase 14 per PHASES.md sequencing. Without this epic's test suite, the prediction algorithm's edge cases (zero cycles, open period exclusion, confidence tiers), the `isPrivate` master override, and the Sex symptom exclusion have no automated regression coverage. These are contract-critical correctness properties; a bug in any of them could expose a Partner to data they were never intended to see. The cadence-testing skill §§3-5 defines exact required test cases. The coverage gate (§10) is enforced via `xcov` in the Fastlane test lane from Epic 1.

## Scope

### In Scope

- `FakeSyncCoordinator.swift` and `SyncCoordinatorProtocol` -- DI infrastructure enabling `@Observable` ViewModel tests without a live Supabase connection
- In-memory `ModelContainer` factory function usable across all SwiftData unit tests
- `PredictionEngineTests.swift` -- all 10 required edge cases per cadence-testing skill §3
- `SwiftDataModelTests.swift` -- `syncStatus` lifecycle, open period enforcement, `DailyLog` uniqueness, prediction recalculation trigger, `SymptomLog` association per cadence-testing skill §4
- `PrivacyFilterTests.swift` -- `isPrivate` master override (3 required tests), Sex symptom exclusion (2 required tests), and 4-rule precedence hierarchy per cadence-testing skill §5
- `xcov` integration in Fastlane `test` lane: `minimum_coverage_percentage: 80.0` scoped to `Cadence.app` target
- Per-file coverage verification: `PredictionEngine.swift` >= 90%, privacy filter logic >= 90%, SwiftData models >= 80%, `@Observable` ViewModels >= 75% -- verified via `xcrun xccov view --report --json`
- All new test files registered in `project.yml` under `CadenceTests` target

### Out of Scope

- UI tests (Log Sheet, chip toggle, isPrivate UI flows) -- Epic 3 (PH-14-E3)
- UI test infrastructure (`--in-memory-store` launch argument, `XCUIApplication` setup) -- Epic 3 (PH-14-E3)
- ViewModels not yet testable without DI refactor: if any ViewModel was implemented with a concrete `SupabaseClient` property, the DI refactor of that ViewModel is a prerequisite task to document as a blocker, not added speculatively here
- Integration tests against a live Supabase instance -- explicitly prohibited by cadence-testing skill §9

## Dependencies

| Dependency                                                                                                                          | Type | Phase/Epic | Status | Risk |
| ----------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---- |
| `PredictionEngine` implemented with rolling-average algorithm and 3 confidence tiers                                                | FS   | PH-3-E2    | Open   | Low  |
| SwiftData schema fully defined: `CycleProfile`, `PeriodLog`, `DailyLog`, `SymptomLog`, `PredictionSnapshot` with `syncStatus` field | FS   | PH-3-E1    | Open   | Low  |
| Privacy filter logic implemented: `isPrivate` override, `is_paused` check, Sex symptom exclusion, `share_*` flag evaluation         | FS   | PH-8-E5    | Open   | Low  |
| `CadenceTests` target registered in `project.yml` with `CadenceTests` scheme                                                        | FS   | PH-0-E1    | Open   | Low  |
| Epic 1 CI infrastructure: Fastlane `test` lane with `result_bundle: true`                                                           | SS   | PH-14-E1   | Open   | Low  |

## Assumptions

- `PredictionEngine` is a pure Swift struct that takes `[PeriodLog]` as input and returns a prediction result -- no network surface, DI not required per cadence-testing skill §2.
- Privacy filter logic is implemented as a standalone function or method testable independently of `SyncCoordinator` -- no Supabase call needed to test the filter rules.
- All five SwiftData model types (`CycleProfile`, `PeriodLog`, `DailyLog`, `SymptomLog`, `PredictionSnapshot`) are `@Model` annotated and can be inserted into an in-memory `ModelContainer` without a Supabase connection.
- `syncStatus` is an enum (`pending`, `synced`, `error`) on each SwiftData model -- its state transitions are driven by `SyncCoordinator`, which is faked via `FakeSyncCoordinator` in tests.
- The `@Observable` ViewModels that own `SyncCoordinator` were implemented with protocol-typed dependencies (cadence-testing skill §2 requirement). If any were not, this epic's DI infrastructure story (S1) documents the gap and a fix must be added before S5 can pass.

## Risks

| Risk                                                                                                     | Likelihood | Impact | Mitigation                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@Observable` ViewModel(s) hold a concrete `SupabaseClient` stored property, blocking unit tests         | Medium     | Medium | S1 audits all ViewModels for DI compliance. Non-compliant ViewModels are refactored as part of S1 before test authoring begins.                                                                     |
| `PredictionEngine` coverage falls below 90% due to uncovered guard branches                              | Low        | High   | Write tests for all 10 specified edge cases; add targeted tests for any guard branch not covered by those cases. Use `xcrun xccov` to identify uncovered lines before declaring S2 done.            |
| `isPrivate` precedence rule tests reveal an implementation bug in the privacy filter                     | Medium     | High   | This is the intended function of the test suite. If a bug is found, fix the implementation (PH-8 scope) before marking the test as passing. Do not write the test to match a broken implementation. |
| Calendar arithmetic in `PredictionEngine` tests produces different results in different time zones on CI | Medium     | Medium | Use a fixed anchor date (`Date(timeIntervalSinceReferenceDate: 0)`) and `Calendar(identifier: .gregorian)` with explicit UTC timezone in all date fixtures per cadence-testing skill §3.            |

---

## Stories

### S1: Dependency Injection Infrastructure

**Story ID:** PH-14-E2-S1
**Points:** 3

Author `SyncCoordinatorProtocol`, `FakeSyncCoordinator`, and the shared `makeTestContainer()` factory function. Audit all `@Observable` ViewModels for DI compliance per cadence-testing skill §2. Document any non-compliant ViewModel as a blocker and fix it before proceeding to test authoring.

**Acceptance Criteria:**

- [ ] `SyncCoordinatorProtocol` is defined as a Swift protocol (marked `actor`) with at minimum `func enqueue(_ write: PendingWrite) async` and `var isOnline: Bool { get }`
- [ ] `FakeSyncCoordinator.swift` is in `CadenceTests/Fakes/` and contains no import of any Supabase SDK type (`import Supabase`, `import PostgREST`, etc. are all prohibited)
- [ ] `FakeSyncCoordinator` conforms to `SyncCoordinatorProtocol`; its `enqueuedWrites` property accumulates all enqueued writes for assertion in tests
- [ ] `makeTestContainer() throws -> ModelContainer` produces an in-memory container holding all five Cadence models; `ModelConfiguration(isStoredInMemoryOnly: true)` is used
- [ ] Every `@Observable` ViewModel that holds a `SyncCoordinator` dependency accepts it as a `any SyncCoordinatorProtocol` at its initializer -- no ViewModel stores a concrete `SyncCoordinator` or `SupabaseClient`
- [ ] All new files are registered in `project.yml` under the `CadenceTests` target
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** None
**Notes:** If a ViewModel is found to hold a concrete `SupabaseClient`, extract a `SupabaseClientProtocol` the same way and create a `FakeSupabaseClient`. The pattern is: protocol-typed at init, fake in tests, concrete in production app injection site. Do not leave a ViewModel untestable to avoid the refactor.

---

### S2: PredictionEngine Unit Tests

**Story ID:** PH-14-E2-S2
**Points:** 5

Author `PredictionEngineTests.swift` covering all 10 required edge cases per cadence-testing skill §3. Every test must use a fixed anchor date, not `Date()`. Every test must assert both `confidenceLevel` and `cyclesUsed`. The SD = 2.0 boundary case is a required test, not optional.

**Acceptance Criteria:**

- [ ] `PredictionEngineTests.swift` exists in `CadenceTests/Domain/` and is registered in `project.yml`
- [ ] All 10 required test cases are present with distinct names following the pattern `test_predictionEngine_<scenario>_<expectedOutcome>()`:
  - `zeroCycles_defaultsApplied_confidenceLow`
  - `oneCompletedCycle_singleLengthAverage_confidenceLow`
  - `twoCompletedCycles_averageOfTwo_confidenceMedium`
  - `threeCompletedCycles_averageOfThree_confidenceMedium`
  - `fourCyclesSDUnder2Days_confidenceHigh`
  - `fourCyclesSDOver2Days_confidenceMedium`
  - `sdExactly2Days_confidenceHigh` (SD = 2.0 is inclusive for `.high`)
  - `openPeriodExcluded_notCountedAsCompletedCycle`
  - `moreThanSixCycles_usesOnlyMostRecentSix`
  - `algorithmSpotCheck_jan1Anchor_correctDatesProduced`
- [ ] All tests use `Date(timeIntervalSinceReferenceDate: 0)` as the anchor date and `Calendar(identifier: .gregorian)` with UTC timezone for date arithmetic
- [ ] The algorithm spot-check asserts: last start Jan 1 (anchor), avg cycle 28 -- `nextPeriod = Jan 29`, `ovulation = Jan 15`, `fertileStart = Jan 10`, `fertileEnd = Jan 15` (exact dates)
- [ ] All 10 tests pass with `xcodebuild test -scheme CadenceTests`
- [ ] `xcrun xccov` confirms `PredictionEngine.swift` line coverage >= 90% after running this test file
- [ ] `scripts/protocol-zero.sh` exits 0 on `PredictionEngineTests.swift`

**Dependencies:** PH-14-E2-S1
**Notes:** `PredictionEngine` takes `[PeriodLog]` directly -- no `ModelContext` or fake coordinator needed. Date calculation for the algorithm spot-check: `Date(timeIntervalSinceReferenceDate: 0)` is 2001-01-01 UTC. `nextPeriod` = 2001-01-29, `ovulation` = 2001-01-15, `fertileStart` = 2001-01-10, `fertileEnd` = 2001-01-15. Verify these match the implementation's `Calendar.current.date(byAdding:)` output for the same anchor.

---

### S3: SwiftData Model Layer Unit Tests

**Story ID:** PH-14-E2-S3
**Points:** 5

Author `SwiftDataModelTests.swift` covering `syncStatus` lifecycle, open period enforcement, `DailyLog` uniqueness, prediction recalculation trigger, and `SymptomLog` association per cadence-testing skill §4. Each test uses a fresh in-memory `ModelContainer` from `makeTestContainer()`.

**Acceptance Criteria:**

- [ ] `SwiftDataModelTests.swift` exists in `CadenceTests/Models/` and is registered in `project.yml`
- [ ] A fresh `ModelContainer` from `makeTestContainer()` is created in `setUp()` or as a local variable per test -- no shared container across test cases
- [ ] `syncStatus` lifecycle: test that inserting any model sets `syncStatus == .pending`; simulating flush success sets `syncStatus == .synced`; simulating 3 exhausted retries sets `syncStatus == .error`
- [ ] Open period enforcement: inserting a `PeriodLog` with `endDate == nil` stores successfully; inserting a second `PeriodLog` with `endDate == nil` triggers the write-time rejection check (implementation-defined -- either throws or returns nil; assert the constraint is enforced)
- [ ] `DailyLog` uniqueness: two `DailyLog` inserts with identical `(userId, date)` produce a constraint error or the second insert is rejected by the write path
- [ ] Prediction recalculation trigger: after writing a `PeriodLog` via the production write path, a `PredictionSnapshot` exists in the `ModelContext`
- [ ] `SymptomLog` association: a `SymptomLog` inserted with a valid `DailyLog.id` reference is retrievable via the `DailyLog` relationship
- [ ] All tests pass with `xcodebuild test -scheme CadenceTests`
- [ ] `scripts/protocol-zero.sh` exits 0 on `SwiftDataModelTests.swift`

**Dependencies:** PH-14-E2-S1
**Notes:** If the write path that rejects a second open `PeriodLog` is a method on the ViewModel (not enforced by SwiftData directly), inject `FakeSyncCoordinator` and call the ViewModel method. Assert the rejection at the ViewModel boundary, not at the raw `ModelContext.insert` level.

---

### S4: Privacy Filter Unit Tests

**Story ID:** PH-14-E2-S4
**Points:** 5

Author `PrivacyFilterTests.swift` covering the `isPrivate` master override, Sex symptom exclusion, and each of the four precedence rules in isolation per cadence-testing skill §5. Missing or incomplete tests in this area are a release blocker per the skill.

**Acceptance Criteria:**

- [ ] `PrivacyFilterTests.swift` exists in `CadenceTests/Domain/` and is registered in `project.yml`
- [ ] `isPrivate == true` test: a `DailyLog` with `isPrivate: true` passed to `partnerVisibleLogs(from:)` produces an empty result -- zero entries visible
- [ ] `isPrivate == false` test: a `DailyLog` with `isPrivate: false` produces exactly one visible entry
- [ ] Mixed batch test: `[DailyLog(isPrivate: true), DailyLog(isPrivate: false)]` produces exactly 1 visible entry; the visible entry has `isPrivate == false`
- [ ] Sex symptom exclusion: `[.sex, .cramps, .headache]` passed to `partnerVisibleSymptoms(from:)` returns 2 entries; `.sex` is absent from the result
- [ ] Sex excluded even when `share_symptoms == true`: constructing a connection with `shareSymptoms: true` and a `SymptomLog(.sex)` produces a partner payload with zero `.sex` entries
- [ ] Each of the four precedence rules is tested in isolation (one rule fires, all others pass):
  - Rule 1 (`isPrivate == true`): all `share_*` flags true, entry private -- zero partner data
  - Rule 2 (`is_paused == true`): connection paused, `isPrivate: false` -- zero partner data
  - Rule 3 (Sex symptom): `share_symptoms: true`, not private -- `.sex` absent from result
  - Rule 4 (`share_<category> == false`): that category's data absent from payload
- [ ] All tests pass with `xcodebuild test -scheme CadenceTests`
- [ ] `xcrun xccov` confirms privacy filter logic files >= 90% line coverage after this test file runs
- [ ] `scripts/protocol-zero.sh` exits 0 on `PrivacyFilterTests.swift`

**Dependencies:** PH-14-E2-S1
**Notes:** Each precedence rule test must be a distinct `func test_*` method -- not combined into a single parameterized test. The isolation requirement from cadence-testing skill §5 means each rule's behavior must be independently verifiable. If the privacy filter is implemented as a method on a ViewModel, inject `FakeSyncCoordinator` and call the method in isolation.

---

### S5: Coverage Gate Enforcement

**Story ID:** PH-14-E2-S5
**Points:** 3

Integrate `xcov` into the Fastlane `test` lane and verify per-file coverage thresholds pass. Confirm that the gate is enforced in CI (the `unit-tests` job fails if coverage falls below threshold) and produce an `xcov` HTML report in `fastlane/test_output/coverage/`.

**Acceptance Criteria:**

- [ ] `fastlane/Fastfile` `test` lane calls `xcov(scheme: "CadenceTests", minimum_coverage_percentage: 80.0, include_targets: "Cadence.app", output_directory: "fastlane/test_output/coverage")` after `run_tests`
- [ ] `bundle exec fastlane test` exits 0 locally: `run_tests` passes, `xcov` passes at the 80% aggregate gate
- [ ] `xcrun xccov view --report --json` output confirms per-file thresholds: `PredictionEngine.swift` >= 90%, privacy filter files >= 90%, all five SwiftData model files >= 80%, all `@Observable` ViewModel files >= 75%
- [ ] Coverage gate failure is confirmed: removing a required test from S2 causes `bundle exec fastlane test` to exit non-zero at the `xcov` step (verify locally before restoring the test)
- [ ] `fastlane/test_output/coverage/` is listed in `.gitignore` -- coverage reports are not committed
- [ ] In CI, the `unit-tests` job fails if `xcov` exits non-zero (confirmed by checking the job step definition uses `bundle exec fastlane test`)

**Dependencies:** PH-14-E2-S2, PH-14-E2-S3, PH-14-E2-S4, PH-14-E1-S3
**Notes:** `xcov` version `~> 1.9.0` is available via the fastlane-community gem. Add it to the `Gemfile`. The `only_project_targets: true` flag restricts coverage to the main `Cadence.app` target, excluding the test bundle itself from the report. Excluded from the 80% gate per cadence-testing skill §10: SwiftUI `body` properties (excluded automatically by `xcov`'s default filter), `CadenceApp.swift` entry point, generated Xcode files.

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
- [ ] All 10 `PredictionEngine` edge cases pass
- [ ] All privacy filter tests pass; each of the four precedence rules is tested in isolation
- [ ] `xcov` confirms: `PredictionEngine.swift` >= 90%, privacy filter >= 90%, SwiftData models >= 80%, ViewModels >= 75%
- [ ] No test uses `Date()` -- all date fixtures use a fixed anchor
- [ ] No test holds a shared `ModelContainer` -- fresh container per test
- [ ] `FakeSyncCoordinator` imports no Supabase SDK type
- [ ] Phase objective is advanced: unit test coverage gate is satisfied; TestFlight build is unblocked from the unit test dimension
- [ ] Applicable skill constraints satisfied: cadence-testing §§2-5, §9, §10 (full unit test contract, no live Supabase, coverage gate)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments
- [ ] All test files registered in `project.yml` under `CadenceTests` target

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: unit test coverage gate -- 80%+ on data + domain layers)
- cadence-testing skill §2 (DI architecture for @Observable stores)
- cadence-testing skill §3 (PredictionEngine unit test contract -- 10 required edge cases)
- cadence-testing skill §4 (SwiftData model layer unit tests)
- cadence-testing skill §5 (privacy override logic unit tests -- release blocker)
- cadence-testing skill §9 (no live Supabase in tests)
- cadence-testing skill §10 (coverage gate -- 80%+ before TestFlight, per-file thresholds)
- cadence-data-layer skill (rolling-average algorithm, confidence scoring thresholds: 4+ cycles SD <= 2.0 = high; 2-3 cycles or 4+ SD > 2.0 = medium; 0-1 = low)
- cadence-privacy-architecture skill (isPrivate master override, Sex exclusion, four-rule precedence hierarchy)
