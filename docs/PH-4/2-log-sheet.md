# Log Sheet -- Full Content Implementation and Save Path

**Epic ID:** PH-4-E2
**Phase:** 4 -- Tracker Navigation Shell & Core Logging
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement `LogSheetView.swift` with all seven content sections defined in Design Spec §12.3: date header, period toggles, flow level chips, symptom chip grid, notes textarea, private flag toggle, and Save CTA. Wire all three entry points (center tab tap, Tracker Home CTA, Calendar date tap) through `TrackerShell.isLogSheetPresented`. Write the save path to SwiftData and fire the `UIImpactFeedbackGenerator .medium` haptic on success. This is the primary daily interaction surface -- the core logging loop that every retention metric depends on.

## Problem / Context

The Log Sheet is Cadence's highest-frequency interaction surface. A Tracker who logs daily opens it at least once per day. Every friction point in the sheet -- slow state updates, misaligned sections, a Save CTA that waits on network -- directly damages retention. MVP Spec §6 and §7 define exactly which fields the Tracker logs; Design Spec §12.3 defines exactly how they are rendered.

Three entry points must converge on a single `@State var isLogSheetPresented` owned by `TrackerShell`. The cadence-navigation skill §4 and §7 are explicit: child views signal intent to open the sheet; they do not own the presentation boolean. The Log Sheet itself calls the `onSave: () -> Void` callback to trigger dismissal -- it does not call `@Environment(\.dismiss)` independently. Breaking this ownership model means two sheets can fight for presentation state.

The save path writes to SwiftData first. The `SyncCoordinator` queue is populated after the SwiftData write -- the sheet dismisses before the Supabase write completes. This is the Cadence optimistic UI contract (cadence-motion skill). Any code that awaits the Supabase write before calling `onSave()` is a motion spec violation.

The "Keep this day private" toggle in the sheet writes `daily_logs.is_private = true`. Its semantics must match the cadence-privacy-architecture model exactly: when toggled on, it functions as a master override for that entry regardless of global `partner_connections.share_*` flags.

**Source references that define scope:**

- Design Spec v1.1 §12.3 (Log Sheet -- all 7 content sections in order, detents, drag indicator, notes textarea spec, private flag description)
- Design Spec v1.1 §13 (haptic feedback: `UIImpactFeedbackGenerator .medium` on save; no success toast)
- cadence-navigation skill §4 (Log Sheet presentation rules: entry points, detents, dismissal)
- cadence-navigation skill §7 (parent coordinator dismissal: `isLogSheetPresented` owned by `TrackerShell`)
- cadence-motion skill (optimistic UI: `onSave()` fires before Supabase write; no await before dismiss)
- cadence-data-layer skill (SwiftData write on save; `DailyLog`, `SymptomLog`, `PeriodLog` model writes)
- cadence-privacy-architecture skill (`is_private` master override: set when private toggle is on)
- PHASES.md Phase 4 in-scope: "Log Sheet per Design Spec §12.3 (date header, period toggles, flow level chips, symptom chip grid, notes textarea, private flag toggle, save CTA at all three entry points)"

## Scope

### In Scope

- `Cadence/Views/Log/LogSheetView.swift`: replaces the minimal placeholder created in PH-4-E1-S2; full 7-section content layout in a `ScrollView` inside a `VStack` with the Save CTA pinned above keyboard
- `LogSheetViewModel.swift` at `Cadence/ViewModels/LogSheetViewModel.swift`: `@Observable` class holding `date: Date`, `periodStarted: Bool`, `periodEnded: Bool`, `selectedFlowLevel: FlowLevel?`, `selectedSymptoms: Set<SymptomType>`, `notes: String`, `isPrivate: Bool`; `save()` method writes to SwiftData and calls `onSave` callback
- Date header: formatted as "Wednesday, March 5" style (`DateFormatter` with `.full` weekday, `.long` month and day) in `title2` + CadenceTextPrimary
- Period toggle section: `PeriodToggle` component (built in PH-4-E4) with `periodStarted` and `periodEnded` bindings; section label "PERIOD" in `caption2` eyebrow style
- Flow level chip section: 4 `SymptomChip`-pattern chips (Spotting, Light, Medium, Heavy) in a single-select horizontal row; only one flow level active at a time; section label "FLOW" in `caption2` eyebrow
- Symptom chip grid: all 10 symptom types from MVP Spec §7 in a `LazyVGrid` with 3 flexible columns; uses `SymptomChip` component (built in PH-4-E3); section label "SYMPTOMS" in `caption2` eyebrow
- Notes textarea: `TextEditor` with `CadenceCard` background, 1pt `CadenceBorder` stroke, 10pt corner radius, placeholder "Anything else worth noting?" in `CadenceTextSecondary` (placeholder handled via overlay)
- Private flag toggle: `Toggle(isOn: $viewModel.isPrivate)` with label "Keep this day private" in `subheadline` and description "This entry won't be shared with your partner, regardless of your sharing settings." in `footnote` + `CadenceTextSecondary`
- Save CTA: `PrimaryButton` component (built in PH-4-E4) with label "Save log", loading state while SwiftData write is in progress, disabled state when no changes have been made
- Save path: `LogSheetViewModel.save()` writes `DailyLog` (including `is_private`), `SymptomLog` entries, and `PeriodLog` (if period state changed) to SwiftData; calls `onSave()` callback immediately after SwiftData write completes; `SyncCoordinator.enqueue()` called asynchronously after `onSave()` -- never before
- `UIImpactFeedbackGenerator(.medium).impactOccurred()` called on Save CTA tap, immediately before `viewModel.save()` -- haptic fires regardless of save outcome
- Sheet opens pre-populated with existing `DailyLog` data for `date` when a log already exists for that date; opens with empty state for dates with no prior log
- `project.yml` updated for all new Swift files; `xcodegen generate` exits 0

### Out of Scope

- Calendar date tap pre-population with historical data beyond the current date (Phase 6 wires the `selectedLogDate` from the Calendar grid; this epic only handles pre-population logic when `date` is provided by the caller)
- Supabase write (Phase 7 -- the SyncCoordinator queue enqueue is called but the actual network write is deferred)
- Edit or delete of a previously saved log beyond overwriting on the same date (Phase 4 writes; edit/delete UI is Phase 6 for Calendar and implied in the Log Sheet's pre-population behavior)
- Partner sharing strip on the Home tab (Phase 5)

## Dependencies

| Dependency                                                                                         | Type | Phase/Epic | Status | Risk                                                                 |
| -------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | -------------------------------------------------------------------- |
| PH-4-E1 complete (TrackerShell with `isLogSheetPresented`, `selectedLogDate`, 3 entry point hooks) | FS   | PH-4-E1    | Open   | High -- Log Sheet is presented by TrackerShell; the shell must exist |
| PH-4-E3 complete (SymptomChip component -- used in symptom grid and flow section)                  | FS   | PH-4-E3    | Open   | High -- the symptom grid cannot compile without SymptomChip          |
| PH-4-E4 complete (PeriodToggle, PrimaryButton components used in the sheet)                        | FS   | PH-4-E4    | Open   | High -- period section and Save CTA require these components         |
| Phase 3 complete (SwiftData schema: `DailyLog`, `SymptomLog`, `PeriodLog` models)                  | FS   | PH-3       | Open   | High -- `LogSheetViewModel.save()` writes to SwiftData models        |
| `FlowLevel` enum and `SymptomType` enum defined in Phase 3 data layer                              | FS   | PH-3       | Open   | Medium -- enums must exist before ViewModel compiles                 |

## Assumptions

- `FlowLevel` is defined in the Phase 3 data layer as an enum: `.spotting`, `.light`, `.medium`, `.heavy` (matching the SwiftData schema CHECK constraint values from PH-1-E2).
- `SymptomType` is defined in the Phase 3 data layer as an enum with all 10 cases from MVP Spec §7: `.cramps`, `.headache`, `.bloating`, `.moodChanges`, `.fatigue`, `.acne`, `.discharge`, `.sex`, `.exercise`, `.sleepQuality`.
- `SyncCoordinator` exists in Phase 3 as a service-layer object with an `enqueue(_ operation: SyncOperation)` method. Phase 4 calls `enqueue` but Phase 7 implements the actual queue processing.
- The Save CTA is disabled when no log fields have been changed from their initial loaded state -- this prevents saving empty/identical entries. The `viewModel.hasChanges` computed property drives the disabled state.
- The `LogSheetView` entry points: (1) center tab tap already handled by PH-4-E1-S2 onChange; (2) Tracker Home "Log today" CTA will be wired in Phase 5 via `TrackerShell`'s callback; (3) Calendar date tap will be wired in Phase 6. For Phase 4, entry points 2 and 3 are verified by directly setting `isLogSheetPresented = true` and `selectedLogDate` on `TrackerShell` via the simulator.

## Risks

| Risk                                                                                                         | Likelihood | Impact | Mitigation                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------ | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Notes `TextEditor` placeholder not rendering correctly (TextEditor has no native placeholder API pre-iOS 26) | Medium     | Low    | Use a `ZStack` overlay with the placeholder text; hide overlay when `text.isEmpty == false`; verify on iOS 26 simulator                                                                                          |
| Save CTA calling `onSave()` after awaiting Supabase write                                                    | Low        | High   | `LogSheetViewModel.save()` must call `onSave()` immediately after `modelContext.save()` -- add this to the acceptance criteria; the SyncCoordinator `enqueue` is a fire-and-forget `Task {}` after `onSave()`    |
| Sheet content layout shifting when keyboard appears                                                          | Medium     | Medium | Pin Save CTA with `.safeAreaInset(edge: .bottom)` or `KeyboardAdaptive` pattern; verify notes section scrolls above keyboard when focused                                                                        |
| Private flag toggle semantics differ from cadence-privacy-architecture is_private contract                   | Low        | High   | `LogSheetViewModel.save()` must pass `isPrivate` from the toggle binding to `DailyLog.isPrivate`; verify the cadence-privacy-architecture skill's master override semantics are satisfied at the SwiftData layer |

---

## Stories

### S1: LogSheetView skeleton -- structure, detents, date header

**Story ID:** PH-4-E2-S1
**Points:** 3

Replace the minimal `LogSheetView` placeholder from PH-4-E1-S2 with the full view skeleton: `ScrollView` + `VStack` sections, drag indicator, `.medium` default detent, date header, and `LogSheetViewModel`. No chip components yet -- section placeholders use `Color.clear` with a fixed height until components are available from E3/E4.

**Acceptance Criteria:**

- [ ] `LogSheetView.swift` is at `Cadence/Views/Log/LogSheetView.swift` and replaces the E1 placeholder
- [ ] `LogSheetViewModel.swift` is at `Cadence/ViewModels/LogSheetViewModel.swift`; is an `@Observable` class
- [ ] `LogSheetViewModel` properties: `date: Date`, `periodStarted: Bool`, `periodEnded: Bool`, `selectedFlowLevel: FlowLevel?`, `selectedSymptoms: Set<SymptomType>`, `notes: String`, `isPrivate: Bool`
- [ ] `LogSheetView` takes `date: Date` and `onSave: () -> Void` parameters and creates `@State private var viewModel = LogSheetViewModel(date: date)`
- [ ] Sheet presents with `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)` -- these match the values registered in `TrackerShell`; `LogSheetView` itself does NOT re-declare these (they are set by the caller in `TrackerShell`)
- [ ] Date header renders the provided `date` formatted as full weekday + month + day (e.g., "Wednesday, March 5") using `caption2` eyebrow label "DATE" above, `title2` date string, `CadenceTextPrimary`
- [ ] `ScrollView` content is a `VStack(alignment: .leading, spacing: 24)` containing 6 section slots (period, flow, symptoms, notes, private, save); placeholders are `Color.clear.frame(height: 44)` at each slot
- [ ] `project.yml` updated with `Cadence/Views/Log/LogSheetView.swift` and `Cadence/ViewModels/LogSheetViewModel.swift`
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E1-S2 (TrackerShell sheet registration), PH-3 (FlowLevel + SymptomType enums)

**Notes:** The `@Observable` macro requires importing `Observation` -- Swift 5.9+. No `@StateObject`, `@ObservedObject`, or `@Published` patterns. `LogSheetView` holds `@State private var viewModel` (not `@StateObject`). This matches the swiftui-production skill's @Observable mandate. The date header section spacing (`caption2` eyebrow above `title2`) uses the 8pt space-8 token between eyebrow and value, 24pt space-24 between sections.

---

### S2: Period toggle section and flow level chip section

**Story ID:** PH-4-E2-S2
**Points:** 3

Wire the `PeriodToggle` component (from PH-4-E4) and the flow level chip row into the Log Sheet. Flow level chips use the same `SymptomChip` visual component (from PH-4-E3) in a single-select horizontal row, replacing the placeholder height slots from S1.

**Acceptance Criteria:**

- [ ] Period toggle section: "PERIOD" `caption2` eyebrow label; `PeriodToggle(periodStarted: $viewModel.periodStarted, periodEnded: $viewModel.periodEnded)` renders at full section width
- [ ] Flow level section: "FLOW" `caption2` eyebrow label; 4 `SymptomChip` instances in an `HStack` (Spotting, Light, Medium, Heavy); tapping one chip deactivates any previously active flow chip (single-select: `selectedFlowLevel` updates to the tapped value; tapping the active chip deselects it, setting `selectedFlowLevel = nil`)
- [ ] Flow chips use `SymptomChip` with the standard active/default states (CadenceTerracotta active, transparent default)
- [ ] Flow chip labels match exactly: "Spotting", "Light", "Medium", "Heavy" (matches `FlowLevel` enum display names)
- [ ] Eyebrow labels are `caption2` style, uppercased, `CadenceTextSecondary` -- no hardcoded font modifiers, use the `caption2` token
- [ ] Section spacing between eyebrow and component is 8pt; between sections is 24pt
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E2-S1, PH-4-E3 (SymptomChip), PH-4-E4 (PeriodToggle)

**Notes:** Flow chips are single-select by design -- a period can have one flow level per day. The selection logic is: tap active chip = deselect (set to nil); tap inactive chip = set as active (replacing any previous selection). This differs from symptom chips (multi-select). The `SymptomChip` component accepts an `isActive: Bool` binding -- the Log Sheet computes `isActive` for each flow chip as `viewModel.selectedFlowLevel == flowLevel`.

---

### S3: Symptom chip grid -- all 10 symptoms

**Story ID:** PH-4-E2-S3
**Points:** 3

Implement the symptom chip grid section: all 10 symptom types from MVP Spec §7 in a `LazyVGrid` with 3 adaptive columns using `SymptomChip` components with multi-select toggle semantics.

**Acceptance Criteria:**

- [ ] Symptom grid section: "SYMPTOMS" `caption2` eyebrow label
- [ ] `LazyVGrid` with `columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]` (3 equal-width columns)
- [ ] All 10 symptom types rendered: Cramps, Headache, Bloating, Mood changes, Fatigue, Acne, Discharge, Sex, Exercise, Sleep quality (display names matching `SymptomType` enum `displayName` property)
- [ ] Each chip is a `SymptomChip(label: symptomType.displayName, isActive: viewModel.selectedSymptoms.contains(symptomType), isReadOnly: false, isSexChip: symptomType == .sex)` -- passing `isSexChip: true` for the Sex chip triggers the lock icon rendering
- [ ] Tapping a chip toggles it in `viewModel.selectedSymptoms` (multi-select: tapping active removes it; tapping inactive inserts it)
- [ ] Chip grid horizontal padding matches the sheet's content inset (16pt from sheet edges)
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E2-S2, PH-4-E3 (SymptomChip with `isSexChip` parameter)

**Notes:** The 3-column `LazyVGrid` with `.flexible()` columns produces chips that wrap to content width. If chip labels vary dramatically in length, the grid may render unevenly -- this is acceptable for beta. The symptom display order matches MVP Spec §7: Cramps, Headache, Bloating, Mood changes, Fatigue, Acne, Discharge, Sex, Exercise, Sleep quality. Do not reorder for aesthetic reasons.

---

### S4: Notes textarea, private flag toggle, and Save CTA with SwiftData write

**Story ID:** PH-4-E2-S4
**Points:** 3

Complete the final three Log Sheet sections: notes textarea, private flag toggle, and Save CTA. Implement `LogSheetViewModel.save()` to write to SwiftData. The Save CTA calls `onSave()` immediately after the SwiftData write -- no Supabase wait.

**Acceptance Criteria:**

- [ ] Notes textarea: `TextEditor(text: $viewModel.notes)` with `CadenceCard` background, 1pt `CadenceBorder` stroke, `10pt` corner radius, minimum height of 80pt; placeholder text "Anything else worth noting?" displayed as a `ZStack` overlay in `CadenceTextSecondary` body style when `viewModel.notes.isEmpty`
- [ ] Private flag toggle: `Toggle(isOn: $viewModel.isPrivate)` with `subheadline` label "Keep this day private" and `footnote` description "This entry won't be shared with your partner, regardless of your sharing settings." in `CadenceTextSecondary`
- [ ] Save CTA: `PrimaryButton` component with label "Save log", loading state active while `viewModel.isSaving`, disabled state when `!viewModel.hasChanges`
- [ ] `viewModel.hasChanges: Bool` computed property returns `true` if any field has changed from its loaded state (`periodStarted`, `periodEnded`, `selectedFlowLevel`, `selectedSymptoms`, `notes`, or `isPrivate`)
- [ ] `viewModel.save()`: (1) sets `isSaving = true`; (2) writes `DailyLog` with all fields including `isPrivate` to `modelContext`; (3) inserts or updates `SymptomLog` entries for `selectedSymptoms`; (4) writes `PeriodLog` if `periodStarted` or `periodEnded` changed; (5) calls `modelContext.save()`; (6) calls `onSave()` callback; (7) enqueues `SyncCoordinator` as a background `Task`
- [ ] `isPrivate` from the toggle binding is written to `DailyLog.isPrivate` -- the cadence-privacy-architecture master override contract is satisfied at the data layer
- [ ] `viewModel.save()` does NOT `await` any Supabase call before calling `onSave()`
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E2-S1, PH-4-E4 (PrimaryButton), Phase 3 (SwiftData model context injected)

**Notes:** The Save CTA is pinned above the keyboard using `.safeAreaInset(edge: .bottom)` on the outer `VStack`, or by placing it outside the `ScrollView` and using a `VStack` with `Spacer()`. Verify the CTA does not scroll out of view when the notes `TextEditor` is focused and the keyboard is visible. The button must remain fixed at the bottom of the sheet regardless of keyboard state.

---

### S5: Three entry points wired through TrackerShell and haptic feedback

**Story ID:** PH-4-E2-S5
**Points:** 3

Wire all three Log Sheet entry points through `TrackerShell.isLogSheetPresented`, verify the pre-population logic reads existing SwiftData for the given date, and implement the `UIImpactFeedbackGenerator .medium` haptic on Save tap.

**Acceptance Criteria:**

- [ ] Entry point 1 (center tab tap): already functional from PH-4-E1-S2; verified: tap center Log tab, sheet opens with `Date()` (today); sheet shows pre-populated data if a `DailyLog` for today exists in SwiftData; sheet shows empty state if no log exists
- [ ] Entry point 2 (Tracker Home "Log today" CTA): `TrackerHomeView` exposes an `onLogTodayTapped: () -> Void` callback; in Phase 5 `TrackerShell` will wire this; for Phase 4, the callback is declared on `TrackerHomeView` and documented -- actual wiring verified in Phase 5
- [ ] Entry point 3 (Calendar date tap): `CalendarView` exposes an `onDateTapped: (Date) -> Void` callback; `TrackerShell` sets `selectedLogDate = date` and `isLogSheetPresented = true` in the callback; for Phase 4, the callback is declared on `CalendarView` and documented -- actual calendar content wiring is Phase 6
- [ ] `LogSheetViewModel` `init(date:)` accepts a `Date` parameter and fetches the existing `DailyLog` for that date from the SwiftData `ModelContext` during initialization; if no log exists, all fields are nil/empty/false
- [ ] `UIImpactFeedbackGenerator(.medium).impactOccurred()` is called in the Save CTA's tap action handler, before `viewModel.save()` is called
- [ ] Haptic fires even if `viewModel.save()` subsequently fails -- the haptic confirms the user's tap, not the outcome
- [ ] Tapping Save dismisses the sheet (via `onSave()` callback clearing `isLogSheetPresented`) and does not wait for any async operation before dismissing
- [ ] `scripts/protocol-zero.sh` exits 0 on all Phase 4 E2 Swift files
- [ ] `scripts/check-em-dashes.sh` exits 0

**Dependencies:** PH-4-E2-S4, PH-4-E1-S2

**Notes:** The haptic call appears in the button action closure: `hapticEngine.impactOccurred(); viewModel.save()`. Do not use `await` between the haptic and the save call. The `UIImpactFeedbackGenerator` must be prepared before firing -- call `prepare()` in `onAppear` of the Log Sheet and store the generator in the ViewModel or the view. Fire with `.impactOccurred()` on tap. Reference Design Spec §13: "Haptic feedback (`UIImpactFeedbackGenerator .medium`) on Log save. No toast -- the UI state change itself is confirmation."

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

- [ ] All five stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Log Sheet opens from all 3 entry points with correct pre-population behavior
- [ ] Save writes to SwiftData; sheet dismisses optimistically before any async work
- [ ] Haptic fires on Save tap
- [ ] `isPrivate` written to `DailyLog.isPrivate` per cadence-privacy-architecture master override contract
- [ ] Phase objective is advanced: the core logging loop is complete and functional
- [ ] cadence-navigation skill §4 and §7 constraints satisfied: `isLogSheetPresented` owned by `TrackerShell`; no child view owns a competing presentation binding
- [ ] cadence-motion skill optimistic UI constraint: `onSave()` fires before `SyncCoordinator.enqueue()` -- never awaits network
- [ ] cadence-data-layer skill: SwiftData write is the first operation on Save; sync is queued after
- [ ] cadence-privacy-architecture skill: `is_private` flag written correctly to `DailyLog`
- [ ] swiftui-production skill: `@Observable` ViewModel; no `@ObservedObject`; no `AnyView`
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No force unwraps, hardcoded hex values, or `print()` calls

## Source References

- PHASES.md: Phase 4 -- Tracker Navigation Shell & Core Logging (in-scope: Log Sheet per §12.3)
- Design Spec v1.1 §12.3 (Log Sheet: all 7 sections, detents, private flag description, Save CTA spec)
- Design Spec v1.1 §13 (haptic feedback: .medium on save; no success toast)
- Design Spec v1.1 §10.1 (SymptomChip -- used in symptom grid and flow section)
- MVP Spec §6 (period logging: flow levels -- Spotting, Light, Medium, Heavy)
- MVP Spec §7 (symptom logging: all 10 symptom types, private flag, notes field)
- cadence-navigation skill §4 (Log Sheet entry points, detents, dismissal)
- cadence-navigation skill §7 (parent coordinator dismissal pattern)
- cadence-motion skill (optimistic UI: no network await before dismiss; haptic on save)
- cadence-data-layer skill (SwiftData write path, SyncCoordinator enqueue)
- cadence-privacy-architecture skill (is_private as master override)
