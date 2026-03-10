# ReportsViewModel & Metrics Query Layer

**Epic ID:** PH-11-E1
**Phase:** 11 -- Reports
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `ReportsViewModel` as the single `@Observable` data source for the Reports tab, along with all SwiftData query methods and metric computation functions that derive the five report cards from local `PeriodLog`, `DailyLog`, `SymptomLog`, and `PredictionSnapshot` records. This epic produces no UI. Its outputs are value types and a ViewModel that PH-11-E2 components bind to.

## Problem / Context

The Reports tab requires five distinct metrics, each computed from a different subset of the SwiftData schema established in Phase 3. Before any chart or card component can be built (PH-11-E2), the data layer must define: what a "completed cycle" is, which records satisfy the 2-cycle minimum gate, how averages are computed, how cycle consistency is classified, and how symptoms are bucketed by cycle phase.

Without this epic, PH-11-E2 and PH-11-E3 have no well-typed data contract. The computation logic also carries the highest unit test burden in the phase -- separating it from UI allows tests to run without a live SwiftUI environment.

Sources: MVP Spec §10 (all 5 report card types, 2-cycle requirement); cadence-data-layer skill (SwiftData schema, `PeriodLog.endDate` nil semantics, prediction engine confidence tiers); Design Spec v1.1 §13 (empty state gate condition); PHASES.md Phase 11 in-scope list.

## Scope

### In Scope

- `ReportMetrics` value type (struct) encapsulating all five metric outputs
- `CompletedCycleSummary` value type: `startDate: Date`, `endDate: Date`, `cycleLength: Int`, `periodLength: Int` -- one instance per completed `PeriodLog` pair
- `CyclePhase` enum: `menstrual`, `follicular`, `ovulatory`, `luteal` -- used for symptom frequency bucketing
- `CycleConsistency` enum: `regular`, `irregular` -- derived from SD of cycle lengths across the query window
- `SymptomPhaseCount` value type: `symptomType: SymptomType`, `phase: CyclePhase`, `count: Int` -- one instance per (symptom, phase) pair
- `ReportsViewModel` as an `@Observable` class with a `ModelContext` dependency, exposing: `isGated: Bool`, `isLoading: Bool`, `metrics: ReportMetrics?`, and `refresh() async`
- `completedPeriods(context:)` -- SwiftData `#Predicate` query: `PeriodLog` where `endDate != nil`, sorted by `startDate` descending
- Average cycle length computation: mean of start-to-start intervals of the N most recent completed periods, using the same 3-6 window as the prediction engine
- Average period length computation: mean of `endDate - startDate` across the same window
- Recent cycles sequence: last 6 `CompletedCycleSummary` records (or all available if fewer than 6), ordered oldest-first for chart rendering
- Cycle consistency classification: SD of cycle lengths in the query window; SD <= 2.0 days = `.regular`, SD > 2.0 days = `.irregular`; if fewer than 2 data points, consistency = `.irregular`
- Symptom frequency by cycle phase: join `SymptomLog` -> `DailyLog.date` -> classify date against `PeriodLog` + `PredictionSnapshot` records to assign `CyclePhase`; aggregate into `[SymptomPhaseCount]`; `SymptomType.sex` is included (Tracker-only view; sex exclusion applies to Partner-facing queries only)
- `ReportsViewModelProtocol` for test injection

### Out of Scope

- SwiftUI views, chart components, or any rendering logic (PH-11-E2)
- Screen assembly and gate rendering branch (PH-11-E3)
- Modifications to the SwiftData schema (established in PH-3; this epic is read-only against that schema)
- Writing any new `PredictionSnapshot` records (PredictionEngine recalculation is triggered on `PeriodLog` writes, handled in PH-3-E2)
- HealthKit data (out of scope for beta per MVP Spec)

## Dependencies

| Dependency                                                                                              | Type | Phase/Epic | Status   | Risk |
| ------------------------------------------------------------------------------------------------------- | ---- | ---------- | -------- | ---- |
| SwiftData schema deployed: `PeriodLog`, `DailyLog`, `SymptomLog`, `PredictionSnapshot`, `CycleProfile`  | FS   | PH-3-E1    | Resolved | Low  |
| `PredictionSnapshot` records written after every `PeriodLog` write (required for cycle phase date math) | FS   | PH-3-E2    | Resolved | Low  |
| `SymptomType` enum with all 10 cases including `.sex`                                                   | FS   | PH-3-E1    | Resolved | Low  |
| Phase 4 nav shell exists (Reports tab registered, `ReportsViewModel` injected via environment)          | FS   | PH-4       | Resolved | Low  |

## Assumptions

- A "completed cycle" is a `PeriodLog` where `endDate != nil`. Open periods (`endDate == nil`) are excluded from all metric computations.
- The query window for averages uses 3-6 completed cycles, identical to the `PredictionEngine` window defined in the cadence-data-layer skill. This ensures Reports and the prediction engine never diverge on what constitutes the baseline.
- Cycle phase assignment uses the most recent `PredictionSnapshot` to locate `predictedOvulation`. If no snapshot exists for a given historical date range, that date is assigned `.follicular` by default as a conservative fallback.
- The SD threshold for `regular` vs. `irregular` is exactly 2.0 days, the same boundary used by the `PredictionEngine` confidence scoring, as specified in the cadence-data-layer skill.
- `ReportsViewModel.refresh()` is called on `.task` in `ReportsView` and on each app foreground event. It does not observe SwiftData reactive publishers directly -- it pulls on demand.
- The `sex` symptom is included in symptom frequency because Reports is a Tracker-only surface. The exclusion in the cadence-privacy-architecture skill applies only to Partner-visible query projections.
- Cycle phase boundary dates for symptom bucketing: menstrual = period startDate through endDate; ovulatory = predictedOvulation minus 1 day through predictedOvulation plus 1 day; luteal = ovulation+2 days through next predicted period start minus 1 day; follicular = all remaining days between period end and ovulation window start.

## Risks

| Risk                                                                                                   | Likelihood | Impact | Mitigation                                                                                                                  |
| ------------------------------------------------------------------------------------------------------ | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| No `PredictionSnapshot` exists for historical cycle dates, breaking cycle phase assignment             | Medium     | Medium | Default to `.follicular` when no snapshot covers a date; document fallback in `CyclePhase` assignment function.             |
| SD computation produces NaN when cyclesUsed == 1                                                       | Low        | High   | Guard: if fewer than 2 data points, return `.irregular` immediately without calling SD formula. Unit test this path.        |
| `PeriodLog` records have overlapping date ranges due to user edit, producing nonsensical cycle lengths | Low        | Medium | Filter out any computed `cycleLength <= 0` before using in averages; skip the outlier, log to structured logger.            |
| Phase 3 SwiftData schema differs from cadence-data-layer skill definition (e.g., field renames)        | Low        | High   | Read the actual Swift files from PH-3 before writing any `#Predicate` query. Do not infer field names from the skill alone. |

---

## Stories

### S1: `ReportMetrics`, `CompletedCycleSummary`, `CyclePhase`, and `ReportsViewModel` Scaffold

**Story ID:** PH-11-E1-S1
**Points:** 3

Define all value types and the `ReportsViewModel` class shell. No computation logic is written in this story -- only type definitions and the `ReportsViewModelProtocol`. This story gates all PH-11-E2 component development because components take `ReportMetrics` as their input parameter.

`ReportMetrics` struct fields:

- `averageCycleLengthDays: Int`
- `averagePeriodLengthDays: Int`
- `cyclesUsed: Int`
- `recentCycles: [CompletedCycleSummary]`
- `consistency: CycleConsistency`
- `consistencyStandardDeviationDays: Double`
- `symptomFrequency: [SymptomPhaseCount]`

**Acceptance Criteria:**

- [ ] `ReportMetrics`, `CompletedCycleSummary`, `CyclePhase`, `CycleConsistency`, and `SymptomPhaseCount` are defined as `struct` value types in separate files under a `Reports/` group in `project.yml`
- [ ] `CyclePhase` has exactly four cases: `menstrual`, `follicular`, `ovulatory`, `luteal`; each case has a `displayName: String` computed property returning a title-cased string
- [ ] `CycleConsistency` has exactly two cases: `regular`, `irregular`
- [ ] `ReportsViewModel` is an `@Observable` class with `var isGated: Bool`, `var isLoading: Bool`, `var metrics: ReportMetrics?`, and `func refresh() async`
- [ ] `ReportsViewModelProtocol` is a protocol with the same surface (`isGated`, `isLoading`, `metrics`, `refresh`)
- [ ] `ReportsViewModel` conforms to `ReportsViewModelProtocol`
- [ ] A `MockReportsViewModel` conforming to `ReportsViewModelProtocol` is created with settable properties for use in unit tests and SwiftUI Previews
- [ ] All new Swift files are added to `project.yml` before `xcodegen generate` is run; build compiles

**Dependencies:** None
**Notes:** File locations: `Cadence/Reports/ReportMetrics.swift`, `Cadence/Reports/CyclePhase.swift`, `Cadence/Reports/CycleConsistency.swift`, `Cadence/Reports/SymptomPhaseCount.swift`, `Cadence/Reports/CompletedCycleSummary.swift`, `Cadence/Reports/ReportsViewModel.swift`. The `MockReportsViewModel` lives at `CadenceTests/Mocks/MockReportsViewModel.swift`.

---

### S2: Completed PeriodLog Query and 2-Cycle Gate Predicate

**Story ID:** PH-11-E1-S2
**Points:** 3

Implement `ReportsViewModel.fetchCompletedPeriods(context:) -> [PeriodLog]` using a SwiftData `#Predicate` that filters `PeriodLog` records where `endDate != nil`, sorted by `startDate` descending. Populate `isGated` based on whether the result count is `< 2`. All downstream metric computations in S3-S6 call this method as their data source.

**Acceptance Criteria:**

- [ ] `fetchCompletedPeriods(context:)` issues a SwiftData `FetchDescriptor<PeriodLog>` with a `#Predicate` that excludes records where `endDate == nil`
- [ ] Results are sorted by `startDate` descending (most recent period first)
- [ ] `ReportsViewModel.isGated` is set to `true` when `fetchCompletedPeriods` returns fewer than 2 records
- [ ] `ReportsViewModel.isGated` is set to `false` when `fetchCompletedPeriods` returns 2 or more records
- [ ] Unit test: model context seeded with 1 completed `PeriodLog` -- `isGated` == `true`
- [ ] Unit test: model context seeded with 2 completed `PeriodLog` records -- `isGated` == `false`
- [ ] Unit test: model context seeded with 0 records -- `isGated` == `true`
- [ ] Open `PeriodLog` records (endDate == nil) are excluded from the result in all test cases above

**Dependencies:** PH-11-E1-S1
**Notes:** The `#Predicate` must use the exact property name as declared in the `PeriodLog` `@Model` class from PH-3. Read the PH-3 Swift source before writing the predicate to avoid field-name mismatch that would fail silently at runtime.

---

### S3: Average Cycle Length and Average Period Length Computation

**Story ID:** PH-11-E1-S3
**Points:** 3

Implement metric computations for `averageCycleLengthDays` and `averagePeriodLengthDays` within `ReportsViewModel`. Both use the 3-6 cycle rolling window defined in the cadence-data-layer skill. Populate `cyclesUsed` with the actual window size used.

**Acceptance Criteria:**

- [ ] `computeAverageCycleLength(from periods: [PeriodLog]) -> (avgDays: Int, cyclesUsed: Int)` computes start-to-start intervals between consecutive `PeriodLog.startDate` values; takes the N most recent where N = min(max(periods.count - 1, 0), 6) with a floor of 3 if 3+ intervals are available
- [ ] `computeAveragePeriodLength(from periods: [PeriodLog]) -> Int` computes the mean of `endDate - startDate` in calendar days across the same N records; returns 5 (default) if fewer than 2 completed periods
- [ ] Both functions are pure (no SwiftData access; take the already-fetched `[PeriodLog]` array)
- [ ] Unit test: 6 completed periods with cycle lengths [28, 30, 27, 29, 28, 31] -- `averageCycleLengthDays` == 29 (mean of last 6 start-to-start intervals), `cyclesUsed` == 6
- [ ] Unit test: 2 completed periods -- `cyclesUsed` == 1 (only one start-to-start interval available), `averageCycleLengthDays` == that single interval
- [ ] Unit test: 0 completed periods -- `averageCycleLengthDays` defaults to 28, `averagePeriodLengthDays` defaults to 5
- [ ] No floating point stored in the output -- both averages are truncated to `Int` via integer division (consistent with the prediction engine)

**Dependencies:** PH-11-E1-S2
**Notes:** Cycle length = interval in calendar days between `periods[i].startDate` and `periods[i+1].startDate` (working backwards through the descending-sorted array). Period length = `endDate - startDate` of the same `PeriodLog` in calendar days. Use `Calendar.current.dateComponents([.day], from:to:).day!` for day-count arithmetic -- do not use raw `TimeInterval` division.

---

### S4: Recent Cycles Sequence Extraction

**Story ID:** PH-11-E1-S4
**Points:** 3

Build `computeRecentCycles(from periods: [PeriodLog]) -> [CompletedCycleSummary]` to produce the data series for the Recent Cycles chart in PH-11-E2-S2. Return the last 6 completed cycles (or all available if fewer), ordered oldest-first so the chart renders left-to-right chronologically.

**Acceptance Criteria:**

- [ ] Returns up to 6 `CompletedCycleSummary` records
- [ ] Records are ordered oldest-first (`startDate` ascending) to support chart x-axis ordering
- [ ] Each `CompletedCycleSummary.cycleLength` equals the start-to-start interval to the following period (in calendar days); the most recent period has no successor, so its `cycleLength` is set to `0` to indicate that the cycle is not yet closed for the purposes of the overview chart -- this record is excluded from the sequence
- [ ] Each `CompletedCycleSummary.periodLength` equals `endDate - startDate` in calendar days for that `PeriodLog`
- [ ] Unit test: 8 completed periods input -- returns exactly 6 `CompletedCycleSummary` records
- [ ] Unit test: 3 completed periods input -- returns 2 `CompletedCycleSummary` records (the 3rd cannot form a start-to-start interval and is excluded)
- [ ] Unit test: 1 completed period -- returns 0 records (the gate in S2 prevents this path from being reached in production, but the function must not crash)

**Dependencies:** PH-11-E1-S2, PH-11-E1-S3
**Notes:** The exclusion of the most-recent period from the cycle length chart is intentional: the start-to-start interval for the last period requires knowing the next period's start date, which is predicted, not logged. Using the prediction for this chart would conflate logged history with estimates. The chart in PH-11-E2-S2 must label the x-axis with `startDate` abbreviated as "Jan 5", not cycle index numbers.

---

### S5: Cycle Consistency Classification

**Story ID:** PH-11-E1-S5
**Points:** 3

Implement `computeConsistency(cycleLengths: [Int]) -> (consistency: CycleConsistency, standardDeviationDays: Double)`. Apply the exact SD threshold from the cadence-data-layer skill: SD <= 2.0 = `.regular`, SD > 2.0 = `.irregular`. Fewer than 2 data points returns `.irregular` with SD = 0.0.

**Acceptance Criteria:**

- [ ] SD is computed as the population standard deviation of `cycleLengths` (not sample SD) -- consistent with the prediction engine confidence scoring implementation
- [ ] Returns `.regular` when SD <= 2.0 days
- [ ] Returns `.irregular` when SD > 2.0 days
- [ ] Returns `.irregular` with `standardDeviationDays == 0.0` when `cycleLengths.count < 2`
- [ ] Unit test: `[28, 28, 29, 28]` -- SD == 0.43, result == `.regular`
- [ ] Unit test: `[28, 35, 21, 30]` -- SD > 2.0, result == `.irregular`
- [ ] Unit test: `[28]` -- result == `.irregular`, `standardDeviationDays == 0.0`
- [ ] Unit test: `[]` -- result == `.irregular`, `standardDeviationDays == 0.0`
- [ ] `ReportMetrics.consistencyStandardDeviationDays` is populated with the raw SD value (rounded to 1 decimal place) for display in the consistency card

**Dependencies:** PH-11-E1-S4
**Notes:** Population SD formula: `sqrt(sum((x - mean)^2) / n)`. Do not use `n-1` (sample SD). The 2.0-day threshold is a product-spec value (cadence-data-layer skill §3). Do not adjust it.

---

### S6: Symptom Frequency by Cycle Phase Computation

**Story ID:** PH-11-E1-S6
**Points:** 5

Implement `computeSymptomFrequency(context: ModelContext, completedPeriods: [PeriodLog]) -> [SymptomPhaseCount]`. Join `SymptomLog` records to their parent `DailyLog.date`, then classify each date against the `CyclePhase` boundaries derived from the most recent available `PredictionSnapshot`. Aggregate into a flat `[SymptomPhaseCount]` array sorted by `phase` then `count` descending.

**Acceptance Criteria:**

- [ ] Fetches all `SymptomLog` records whose `dailyLogId` maps to a `DailyLog.date` falling within the date range covered by the `completedPeriods` input (oldest `startDate` through most recent `endDate`)
- [ ] Fetches the `PredictionSnapshot` most recently generated before each date to determine `predictedOvulation` for cycle phase boundary computation
- [ ] Phase assignment rules (applied per `DailyLog.date`):
  - `menstrual`: `periodLog.startDate <= date <= periodLog.endDate` for any `PeriodLog` in the query window
  - `ovulatory`: `(predictedOvulation - 1 day) <= date <= (predictedOvulation + 1 day)` -- 3-day window centered on predicted ovulation
  - `luteal`: `(predictedOvulation + 2 days) <= date <= (nextPeriodStartDate - 1 day)`
  - `follicular`: all dates between `periodLog.endDate + 1 day` and `predictedOvulation - 2 days`
  - Fallback when no snapshot available: assign `.follicular`
- [ ] `SymptomType.sex` is included in the aggregation (Tracker-only view; no exclusion needed locally)
- [ ] Returns an empty array when `completedPeriods` is empty (gate in S2 prevents this in production)
- [ ] Output is a flat `[SymptomPhaseCount]` with one entry per `(symptomType, phase)` pair that has `count > 0`; zero-count pairs are omitted
- [ ] Unit test: 3 cramp symptoms assigned to menstrual dates, 1 headache to luteal -- output contains `(cramps, menstrual, 3)` and `(headache, luteal, 1)`, no zero entries
- [ ] Unit test: no symptoms logged -- returns `[]`
- [ ] Integration test: run against an in-memory SwiftData container seeded with 2 completed periods, 6 DailyLog + SymptomLog records; verify output matches hand-computed expected values

**Dependencies:** PH-11-E1-S1, PH-11-E1-S2
**Notes:** The join `SymptomLog.dailyLogId -> DailyLog.id` requires fetching both tables. Use two `FetchDescriptor` calls rather than a relationship traversal -- the in-memory cost is low for the beta-scale dataset. Do not reconstruct the cycle phase logic from scratch; reference `PredictionSnapshot.predictedOvulation` directly. The ovulatory window of +/-1 day is a simplification appropriate for this display context; it does not need to match the exact fertile window boundaries used in the calendar view.

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
- [ ] Integration with dependencies verified end-to-end: `ReportsViewModel.refresh()` produces a non-nil `ReportMetrics` when seeded with 2+ completed `PeriodLog` records in an in-memory SwiftData container
- [ ] Phase objective is advanced: `ReportsViewModel` is injectable and produces correct metrics for all five report cards from local SwiftData -- no UI required
- [ ] Applicable skill constraints satisfied: cadence-data-layer (SwiftData query patterns, `PeriodLog.endDate` nil semantics, 3-6 cycle window, SD threshold of 2.0 days), cadence-testing (`ReportsViewModelProtocol` injectable, `MockReportsViewModel` available, no live Supabase in tests), swiftui-production (@Observable pattern, no force unwraps)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Unit tests cover: 2-cycle gate threshold, SD classification edge cases (n<2, SD==2.0, SD>2.0), average computation with 1/2/6 cycles, symptom phase assignment including fallback
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §10, cadence-data-layer skill SD thresholds, or `PeriodLog` schema

## Source References

- PHASES.md: Phase 11 -- Reports (in-scope: reports data reads from SwiftData; all 5 report card types; 2-cycle minimum gate)
- MVP Spec §10: History and Reports (5 report card types, 2-cycle requirement)
- Design Spec v1.1 §13: States & Feedback (empty state gate condition for Reports < 2 cycles)
- cadence-data-layer skill §2 (SwiftData schema -- `PeriodLog`, `DailyLog`, `SymptomLog`, `PredictionSnapshot`, `SymptomType` enum)
- cadence-data-layer skill §3 (prediction algorithm -- confidence scoring SD threshold 2.0 days, 3-6 cycle window)
- cadence-testing skill (injectable @Observable pattern, MockReportsViewModel contract)
