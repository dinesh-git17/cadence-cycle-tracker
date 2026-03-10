# PredictionEngine

**Epic ID:** PH-3-E2
**Phase:** 3 -- Core Data Layer & Prediction Engine
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `PredictionEngine` as a pure Swift struct with no network dependencies. The engine accepts completed `PeriodLog` history as input, computes rolling averages of cycle and period lengths from the last 3-6 cycles, produces next-period, ovulation, and fertile window predictions using calendar-day arithmetic, and scores confidence based on the number of completed cycles and the standard deviation of cycle lengths. A new `PredictionSnapshot` is written to SwiftData after every `PeriodLog` write.

## Problem / Context

Phase 5 (Home Dashboard), Phase 6 (Calendar), and Phase 11 (Reports) all read prediction data. If the algorithm is incorrect, all three surfaces surface wrong dates. Implementing and testing the prediction engine in Phase 3 -- before any UI exists -- gives a tight feedback loop: a unit test failure means a bug in the algorithm, not a rendering artifact. Post-Phase-3, the algorithm is locked. UI phases read from `PredictionSnapshot` and do not re-derive predictions.

The offline-first contract also depends on this engine: the engine runs synchronously on the write path, produces a `PredictionSnapshot` immediately, and marks it `.pending` for Supabase sync. No prediction is ever deferred to a network round-trip.

Source authority: cadence-data-layer skill §3 (Prediction Algorithm) is the canonical reference for all formulas, thresholds, and constraints. MVP Spec §8 (Fertility and Cycle Predictions) confirms the same rules. Both agree. The spec formulas are locked -- do not modify without a spec change.

## Scope

### In Scope

- `PredictionEngine.swift` -- pure Swift struct with no Supabase or URLSession imports
- Rolling-average calculation from last 3-6 completed `PeriodLog` records (where `endDate != nil`)
- Cycle length computation: start-to-start interval between consecutive completed periods (days)
- Period length computation: `endDate - startDate` in calendar days
- Prediction formulas: `predictedNextPeriod = lastPeriodStartDate + averageCycleLength`, `predictedOvulation = predictedNextPeriod - 14`, `fertileWindowStart = predictedOvulation - 5`, `fertileWindowEnd = predictedOvulation`
- Standard deviation computation on cycle lengths (sample SD, divide by N-1)
- Confidence scoring: `0-1 cycles → .low`, `2-3 cycles → .medium`, `4+ cycles AND SD <= 2.0 → .high`, `4+ cycles AND SD > 2.0 → .medium`
- Zero-history fallback: when no completed periods exist, use defaults (cycle length 28, period length 5) from the CycleProfile record; confidence is `.low`; `cyclesUsed = 0`
- `PredictionSnapshot` construction from computed values
- Recalculation trigger: the write path function (a free function or method on a coordinator) that (1) writes a `PeriodLog` to the `ModelContext`, (2) calls `PredictionEngine.recalculate(periods:cycleProfile:)`, (3) inserts the resulting `PredictionSnapshot` into the `ModelContext`, and (4) enqueues both writes via `SyncCoordinator`
- `CycleProfile.averageCycleLength` and `averagePeriodLength` updated to reflect the newly computed averages on each recalculation
- All date arithmetic uses `Calendar.current.dateComponents([.day], from:to:).day!` -- never raw `TimeInterval` division

### Out of Scope

- UI display of prediction results (Phase 5 and Phase 6)
- The disclaimer label "Based on your logged history -- not medical advice." on prediction surfaces (Phase 5 display, but the product requirement is noted here for Phase 5 implementation)
- Supabase writes for PredictionSnapshot or PeriodLog (Phase 7 -- SyncCoordinator full implementation)
- Recalculation after DailyLog writes (DailyLog does not affect cycle predictions -- only PeriodLog history does)
- Multi-cycle history updates after period edits (edit path lives in Phase 4/6; the engine recalculates on every PeriodLog write regardless of edit or new-entry)

## Dependencies

| Dependency                                                          | Type | Phase/Epic | Status | Risk |
| ------------------------------------------------------------------- | ---- | ---------- | ------ | ---- |
| PeriodLog, PredictionSnapshot, CycleProfile @Model types            | FS   | PH-3-E1    | Open   | Low  |
| SyncCoordinator protocol (for the recalculation trigger write path) | SS   | PH-3-E4    | Open   | Low  |

## Assumptions

- All date arithmetic is calendar-day arithmetic using `Calendar.current`. No raw `TimeInterval` (86400-second day) arithmetic is used. `Calendar.current` handles DST transitions and leap years correctly.
- The "last period start date" used for prediction is `completedPeriods.sorted(by: startDate).last?.startDate` -- the most recent period's start date.
- "Completed periods" = PeriodLog records where `endDate != nil`. Open periods (nil `endDate`) are excluded from all calculations.
- With 0 completed periods: `lastPeriodStartDate` falls back to the `CycleProfile.createdAt` date (the date the user entered during onboarding); average lengths fall back to `CycleProfile.averageCycleLength` (28) and `averagePeriodLength` (5). Confidence = `.low`.
- With 1 completed period: `averagePeriodLength` = that period's duration in days. `averageCycleLength` is not computable from history (need 2 periods for a start-to-start interval) -- use the stored `CycleProfile.averageCycleLength` (default 28 from onboarding). Confidence = `.low`.
- `cyclesUsed` in `PredictionSnapshot` = the count of completed periods used in the average (max 6, min 0).
- Standard deviation uses the sample formula (divide by N-1). With fewer than 2 cycle lengths, SD is undefined -- treat as > 2.0 (conservative, yields `.low` or `.medium` confidence, never `.high`).
- The recalculation trigger is implemented as a standalone function in `Cadence/Services/PeriodLogService.swift` (or equivalent) rather than directly on the `PredictionEngine` struct. The engine is a pure calculation type; the coordinator owns the write orchestration.

## Risks

| Risk                                                                                                                                              | Likelihood | Impact | Mitigation                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Calendar-day arithmetic producing off-by-one errors near midnight or DST transitions                                                              | Medium     | Medium | All unit test date fixtures use `Calendar.current.startOfDay(for:)` to normalize; tests run across multiple time zones in CI |
| `cyclesUsed` count mismatched between PredictionSnapshot and the PeriodLogs actually used in the average (e.g., filtering vs. slicing off-by-one) | Low        | Medium | Unit test the exact `cyclesUsed` value on all 10 edge cases, not just the confidence level                                   |
| Standard deviation of exactly 2.0 evaluating as 2.0000001 due to floating-point arithmetic                                                        | Low        | Low    | Confidence threshold uses `sd <= 2.0` with a tolerance or exact Double equality -- see S4 AC for exact comparison policy     |

---

## Stories

### S1: PredictionEngine struct definition and input validation

**Story ID:** PH-3-E2-S1
**Points:** 2

Define the `PredictionEngine` struct with its public interface. No implementation beyond the function signatures and type definitions in this story -- the engine is buildable and satisfies the "no network imports" rule.

**Acceptance Criteria:**

- [ ] `Cadence/Services/PredictionEngine.swift` exists with `struct PredictionEngine`
- [ ] No `import` statement references `Supabase`, `URLSession`, `Network`, or any third-party networking SDK
- [ ] Public function signature: `func recalculate(completedPeriods: [PeriodLog], cycleProfile: CycleProfile) -> PredictionSnapshot`
- [ ] Function is synchronous (`func`, not `async func`) -- prediction is never deferred to a background queue
- [ ] File compiles without errors or warnings
- [ ] `project.yml` updated with `Cadence/Services/PredictionEngine.swift` under a `Cadence/Services/` source group

**Dependencies:** PH-3-E1 (PeriodLog, PredictionSnapshot, CycleProfile types)
**Notes:** The function signature accepts `[PeriodLog]` (not `ModelContext`) for testability. Callers fetch completed periods from SwiftData before calling this function. The `CycleProfile` parameter provides fallback values (average lengths) when period history is insufficient.

---

### S2: Rolling-average computation

**Story ID:** PH-3-E2-S2
**Points:** 5

Implement the rolling-average calculation that produces `averageCycleLength` and `averagePeriodLength` from the last 3-6 completed periods. This is the core data-reduction step before the prediction formula is applied.

**Acceptance Criteria:**

- [ ] `completedPeriods` is sorted by `startDate` descending before any computation; the function does not require a pre-sorted input
- [ ] Only periods where `endDate != nil` are used; open periods (nil `endDate`) are filtered before any slice
- [ ] The most recent 6 completed periods are used (slice: `prefix(6)` from the descending-sorted array); if fewer than 6 exist, all available completed periods are used
- [ ] **Average cycle length:** computed as the mean start-to-start interval between consecutive periods in the slice. Requires at least 2 completed periods to compute a cycle interval. With 0 or 1 completed periods, falls back to `cycleProfile.averageCycleLength`.
- [ ] **Average period length:** computed as the mean of `Calendar.current.dateComponents([.day], from: period.startDate, to: period.endDate!).day!` for each completed period in the slice. With 0 completed periods, falls back to `cycleProfile.averagePeriodLength`.
- [ ] `cyclesUsed` = the count of completed periods included in the average (0 to 6)
- [ ] With exactly 0 completed periods: `averageCycleLength = cycleProfile.averageCycleLength` (28 if default), `averagePeriodLength = cycleProfile.averagePeriodLength` (5 if default), `cyclesUsed = 0`
- [ ] With exactly 1 completed period: `averagePeriodLength` = that period's duration; `averageCycleLength` = `cycleProfile.averageCycleLength`; `cyclesUsed = 1`
- [ ] All day-count arithmetic uses `Calendar.current.dateComponents([.day], from:to:).day!` -- no raw `TimeInterval` division

**Dependencies:** PH-3-E2-S1
**Notes:** The descending sort + `prefix(6)` approach means the oldest period in the slice is `completedPeriods.sorted(...).prefix(6).last` and the most recent is `prefix(6).first`. Cycle intervals are computed between each adjacent pair in chronological (ascending) order.

---

### S3: Next-period, ovulation, and fertile-window prediction formulas

**Story ID:** PH-3-E2-S3
**Points:** 3

Apply the locked prediction formulas to produce the four output dates. These formulas are defined in the spec and must not be modified.

**Acceptance Criteria:**

- [ ] `predictedNextPeriod = Calendar.current.date(byAdding: .day, value: averageCycleLength, to: lastPeriodStartDate)!`
- [ ] `predictedOvulation = Calendar.current.date(byAdding: .day, value: -14, to: predictedNextPeriod)!`
- [ ] `fertileWindowStart = Calendar.current.date(byAdding: .day, value: -5, to: predictedOvulation)!`
- [ ] `fertileWindowEnd = predictedOvulation`
- [ ] `lastPeriodStartDate` is the `startDate` of the most recent completed period (first element after descending sort)
- [ ] With 0 completed periods, `lastPeriodStartDate` falls back to `cycleProfile.updatedAt` (the onboarding date) -- confirmed as the correct fallback per the cadence-data-layer skill default path
- [ ] Spot-check: `lastPeriodStartDate = Jan 1 2001`, `averageCycleLength = 28` → `predictedNextPeriod = Jan 29 2001`, `predictedOvulation = Jan 15 2001`, `fertileWindowStart = Jan 10 2001`, `fertileWindowEnd = Jan 15 2001`
- [ ] The resulting `PredictionSnapshot` has `dateGenerated = Date()` set at call time (the snapshot records when it was generated, not a predicted date)

**Dependencies:** PH-3-E2-S2
**Notes:** All four output dates use `Calendar.current.date(byAdding:value:to:)` -- never `date.addingTimeInterval(N * 86400)`. The spot-check values match the cadence-testing skill §3 algorithm spot-check test case exactly.

---

### S4: Confidence scoring with standard deviation

**Story ID:** PH-3-E2-S4
**Points:** 3

Implement the confidence scoring function using the four-case rule from the cadence-data-layer skill. Implement the sample standard deviation helper for cycle lengths. Handle the SD-undefined edge case (fewer than 2 data points).

**Acceptance Criteria:**

- [ ] A private helper `func standardDeviation(_ values: [Double]) -> Double` computes sample SD: `sqrt( sum( (x - mean)^2 ) / (n - 1) )` for n >= 2
- [ ] With 0 or 1 values, `standardDeviation` returns `Double.infinity` (represents "undefined, treat as > 2.0")
- [ ] Confidence scoring rule implemented exactly:
  - `cyclesUsed == 0 || cyclesUsed == 1` → `.low`
  - `cyclesUsed == 2 || cyclesUsed == 3` → `.medium`
  - `cyclesUsed >= 4 && sd <= 2.0` → `.high`
  - `cyclesUsed >= 4 && sd > 2.0` → `.medium`
- [ ] `sd <= 2.0` uses a plain `Double` `<=` comparison (no epsilon tolerance) -- the spec boundary is 2.0 and is inclusive
- [ ] Cycle length values fed to `standardDeviation` are `[Double]` derived from the computed start-to-start intervals (same values used to compute `averageCycleLength` in S2)
- [ ] With `cyclesUsed < 4`, `standardDeviation` is not computed (short-circuit return before calling the helper)
- [ ] The resulting `confidenceLevel` and `cyclesUsed` are set on the `PredictionSnapshot` returned by `recalculate`

**Dependencies:** PH-3-E2-S3
**Notes:** The SD threshold 2.0 is a product spec value defined in cadence-data-layer skill §3. Do not adjust it. The `Double.infinity` sentinel for undefined SD ensures the `> 2.0` branch is taken when SD is uncomputable, which gives `.medium` (the conservative option) for the 4+ cycles case.

---

### S5: Recalculation trigger and CycleProfile average update

**Story ID:** PH-3-E2-S5
**Points:** 3

Implement the write path function that ties together the local SwiftData write, PredictionEngine call, and snapshot insertion. Update `CycleProfile` averages after each recalculation. Enqueue all modified records via `SyncCoordinator`. This is the offline-first write contract in action.

**Acceptance Criteria:**

- [ ] `Cadence/Services/PeriodLogService.swift` exists with `func writePeriodLog(_ log: PeriodLog, context: ModelContext, syncCoordinator: any SyncCoordinatorProtocol, cycleProfile: CycleProfile) async`
- [ ] Step 1: `context.insert(log)` with `log.syncStatus = .pending` -- write to SwiftData first
- [ ] Step 2: Fetch all completed `PeriodLog` records for the user from `context` using a `FetchDescriptor`
- [ ] Step 3: Call `PredictionEngine().recalculate(completedPeriods:cycleProfile:)` synchronously
- [ ] Step 4: Insert the resulting `PredictionSnapshot` into `context` with `syncStatus = .pending`
- [ ] Step 5: Update `cycleProfile.averageCycleLength` and `cycleProfile.averagePeriodLength` to the computed averages; set `cycleProfile.syncStatus = .pending`; set `cycleProfile.updatedAt = Date()`
- [ ] Step 6: `try context.save()` -- save all three changes atomically
- [ ] Step 7: Enqueue all three modified records via `await syncCoordinator.enqueue(.periodLog(log))`, `.predictionSnapshot(snapshot)`, `.cycleProfile(cycleProfile)` -- these calls do not block the caller
- [ ] No Supabase write occurs in this function -- the sync is enqueued only
- [ ] `writePeriodLog` accepts `SyncCoordinatorProtocol` (not the concrete `SyncCoordinator`) so it is testable with `FakeSyncCoordinator` in PH-3-E3
- [ ] `project.yml` updated with `Cadence/Services/PeriodLogService.swift`

**Dependencies:** PH-3-E2-S4, PH-3-E4-S1 (SyncCoordinatorProtocol type must exist)
**Notes:** The `writePeriodLog` function is `async` only because `syncCoordinator.enqueue` is `async` (actor method). The SwiftData writes and prediction computation are synchronous within it. No network calls are made. If the `context.save()` throws, the function propagates the error to the caller -- the Supabase enqueue is not attempted on save failure.

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
- [ ] `PredictionEngine.recalculate` produces correct output for the algorithm spot-check case (Jan 1 + 28 days → Jan 29 next period)
- [ ] `PredictionEngine.swift` contains zero imports of Supabase, URLSession, or any network framework
- [ ] Phase objective is advanced: a correct, deterministic prediction engine is available for Phase 3 unit tests and Phase 5 UI
- [ ] Applicable skill constraints satisfied: `cadence-data-layer` (all algorithm formulas exact, SD threshold 2.0, recalculation trigger on PeriodLog write, no network imports, offline-first write contract), `cadence-sync` (SyncCoordinator is sole Supabase gateway; enqueue is step 7, after all local writes), `swiftui-production` (no force unwraps except calendar date arithmetic where nil is impossible)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] Offline-first write path verified: SwiftData write precedes enqueue in `writePeriodLog`
- [ ] Source document alignment verified: all four prediction formulas match cadence-data-layer skill §3 and MVP Spec §8 exactly

## Source References

- cadence-data-layer skill §3 (Prediction Algorithm -- all formulas, SD threshold, recalculation trigger, offline-first write path code)
- cadence-data-layer skill §4 (Offline-First Write Contract -- correct write path example)
- cadence-data-layer skill §5 (Network Isolation -- PredictionEngine import constraints)
- MVP Spec §8 (Fertility and Cycle Predictions -- prediction rules, confidence levels, average recalculation)
- cadence-testing skill §3 (PredictionEngine unit test contract -- all 10 edge cases, date fixtures, test naming)
- PHASES.md: Phase 3 -- Core Data Layer & Prediction Engine (In-Scope items 2-4)
