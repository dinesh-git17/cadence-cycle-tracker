# TrackerShell -- 5-Tab Navigation with Liquid Glass Chrome

**Epic ID:** PH-4-E1
**Phase:** 4 -- Tracker Navigation Shell & Core Logging
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement `TrackerShell.swift`: the 5-tab `TabView` with per-tab `NavigationStack`, the Log-tab modal intercept (ensuring `selectedTab` never persists at `.log`), the permanently-terracotta center Log button identity within the Liquid Glass tab bar, and the empty root content views for all four navigable tabs. This shell is the structural container every Phase 5, 6, 11, and 12 surface is placed inside -- it must compile, navigate, and intercept correctly before any tab content is built.

## Problem / Context

Phase 2 ends when the user lands at the base of the navigation shell after onboarding. That landing is `TrackerShell`. Without a correct shell, every subsequent phase has no container, no navigation tree, and no Log Sheet entry point. Getting the shell wrong -- wrapping `TabView` in a `NavigationStack`, sharing a `NavigationPath` across tabs, or allowing `selectedTab` to persist at `.log` -- compounds through all 8 downstream phases and produces hard-to-diagnose routing regressions.

The Log tab intercept is the most failure-prone pattern in Cadence's navigation architecture. iOS 26 `TabView` with the structural `Tab` API fires `selectedTab` updates synchronously -- the `onChange(of: selectedTab)` handler must revert to `previousTab` in the same run-loop turn. Any async delay in the revert produces a visible flash on the Log tab icon and a broken navigation state. The cadence-navigation skill §2 defines the exact `onChange` body that satisfies this requirement.

The permanently-terracotta Log button (`plus.circle.fill`) cannot be achieved by setting `.tint(CadenceTerracotta)` on the `TabView` alone -- that only affects the currently-active tab icon. The center button must maintain its fill at all times, which requires an explicit `.foregroundStyle(Color("CadenceTerracotta"))` override on the icon inside the `Tab` label.

iOS 26 Liquid Glass on the tab bar and navigation bar is automatic when compiled with Xcode 26. The implementation goal is to preserve this behavior -- not override it. No `UITabBar.appearance()`, no `.toolbarBackground(Color(...))` on the `TabView`, no custom tab bar build.

**Source references that define scope:**

- cadence-navigation skill §2 (TrackerShell code pattern, `onChange` interceptor, `previousTab` revert, `Color.clear` Log tab content)
- cadence-navigation skill §5 (role isolation -- `TrackerShell` mounts only when `session.role == .tracker`)
- liquid-glass-ios26 skill (tab bar chrome rules, center Log button permanent terracotta, `.tint()` placement, anti-pattern list)
- Design Spec v1.1 §8 (Tracker navigation IA -- 5 tabs, positions, SF Symbols)
- Design Spec v1.1 §9 (Tab bar icons -- `house.fill`, `calendar`, `plus.circle.fill`, `chart.bar.fill`, `gearshape.fill`; active tint CadenceTerracotta)
- PHASES.md Phase 4 in-scope: "5-tab TabView: Home, Calendar, Log (center, modal intercept), Reports, Settings; Liquid Glass tab bar and nav bar; NavigationStack + navigationDestination for Tracker tree"

## Scope

### In Scope

- `Cadence/Views/Tracker/TrackerShell.swift`: `TrackerTab` enum (`.home`, `.calendar`, `.log`, `.reports`, `.settings`); `@State private var selectedTab: TrackerTab = .home`; `@State private var previousTab: TrackerTab = .home`; `@State private var isLogSheetPresented = false`; `@State private var selectedLogDate: Date = Date()`
- `TabView(selection: $selectedTab)` with 5 `Tab` entries using the structural `Tab("Label", systemImage: symbol, value: TrackerTab.*)` API -- no deprecated `tabItem(_:)` modifier
- `.tint(Color("CadenceTerracotta"))` on the `TabView` for active-tab icon tint
- Log tab (`TrackerTab.log`) content: `Color.clear` (unreachable as navigation destination)
- Log tab label override: explicit `.foregroundStyle(Color("CadenceTerracotta"))` on `Image(systemName: "plus.circle.fill")` to maintain permanent terracotta fill regardless of selection state
- `.onChange(of: selectedTab)` handler: reverts `selectedTab` to `previousTab` synchronously when new value is `.log`; sets `isLogSheetPresented = true`; updates `previousTab` for all non-Log selections
- `.sheet(isPresented: $isLogSheetPresented)` registration on `TrackerShell` with `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)` -- `LogSheetView` is passed `date: selectedLogDate` and `onSave` callback
- Per-tab `NavigationStack` wrapping each tab's root content view -- `TrackerShell` is NOT wrapped in an outer `NavigationStack`
- Route enum `TrackerRoute: Hashable` defined in `Cadence/Models/TrackerRoute.swift` with the routes needed for Phase 4 (Settings-level routes deferred to Phase 12; empty enum body acceptable at this stage)
- Empty root content views for all 4 navigable tabs, each in their correct source group: `TrackerHomeView.swift` (`Cadence/Views/Tracker/Home/`), `CalendarView.swift` (`Cadence/Views/Tracker/Calendar/`), `ReportsView.swift` (`Cadence/Views/Tracker/Reports/`), `TrackerSettingsView.swift` (`Cadence/Views/Tracker/Settings/`) -- each contains a single `Text("[Tab Name]").navigationTitle("[Title]")` body; these are structural entry points, not stubs
- `project.yml` updated with all new Swift file paths; `xcodegen generate` run after each file addition
- Build compiles clean with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

### Out of Scope

- `LogSheetView` implementation (Epic 2)
- `PartnerShell` (Phase 9 -- fully isolated, must not share any state with `TrackerShell`)
- Tab content views with real feature code: `TrackerHomeView` content (Phase 5), `CalendarView` content (Phase 6), `ReportsView` content (Phase 11), `TrackerSettingsView` content (Phase 12)
- Deep link handler wired to real notification routes (Phase 10 -- the `onOpenURL` handler structure is established here but no routes are live until Phase 10)
- `navigationDestination(for: TrackerRoute.self)` destinations beyond those needed in Phase 4

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| Phase 3 complete (SwiftData model layer exists; `AppSession` with role available) | FS | PH-3 | Open | High -- `TrackerShell` is mounted by role from `AppSession`; session model must exist |
| Phase 2 complete (`RootView` routing from auth to shell exists; `AppSession.role` is set on sign-in) | FS | PH-2 | Open | High -- `TrackerShell` needs a caller; Phase 2 `RootView` is that caller |
| All color assets required by the shell exist in `Colors.xcassets` (`CadenceTerracotta`) | FS | PH-0-E2 | Open | Low -- resolved in Phase 0 |
| Xcode 26 + iOS 26 simulator available for Liquid Glass verification | External | None | Open | Low -- established in Phase 0 build verification |

## Assumptions

- `AppSession` (or equivalent observable session model from Phase 2) provides `role: UserRole` as an `@Observable` property that `RootView` reads to mount the correct shell.
- `TrackerTab.log` content is `Color.clear`. Any attempt to render actual content in the Log tab destination is a navigation architecture violation per cadence-navigation skill §2.
- The `Tab(value:)` structural API (iOS 18+, back-ported to iOS 26) is the correct API for Cadence. The deprecated `tabItem(_:)` modifier must not appear.
- `previousTab` is initialized to `.home`. On first app launch, the Tracker lands on the Home tab and the first Log tap correctly reverts to `.home`.
- Empty root content views (`TrackerHomeView`, etc.) are valid production code at this stage -- they are phase gates, not stubs. Phase 5/6/11/12 fill in content without modifying the shell.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `onChange(of: selectedTab)` async revert causes visible `.log` flash | Medium | High | Revert to `previousTab` synchronously within the `onChange` body; do not dispatch to a `Task` or `DispatchQueue.main.async`; verify in simulator before marking S2 done |
| `plus.circle.fill` foregroundStyle override fights Liquid Glass tinting system | Low | Medium | Test the Log button rendering across all 4 tab-selected states in the simulator; verify the terracotta fill is persistent; reference liquid-glass-ios26 skill §Center Log Tab |
| `project.yml` not updated when new Swift files are added | Medium | High | `xcodegen-on-project-yml.sh` hook auto-runs `xcodegen` after `project.yml` edits; verify each new file appears in `xcodebuild -list` sources before moving to the next story |
| `NavigationStack` accidentally wrapping the `TabView` instead of per-tab content | Low | High | cadence-navigation §2 checklist item: "TabView is NOT wrapped in a NavigationStack"; verify with `xcodebuild build` -- misconfigured navigation creates deprecation warnings in Xcode 26 |

---

## Stories

### S1: TrackerTab enum, TrackerShell TabView, and per-tab NavigationStacks

**Story ID:** PH-4-E1-S1
**Points:** 3

Define `TrackerTab` and author the `TrackerShell` `TabView` structure with all 5 tabs using the structural `Tab` API, each tab content wrapped in its own `NavigationStack`. The shell state properties are declared but the `onChange` interceptor is added in S2.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/TrackerShell.swift` exists and contains a `struct TrackerShell: View`
- [ ] `enum TrackerTab: Hashable` is defined with cases: `.home`, `.calendar`, `.log`, `.reports`, `.settings`
- [ ] `TabView(selection: $selectedTab)` has exactly 5 `Tab(label, systemImage, value:)` entries matching Design Spec §9 symbols: `house.fill`, `calendar`, `plus.circle.fill`, `chart.bar.fill`, `gearshape.fill`
- [ ] `.tint(Color("CadenceTerracotta"))` is applied to the `TabView` -- not to individual tabs
- [ ] Log tab content is `Color.clear` -- no real content view is rendered for the log destination
- [ ] Each of the 4 navigable tabs (home, calendar, reports, settings) has its content wrapped in `NavigationStack { [RootContentView]() }`
- [ ] The `TabView` itself is NOT wrapped in a `NavigationStack`
- [ ] `@State private var selectedTab: TrackerTab = .home` declared on `TrackerShell`
- [ ] `@State private var isLogSheetPresented = false` declared on `TrackerShell`
- [ ] `@State private var selectedLogDate: Date = Date()` declared on `TrackerShell`
- [ ] `project.yml` updated with `Cadence/Views/Tracker/TrackerShell.swift`; `xcodegen generate` exits 0
- [ ] `xcodebuild build` exits 0 with no warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

**Dependencies:** PH-3 complete (AppSession accessible); PH-0-E2 (color assets exist)

**Notes:** The `Tab` structural API replaces the deprecated `.tabItem` modifier. In Xcode 26, using `.tabItem` produces a deprecation warning that becomes a build error under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. Use `Tab("Label", systemImage: "symbol", value: TrackerTab.home) { content }` syntax exclusively.

---

### S2: Log tab modal intercept and previousTab revert

**Story ID:** PH-4-E1-S2
**Points:** 3

Implement the `onChange(of: selectedTab)` interceptor that fires `isLogSheetPresented = true` and synchronously reverts `selectedTab` to `previousTab` whenever `.log` is selected. This is the behavioral heart of the center-tab pattern -- it must never allow `.log` to be the persisted tab state.

**Acceptance Criteria:**

- [ ] `@State private var previousTab: TrackerTab = .home` declared on `TrackerShell`
- [ ] `.onChange(of: selectedTab)` modifier is applied to the `TabView`
- [ ] Inside `onChange`: when `newTab == .log`, `selectedTab = previousTab` is assigned synchronously (same synchronous call, no `Task {}` wrapper) and `isLogSheetPresented = true`
- [ ] Inside `onChange`: when `newTab != .log`, `previousTab = newTab` is updated
- [ ] `.sheet(isPresented: $isLogSheetPresented)` is registered on `TrackerShell` with `LogSheetView(date: selectedLogDate, onSave: { isLogSheetPresented = false })`, `.presentationDetents([.medium, .large])`, and `.presentationDragIndicator(.visible)`
- [ ] `LogSheetView` reference resolves at compile time -- a minimal `struct LogSheetView: View` exists with `var date: Date` and `var onSave: () -> Void` parameters and `Text("Log Sheet")` body (replaced in PH-4-E2)
- [ ] Tapping the Log tab in the simulator: `selectedTab` does NOT persist at `.log` after the tap; the Log Sheet appears; the previously-selected tab icon remains highlighted
- [ ] Tapping the Log tab twice in sequence: no crash, sheet presents correctly on both taps (test with `isLogSheetPresented` already `true` -- sheet stays open; second tap is absorbed)
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E1-S1

**Notes:** The synchronous revert is critical. On iOS 26, `onChange(of:)` fires on the main actor. Assigning `selectedTab = previousTab` in the same synchronous closure body prevents the tab bar from visually landing on `.log` even for a single frame. Do not use `DispatchQueue.main.async` or `Task { @MainActor in }` -- any deferral allows the `.log` tab to render as selected.

---

### S3: Permanent terracotta Log button within Liquid Glass tab bar

**Story ID:** PH-4-E1-S3
**Points:** 2

Override the Log tab icon to maintain permanent CadenceTerracotta fill regardless of which tab is selected. The system Liquid Glass tab bar applies active/inactive tinting system-wide; the `.tint(CadenceTerracotta)` on the `TabView` tints only the active tab. The center button must be explicitly forced to terracotta at all selection states.

**Acceptance Criteria:**

- [ ] The Log tab entry uses the custom label form: `Tab(value: TrackerTab.log) { Color.clear } label: { Label { Text("Log") } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(Color("CadenceTerracotta")) } }`
- [ ] With Home tab selected, the Log tab icon is `plus.circle.fill` in CadenceTerracotta (not in the system inactive tint)
- [ ] With Calendar tab selected, the Log tab icon remains CadenceTerracotta `plus.circle.fill`
- [ ] With Reports tab selected, the Log tab icon remains CadenceTerracotta `plus.circle.fill`
- [ ] With Settings tab selected, the Log tab icon remains CadenceTerracotta `plus.circle.fill`
- [ ] No `shadow()` modifier is applied to the Log tab icon
- [ ] No `.glassEffect()` modifier is applied to the Log tab icon (it is a foreground element on the glass, not a glass element itself)
- [ ] The Log tab icon is `plus.circle.fill` -- not `plus.circle` (outline variant is prohibited per liquid-glass-ios26 anti-pattern list)
- [ ] `xcodebuild build` exits 0 after this story

**Dependencies:** PH-4-E1-S2

**Notes:** Verify the `foregroundStyle` override in the simulator. The Liquid Glass tab bar on iOS 26 can apply its own adaptive tinting to icon images. If the override does not persist in the simulator, inspect whether a `.tintAdjustmentMode` or system rendering mode is overriding the explicit `foregroundStyle`. This behavior was documented as an implementation-time verification item in the liquid-glass-ios26 skill ambiguity notes.

---

### S4: Empty root content views for all 4 navigable tabs

**Story ID:** PH-4-E1-S4
**Points:** 2

Create the four structural root content views that Phase 5, 6, 11, and 12 will populate. Each view is a minimal but valid SwiftUI view with the correct file path, `navigationTitle`, and project.yml registration. These are phase-gate files, not stubs.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/TrackerHomeView.swift` exists with `struct TrackerHomeView: View { var body: some View { Text("Home").navigationTitle("Cadence") } }`
- [ ] `Cadence/Views/Tracker/Calendar/CalendarView.swift` exists with `struct CalendarView: View { var body: some View { Text("Calendar").navigationTitle("Calendar") } }`
- [ ] `Cadence/Views/Tracker/Reports/ReportsView.swift` exists with `struct ReportsView: View { var body: some View { Text("Reports").navigationTitle("Reports") } }`
- [ ] `Cadence/Views/Tracker/Settings/TrackerSettingsView.swift` exists with `struct TrackerSettingsView: View { var body: some View { Text("Settings").navigationTitle("Settings") } }`
- [ ] All four files are added to `project.yml` under the correct source groups
- [ ] `xcodegen generate` exits 0 after all four files are added
- [ ] `xcodebuild -list` shows all four views as included sources in the `Cadence` target
- [ ] `TrackerRoute.swift` exists at `Cadence/Models/TrackerRoute.swift` with `enum TrackerRoute: Hashable {}` -- empty body is correct; routes are added as phases implement push destinations
- [ ] No force unwraps, `print()` calls, or hardcoded hex values in any of the four files

**Dependencies:** PH-4-E1-S1

**Notes:** The `navigationTitle` values are definitive per Design Spec §8: Home shows "Cadence" (brand title per §12.2 nav bar spec), Calendar shows "Calendar", Reports shows "Reports", Settings shows "Settings". Do not use generic placeholder strings like "TODO" or "Coming soon". The Text body view communicates the content context cleanly without violating CLAUDE.md's "no placeholder code" rule.

---

### S5: TrackerShell integration verification

**Story ID:** PH-4-E1-S5
**Points:** 2

Verify the complete TrackerShell navigation contract in the iOS 26 simulator: all tabs navigate correctly, the Log intercept fires reliably, the sheet opens and dismisses, and the Liquid Glass chrome is correct.

**Acceptance Criteria:**

- [ ] App launches in iOS 26 simulator and lands on the Home tab (`TrackerHomeView`)
- [ ] Tapping Calendar, Reports, and Settings tabs each navigate to their respective root content views without crash
- [ ] Tapping the Log tab center button opens the Log Sheet (`.medium` detent by default) and does not navigate to a new tab destination
- [ ] After tapping Log tab from Home, `selectedTab` remains at `.home` -- verified by confirming the Home tab icon is highlighted when the Log Sheet is open
- [ ] After tapping Log tab from Calendar, `selectedTab` remains at `.calendar` -- Calendar tab icon highlighted when Log Sheet is open
- [ ] Swiping the Log Sheet down dismisses it and returns to the previously-selected tab with no visual change to the underlying tab
- [ ] The Log tab icon (`plus.circle.fill`) is CadenceTerracotta in ALL 4 non-Log tab states
- [ ] The Liquid Glass tab bar is visible and floating above content (system material, not overridden)
- [ ] Navigation bars on Home, Calendar, Reports, and Settings tabs render with Liquid Glass material (system default)
- [ ] No `UITabBar.appearance()`, `.toolbarBackground(Color(...))`, or custom tab bar code exists anywhere in Phase 4 source files
- [ ] `scripts/protocol-zero.sh` exits 0 on all Phase 4 E1 source files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all Phase 4 E1 source files
- [ ] `xcodebuild build` exits 0 with zero warnings

**Dependencies:** PH-4-E1-S1, PH-4-E1-S2, PH-4-E1-S3, PH-4-E1-S4

**Notes:** Run the simulator verification on a physical iPhone 16 Pro simulator target (matching the CI matrix). The Liquid Glass rendering can differ between device families in the simulator. If the center Log button foregroundStyle override does not hold in the simulator, consult the liquid-glass-ios26 skill ambiguity notes and document findings before declaring S5 done.

---

## Story Point Reference

| Points | Meaning |
| --- | --- |
| 1 | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour. |
| 2 | Small. One component or function, minimal unknowns. Half a day. |
| 3 | Medium. Multiple files, some integration. One day. |
| 5 | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8 | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days. |
| 13 | Very large. Should rarely appear. If it does, consider splitting the story. A week. |

## Definition of Done

- [ ] All five stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] `selectedTab` never persists at `.log` -- verified by simulator interaction
- [ ] Log Sheet opens from center tab tap on all 4 non-Log tabs
- [ ] Liquid Glass tab bar and nav bar render correctly without custom override code
- [ ] Phase objective is advanced: a compilable, navigable 5-tab Tracker shell exists
- [ ] cadence-navigation skill §2 checklist fully satisfied
- [ ] liquid-glass-ios26 skill pre-implementation checklist fully satisfied
- [ ] cadence-xcode-project skill: all new Swift files added to `project.yml`; `.pbxproj` never edited directly
- [ ] cadence-git skill: `project.yml` and `Cadence.xcodeproj` committed in isolated `chore(project):` commits
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No force unwraps, hardcoded hex values, or `print()` calls in any committed Swift file

## Source References

- PHASES.md: Phase 4 -- Tracker Navigation Shell & Core Logging (in-scope: 5-tab TabView, Liquid Glass chrome, NavigationStack + navigationDestination)
- Design Spec v1.1 §8 (Tracker navigation IA: 5 tabs, positions, content)
- Design Spec v1.1 §9 (Tab bar icons: SF Symbols, active tint CadenceTerracotta, Log permanently filled)
- cadence-navigation skill §2 (TrackerShell code pattern, onChange interceptor, previousTab, Log intercept)
- cadence-navigation skill §5 (role isolation: one shell mounted at a time)
- liquid-glass-ios26 skill (tab bar chrome rules, permanent terracotta center button, anti-pattern list)
- cadence-xcode-project skill (project.yml as source of truth, new Swift file rule)
- cadence-build skill (xcodebuild scheme Cadence, SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)
