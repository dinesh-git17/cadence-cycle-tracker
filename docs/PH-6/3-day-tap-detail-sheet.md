# Day Tap & Day Detail Read-Sheet

**Epic ID:** PH-6-E3
**Phase:** 6 -- Calendar View
**Estimated Size:** M
**Status:** Draft

---

## Objective

Make every calendar day cell tappable and drive a `.medium` detent read-sheet that displays the existing log for the tapped date: period state, flow level, symptom chips in read-only mode, notes, and private flag. Days with no log show an empty state with a "Log this day" CTA. Days with an existing log show an "Edit entry" action that routes into the Log Sheet pre-population flow (Epic 4).

## Problem / Context

Without day-tap, the calendar is a read-only visualization with no interaction path. The Design Spec §12.4 explicitly specifies "Tapped day: Opens day detail read-sheet (bottom sheet, .medium detent)." The day detail sheet is the Calendar tab's only interactive surface -- it is both the read path and the routing entry point for the historical edit path in Epic 4.

The day detail sheet is a read-sheet, not an edit sheet. It uses the same `SymptomChip` component from Phase 4 but with `isReadOnly: true` -- no toggle interaction is possible. This is not a reduced Log Sheet; it is a distinct presentation of stored log data for a specific date.

The sheet presentation must be driven from `CalendarViewModel.selectedDate: Date?` via a `.sheet(item:)` modifier. When `selectedDate` is set, the sheet appears. When it is cleared (on dismiss), the calendar returns to its neutral state. This pattern isolates sheet lifecycle from the day cell component -- cells fire a tap callback and the ViewModel owns the presentation state.

The ".medium" detent is the only detent for day detail. The user cannot drag the sheet to `.large`. This differs from the Log Sheet (which has both `.medium` and `.large`). The spec calls this out explicitly as ".medium detent" for the day detail read-sheet.

**Source references that define scope:**

- Design Spec v1.1 §12.4 (Calendar View: "Tapped day: Opens day detail read-sheet (bottom sheet, .medium detent)")
- Design Spec v1.1 §10.1 (SymptomChip: `isReadOnly: Bool` parameter disables tap gesture)
- Design Spec v1.1 §13 (States: empty state copy, offline rendering from local SwiftData)
- PHASES.md Phase 6 in-scope: "day tap opens day detail read-sheet (.medium detent); day detail sheet: read log for that date with chip display"
- MVP Spec §5 (Calendar View: "Tap a date to view logs or edit entries")
- cadence-navigation skill (sheet presentation patterns, `.presentationDetents`, parent-coordinator-owned sheet state)
- swiftui-production skill (@Observable ViewModel state ownership, view extraction)

## Scope

### In Scope

- `CalendarViewModel` property: `selectedDate: Date?` (nil when no day is selected; set to the tapped date when a cell is tapped; cleared on sheet dismiss)
- `onDayTap` closure on `CalendarGridView` and `CalendarDayCell` wired to `CalendarViewModel.selectedDate = tappedDate` -- this closure was declared in Epic 1 S2 but was noop; this epic implements the body
- `.sheet(item: $selectedDate)` modifier on `CalendarView` (the `Date` must be made `Identifiable` via a wrapper or conform to `Identifiable` via an extension) presenting `DayDetailView`
- `Cadence/Views/Tracker/Calendar/DayDetailView.swift`: sheet content view; accepts `date: Date`, `log: DailyLog?`, `symptoms: [SymptomLog]` parameters; fetches nothing itself -- all data is passed from `CalendarViewModel` via the sheet presentation closure
- `CalendarViewModel` method: `fetchLog(for date: Date) -> (DailyLog?, [SymptomLog])` -- executed when `selectedDate` is set; fetches `DailyLog` by exact date match and associated `SymptomLog` rows; result bound to `selectedDayLog` and `selectedDaySymptoms` properties
- Day detail content layout (when log exists):
  - Date header: `Text(date, style: .date)` in `.title2` style, `CadenceTextPrimary`
  - Period state: if any `period_log` spans this date, display "Period day" in `.subheadline`, `CadenceTerracotta`; if `flow_level` is non-nil on the `daily_log`, display the flow level chip via `SymptomChip(label: flowLevel.displayName, isSelected: true, isReadOnly: true)`
  - Symptom chips: `SymptomChip` instances for each `SymptomLog` row with `isSelected: true, isReadOnly: true`, rendered in a wrapped horizontal layout using `FlowLayout` or equivalent
  - Notes: if `daily_log.notes` is non-nil and non-empty, display in `.body`, `CadenceTextPrimary`; if nil or empty, display "No notes" in `.footnote`, `CadenceTextSecondary`
  - Private flag: if `daily_log.is_private == true`, display "This entry is marked private" in `.footnote`, `CadenceTextSecondary` with `lock.fill` SF Symbol at 11pt
  - "Edit entry" action: `.footnote` text link in `CadenceTerracotta`, bottom of sheet; tapping sets `CalendarViewModel.pendingEditDate = date` and dismisses the detail sheet (Epic 4 observes `pendingEditDate` to open the Log Sheet)
- Day detail content layout (when no log exists for the tapped date):
  - Date header: same formatting as above
  - "Nothing logged for this day." in `.body`, `CadenceTextSecondary`, centered
  - "Log this day" Primary CTA Button in `CadenceTerracotta` if the date is not in the future; sets `CalendarViewModel.pendingEditDate = date` and dismisses the detail sheet
  - If date is in the future (after `Date()`): "Nothing logged yet." in `.body`, `CadenceTextSecondary`; no Log CTA
- `.presentationDetents([.medium])` on the sheet -- no `.large` option for day detail
- `.presentationDragIndicator(.visible)` on the sheet

### Out of Scope

- Log Sheet pre-population and upsert save path (Epic 4 -- day detail sheet only routes to the Log Sheet; it does not implement the Log Sheet itself)
- Day detail for future predicted period days (tap gesture fires for all dates including future dates; future dates show the "Nothing logged yet" empty state with no Log CTA -- the distinction is handled in the empty state branch)
- Editing the date header from within the day detail sheet (dates are immutable once selected)
- Notes editing from within the day detail sheet (day detail is read-only; edit path goes through the Log Sheet via Epic 4)

## Dependencies

| Dependency                                                                                                                   | Type | Phase/Epic | Status | Risk                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PH-6-E1 complete -- `CalendarDayCell` exists with `onTap` closure and `CalendarViewModel` is initialized with `selectedDate` | FS   | PH-6-E1    | Open   | High -- tap gesture and ViewModel state must exist before this epic can wire them                                                                                                       |
| PH-6-E2 complete -- full calendar visual is in place before day-tap ships                                                    | FS   | PH-6-E2    | Open   | Medium -- day-tap can be implemented in parallel with E2 but should not ship until the calendar renders correctly; partial calendar (no fertile window) risks confusing QA verification |
| Phase 4 complete -- `SymptomChip` component with `isReadOnly: Bool` parameter exists                                         | FS   | PH-4-E3    | Open   | High -- day detail sheet reuses `SymptomChip(isReadOnly: true)`; Phase 4 must have implemented the read-only mode                                                                       |
| Phase 3 complete -- `DailyLog` and `SymptomLog` SwiftData models exist                                                       | FS   | PH-3       | Open   | High -- `DayDetailView` displays data from these models; schema must match what is fetched                                                                                              |

## Assumptions

- `Date` is made `Identifiable` for `.sheet(item: $selectedDate)` via `extension Date: Identifiable { public var id: TimeInterval { self.timeIntervalSince1970 } }` in a project-level extension file. If this extension already exists from another phase, do not re-declare it.
- "Future date" is determined by comparing `Calendar.current.startOfDay(for: tappedDate)` to `Calendar.current.startOfDay(for: Date())`. Today is not a future date (Log CTA is shown for today and all past dates).
- `DayDetailView` does not fetch data itself. `CalendarViewModel` fetches when `selectedDate` is set and passes data into the sheet presentation closure. This keeps `DayDetailView` a pure presentation component with no `@Environment(\.modelContext)` dependency.
- The `SymptomChip` component's `isReadOnly: true` mode disables the tap gesture on the chip entirely. The chip renders as selected (terracotta fill) but does not respond to touch. This behavior is already implemented in Phase 4 -- Phase 6 relies on it without modification.

## Risks

| Risk                                                                                               | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                                                                                           |
| -------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.sheet(item: $selectedDate)` re-presents incorrectly when same date is tapped twice               | Low        | Medium | `Date` identity via `timeIntervalSince1970` is stable; tapping the same date while the sheet is already open does not dismiss and re-present if `selectedDate` is already set to that date; verify behavior in simulator                                                                                                             |
| Symptom chips wrap incorrectly in read-only layout at narrow sheet width                           | Medium     | Low    | Use a wrapped `HStack` via `LazyVGrid` with `.flexible()` columns or a custom `FlowLayout` implementation; verify chip wrapping at default sheet width (.medium detent on iPhone 15 Pro)                                                                                                                                             |
| `CalendarViewModel.fetchLog` executes on the main thread blocking the sheet presentation animation | Low        | Medium | Wrap fetch in `Task { @MainActor in ... }` inside the `onChange(of: selectedDate)` handler; result sets `selectedDayLog` and `selectedDaySymptoms` which triggers sheet presentation with populated data                                                                                                                             |
| Day detail sheet presents empty before log data is fetched                                         | Low        | Medium | Present sheet after `fetchLog` completes, not on `selectedDate` being set. Use a two-step: `selectedDate` triggers fetch; fetch completion sets `readyToPresent: Bool` which drives the sheet. Alternatively, show a `ProgressView` skeleton in `DayDetailView` until data arrives (consistent with Design Spec §13 loading states). |

---

## Stories

### S1: Day Cell Tap Gesture Wiring

**Story ID:** PH-6-E3-S1
**Points:** 2

Wire the `onDayTap` closure in `CalendarDayCell` and `CalendarGridView` to `CalendarViewModel.selectedDate`. When a cell is tapped, `selectedDate` is set to the tapped date, which drives sheet presentation in the next story.

**Acceptance Criteria:**

- [ ] `CalendarDayCell` calls `onTap()` via `.onTapGesture` on the cell's root view; `.onTapGesture` is applied to the full `.frame(minWidth: 44, minHeight: 44)` area (not just the text or filled rectangle)
- [ ] `.contentShape(Rectangle())` is applied to the cell root view to ensure the full 44pt frame is the tap target, not just the visible fill
- [ ] `CalendarGridView.onDayTap` closure is called with the correct `Date` value (midnight of the tapped day, normalized via `Calendar.current.startOfDay(for:)`)
- [ ] `CalendarViewModel.selectedDate` is set to the tapped date value after the tap
- [ ] Leading empty cells (day-of-week offset cells) do not have a tap gesture
- [ ] Tap does not trigger navigation -- it only sets `selectedDate`; no `NavigationStack` push occurs

**Dependencies:** PH-6-E1-S2 (CalendarGridView with onDayTap closure parameter must exist)

---

### S2: Day Detail Sheet Presentation

**Story ID:** PH-6-E3-S2
**Points:** 3

`.sheet(item: $selectedDate)` on `CalendarView` presents `DayDetailView`. Sheet configuration: `.medium` detent only, visible drag indicator. Dismissal clears `selectedDate`.

**Acceptance Criteria:**

- [ ] `CalendarView` has `.sheet(item: Binding<Date?>)` modifier presenting `DayDetailView`; the binding is `$calendarViewModel.selectedDate`
- [ ] `Date` conforms to `Identifiable` via a project-level extension; no duplicate conformance with any existing extension from prior phases
- [ ] Sheet uses `.presentationDetents([.medium])` -- `.large` is not added; user cannot drag the sheet taller than .medium
- [ ] Sheet uses `.presentationDragIndicator(.visible)`
- [ ] Swiping the sheet down sets `CalendarViewModel.selectedDate = nil`
- [ ] After dismissal, re-tapping any date presents the sheet again correctly (no stuck state)
- [ ] Sheet background is `CadenceCard` (`Color("CadenceCard")`), not transparent

**Dependencies:** PH-6-E3-S1

---

### S3: Day Detail Content -- Existing Log Display

**Story ID:** PH-6-E3-S3
**Points:** 5

`DayDetailView` renders the full read-only log for a date that has an existing `DailyLog` entry: date header, period state, flow level chip, symptom chips in read-only mode, notes, and private flag indicator.

**Acceptance Criteria:**

- [ ] `DayDetailView.swift` exists at `Cadence/Views/Tracker/Calendar/DayDetailView.swift`; accepts `date: Date`, `log: DailyLog?`, `symptoms: [SymptomLog]`, `isPeriodDay: Bool`, `flowLevel: FlowLevel?` parameters; no `@Environment(\.modelContext)` dependency
- [ ] Date header renders using `Text(date, format: .dateTime.weekday(.wide).month().day())` (e.g. "Tuesday, March 4") in `.title2` style, `Color("CadenceTextPrimary")`
- [ ] When `isPeriodDay == true`: "Period day" label in `.subheadline`, `Color("CadenceTerracotta")`
- [ ] When `flowLevel` is non-nil: a `SymptomChip` with `label: flowLevel.displayName`, `isSelected: true`, `isReadOnly: true` renders below the period day label
- [ ] Symptom chips: one `SymptomChip(label:, isSelected: true, isReadOnly: true)` per `SymptomLog` entry; chips wrap via `FlowLayout` or equivalent when they exceed the sheet width
- [ ] Notes display: `Text(log.notes)` in `.body`, `Color("CadenceTextPrimary")` when `log.notes` is non-nil and non-empty; `Text("No notes")` in `.footnote`, `Color("CadenceTextSecondary")` when absent
- [ ] Private flag: when `log.is_private == true`, renders `HStack { Image(systemName: "lock.fill").font(.system(size: 11)); Text("This entry is marked private") }` in `.footnote`, `Color("CadenceTextSecondary")`
- [ ] `DayDetailView` body does not exceed 50 lines (swiftui-production skill §view extraction); date header, chips section, notes section, and actions section are extracted subviews if needed
- [ ] No `AnyView` used in `DayDetailView` or its subviews

**Dependencies:** PH-6-E3-S2 (sheet must present before content can be verified)

---

### S4: Day Detail Empty State & Future Date Handling

**Story ID:** PH-6-E3-S4
**Points:** 2

`DayDetailView` renders the correct empty state when no `DailyLog` exists for the tapped date. Past and today dates show "Log this day" CTA. Future dates show a no-log message with no CTA.

**Acceptance Criteria:**

- [ ] When `log == nil` and `date <= Calendar.current.startOfDay(for: Date())` (today or past): renders date header, then "Nothing logged for this day." in `.body`, `Color("CadenceTextSecondary")`, then "Log this day" Primary CTA Button in `Color("CadenceTerracotta")`
- [ ] When `log == nil` and `date > Calendar.current.startOfDay(for: Date())` (future): renders date header, then "Nothing logged yet." in `.body`, `Color("CadenceTextSecondary")`; no CTA button
- [ ] "Log this day" CTA is a `Button` using the Primary CTA Button spec from Design Spec v1.1 §10.3: 50pt height, 14pt corner radius, full container width, `CadenceTerracotta` fill, white label in `.headline` semibold
- [ ] Tapping "Log this day" calls `onLogThisDay: () -> Void` closure parameter on `DayDetailView` (body is implemented in Epic 4 S5); at this story, the closure is passed as a noop from the caller

**Dependencies:** PH-6-E3-S3

---

### S5: "Edit Entry" Action Routing

**Story ID:** PH-6-E3-S5
**Points:** 3

The day detail sheet's "Edit entry" action dismisses the read-sheet and signals `CalendarViewModel` to open the Log Sheet pre-populated for the tapped date. The routing mechanism (setting `pendingEditDate`) is consumed by Epic 4.

**Acceptance Criteria:**

- [ ] When `log != nil`: an "Edit entry" text link appears at the bottom of `DayDetailView` in `.footnote` style, `Color("CadenceTerracotta")`; it is not a Primary CTA Button
- [ ] Tapping "Edit entry" calls `onEditEntry: () -> Void` closure parameter on `DayDetailView`
- [ ] `CalendarViewModel.pendingEditDate: Date?` property (new) is set to `selectedDate` when `onEditEntry` fires; this is the property that Epic 4 observes to open the Log Sheet
- [ ] After setting `pendingEditDate`, `CalendarViewModel.selectedDate` is set to `nil` (dismissing the detail sheet)
- [ ] The "Log this day" CTA in the empty state calls the same routing mechanism via `onLogThisDay` -- `CalendarViewModel.pendingEditDate` is set and `selectedDate` is cleared (same signal, different trigger)
- [ ] When `pendingEditDate` is set and is non-nil, `CalendarView` presents the Log Sheet for that date (implementation in Epic 4 S1; at this story, `pendingEditDate` is declared and set but Log Sheet presentation is a noop until Epic 4)

**Dependencies:** PH-6-E3-S4

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
- [ ] Day-tap verified end-to-end: tapping a logged date shows the correct period state, symptoms, notes, and private flag in the read-sheet
- [ ] Day-tap verified for an empty date: correct empty state renders with "Log this day" CTA for past/today dates and "Nothing logged yet" for future dates
- [ ] `SymptomChip` read-only mode verified: tapping a chip in the day detail sheet produces no state change
- [ ] Sheet dismissal verified: swiping down clears `selectedDate`; re-tapping any date presents a fresh sheet correctly
- [ ] Phase objective is advanced: a Tracker can tap any calendar day and read their log for that day
- [ ] Applicable skill constraints satisfied: cadence-navigation (sheet driven from ViewModel state, .presentationDetents correctly set), swiftui-production (view extraction enforced, no AnyView), cadence-accessibility (44pt tap targets on day cells, accessibility labels on chips)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments in `DayDetailView` or `CalendarViewModel`
- [ ] Source document alignment verified: Design Spec v1.1 §12.4 day detail spec matched exactly; day detail copy matches Design Spec §13 empty state patterns

## Source References

- PHASES.md: Phase 6 -- Calendar View (in-scope: "day tap opens day detail read-sheet (.medium detent); day detail sheet: read log for that date with chip display")
- Design Spec v1.1 §12.4 (Calendar View: "Tapped day: Opens day detail read-sheet (bottom sheet, .medium detent)")
- Design Spec v1.1 §10.1 (SymptomChip: `isReadOnly: Bool` parameter disables tap gesture)
- Design Spec v1.1 §10.3 (Primary CTA Button: 50pt height, 14pt corner, CadenceTerracotta fill)
- Design Spec v1.1 §13 (States: empty states, offline rendering)
- MVP Spec §5 (Calendar View: "Tap a date to view logs or edit entries")
- cadence-navigation skill (sheet presentation patterns, parent-coordinator-owned sheet state, `.presentationDetents`)
