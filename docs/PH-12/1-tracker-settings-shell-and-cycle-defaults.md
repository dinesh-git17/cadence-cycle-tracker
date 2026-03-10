# Tracker Settings Navigation Shell + Cycle Defaults

**Epic ID:** PH-12-E1
**Phase:** 12 -- Settings
**Estimated Size:** M
**Status:** Draft

---

## Objective

Build the Tracker Settings tab content: a root `List` view with `NavigationStack`-based routing to all settings destinations, the Cycle Defaults form that reads and writes `cycle_profiles`, and the navigation wiring that surfaces `PartnerManagementView` (Phase 8) and `NotificationSettingsView` (Phase 10) within the Tracker's settings hierarchy. When this epic is complete, all prior-phase settings surfaces are reachable from a single coherent navigation tree and the Cycle Defaults form is fully functional.

## Problem / Context

Phase 4 placed a stub view in the Tracker Settings tab (tab 5). Every prior phase that builds a settings surface -- Phase 8's `PartnerManagementView`, Phase 10's `NotificationSettingsView` -- explicitly deferred navigation wiring to Phase 12. Without this epic, none of those surfaces are reachable from within the app. The Tracker also has no way to update their cycle defaults (average cycle length, average period length, goal mode) after onboarding, even though `cycle_profiles` has been writable since Phase 3.

The Settings tab is a navigation aggregator, not a feature owner. Its job is to route the Tracker to the correct subsystem view without duplicating logic or state. This maps cleanly to `NavigationStack + navigationDestination(for:)` with a `SettingsDestination` enum as the type-safe navigation value.

Design Spec v1.1 §8 defines Settings as tab 5 of the Tracker shell: "Partner management, sharing permissions, account, notifications." MVP Spec §11 defines the full Tracker settings surface: cycle defaults, partner sharing controls, reminder preferences, app lock, delete all data.

**Source references that define scope:**

- Design Spec v1.1 §8 (Information Architecture -- Tracker tab 5: Settings)
- MVP Spec §11 (Privacy and Settings -- full Tracker settings list)
- PHASES.md Phase 12 in-scope (cycle defaults writes to cycle_profiles; partner management section; reminder preferences; Settings is navigation aggregator)
- PH-8-E1 through PH-8-E4 (InviteCodeView, PartnerManagementView, PauseSharingToggleRow, disconnect -- all surfaced here via navigation, not re-implemented)
- PH-10-E4 (NotificationSettingsView -- surfaced here via navigation, not re-implemented)

## Scope

### In Scope

- `SettingsDestination` enum in `Cadence/Views/Settings/SettingsDestination.swift`: `CaseIterable`, `Hashable`; cases: `.cycleDefaults`, `.partnerSharing`, `.notifications`, `.appLock`, `.account`
- `TrackerSettingsView` in `Cadence/Views/Settings/TrackerSettingsView.swift`: `List`-based root view; sections defined below; wired into the Phase 4 Tracker shell replacing the settings tab stub; uses `NavigationLink(value: SettingsDestination)` for each row; `navigationDestination(for: SettingsDestination.self)` routing block in the wrapping `NavigationStack` (or appended to the Tracker shell's existing `NavigationStack` if Phase 4 used a shared stack -- verify before implementation)
- `TrackerSettingsView` sections in order: (1) "CYCLE" -- "Cycle Defaults" row; (2) "PARTNER" -- partner section (S4); (3) "NOTIFICATIONS" -- "Notifications" row; (4) "PRIVACY" -- "App Lock" row; (5) "ACCOUNT" -- "Account" row (no navigation -- destructive actions handled in Epic 3)
- Section eyebrow labels in `caption2` uppercased `CadenceTextSecondary`, matching Design Spec §4 eyebrow style
- `CycleDefaultsView` in `Cadence/Views/Settings/CycleDefaultsView.swift`: `Form`-based view; three controls: (1) `Stepper` for average cycle length, range 21-35 days, label `"Average cycle length"` with current value shown as `"\(avgCycleLength) days"` in trailing `Text`; (2) `Stepper` for average period length, range 2-10 days, label `"Average period length"` with value shown as `"\(avgPeriodLength) days"`; (3) `Picker("Goal", selection: $goalMode)` with `pickerStyle(.segmented)` and two options: "Track cycle" (`.track` enum case) and "Trying to conceive" (`.conceive` enum case) -- these map to the `goal_mode` enum in `cycle_profiles`
- `CycleDefaultsViewModel` in `Cadence/ViewModels/CycleDefaultsViewModel.swift`: `@Observable` class; reads the Tracker's `CycleProfile` from SwiftData on init; exposes `avgCycleLength: Int`, `avgPeriodLength: Int`, `goalMode: GoalMode` as mutable published properties; `save() async throws` commits mutations to SwiftData and enqueues a SyncCoordinator write to `cycle_profiles`
- Prediction engine re-trigger: after `CycleDefaultsViewModel.save()`, if `avgCycleLength` changed, call the Phase 3 prediction engine's recalculate entry point to refresh `prediction_snapshots` with the new average; if only `goalMode` changed, no recalculation is needed (goal mode affects display, not the rolling-average algorithm)
- Partner section conditional render logic (S4): read `PartnerConnectionStore.connectionStatus` from environment; if `.none`, show "Invite a Partner" row with `plus.circle` SF Symbol leading icon; if `.pendingCode`, `.pendingConfirmation`, or `.active`, show "Partner Sharing" row with a `circle.fill` status indicator tinted `CadenceSage` leading icon and the partner name (or "Pending connection") as a trailing detail label; both rows navigate to `SettingsDestination.partnerSharing`
- Notifications navigation row: "Notifications" label, `bell` SF Symbol leading icon, navigates to `SettingsDestination.notifications`; `PartnerNotificationControlsView` visibility inside `NotificationSettingsView` is gated by `PartnerConnectionStore.connectionStatus == .active` (per PH-10-E4-S4 contract -- Phase 12 passes this condition to `NotificationSettingsView`)
- `project.yml` updated with entries for `SettingsDestination.swift`, `TrackerSettingsView.swift`, `CycleDefaultsView.swift`, `CycleDefaultsViewModel.swift` under their respective source groups; `xcodegen generate` exits 0 after changes

### Out of Scope

- App lock screen and enforcement -- PH-12-E2
- Account settings, sign out, delete all data, delete account -- PH-12-E3
- Partner Settings tab (tab 3 in Partner shell) -- PH-12-E4
- Re-implementing `PartnerManagementView`, `InviteCodeView`, `PauseSharingToggleRow`, or disconnect flow -- PH-8-E1 through PH-8-E4 own those; this epic only navigates to them
- Re-implementing `NotificationSettingsView` or `NotificationRemindersView` -- PH-10-E4 owns those; this epic only navigates to them
- Changing the Phase 4 Tracker shell tab bar structure or tab icon -- tab 5 stub is replaced, nothing else changes

## Dependencies

| Dependency                                            | Type | Phase/Epic | Status | Risk                                                                                                                                                  |
| ----------------------------------------------------- | ---- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 4 Tracker shell with Settings tab stub          | FS   | PH-4       | Open   | Low -- shell must exist for stub replacement                                                                                                          |
| `PartnerConnectionStore` in environment (PH-8-E1)     | FS   | PH-8-E1    | Open   | Low -- store must be injectable                                                                                                                       |
| `PartnerManagementView` built and navigable (PH-8-E3) | FS   | PH-8-E3    | Open   | Low                                                                                                                                                   |
| `InviteCodeView` built (PH-8-E1-S4)                   | FS   | PH-8-E1    | Open   | Low                                                                                                                                                   |
| `NotificationSettingsView` built (PH-10-E4-S5)        | FS   | PH-10-E4   | Open   | Low                                                                                                                                                   |
| `CycleProfile` SwiftData model (PH-3)                 | FS   | PH-3       | Open   | Low -- model must exist for reads and writes                                                                                                          |
| SyncCoordinator write queue (PH-7)                    | FS   | PH-7       | Open   | Low -- needed for `cycle_profiles` remote write                                                                                                       |
| Phase 3 prediction engine recalculate entry point     | FS   | PH-3       | Open   | Medium -- if Phase 3 did not expose a public `recalculate(for:)` method, S3 must call into the engine's internal API; verify before S3 implementation |

## Assumptions

- The Phase 4 Tracker shell uses `NavigationStack` at the top level of the Tracker tab hierarchy, with `navigationDestination(for:)` modifiers available on child views. If Phase 4 used a different navigation pattern, `TrackerSettingsView` must own its own nested `NavigationStack` -- inspect Phase 4 source before implementing S1.
- `PartnerConnectionStore` is injected into the environment at the `TrackerTabView` level (Phase 4 assumption) and is accessible via `@Environment` in `TrackerSettingsView`.
- The `CycleProfile` SwiftData model exists with `averageCycleLength: Int`, `averagePeriodLength: Int`, and `goalMode: GoalMode` fields matching the MVP Spec data model. If the Phase 3 field names differ, align to the actual model before implementing S2.
- Average cycle length range (21-35) and period length range (2-10) are standard clinical ranges suitable for a beta cohort. These are product decisions derived from the MVP Spec and are not user-configurable beyond the stepper bounds.
- The Phase 3 prediction engine exposes a recalculate method that can be invoked on demand. If it only recalculates reactively (e.g., via `@Observable` property observation), triggering a `CycleProfile` save through SwiftData is sufficient to trigger recalculation automatically.

## Risks

| Risk                                                                                                                | Likelihood | Impact                                                                                             | Mitigation                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Phase 4 Tracker shell uses a non-standard NavigationStack pattern that conflicts with `SettingsDestination` routing | Medium     | Medium -- may require refactoring Phase 4 navigation wiring                                        | Inspect Phase 4 `TrackerTabView` and Tracker home navigation before writing S1; adapt `SettingsDestination` routing accordingly |
| Phase 3 prediction engine does not expose a public recalculate API                                                  | Medium     | Low -- worst case, the new cycle default doesn't affect predictions until next app launch          | Expose a `recalculate(using:)` method from Phase 3's prediction engine if absent; or trigger via SwiftData observation          |
| `cycle_profiles` has only one row per user; saving a mutation replaces the row                                      | Low        | Low -- behavior is correct; just verify upsert vs. insert semantics in the Phase 3 SwiftData model | Use `ModelContext.save()` on the existing fetched `CycleProfile` instance (not a new insert)                                    |

---

## Stories

### S1: TrackerSettingsView Root List + SettingsDestination Navigation

**Story ID:** PH-12-E1-S1
**Points:** 3

Define `SettingsDestination` enum and implement `TrackerSettingsView` as the root Settings tab content. All section rows use `NavigationLink(value: SettingsDestination)`. A `navigationDestination(for: SettingsDestination.self)` block routes each case to the correct destination view. Replace the Phase 4 Settings tab stub.

**Acceptance Criteria:**

- [ ] `SettingsDestination` is a `Hashable`, `CaseIterable` enum with exactly 5 cases: `.cycleDefaults`, `.partnerSharing`, `.notifications`, `.appLock`, `.account`
- [ ] `TrackerSettingsView` renders a `List` with 5 sections: "CYCLE", "PARTNER", "NOTIFICATIONS", "PRIVACY", "ACCOUNT"; each section header uses `caption2` uppercased `CadenceTextSecondary` style
- [ ] Each row in `TrackerSettingsView` uses `NavigationLink(value: SettingsDestination)` -- no `NavigationLink(destination:)` form (deprecated pattern)
- [ ] `navigationDestination(for: SettingsDestination.self)` routes `.cycleDefaults` to `CycleDefaultsView`, `.partnerSharing` to `PartnerManagementView` or `InviteCodeView` (per S4 condition), `.notifications` to `NotificationSettingsView`, `.appLock` to `AppLockView` (PH-12-E2), `.account` to `AccountView` (PH-12-E3)
- [ ] The Phase 4 Settings tab stub is replaced by `TrackerSettingsView`; the tab bar still shows the Settings tab (position 5, `gearshape.fill` active icon per Design Spec §9) correctly
- [ ] No `AnyView` in the view or its routing (swiftui-production constraint)
- [ ] `SettingsDestination.swift` and `TrackerSettingsView.swift` are added to `project.yml`; `xcodegen generate` exits 0
- [ ] No hardcoded hex colors; all colors via `Color("CadenceTokenName")`

**Dependencies:** None (routing destinations are stubs that will be implemented in subsequent stories and epics)
**Notes:** If Phase 4's `TrackerTabView` uses a `NavigationStack` shared across all tabs rather than per-tab stacks, `TrackerSettingsView` must append `navigationDestination(for: SettingsDestination.self)` to the shared stack. Inspect Phase 4 before committing to an approach. The `cadence-navigation` skill requires `NavigationStack + navigationDestination` for all push navigation.

---

### S2: CycleDefaultsView -- Form with Stepper and Picker Controls

**Story ID:** PH-12-E1-S2
**Points:** 3

Implement `CycleDefaultsView` and `CycleDefaultsViewModel`. The view reads the Tracker's `CycleProfile` from SwiftData on appear and renders three controls: average cycle length stepper, average period length stepper, goal mode segmented picker. Changes are reflected optimistically in the UI.

**Acceptance Criteria:**

- [ ] `CycleDefaultsView` is a `Form`-based view navigable from `TrackerSettingsView` via `SettingsDestination.cycleDefaults`
- [ ] Average cycle length `Stepper` renders with label `"Average cycle length"` and a trailing `Text` reading `"\(avgCycleLength) days"`; range is 21-35 inclusive; tapping the stepper increments/decrements by 1
- [ ] Average period length `Stepper` renders with label `"Average period length"` and trailing `Text` reading `"\(avgPeriodLength) days"`; range is 2-10 inclusive
- [ ] Goal mode `Picker` uses `pickerStyle(.segmented)` with two segments: `"Track cycle"` and `"Trying to conceive"`, bound to `CycleDefaultsViewModel.goalMode`
- [ ] All three controls are bound to `CycleDefaultsViewModel` properties; changes are reflected immediately in the UI without requiring an explicit save tap
- [ ] `CycleDefaultsViewModel` is `@Observable`; no `ObservableObject` or `@Published` usage
- [ ] Text labels use system type tokens (`body`, `subheadline`); no fixed-size text
- [ ] A "Save" `NavigationBarItem` button (trailing) triggers `CycleDefaultsViewModel.save()` and pops the view on success; the button shows an inline `ProgressView` while the async save is in flight (Primary CTA Button loading pattern per Design Spec §10.3)
- [ ] `CycleDefaultsView.swift` and `CycleDefaultsViewModel.swift` added to `project.yml`

**Dependencies:** PH-12-E1-S1 (navigation routing exists for `.cycleDefaults`)
**Notes:** The form uses `List`-style grouping via `Form` -- do not use a `VStack` manually. `Form` on iOS 26 renders with the system's inset-grouped style automatically.

---

### S3: Cycle Defaults Persistence via SyncCoordinator

**Story ID:** PH-12-E1-S3
**Points:** 3

Implement `CycleDefaultsViewModel.save() async throws`. Mutate the fetched `CycleProfile` SwiftData instance with the current stepper/picker values, call `context.save()`, and enqueue a SyncCoordinator write to Supabase `cycle_profiles`. If `avgCycleLength` changed, trigger the Phase 3 prediction engine's recalculate path to refresh `prediction_snapshots`.

**Acceptance Criteria:**

- [ ] `CycleDefaultsViewModel.save()` mutates the existing `CycleProfile` instance (does not insert a new row); only the changed fields are modified
- [ ] `ModelContext.save()` is called after mutation; on failure, a typed error is thrown and the UI remains on `CycleDefaultsView` with an error toast (Design Spec §13 error pattern)
- [ ] A SyncCoordinator write is enqueued for `cycle_profiles` within the same call as the local save (local-first, per cadence-sync skill)
- [ ] If `avgCycleLength` differs from the value loaded on init, the Phase 3 prediction engine's recalculate method is called after the local save; `prediction_snapshots` are refreshed before the view pops
- [ ] If only `goalMode` or `avgPeriodLength` changed (not `avgCycleLength`), no prediction recalculation is triggered
- [ ] On successful save, `CycleDefaultsView` pops from the navigation stack
- [ ] Unit test: inject a mock SwiftData context and mock SyncCoordinator; call `save()` with a changed `avgCycleLength`; verify `context.save()` was called and SyncCoordinator enqueued a write for `cycle_profiles`
- [ ] Unit test: inject mock where `avgCycleLength` is unchanged but `goalMode` changed; verify prediction engine recalculate is NOT called

**Dependencies:** PH-12-E1-S2, PH-3 (CycleProfile SwiftData model), PH-7 (SyncCoordinator write queue)
**Notes:** `CycleDefaultsViewModel` fetches the `CycleProfile` on init using `@Query` or a direct `ModelContext.fetch(FetchDescriptor<CycleProfile>())`. There is exactly one `CycleProfile` per user. If the fetch returns nil (edge case: no profile exists), `save()` inserts a new row with current stepper values.

---

### S4: Partner Sharing Settings Section -- Conditional Invite vs. Management Navigation

**Story ID:** PH-12-E1-S4
**Points:** 2

Implement the "PARTNER" section in `TrackerSettingsView`. The section content adapts based on `PartnerConnectionStore.connectionStatus`: no connection shows an "Invite a Partner" row that navigates to `InviteCodeView`; any connection state shows a "Partner Sharing" row with a status indicator that navigates to `PartnerManagementView`. Both navigate via `SettingsDestination.partnerSharing`.

**Acceptance Criteria:**

- [ ] When `PartnerConnectionStore.connectionStatus == .none`, the "PARTNER" section renders one row: `"Invite a Partner"` with a `plus.circle` SF Symbol leading icon in `CadenceTerracotta` and a disclosure indicator; tapping navigates to `InviteCodeView` (PH-8-E1-S4)
- [ ] When `connectionStatus == .pendingCode(...)`, the row renders `"Partner Sharing"` with label `"Code sent"` as trailing detail in `CadenceTextSecondary` and a `circle.fill` icon tinted `CadenceTextSecondary`; tapping navigates to `PartnerManagementView` (PH-8-E3)
- [ ] When `connectionStatus == .active`, the row renders `"Partner Sharing"` with the Partner's display name as trailing detail and a `circle.fill` icon tinted `CadenceSage`; tapping navigates to `PartnerManagementView` (PH-8-E3)
- [ ] `PartnerConnectionStore` is read from `@Environment` -- no direct init parameter (injectable for testing)
- [ ] The `navigationDestination(for: SettingsDestination.self)` block switches between `InviteCodeView` and `PartnerManagementView` based on `connectionStatus` at the time of navigation
- [ ] The section adapts dynamically: if a Partner connects while the Settings view is visible, the row updates without requiring a navigation pop-and-repush (driven by `@Observable` `PartnerConnectionStore`)

**Dependencies:** PH-12-E1-S1, PH-8-E1-S4 (InviteCodeView), PH-8-E3-S3 (PartnerManagementView)
**Notes:** Do not duplicate the status determination logic that already exists in `PartnerConnectionStore`. Read `connectionStatus` directly; do not re-query Supabase in this view.

---

### S5: Notifications Settings Section + PartnerNotificationControls Visibility

**Story ID:** PH-12-E1-S5
**Points:** 2

Implement the "NOTIFICATIONS" section in `TrackerSettingsView` that navigates to `NotificationSettingsView` (Phase 10). Pass the Partner connection active state to `NotificationSettingsView` so it can conditionally render `PartnerNotificationControlsView` per PH-10-E4-S4's documented interface.

**Acceptance Criteria:**

- [ ] The "NOTIFICATIONS" section in `TrackerSettingsView` renders one row: `"Notifications"` with a `bell` SF Symbol leading icon; tapping navigates to `NotificationSettingsView` (PH-10-E4-S5)
- [ ] `NotificationSettingsView` receives `isPartnerConnected: Bool` as an init parameter (or via environment); `isPartnerConnected` is `true` only when `PartnerConnectionStore.connectionStatus == .active`
- [ ] When `isPartnerConnected == true`, `NotificationSettingsView` renders both `NotificationRemindersView` and `PartnerNotificationControlsView` sections per PH-10-E4-S5
- [ ] When `isPartnerConnected == false`, `NotificationSettingsView` renders only `NotificationRemindersView`; `PartnerNotificationControlsView` is not rendered (not just hidden -- not in the view hierarchy)
- [ ] The `NotificationSettingsView` nav title renders correctly without double-title when pushed from `TrackerSettingsView` (standard `NavigationStack` push behavior)
- [ ] No hardcoded hex in any view introduced or modified in this story

**Dependencies:** PH-12-E1-S1, PH-10-E4-S5 (NotificationSettingsView), PH-8-E1-S2 (PartnerConnectionStore)
**Notes:** If PH-10-E4's `NotificationSettingsView` does not accept `isPartnerConnected` as a parameter (Phase 10 noted that Phase 12 would control the conditional -- verify PH-10-E4-S4 interface comment), add the parameter to `NotificationSettingsView` in this story. This is a one-line addition to the Phase 10 view's init; it does not constitute re-implementing Phase 10 scope.

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
- [ ] Integration verified end-to-end: tapping "Cycle Defaults" in Tracker Settings opens `CycleDefaultsView`; saving a new `avgCycleLength` value updates the live Supabase `cycle_profiles` row and triggers a prediction recalculation visible on the Tracker Home dashboard
- [ ] Integration verified: tapping "Partner Sharing" when connected navigates to the full `PartnerManagementView` with all 6 permission toggles rendered and functional
- [ ] Integration verified: tapping "Notifications" opens `NotificationSettingsView` with `PartnerNotificationControlsView` visible only when a Partner is active
- [ ] Phase objective is advanced: a Tracker can access all configuration surfaces from the Settings tab
- [ ] Applicable skill constraints satisfied: swiftui-production (@Observable, no AnyView, no force unwraps), cadence-design-system (no hardcoded hex, section eyebrow style per Design Spec §4), cadence-navigation (NavigationStack + navigationDestination, no custom transitions), cadence-xcode-project (project.yml updated for all new files)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility: all `NavigationLink` rows have 44pt minimum touch target; row labels are descriptive for VoiceOver (no "row 1" labels)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Settings tab section structure matches MVP Spec §11 Tracker settings list

## Source References

- PHASES.md: Phase 12 -- Settings (primary goal, in-scope list, sequencing rationale)
- MVP Spec §11 (Privacy and Settings -- full Tracker settings list: cycle defaults, partner sharing controls, reminder preferences, app lock, delete all data)
- Design Spec v1.1 §8 (Information Architecture -- Tracker tab 5 Settings: partner management, sharing permissions, account, notifications)
- Design Spec v1.1 §4 (Typography -- caption2 for eyebrow labels)
- PH-8-E1 (InviteCodeView -- source of the invite section destination)
- PH-8-E3 (PartnerManagementView -- source of the permission management destination)
- PH-10-E4 (NotificationSettingsView -- source of the notifications destination)
- cadence-navigation skill (NavigationStack + navigationDestination contract, push navigation rule)
- swiftui-production skill (@Observable, AnyView ban, view extraction)
