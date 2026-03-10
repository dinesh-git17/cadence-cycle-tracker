# Partner Navigation Shell

**Epic ID:** PH-9-E1
**Phase:** 9 -- Partner Navigation Shell & Dashboard
**Estimated Size:** M
**Status:** Draft

---

## Objective

Build the 3-tab Partner TabView and its NavigationStack, fully isolated from the Tracker navigation tree, with Liquid Glass chrome and correct SF Symbol tab icons. This shell is the structural container into which all subsequent Phase 9 epics (Bento grid, Realtime data, paused state) are assembled.

## Problem / Context

Phase 2 routes authenticated Partner users to a PartnerRootView placeholder. Phase 9 replaces that placeholder with a real 3-tab shell. Without this shell, no Partner-facing content can be built or tested in context. The isolation requirement is non-negotiable: the cadence-navigation skill prohibits any shared NavigationPath, ViewModel, or tab state between the Tracker and Partner trees. Coupling at the AppCoordinator level creates a class of routing bugs that manifest only when both roles are tested in the same session.

Source authority: Design Spec v1.1 §8 (Partner navigation IA), §9 (tab bar icons), §7 (Liquid Glass chrome); cadence-navigation skill (Partner shell isolation).

## Scope

### In Scope

- PartnerTabView: 3-tab TabView with Her Dashboard (position 1), Notifications stub (position 2), Settings stub (position 3)
- Tab bar icons per Design Spec §9: Her Dashboard = `person.crop.rectangle` / `person.crop.rectangle.fill`, Notifications = `bell` / `bell.fill`, Settings = `gearshape` / `gearshape.fill`
- Active tint CadenceTerracotta, inactive tint CadenceTextSecondary; icon size 25pt, medium weight
- NavigationStack for Partner tree with its own NavigationPath instance; no NavigationPath, ViewModel, or tab selection state shared with TrackerTabView or any Tracker-rooted view
- iOS 26 automatic Liquid Glass tab bar and navigation bar chrome (no toolbarBackground overrides that would interfere with glass)
- AppCoordinator update: replace PartnerRootView stub with PartnerTabView when authenticated user role is .partner
- PartnerNotificationsStubView: "Notifications will appear here" in body style, CadenceTextSecondary, centered -- placeholder for Phase 10
- PartnerSettingsStubView: "Settings coming soon" in body style, CadenceTextSecondary, centered -- placeholder for Phase 12

### Out of Scope

- Partner Home Dashboard content: Bento grid cards, ViewModel (PH-9-E2)
- Realtime data subscription and live data binding (PH-9-E3)
- Paused sharing state card and animation (PH-9-E4)
- Full Notifications tab content (Phase 10)
- Full Settings tab content (Phase 12)

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| AppCoordinator.swift with role-based routing stub targeting PartnerRootView | FS | PH-2 | Resolved | Low |
| Authenticated user role field (.partner) available from users table via Supabase auth session | FS | PH-2 | Resolved | Low |
| CadenceTerracotta and CadenceTextSecondary color assets in xcassets | FS | PH-0 | Resolved | Low |
| iOS 26 SDK Liquid Glass automatic tab bar behavior | External | Apple SDK | Resolved | Low |

## Assumptions

- AppCoordinator.swift from Phase 2 contains a branching point for `user.role == .partner` that currently renders a stub view; this epic replaces that stub with PartnerTabView
- User role is determined from the authenticated session's users table row, not from a local flag
- The iOS 26 SDK provides automatic Liquid Glass chrome for TabView and NavigationStack without requiring explicit glassEffect() calls on the tab bar itself; no custom surface configuration is needed for standard tab bar glass

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| AppCoordinator role routing pattern from Phase 2 requires structural changes incompatible with PartnerTabView injection | Low | Medium | Read AppCoordinator.swift before implementing; map the exact injection point before writing any code |
| iOS 26 SDK tab bar Liquid Glass behavior differs from liquid-glass-ios26 skill spec | Low | Medium | Verify against liquid-glass-ios26 skill rules before finalizing chrome configuration; fallback to ultraThinMaterial if needed |

---

## Stories

### S1: AppCoordinator routing to PartnerTabView

**Story ID:** PH-9-E1-S1
**Points:** 3

Modify AppCoordinator to route authenticated users with role .partner to PartnerTabView. The existing TrackerTabView routing path must be unchanged. Verify that switching roles in tests routes to the correct shell.

**Acceptance Criteria:**

- [ ] Given an authenticated session with role .partner, AppCoordinator renders PartnerTabView as the root view
- [ ] Given an authenticated session with role .tracker, AppCoordinator renders TrackerTabView and PartnerTabView is not instantiated
- [ ] AppCoordinator holds no reference to PartnerTabView's NavigationPath or any Partner-scoped ViewModel
- [ ] No shared @Observable store or @EnvironmentObject is injected into both TrackerTabView and PartnerTabView from the same instance

**Dependencies:** None
**Notes:** Read AppCoordinator.swift before writing any code. Identify the exact conditional where the stub PartnerRootView is currently rendered.

---

### S2: PartnerTabView 3-tab scaffold with SF Symbol icons

**Story ID:** PH-9-E1-S2
**Points:** 2

Implement PartnerTabView as a 3-tab TabView. Her Dashboard is tab 1 (index 0), Notifications is tab 2 (index 1), Settings is tab 3 (index 2). Tab icons use SF Symbols per Design Spec §9 with correct active/inactive tint and 25pt size.

**Acceptance Criteria:**

- [ ] PartnerTabView renders 3 tabs in order: Her Dashboard, Notifications, Settings
- [ ] Her Dashboard tab icon: `person.crop.rectangle` inactive, `person.crop.rectangle.fill` active, tinted CadenceTerracotta when active
- [ ] Notifications tab icon: `bell` inactive, `bell.fill` active, tinted CadenceTerracotta when active
- [ ] Settings tab icon: `gearshape` inactive, `gearshape.fill` active, tinted CadenceTerracotta when active
- [ ] All inactive tab icons tinted CadenceTextSecondary
- [ ] No `.tabItem` label text is visible (icon-only tab bar, consistent with Tracker shell)
- [ ] Tab icons render at 25pt with medium weight (`.imageScale(.medium)` on tabItem content)

**Dependencies:** PH-9-E1-S1
**Notes:** Verify icon rendering size and weight match the Tracker tab bar; use the same tab item configuration pattern.

---

### S3: Partner NavigationStack isolation

**Story ID:** PH-9-E1-S3
**Points:** 3

Implement NavigationStack for the Partner tree's Her Dashboard tab with its own NavigationPath instance. Verify that no NavigationPath reference, path-modifying method, or path-bound ViewModel is shared between Partner and Tracker navigation trees.

**Acceptance Criteria:**

- [ ] Her Dashboard tab wraps its content in a NavigationStack with a Partner-scoped NavigationPath instance
- [ ] No NavigationPath property is shared between PartnerTabView and TrackerTabView (verified by code inspection -- two distinct instances)
- [ ] No ViewModel instance is shared between the Partner and Tracker navigation trees via @EnvironmentObject or @Environment injection at the AppCoordinator level
- [ ] Navigating to a detail view within the Partner shell (if applicable in later epics) does not affect Tracker tab state or NavigationPath
- [ ] The Partner shell compiles and routes correctly in a clean build with TrackerTabView present in the same target

**Dependencies:** PH-9-E1-S2

---

### S4: Liquid Glass chrome on Partner shell

**Story ID:** PH-9-E1-S4
**Points:** 3

Apply iOS 26 Liquid Glass chrome to the Partner shell's tab bar and navigation bar following the liquid-glass-ios26 skill rules. The tab bar and nav bar must use automatic glass; no explicit glassEffect() or ultraThinMaterial overrides are applied to the tab bar surface itself.

**Acceptance Criteria:**

- [ ] Partner shell tab bar renders with iOS 26 automatic Liquid Glass chrome on a device/simulator running iOS 26
- [ ] Partner shell navigation bar renders with iOS 26 automatic Liquid Glass chrome
- [ ] No `.toolbarBackground(_:for:)` modifier overrides the automatic glass on PartnerTabView itself (overrides, if needed, are applied to tab content views per liquid-glass-ios26 rules)
- [ ] No explicit `.background(ultraThinMaterial)` or `.glassEffect()` is applied to the tab bar container
- [ ] The Liquid Glass chrome is visually consistent with the Tracker shell's tab bar chrome when both are rendered side-by-side in a test

**Dependencies:** PH-9-E1-S2

---

### S5: Stub content for Notifications and Settings tabs

**Story ID:** PH-9-E1-S5
**Points:** 1

Implement PartnerNotificationsStubView and PartnerSettingsStubView as minimal placeholder views. Both are visible in the Partner shell and will be replaced in Phase 10 and Phase 12 respectively.

**Acceptance Criteria:**

- [ ] Notifications tab renders PartnerNotificationsStubView: "Notifications will appear here" in body style, CadenceTextSecondary, vertically and horizontally centered
- [ ] Settings tab renders PartnerSettingsStubView: "Settings coming soon" in body style, CadenceTextSecondary, vertically and horizontally centered
- [ ] Both stub views use Color("CadenceBackground") as the background (no hardcoded hex values)
- [ ] Neither stub view contains any navigation destinations, buttons, or interactive elements

**Dependencies:** PH-9-E1-S2

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

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration with dependencies verified end-to-end: AppCoordinator routes .partner role to PartnerTabView; .tracker role routes to TrackerTabView unaffected
- [ ] Phase objective is advanced: a Partner user can open the app and see a 3-tab shell with correct icons and Liquid Glass chrome
- [ ] cadence-navigation skill constraints satisfied: zero shared NavigationPath, ViewModel, or tab state between Tracker and Partner trees
- [ ] cadence-design-system skill constraints satisfied: all color references use Color("CadenceToken") -- no hardcoded hex values
- [ ] liquid-glass-ios26 skill constraints satisfied: glassEffect ordering rules respected, no custom chrome overrides on tab bar container
- [ ] swiftui-production skill constraints satisfied: no AnyView usage, no force unwraps, no heavy work on main actor
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] No dead code, stubs, or placeholder comments in production Swift files
- [ ] Source document alignment verified: tab icons, tint colors, and navigation structure match Design Spec v1.1 §8 and §9 exactly

## Source References

- PHASES.md: Phase 9 -- Partner Navigation Shell & Dashboard (in-scope items 1, 2; sequencing rationale)
- Design Spec v1.1 §8 (Partner Navigation -- 3-tab IA)
- Design Spec v1.1 §9 (Partner tab bar icons -- SF Symbols, active/inactive tint, size)
- Design Spec v1.1 §7 (Elevation & Surfaces -- Liquid Glass tab bar and nav bar)
- cadence-navigation skill (Partner shell isolation rules, NavigationStack + navigationDestination pattern)
- liquid-glass-ios26 skill (iOS 26 glassEffect ordering, automatic tab bar glass behavior)
- cadence-design-system skill (CadenceTerracotta, CadenceTextSecondary tokens)
