# Calendar Month Grid & Period Day State Rendering

**Epic ID:** PH-6-E1
**Phase:** 6 -- Calendar View
**Estimated Size:** L
**Status:** Draft

---

## Objective

Build `CalendarView.swift` into a functional month grid that reads `period_logs` and `prediction_snapshots` from local SwiftData and renders all period-related day states (logged, predicted, default, today) at 60fps. This is the structural foundation every other Phase 6 epic is composed on top of -- no day-tap, no fertile window band, and no edit path can exist before this grid renders correctly.

## Problem / Context

`CalendarView.swift` was scaffolded in Phase 4 as an empty structural entry point (`Text("Calendar").navigationTitle("Calendar")`). It is a phase gate, not a stub -- Phase 6 fills in its content without modifying the shell that contains it.

The month grid is the Calendar tab's primary data surface. It must read from the same `period_logs` and `prediction_snapshots` tables that the prediction engine (Phase 3) writes to. A custom SwiftUI `LazyVGrid` is required because neither `UICalendarView` nor any system SwiftUI calendar component exposes the per-cell rendering control needed to implement the dashed predicted-period border and the fertile window band behind-cell layer (Epic 2).

The 60fps scrolling requirement (PHASES.md Phase 6 in-scope, MVP Spec §NFR Performance) means all cell rendering must be lazy and all SwiftData fetches must happen off the main thread via async query. No synchronous `ModelContext.fetch()` in the view body.

The dashed border on predicted period days requires `StrokeStyle(lineWidth: 1, dash: [4, 4])` applied via `strokeBorder` on `RoundedRectangle(cornerRadius: 10)` -- not a solid fill. This is the primary visual differentiator between logged and predicted days and must be exact.

**Source references that define scope:**

- Design Spec v1.1 §12.4 (all Calendar View day states and their exact visual specs)
- PHASES.md Phase 6 in-scope: month grid layout; logged/predicted day cell rendering; today indicator (system default); 60fps target
- MVP Spec §5 (Calendar View components: month grid, logged period days, predicted period days, tap a date to view or edit)
- cadence-design-system skill (CadenceTerracotta, CadenceTextOnAccent, CadenceTextPrimary usage)
- swiftui-production skill (LazyVGrid for grids, @Observable for ViewModel, view extraction beyond 50 lines)

## Scope

### In Scope

- `Cadence/Views/Tracker/Calendar/CalendarViewModel.swift`: `@Observable` class; fetches `period_logs` filtered to the current display month date range via `ModelContext`; fetches the latest `prediction_snapshots` row for the current user; computes `[Date: DayState]` dictionary exposed as a published property; exposed `displayMonth: Date` property defaulting to `Date()` (current month)
- `Cadence/Models/DayState.swift`: `enum DayState { case loggedPeriod, predictedPeriod, ovulation, default }` -- `fertileWindow` is a band concern handled by `FertileWindowBand` in Epic 2, not a `DayState` case; `ovulation` is computed and stored here for use by Epic 2
- `Cadence/Views/Tracker/Calendar/CalendarGridView.swift`: extracted subview containing the `LazyVGrid` with 7 `GridItem(.flexible())` columns; receives `[Date: DayState]` and `displayMonth: Date` as parameters; no direct SwiftData dependency
- `Cadence/Views/Tracker/Calendar/CalendarDayCell.swift`: extracted subview; renders one day cell; switches on `DayState` to apply correct background, border, and text color; accepts `date: Date`, `state: DayState`, `isToday: Bool` parameters; minimum 44pt touch target enforced via `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`
- Day-of-week header row: `["S", "M", "T", "W", "T", "F", "S"]` in `caption2` style, `CadenceTextSecondary`, uppercase -- 7 columns matching grid alignment
- Month start offset: `Calendar.current.component(.weekday, from: firstOfMonth) - 1` empty leading cells to align first day to correct column
- Logged period day cell visual: `RoundedRectangle(cornerRadius: 10)` solid `Color("CadenceTerracotta")` fill; date number in `caption1`, `Color("CadenceTextOnAccent")`, semibold when state is `.loggedPeriod`
- Predicted period day cell visual: `RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))` in `Color("CadenceTerracotta")`; no fill; date number in `caption1`, `Color("CadenceTerracotta")`
- Today indicator: `isToday` flag set when `Calendar.current.isDateInToday(date)` is true; today cell renders date number in `.headline` weight regardless of DayState (bold today convention matching iOS Calendar.app); system-style indicator does not override period fill -- the fill is preserved and the bold weight is additive
- Default day cell: no background, no border; date number in `caption1`, `Color("CadenceTextPrimary")`
- 16pt horizontal safe-area inset on `CalendarView`'s scroll container
- `project.yml` updated with all new Swift file paths; `xcodegen generate` run after each file addition
- Build compiles clean with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

### Out of Scope

- Fertile window band and ovulation day rendering (Epic 2 -- requires separate ZStack layer below date cells)
- Day-tap gesture and day detail sheet (Epic 3 -- cell tap behavior)
- Log Sheet pre-population for historical dates (Epic 4 -- edit path)
- Multi-month navigation (PHASES.md Phase 6 out-of-scope: "Multi-month navigation beyond current month -- not specified in source docs")
- Month navigation controls (swipe or chevron to go to previous/next month -- not specified)
- Any write interaction from the calendar grid (write path is exclusively via Log Sheet in Epic 4)

## Dependencies

| Dependency                                                                                                                       | Type | Phase/Epic | Status | Risk                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---------------------------------------------------------------------------------------- |
| Phase 3 complete -- `period_logs` and `prediction_snapshots` SwiftData models exist and are written by the prediction engine     | FS   | PH-3       | Open   | High -- CalendarViewModel reads both tables; schema must exist before any fetch compiles |
| Phase 4 complete -- `CalendarView.swift` structural entry point exists in the Tracker nav shell                                  | FS   | PH-4-E1    | Open   | Low -- Phase 4 scaffolds the empty view; Phase 6 fills content into it                   |
| Color assets `CadenceTerracotta`, `CadenceTextOnAccent`, `CadenceTextPrimary`, `CadenceTextSecondary` exist in `Colors.xcassets` | FS   | PH-0-E2    | Open   | Low -- resolved in Phase 0                                                               |

## Assumptions

- `period_logs` in SwiftData contains `start_date: Date` and `end_date: Date?` per the MVP Spec data model. A day is a logged period day if `start_date <= day <= end_date` for any `period_log` row owned by the current user.
- `prediction_snapshots` contains `predicted_next_period: Date`, `fertile_window_start: Date`, `fertile_window_end: Date`, `predicted_ovulation: Date`. The latest snapshot row (by `date_generated`) is the authoritative prediction.
- A day can only hold one `DayState` value. Priority when a date matches multiple conditions: `.loggedPeriod` > `.predictedPeriod` > `.ovulation` > `.default`. Fertile window is a band, not a cell state, so it does not participate in this priority.
- The calendar always displays the current month (`Date()`). There is no month navigation control in Phase 6. `displayMonth` is read-only at launch.
- SwiftData is always available locally (offline-first). The fetch never fails due to network unavailability. Empty results are valid (zero `period_logs` = all cells in `.default` state).

## Risks

| Risk                                                                                         | Likelihood | Impact | Mitigation                                                                                                                                                                                       |
| -------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `LazyVGrid` date cell layout breaks at wide Dynamic Type sizes (cells overflow 44pt minimum) | Medium     | Medium | Set `GridItem(.flexible(), spacing: 4)` with `.frame(minWidth: 44, minHeight: 44)` on each cell; test at `xxxLarge` Dynamic Type in the simulator before marking S4 done                         |
| Month start offset computation is wrong for locales where week starts on Monday              | Low        | Medium | Use `Calendar.current.component(.weekday, from: firstOfMonth) - Calendar.current.firstWeekday` for locale-correct offset; verify against both Sunday-first and Monday-first locales in simulator |
| SwiftData fetch in view body triggers main-thread blocking                                   | Medium     | High   | Fetch in `CalendarViewModel` via `Task { await modelContext.fetch(...) }` on appear; never call `modelContext.fetch()` synchronously during view evaluation                                      |
| Dashed border on predicted day cell not visible at small cell size                           | Low        | Low    | Use `dash: [4, 4]` with `lineWidth: 1`; verify at default and reduced Dynamic Type sizes; the dash parameters may need tuning once rendered on device                                            |

---

## Stories

### S1: CalendarViewModel -- SwiftData Fetch & Day State Computation

**Story ID:** PH-6-E1-S1
**Points:** 5

`CalendarViewModel` is an `@Observable` class that fetches `period_logs` and the latest `prediction_snapshots` row from the local SwiftData `ModelContext`, then computes a `[Date: DayState]` dictionary for every date in the current display month. The dictionary is the single source of truth that `CalendarGridView` reads for cell rendering -- no raw SwiftData models cross the view boundary.

**Acceptance Criteria:**

- [ ] `CalendarViewModel.swift` is an `@Observable` class in `Cadence/Views/Tracker/Calendar/`
- [ ] `dayStates: [Date: DayState]` is a computed or stored property exposed by the ViewModel, containing an entry for every date in the current display month
- [ ] Logged period days are correctly identified: any date `d` where a `PeriodLog` row satisfies `start_date <= d && (end_date == nil || d <= end_date)` and `user_id == currentUser` maps to `.loggedPeriod`
- [ ] Predicted period days are correctly identified: `predicted_next_period` from the latest `prediction_snapshots` row maps to `.predictedPeriod`, and any date that falls within a predicted-but-not-yet-logged range is also marked (rule: dates from `predicted_next_period` through `predicted_next_period + average_period_length - 1` that have no logged period entry map to `.predictedPeriod`)
- [ ] Ovulation day is marked: `predicted_ovulation` from the latest snapshot maps to `.ovulation`
- [ ] When no `period_logs` exist, `dayStates` contains only `.default` and `.predictedPeriod`/`.ovulation` entries derived from `prediction_snapshots`; no crash or empty-state error
- [ ] Fetch is initiated in a `Task` on ViewModel init or on `displayMonth` change -- never on the SwiftUI main thread during view body evaluation
- [ ] `DayState.swift` enum file exists at `Cadence/Models/DayState.swift` with cases: `loggedPeriod`, `predictedPeriod`, `ovulation`, `default`

**Dependencies:** Phase 3 SwiftData models compiled and accessible
**Notes:** Priority resolution for overlapping states: `.loggedPeriod` takes precedence over `.predictedPeriod`. A logged day is never shown as predicted, even if the prediction engine incorrectly predicts it. This prevents user confusion when a period starts earlier than predicted.

---

### S2: Month Grid Layout

**Story ID:** PH-6-E1-S2
**Points:** 5

`CalendarGridView.swift` renders the 7-column month grid using `LazyVGrid`. It receives `[Date: DayState]` and `displayMonth: Date` from `CalendarViewModel`. It computes the ordered list of dates to render (including leading empty cells for the correct day-of-week offset) and maps each date to a `CalendarDayCell`. The view is fully parameterized -- no internal SwiftData access.

**Acceptance Criteria:**

- [ ] `CalendarGridView.swift` exists at `Cadence/Views/Tracker/Calendar/CalendarGridView.swift` and accepts `dayStates: [Date: DayState]`, `displayMonth: Date`, and `onDayTap: (Date) -> Void` (wired in Epic 3) parameters
- [ ] Grid uses `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4)`
- [ ] Day-of-week header row renders `["S", "M", "T", "W", "T", "F", "S"]` in `.caption2` style, `Color("CadenceTextSecondary")`, above the grid
- [ ] First calendar day is offset to the correct column using `Calendar.current.component(.weekday, from: firstDayOfMonth) - Calendar.current.firstWeekday` (locale-aware); leading empty cells are `Color.clear` non-interactive rectangles of the same frame size as day cells
- [ ] All dates in the display month are present in the grid in correct day-of-week column positions
- [ ] Trailing empty cells after the last day of the month fill the remaining cells in the final row (no ragged right edge)
- [ ] `CalendarView.swift` embeds `CalendarGridView` in a `ScrollView` with 16pt horizontal padding and `16pt` top/bottom padding

**Dependencies:** PH-6-E1-S1 (DayState enum must exist)
**Notes:** The `onDayTap` closure is wired here but noop until Epic 3 (S1) implements the gesture. Declaring it now prevents a structural rework of `CalendarGridView` when Epic 3 adds tap behavior.

---

### S3: Logged Period Day Cell Rendering

**Story ID:** PH-6-E1-S3
**Points:** 3

`CalendarDayCell.swift` renders a day cell in `.loggedPeriod` state: solid `CadenceTerracotta` fill, `CadenceTextOnAccent` date number, 10pt corner radius, 44pt minimum touch target.

**Acceptance Criteria:**

- [ ] `CalendarDayCell.swift` exists at `Cadence/Views/Tracker/Calendar/CalendarDayCell.swift`; accepts `date: Date`, `state: DayState`, `isToday: Bool`, `onTap: () -> Void` parameters
- [ ] When `state == .loggedPeriod`: `RoundedRectangle(cornerRadius: 10).fill(Color("CadenceTerracotta"))` is the cell background
- [ ] Date number text uses `.caption1` font style and `Color("CadenceTextOnAccent")` foreground
- [ ] Cell has `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(Rectangle())` for full-area tap targeting
- [ ] No hardcoded hex color values appear in `CalendarDayCell.swift` (enforced by `no-hex-in-swift` hook)

**Dependencies:** PH-6-E1-S2 (grid layout must exist before cells are placed into it)
**Notes:** `CalendarDayCell` handles all four day states via a switch -- this story implements the `.loggedPeriod` branch. S4 adds `.predictedPeriod`, S5 adds `.default` and today. The full switch must compile at the end of S5 with no unhandled cases.

---

### S4: Predicted Period Day Cell Rendering

**Story ID:** PH-6-E1-S4
**Points:** 3

`CalendarDayCell` renders the `.predictedPeriod` state: no fill, 1pt dashed `CadenceTerracotta` border, `CadenceTerracotta` date number, same corner radius and touch target as logged cells.

**Acceptance Criteria:**

- [ ] When `state == .predictedPeriod`: `RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]), antialiased: true)` in `Color("CadenceTerracotta")` is the cell border; no fill layer behind the text
- [ ] Date number text uses `.caption1` font style and `Color("CadenceTerracotta")` foreground
- [ ] Cell background behind the dashed border is transparent (allows fertile window band from Epic 2 to show through)
- [ ] At the default Dynamic Type size, the dashed border segments are visually distinguishable from a solid border (minimum segment length of 3pt visible on non-retina and retina displays)
- [ ] No hardcoded hex color values appear in `CalendarDayCell.swift`

**Dependencies:** PH-6-E1-S3

---

### S5: Default Day Cell & Today Indicator

**Story ID:** PH-6-E1-S5
**Points:** 2

`CalendarDayCell` renders the `.default` state (no period, not predicted) and overlays the today indicator on any cell where `isToday == true`. Today's bold-weight date number is additive -- it does not override the cell's `DayState` fill or border.

**Acceptance Criteria:**

- [ ] When `state == .default` and `isToday == false`: cell has no background and no border; date number uses `.caption1` style, `Color("CadenceTextPrimary")`
- [ ] When `isToday == true` regardless of `DayState`: date number font weight is `.semibold` (`.headline` scale); the period fill or border for the cell's `DayState` is preserved -- the bold weight is the only today-specific change
- [ ] When `state == .loggedPeriod` and `isToday == true`: solid terracotta fill is preserved; date number is `CadenceTextOnAccent`, semibold
- [ ] When `state == .predictedPeriod` and `isToday == true`: dashed border is preserved; date number is `CadenceTerracotta`, semibold
- [ ] `CalendarViewModel` sets `isToday: Calendar.current.isDateInToday(date)` for each cell

**Dependencies:** PH-6-E1-S4

---

### S6: 60fps Scrolling Performance Verification

**Story ID:** PH-6-E1-S6
**Points:** 3

The calendar grid must scroll at 60fps under normal usage conditions. This story verifies the implementation is lazy, measures frame time in Instruments, and fixes any eager rendering that causes frame drops.

**Acceptance Criteria:**

- [ ] `LazyVGrid` is used (not `VStack` + `HStack` or `Grid`) -- off-screen cells are not instantiated during scroll
- [ ] No `GeometryReader` wrapping individual day cells (GeometryReader defeats lazy rendering in LazyVGrid -- reference swiftui-production skill §GeometryReader restraint)
- [ ] Instruments Time Profiler shows no frame drops (>16ms) during programmatic scroll through a fully-populated month (all 28-31 cells in `.loggedPeriod` state) on iPhone 16 Pro simulator
- [ ] `CalendarViewModel` SwiftData fetch does not block the main thread during scroll (fetch is initiated once on appear, not on each cell render)
- [ ] Memory footprint does not grow unboundedly during repeated appear/disappear cycles of `CalendarView` (verified by checking for leaks in Instruments Allocations)

**Dependencies:** PH-6-E1-S5 (all day states must be implemented before performance profiling)

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
- [ ] Integration with Phase 3 SwiftData models verified -- `CalendarViewModel` reads real `period_logs` and `prediction_snapshots` data, not hardcoded test fixtures
- [ ] Integration with Phase 4 nav shell verified -- `CalendarView` mounts correctly within the Tracker `TabView` and its `NavigationStack`
- [ ] Phase objective is advanced: a Tracker can open the Calendar tab and see logged and predicted period days color-coded on a correctly laid-out month grid
- [ ] Applicable skill constraints satisfied: cadence-design-system (no hardcoded hex, all token references), swiftui-production (@Observable ViewModel, LazyVGrid, no AnyView, view extraction enforced), cadence-accessibility (44pt touch targets on all day cells)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] All interactive day cells meet 44pt minimum touch target requirement
- [ ] 60fps scroll performance verified in Instruments on iPhone 16 Pro simulator
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Design Spec v1.1 §12.4 day state specs are exactly matched; no drift

## Source References

- PHASES.md: Phase 6 -- Calendar View (in-scope: month grid layout, logged period days, predicted period days, today indicator, 60fps target)
- Design Spec v1.1 §12.4 (Calendar View -- all day state visual specifications)
- Design Spec v1.1 §5 (Spacing -- 16pt screen margin, intrinsic sizing rule)
- Design Spec v1.1 §6 (Corner Radii -- 10pt for calendar day cells)
- Design Spec v1.1 §3 (Color System -- CadenceTerracotta, CadenceTextOnAccent, CadenceTextPrimary, CadenceTextSecondary)
- MVP Spec §5 (Calendar View components)
- MVP Spec Data Model (period_logs schema: start_date, end_date; prediction_snapshots schema: predicted_next_period, predicted_ovulation, fertile_window_start, fertile_window_end)
