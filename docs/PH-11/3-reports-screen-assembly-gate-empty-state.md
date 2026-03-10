# Reports Screen Assembly, Gate Logic & Empty State

**Epic ID:** PH-11-E3
**Phase:** 11 -- Reports
**Estimated Size:** M
**Status:** Draft

---

## Objective

Compose `ReportsView` -- the full Reports tab screen -- by wiring `ReportsViewModel` to the metric components from PH-11-E2, implementing the 2-cycle minimum gate rendering branch, and building the empty state view specified in Design Spec §13. On completion, the Reports tab is a fully functional screen a Tracker can navigate to and read meaningful cycle intelligence from, or receive a clear explanation of what will appear once sufficient data exists.

## Problem / Context

PH-11-E1 produces data. PH-11-E2 produces components. Neither produces a navigable, end-to-end screen. This epic is the integration layer: it connects the ViewModel to the view hierarchy, implements the gate condition that branches between the populated reports layout and the empty state, handles loading and offline indicator states, and ensures the tab chrome (icon, NavigationStack title) is correctly wired per Phase 4 nav shell conventions.

Without this epic, the Reports tab remains a placeholder shell registered in the Phase 4 nav shell but showing no content.

Sources: Design Spec v1.1 §13 (empty state for Reports < 2 cycles), §8 (Reports tab position 4 in Tracker navigation), §9 (tab icon `chart.bar.fill` tinted CadenceTerracotta); MVP Spec §10 (2-cycle gate requirement); cadence-navigation skill (NavigationStack + navigationDestination, no selected-tab mutation for Log center tab); cadence-data-layer skill (display requirement: disclaimer on prediction-adjacent content).

## Scope

### In Scope

- `ReportsView` as the root SwiftUI view for tab position 4 in the Tracker `TabView`, using `NavigationStack`
- Navigation bar title "Reports" in `Color("CadenceTextPrimary")`, large title style
- `.task` modifier on `ReportsView` that calls `ReportsViewModel.refresh()` on first appearance and on `scenePhase` `.active` transition
- 2-cycle gate rendering logic: `if viewModel.isGated { ReportsEmptyStateView() } else { ReportsContentView(metrics: viewModel.metrics!) }`
- `ReportsEmptyStateView`: centered SF Symbol + body text per Design Spec §13 spec ("Your reports will appear here once you've logged 2 full cycles.")
- `ReportsContentView`: `ScrollView` with `LazyVStack(spacing: CadenceSpacing.space16)` containing all five metric sections from PH-11-E2 plus `ReportsDisclaimerFooter`
- Section header labels above each metric group (e.g., "AVERAGES", "RECENT CYCLES", "CONSISTENCY", "SYMPTOMS") in `subheadline` token, `Color("CadenceTextSecondary")`, uppercased
- Offline indicator in the navigation bar area: "Last updated [relative time]" in `caption1`, `Color("CadenceTextSecondary")`, visible when `SyncCoordinator.isOffline == true` (per Design Spec §13 offline state spec)
- Loading state: `ReportsViewModel.isLoading == true` shows skeleton versions of each component (delegated to each component's own skeleton implementation from PH-11-E2)
- `ReportsView` registered in `project.yml` and `Cadence/Reports/` source group

### Out of Scope

- Chart component implementation (PH-11-E2)
- Metric computation logic (PH-11-E1)
- Drill-down navigation from any report card or chart bar (not specified in source documents)
- Reports content for the Partner role (Partner has no Reports tab per Design Spec §8)
- Share sheet or export from Reports (MVP Spec Out of Scope for Beta)
- Reports push notification or badge count (not specified)

## Dependencies

| Dependency                                                                                                                                         | Type | Phase/Epic | Status   | Risk   |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | -------- | ------ |
| `ReportsViewModel` with `isGated`, `isLoading`, `metrics` implemented and gate logic correct                                                       | FS   | PH-11-E1   | Open     | Low    |
| All five metric components built: `CycleStatCard`, `RecentCyclesChart`, `CycleConsistencyCard`, `SymptomFrequencyChart`, `ReportsDisclaimerFooter` | FS   | PH-11-E2   | Open     | Medium |
| Tracker `TabView` shell with Reports tab at position 4 registered                                                                                  | FS   | PH-4       | Resolved | Low    |
| `SyncCoordinator.isOffline: Bool` published property available                                                                                     | FS   | PH-7       | Resolved | Low    |
| `NavigationStack` + `navigationDestination` pattern established in Tracker nav tree                                                                | FS   | PH-4       | Resolved | Low    |

## Assumptions

- `ReportsViewModel` is injected into `ReportsView` via `.environment` on the Reports tab's root view in the Phase 4 `TabView` -- consistent with the injection pattern used by other tab ViewModels in the Tracker shell.
- `ReportsContentView` is a private sub-view of `ReportsView`, extracted to stay under the 50-line view extraction rule from the swiftui-production skill.
- The empty state SF Symbol is `chart.bar` (matching the Reports tab icon from Design Spec §9) at a display size of 60pt, tinted `Color("CadenceTextSecondary")`. The spec says "appropriate SF Symbol illustration" without naming the symbol; `chart.bar` is the canonical choice given the tab identity.
- "Last updated [relative time]" uses `RelativeDateTimeFormatter` with `.naturalLanguage` style applied to `SyncCoordinator.lastSyncDate`. If `lastSyncDate == nil`, the indicator is not shown.
- `ReportsContentView` does not force-unwrap `viewModel.metrics!` in production code. The guard `!viewModel.isGated` guarantees non-nil `metrics` when the content branch is reached, but the unwrap should use `guard let metrics = viewModel.metrics else { return }` inside the content view's `body`.

## Risks

| Risk                                                                                                    | Likelihood | Impact | Mitigation                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --- | ---------------- |
| `viewModel.metrics` is `nil` when `isGated == false` due to a race condition in `refresh()`             | Low        | Medium | Show loading skeleton when `metrics == nil && !isGated`; `refresh()` populates `metrics` before setting `isLoading = false`. Unit test the state machine: isLoading -> (isGated |     | metrics != nil). |
| `LazyVStack` with Swift Charts views causes off-screen chart pre-rendering degrading scroll performance | Low        | Low    | Swift Charts renders lazily by default inside `LazyVStack`. Verify scroll FPS on iPhone SE (smallest supported device) before declaring done.                                   |
| `SyncCoordinator.isOffline` not yet published as an observable property (implementation detail of PH-7) | Medium     | Low    | If not yet published, add `@Published var isOffline: Bool` to `SyncCoordinator` in PH-7 scope. Flag if missing before E3-S6 implementation.                                     |

---

## Stories

### S1: `ReportsView` Container with NavigationStack and Tab Registration

**Story ID:** PH-11-E3-S1
**Points:** 2

Create `ReportsView.swift` under `Cadence/Reports/` and register it in `project.yml`. Wire the view to `ReportsViewModel` via `@Environment`. Establish the `NavigationStack` shell and large-title navigation bar title "Reports". No content beyond a placeholder `Text("Reports")` is needed in this story -- that is S4.

**Acceptance Criteria:**

- [ ] `Cadence/Reports/ReportsView.swift` exists and is listed under the `Reports` source group in `project.yml`
- [ ] `xcodegen generate` completes without error after this file is added
- [ ] `ReportsView` has a `@Environment(ReportsViewModelProtocol.self) var viewModel` property
- [ ] `ReportsView.body` wraps content in a `NavigationStack`
- [ ] Navigation bar title is "Reports" using `.navigationTitle("Reports")` with `.navigationBarTitleDisplayMode(.large)`
- [ ] The tab item is declared as `Label("Reports", systemImage: "chart.bar")` per Design Spec §9; when selected, the active icon is `chart.bar.fill` tinted via `.tint(Color("CadenceTerracotta"))` on the `TabView` (already set in PH-4 shell)
- [ ] Build compiles; Reports tab is navigable in the simulator and shows "Reports" title

**Dependencies:** PH-4 (Tracker TabView shell), PH-11-E1-S1 (`ReportsViewModelProtocol` defined)
**Notes:** The tab item configuration (icon, label) must match Design Spec §9 exactly. Do not introduce a new `.tint` modifier in `ReportsView` -- the CadenceTerracotta tint is set once on the `TabView` in the Phase 4 shell and inherited by all tabs.

---

### S2: 2-Cycle Gate Rendering Logic

**Story ID:** PH-11-E3-S2
**Points:** 2

Implement the rendering branch inside `ReportsView.body` that switches between `ReportsEmptyStateView` (when `viewModel.isGated == true`) and `ReportsContentView` (when `viewModel.isGated == false` and `viewModel.metrics != nil`). Handle the loading state branch (when `viewModel.isLoading == true`) as a third distinct branch showing skeleton components.

**Acceptance Criteria:**

- [ ] When `viewModel.isLoading == true`: body renders skeleton versions of the metric components via `ReportsContentView(metrics: nil)` (nil propagates skeleton display to each component)
- [ ] When `viewModel.isLoading == false && viewModel.isGated == true`: body renders `ReportsEmptyStateView`
- [ ] When `viewModel.isLoading == false && viewModel.isGated == false && viewModel.metrics != nil`: body renders `ReportsContentView(metrics: viewModel.metrics!)`
- [ ] When `viewModel.isLoading == false && viewModel.isGated == false && viewModel.metrics == nil`: body renders skeleton (same as loading branch) -- this is a defensive guard for the race condition identified in Risks
- [ ] State transitions between branches are animated with `.animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)` and `.animation(.easeInOut(duration: 0.25), value: viewModel.isGated)` -- consistent with Partner Dashboard hide crossfade spec in cadence-motion skill
- [ ] Animations are gated on `@Environment(\.accessibilityReduceMotion)`: when true, transitions are instant
- [ ] Unit test using `MockReportsViewModel`: cycling through (isLoading: true), (isLoading: false, isGated: true), (isLoading: false, isGated: false, metrics: populated) -- verify the correct branch is selected in each case

**Dependencies:** PH-11-E3-S1, PH-11-E1 (all stories complete for ViewModel state correctness)
**Notes:** Pass `metrics: ReportMetrics?` to `ReportsContentView` rather than forcing an unwrap at the branch point. `ReportsContentView` guards internally and shows skeletons when `metrics == nil`. This pattern avoids the force-unwrap while keeping the gate logic readable.

---

### S3: `ReportsEmptyStateView`

**Story ID:** PH-11-E3-S3
**Points:** 2

Build the empty state view shown when fewer than 2 completed cycles exist. Spec source: Design Spec §13 -- "Your reports will appear here once you've logged 2 full cycles." body, CadenceTextSecondary, centered with appropriate SF Symbol illustration.

Layout (centered vertically and horizontally in the available space):

- `Image(systemName: "chart.bar")` at 60pt, `Color("CadenceTextSecondary")`, `accessibilityHidden(true)` (decorative)
- `Text("Your reports will appear here once you've logged 2 full cycles.")` in `body` type token, `Color("CadenceTextSecondary")`, `.multilineTextAlignment(.center)`, max width 280pt

**Acceptance Criteria:**

- [ ] `ReportsEmptyStateView` is a standalone SwiftUI view file at `Cadence/Reports/ReportsEmptyStateView.swift`
- [ ] SF Symbol `chart.bar` renders at 60pt image size (`.font(.system(size: 60))`), tinted `Color("CadenceTextSecondary")`
- [ ] SF Symbol has `accessibilityHidden(true)` (it is decorative; the text below conveys the state)
- [ ] Body text is exactly: "Your reports will appear here once you've logged 2 full cycles." -- no deviation from Design Spec §13
- [ ] Text uses `body` type token, `Color("CadenceTextSecondary")`, centered alignment, max width 280pt via `.frame(maxWidth: 280)`
- [ ] The view fills the available space and centers its content vertically using `VStack { Spacer(); content; Spacer() }`
- [ ] No hardcoded hex values; `no-hex-in-swift` hook exits 0
- [ ] VoiceOver: the `Text` label is the accessible description of the empty state; no additional `accessibilityLabel` needed
- [ ] SwiftUI Preview renders correctly at Default and Accessibility1 Dynamic Type sizes

**Dependencies:** PH-11-E3-S1
**Notes:** The body text is verbatim from Design Spec §13. Do not paraphrase or rewrite it. The SF Symbol choice `chart.bar` is an assumption (see Assumptions section). If Dinesh designates a different symbol, update both the symbol name and this story's acceptance criterion.

---

### S4: `ReportsContentView` ScrollView Assembly

**Story ID:** PH-11-E3-S4
**Points:** 3

Build `ReportsContentView` as the populated reports layout: a `ScrollView` containing a `LazyVStack` of all five metric sections. Sections are separated by section headers and `CadenceSpacing.space16` inter-section spacing. `ReportsDisclaimerFooter` appears at the bottom of the stack.

Layout order (top to bottom):

1. Section header "AVERAGES"
2. `CycleStatCard` for average cycle length
3. `CycleStatCard` for average period length
4. Section header "RECENT CYCLES"
5. `RecentCyclesChart`
6. Section header "CONSISTENCY"
7. `CycleConsistencyCard`
8. Section header "SYMPTOMS BY PHASE"
9. `SymptomFrequencyChart`
10. `ReportsDisclaimerFooter`

**Acceptance Criteria:**

- [ ] `ReportsContentView` accepts `metrics: ReportMetrics?`; when `metrics == nil`, each sub-component receives `nil`/skeleton inputs
- [ ] Content is wrapped in `ScrollView(.vertical, showsIndicators: false)` containing `LazyVStack(alignment: .leading, spacing: CadenceSpacing.space16)`
- [ ] Four section headers render as uppercased strings in `subheadline` type token, `Color("CadenceTextSecondary")`; no hardcoded hex
- [ ] Horizontal padding on the `LazyVStack`: `CadenceSpacing.space16` on both sides
- [ ] `CycleStatCard` for cycle length: `value: metrics?.averageCycleLengthDays ?? 0`, `unit: "days"`, `label: "Avg cycle length"`, `cyclesUsed: metrics?.cyclesUsed ?? 0`
- [ ] `CycleStatCard` for period length: `value: metrics?.averagePeriodLengthDays ?? 0`, `unit: "days"`, `label: "Avg period length"`, `cyclesUsed: metrics?.cyclesUsed ?? 0`
- [ ] `RecentCyclesChart`: `recentCycles: metrics?.recentCycles ?? []`, `averageCycleLengthDays: metrics?.averageCycleLengthDays ?? 0`
- [ ] `CycleConsistencyCard`: `consistency: metrics?.consistency ?? .irregular`, `standardDeviationDays: metrics?.consistencyStandardDeviationDays ?? 0.0`
- [ ] `SymptomFrequencyChart`: `symptomFrequency: metrics?.symptomFrequency ?? []`
- [ ] `ReportsDisclaimerFooter` appears as the final element in the `LazyVStack`
- [ ] `LazyVStack` bottom padding: `CadenceSpacing.space32` to clear the Liquid Glass tab bar
- [ ] SwiftUI Preview shows both the skeleton state (metrics: nil) and the populated state (metrics: sample `ReportMetrics`)

**Dependencies:** PH-11-E3-S2, PH-11-E2 (all stories complete)
**Notes:** `LazyVStack` is mandatory per swiftui-production skill for all feed/list views. Do not use `VStack` here even though the content count is fixed -- `LazyVStack` prevents unnecessary view construction for off-screen chart components. Section header strings are all-caps display strings, not localization keys for beta; use `.uppercased()` in the view rather than storing uppercased strings in a constant.

---

### S5: `.task` Refresh and Scene Phase Foreground Trigger

**Story ID:** PH-11-E3-S5
**Points:** 2

Wire the data refresh lifecycle: call `viewModel.refresh()` on initial view appearance via `.task` and on each `scenePhase` transition to `.active` via `.onChange(of: scenePhase)`. This ensures the Reports screen always reflects the latest local data after the user backgrounds and returns to the app.

**Acceptance Criteria:**

- [ ] `ReportsView.body` has a `.task { await viewModel.refresh() }` modifier that fires once on initial appearance
- [ ] `ReportsView` reads `@Environment(\.scenePhase) var scenePhase`
- [ ] `.onChange(of: scenePhase) { _, newPhase in if newPhase == .active { Task { await viewModel.refresh() } } }` is applied to `ReportsView.body`
- [ ] `viewModel.refresh()` is not called redundantly when `scenePhase` changes to `.active` on the very first appearance (the `.task` fires first; the `scenePhase` handler fires on subsequent foreground events only)
- [ ] Unit test using `MockReportsViewModel`: verify `refresh()` is called exactly once on initial appearance and once more on a simulated `.active` transition after initial load
- [ ] `viewModel.isLoading` is set to `true` at the start of `refresh()` and `false` on completion in the `ReportsViewModel` implementation (verified via MockReportsViewModel tracking)

**Dependencies:** PH-11-E3-S2, PH-11-E1 (full ReportsViewModel)
**Notes:** The `.task` modifier cancels and re-runs if the view is dismissed and re-presented. This is the correct behavior -- the Reports tab is a persistent tab, not a sheet, so this case does not arise in normal navigation. `.onChange(of:)` with the two-argument closure form is required for iOS 17+ compatibility; the one-argument form is deprecated.

---

### S6: Offline Indicator in Navigation Bar

**Story ID:** PH-11-E3-S6
**Points:** 1

Display a non-blocking offline indicator below the navigation bar when `SyncCoordinator.isOffline == true`, per Design Spec §13 ("Footnote 'Last updated [time]' appears in navigation bar area. Non-blocking toast for queued writes.").

**Acceptance Criteria:**

- [ ] When `SyncCoordinator.isOffline == true` and `SyncCoordinator.lastSyncDate != nil`: a `Text("Last updated \(lastSyncDate, style: .relative) ago")` label renders in `caption1` token, `Color("CadenceTextSecondary")`, pinned below the navigation bar title using `.safeAreaInset(edge: .top)`
- [ ] When `SyncCoordinator.isOffline == false`: the indicator is hidden; transition uses `.animation(.easeInOut(duration: 0.2), value: syncCoordinator.isOffline)` -- gated on `accessibilityReduceMotion` (instant when true)
- [ ] When `SyncCoordinator.lastSyncDate == nil`: the indicator is not shown even if `isOffline == true`
- [ ] The indicator does not overlap or displace any metric card content (`.safeAreaInset` handles layout correctly)
- [ ] No hardcoded hex values; text color uses `Color("CadenceTextSecondary")`

**Dependencies:** PH-11-E3-S1, PH-7 (SyncCoordinator.isOffline and lastSyncDate properties)
**Notes:** Design Spec §13 says the offline indicator "appears in navigation bar area" -- `.safeAreaInset(edge: .top)` with a small-height view is the correct SwiftUI implementation for a persistent sub-navigation-bar indicator. Do not use a `.toolbar` item, which would appear inside the navigation bar and displace other bar content.

---

## Story Point Reference

| Points | Meaning                                                                                       |
| ------ | --------------------------------------------------------------------------------------------- |
| 1      | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour.                  |
| 2      | Small. One component or function, minimal unknowns. Half a day.                               |
| 3      | Medium. Multiple files, some integration. One day.                                            |
| 5      | Significant. Cross-cutting concern, multiple components, multiple testing required. 2-3 days. |
| 8      | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days.               |
| 13     | Very large. Should rarely appear. If it does, consider splitting the story. A week.           |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] End-to-end integration verified: a Tracker account with 2+ completed `PeriodLog` records in local SwiftData can navigate to the Reports tab and see all five metric sections populated with correct values
- [ ] End-to-end integration verified: a Tracker account with 0 or 1 completed `PeriodLog` records sees the empty state view with the exact Design Spec §13 copy
- [ ] Loading skeleton renders for each metric component during `refresh()` and transitions to populated state without layout shift
- [ ] Offline indicator appears and disappears correctly per `SyncCoordinator.isOffline` state on a device with airplane mode toggled
- [ ] Phase objective achieved: Phase 11 completion standard satisfied -- "A Tracker with 2+ completed cycles can view meaningful cycle history reports; a Tracker below the threshold sees a clear empty state explaining what will appear"
- [ ] Applicable skill constraints satisfied: cadence-navigation (NavigationStack in Tracker tree, no Log tab mutation), cadence-design-system (all color tokens from xcassets, no hardcoded hex, spacing tokens), cadence-accessibility (Dynamic Type on all text, VoiceOver on empty state, reduceMotion gating on transitions), cadence-motion (0.25s easeInOut crossfade on gate branch switch per Partner Dashboard hide pattern), swiftui-production (LazyVStack for content stack, view extraction, no AnyView, no force unwraps)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] `no-hex-in-swift` hook exits 0 on all files in this epic
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 11 -- Reports (in-scope: 2-cycle minimum gate, empty state, Reports tab content assembly; completion standard)
- Design Spec v1.1 §8: Tracker Navigation IA (Reports at tab position 4, content description "Cycle history charts, pattern insights (unlocked after 2 full cycles)")
- Design Spec v1.1 §9: Tab Bar Icons (Reports: `chart.bar` / `chart.bar.fill`, active state `chart.bar.fill` tinted CadenceTerracotta)
- Design Spec v1.1 §13: States & Feedback (empty state spec for Reports < 2 cycles; offline indicator: "Last updated [time]" in navigation bar area; loading: skeleton on card surfaces)
- MVP Spec §10: History and Reports (2-cycle gate requirement; 5 report card types)
- cadence-navigation skill (NavigationStack + navigationDestination, Tracker tab role, no Log tab selectedTab mutation)
- cadence-motion skill (0.25s easeInOut crossfade for hide/show transitions; skeleton shimmer delegated to E2 components; reduceMotion gating)
- cadence-accessibility skill (Dynamic Type enforcement, VoiceOver on empty state, reduceMotion environment variable)
- swiftui-production skill (LazyVStack for feed views, view extraction at 50-line boundary, no AnyView, no force unwraps)
- cadence-data-layer skill (display requirement: prediction disclaimer on all prediction-adjacent content)
