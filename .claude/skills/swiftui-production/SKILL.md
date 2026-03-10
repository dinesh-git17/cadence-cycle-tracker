---
name: swiftui-production
description: Baseline production-grade SwiftUI governance for every Swift file in this repository. Use when writing, reviewing, or modifying any SwiftUI view, ViewModel, or UI-adjacent Swift code in the Cadence project. Enforces correct @Observable vs @State vs @Binding selection, mandatory view extraction beyond 50 lines, LazyVStack for all feed views, AnyView ban, stable ForEach identity, and GeometryReader restraint. Flags force-unwraps, retain cycles in closures, and synchronous heavy work on the main actor. This is the default engineering standard — trigger on any Swift file, SwiftUI view, ViewModel, state management decision, or architectural question in this codebase, even if the user does not explicitly ask for a review.
---

# SwiftUI Production Standards — iOS 26

Baseline engineering governance for all SwiftUI code in this repository. Apply to every Swift file that participates in UI or UI-adjacent architecture. All rules are blocking unless explicitly noted otherwise.

---

## 1. State Model Selection

### Decision Table

| Situation                                                     | Correct choice                 |
| ------------------------------------------------------------- | ------------------------------ |
| Mutable app/screen state in a ViewModel                       | `@Observable` class            |
| `@Observable` ViewModel whose lifecycle this view owns        | `@State var viewModel: SomeVM` |
| View-local transient state (Bool, String, enum, simple value) | `@State`                       |
| Two-way reference to state owned by a parent                  | `@Binding`                     |
| `@Observable` object shared across the view tree              | `@Environment`                 |
| Constant data passed in from a parent                         | `let` property                 |

### Rules

Use the Observation framework (`@Observable`) for ViewModels and shared data models. Do not use `ObservableObject` + `@Published` for new code targeting iOS 26.

Do not use `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` with `@Observable` types. These property wrappers belong to the `ObservableObject` protocol only and are incompatible with `@Observable`.

`@State` owns value types local to a view and owns `@Observable` class instances when the creating view controls the lifecycle. `@Binding` is a two-way reference — it never owns state. A view receiving a `@Binding` is never the source of truth.

Pass `@Observable` objects down as plain `let` parameters or inject via `@Environment`. SwiftUI tracks property access automatically — no `@Published` annotation needed.

```swift
// WRONG: ObservableObject wrappers on @Observable type
@ObservedObject var viewModel: TrackerHomeViewModel

// WRONG: creating ViewModel without @State (recreated every render)
var viewModel = TrackerHomeViewModel()

// WRONG: @State for data owned by a parent
@State var selectedDate: Date  // parent owns this — use @Binding

// CORRECT
@Observable class TrackerHomeViewModel { var phase: CyclePhase = .follicular }

struct TrackerHomeView: View {
    @State private var viewModel = TrackerHomeViewModel()  // view owns lifecycle
    var body: some View { ... }
}

struct CountdownCard: View {
    let viewModel: TrackerHomeViewModel  // passed in, observed automatically
    var body: some View { ... }
}
```

---

## 2. View Extraction — 50-Line Rule

A SwiftUI `body` exceeding 50 lines must be decomposed. This rule is not advisory.

**Why it matters:** Large `body` properties degrade Swift's type-checker performance, obscure state flow, and prevent subview reuse. SwiftUI subview structs are zero-cost — creating more of them has no runtime penalty.

**How to decompose:**

- Extract logical sections into separate `struct` types conforming to `View`.
- Use `@ViewBuilder` functions or computed properties returning `some View` for inline groupings.
- Each extracted subview has one clear responsibility and receives only the data it needs.

```swift
// WRONG: monolithic body
struct TrackerHomeView: View {
    var body: some View {
        ScrollView {
            // 90 lines of inline layout for sharing strip, cycle card,
            // countdown row, today's log, CTA, insight card...
        }
    }
}

// CORRECT: decomposed
struct TrackerHomeView: View {
    @State private var viewModel = TrackerHomeViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                SharingStatusStrip(viewModel: viewModel)
                CycleStatusCard(viewModel: viewModel)
                CountdownRow(viewModel: viewModel)
                TodayLogCard(viewModel: viewModel)
                LogTodayCTA { viewModel.openLogSheet() }
                InsightCard(insight: viewModel.currentInsight)
            }
            .padding(.horizontal, 16)
        }
    }
}
```

---

## 3. Feed Views — LazyVStack Required

All feed-style vertically scrolling content must use `LazyVStack` inside a `ScrollView`. `VStack` inside `ScrollView` renders every child eagerly regardless of visibility — this is prohibited for feed contexts.

**Cadence feed surfaces:** Tracker Home dashboard, Reports feed, any vertically scrolling card list.

```swift
// WRONG: VStack renders all cards at launch
ScrollView {
    VStack(spacing: 32) {
        ForEach(cards) { card in CardView(card: card) }
    }
}

// CORRECT: LazyVStack renders only visible cards
ScrollView {
    LazyVStack(spacing: 32) {
        ForEach(cards) { card in CardView(card: card) }
    }
    .padding(.horizontal, 16)
}
```

**When `List` is acceptable:** Settings rows, notification history — where system list styling and built-in swipe actions are appropriate. Use `LazyVStack` for Cadence's custom card feeds.

**Documented exception:** A `VStack` containing a fixed, small, statically-known number of items (≤ 5, will never grow) does not require `LazyVStack`. Document the cardinality assumption with an inline comment.

---

## 4. AnyView — Banned

`AnyView` is banned. Do not use it as a convenience escape hatch.

**Why:** `AnyView` erases the concrete view type. SwiftUI cannot diff the type hierarchy, loses structural identity, breaks layout animations, and forces full subtree re-renders on every state change.

```swift
// WRONG: type-erased return
func card() -> AnyView { AnyView(DataCard(data: data)) }

// CORRECT: opaque return
func card() -> some View { DataCard(data: data) }

// CORRECT: @ViewBuilder for conditional returns
@ViewBuilder
func dashboardContent() -> some View {
    if sharingPaused {
        SharingPausedCard()
    } else {
        BentoDashboardGrid()
    }
}

// CORRECT: Group for inline conditionals
Group {
    if condition { ViewA() } else { ViewB() }
}
```

**Extraordinary exception:** `AnyView` is only acceptable when a third-party API signature demands it and no other option exists. Requires an inline comment stating the specific reason.

---

## 5. ForEach Identity — Stable IDs Required

Every `ForEach` must use a stable, unique, persistent identifier. SwiftUI uses identity to diff the view graph, drive animations, and preserve child view state across redraws.

```swift
// WRONG: index as identity — breaks on reorder/insert/delete
ForEach(0..<symptoms.count, id: \.self) { i in ChipView(symptom: symptoms[i]) }

// WRONG: \.self on mutable value type — unstable if properties change
ForEach(symptoms, id: \.self) { ChipView(symptom: $0) }

// CORRECT: stable model ID
ForEach(symptoms, id: \.id) { ChipView(symptom: $0) }

// CORRECT: Identifiable conformance (preferred)
ForEach(symptoms) { ChipView(symptom: $0) }  // symptom: Identifiable, id: UUID
```

All model types iterated in `ForEach` must conform to `Identifiable` using a stable UUID or persistent database ID (SwiftData `@Model` provides this automatically). Never derive an ID from computed or random values.

---

## 6. GeometryReader — Restraint Required

`GeometryReader` takes the full proposed size from its parent, disrupting natural layout flow. It is frequently misused when a simpler layout tool exists.

**Try these first:**

| Goal                 | Preferred API                                                   |
| -------------------- | --------------------------------------------------------------- |
| Full-width element   | `.frame(maxWidth: .infinity)`                                   |
| Proportional sizing  | `containerRelativeFrame(_:)` (iOS 17+)                          |
| Equal-width siblings | `Grid` (iOS 16+) or `HStack` with `.frame(maxWidth: .infinity)` |
| Centering            | `.frame(maxWidth: .infinity, alignment: .center)`               |
| Aspect ratio         | `.aspectRatio(_, contentMode:)`                                 |
| Custom alignment     | `alignmentGuide(_:computeValue:)`                               |

**When GeometryReader is acceptable:** You need the actual rendered size of a view to compute a layout that cannot be expressed declaratively, or you need a coordinate space for drag gestures or scroll-offset tracking. Document the justification with an inline comment.

```swift
// WRONG: GeometryReader for something layout can handle
GeometryReader { geo in Rectangle().frame(width: geo.size.width) }

// CORRECT
Rectangle().frame(maxWidth: .infinity)
```

---

## 7. Safety and Correctness

### Force-Unwraps

Zero tolerance for `!` in production code. Every force-unwrap is a latent crash.

```swift
// WRONG
let user = userStore.currentUser!

// CORRECT
guard let user = userStore.currentUser else { return }
// or
let name = user?.displayName ?? "Partner"
```

Acceptable boundary: known-safe initializer expressions (e.g., `Color("CadenceTerracotta")` — asset catalog guaranteed at build time). All other `!` usage is rejected.

### Retain Cycles in Closures

`@Observable` ViewModels are reference types. Closures capturing `self` inside a class can create retain cycles.

```swift
// RISK: stored closure on a class captures self strongly
class LogViewModel {
    var onSave: (() -> Void)?

    func setup() {
        onSave = { self.handleSave() }  // retain cycle — self holds onSave, onSave holds self
    }
}

// CORRECT
func setup() {
    onSave = { [weak self] in self?.handleSave() }
}
```

**Rule:** Use `[weak self]` in any closure stored as a property on a class type. `Task {}` bodies in `@MainActor` functions do not require `[weak self]` — the Task lifetime does not extend the object beyond what is expected. Stored completion handlers, delegation closures, and Combine subscriptions always require `[weak self]`.

SwiftUI view structs are value types — no retain cycle risk in view body code.

### Synchronous Work on the Main Actor

`@MainActor` is the UI thread. Blocking it causes dropped frames and unresponsive UI.

**Prohibited on the main actor:**

- Sorting or filtering large collections synchronously.
- Any blocking I/O (file reads, network waits).
- Cadence's client-side prediction arithmetic on large datasets.
- Large SwiftData queries blocking the main context (use a background `ModelContext`).

```swift
// WRONG: heavy computation on @MainActor
@MainActor class ReportsViewModel {
    func load() {
        reports = massiveDataTransform(rawCycles)  // blocks UI if expensive
    }
}

// CORRECT: offload to background
@MainActor class ReportsViewModel {
    func load() {
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                massiveDataTransform(rawCycles)
            }.value
            self.reports = result
        }
    }
}
```

`SyncCoordinator` and all Supabase operations are async — never call them synchronously or await them directly on the main actor without a wrapping `Task {}`.

---

## 8. Anti-Pattern Table

| Anti-pattern                                             | Verdict                                                    |
| -------------------------------------------------------- | ---------------------------------------------------------- |
| `@ObservedObject` / `@StateObject` on `@Observable` type | Reject                                                     |
| `ObservableObject` + `@Published` for new code           | Reject — use `@Observable`                                 |
| `var viewModel = SomeVM()` without `@State`              | Reject — recreated every render                            |
| View body > 50 lines without decomposition               | Reject — extract subviews                                  |
| `VStack` in `ScrollView` for feed content                | Reject — use `LazyVStack`                                  |
| `AnyView`                                                | Reject — use `@ViewBuilder` or `some View`                 |
| `ForEach` with index or computed ID                      | Reject — use stable `Identifiable` model ID                |
| `GeometryReader` when layout alternative exists          | Reject — use `containerRelativeFrame`, `Grid`, or `.frame` |
| Force-unwrap `!` outside safe initializer boundary       | Reject                                                     |
| Stored closure on class without `[weak self]`            | Reject                                                     |
| Synchronous heavy computation in `@MainActor` function   | Reject — offload via `Task.detached`                       |
| `@Binding` used to own state (not reference it)          | Reject                                                     |

---

## 9. Enforcement Checklist

Before marking any SwiftUI view or ViewModel complete:

- [ ] State model matches the decision table: `@Observable`, `@State`, `@Binding`, `@Environment`, or `let`
- [ ] No `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` on `@Observable` types
- [ ] No `ObservableObject` + `@Published` in new code
- [ ] View body is ≤ 50 lines, or decomposed into named subview structs
- [ ] Feed views use `LazyVStack` inside `ScrollView`
- [ ] No `AnyView` — conditional returns use `@ViewBuilder` or `some View`
- [ ] Every `ForEach` uses a stable `Identifiable` model ID
- [ ] No `GeometryReader` without a documented justification proving alternatives don't work
- [ ] No force-unwraps (`!`) outside known-safe initializer boundaries
- [ ] Stored closures on class types use `[weak self]`
- [ ] No synchronous heavy computation in `@MainActor` functions — offload via `Task.detached`
- [ ] All Supabase / SyncCoordinator calls are async, never blocking
