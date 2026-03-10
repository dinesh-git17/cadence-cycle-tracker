---
name: cadence-navigation
description: "Governs all navigation architecture for Cadence's Tracker (5-tab) and Partner (3-tab) flows. Enforces NavigationStack + navigationDestination for push navigation, .sheet with .presentationDetents([.medium, .large]) for the Log Sheet, and the modal intercept pattern for the center Log tab — selectedTab never becomes .log. Enforces role isolation — Tracker and Partner trees never share NavigationPath, ViewModels, or tab state. Covers deep link dispatch (role-gated, path cleared before navigating), parent-coordinator-owned sheet presentation state, and child-to-parent dismissal signaling. Use whenever implementing or reviewing Cadence tab structure, NavigationStack, Log Sheet, sheet presentation, deep links, push routes, or navigation state ownership. Triggers on any question about Cadence tab bar, NavigationStack, Log Sheet, sheet, deep link, tab intercept, programmatic tab selection, or navigation state in this codebase."
---

# Cadence Navigation Architecture

Authoritative navigation governance for Cadence. Both the Tracker (5-tab) and Partner (3-tab) flows are covered here. Do not introduce navigation patterns not specified below without flagging a gap requiring designer and engineer confirmation.

---

## 1. Flow Architecture

### Tracker — 5 Tabs

| Index | Tab | Destination |
|-------|-----|-------------|
| 0 | Home | Tracker home dashboard |
| 1 | Calendar | Calendar view |
| 2 | Log (center) | **Modal intercept** — opens Log Sheet over current tab; `selectedTab` never becomes `.log` |
| 3 | Reports | Reports view |
| 4 | Settings | Tracker settings |

### Partner — 3 Tabs

| Index | Tab | Destination |
|-------|-----|-------------|
| 0 | Her Dashboard | Partner home dashboard |
| 1 | Notifications | Notification history and preferences |
| 2 | Settings | Partner settings |

**Ownership rule:** `TrackerShell` and `PartnerShell` are separate SwiftUI subtrees. They share no `NavigationPath`, no `@Observable` ViewModel, and no tab selection state. Role is determined once at session start and never changes in beta.

---

## 2. TabView and Per-Tab NavigationStack

The `TabView` is NOT wrapped in a `NavigationStack`. Each tab's content view is individually wrapped in its own `NavigationStack`. Wrapping the `TabView` creates a shared navigation context across tabs — this is prohibited.

```swift
enum TrackerTab: Hashable { case home, calendar, log, reports, settings }

struct TrackerShell: View {
    @State private var selectedTab: TrackerTab = .home
    @State private var previousTab: TrackerTab = .home
    @State private var isLogSheetPresented = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: TrackerTab.home) {
                NavigationStack { TrackerHomeView() }
            }
            Tab("Calendar", systemImage: "calendar", value: TrackerTab.calendar) {
                NavigationStack { CalendarView() }
            }
            Tab("Log", systemImage: "plus.circle.fill", value: TrackerTab.log) {
                Color.clear  // unreachable as a normal destination
            }
            Tab("Reports", systemImage: "chart.bar.fill", value: TrackerTab.reports) {
                NavigationStack { ReportsView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TrackerTab.settings) {
                NavigationStack { TrackerSettingsView() }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .log {
                selectedTab = previousTab  // revert — .log is never the active tab
                isLogSheetPresented = true
            } else {
                previousTab = newTab
            }
        }
        .sheet(isPresented: $isLogSheetPresented) {
            LogSheetView(onSave: { isLogSheetPresented = false })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
```

**Rules:**
- `selectedTab` must never persist at `.log`. The `onChange` interceptor reverts it in the same synchronous update.
- `previousTab` tracks the last non-Log tab so the revert lands correctly.
- The Log tab's `Tab` content is a placeholder (`Color.clear`). It is visually reachable only through the tab bar icon; its content view is irrelevant because `selectedTab` is immediately reverted.
- The `plus.circle.fill` icon is permanently filled with `CadenceTerracotta` — it never switches to an outlined variant regardless of selection state. See `liquid-glass-ios26` skill for tab chrome.

---

## 3. Push Navigation — NavigationStack + navigationDestination

All push navigation within a tab uses `NavigationStack` + `navigationDestination(for:destination:)`. Do not use `NavigationLink(isActive:)`, `NavigationLink(destination:)` with an inline destination closure as the sole mechanism, or any UIKit push equivalent.

```swift
enum SettingsRoute: Hashable { case partnerSharing, cycleDefaults, reminders }

struct TrackerSettingsView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Partner Sharing", value: SettingsRoute.partnerSharing)
                NavigationLink("Cycle Defaults", value: SettingsRoute.cycleDefaults)
                NavigationLink("Reminders", value: SettingsRoute.reminders)
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .partnerSharing: PartnerSharingView()
                case .cycleDefaults:  CycleDefaultsView()
                case .reminders:      RemindersView()
                }
            }
        }
    }
}
```

**Rules:**
- Route enums are role-namespaced: `TrackerRoute`, `PartnerRoute`. Never use a Tracker route inside `PartnerShell` or vice versa.
- `navigationDestination` is registered on the `NavigationStack` root or near its corresponding `NavigationLink`. Never place it inside a `LazyVStack`, `LazyHStack`, or `List` cell body — this causes non-deterministic push behavior.
- `NavigationPath` is per-tab, owned by that tab's root view or its ViewModel. It is never passed across tab boundaries or role boundaries.
- Navigation push uses the system default transition. No `.transition()` or `.animation()` overrides on push. See `cadence-motion` skill.

---

## 4. Log Sheet — Presentation Rules

The Log Sheet is the only modal surface with multiple entry points. All three entry points converge on a single `@State var isLogSheetPresented` owned by `TrackerShell`.

**Entry points:**
1. Log tab center button tap → `onChange` interceptor in `TrackerShell`
2. "Log today" CTA on Tracker Home → ViewModel signals `TrackerShell` via callback or shared state
3. Calendar date tap → same signal path; pre-populates `logDate`

**Detents:** Always `.presentationDetents([.medium, .large])`. Default displayed detent is `.medium`. Do not add `.fraction()` or `.height()` custom detents without explicit spec change.

**Dismissal:**
- Swipe down — native dismiss. SwiftUI resets `isLogSheetPresented` automatically through the binding.
- Save CTA — `LogSheetView` calls `onSave: () -> Void` provided by the parent. Parent clears `isLogSheetPresented = false`. Sheet dismisses immediately (optimistic — no network await before dismiss).

```swift
// TrackerShell — sheet registration
.sheet(isPresented: $isLogSheetPresented) {
    LogSheetView(
        date: selectedLogDate,
        onSave: { isLogSheetPresented = false }
    )
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
}

// LogSheetView — Save CTA (child uses callback, not its own @State binding)
Button("Save log") {
    viewModel.save()  // writes to SwiftData, enqueues SyncCoordinator
    onSave()          // parent clears isLogSheetPresented
}
```

`@Environment(\.dismiss)` in `LogSheetView` is also acceptable for the Save tap — SwiftUI routes it up to the parent's binding. What is prohibited is `LogSheetView` owning a separate `@State var isPresented` that duplicates or shadows the parent's `isLogSheetPresented`.

---

## 5. Role Isolation

`TrackerShell` and `PartnerShell` are entirely separate. The app's root mounts exactly one shell based on `session.role`. They never coexist in the view tree simultaneously.

```swift
struct RootView: View {
    @Environment(AppSession.self) var session

    var body: some View {
        switch session.role {
        case .tracker: TrackerShell()
        case .partner: PartnerShell()
        case .none:    AuthView()
        }
    }
}
```

**Rules:**
- No `NavigationPath`, tab selection `@State`, or ViewModel instance is shared between the two shells.
- Route value types (`TrackerRoute`, `PartnerRoute`) are not reused across roles.
- Do not use `opacity(0)` / `hidden()` to toggle between both shells — mount only the correct one.

---

## 6. Deep Link Handling

Deep links are dispatched by a root-level `onOpenURL` (or `onContinueUserActivity`) handler. The handler resolves role and destination before touching any navigation state.

**Documented route table** (PRD §14):

| Trigger | Destination |
|---------|-------------|
| Tracker: period / ovulation reminder | Tracker Home tab |
| Tracker: daily log reminder | Tracker Home tab + open Log Sheet directly |
| Partner: any notification | Partner Home tab |

**Rules:**
- Verify `session.role` matches the deep link's target role before mutating any state. Drop silently on mismatch.
- Clear the active tab's `NavigationPath` to root before navigating to the deep link destination. Never deep-link into a stale push stack.
- To open the Log Sheet from a deep link: set `selectedTab = .home`, clear the path, then set `isLogSheetPresented = true`. Do **not** set `selectedTab = .log` — that triggers the `onChange` interceptor, which is the user-tap path, not the deep link path.
- Deep links never mutate the opposite role's navigation tree.

```swift
// TrackerShell or root view
.onOpenURL { url in
    guard let route = DeepLinkParser.parse(url),
          route.role == session.role else { return }
    switch route.destination {
    case .trackerHome:
        selectedTab = .home
        homePath = NavigationPath()
    case .logSheet:
        selectedTab = .home
        homePath = NavigationPath()
        isLogSheetPresented = true
    case .partnerHome:
        break  // handled by PartnerShell's equivalent handler
    }
}
```

---

## 7. Parent Coordinator Dismissal

`isLogSheetPresented` is owned exclusively by `TrackerShell`. Views that trigger the Log Sheet signal intent — they never own the presentation boolean.

**Correct signal paths:**
- `TrackerHomeView` → ViewModel method `openLogSheet()` → `TrackerShell` observes and sets `isLogSheetPresented = true`
- `CalendarView` → same ViewModel method, additionally sets `selectedLogDate`
- Log tab tap → `onChange` interceptor in `TrackerShell` directly

**Anti-patterns — reject immediately:**
- `CalendarView` owns `@State var isLogSheetPresented` and presents the sheet itself
- `TrackerHomeView` owns `@State var isLogSheetPresented` — the shell owns it, not a tab content view
- `LogSheetView` presents itself via its own binding

---

## 8. Anti-Pattern Table

| Anti-pattern | Rule violated |
|---|---|
| `NavigationView` anywhere | Deprecated — use `NavigationStack` |
| `NavigationLink(destination:)` as sole push mechanism (no `navigationDestination`) | Push navigation rule |
| `TabView` wrapped in `NavigationStack` | Creates shared nav context across all tabs |
| `selectedTab` staying at `.log` after tap | Center-tab intercept rule |
| Log tab content implemented as a real navigation destination | Modal intercept rule |
| Shared `NavigationPath` across tabs or roles | Role / tab isolation |
| `TrackerRoute` value used inside `PartnerShell` | Role isolation |
| Deep link mutating both shells | Role isolation — must be role-gated |
| `selectedTab = .log` to open Log Sheet from deep link | Use `isLogSheetPresented = true` directly |
| Log Sheet without `.presentationDetents([.medium, .large])` | Log Sheet spec |
| Child view owns `@State var isLogSheetPresented` | Parent coordinator rule |
| Awaiting network write before dismissing Log Sheet | Optimistic UI — `cadence-motion` skill |
| Custom push transition on `NavigationStack` | System default only — `cadence-motion` skill |
| `navigationDestination` inside `LazyVStack` or lazy container | Non-deterministic push behavior |

---

## 9. Enforcement Checklist

Before marking any navigation-related view complete:

- [ ] No `NavigationView` — only `NavigationStack`
- [ ] `TabView` is NOT wrapped in a `NavigationStack`; each tab content has its own `NavigationStack`
- [ ] `TrackerTab` enum used for Tracker tab selection; `PartnerTab` for Partner — no raw integers
- [ ] Log tab tap: `selectedTab` reverts immediately, `isLogSheetPresented = true` fires in `onChange`
- [ ] `selectedTab` never persists at `.log`
- [ ] `previousTab` tracks the last non-Log selection for correct revert behavior
- [ ] Log Sheet registered with `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)`
- [ ] `isLogSheetPresented` owned by `TrackerShell` exclusively — not by `TrackerHomeView`, `CalendarView`, or `LogSheetView`
- [ ] All push navigation uses `NavigationLink(value:)` + `navigationDestination(for:destination:)`
- [ ] `navigationDestination` not inside any lazy container
- [ ] `NavigationPath` is per-tab; never shared across tabs or roles
- [ ] Route enums are role-namespaced (`TrackerRoute`, `PartnerRoute`) — no cross-role reuse
- [ ] `TrackerShell` and `PartnerShell` share zero state; only one is mounted at a time
- [ ] Deep link handler checks `session.role` before mutating navigation state
- [ ] Deep link clears `NavigationPath` to root before applying destination
- [ ] Log Sheet opened from deep link uses `isLogSheetPresented = true`, not `selectedTab = .log`
- [ ] Log Sheet dismissal does not await any network call (optimistic — see `cadence-motion` skill)
- [ ] No custom push or sheet transitions (system defaults only)
