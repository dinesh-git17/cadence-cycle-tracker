# Today's Log Card, Log Today CTA, and Insight Card

**Epic ID:** PH-5-E4
**Phase:** 5 -- Tracker Home Dashboard
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement the lower three feed sections of the Tracker Home dashboard: `TodayLogCard` (slots 4), the Log Today CTA button (slot 5), and `InsightCard` (slot 6). Together these sections close the daily habit loop -- a Tracker can see what they logged today at a glance, tap Log Today to add more, and receive a contextual insight once sufficient cycle history exists. This epic completes the Phase 5 feed and delivers the full Home dashboard experience.

## Problem / Context

The `TodayLogCard` reads today's `DailyLog` and renders the active `SymptomChip` set using the `SymptomChip` component built in Phase 4 (`PH-4-E3`). The chip grid on the Home dashboard is read-only -- chips reflect logged state but cannot be toggled from this view. `SymptomChip` has an `isReadOnly: Bool` parameter (`PH-4-E3`) that must be set to `true` here to disable the tap gesture. Rendering it without `isReadOnly: true` would allow the Home card to inadvertently write symptom state.

The Log Today CTA is a `PrimaryButton` that opens the Log Sheet. In Phase 4, the Log Sheet is opened from `TrackerShell` via `isLogSheetPresented`. The Home view does not own sheet state -- it must signal up to `TrackerShell` to present the sheet. This is the parent-coordinator-owned sheet presentation pattern from the cadence-navigation skill. A direct sheet presentation from `TrackerHomeView` would create a second, floating sheet presentation context -- a navigation architecture violation.

The `InsightCard` is the most nuanced component. MVP Spec §3 lists insight examples, but does not specify an algorithm beyond what the prediction engine already computes. Design Spec §12.2 says the Insight Card is "shown only when sufficient cycle history exists" -- the threshold is not explicitly defined in the spec. Two completed cycles is the minimum meaningful data threshold used throughout the product (it is the same threshold as Reports, per Design Spec §13). For Phase 5, the insight card is shown when `completedCycleCount >= 2` and is hidden otherwise. The insight content derives from data already available in `TrackerHomeViewModel`: prediction snapshots and `PeriodLog` history. Symptom-pattern insights (e.g., "You usually experience cramps on days 1 and 2") require symptom frequency analysis across cycles -- this is implementable from `SymptomLog` data in Phase 5, and is scoped as an explicit story (S5).

**Source references that define scope:**

- Design Spec v1.1 §12.2 (Today's Log Card: "TODAY'S LOG" eyebrow, active chip display; Log Today CTA: full-width Primary CTA Button; Insight Card: CadenceSageLight surface, "INSIGHT" eyebrow, callout body -- shown only when sufficient cycle history exists)
- Design Spec v1.1 §10.1 (SymptomChip: default/active states; `isReadOnly` parameter disables tap gesture)
- Design Spec v1.1 §10.3 (PrimaryButton: CadenceTerracotta, 50pt height, 14pt corner)
- Design Spec v1.1 §13 (empty state: Today's Log when no symptoms logged; states and feedback)
- MVP Spec §3 (Tracker home components: today's log summary; insight examples: "Fertile window starts tomorrow", "Your last 3 cycles were within 2 days of each other", "You usually experience cramps on days 1 and 2")
- cadence-navigation skill (parent-coordinator-owned sheet pattern; child signals parent via callback; Log Sheet never presented from child views)
- PHASES.md Phase 5 in-scope: "Today's Log Card (INSIGHT eyebrow, active chip display); Log Today CTA (Primary CTA Button linking to Log Sheet); Insight Card (CadenceSageLight surface, INSIGHT eyebrow, callout body -- shown only when sufficient cycle history exists)"

## Scope

### In Scope

- `Cadence/Views/Tracker/Home/TodayLogCard.swift`: `struct TodayLogCard: View` taking `dailyLog: DailyLog?` parameter; wraps in `DataCard(isInsight: false)`; renders "TODAY'S LOG" eyebrow in `.caption2` `.textCase(.uppercase)` `CadenceTextSecondary`; renders active `SymptomChip` instances for all logged symptoms from `dailyLog.symptomLogs` using `SymptomChip(label:, isActive: true, isReadOnly: true)`; when `dailyLog == nil` or `dailyLog.symptomLogs.isEmpty`: renders "Nothing logged yet today." in `.font(.subheadline)` `CadenceTextSecondary` centered within the card
- Log Today CTA (slot 5): `PrimaryButton(label: "Log today", isLoading: false, isDisabled: false, action: onLogToday)` where `onLogToday: () -> Void` is a parameter on `TrackerHomeView` passed from `TrackerShell`; the button does not present a sheet directly -- it calls the callback which sets `TrackerShell.isLogSheetPresented = true`
- `Cadence/Views/Tracker/Home/InsightCard.swift`: `struct InsightCard: View` taking `insightText: String` parameter; wraps in `DataCard(isInsight: true)` (CadenceSageLight surface); renders "INSIGHT" eyebrow in `.caption2` `.textCase(.uppercase)` `CadenceSage`; renders `insightText` in `.font(.callout)` `CadenceTextPrimary`
- Insight Card gating in `TrackerHomeView` slot 6: shown only when `viewModel.completedCycleCount >= 2` and `viewModel.insightText != nil`; hidden (slot absent) below threshold
- `TrackerHomeViewModel` extended with `var insightText: String?` -- derived in priority order: (1) if `periodDaysRemaining <= 1`: `"Your period is expected \(periodDaysRemaining == 0 ? "today" : "tomorrow")."` (2) if `ovulationDaysRemaining == 1`: `"Fertile window starts tomorrow."` (3) if `completedCycleCount >= 3` and cycle standard deviation <= 2: `"Your last \(min(completedCycleCount, 6)) cycles were within 2 days of each other."` (4) symptom frequency insight if most-common symptom appears in >= 2 of last 3 cycles on days 1-2: `"You often experience [symptom] in the first 2 days of your cycle."` (5) `nil` if no condition is met
- `TrackerHomeViewModel` extended with symptom frequency computation: query `SymptomLog` entries joined to `DailyLog` for the Tracker's last 3 completed cycles; count occurrences of each symptom on cycle days 1-2; if any symptom appears in >= 2 of those 3 cycles, it is the candidate symptom for insight (4)
- `TrackerHomeView` wired with `onLogToday` callback parameter; `TrackerShell` passes `{ isLogSheetPresented = true }` as the callback; `selectedLogDate = Date()` set on `TrackerShell` before presenting the sheet
- `project.yml` updated for `TodayLogCard.swift`, `InsightCard.swift`; `xcodegen generate` exits 0

### Out of Scope

- Editing today's log from `TodayLogCard` (the card is read-only; edits go through the Log Sheet)
- Displaying flow level chips on `TodayLogCard` (flow level is shown in the Log Sheet period toggles, not in the today's log card summary)
- Advanced insight patterns beyond the four derivation rules defined above (e.g., mood correlation, sleep quality patterns -- not specified in source docs for Phase 5)
- Insight card content populated via Supabase remote configuration (Phase 5 uses locally derived insights only)
- Multiple insight cards (one insight card, one insight at a time, as shown in Design Spec §12.2 feed order)

## Dependencies

| Dependency                                                                                                                                | Type | Phase/Epic | Status | Risk                                                                                                                         |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------- |
| PH-5-E1 complete: `TrackerHomeView` slots 4, 5, 6 exist; `TrackerHomeViewModel` with `completedCycleCount`, `todayLog`                    | FS   | PH-5-E1    | Open   | High -- this epic populates these slots                                                                                      |
| PH-4-E2 complete: `LogSheetView` exists and `TrackerShell` owns `isLogSheetPresented`; `TrackerHomeView` accepts an `onLogToday` callback | FS   | PH-4-E2    | Open   | High -- Log Today CTA signals to TrackerShell; the callback pattern depends on Phase 4 Log Sheet being wired to TrackerShell |
| PH-4-E3 complete: `SymptomChip` component with `isReadOnly: Bool` parameter                                                               | FS   | PH-4-E3    | Open   | High -- `TodayLogCard` uses `SymptomChip(isReadOnly: true)`                                                                  |
| PH-4-E4-S1 complete: `DataCard` and `PrimaryButton` components                                                                            | FS   | PH-4-E4    | Open   | Low -- established in Phase 4                                                                                                |
| Phase 3 complete: `DailyLog`, `SymptomLog`, `PeriodLog` SwiftData models with all fields used here                                        | FS   | PH-3       | Open   | High -- TodayLogCard and insight computation read these models                                                               |

## Assumptions

- `TrackerHomeView` is modified to accept a `var onLogToday: () -> Void` parameter. `TrackerShell` passes `{ self.selectedLogDate = Date(); self.isLogSheetPresented = true }` as the closure. This is the parent-coordinator pattern -- `TrackerHomeView` cannot own sheet state.
- `DailyLog.symptomLogs` is an array of `SymptomLog` entries accessible from the `DailyLog` `@Model` object via a SwiftData relationship. The `symptomType` enum on `SymptomLog` maps to `SymptomChip` label strings via a computed `displayName: String` property on the enum.
- `SymptomLog` records for today's `DailyLog` are loaded as part of `TrackerHomeViewModel.load()` via the `todayLog` relationship fetch. No separate fetch is needed for symptom display in `TodayLogCard`.
- The insight derivation priority list (4 conditions, checked in order) produces at most one insight string. If no condition is met, `insightText` is `nil` and the insight slot is hidden entirely.
- Cycle standard deviation computation uses the last 3-6 completed cycle lengths, consistent with the prediction engine algorithm in Phase 3.

## Risks

| Risk                                                                                                                       | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                                       |
| -------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Symptom frequency computation in `TrackerHomeViewModel` is slow enough to delay `isLoading = false` by a noticeable amount | Low        | Medium | The computation queries at most 6 completed cycles' `SymptomLog` records -- a bounded, small dataset. SwiftData fetch is fast. If profiling reveals latency, move symptom frequency to a background `Task` that populates `insightText` independently after `isLoading = false`. |
| `TodayLogCard` chip grid wraps poorly at narrow screen widths with many active symptoms                                    | Low        | Low    | Use `LazyVGrid` with adaptive columns for chip display -- `LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8)`. This allows chips to fill the available width without overflowing.                                                                               |
| Log Today CTA callback pattern breaks if `TrackerHomeView` is ever previewed in isolation (no `TrackerShell` parent)       | Low        | Low    | Provide a `static func preview() -> TrackerHomeView` factory with a no-op `onLogToday: {}` closure for Preview usage.                                                                                                                                                            |
| Insight card appears and disappears as `completedCycleCount` crosses the threshold, causing a layout jump in the feed      | Low        | Low    | The insight slot is gated with a simple `if` -- it either occupies 0pt or its natural height. This is visible behavior but expected and consistent with other conditional feed elements. No animation needed for insight appearance (not specified).                             |

---

## Stories

### S1: TodayLogCard component -- eyebrow, read-only chip display, and empty state

**Story ID:** PH-5-E4-S1
**Points:** 3

Implement `TodayLogCard`: the read-only summary of today's logged symptoms. Renders active `SymptomChip` instances for all logged symptoms using `isReadOnly: true`. Shows a "Nothing logged yet today." empty state when no symptoms are present.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/TodayLogCard.swift` exists with `struct TodayLogCard: View`
- [ ] Parameter: `dailyLog: DailyLog?`
- [ ] Wraps content in `DataCard(isInsight: false)`
- [ ] "TODAY'S LOG" eyebrow: `Text("TODAY'S LOG")` in `.font(.caption2)` `.textCase(.uppercase)` `Color("CadenceTextSecondary")`; positioned at top of card via `VStack(alignment: .leading, spacing: 8)`
- [ ] When `dailyLog != nil` and symptom count > 0: renders a `LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8)` with `SymptomChip(label: symptom.displayName, isActive: true, isReadOnly: true)` for each symptom in `dailyLog.symptomLogs`
- [ ] When `dailyLog == nil` or `dailyLog.symptomLogs.isEmpty`: renders `Text("Nothing logged yet today.")` in `.font(.subheadline)` `Color("CadenceTextSecondary")` with `.frame(maxWidth: .infinity, alignment: .center)` inside the `DataCard`
- [ ] `SymptomChip` instances are rendered with `isReadOnly: true` -- no tap gesture is active on any chip in this view
- [ ] A SwiftUI Preview shows two states: one with 3 active symptoms, one with `dailyLog = nil`
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-4-E3 (SymptomChip with isReadOnly parameter), PH-4-E4-S1 (DataCard)

**Notes:** `SymptomLog.symptom_type` is an enum. The `displayName: String` computed property returns the plain-language chip label (e.g., `.cramps` = "Cramps", `.fatigue` = "Fatigue"). This property lives on the `SymptomType` enum in the Phase 3 data layer. If it is not present in Phase 3, add it in Phase 5 as an extension on `SymptomType`.

---

### S2: TodayLogCard empty state and integration into TrackerHomeView slot 4

**Story ID:** PH-5-E4-S2
**Points:** 2

Integrate `TodayLogCard` into `TrackerHomeView` slot 4, verify the skeleton-to-card transition, and confirm the empty state renders correctly on a Tracker with no symptoms logged today.

**Acceptance Criteria:**

- [ ] `TrackerHomeView` slot 4 renders `TodayLogCard(dailyLog: viewModel.todayLog)` when `viewModel.isLoading == false`
- [ ] `TrackerHomeView` slot 4 renders `SkeletonCard(height: 88)` when `viewModel.isLoading == true`
- [ ] On first launch (no `DailyLog` for today): `TodayLogCard` shows "Nothing logged yet today." in the simulator
- [ ] After logging symptoms via the Log Sheet (in a manual test flow): `TodayLogCard` shows the active chips for those symptoms -- confirmed by forcing a SwiftData insert in a Preview
- [ ] `TodayLogCard` does not appear below the `SkeletonCard` during loading (no double-render)
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E4-S1, PH-5-E1

---

### S3: Log Today CTA -- PrimaryButton wired to TrackerShell Log Sheet via callback

**Story ID:** PH-5-E4-S3
**Points:** 2

Add an `onLogToday: () -> Void` parameter to `TrackerHomeView`. Wire `TrackerShell` to pass `{ selectedLogDate = Date(); isLogSheetPresented = true }`. Render `PrimaryButton` in feed slot 5 calling the callback.

**Acceptance Criteria:**

- [ ] `TrackerHomeView` gains `var onLogToday: () -> Void` as a required parameter
- [ ] `TrackerShell` passes `{ self.selectedLogDate = Date(); self.isLogSheetPresented = true }` as the `onLogToday` closure when mounting `TrackerHomeView` inside the Home tab `NavigationStack`
- [ ] Feed slot 5 renders `PrimaryButton(label: "Log today", isLoading: false, isDisabled: false, action: onLogToday)`
- [ ] `PrimaryButton` is not presented with `.sheet(isPresented:)` from `TrackerHomeView` -- no sheet modifier exists on `TrackerHomeView` or `TodayLogCard` or any other Phase 5 view
- [ ] In the simulator: tapping "Log today" from the Home tab presents the Log Sheet (`TrackerShell`-owned sheet) with today's date
- [ ] After dismissing the Log Sheet: Home tab is still selected; `TrackerHomeView` is visible; `selectedTab` did not change
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E1, PH-4-E1 (TrackerShell owns sheet state), PH-4-E2 (LogSheetView exists)

**Notes:** The `PrimaryButton` callback pattern is the only Log Sheet entry point from Phase 5. The cadence-navigation skill prohibits child views from owning the Log Sheet's `isPresented` binding. If `TrackerHomeView` had its own `@State var isLogSheetPresented`, it would create a second sheet context floating over the TrackerShell-owned sheet, producing double-presentation bugs.

---

### S4: InsightCard component -- CadenceSageLight surface, eyebrow, and callout body

**Story ID:** PH-5-E4-S4
**Points:** 3

Implement `InsightCard`: the `DataCard(isInsight: true)` wrapped component with the "INSIGHT" eyebrow and a callout-style body. The component is display-only -- it receives `insightText: String` and renders it. Gating logic lives in `TrackerHomeViewModel`, not in `InsightCard` itself.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/InsightCard.swift` exists with `struct InsightCard: View`
- [ ] Parameter: `insightText: String`
- [ ] Wraps content in `DataCard(isInsight: true)` (CadenceSageLight background, 1pt CadenceBorder stroke, 16pt corner, 20pt padding)
- [ ] "INSIGHT" eyebrow: `Text("INSIGHT")` in `.font(.caption2)` `.textCase(.uppercase)` `Color("CadenceSage")`
- [ ] Body text: `Text(insightText)` in `.font(.callout)` `Color("CadenceTextPrimary")`
- [ ] `VStack(alignment: .leading, spacing: 8)` for eyebrow and body
- [ ] `accessibilityLabel`: `"Insight: \(insightText)"` on the outer container so VoiceOver announces the full insight in one traversal stop
- [ ] A SwiftUI Preview shows the card with each of the four possible insight strings from the `TrackerHomeViewModel` priority list
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-4-E4-S1 (DataCard with isInsight variant)

---

### S5: TrackerHomeViewModel insight derivation and InsightCard gating

**Story ID:** PH-5-E4-S5
**Points:** 5

Extend `TrackerHomeViewModel` with the four-condition insight derivation priority list and the symptom frequency computation. Wire `InsightCard` into `TrackerHomeView` slot 6 with the `completedCycleCount >= 2` gating rule.

**Acceptance Criteria:**

- [ ] `TrackerHomeViewModel` gains `var insightText: String?` computed in `load()` after prediction and log data is fetched
- [ ] Condition 1 (period imminent): if `periodDaysRemaining <= 1`, set `insightText = "Your period is expected \(periodDaysRemaining == 0 ? "today" : "tomorrow")."` -- evaluated first; takes priority over all other conditions
- [ ] Condition 2 (fertile window imminent): if `ovulationDaysRemaining == 1` and condition 1 is not met, set `insightText = "Fertile window starts tomorrow."`
- [ ] Condition 3 (cycle regularity): if `completedCycleCount >= 3` and the standard deviation of the last 3-6 completed cycle lengths is <= 2.0 days and conditions 1 and 2 are not met, set `insightText = "Your last \(min(completedCycleCount, 6)) cycles were within 2 days of each other."`
- [ ] Condition 4 (symptom pattern): fetch `SymptomLog` entries joined to `DailyLog` for cycle days 1-2 of the last 3 completed cycles; if any `symptom_type` appears in >= 2 of those 3 cycles on cycle days 1-2 and conditions 1-3 are not met, set `insightText = "You often experience \(symptom.displayName.lowercased()) in the first 2 days of your cycle."`
- [ ] If no condition is met, `insightText = nil`
- [ ] `TrackerHomeView` slot 6: `if viewModel.completedCycleCount >= 2, let text = viewModel.insightText { InsightCard(insightText: text) }` -- both conditions must be true
- [ ] Slot 6 shows `SkeletonCard(height: 96)` when `viewModel.isLoading == true`; shows nothing when `isLoading == false` and the gate conditions are not met
- [ ] Unit tests in `CadenceTests/TrackerHomeViewModelTests.swift` cover: condition 1 fires when `periodDaysRemaining = 0`; condition 2 fires when `ovulationDaysRemaining = 1` and `periodDaysRemaining > 1`; condition 3 fires with 4 cycles of equal length; condition 4 fires when cramps appear on days 1-2 in 2 of 3 cycles; `insightText = nil` when 1 completed cycle exists
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E4-S4, PH-5-E1-S1, PH-5-E3-S5

**Notes:** Cycle standard deviation for condition 3 uses the same cycle length array as the prediction engine (Phase 3). Extract the standard deviation computation into a file-private extension or a shared utility that both `PredictionEngine` and `TrackerHomeViewModel` can call without duplication. If `PredictionEngine` already exposes a `cycleStandardDeviation: Double` property, read it directly.

---

### S6: Full Phase 5 feed end-to-end verification

**Story ID:** PH-5-E4-S6
**Points:** 3

Verify the complete Tracker Home Dashboard feed -- all six slots in correct order, all skeleton-to-content transitions, all empty states, and all three entry points to the Log Sheet -- against Design Spec §12.2 in the iOS 26 simulator.

**Acceptance Criteria:**

- [ ] Feed renders in the following slot order with no gap anomalies: (1) absent strip (isPartnerConnected = false), (2) CycleStatusCard, (3) CountdownRow, (4) TodayLogCard, (5) "Log today" CTA, (6) InsightCard (if gated condition met) or absent
- [ ] All six slots show `SkeletonCard` during `isLoading = true`; all six resolve to their live states after `isLoading = false`
- [ ] Zero-prediction state (predictionSnapshot = nil): slots 2 and 3 replaced by the zero-cycle explanatory `DataCard`; slots 4, 5, and 6 still render
- [ ] First-launch state (completedCycleCount < 2): slot 6 is absent (no InsightCard); confirmed in simulator
- [ ] With completedCycleCount >= 2 and an applicable insight condition: InsightCard appears in slot 6 with the correct text
- [ ] Tapping "Log today" from the Home tab presents the Log Sheet via `TrackerShell` (correct date pre-filled); dismissing the sheet returns to the Home feed with no navigation state corruption
- [ ] Tapping the Log tab center button also presents the Log Sheet (this is Phase 4 behavior -- verify it is not broken by Phase 5 changes)
- [ ] 32pt inter-card gap is visually consistent between all adjacent card pairs -- verified by comparing slot boundaries in the simulator against a 32pt reference
- [ ] 16pt horizontal inset is consistent on both sides across all cards -- verified in simulator
- [ ] `scripts/protocol-zero.sh` exits 0 on all Phase 5 source files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all Phase 5 source files
- [ ] `xcodebuild build` exits 0 with zero warnings

**Dependencies:** PH-5-E4-S1, PH-5-E4-S2, PH-5-E4-S3, PH-5-E4-S4, PH-5-E4-S5, PH-5-E3, PH-5-E2

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

- [ ] All six stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Full Home feed renders all 6 slots in correct order in the iOS 26 simulator
- [ ] `TodayLogCard` chip grid is read-only -- no chip is togglable from the Home screen
- [ ] Log Today CTA opens the Log Sheet via `TrackerShell` callback -- no sheet ownership in `TrackerHomeView`
- [ ] InsightCard appears only when `completedCycleCount >= 2` and an applicable condition is met
- [ ] Insight derivation unit tests pass for all five conditions (4 positive + 1 nil case)
- [ ] Phase 5 phase objective achieved: a Tracker landing on the Home tab sees their current cycle phase, confidence level, period and ovulation countdowns, today's logged symptoms, and a contextual insight (when applicable)
- [ ] cadence-design-system skill: no hardcoded hex; all tokens referenced by name
- [ ] swiftui-production skill: no AnyView; LazyVGrid for chip display; view extraction per 50-line rule
- [ ] cadence-navigation skill: Log Sheet owned by TrackerShell; no sheet presentation from TrackerHomeView
- [ ] cadence-accessibility skill: TodayLogCard VoiceOver reads each chip label and active state; InsightCard accessibilityLabel includes "Insight:" prefix; Dynamic Type scaling verified
- [ ] cadence-motion skill: all custom animations in Phase 5 gated on accessibilityReduceMotion
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No force unwraps, hardcoded hex values, or `print()` calls in any committed Swift file

## Source References

- PHASES.md: Phase 5 -- Tracker Home Dashboard (in-scope: Today's Log Card, Log Today CTA, Insight Card; completion standard: "A Tracker landing on the Home tab sees their current cycle phase, confidence level, period and ovulation countdowns, today's logged symptoms, and a contextual insight")
- Design Spec v1.1 §12.2 (Today's Log Card: TODAY'S LOG eyebrow, active chip display; Log Today CTA: Primary CTA Button; Insight Card: CadenceSageLight surface, INSIGHT eyebrow, callout body, shown only when sufficient cycle history exists)
- Design Spec v1.1 §10.1 (SymptomChip: isReadOnly parameter disables tap gesture)
- Design Spec v1.1 §10.3 (PrimaryButton: CadenceTerracotta, 50pt height, 14pt corner)
- Design Spec v1.1 §13 (empty state: Today's Log when no symptoms logged)
- MVP Spec §3 (Tracker home components; insight examples: Fertile window, cycle regularity, symptom pattern)
- cadence-navigation skill (parent-coordinator sheet ownership; Log Sheet never presented from child views)
- cadence-accessibility skill (chip VoiceOver labels; InsightCard accessibilityLabel prefix)
- cadence-data-layer skill (DailyLog, SymptomLog, PeriodLog schema; cycle SD computation)
