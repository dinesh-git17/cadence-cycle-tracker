# Historical Entry Edit via Log Sheet

**Epic ID:** PH-6-E4
**Phase:** 6 -- Calendar View
**Estimated Size:** L
**Status:** Draft

---

## Objective

Enable a Tracker to open the Log Sheet for any past date, pre-populated with that date's existing log data, and save changes that upsert (not duplicate) the `DailyLog` and replace its `SymptomLog` set. The calendar grid must immediately reflect the updated log without a full reload. On period state change, the prediction engine recalculates.

## Problem / Context

Phase 4 implemented the Log Sheet for today's date only. The `LogSheetView` accepts a `date: Date` parameter (established by the `TrackerShell` epic in Phase 4) but was built against the assumption that `date` is always `Date()`. When a historical date is passed:

1. The sheet must fetch and bind any existing `DailyLog` and `SymptomLog` rows for that date before it is interactive.
2. The date header must display the historical date in human-readable form ("Tuesday, March 4"), not the string "Today".
3. The save action must upsert (update existing or insert new) rather than unconditionally inserting a new `DailyLog` row, which would create a duplicate.
4. If period state changes on a historical date (period started/ended), the Phase 3 prediction engine must recalculate because changing historical period data invalidates all downstream predictions.

The entry point for this flow is `CalendarViewModel.pendingEditDate: Date?`, set in Epic 3 when the user taps "Edit entry" or "Log this day" from the day detail sheet. `CalendarView` observes `pendingEditDate` and presents the Log Sheet when it is non-nil.

**Source references that define scope:**

- Design Spec v1.1 §12.3 (Log Sheet: date header, period toggles, flow level chips, symptom chip grid, notes textarea, private flag toggle, save CTA; "Keep this day private" acts as master override)
- PHASES.md Phase 6 in-scope: "edit entry path from day detail sheet opens Log Sheet pre-populated for that date"
- PHASES.md Phase 4 in-scope note: "Log Sheet save writes to SwiftData" and "Log Sheet entry from calendar day tap" as an entry point
- MVP Spec §6 (Period Logging: "Edit previously logged period dates"; period start/end actions)
- MVP Spec §7 (Symptom Logging: "Edit or delete a log after saving"; "Private flag on any individual entry")
- cadence-data-layer skill (offline-first write pattern: local SwiftData first, sync queue via SyncCoordinator; prediction engine recalculation triggers)
- swiftui-production skill (@Observable state, view extraction)

## Scope

### In Scope

- `CalendarView` property: `.sheet(item: $calendarViewModel.pendingEditDate)` presenting `LogSheetView(date: date, onSave: { ... }, onDismiss: { calendarViewModel.pendingEditDate = nil })`; uses the same sheet infrastructure as the day detail sheet but is a separate `.sheet` modifier instance (two `.sheet` modifiers on `CalendarView` -- one for day detail, one for Log Sheet via `pendingEditDate`)
- `LogSheetView` date header update: when `date` parameter is the current calendar day (`Calendar.current.isDateInToday(date)`), display "Today"; when `date` is a historical date, display `Text(date, format: .dateTime.weekday(.wide).month(.wide).day())` in `.title2`, `Color("CadenceTextPrimary")`; date display is read-only (no date picker in the Log Sheet)
- `LogSheetViewModel` (or internal state in `LogSheetView`) pre-population: on init with a non-today date, fetch `DailyLog` where `date == targetDate && user_id == currentUser` from `ModelContext`; fetch associated `SymptomLog` rows; bind results to Log Sheet `@State` variables (period started, period ended, flow level, symptom selection set, notes text, isPrivate toggle)
- Pre-population must complete before the sheet is interactive: show a brief `ProgressView` inline within the sheet if the fetch has not yet returned (consistent with Design Spec §13 loading state: "Localized ProgressView inside CTA buttons. Never full-screen spinners")
- Upsert save path: when the user taps the Save CTA --
  - If a `DailyLog` exists for `targetDate`: update it in-place (`log.flowLevel = newValue`, `log.notes = newValue`, etc.) rather than inserting a new row
  - If no `DailyLog` exists: insert a new `DailyLog` for `targetDate` (same insert path as today's log, with `date` set to `targetDate`)
  - `SymptomLog` replacement semantics: delete all existing `SymptomLog` rows linked to the `DailyLog` for `targetDate`, then insert new `SymptomLog` rows from the current chip selection
  - All writes to SwiftData are immediate (offline-first per cadence-data-layer and cadence-sync skills); SyncCoordinator write queue call follows each save (SyncCoordinator skeleton from Phase 3)
- Prediction engine recalculation trigger: when period started or period ended state changes on save (comparing pre-population values to saved values), call the Phase 3 prediction engine's recalculation entry point to update `prediction_snapshots`
- Calendar grid refresh after save: `CalendarViewModel.dayStates` recomputes after `pendingEditDate` sheet dismisses following a save; the calendar grid updates to reflect the new log state; no full `NavigationStack` pop or `CalendarView` re-creation
- Haptic feedback: `UIImpactFeedbackGenerator(.medium).impactOccurred()` fires on successful save of a historical entry (identical to today's log save haptic per Design Spec §13 success state)

### Out of Scope

- Deleting a log entry from the historical edit path (MVP Spec §7 mentions "edit or delete" but no delete UI is defined in the Design Spec; deletion is not specified in PHASES.md Phase 6 in-scope; defer to a post-beta decision)
- Editing a future predicted period day from the calendar (future dates show no Log CTA per Epic 3 S4; Log Sheet is for logged or empty past dates only)
- Full SyncCoordinator implementation (Phase 7 -- this epic calls the SyncCoordinator skeleton enqueue method established in Phase 3; it does not implement the sync transport layer)
- Haptic pattern library beyond the specified `.medium` feedback (Design Spec v1.1 §15 open item: "Haptic pattern library -- define `.light`/`.medium`/`.heavy` assignments for all interaction types -- before Log Sheet implementation"; Phase 4 established the `.medium` haptic for Log save; Phase 6 reuses the same pattern without introducing new haptic types)

## Dependencies

| Dependency                                                                                                               | Type | Phase/Epic | Status | Risk                                                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------ | ---- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| PH-6-E3 complete -- `CalendarViewModel.pendingEditDate` is declared and set by the day detail sheet routing actions      | FS   | PH-6-E3    | Open   | High -- the routing signal that triggers Log Sheet presentation originates in Epic 3; Epic 4 cannot present the sheet without it      |
| Phase 4 complete -- `LogSheetView` exists with `date: Date` and `onSave` parameters                                      | FS   | PH-4-E2    | Open   | High -- Epic 4 extends `LogSheetView`, not replaces it; Phase 4 implementation is the base that this epic modifies                    |
| Phase 3 complete -- `DailyLog` and `SymptomLog` SwiftData models, and `PredictionEngine.recalculate()` entry point exist | FS   | PH-3       | Open   | High -- pre-population fetches from these models; prediction recalculation calls the Phase 3 engine                                   |
| Phase 3 complete -- `SyncCoordinator.enqueue(operation:)` skeleton method exists                                         | SS   | PH-3       | Open   | Low -- sync enqueue is a fire-and-forget call; if the skeleton is not yet implemented, the call is a noop; transport layer is Phase 7 |

## Assumptions

- `LogSheetView` in Phase 4 was implemented with a `date: Date` parameter defaulting to `Date()` and a `@State var periodStarted: Bool = false` (not pre-populated). This epic modifies the initialization logic to optionally pre-populate from SwiftData when `date != Date()` (i.e., when a historical date is passed).
- `LogSheetView` must not exceed 50 lines in its body after this modification (swiftui-production skill §view extraction). If Phase 4 left it within bounds, adding pre-population logic may require extracting additional subviews. The engineer implementing this epic is responsible for that extraction.
- `SymptomLog` replacement semantics (delete-and-reinsert on save) are correct for the beta. An alternative (diffing added/removed chips) is more complex and offers no user-visible benefit for the beta cohort size.
- The prediction engine's recalculation entry point is a synchronous or async function callable from the save path that recomputes `prediction_snapshots` from the current `period_logs`. If Phase 3 defined this as a method on `PredictionEngine`, this epic calls it directly from the save closure. If it was not explicitly defined, the engineer must verify with the Phase 3 implementation before proceeding (cadence-data-layer skill defines the rolling-average algorithm and recalculation contract).
- Two `.sheet` modifiers on `CalendarView` are valid in SwiftUI. The day detail sheet is driven by `selectedDate: Date?`; the Log Sheet is driven by `pendingEditDate: Date?`. Both are nil by default. SwiftUI processes at most one active sheet at a time -- dismissing the day detail sheet before `pendingEditDate` is set ensures no conflict.

## Risks

| Risk                                                                                                                        | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Duplicate `DailyLog` rows inserted for the same date if upsert logic has a race condition                                   | Low        | High   | Implement upsert as: `let existing = try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<DailyLog> { $0.date == targetDate && $0.userId == currentUserId })).first`; if `existing != nil`, update in-place; if nil, insert new; never call `modelContext.insert()` if an existing row was found     |
| Pre-population state binding causes Log Sheet to reset to empty before data arrives                                         | Medium     | Medium | Initialize Log Sheet `@State` vars to nil/empty; set them in a `Task { ... }` on `.onAppear`; show a `ProgressView` replacing the Save CTA while pre-population is in progress; do not show the sheet as interactive until pre-population completes                                                           |
| Prediction engine recalculation on every historical save causes noticeable lag on devices with many `period_logs`           | Low        | Medium | Recalculate only when period state changed: compare `wasOnPeriod != isNowOnPeriod` or `flowLevel` changed from nil to non-nil (period started case); skip recalculation if only symptoms or notes changed                                                                                                     |
| `CalendarViewModel.dayStates` refresh after save causes a full calendar re-render and visible layout flash                  | Medium     | Low    | `dayStates` is an `@Observable` property; updating it triggers only the cells whose `DayState` value changed; `LazyVGrid` with stable identity (Date as `id`) will animate the minimum diff; verify no visible flash in simulator after saving a historical entry                                             |
| Two `.sheet` modifiers on `CalendarView` conflict when both `selectedDate` and `pendingEditDate` are simultaneously non-nil | Low        | High   | Enforce sequencing: "Edit entry" tap sets `pendingEditDate` and simultaneously clears `selectedDate`; these two assignments happen synchronously in the same `onChange` handler body; SwiftUI sheet transition ensures the day detail sheet begins dismissing before `pendingEditDate` triggers the Log Sheet |

---

## Stories

### S1: Log Sheet Presentation from CalendarView for Historical Dates

**Story ID:** PH-6-E4-S1
**Points:** 3

`CalendarView` adds a second `.sheet(item: $calendarViewModel.pendingEditDate)` modifier that presents `LogSheetView(date: pendingEditDate)`. Sheet dismissal clears `pendingEditDate`. The Log Sheet's date header renders the correct historical date string.

**Acceptance Criteria:**

- [ ] `CalendarView` has `.sheet(item: $calendarViewModel.pendingEditDate)` presenting `LogSheetView` with `date: pendingEditDate`, `onSave` (implemented in S3), and `onDismiss: { calendarViewModel.pendingEditDate = nil }`
- [ ] The `.sheet` for `pendingEditDate` is a distinct modifier from the `.sheet` for `selectedDate` (day detail); both can exist on `CalendarView` without conflict
- [ ] `LogSheetView` date header: when `Calendar.current.isDateInToday(date)` is true, header text is "Today" in `.title2`, `Color("CadenceTextPrimary")`; when date is not today, header text is `Text(date, format: .dateTime.weekday(.wide).month(.wide).day())` in `.title2`, `Color("CadenceTextPrimary")` (e.g. "Tuesday, March 4")
- [ ] The date parameter displayed in the header is immutable once the sheet is presented -- there is no date picker control in the Log Sheet
- [ ] Swiping the Log Sheet down clears `calendarViewModel.pendingEditDate` and the sheet dismisses
- [ ] Log Sheet presented from the calendar uses `.presentationDetents([.medium, .large])` (same as the Log Sheet presented from the tab bar center button and the dashboard CTA, per Phase 4 implementation)

**Dependencies:** PH-6-E3-S5 (`pendingEditDate` property must be declared in `CalendarViewModel`)

---

### S2: Log Sheet Pre-Population from SwiftData

**Story ID:** PH-6-E4-S2
**Points:** 5

When `LogSheetView` opens for a historical date that has an existing `DailyLog`, fetch the log and its associated `SymptomLog` rows and bind them into the Log Sheet's `@State` variables before the sheet is interactive.

**Acceptance Criteria:**

- [ ] On `.onAppear` of `LogSheetView`, when `date != Date()` (historical date), a `Task { @MainActor in ... }` initiates a `ModelContext` fetch for `DailyLog` where `date == targetDate && userId == currentUser`
- [ ] If a `DailyLog` is found: `@State var periodStarted: Bool` binds to `(existingLog.flowLevel != nil || isPeriodDay)`, `@State var flowLevel: FlowLevel?` binds to `existingLog.flowLevel`, `@State var selectedSymptoms: Set<SymptomType>` binds to the set of `SymptomType` values from all linked `SymptomLog` rows, `@State var notes: String` binds to `existingLog.notes ?? ""`, `@State var isPrivate: Bool` binds to `existingLog.is_private`
- [ ] If no `DailyLog` exists for the date: all `@State` vars initialize to their default empty values (same as opening the sheet for a brand-new entry); no error or warning
- [ ] While the fetch is in-flight, a `ProgressView()` renders inside the Save CTA button frame (replacing the button label); the Save CTA is disabled (`.disabled(true)`) and at 40% opacity per Design Spec §10.3 disabled state
- [ ] After fetch completes (success or empty result), the `ProgressView` disappears and the Save CTA becomes active; total pre-population latency on a local SwiftData fetch is under 100ms on iPhone 16 Pro
- [ ] Pre-population does not run when `Calendar.current.isDateInToday(date)` is true -- today's sheet does not need to pre-fetch (it was already implemented in Phase 4 with live `@Query` bindings)

**Dependencies:** PH-6-E4-S1

---

### S3: Upsert Save Path for Historical Dates

**Story ID:** PH-6-E4-S3
**Points:** 5

The Log Sheet Save CTA for a historical date performs an upsert (update-in-place if an existing `DailyLog` is found, insert if none) and replaces `SymptomLog` rows with the current chip selection. All writes are immediate in SwiftData. SyncCoordinator is enqueued after the SwiftData write.

**Acceptance Criteria:**

- [ ] On Save: fetch `DailyLog` for `targetDate` and `currentUser` from `ModelContext` (same fetch pattern as pre-population in S2)
- [ ] If an existing `DailyLog` is found: update `existingLog.flowLevel`, `existingLog.notes`, `existingLog.is_private` in-place; do not call `modelContext.insert(existingLog)`
- [ ] If no existing `DailyLog` is found: call `modelContext.insert(DailyLog(date: targetDate, userId: currentUser, ...))` with the current `@State` values
- [ ] `SymptomLog` replacement: call `modelContext.delete(symptomLog)` for all existing `SymptomLog` rows linked to the `DailyLog` for `targetDate`; then call `modelContext.insert(SymptomLog(dailyLogId: log.id, symptomType: type))` for each type in `selectedSymptoms`
- [ ] All writes committed via `try modelContext.save()` before the sheet dismisses
- [ ] `SyncCoordinator.enqueue(.upsertDailyLog(logId: log.id))` is called after the SwiftData save succeeds
- [ ] No duplicate `DailyLog` rows exist for `targetDate` after save -- verified by fetching all `DailyLog` rows for `targetDate` and asserting count <= 1
- [ ] Save failure (SwiftData `save()` throws): sheet stays open; a non-blocking error toast appears at the bottom per Design Spec §13 error state ("Non-blocking toast at bottom of screen. Do not use destructive red -- use CadenceTextSecondary with a `warning.fill` SF Symbol.")

**Dependencies:** PH-6-E4-S2

---

### S4: Prediction Engine Recalculation on Period State Change

**Story ID:** PH-6-E4-S4
**Points:** 3

When a historical save changes the period state for a date (period started or ended was toggled), the prediction engine recalculates `prediction_snapshots` to incorporate the updated period history.

**Acceptance Criteria:**

- [ ] Before the SwiftData save in S3, capture the pre-save period state: `let wasOnPeriod = existingLog?.flowLevel != nil` (or the pre-population value of `periodStarted`)
- [ ] After the SwiftData save completes, compute `let isNowOnPeriod = savedLog.flowLevel != nil` (or the saved value of `periodStarted`)
- [ ] If `wasOnPeriod != isNowOnPeriod`: call `PredictionEngine.shared.recalculate(for: currentUser, context: modelContext)` (or equivalent entry point defined in Phase 3) in a `Task { ... }` after save; this is non-blocking to sheet dismissal
- [ ] If only notes, symptoms, or `is_private` changed (period state unchanged): `PredictionEngine.recalculate` is NOT called; no unnecessary recalculation
- [ ] After recalculation completes, `CalendarViewModel.dayStates` is refreshed (the recalculation updates `prediction_snapshots` in SwiftData; `CalendarViewModel` re-fetches on its next refresh cycle or is explicitly triggered via `calendarViewModel.refresh()`)
- [ ] Recalculation does not block the main thread (runs in `Task { ... }` off the main actor)

**Dependencies:** PH-6-E4-S3

---

### S5: Calendar Grid Refresh After Historical Save

**Story ID:** PH-6-E4-S5
**Points:** 2

After the Log Sheet dismisses following a historical save, `CalendarViewModel.dayStates` refreshes to reflect the updated log. The calendar grid updates affected cells without a full view reload. Haptic feedback fires on save.

**Acceptance Criteria:**

- [ ] `CalendarViewModel` exposes a `refresh()` method that re-fetches `period_logs` and `prediction_snapshots` for the current display month and recomputes `dayStates`
- [ ] `CalendarView` calls `calendarViewModel.refresh()` inside the `onSave` closure passed to `LogSheetView`
- [ ] After `refresh()`, cells whose `DayState` changed (e.g., a `.default` cell that is now `.loggedPeriod` after the user logged a period for that date) update their appearance; cells whose state did not change do not re-render
- [ ] `calendarViewModel.pendingEditDate` is set to `nil` inside `onSave` (after calling `refresh()`), which dismisses the Log Sheet
- [ ] `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` fires in the `onSave` closure before dismissal (consistent with Phase 4 Log Sheet haptic behavior for today's log)
- [ ] No visible layout flash or blank frame occurs between the Log Sheet dismissal and the calendar grid update

**Dependencies:** PH-6-E4-S4

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
- [ ] Upsert correctness verified: saving a historical entry with an existing log produces exactly one `DailyLog` row for that date in SwiftData (no duplicates); verified by querying the model context after save
- [ ] Symptom replacement correctness verified: symptoms from the previous save that are not in the new selection are absent from SwiftData after the new save
- [ ] Prediction recalculation verified: toggling period started/ended on a historical date updates `prediction_snapshots.predicted_next_period` when the change affects the rolling average
- [ ] Calendar grid refresh verified: edited date's cell changes to `.loggedPeriod` state immediately after Log Sheet dismissal with no user-visible flash
- [ ] Pre-population verified: reopening the Log Sheet for the same date after a save shows the newly saved values, not the pre-save values
- [ ] Phase objective is fully complete: a Tracker can tap a calendar date, view their log, edit it via the Log Sheet, save changes that are reflected immediately on the calendar
- [ ] Applicable skill constraints satisfied: cadence-data-layer (offline-first write, SyncCoordinator enqueue, prediction recalculation trigger), cadence-sync (write queue pattern, no UI blocking), swiftui-production (view extraction, no force-unwraps, no main-thread blocking fetch)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Phase 4 `LogSheetView` contract is extended, not replaced; no regression in today's log save path

## Source References

- PHASES.md: Phase 6 -- Calendar View (in-scope: "edit entry path from day detail sheet opens Log Sheet pre-populated for that date")
- Design Spec v1.1 §12.3 (Log Sheet: full content section order, date header, period toggles, Save CTA behavior, private flag as master override)
- Design Spec v1.1 §10.3 (Primary CTA Button: loading state with ProgressView, disabled state at 40% opacity)
- Design Spec v1.1 §13 (States: loading ProgressView inside CTA, error toast with warning.fill SF Symbol, haptic on Log save: UIImpactFeedbackGenerator .medium)
- MVP Spec §6 (Period Logging: "Edit previously logged period dates")
- MVP Spec §7 (Symptom Logging: "Edit or delete a log after saving"; "Private flag on any individual entry")
- cadence-data-layer skill (offline-first write pattern, SyncCoordinator.enqueue, prediction engine recalculation contract)
- cadence-sync skill (write queue: local SwiftData first, background async queue, never blocks UI)
