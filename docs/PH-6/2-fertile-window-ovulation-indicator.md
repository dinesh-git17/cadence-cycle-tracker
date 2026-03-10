# Fertile Window Band & Ovulation Day Indicator

**Epic ID:** PH-6-E2
**Phase:** 6 -- Calendar View
**Estimated Size:** M
**Status:** Draft

---

## Objective

Render the continuous `CadenceSageLight` fertile window band behind date cells and the `CadenceSageLight`-fill ovulation day indicator, reading fertile window and ovulation dates from `prediction_snapshots` via `CalendarViewModel`. Both indicators must compose correctly with the period state cells from Epic 1 and degrade cleanly when no prediction snapshot exists.

## Problem / Context

The fertile window and ovulation indicators are architecturally distinct from the period day states in Epic 1. Period states are cell-level properties (each date cell has one state). The fertile window is a continuous horizontal band that runs behind the date cells across one or more calendar rows -- it is not a per-cell background. This distinction requires a layered ZStack rendering approach: the band is drawn first (behind), then the date cell grid is overlaid on top.

The fertile window band must span full calendar row height and be continuous (no per-cell segmentation visible to the user). If the fertile window spans six days across two calendar rows (e.g., Thursday of one week through Tuesday of the next), the band must visually break at the end of the first row and resume at the start of the second. The band is not a single rectangle behind the whole grid -- it is one band segment per affected calendar row.

The ovulation day indicator is a cell-level overlay that composes with the fertile window band: the ovulation day always falls within the fertile window, so its `CadenceSageLight` fill sits on top of the band's `CadenceSageLight` layer (effectively invisible as a fill difference), and its `1pt CadenceSage` border distinguishes it.

`prediction_snapshots.fertile_window_start` and `fertile_window_end` are already computed by the Phase 3 prediction engine. This epic does not recompute them -- it reads and renders them.

**Source references that define scope:**

- Design Spec v1.1 §12.4 (fertile window: "Continuous CadenceSageLight band behind date cells - fills full calendar row height"; ovulation: "CadenceSageLight fill with 1pt CadenceSage border")
- Design Spec v1.1 §3 (CadenceSageLight: `#EAF0EA` light / `#1E2B1E` dark; CadenceSage: `#7A9B7A` light / `#8FB08F` dark)
- PHASES.md Phase 6 in-scope: "fertile window highlight band (continuous CadenceSageLight behind date cells, full row height); ovulation day (CadenceSageLight fill, 1pt CadenceSage border)"
- cadence-design-system skill (CadenceSage, CadenceSageLight token rules)
- cadence-data-layer skill (prediction_snapshots schema, fertile window computation rules)

## Scope

### In Scope

- `Cadence/Views/Tracker/Calendar/FertileWindowBandView.swift`: extracted subview that renders the band for a given set of date ranges; accepts `fertileWindowDates: Set<Date>` and `calendarLayout: CalendarLayoutInfo` (column/row position map) as parameters; renders one `RoundedRectangle` or `Rectangle` band segment per calendar row that contains at least one fertile window date; band fills full row height
- `CalendarLayoutInfo` struct: `Cadence/Models/CalendarLayoutInfo.swift`; maps `Date` to `(row: Int, column: Int)` for the current display month; computed by `CalendarGridView` and passed to `FertileWindowBandView` -- not recomputed independently
- `CalendarViewModel` extension: exposes `fertileWindowDates: Set<Date>` (all dates from `fertile_window_start` through `fertile_window_end` inclusive) and `ovulationDate: Date?` derived from the latest `prediction_snapshots` row
- Band layer in `CalendarGridView`: `ZStack(alignment: .top)` with `FertileWindowBandView` as the bottom layer and `LazyVGrid` date cells as the top layer
- Band segment geometry: each segment spans from the left edge of the first fertile date's column to the right edge of the last fertile date's column in that row, at full row height; segments on a full fertile row (columns 0-6) span the full grid width
- Ovulation day rendering in `CalendarDayCell`: when `state == .ovulation`, cell background is `RoundedRectangle(cornerRadius: 10).fill(Color("CadenceSageLight"))` with `RoundedRectangle(cornerRadius: 10).strokeBorder(Color("CadenceSage"), lineWidth: 1)` border overlay; date number in `.caption1`, `Color("CadenceTextPrimary")`
- Accessibility annotations for the fertile window region and ovulation day (see S4)
- Graceful degradation: when `prediction_snapshots` has no row for the current user, `fertileWindowDates` is empty, `ovulationDate` is nil, and no band or ovulation indicator renders; no error state, no placeholder card

### Out of Scope

- Any write interaction related to the fertile window (fertile window is read-only, derived from predictions)
- Fertile window sharing with the Partner (Phase 8 -- privacy architecture and permission model)
- Fertile window display on the Partner dashboard (Phase 9)
- Displaying the fertile window confidence badge on the calendar (confidence is shown on the Tracker Home dashboard in Phase 5, not the Calendar in Phase 6)
- Multi-month band rendering (band is scoped to the current display month only, as established by Phase 6's single-month scope)

## Dependencies

| Dependency                                                                                                                                         | Type | Phase/Epic | Status | Risk                                                                                                                                            |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| PH-6-E1 complete -- `CalendarGridView` with `LazyVGrid` exists and `CalendarViewModel` is initialized                                              | FS   | PH-6-E1    | Open   | High -- `FertileWindowBandView` is a layer inside `CalendarGridView`; the grid structure must exist before the band can be positioned within it |
| Phase 3 complete -- `prediction_snapshots` SwiftData model exists with `fertile_window_start`, `fertile_window_end`, `predicted_ovulation` columns | FS   | PH-3       | Open   | High -- band rendering reads these fields directly; schema must exist                                                                           |
| Color assets `CadenceSageLight` and `CadenceSage` exist in `Colors.xcassets`                                                                       | FS   | PH-0-E2    | Open   | Low -- resolved in Phase 0                                                                                                                      |

## Assumptions

- The fertile window never spans more than 7 consecutive days (ovulation day + 5 preceding days per the prediction engine rules in cadence-data-layer skill). Maximum two-row band span for any calendar display.
- `predicted_ovulation` always falls within `fertile_window_start`...`fertile_window_end` (this is a prediction engine invariant from Phase 3 -- Phase 6 trusts it and does not re-validate).
- When `ovulationDate` falls on a day that is also a logged period day (`.loggedPeriod` DayState), the period fill takes visual precedence over the ovulation cell fill. The `DayState` priority from Epic 1 (`.loggedPeriod > .ovulation`) governs cell rendering.
- Band height equals cell row height. Since `GridItem(.flexible())` produces equal-height rows, the band height is inferred from the grid's row height at layout time, not hardcoded.
- `CalendarLayoutInfo` is a value type (struct) passed downward through the view hierarchy. It is not an observable -- it is recomputed when `displayMonth` changes and passed explicitly.

## Risks

| Risk                                                                                                      | Likelihood | Impact | Mitigation                                                                                                                                                                                                |
| --------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Band positioning is wrong when fertile window starts on a non-Sunday column                               | Medium     | High   | Unit-test `CalendarLayoutInfo` computation with fertile window ranges starting on each day of week; verify band start x-offset matches expected column position in the simulator                          |
| ZStack layering fails -- band renders on top of date text                                                 | Medium     | High   | Verify ZStack child order: `FertileWindowBandView` must be the first child (bottom layer); date cell `LazyVGrid` must be the second child (top layer); do not wrap the ZStack in a reverse-order modifier |
| Ovulation cell border not visible when overlaid on fertile window band (same CadenceSageLight background) | Low        | Medium | The 1pt `CadenceSage` border is the differentiator, not the fill; verify border is rendered via `strokeBorder` overlay and is visible in both light and dark mode in the simulator                        |
| Full-row band segments have a visible gap between cells                                                   | Low        | Low    | Band segment is a continuous `Rectangle` or `RoundedRectangle` spanning the full column range -- it does not segment per cell; verify no horizontal gaps at cell boundaries                               |

---

## Stories

### S1: Fertile Window Date Range Computation in CalendarViewModel

**Story ID:** PH-6-E2-S1
**Points:** 3

Extend `CalendarViewModel` to expose `fertileWindowDates: Set<Date>` and `ovulationDate: Date?` derived from the latest `prediction_snapshots` row. These properties power both the band positioning in `FertileWindowBandView` and the ovulation cell state in `CalendarDayCell`.

**Acceptance Criteria:**

- [ ] `CalendarViewModel` exposes `fertileWindowDates: Set<Date>` containing every date from `fertile_window_start` through `fertile_window_end` inclusive, computed by iterating via `Calendar.current.date(byAdding: .day, value: i, to: fertile_window_start)`
- [ ] `CalendarViewModel` exposes `ovulationDate: Date?` set to `predicted_ovulation` from the latest snapshot, or `nil` if no snapshot exists
- [ ] When no `prediction_snapshots` row exists for the current user, `fertileWindowDates` is an empty `Set<Date>` and `ovulationDate` is `nil` -- no crash, no error thrown
- [ ] `DayState` computation in `CalendarViewModel` correctly assigns `.ovulation` to the date matching `ovulationDate` (when that date is not also a `.loggedPeriod` day, per priority rules from S1 of Epic 1)
- [ ] Both properties update when `displayMonth` changes (recomputed from the same snapshot fetch)

**Dependencies:** PH-6-E1-S1 (CalendarViewModel already exists; this story extends it)

---

### S2: CalendarLayoutInfo Struct & Row/Column Position Map

**Story ID:** PH-6-E2-S2
**Points:** 3

`CalendarLayoutInfo` maps every date in the display month to its `(row: Int, column: Int)` position in the 7-column grid. This is the geometric bridge between the date domain and the pixel-level band positioning. Without it, `FertileWindowBandView` cannot know where to draw each band segment.

**Acceptance Criteria:**

- [ ] `CalendarLayoutInfo.swift` exists at `Cadence/Models/CalendarLayoutInfo.swift`; is a `struct` (value type); is not `@Observable`
- [ ] `positions: [Date: (row: Int, column: Int)]` dictionary maps each date in the display month to its grid position; row 0 is the first week row; column 0 is Sunday (or Monday if `Calendar.current.firstWeekday == 2`)
- [ ] `rowCount: Int` exposes the total number of week rows needed to display the month (4, 5, or 6)
- [ ] `CalendarLayoutInfo` is initialized with `displayMonth: Date` and uses the same offset computation as `CalendarGridView` (locale-aware `firstWeekday`) to ensure position maps are consistent with what the grid renders
- [ ] `CalendarGridView` computes a `CalendarLayoutInfo` value and passes it to `FertileWindowBandView` as a parameter -- no re-computation inside `FertileWindowBandView`

**Dependencies:** PH-6-E2-S1
**Notes:** `CalendarLayoutInfo` is a struct, not an @Observable class. It is computed once per display month and passed as a value. Using a class here would create unnecessary reference-type complexity for a pure coordinate map.

---

### S3: FertileWindowBandView -- Continuous Band Rendering

**Story ID:** PH-6-E2-S3
**Points:** 8

`FertileWindowBandView` renders the continuous `CadenceSageLight` band behind date cells. It groups fertile window dates by calendar row, then for each affected row renders a band segment spanning the correct column range at full row height. The band is composited below the date cell `LazyVGrid` via ZStack ordering in `CalendarGridView`.

**Acceptance Criteria:**

- [ ] `FertileWindowBandView.swift` exists at `Cadence/Views/Tracker/Calendar/FertileWindowBandView.swift`; accepts `fertileWindowDates: Set<Date>`, `calendarLayout: CalendarLayoutInfo`, `cellSize: CGSize` (propagated from `GeometryReader` at the grid level, not individual cells) parameters
- [ ] For each row in `calendarLayout` that contains at least one date in `fertileWindowDates`, a band segment is rendered: a `Color("CadenceSageLight")` `Rectangle` at `x = cellSize.width * firstFertileColumn`, `y = cellSize.height * row`, `width = cellSize.width * (lastFertileColumn - firstFertileColumn + 1)`, `height = cellSize.height`
- [ ] When the fertile window spans two rows, two separate band segments are rendered -- one per row; they are not connected across the row break
- [ ] When the fertile window occupies all 7 columns of a row, the band segment spans full grid width (no gaps at row edges)
- [ ] Band segments use `Color("CadenceSageLight")` fill with no border and no corner radius (the band is a full-height rectangle, not a rounded surface)
- [ ] `CalendarGridView` wraps `FertileWindowBandView` and the `LazyVGrid` in a `ZStack(alignment: .topLeading)` with `FertileWindowBandView` as the bottom layer
- [ ] `GeometryReader` is scoped to the calendar grid container level only -- not placed inside individual day cells (swiftui-production skill §GeometryReader restraint)
- [ ] When `fertileWindowDates` is empty, `FertileWindowBandView` renders nothing (no `Color.clear` placeholder, no zero-size frame)

**Dependencies:** PH-6-E2-S2

---

### S4: Ovulation Day Cell Rendering & Accessibility

**Story ID:** PH-6-E2-S4
**Points:** 2

`CalendarDayCell` renders the `.ovulation` state: `CadenceSageLight` fill with `1pt CadenceSage` border. Both the fertile window region and the ovulation day are annotated for VoiceOver.

**Acceptance Criteria:**

- [ ] When `state == .ovulation`: `CalendarDayCell` renders `RoundedRectangle(cornerRadius: 10).fill(Color("CadenceSageLight"))` as the cell background and `RoundedRectangle(cornerRadius: 10).strokeBorder(Color("CadenceSage"), lineWidth: 1)` as the border overlay; date number in `.caption1`, `Color("CadenceTextPrimary")`
- [ ] Ovulation day cell with `isToday == true`: same ovulation visual with semibold date weight (today indicator additive, consistent with Epic 1 S5 behavior)
- [ ] `FertileWindowBandView` has an `.accessibilityElement(children: .ignore)` modifier with `.accessibilityLabel("Fertile window, \(formattedStart) through \(formattedEnd)")` using `DateFormatter` with `.medium` date style for human-readable dates
- [ ] Ovulation day cell has `.accessibilityLabel("Estimated ovulation day, \(formattedDate)")` via `CalendarDayCell`'s `accessibilityLabel` modifier when `state == .ovulation`
- [ ] `FertileWindowBandView` renders without animation on initial appear (no shimmer, no fade-in -- band is a static layout element); reduced motion has no additional effect because there is no animation to gate

**Dependencies:** PH-6-E2-S3

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
- [ ] Integration with PH-6-E1 verified: band and date cells render correctly together in the ZStack; no cell content is obscured by the band
- [ ] Integration with Phase 3 prediction_snapshots verified: real fertile window and ovulation dates from the prediction engine are rendered, not test fixtures
- [ ] Phase objective is advanced: a Tracker with prediction data can see the fertile window band and ovulation day on the calendar
- [ ] Applicable skill constraints satisfied: cadence-design-system (CadenceSage, CadenceSageLight token usage, no hardcoded hex), swiftui-production (GeometryReader scoped to grid container, not per-cell), cadence-accessibility (accessibility labels on fertile window and ovulation elements)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] Fertile window band verified in dark mode: `CadenceSageLight` dark variant (`#1E2B1E`) renders correctly against `CadenceBackground` dark (`#1C1410`)
- [ ] Band renders correctly for a fertile window that spans two calendar rows (most common real-world case)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Design Spec v1.1 §12.4 fertile window and ovulation specs are exactly matched

## Source References

- PHASES.md: Phase 6 -- Calendar View (in-scope: fertile window highlight band; ovulation day indicator)
- Design Spec v1.1 §12.4 (Calendar View -- fertile window and ovulation day visual specifications: "Continuous CadenceSageLight band behind date cells -- fills full calendar row height"; "CadenceSageLight fill with 1pt CadenceSage border")
- Design Spec v1.1 §3 (Color System -- CadenceSage light `#7A9B7A` / dark `#8FB08F`; CadenceSageLight light `#EAF0EA` / dark `#1E2B1E`)
- Design Spec v1.1 §14 (Accessibility -- VoiceOver labels on interactive elements)
- MVP Spec §8 (Fertility and Cycle Predictions -- fertile window = ovulation minus 5 days through ovulation day; ovulation = predicted next period minus 14 days)
- MVP Spec Data Model (prediction_snapshots: fertile_window_start, fertile_window_end, predicted_ovulation columns)
- cadence-data-layer skill (prediction engine fertile window computation rules and invariants)
