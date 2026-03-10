# Tracker Onboarding

**Epic ID:** PH-2-E4
**Phase:** 2 -- Authentication & Onboarding
**Estimated Size:** S
**Status:** Draft

---

## Objective

Implement the Tracker onboarding form that captures the four cycle setup inputs (last period date, average cycle length, average period length, goal mode), validates them, and writes a `cycle_profiles` row to Supabase. On successful write, the AppCoordinator routes the user to the Tracker shell stub. This data is the seed input for all prediction logic in Phase 3.

## Problem / Context

The `cycle_profiles` row written by this epic is the first piece of user-specific data in the system. Phase 3's prediction engine reads `average_cycle_length`, `average_period_length`, and `goal_mode` from this row to generate the initial predictions that feed Phase 5 (Home Dashboard). If this write does not exist, the prediction engine has no seed input and Phase 5 cannot show meaningful data to a new user.

Source authority: MVP Spec §1 (Onboarding and Role Selection) defines the four inputs and their defaults. Design Spec §12 does not include a dedicated onboarding screen spec -- the screen is designed from the component library (Primary CTA Button §10.3, input fields §12.1 for style reference, spacing §5).

## Scope

### In Scope

- `TrackerOnboardingView.swift` -- single-screen form with all four inputs
- `TrackerOnboardingViewModel.swift` -- @Observable class owning form state, validation, and Supabase write
- Last period date picker: native `DatePicker` component, `.graphical` or `.compact` style, limited to dates from today minus 90 days through today
- Average cycle length input: integer stepper or segmented picker, range 15-60 days, default 28
- Average period length input: integer stepper or segmented picker, range 1-15 days, default 5
- Goal mode selector: two-option pill selector ("Track my cycle" / "Trying to conceive"), styled as a paired set of toggle buttons
- Input validation: all fields required, date within allowed range, cycle length and period length within allowed ranges
- `cycle_profiles` upsert to Supabase: `user_id`, `average_cycle_length`, `average_period_length`, `goal_mode`, `predictions_enabled: true`
- Loading state on CTA during write and error feedback on failure
- `project.yml` additions for two new Swift files

### Out of Scope

- Initial prediction generation -- Phase 3 (prediction engine does not exist yet)
- Tracker Home Dashboard rendering -- Phase 5
- Editing cycle profile after initial setup -- Phase 12 (Settings)
- Onboarding progress indicator (multi-step UI) -- the spec defines a single-screen form; no step indicator is required for the MVP
- Haptic feedback on form completion -- Design Spec §15 defers haptic library definition to "before Log Sheet implementation"; this is not the Log Sheet

## Dependencies

| Dependency                                                                                                                       | Type | Phase/Epic | Status | Risk   |
| -------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ------ |
| `AppCoordinator` routing to `.trackerOnboarding` and `.trackerShell`                                                             | FS   | PH-2-E3    | Open   | Low    |
| Authenticated Supabase session (user is signed in when this screen is reached)                                                   | FS   | PH-2-E2    | Open   | Low    |
| `cycle_profiles` table schema in Supabase (user_id, average_cycle_length, average_period_length, goal_mode, predictions_enabled) | FS   | PH-1       | Open   | Medium |
| RLS on `cycle_profiles` allowing authenticated user to insert/update their own row                                               | FS   | PH-1       | Open   | Medium |

## Assumptions

- The onboarding form is a single screen. There is no multi-step flow. All four inputs are presented simultaneously.
- Default values are pre-populated when the screen loads: cycle length = 28, period length = 5. The date picker defaults to today's date. Goal mode has no default selection -- the user must explicitly choose one.
- A `cycle_profiles` row may not already exist for a new user. The write uses `upsert` with `onConflict: "user_id"` to handle re-entering onboarding (e.g., sign out and sign in again before completing setup).
- `predictions_enabled` defaults to `true` on the initial write. There is no UI to set this during onboarding.
- The "last period date" field collects the start date of the user's most recent period. This is the anchor for Phase 3's initial prediction calculation. The date picker label should read "When did your last period start?" to eliminate ambiguity.
- Cycle length and period length are integers only (no fractional days). The input component should not accept decimal input.
- `goal_mode` maps to the Postgres enum (`track` / `conceive`) as a Swift enum `GoalMode.trackCycle` and `GoalMode.tryingToConceive`.

## Risks

| Risk                                                                         | Likelihood | Impact | Mitigation                                                                                                     |
| ---------------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------- |
| `cycle_profiles` RLS not allowing insert by authenticated user (Phase 1 gap) | Medium     | High   | Test the Supabase write immediately when Phase 1 is complete; do not wait for full Phase 2 integration testing |
| Date picker `.compact` style clips on small screen sizes (iPhone SE)         | Low        | Low    | Test on SE simulator; use `.graphical` style if `.compact` clips                                               |
| User taps Continue without selecting goal mode                               | Low        | Medium | Disable Continue CTA until goal mode is selected (goal mode has no default)                                    |

---

## Stories

### S1: Tracker onboarding form layout

**Story ID:** PH-2-E4-S1
**Points:** 5

Implement `TrackerOnboardingView` with all four input fields, their labels, default values, and the Continue CTA. No Supabase calls in this story -- the form is fully renderable in preview with static state. The goal mode selector uses a custom two-button pill component consistent with the Period Toggle spec (Design Spec §10.2) but with different labels.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Onboarding/TrackerOnboardingView.swift` and `Cadence/ViewModels/TrackerOnboardingViewModel.swift` exist and compile clean
- [ ] Screen title "Set up your cycle" (or equivalent per Design Spec typography: `.title2`, `CadenceTextPrimary`) is displayed at the top
- [ ] "When did your last period start?" label with a `DatePicker` below it; the picker is limited to `Date.distantPast...Date()` but practically clipped to 90 days in the past via a `max` binding validation
- [ ] "Average cycle length" label with an integer stepper below it: default 28, minimum 15, maximum 60, increment 1
- [ ] "Average period length" label with an integer stepper below it: default 5, minimum 1, maximum 15, increment 1
- [ ] Goal mode selector: two equal-width pill buttons "Track my cycle" / "Trying to conceive", 44pt height, 12pt corner radius, `CadenceTerracotta` fill on selected option, `CadenceCard` fill with 1pt `CadenceBorder` on unselected option, matching Period Toggle spec
- [ ] No goal mode button is pre-selected on screen load
- [ ] Continue CTA: full-width Primary CTA Button, `CadenceTerracotta`, "Continue" label, disabled until goal mode is selected
- [ ] All content is scrollable in a `ScrollView` so the keyboard does not obscure inputs on small screens
- [ ] 16pt horizontal screen margins applied consistently
- [ ] 20pt internal card padding if content is wrapped in a Data Card surface
- [ ] `project.yml` updated with both Swift files

**Dependencies:** PH-2-E3-S1 (AppCoordinator routes to this view), PH-2-E2 (user is authenticated)
**Notes:** `TrackerOnboardingViewModel` is `@Observable` and owns all four input state variables. `TrackerOnboardingView` reads from the ViewModel and passes user interactions back to it. The ViewModel is created by the view (not injected for this screen -- it has no singleton concerns).

---

### S2: Input validation and boundary enforcement

**Story ID:** PH-2-E4-S2
**Points:** 3

Implement all input validation rules and wire them to the Continue CTA's disabled state. The stepper components enforce their min/max bounds inline. The date picker enforces the 90-day lookback window. Edge cases: what happens if the user manually enters a date beyond the allowed range (should not be possible with a picker, but verify).

**Acceptance Criteria:**

- [ ] Continue CTA is enabled only when: goal mode is selected AND last period date is set to a valid value (today or earlier, within 90 days of today)
- [ ] Stepper for cycle length cannot be decremented below 15 or incremented above 60
- [ ] Stepper for period length cannot be decremented below 1 or incremented above 15
- [ ] Period length stepper maximum is capped at the current cycle length value minus 1 (a period cannot be longer than a cycle)
- [ ] Last period date picker disables dates in the future (picker mode limits selection to `..<Date()`)
- [ ] Last period date defaults to today's date on screen load (not nil -- the picker always has a valid value)
- [ ] If cycle length is changed to a value less than the current period length, period length is automatically adjusted to `min(periodLength, cycleLength - 1)`
- [ ] All validation logic lives in `TrackerOnboardingViewModel`, not in the view body

**Dependencies:** PH-2-E4-S1
**Notes:** The 90-day lookback window for last period date is not specified in the source documents -- it is an implementation assumption added for UX sanity. If Dinesh specifies a different window, update the acceptance criterion and note the change.

---

### S3: cycle_profiles Supabase upsert and completion routing

**Story ID:** PH-2-E4-S3
**Points:** 3

Wire the Continue CTA to the `cycle_profiles` Supabase upsert. Show a loading state during the write. On success, signal the AppCoordinator to route to `.trackerShell`. On failure, display an inline error and leave the user on the onboarding screen to retry.

**Acceptance Criteria:**

- [ ] Tapping Continue calls `supabase.from("cycle_profiles").upsert(CycleProfile(userId: session.user.id, averageCycleLength: cycleLength, averagePeriodLength: periodLength, goalMode: goalMode, predictionsEnabled: true), onConflict: "user_id")` via a `Task` in `TrackerOnboardingViewModel`
- [ ] Continue CTA shows an inline `ProgressView` and is disabled during the write (Design Spec §10.3 loading state)
- [ ] On successful upsert, `AppCoordinator.currentRoute` is set to `.trackerShell` via the coordinator reference passed to the ViewModel
- [ ] On network error or Supabase error, an inline error message appears below the CTA in `.footnote` `CadenceTextSecondary` with `warning.fill` SF Symbol; the form data is preserved so the user can retry
- [ ] No data is written to Supabase if any validation constraint is violated (guard in ViewModel before dispatching the upsert)
- [ ] The `CycleProfile` Swift struct used for the upsert conforms to `Codable` with snake_case key strategy matching the Postgres column names
- [ ] `TrackerOnboardingViewModel` is testable without a live Supabase connection -- the Supabase write is behind a protocol or closure that can be swapped in tests

**Dependencies:** PH-2-E4-S2, PH-2-E3 (AppCoordinator routing), Phase 1 (cycle_profiles table and RLS)
**Notes:** The `CycleProfile` struct maps to the `cycle_profiles` table. `goal_mode` is a Postgres enum (`track` / `conceive`) -- the Swift enum must serialize to these exact string values. Use a `RawRepresentable` String enum to ensure correct JSON encoding.

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
- [ ] End-to-end verified: a new user completes Tracker onboarding and a `cycle_profiles` row is confirmed in the Supabase dashboard
- [ ] Routing verified: after successful write, the AppCoordinator routes to `.trackerShell` stub
- [ ] Phase objective is advanced: a Tracker user has a complete `cycle_profiles` row seeding Phase 3's prediction engine
- [ ] Applicable skill constraints satisfied: `swiftui-production` (@Observable ViewModel, no force unwraps, LazyVStack not required for this single-screen form), `cadence-design-system` (all tokens used correctly -- colors, spacing, corner radii), `cadence-xcode-project` (project.yml additions), `cadence-supabase` (typed Codable struct, onConflict upsert, RLS-aligned write), `cadence-testing` (ViewModel injectable for unit tests)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code or placeholder comments in Swift files
- [ ] Source document alignment verified: four input fields match MVP Spec §1 exactly

## Source References

- MVP Spec §1 (Onboarding and Role Selection -- four input fields, defaults)
- MVP Spec User Flow 1 (Tracker Onboarding sequence)
- MVP PRD v1.0 Data Model (cycle_profiles table: user_id, average_cycle_length, average_period_length, goal_mode, predictions_enabled)
- Design Spec v1.1 §10.2 (Period Toggle Buttons -- used as style reference for goal mode selector)
- Design Spec v1.1 §10.3 (Primary CTA Button -- loading state, disabled state)
- Design Spec v1.1 §5 (spacing tokens: 16pt screen margin, 20pt card padding)
- Design Spec v1.1 §13 (error state -- warning.fill, no red)
- PHASES.md: Phase 2 -- Authentication & Onboarding (In-Scope items 7-8)
