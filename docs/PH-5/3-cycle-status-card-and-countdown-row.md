# Cycle Status Card and Countdown Row

**Epic ID:** PH-5-E3
**Phase:** 5 -- Tracker Home Dashboard
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement `CycleStatusCard`, `ConfidenceBadge`, `CountdownCard`, and `CountdownRow` -- the four components that occupy feed slots 2 and 3 and communicate a Tracker's current cycle position and upcoming event timing. All four read from the `PredictionSnapshot` fetched by `TrackerHomeViewModel`. This epic delivers the primary informational payload of the Home dashboard.

## Problem / Context

The Cycle Status Card and Countdown Row are the first data surfaces a Tracker sees on every app open. They answer the question "where am I right now?" with three signals: the current cycle phase name, the confidence level of predictions, and the countdown to the next period and estimated ovulation. Design Spec §12.2 defines all three precisely.

The 48pt rounded numeral in `CountdownCard` requires a non-Dynamic-Type-scaled font: `.system(size: 48, weight: .medium, design: .rounded)`. Design Spec §4 notes this explicitly: "Large countdown numbers use `.system(size: 48, weight: .medium, design: .rounded)` -- not a named Dynamic Type style, but must scale with `accessibilityLargeText`." The phrase "must scale with accessibilityLargeText" means the `48` value must respond to the accessibility large text category via `@ScaledMetric` -- the raw `.system(size: 48)` does NOT scale automatically. This is a subtle but required distinction.

`ConfidenceBadge` maps `PredictionSnapshot.confidence_level` (high / medium / low) to a text label and renders in a `CadenceSageLight` filled capsule. The badge must not appear when `predictionSnapshot == nil` (zero-cycle state handled in E1).

Both `CountdownCard` instances use the same component with different color parameters: `CadenceTerracotta` for period countdown, `CadenceSage` for ovulation countdown. They are placed in `CountdownRow` as an `HStack` with equal width and a 12pt gap.

**Source references that define scope:**

- Design Spec v1.1 §12.2 (Cycle Status Card: phase name display style, confidence badge CadenceSageLight, "Cycle day X of Y" subheadline, disclaimer footnote italic; Countdown Row: two equal-width cards, 48pt rounded numeral, period CadenceTerracotta, ovulation CadenceSage)
- Design Spec v1.1 §4 (large countdown numbers: `.system(size: 48, weight: .medium, design: .rounded)`; must scale with accessibilityLargeText)
- Design Spec v1.1 §10.4 (DataCard: CadenceCard surface, 1pt CadenceBorder stroke, 16pt corner radius, 20pt internal padding, no shadow)
- Design Spec v1.1 §10 (confidence badge: CadenceSageLight background, CadenceSage text, caption1, capsule)
- MVP Spec §8 (predictions: confidence high/medium/low definitions; disclaimer label "Based on your logged history -- not medical advice.")
- cadence-data-layer skill (PredictionSnapshot schema: predicted_next_period, predicted_ovulation, fertile_window_start, fertile_window_end, confidence_level)
- PHASES.md Phase 5 in-scope: "Cycle Status Card (phase name in display type, confidence badge in CadenceSageLight, cycle day subheadline, disclaimer footnote); Countdown Row (two equal-width cards, 48pt rounded numeral, period CadenceTerracotta, ovulation CadenceSage)"

## Scope

### In Scope

- `Cadence/Views/Tracker/Home/CycleStatusCard.swift`: `struct CycleStatusCard: View` taking `snapshot: PredictionSnapshot` and `cycleDay: Int` and `cycleLength: Int` parameters; wraps content in `DataCard(isInsight: false)`; renders phase name, confidence badge, cycle day subheadline, disclaimer footnote
- `Cadence/Views/Tracker/Home/ConfidenceBadge.swift`: `struct ConfidenceBadge: View` taking `confidence: ConfidenceLevel` (the enum from the data layer -- `.high`, `.medium`, `.low`); renders the confidence label in `CadenceSageLight` background, `CadenceSage` text, `.caption1`, capsule `RoundedRectangle(cornerRadius: 20)`
- `Cadence/Views/Tracker/Home/CountdownCard.swift`: `struct CountdownCard: View` taking `daysRemaining: Int`, `label: String`, `accentColor: Color` parameters; wraps in `DataCard(isInsight: false)`; renders `daysRemaining` in `.system(size: 48 * dynamicScale, weight: .medium, design: .rounded)` in `accentColor`; renders `label` in `.footnote` `CadenceTextSecondary`; `@ScaledMetric(relativeTo: .largeTitle) private var dynamicScale = 1.0` used to scale the 48pt base size
- `Cadence/Views/Tracker/Home/CountdownRow.swift`: `struct CountdownRow: View` taking `periodDaysRemaining: Int`, `ovulationDaysRemaining: Int`; renders `HStack(spacing: 12)` with `CountdownCard(daysRemaining: periodDaysRemaining, label: "Days until period", accentColor: Color("CadenceTerracotta"))` and `CountdownCard(daysRemaining: ovulationDaysRemaining, label: "Days until ovulation", accentColor: Color("CadenceSage"))`, each with `.frame(maxWidth: .infinity)`
- `TrackerHomeViewModel` extended with: `var cycleDay: Int` (computed from last `PeriodLog.start_date` to today); `var cycleLength: Int` (from `CycleProfile.average_cycle_length`); `var periodDaysRemaining: Int` (from `predictionSnapshot.predicted_next_period` - today); `var ovulationDaysRemaining: Int` (from `predictionSnapshot.predicted_ovulation` - today) -- all return 0 if `predictionSnapshot == nil`
- `TrackerHomeView` slots 2 and 3: slot 2 shows `CycleStatusCard(snapshot:, cycleDay:, cycleLength:)` when `predictionSnapshot != nil` and `isLoading == false`; slot 3 shows `CountdownRow(periodDaysRemaining:, ovulationDaysRemaining:)` under the same conditions; both slots show `SkeletonCard` when `isLoading == true` and the E1 zero-prediction empty state when `predictionSnapshot == nil`
- Phase name derivation: computed from `cycleDay` and `CycleProfile.goal_mode` per the following rules: day 1 through average period length = "Menstrual phase"; next 6 days = "Follicular phase"; fertile window days = "Fertile window"; ovulation day = "Ovulation day"; remaining days = "Luteal phase" -- these labels are the non-clinical display names used in the spec; derivation logic lives in `TrackerHomeViewModel`
- Disclaimer footnote: `"Based on your logged history -- not medical advice."` in `.footnote` `.italic()` `CadenceTextSecondary` below the cycle day subheadline
- `project.yml` updated for all four new Swift files; `xcodegen generate` exits 0

### Out of Scope

- Fertility window details on the Home dashboard (shown in Calendar, Phase 6)
- Editing cycle parameters from the Home dashboard (Settings, Phase 12)
- Real-time prediction recalculation triggered from the Home view (prediction engine recalculates on period history update per Phase 3 -- Home view only reads the latest snapshot)
- Ovulation day and fertile window cards beyond the two CountdownCard instances specified here

## Dependencies

| Dependency                                                                                                                  | Type | Phase/Epic | Status | Risk                                                             |
| --------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---------------------------------------------------------------- |
| PH-5-E1 complete: `TrackerHomeViewModel` exists; `TrackerHomeView` feed slots 2 and 3 exist as `EmptyView()` placeholders   | FS   | PH-5-E1    | Open   | High -- this epic replaces those placeholders                    |
| Phase 3 complete: `PredictionSnapshot`, `CycleProfile` SwiftData models with all fields used here                           | FS   | PH-3       | Open   | High -- `TrackerHomeViewModel` extensions read from these models |
| PH-4-E4-S1 complete: `DataCard` component available for wrapping `CycleStatusCard` and `CountdownCard`                      | FS   | PH-4-E4-S1 | Open   | Low -- established in Phase 4                                    |
| Color assets `CadenceTerracotta`, `CadenceSage`, `CadenceTextSecondary`, `CadenceSageLight`, `CadenceBorder`, `CadenceCard` | FS   | PH-0-E2    | Open   | Low -- established in Phase 0                                    |

## Assumptions

- `PredictionSnapshot.confidence_level` maps to `enum ConfidenceLevel: String, Codable { case high, medium, low }` defined in the Phase 3 data layer. `ConfidenceBadge` receives this enum directly.
- `CountdownCard` renders negative values (days past due) as `0` -- the `max(0, daysRemaining)` clamp is applied in `TrackerHomeViewModel`, not inside `CountdownCard`. The component itself is display-only.
- Phase name derivation uses `CycleProfile.average_cycle_length` and `average_period_length` as the bounds for phase windows. This is the same data used by the prediction engine and is available from SwiftData without an additional fetch.
- `@ScaledMetric(relativeTo: .largeTitle)` on the `dynamicScale` multiplier scales proportionally with the `.largeTitle` text category. At default type size, `dynamicScale = 1.0` so the numeral renders at exactly 48pt. At AX5, the multiplier increases and the numeral scales up.

## Risks

| Risk                                                                                                                     | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------ | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@ScaledMetric` multiplied by 48 produces a fractional point value causing subpixel rendering artifacts                  | Low        | Low    | Cast to `CGFloat` and round: `let scaledSize = (48.0 * dynamicScale).rounded()` before passing to `.system(size:)`                                                                                                                                              |
| Phase name derivation edge cases: cycleDay == 0 (today == period start), cycleDay exceeds cycle length (irregular cycle) | Medium     | Medium | Clamp `cycleDay` to `1...cycleLength` range; render "Luteal phase" for any day beyond the luteal window boundary; add unit tests for edge cases in the ViewModel extension                                                                                      |
| `CountdownCard` negative day values (predicted period is overdue)                                                        | Low        | Medium | `periodDaysRemaining = max(0, daysBetween(Date(), snapshot.predicted_next_period))` in `TrackerHomeViewModel`; consider rendering "Today" or "Overdue" label for 0-day value -- this is not specified in source docs; default to `0` and flag for design review |
| `DataCard` 20pt internal padding causes `CountdownCard` numerals to feel cramped at large Dynamic Type sizes             | Low        | Low    | `DataCard` uses `padding(20)` uniformly. The `CountdownCard` content is a `VStack` with the numeral and label -- this stacks vertically and does not constrain horizontal space                                                                                 |

---

## Stories

### S1: CycleStatusCard component -- phase name, cycle day, and disclaimer

**Story ID:** PH-5-E3-S1
**Points:** 3

Implement `CycleStatusCard` as a `DataCard`-wrapped component showing the Tracker's current phase name in display font, the cycle day subheadline, and the disclaimer footnote. The confidence badge slot is left as an `EmptyView()` placeholder until `ConfidenceBadge` is implemented in S2.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/CycleStatusCard.swift` exists with `struct CycleStatusCard: View`
- [ ] Parameters: `phaseName: String`, `cycleDay: Int`, `cycleLength: Int`, `confidence: ConfidenceLevel`, `badge: (_ confidence: ConfidenceLevel) -> some View` as a `@ViewBuilder` parameter (allows the badge slot to accept `ConfidenceBadge` after S2)
- [ ] Wraps content in `DataCard(isInsight: false)`
- [ ] Phase name rendered in `.font(.system(size: 34, weight: .semibold, design: .default))` matching the `display` token (`.largeTitle` equivalent, 34pt semibold) in `Color("CadenceTextPrimary")`
- [ ] `badge(confidence)` slot renders below the phase name
- [ ] "Cycle day \(cycleDay) of \(cycleLength)" in `.font(.subheadline)` `Color("CadenceTextSecondary")` below the badge
- [ ] `"Based on your logged history -- not medical advice."` in `.font(.footnote)` `.italic()` `Color("CadenceTextSecondary")` at the bottom of the card
- [ ] `VStack(alignment: .leading, spacing: 8)` for internal layout
- [ ] A SwiftUI Preview shows the card with phaseName "Follicular phase", cycleDay 8, cycleLength 28, and an `EmptyView()` badge
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-4-E4-S1 (DataCard component)

**Notes:** Using a `@ViewBuilder` parameter for the badge slot avoids a hard dependency on `ConfidenceBadge` within `CycleStatusCard` and allows S1 and S2 to be implemented and previewed independently before integration in S3.

---

### S2: ConfidenceBadge component -- three confidence levels in CadenceSageLight capsule

**Story ID:** PH-5-E3-S2
**Points:** 2

Implement `ConfidenceBadge`: a compact capsule-shaped chip that maps the three `ConfidenceLevel` enum values to human-readable labels rendered in `CadenceSage` text on a `CadenceSageLight` background.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/ConfidenceBadge.swift` exists with `struct ConfidenceBadge: View`
- [ ] Parameter: `confidence: ConfidenceLevel`
- [ ] Label text per confidence level: `.high` = "High confidence"; `.medium` = "Medium confidence"; `.low` = "Low confidence"
- [ ] Text style: `.font(.caption)` (caption1 token, 12pt regular) in `Color("CadenceSage")`
- [ ] Background: `Color("CadenceSageLight")` on `Capsule()` (full pill shape -- 20pt corner radius approximated by Capsule)
- [ ] Padding: `.padding(.horizontal, 12).padding(.vertical, 4)` inside the capsule
- [ ] No border stroke on the badge (Design Spec §12.2 does not specify a stroke on the confidence badge)
- [ ] `accessibilityLabel`: `"\(label) prediction confidence"`
- [ ] A SwiftUI Preview shows all three confidence levels side by side
- [ ] `project.yml` updated; `xcodebuild build` exits 0

**Dependencies:** None (no dependencies on E3 stories; can proceed in parallel with S1)

**Notes:** `ConfidenceLevel` enum is defined in the Phase 3 data layer. If the exact enum type is unavailable at implementation time (Phase 3 not yet complete), define a local `enum ConfidenceLevel` in `ConfidenceBadge.swift` that mirrors the Phase 3 definition and remove the duplicate when Phase 3 merges.

---

### S3: CycleStatusCard + ConfidenceBadge integration and TrackerHomeViewModel phase name derivation

**Story ID:** PH-5-E3-S3
**Points:** 5

Wire `CycleStatusCard` with a live `ConfidenceBadge` badge slot. Extend `TrackerHomeViewModel` with cycle day calculation, cycle length read, and phase name derivation. Integrate both into `TrackerHomeView` slot 2.

**Acceptance Criteria:**

- [ ] `TrackerHomeViewModel` extended with `var phaseName: String` (computed from `cycleDay`, `averagePeriodLength`, `fertileWindowStart`, `ovulationDay` via the derivation rules: Menstrual phase = days 1 through `averagePeriodLength`; Follicular phase = next 6 days; Fertile window = `fertileWindowStart` through `ovulationDay - 1`; Ovulation day = `ovulationDay`; Luteal phase = all remaining days; clamp cycleDay to `1...averageCycleLength`)
- [ ] `TrackerHomeViewModel` extended with `var cycleDay: Int` (days from `lastPeriodStartDate` to today, minimum 1)
- [ ] `TrackerHomeViewModel` extended with `var cycleLength: Int` (reads `CycleProfile.average_cycle_length`; defaults to 28 if `CycleProfile` not found)
- [ ] `TrackerHomeView` slot 2: `CycleStatusCard(phaseName: viewModel.phaseName, cycleDay: viewModel.cycleDay, cycleLength: viewModel.cycleLength, confidence: viewModel.predictionSnapshot?.confidenceLevel ?? .low) { confidence in ConfidenceBadge(confidence: confidence) }` rendered when `isLoading == false && predictionSnapshot != nil`
- [ ] At the cycleDay boundary of each phase (e.g., day 5 for 5-day period), the phase transitions correctly -- verified with a unit test in `TrackerHomeViewModelTests`
- [ ] Phase names match Design Spec §12.2 labels exactly (non-clinical, plain language)
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E3-S1, PH-5-E3-S2, PH-5-E1

**Notes:** Phase name derivation logic must be covered by unit tests. This is the most likely source of edge-case bugs (cycleDay == 1 on period start, cycleDay at ovulation boundary, cycleDay beyond cycleLength due to late period). Write tests in `CadenceTests/TrackerHomeViewModelTests.swift`. The phase boundaries use `CycleProfile.average_period_length` and prediction engine outputs -- do not hardcode 5-day or 14-day constants.

---

### S4: CountdownCard component -- 48pt scaled numeral with color parameter

**Story ID:** PH-5-E3-S4
**Points:** 3

Implement `CountdownCard`: a `DataCard`-wrapped component with a large scaled numeral in a caller-specified accent color and a footnote label. The numeral uses `@ScaledMetric` to satisfy Design Spec §4's requirement that the 48pt size scales with `accessibilityLargeText`.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/CountdownCard.swift` exists with `struct CountdownCard: View`
- [ ] Parameters: `daysRemaining: Int`, `label: String`, `accentColor: Color`
- [ ] Wraps content in `DataCard(isInsight: false)`
- [ ] `@ScaledMetric(relativeTo: .largeTitle) private var dynamicScale: CGFloat = 1.0` declared
- [ ] Numeral rendered as `Text("\(max(0, daysRemaining))")` with `.font(.system(size: (48.0 * dynamicScale).rounded(), weight: .medium, design: .rounded))` in `accentColor`
- [ ] Label rendered as `Text(label)` in `.font(.footnote)` `Color("CadenceTextSecondary")`
- [ ] `VStack(alignment: .center, spacing: 4)` for numeral and label
- [ ] Numeral `accessibilityLabel`: `"\(max(0, daysRemaining)) \(label)"` so VoiceOver announces "14 days until period" rather than "14"
- [ ] A SwiftUI Preview shows two instances: `CountdownCard(daysRemaining: 14, label: "Days until period", accentColor: Color("CadenceTerracotta"))` and `CountdownCard(daysRemaining: 6, label: "Days until ovulation", accentColor: Color("CadenceSage"))` side by side in an `HStack`
- [ ] At AX5 Dynamic Type in the simulator, the numeral scales up and the `DataCard` height expands to accommodate it without clipping
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-4-E4-S1 (DataCard component)

---

### S5: CountdownRow and TrackerHomeViewModel countdown data wiring

**Story ID:** PH-5-E3-S5
**Points:** 3

Implement `CountdownRow` as the equal-width two-card `HStack` container, extend `TrackerHomeViewModel` with `periodDaysRemaining` and `ovulationDaysRemaining` computed from `PredictionSnapshot`, and wire slot 3 in `TrackerHomeView`.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/CountdownRow.swift` exists with `struct CountdownRow: View`
- [ ] Parameters: `periodDaysRemaining: Int`, `ovulationDaysRemaining: Int`
- [ ] Layout: `HStack(spacing: 12)` with two `CountdownCard` instances each with `.frame(maxWidth: .infinity)`
- [ ] Period card: `CountdownCard(daysRemaining: periodDaysRemaining, label: "Days until period", accentColor: Color("CadenceTerracotta"))`
- [ ] Ovulation card: `CountdownCard(daysRemaining: ovulationDaysRemaining, label: "Days until ovulation", accentColor: Color("CadenceSage"))`
- [ ] `TrackerHomeViewModel` extended with `var periodDaysRemaining: Int` = `Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: predictionSnapshot?.predicted_next_period ?? Date()).day ?? 0`, clamped to `max(0, ...)`
- [ ] `TrackerHomeViewModel` extended with `var ovulationDaysRemaining: Int` = same pattern for `predicted_ovulation`, clamped to `max(0, ...)`
- [ ] `TrackerHomeView` slot 3: `CountdownRow(periodDaysRemaining: viewModel.periodDaysRemaining, ovulationDaysRemaining: viewModel.ovulationDaysRemaining)` when `isLoading == false && predictionSnapshot != nil`
- [ ] `CountdownRow` renders symmetrically on all iPhone screen sizes from iPhone SE (375pt) to iPhone 16 Pro Max (430pt) -- verified in simulator; no card clips or overflows
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E3-S4, PH-5-E1

---

### S6: VoiceOver, Dynamic Type compliance, and E3 end-to-end verification

**Story ID:** PH-5-E3-S6
**Points:** 2

Verify that `CycleStatusCard`, `ConfidenceBadge`, `CountdownCard`, and `CountdownRow` all satisfy VoiceOver traversal order, Dynamic Type scaling at AX1-AX5, and correct rendering in the live simulator feed.

**Acceptance Criteria:**

- [ ] VoiceOver on `CycleStatusCard` reads: phase name, confidence badge label with "prediction confidence" suffix, cycle day text, disclaimer -- in top-to-bottom order with no redundant readings
- [ ] VoiceOver on `CountdownRow` reads each `CountdownCard` as a single unit: "14 days until period" and "6 days until ovulation" -- not "14" and "Days until period" as separate elements
- [ ] At AX3 Dynamic Type, `CycleStatusCard` internal text does not clip within `DataCard`'s 20pt padding; `DataCard` height expands naturally
- [ ] At AX5 Dynamic Type, `CountdownCard` numeral is visibly larger than at default size -- confirming `@ScaledMetric` is functioning
- [ ] No `.lineLimit(1)` or `.minimumScaleFactor` on any text in `CycleStatusCard` or `CountdownCard` unless explicitly justified with a reference to Design Spec §14
- [ ] Full feed renders in the iOS 26 simulator (iPhone 16 Pro) with slots 1-3 visible: strip absent (isPartnerConnected = false), cycle status card in slot 2, countdown row in slot 3
- [ ] `scripts/protocol-zero.sh` exits 0 on all E3 source files
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0 with zero warnings

**Dependencies:** PH-5-E3-S3, PH-5-E3-S5

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
- [ ] `CycleStatusCard` renders phase name, confidence badge, cycle day, and disclaimer correctly in simulator
- [ ] `CountdownRow` renders two equal-width cards with correctly colored numerals
- [ ] Phase name derivation unit tests pass for all boundary cases (day 1, day at period end, ovulation day, day beyond cycle length)
- [ ] `@ScaledMetric` numeral confirmed to scale at AX5 in simulator
- [ ] Phase objective is advanced: a Tracker landing on the Home tab sees their current phase and countdown data
- [ ] cadence-design-system skill: no hardcoded hex; display font per §4; subheadline, footnote per §4 table
- [ ] cadence-accessibility skill: VoiceOver traversal correct; countdown numeral accessibilityLabel includes label string; Dynamic Type scaling verified
- [ ] swiftui-production skill: no AnyView; view extraction per 50-line rule; no GeometryReader without justification
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

## Source References

- PHASES.md: Phase 5 -- Tracker Home Dashboard (in-scope: Cycle Status Card, Countdown Row -- full spec)
- Design Spec v1.1 §12.2 (Tracker Home Dashboard: Cycle Status Card all elements, Countdown Row two cards, 48pt rounded numeral, terracotta/sage colors, confidence badge)
- Design Spec v1.1 §4 (typography: display = 34pt semibold, subheadline = 15pt regular, footnote = 13pt regular; large countdown: .system(size: 48) must scale with accessibilityLargeText)
- Design Spec v1.1 §10.4 (DataCard: CadenceCard, 1pt CadenceBorder, 16pt corner, 20pt internal padding, no shadow)
- MVP Spec §8 (confidence levels: high = 4+ cycles SD<=2, medium = 2-3 cycles, low = 0-1 cycles; disclaimer label text)
- cadence-data-layer skill (PredictionSnapshot schema, ConfidenceLevel enum, rolling-average outputs)
- cadence-accessibility skill (VoiceOver label patterns, Dynamic Type scaling, accessibilityLabel on countdown)
