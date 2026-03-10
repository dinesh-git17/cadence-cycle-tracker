---
name: liquid-glass-ios26
description: Implements iOS 26 Liquid Glass (ultraThinMaterial / glassEffect) correctly for Cadence's tab bar and navigation bar surfaces. Enforces that glassEffect() is never applied before .background(), that no custom chrome overrides system materials, and that all Liquid Glass surfaces degrade gracefully if the deployment target changes. Covers the 5-tab Tracker layout and the permanently filled terracotta center Log button. Use this skill whenever working on Cadence's TabView, NavigationStack, toolbar surfaces, navigation bar, tab bar chrome, or any view that touches the Liquid Glass layer. Trigger on any question about tab bar styling, nav bar material, ultraThinMaterial, glassEffect, toolbar customization, center Log button behavior, or navigation chrome in the Cadence project.
---

# Liquid Glass — iOS 26 Implementation Skill for Cadence

**Platform:** iOS 26 minimum · SwiftUI throughout · Xcode 26 SDK
**Authoritative source:** `docs/Cadence_Design_Spec_v1.1.md` (design intent) + Apple WWDC25 "Build a SwiftUI app with the new design" (session 323) + Apple Developer Documentation (glassEffect API)

This skill governs all Liquid Glass usage in Cadence. It covers navigation chrome only — tab bars, navigation bars, and toolbar surfaces. It does not govern decorative blur on content surfaces; those are prohibited per the design spec.

---

## Scope Boundary

**This skill applies to:**

- `TabView` and its tab bar chrome
- `NavigationStack` and its navigation bar
- Toolbar modifiers targeting `.tabBar` or `.navigationBar`
- Any `glassEffect()` call in the codebase
- The 5-tab Tracker shell
- The center Log tab button coexistence with Liquid Glass

**Out of scope (handle violations, not implementation):**

- `glassEffect()` on content cards, symptom chips, or data surfaces — this is a spec violation. Cadence cards use `CadenceCard` fills with `CadenceBorder` strokes. Glass is not a card treatment.
- `ultraThinMaterial` on non-navigation surfaces without iOS 26 fallback justification.

---

## iOS 26 Liquid Glass Fundamentals

### What is automatic

When compiled with Xcode 26, the following receive Liquid Glass treatment **without any developer action**:

- `TabView` tab bar — floats above content, adopts glass material automatically
- `NavigationStack` navigation bar — glass background applied by the system
- Sheet backgrounds, system alerts, action sheets — system-managed

For Cadence: both the tab bar and navigation bar are **already Liquid Glass by default**. The implementation goal is to **preserve this behavior** rather than fight it.

### What requires explicit implementation

- Custom `glassEffect()` modifiers on developer-created surfaces
- Per-tab `toolbarBackground` / `toolbarBackgroundVisibility` customization
- The center Log tab's permanent terracotta identity within the glass tab bar
- Graceful degradation code for any custom glass surfaces

---

## Critical Rule: glassEffect() Modifier Ordering

`glassEffect()` samples the content rendered **behind** it at the time it is evaluated. Applying it before `.background()` means it samples from nothing — the background has not been rendered yet — producing incorrect or empty sampling artifacts.

**Required order:**

```swift
// CORRECT — glass samples the rendered blue background
Text("Label")
    .padding()
    .background(Color.blue)
    .glassEffect()

// WRONG — glass samples before the background exists
Text("Label")
    .padding()
    .glassEffect()
    .background(Color.blue)
```

**Enforcement rule:** Any `glassEffect()` call in Cadence source must have `.background()` applied before it in the modifier chain when a background is present. If no explicit background is needed, `glassEffect()` may be applied directly — but verify the rendering intent explicitly.

This rule applies to custom surfaces only. Tab bar and nav bar glass is system-managed and requires no modifier ordering.

---

## Cadence Tab Bar — 5-Tab Tracker Shell

### Tab structure

The Tracker shell has exactly 5 tabs. The structural `Tab` API (preferred over deprecated `tabItem(_:)`) is used:

```swift
TabView {
    Tab("Home", systemImage: "house") {
        TrackerHomeView()
    }
    Tab("Calendar", systemImage: "calendar") {
        CalendarView()
    }
    Tab("Log", systemImage: "plus.circle.fill") {
        // Intercept — opens LogSheet, does not navigate
        Color.clear
    }
    Tab("Reports", systemImage: "chart.bar") {
        ReportsView()
    }
    Tab("Settings", systemImage: "gearshape") {
        SettingsView()
    }
}
```

### Icon tint rules

Apply tab tint at the root `TabView` level:

```swift
TabView { ... }
    .tint(Color("CadenceTerracotta"))
```

This sets the **active tab icon tint** to `CadenceTerracotta`. Inactive icons use the system default which resolves to `CadenceTextSecondary` — verify this renders correctly against the glass bar before shipping.

Do not call `.accentColor()` — use `.tint()`.

### Tab bar chrome — do not override

The tab bar's Liquid Glass material is system-managed. Do not apply:

- `.toolbarBackground(.hidden, for: .tabBar)` — hides the glass entirely
- `.toolbarBackground(Color("CadenceBackground"), for: .tabBar)` on the `TabView` — has no effect and creates confusion
- Custom `UITabBar.appearance()` modifications — fights the system material model
- A fully custom tab bar built from scratch — violates the design spec mandate ("no custom navigation chrome")

If per-tab toolbar customization is required, apply the modifier **inside each Tab's content view**, not on the `TabView`:

```swift
// CORRECT — modifiers on the content, not the TabView
Tab("Home", systemImage: "house") {
    TrackerHomeView()
        .toolbarBackground(.visible, for: .tabBar)
}

// WRONG — has no effect on iOS 26
TabView { ... }
    .toolbarBackground(.visible, for: .tabBar)
```

---

## Center Log Tab — Permanent Terracotta Identity

The Log tab (`plus.circle.fill`) is permanently filled with `CadenceTerracotta`. It does not switch to an outlined variant in the inactive state. This is a core Cadence design requirement.

### The challenge

iOS 26's Liquid Glass tab bar applies active/inactive tinting system-wide. The `.tint(Color("CadenceTerracotta"))` approach tints all **active** icons terracotta, while inactive icons adopt the system default. This works for Home, Calendar, Reports, and Settings — but the Log tab must appear "active" (terracotta `plus.circle.fill`) at all times, regardless of which tab is selected.

### Implementation pattern

Use a custom `Tab` label with a persistent filled symbol and forced terracotta tint:

```swift
Tab(value: TabDestination.log) {
    Color.clear // Log tab does not push a view; it opens a sheet
} label: {
    Label {
        Text("Log")
    } icon: {
        Image(systemName: "plus.circle.fill")
            .foregroundStyle(Color("CadenceTerracotta"))
    }
}
```

The explicit `.foregroundStyle(Color("CadenceTerracotta"))` on the icon overrides the system inactive-state tint and maintains the permanent terracotta fill.

### Log action — sheet intercept, not navigation

The Log tab must open `LogSheet` as a modal bottom sheet rather than navigating to a new view. Implement via a `.onChange(of: selectedTab)` handler or the `Tab(value:)` selection intercept pattern:

```swift
.onChange(of: selectedTab) { _, newValue in
    if newValue == .log {
        isShowingLogSheet = true
        selectedTab = previousTab // restore previous selection
    }
}
```

This keeps the Liquid Glass tab bar visually consistent — no "selected" state ever persists on the Log tab — and prevents the center button from appearing as a navigation destination.

### Coexistence with Liquid Glass

The terracotta fill on the center button sits **within** the system Liquid Glass tab bar surface. No additional `glassEffect()` modifier is applied to the Log tab icon — it is a foreground element on the glass, not a glass element itself. Do not wrap the Log tab icon in `glassEffect()`.

The glass material samples the content behind the tab bar, not the tab icons. The terracotta fill does not interfere with sampling.

---

## Navigation Bar

The Tracker Home navigation bar uses `ultraThinMaterial` (Liquid Glass) automatically. No developer action required to establish the material.

Title: "Cadence" or empty — configured via `.navigationTitle("Cadence")` or `.navigationTitle("")`.

Do not apply:

- `.toolbarBackground(Color("CadenceCard"), for: .navigationBar)` — overrides the glass with an opaque fill
- `.toolbarBackground(.hidden, for: .navigationBar)` — eliminates the bar entirely
- Custom `UINavigationBar.appearance()` — fights system material management

If a navigation bar background customization becomes necessary (e.g., for a specific screen), apply it on that screen's view, not globally, and document the deviation with a comment citing which design spec open item justifies it.

---

## Graceful Degradation

Cadence targets iOS 26 minimum. For any code that explicitly calls `glassEffect()` on custom surfaces (not system chrome), guard with an `@available` check and provide an `ultraThinMaterial` fallback:

```swift
if #available(iOS 26, *) {
    customView
        .background(baseColor)
        .glassEffect()
} else {
    customView
        .background(.ultraThinMaterial)
}
```

**When this applies:** Only on custom developer-built surfaces that use `glassEffect()`. The system tab bar and nav bar do not require this guard — they degrade automatically when built against older SDKs.

**If the iOS 26 minimum deployment target ever drops:** All `glassEffect()` calls in the codebase must be audited for this guard pattern. The skill-creator skill should be used to update this skill if the deployment target changes.

**Availability annotation for custom glass APIs:**

```swift
@available(iOS 26, *)
func applyGlassChrome(to view: some View) -> some View {
    view
        .background(Color("CadenceCard"))
        .glassEffect()
}
```

---

## GlassEffectContainer — When Required

If Cadence ever introduces multiple adjacent `glassEffect()` surfaces (e.g., floating toolbar buttons, morphing badge transitions), they must be wrapped in a `GlassEffectContainer`. Glass cannot sample other glass — without the container, overlapping glass elements produce visual artifacts.

```swift
GlassEffectContainer {
    // Multiple glass views share one sampling region
    glassButtonA
    glassButtonB
}
```

Current Cadence implementation (tab bar + nav bar): both are system-managed, not wrapped in a custom `GlassEffectContainer`. This is correct. Do not add one.

If custom floating buttons with `glassEffect()` are added in future (e.g., a floating compose FAB), they must use `GlassEffectContainer` if they appear near other glass surfaces.

---

## Anti-Pattern Rejection List

The following patterns are **explicitly prohibited** in Cadence:

| Anti-Pattern                                                             | Why It Fails                                              |
| ------------------------------------------------------------------------ | --------------------------------------------------------- |
| `.glassEffect()` before `.background()`                                  | Glass samples from nothing — visual artifacts             |
| Custom `UITabBar` subclass replacing system bar                          | Violates spec § "no custom navigation chrome"             |
| `TabView.toolbarBackground(...)` (on TabView itself)                     | Has no effect on iOS 26 — misleading dead code            |
| `.toolbarBackground(.hidden, for: .tabBar)` without design justification | Eliminates Liquid Glass — spec violation                  |
| `UINavigationBar.appearance()` global overrides                          | Fights system material model                              |
| `glassEffect()` on content cards or data surfaces                        | Glass is navigation-layer only — content uses CadenceCard |
| `.shadow()` on Liquid Glass surfaces                                     | Shadows on glass break the material hierarchy             |
| Nested `GlassEffectContainer` instances                                  | Not supported                                             |
| Log tab allowed to appear "inactive" (outlined)                          | Permanent fill is a core design requirement               |
| Treating the Log tab as a navigation destination                         | It opens a sheet; it does not push a view                 |
| `plus.circle` (outline) instead of `plus.circle.fill`                    | Wrong symbol — Log tab is permanently filled              |
| Adding a `.border()` or `.overlay(stroke:)` to the tab bar               | Competing visual elements break system edge effects       |

---

## Pre-Implementation Checklist

Before touching any navigation chrome code in Cadence:

- [ ] Is the tab bar change system-level (tint, visibility) or a custom material override? If override: justify against spec.
- [ ] Does any custom surface use `glassEffect()`? If yes: is `.background()` applied before it?
- [ ] Is `glassEffect()` guarded with `@available(iOS 26, *)` and an `ultraThinMaterial` fallback?
- [ ] Is `toolbarBackground` applied on Tab content, not on `TabView`?
- [ ] Is the Log tab icon `plus.circle.fill` with explicit `.foregroundStyle(Color("CadenceTerracotta"))`?
- [ ] Does the Log tab intercept to a sheet rather than navigate?
- [ ] Are multiple adjacent `glassEffect()` views wrapped in a `GlassEffectContainer`?
- [ ] Are no `shadow()` modifiers applied to any Liquid Glass surface?
- [ ] Are no competing visual overlays (borders, veils, gradients) applied to the tab bar or nav bar?

If any item cannot be checked off, resolve it before committing.

---

## Ambiguity Notes

**`ultraThinMaterial` vs `glassEffect()` relationship:** Apple's iOS 26 documentation introduces `glassEffect()` as the preferred new API for applying Liquid Glass to custom views. `ultraThinMaterial` remains the correct pre-iOS 26 fallback. The two are not interchangeable on iOS 26 — `glassEffect()` produces the full Liquid Glass adaptive behavior; `ultraThinMaterial` produces a static translucency. Use `glassEffect()` for any iOS 26-exclusive custom glass surface, with `ultraThinMaterial` as the `#available` fallback.

**`toolbarBackground(.glass, for:)`:** Some sources reference this modifier. Its availability and exact behavior in the final iOS 26 SDK should be verified against the Xcode 26 SDK release notes before use. If confirmed available, it is the preferred way to explicitly request glass on toolbar surfaces. If unavailable, the default system behavior (automatic glass on recompile) is sufficient.

**Log tab implementation:** The permanently filled center button behavior (overriding system inactive tint) was not explicitly documented in Apple's tab bar APIs. The `foregroundStyle` override pattern is the conservative approach. Verify during implementation that the override persists correctly across all tab selection states and does not cause Liquid Glass rendering issues on the containing bar.
