# Metric Cards & Chart Components

**Epic ID:** PH-11-E2
**Phase:** 11 -- Reports
**Estimated Size:** L
**Status:** Draft

---

## Objective

Build the five report display components -- two statistic cards and two Swift Charts visualizations, plus the shared disclaimer footer -- as stateless SwiftUI views that accept `ReportMetrics` as input. These components are assembled into the scrolling Reports screen in PH-11-E3.

## Problem / Context

Phase 11's primary deliverable is visual cycle intelligence: the Tracker sees average cycle and period lengths, a recent-cycle length chart, a consistency classification, and a symptom breakdown by cycle phase. None of these exist yet. PH-11-E1 produces the data; this epic produces the views that surface it.

Design Spec §15 flags "chart types, metric hierarchy, data thresholds" as a post-alpha open item requiring resolution before implementation begins. This epic treats the concrete chart type proposals below as **engineering assumptions that must be confirmed by Dinesh before S2 and S4 are coded**. S1, S3, and S5 have no chart-type dependency and may proceed immediately after PH-11-E1-S1.

Sources: MVP Spec §10 (5 report card types); Design Spec v1.1 §13 (loading state: skeleton placeholders, not full-screen spinners); cadence-data-layer skill (SymptomType enum cases); cadence-design-system skill (token set); cadence-accessibility skill (44pt targets, Dynamic Type, WCAG AA); cadence-motion skill (skeleton shimmer spec).

## Scope

### In Scope

- `CycleStatCard` -- reusable card component for average cycle length and average period length; accepts `value: Int`, `unit: String`, `label: String`, `cyclesUsed: Int`
- `RecentCyclesChart` -- `Chart` view using `BarMark` with cycle start date on x-axis and cycle length in days on y-axis; reference line at average cycle length; last 6 cycles from `ReportMetrics.recentCycles`
- `CycleConsistencyCard` -- card displaying `CycleConsistency` classification (Regular / Irregular) with standard deviation in days as secondary text; no chart
- `SymptomFrequencyChart` -- `Chart` view using grouped `BarMark`; x-axis = `SymptomType` display name; color series = `CyclePhase`; y-axis = occurrence count; built from `ReportMetrics.symptomFrequency`
- `ReportsDisclaimerFooter` -- footnote label "Based on your logged history -- not medical advice." in `CadenceTextSecondary`, `caption1` type token; required on any view that renders predicted-date-adjacent data per the cadence-data-layer skill display requirement
- Skeleton placeholder states for each card and chart component (per Design Spec §13: "Skeleton placeholders on card content surfaces. Never full-screen spinners.")
- Reduced-motion gating on all skeleton shimmer animations (cadence-motion skill)
- All touch targets >= 44x44pt where applicable (cadence-accessibility skill)

### Out of Scope

- Screen-level composition and gate rendering (PH-11-E3)
- `ReportsViewModel` data fetching logic (PH-11-E1)
- NavigationStack integration or tab bar chrome (PH-11-E3)
- Tapping a chart bar to drill into a specific cycle or day (not specified in source documents; do not add)
- Export or share sheet for reports (MVP Spec Out of Scope for Beta: "Export (PDF, CSV)")

## Dependencies

| Dependency                                                                                                                              | Type     | Phase/Epic                     | Status   | Risk |
| --------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------ | -------- | ---- |
| `ReportMetrics`, `CompletedCycleSummary`, `CyclePhase`, `CycleConsistency`, `SymptomPhaseCount` value types defined                     | FS       | PH-11-E1-S1                    | Open     | Low  |
| Design Spec §15 chart type open item resolved (required before S2 and S4 implementation)                                                | External | Dinesh / designer confirmation | Open     | High |
| Design Spec v1.1 color token set (CadenceTerracotta, CadenceSage, CadenceCard, CadenceTextPrimary, CadenceTextSecondary, CadenceBorder) | FS       | PH-0                           | Resolved | Low  |
| Skeleton shimmer animation spec (cadence-motion skill: 1.2s loop left-to-right, static opacity 0.4 under reduceMotion)                  | FS       | PH-0 (skills)                  | Resolved | Low  |

## Assumptions

- **Chart type for Recent Cycles overview (S2):** Vertical `BarMark` chart. X-axis: `CompletedCycleSummary.startDate` formatted as "MMM d" (e.g., "Jan 5"). Y-axis: `cycleLength` in days. A `RuleMark` at `averageCycleLengthDays` renders as a dashed reference line labeled "Avg". Bar fill: `Color("CadenceTerracotta")`. This is the standard representation for this data type in iOS health apps and requires no third-party library. **Requires Dinesh confirmation before S2 implementation.**
- **Chart type for Symptom Frequency by Cycle Phase (S4):** Grouped vertical `BarMark` chart. X-axis: `SymptomType.displayName` (e.g., "Cramps", "Fatigue"). Color series / `foregroundStyle(by:)`: `CyclePhase.displayName` (Menstrual, Follicular, Ovulatory, Luteal). Y-axis: occurrence count. Menstrual phase bars use `Color("CadenceTerracotta")`; Ovulatory uses `Color("CadenceSage")`; Follicular and Luteal use `Color("CadenceSageLight")` and `Color("CadenceBorder")` respectively, differentiated by both color and label (not color alone, per Design Spec §14 colorblind rule). **Requires Dinesh confirmation before S4 implementation.**
- `CycleStatCard` uses the standard Cadence card shape: `Color("CadenceCard")` background, 16pt corner radius, `CadenceSpacing.space16` horizontal padding, `CadenceSpacing.space12` vertical padding.
- Skeleton states are shown when `ReportsViewModel.isLoading == true`. Each card and chart has its own skeleton that matches its loaded layout (prevents layout shift on load completion).
- The `SymptomType.sex` symptom, if present in `symptomFrequency`, is displayed without the lock icon in Reports (the lock icon is specific to the Log Sheet's `SymptomChip` in the partner-sharing context). No special treatment in charts.

## Risks

| Risk                                                                                               | Likelihood | Impact | Mitigation                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| §15 chart type open item not resolved before sprint begins                                         | High       | High   | S1, S3, S5 (no chart dependency) may proceed immediately. S2 and S4 must wait. Flag to Dinesh at phase kickoff with a decision deadline.                                                     |
| Swift Charts `Chart` view with many `BarMark` entries causes layout overflow on small screen sizes | Medium     | Low    | Cap `SymptomFrequencyChart` to the top 7 symptom types by total count if `symptomFrequency.count > 7`; show "+" indicator if truncated. Document the cap in the view.                        |
| Grouped BarMark bars become too narrow to read at 4 phases x 10 symptoms                           | Medium     | Medium | Apply chart truncation above (top 7 symptoms). Use `.chartXAxis` label rotation of -45 degrees when label count > 5. Verify on iPhone SE simulator.                                          |
| Skeleton shimmer performance on older devices (A15 and below)                                      | Low        | Low    | Skeleton uses a simple linear gradient mask animated with `withAnimation(.linear(duration: 1.2).repeatForever())`; not GPU-intensive. Reduced motion gate eliminates the animation entirely. |

---

## Stories

### S1: `CycleStatCard` Component

**Story ID:** PH-11-E2-S1
**Points:** 2

Build `CycleStatCard` as a stateless SwiftUI view. Used twice in the Reports screen: once for average cycle length, once for average period length. Both instances share the same component with different input parameters.

Layout (top to bottom):

- `value` displayed as `"\(value) \(unit)"` in `title1` type token, `Color("CadenceTextPrimary")`
- `label` string in `subheadline` token, `Color("CadenceTextSecondary")`
- "Based on \(cyclesUsed) cycle\(cyclesUsed == 1 ? "" : "s")" in `caption1` token, `Color("CadenceTextSecondary")`
- `CadenceCard` background, `CadenceBorder` 1pt stroke, 16pt corner radius

**Acceptance Criteria:**

- [ ] `CycleStatCard` accepts `value: Int`, `unit: String`, `label: String`, `cyclesUsed: Int`
- [ ] `value` and `unit` render as a single string in `title1` type token using `Color("CadenceTextPrimary")` -- no hardcoded hex values
- [ ] `label` renders in `subheadline` token using `Color("CadenceTextSecondary")`
- [ ] "Based on N cycle(s)" string renders in `caption1` token using `Color("CadenceTextSecondary")`; pluralization is correct (cycle vs. cycles)
- [ ] Card background uses `Color("CadenceCard")` with a 1pt `Color("CadenceBorder")` stroke overlay and 16pt corner radius
- [ ] No hardcoded hex values in the view file (`no-hex-in-swift` hook exits 0)
- [ ] SwiftUI Preview defined with two instances: one for avg cycle length (value: 28, unit: "days", label: "Avg cycle length", cyclesUsed: 4) and one for avg period length (value: 5, unit: "days", label: "Avg period length", cyclesUsed: 4)
- [ ] Skeleton state: a `Color("CadenceBorder").opacity(0.4)` rounded rect replacing the value and label, animated with cadence-motion shimmer spec (1.2s loop; static opacity 0.4 under reduceMotion)

**Dependencies:** PH-11-E1-S1 (for `ReportMetrics` type shape, to confirm field names)
**Notes:** This component does not take `ReportMetrics` directly -- it takes primitive scalars. This keeps it reusable without coupling it to the reports domain.

---

### S2: `RecentCyclesChart` Component

**Story ID:** PH-11-E2-S2
**Points:** 5

Build `RecentCyclesChart` using the Swift Charts `Chart` view with `BarMark` and `RuleMark`. Renders the last 6 completed cycle lengths as vertical bars with a dashed average reference line.

**This story is BLOCKED pending §15 chart type confirmation from Dinesh. See Assumptions above.**

Chart structure:

- `Chart` containing one `BarMark` per `CompletedCycleSummary` in `recentCycles`
- `BarMark(x: .value("Cycle Start", summary.startDate, unit: .day), y: .value("Length", summary.cycleLength))`
- Bar fill: `Color("CadenceTerracotta")`, corner radius 4pt on top corners only (`.cornerRadius(4, style: .continuous)`)
- `RuleMark(y: .value("Average", averageCycleLengthDays))` styled as dashed line (`.lineStyle(StrokeStyle(dash: [4, 4]))`), `Color("CadenceTextSecondary")`; labeled "Avg \(averageCycleLengthDays)d" via `.annotation(position: .top, alignment: .trailing)`
- X-axis labels: date formatted as "MMM d" using `.chartXAxis` with `AxisValueLabel(format: .dateTime.month(.abbreviated).day())`
- Y-axis: integer day counts; `.chartYScale(domain: 0 ... (maxCycleLength + 5))` to prevent bars from reaching the chart top edge
- Chart height: 180pt fixed

**Acceptance Criteria:**

- [ ] `RecentCyclesChart` accepts `recentCycles: [CompletedCycleSummary]` and `averageCycleLengthDays: Int`
- [ ] `import Charts` is present; no third-party charting library is introduced
- [ ] Each `CompletedCycleSummary` in `recentCycles` renders as one `BarMark`; bar count matches `recentCycles.count`
- [ ] `RuleMark` renders at `averageCycleLengthDays` with dashed stroke and "Avg Nd" annotation
- [ ] Bar fill is `Color("CadenceTerracotta")`; no hardcoded hex
- [ ] X-axis labels show "MMM d" abbreviated date format
- [ ] When `recentCycles.isEmpty`, the chart shows a centered text label "No cycle data yet" in `caption1` token, `Color("CadenceTextSecondary")`
- [ ] Chart is contained within a `Color("CadenceCard")` card frame with 16pt corner radius matching `CycleStatCard`
- [ ] Skeleton state: a shimmer overlay matching the chart's fixed 180pt height using cadence-motion shimmer spec
- [ ] SwiftUI Preview defined with 4 sample `CompletedCycleSummary` entries; previews render without error in Xcode

**Dependencies:** PH-11-E1-S1, PH-11-E1-S4; §15 chart type confirmation (External)
**Notes:** `Chart` with `BarMark` using a `Date` x-axis requires that `startDate` values differ by at least one day. The `CompletedCycleSummary` data guaranteed by E1-S4 satisfies this -- each entry is a distinct completed period start date.

---

### S3: `CycleConsistencyCard` Component

**Story ID:** PH-11-E2-S3
**Points:** 3

Build `CycleConsistencyCard` as a text-based stat card. No chart. Displays the cycle regularity classification and its supporting standard deviation value.

Layout:

- Classification badge: "Regular" or "Irregular" in `headline` token; Regular = `Color("CadenceSage")` background pill; Irregular = `Color("CadenceTerracotta")` background pill; pill text in `Color("CadenceTextOnAccent")`; capsule corner radius
- SD value: "SD \(sd, specifier: "%.1f") days" in `subheadline` token, `Color("CadenceTextSecondary")`
- Explanatory copy: "Regular cycles vary by 2 days or less." or "Your cycles vary more than 2 days cycle-to-cycle." in `footnote` token, `Color("CadenceTextSecondary")`
- `CadenceCard` background, `CadenceBorder` stroke, 16pt corner radius

**Acceptance Criteria:**

- [ ] `CycleConsistencyCard` accepts `consistency: CycleConsistency` and `standardDeviationDays: Double`
- [ ] `.regular` renders badge with `Color("CadenceSage")` background; `.irregular` renders badge with `Color("CadenceTerracotta")` background; both use `Color("CadenceTextOnAccent")` text
- [ ] Badge shape uses `.capsule()` clip shape
- [ ] SD value renders as "SD 1.4 days" (1 decimal place) in `subheadline` token, `Color("CadenceTextSecondary")`
- [ ] Explanatory string is distinct for `.regular` and `.irregular`
- [ ] No hardcoded hex values; `no-hex-in-swift` hook exits 0
- [ ] Card background, stroke, and corner radius match `CycleStatCard` spec
- [ ] Skeleton state: shimmer on badge and SD text areas matching cadence-motion spec
- [ ] `accessibilityLabel` on the badge: "Cycle consistency: Regular" or "Cycle consistency: Irregular"
- [ ] SwiftUI Preview shows both `.regular` (SD: 1.2) and `.irregular` (SD: 4.5) states

**Dependencies:** PH-11-E1-S1, PH-11-E1-S5
**Notes:** The 2.0-day threshold is surfaced implicitly through the explanatory copy ("2 days or less"). Do not expose the raw threshold number to the user in a confusing way -- the badge and explanatory text are the full communication.

---

### S4: `SymptomFrequencyChart` Component

**Story ID:** PH-11-E2-S4
**Points:** 5

Build `SymptomFrequencyChart` using Swift Charts grouped `BarMark` with `foregroundStyle(by:)` for cycle phase color coding. Symptom types on x-axis, occurrence count on y-axis, cycle phase as color series.

**This story is BLOCKED pending §15 chart type confirmation from Dinesh. See Assumptions above.**

Chart structure:

- `Chart(symptomFrequency, id: \.id)` with `BarMark(x: .value("Symptom", entry.symptomType.displayName), y: .value("Count", entry.count))` and `.foregroundStyle(by: .value("Phase", entry.phase.displayName))`
- `.chartForegroundStyleScale([CyclePhase.menstrual.displayName: Color("CadenceTerracotta"), CyclePhase.ovulatory.displayName: Color("CadenceSage"), CyclePhase.follicular.displayName: Color("CadenceSageLight"), CyclePhase.luteal.displayName: Color("CadenceBorder")])`
- Truncation: if `uniqueSymptomTypes.count > 7`, display top 7 by total occurrence count; append an annotation "Showing top 7 symptoms" in `caption1`, `Color("CadenceTextSecondary")`
- X-axis: `.chartXAxis { AxisMarks(values: .automatic) { AxisValueLabel(centered: true, collisionResolution: .truncate(percentage: 0.7)) } }` to prevent label overlap
- Y-axis: integer counts only; `.chartYAxis { AxisMarks(values: .stride(by: 1)) { AxisValueLabel() } }`
- Chart height: 200pt fixed
- `.chartLegend(position: .bottom, spacing: 8)` for phase color legend

**Acceptance Criteria:**

- [ ] `SymptomFrequencyChart` accepts `symptomFrequency: [SymptomPhaseCount]`
- [ ] `import Charts` is present; no third-party charting library
- [ ] Each `SymptomPhaseCount` entry renders as one bar within the grouped chart; bars for the same `symptomType` are grouped
- [ ] Phase colors applied via `.chartForegroundStyleScale`: Menstrual = `Color("CadenceTerracotta")`, Ovulatory = `Color("CadenceSage")`, Follicular = `Color("CadenceSageLight")`, Luteal = `Color("CadenceBorder")` -- no hardcoded hex values
- [ ] Color is not the sole visual differentiator between phases: the chart legend displays phase name labels alongside color swatches (satisfies Design Spec §14 colorblind requirement)
- [ ] When `symptomFrequency.isEmpty`, chart shows "No symptoms logged yet" centered in `caption1`, `Color("CadenceTextSecondary")`
- [ ] Top-7 truncation applies when unique symptom types exceed 7; "Showing top 7 symptoms" annotation is present
- [ ] Chart is contained within `CadenceCard` background, 16pt corner radius
- [ ] Skeleton state: shimmer overlay matching 200pt fixed chart height
- [ ] SwiftUI Preview: defined with at least 3 symptom types across 2 cycle phases

**Dependencies:** PH-11-E1-S1, PH-11-E1-S6; §15 chart type confirmation (External)
**Notes:** `SymptomPhaseCount` needs a stable `id` property for the `Chart` initializer. Add `var id: String { "\(symptomType.rawValue)-\(phase.rawValue)" }` to the struct in PH-11-E1-S1 if not already present. `SymptomType.displayName` computed property (e.g., `.cramps` -> "Cramps", `.moodChange` -> "Mood") must be added to the `SymptomType` enum -- scope this addition to PH-11-E2-S4.

---

### S5: `ReportsDisclaimerFooter` Component

**Story ID:** PH-11-E2-S5
**Points:** 1

Build the single-line disclaimer label required on all reports content per the cadence-data-layer skill display requirement: "Based on your logged history -- not medical advice."

**Acceptance Criteria:**

- [ ] `ReportsDisclaimerFooter` is a stateless SwiftUI `View` with no parameters
- [ ] Text: "Based on your logged history -- not medical advice." (ASCII hyphens, not em dashes)
- [ ] Type token: `caption1`; color: `Color("CadenceTextSecondary")`; alignment: `.center`
- [ ] `accessibilityLabel`: "Disclaimer: Based on your logged history, not medical advice."
- [ ] No hardcoded hex values
- [ ] SwiftUI Preview renders correctly at three Dynamic Type sizes: Default, Large, Accessibility1

**Dependencies:** None (can be implemented without E1 or other E2 stories)
**Notes:** This component appears once at the bottom of the scrolling Reports content stack in PH-11-E3-S4. The disclaimer text uses ASCII double hyphen (`--`) as specified by `check-em-dashes.sh` enforcement rules.

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

- [ ] All stories in this epic are complete and merged (including §15 chart type confirmation received and applied)
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration verified: all 5 components render correctly when populated with `MockReportsViewModel` data in SwiftUI Previews
- [ ] Phase objective is advanced: all five report display surfaces are individually demonstrable without the full screen assembly
- [ ] Applicable skill constraints satisfied: cadence-design-system (all color tokens from xcassets, no hardcoded hex), cadence-accessibility (44pt targets where applicable, `accessibilityLabel` on badges, Dynamic Type on all text, colorblind-safe differentiation), cadence-motion (skeleton shimmer 1.2s loop, reduceMotion gate on shimmer), swiftui-production (no AnyView, view extraction beyond 50 lines, stable ForEach identity)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] `no-hex-in-swift` hook exits 0 on all files in this epic
- [ ] Accessibility: VoiceOver reads all chart values meaningfully (Swift Charts provides default accessibilityLabel on chart marks; verify on device)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §10 card types or Design Spec §13 loading state spec

## Source References

- PHASES.md: Phase 11 -- Reports (in-scope: chart components for each metric, metric card types)
- MVP Spec §10: History and Reports (5 report card types: avg cycle length, avg period length, recent cycles overview, cycle consistency, symptom frequency by cycle phase)
- Design Spec v1.1 §13: States & Feedback (loading = skeleton on card surfaces, never full-screen spinner)
- Design Spec v1.1 §14: Accessibility (colorblind differentiation rule: terracotta and sage never sole visual differentiators; Dynamic Type; 44pt targets)
- Design Spec v1.1 §15: Open Items (Reports screen specification -- chart types require confirmation before S2, S4 implementation)
- cadence-design-system skill (CadenceTerracotta, CadenceSage, CadenceSageLight, CadenceCard, CadenceTextPrimary, CadenceTextSecondary, CadenceTextOnAccent, CadenceBorder; full type scale and spacing tokens)
- cadence-motion skill (skeleton shimmer: 1.2s linear loop; reduceMotion gate: static opacity 0.4)
- cadence-accessibility skill (44pt touch targets, accessibilityLabel patterns, Dynamic Type enforcement)
- cadence-data-layer skill §2 (SymptomType enum cases; display requirement for prediction disclaimer)
