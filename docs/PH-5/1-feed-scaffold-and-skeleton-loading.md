# TrackerHomeView Feed Scaffold and Skeleton Loading Infrastructure

**Epic ID:** PH-5-E1
**Phase:** 5 -- Tracker Home Dashboard
**Estimated Size:** M
**Status:** Draft

---

## Objective

Convert `TrackerHomeView.swift` from its Phase 4 placeholder body into the production feed container: a vertical `ScrollView` with `LazyVStack`, 32pt inter-card gaps, 16pt horizontal safe-area insets, and the `SkeletonCard` component that all Phase 5 card epics use as their loading state. This epic produces no visible data -- it produces the structural container and loading-state infrastructure that E2, E3, and E4 populate.

## Problem / Context

Phase 4 left `TrackerHomeView.swift` as a single `Text("Home").navigationTitle("Cadence")` body -- a valid phase gate, not a stub. Phase 5 begins by replacing that body with the real feed structure. Every subsequent Phase 5 epic (E2 Sharing Status Strip, E3 Cycle Status and Countdown, E4 Today's Log and Insight) depends on this scaffold to know where to place their content and how to show a loading placeholder until their data is available.

Design Spec v1.1 §13 defines the loading pattern: "Skeleton placeholders on card content surfaces. Localized `ProgressView` inside CTA buttons. Never full-screen spinners." The cadence-motion skill defines the shimmer: 1.2s loop, left-to-right, static opacity ~0.4 under `accessibilityReduceMotion`. If `SkeletonCard` is not a shared component established here, each of E2/E3/E4 will inline their own shimmer -- producing visual inconsistency and duplicated animation logic.

`TrackerHomeViewModel` is also established here as the single `@Observable` store that all Phase 5 views observe. Establishing it in E1 avoids each epic creating its own observation layer.

**Source references that define scope:**

- Design Spec v1.1 §12.2 (feed order: Sharing Strip, Cycle Status, Countdown, Today's Log, Log CTA, Insight Card; `LazyVStack`, 32pt gaps, 16pt inset)
- Design Spec v1.1 §5 (spacing tokens: `space-16` = 16pt horizontal inset, `space-32` = 32pt inter-card gap)
- Design Spec v1.1 §13 (skeleton placeholders on card surfaces, never full-screen spinners)
- cadence-motion skill (shimmer: 1.2s loop, left-to-right gradient; reduced-motion: static opacity 0.4)
- swiftui-production skill (`LazyVStack` mandatory for feed views; `@Observable` not `ObservableObject`)
- PHASES.md Phase 5 in-scope: "Vertical ScrollView feed with LazyVStack and 32pt card gaps; skeleton loading placeholders for all card surfaces per §13 states; empty/first-launch states"

## Scope

### In Scope

- `Cadence/Views/Tracker/Home/TrackerHomeView.swift`: replace placeholder `Text` body with `ScrollView(.vertical, showsIndicators: false)` containing `LazyVStack(spacing: 32)` with `.padding(.horizontal, 16)` applied to the `LazyVStack`; feed slot placeholders in the correct §12.2 order (6 named slots: strip, cycle status, countdown, today's log, log CTA, insight)
- `Cadence/ViewModels/TrackerHomeViewModel.swift`: `@Observable final class TrackerHomeViewModel`; initialized with a `ModelContext` injection parameter; declares `var isLoading: Bool = true`; declares `var predictionSnapshot: PredictionSnapshot?`; declares `var todayLog: DailyLog?`; declares `var completedCycleCount: Int = 0`; declares `var isSharingPaused: Bool = false`; declares `var isPartnerConnected: Bool = false`; `func load()` async method that fetches from SwiftData and sets `isLoading = false` on completion; called from `.task {}` on `TrackerHomeView`
- `Cadence/Views/Shared/SkeletonCard.swift`: `struct SkeletonCard: View` with a `height: CGFloat` parameter (callers pass the approximate height of the card being replaced); applies a `RoundedRectangle(cornerRadius: 16)` in `Color("CadenceBorder")` at the given height; overlays a shimmer gradient (`LinearGradient` from clear to `Color.white.opacity(0.5)` to clear, shifted with `@State var shimmerOffset`) animated with `.animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: shimmerOffset)` starting in `.onAppear`; under `accessibilityReduceMotion`, renders static `Color("CadenceBorder").opacity(0.4)` at the same height with no animation
- `TrackerHomeView` feed slots: each of the 6 slots renders `SkeletonCard(height: [appropriate height])` when `viewModel.isLoading == true`; renders the real card view (passed from E2/E3/E4) when `isLoading == false`; the real card views are stubbed here as `EmptyView()` and replaced when E2/E3/E4 implement their components
- First-launch and zero-prediction empty state: when `isLoading == false` and `predictionSnapshot == nil`, the Cycle Status and Countdown slots render a single `DataCard` with `Text("Start logging your cycle to see predictions here.").font(.body).foregroundStyle(Color("CadenceTextSecondary"))` -- this is the §13 empty state for a Tracker with 0 completed cycles; it replaces only the Cycle Status and Countdown cards, not the full feed
- `TrackerHomeView` `.navigationTitle("Cadence")` and `.navigationBarTitleDisplayMode(.inline)` preserved from Phase 4
- `project.yml` updated for `TrackerHomeViewModel.swift` and `SkeletonCard.swift`; `xcodegen generate` exits 0

### Out of Scope

- `SharingStatusStrip` component and its data binding (E2)
- `CycleStatusCard`, `ConfidenceBadge`, `CountdownCard`, `CountdownRow` components (E3)
- `TodayLogCard`, Log Today CTA wiring, `InsightCard` component (E4)
- Supabase data loading -- `TrackerHomeViewModel.load()` reads from SwiftData only (Phase 7 wires sync)
- `SkeletonCard` used in Phase 9 Partner Bento grid (Phase 9 consumes it as-is; no API changes in Phase 9)
- Haptic pattern on skeleton-to-content transition (not specified in source docs)

## Dependencies

| Dependency                                                                                                                       | Type | Phase/Epic | Status | Risk                                                      |
| -------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | --------------------------------------------------------- |
| Phase 4 complete: `TrackerHomeView.swift` exists at `Cadence/Views/Tracker/Home/`; `TrackerShell` mounts it as the Home tab root | FS   | PH-4-E1    | Open   | High -- E1 modifies an existing file; the file must exist |
| Phase 3 complete: `PredictionSnapshot`, `DailyLog`, `CycleProfile` SwiftData models defined; `ModelContext` accessible           | FS   | PH-3       | Open   | High -- `TrackerHomeViewModel` queries these models       |
| `CadenceBorder`, `CadenceTextSecondary`, `CadenceCard` color assets in `Colors.xcassets`                                         | FS   | PH-0-E2    | Open   | Low -- established in Phase 0                             |
| `DataCard` component from Phase 4                                                                                                | FS   | PH-4-E4-S1 | Open   | Low -- used by the zero-prediction empty state            |

## Assumptions

- `TrackerHomeViewModel` is injected with `ModelContext` via the view's initializer (not via `@Environment(\.modelContext)` directly in the ViewModel) so that it is testable with an in-memory `ModelContainer` in unit tests per cadence-testing skill.
- `SkeletonCard` height values are defined as named constants in the file: `private let cycleStatusCardSkeletonHeight: CGFloat = 120`, `private let countdownRowSkeletonHeight: CGFloat = 100`, etc. No magic numbers.
- The `shimmerOffset` animation starts at `-UIScreen.main.bounds.width` and ends at `UIScreen.main.bounds.width` -- using `GeometryReader` inside `SkeletonCard` is acceptable here because the shimmer gradient position is a direct function of the card width.
- The Phase 4 root content views (`ReportsView`, `CalendarView`, `TrackerSettingsView`) are not modified by this epic.

## Risks

| Risk                                                                                                                            | Likelihood | Impact | Mitigation                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LazyVStack` inside `ScrollView` with conditional content causes layout jitter when transitioning from skeleton to real content | Medium     | Medium | Ensure skeleton and real card have the same approximate height; use `SkeletonCard(height:)` with a height that matches the real card's intrinsic size to avoid scroll offset jumps |
| `TrackerHomeViewModel.load()` runs on the main actor and blocks the first frame                                                 | Low        | High   | Annotate `load()` with `async` and call it from `.task {}` on the view; SwiftData fetches are fast but must not block `onAppear`                                                   |
| Shimmer `GeometryReader` inside `SkeletonCard` causes recursive layout                                                          | Low        | Low    | Apply `GeometryReader` only to the gradient overlay, not to the card background; the card background uses a fixed `height` parameter, avoiding recursive sizing                    |
| `@Observable` `TrackerHomeViewModel` not available in Xcode 26 Preview canvas without a `ModelContainer`                        | Medium     | Low    | Provide a `static var preview: TrackerHomeViewModel` factory that uses `ModelContainer(for: ..., configurations: .init(isStoredInMemoryOnly: true))`                               |

---

## Stories

### S1: TrackerHomeViewModel -- @Observable data store with SwiftData fetch

**Story ID:** PH-5-E1-S1
**Points:** 3

Implement `TrackerHomeViewModel` as the single `@Observable` data store for all Phase 5 views. It fetches `PredictionSnapshot`, `DailyLog` (today), and `PeriodLog` count from SwiftData and exposes them as published properties. All Phase 5 card views read from this ViewModel -- none reach into SwiftData directly.

**Acceptance Criteria:**

- [ ] `Cadence/ViewModels/TrackerHomeViewModel.swift` exists with `@Observable final class TrackerHomeViewModel`
- [ ] Initializer signature: `init(modelContext: ModelContext)`; `modelContext` stored as a private property
- [ ] `var isLoading: Bool = true` -- set to `true` at init, set to `false` after `load()` completes
- [ ] `var predictionSnapshot: PredictionSnapshot?` -- holds the most recently generated snapshot for the authenticated user
- [ ] `var todayLog: DailyLog?` -- holds today's `DailyLog` if one exists; `nil` if not yet logged
- [ ] `var completedCycleCount: Int = 0` -- count of `PeriodLog` entries with a non-nil `end_date` (proxy for completed cycles)
- [ ] `var isSharingPaused: Bool = false` -- placeholder for Phase 8; hardcoded `false` in Phase 5
- [ ] `var isPartnerConnected: Bool = false` -- placeholder for Phase 8; hardcoded `false` in Phase 5
- [ ] `func load() async` fetches `PredictionSnapshot` using a `FetchDescriptor` sorted by `dateGenerated` descending, limit 1; fetches `DailyLog` for `date == Calendar.current.startOfDay(for: Date())`; counts `PeriodLog` entries with `end_date != nil`; sets `isLoading = false` after all fetches complete regardless of whether results are empty
- [ ] All SwiftData fetches are wrapped in `do/catch`; on error, `isLoading` is still set to `false` and `predictionSnapshot` / `todayLog` remain `nil`
- [ ] No `print()` calls in committed code; errors are swallowed silently in Phase 5 (sync error toasts are a Phase 7 concern)
- [ ] A static `var preview: TrackerHomeViewModel` factory exists using an in-memory `ModelContainer`
- [ ] `project.yml` updated with `Cadence/ViewModels/TrackerHomeViewModel.swift`; `xcodebuild build` exits 0

**Dependencies:** PH-3 complete (SwiftData models exist)

**Notes:** `isSharingPaused` and `isPartnerConnected` are hardcoded `false` in Phase 5. Phase 8 replaces them with live `partner_connections` reads. Hardcoding prevents nil-unwrap crashes when E2 binds to these properties before Phase 8 data exists.

---

### S2: TrackerHomeView feed body -- LazyVStack scaffold with ordered slots

**Story ID:** PH-5-E1-S2
**Points:** 3

Replace the Phase 4 placeholder `Text("Home")` body in `TrackerHomeView` with the production `ScrollView` / `LazyVStack` feed container. Each of the 6 §12.2 feed sections is represented by a named slot that shows `SkeletonCard` when loading, or `EmptyView()` when not loading (replaced by E2/E3/E4).

**Acceptance Criteria:**

- [ ] `TrackerHomeView` declares `@State private var viewModel: TrackerHomeViewModel` initialized with `ModelContext` from `@Environment(\.modelContext)`
- [ ] `.task { await viewModel.load() }` applied to the root view -- not `.onAppear`
- [ ] Root body: `ScrollView(.vertical, showsIndicators: false)` containing `LazyVStack(spacing: 32)` with `.padding(.horizontal, 16)` on the `LazyVStack`
- [ ] Feed slot order matches Design Spec §12.2 exactly: (1) strip slot, (2) cycle status slot, (3) countdown slot, (4) today's log slot, (5) log CTA slot, (6) insight slot
- [ ] When `viewModel.isLoading == true`: strip slot shows `SkeletonCard(height: 52)`, cycle status shows `SkeletonCard(height: 120)`, countdown shows `SkeletonCard(height: 100)`, today's log shows `SkeletonCard(height: 88)`, log CTA shows `SkeletonCard(height: 50)`, insight shows `SkeletonCard(height: 96)`
- [ ] When `viewModel.isLoading == false`: each slot shows `EmptyView()` (replaced by real components in E2/E3/E4)
- [ ] `.navigationTitle("Cadence")` and `.navigationBarTitleDisplayMode(.inline)` preserved
- [ ] No hardcoded numeric literals in slot heights -- each height is a `private let` constant at the file level
- [ ] `TrackerHomeView` body does not exceed 50 lines -- slots are extracted as private computed vars if necessary per swiftui-production skill
- [ ] `xcodebuild build` exits 0 with zero warnings

**Dependencies:** PH-5-E1-S1

**Notes:** The `LazyVStack` padding approach: `.padding(.horizontal, 16)` on the `LazyVStack` (not on individual cards) applies the §5 16pt safe-area inset uniformly. Individual card components must not add their own outer horizontal padding -- they are designed to fill the full width of the `LazyVStack` column.

---

### S3: SkeletonCard component -- shimmer animation with reduced-motion gate

**Story ID:** PH-5-E1-S3
**Points:** 3

Implement `SkeletonCard`: the shared loading placeholder used by all Phase 5 card slots. The shimmer sweeps left-to-right over a `CadenceBorder`-tinted rounded rectangle in 1.2 seconds on loop. Under `accessibilityReduceMotion`, the animation is suppressed and a static `CadenceBorder.opacity(0.4)` surface is shown instead.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/SkeletonCard.swift` exists with `struct SkeletonCard: View`
- [ ] Parameter: `height: CGFloat` -- the card placeholder height; no default value (callers must be explicit)
- [ ] `@Environment(\.accessibilityReduceMotion) private var reduceMotion` declared
- [ ] Non-reduced-motion rendering: `RoundedRectangle(cornerRadius: 16)` filled with `Color("CadenceBorder")` at the specified `height`; overlaid with a `LinearGradient` from `Color.clear` to `Color.white.opacity(0.5)` to `Color.clear` (horizontal); gradient position driven by `@State private var shimmerOffset: CGFloat = -1`; `.onAppear` sets `shimmerOffset = 1` with `.animation(.linear(duration: 1.2).repeatForever(autoreverses: false))`; offset is applied as `.offset(x: shimmerOffset * containerWidth)` where `containerWidth` is read via `GeometryReader` scoped only to the gradient overlay layer
- [ ] Reduced-motion rendering: `RoundedRectangle(cornerRadius: 16)` filled with `Color("CadenceBorder").opacity(0.4)` at the specified `height`; no animation applied
- [ ] Width: `.frame(maxWidth: .infinity)` -- fills the `LazyVStack` column width
- [ ] Corner radius: `16pt` matching `DataCard` corner radius (per Design Spec §6)
- [ ] No external drop shadow on `SkeletonCard`
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values -- `CadenceBorder` referenced as `Color("CadenceBorder")`

**Dependencies:** PH-0-E2 (CadenceBorder color asset exists)

**Notes:** The shimmer gradient uses `GeometryReader` only inside the overlay, not as the root layout container. The `RoundedRectangle` base uses the explicit `height` parameter, avoiding any recursive layout. Verify in simulator that the shimmer sweeps left-to-right continuously without stuttering at loop boundaries -- the `autoreverses: false` configuration is required for the clean one-directional sweep.

---

### S4: First-launch and zero-prediction empty state

**Story ID:** PH-5-E1-S4
**Points:** 2

Implement the empty state for Trackers with zero completed cycles (i.e., `predictionSnapshot == nil` after loading completes). This state replaces the Cycle Status and Countdown slots with a single explanatory card that communicates what will appear once logging begins.

**Acceptance Criteria:**

- [ ] When `viewModel.isLoading == false` and `viewModel.predictionSnapshot == nil`, the cycle status slot and countdown slot are replaced by a single `DataCard` containing `Text("Start logging your cycle to see predictions here.")` in `.font(.body)` and `Color("CadenceTextSecondary")`; the text is centered horizontally and vertically within the card
- [ ] The empty-state card uses `DataCard(isInsight: false)` from `PH-4-E4-S1` -- it is not an inline styled container
- [ ] The empty-state card is the same visual weight as a regular DataCard -- 1pt CadenceBorder stroke, 16pt corner radius, 20pt internal padding (enforced by DataCard component)
- [ ] The Today's Log slot, Log CTA slot, and Insight slot are still rendered in the empty state -- only Cycle Status and Countdown are replaced
- [ ] When `viewModel.isLoading == false` and `viewModel.predictionSnapshot != nil`, the empty-state card does not appear -- the Cycle Status and Countdown slots show their respective components (or `EmptyView()` until E3 is merged)
- [ ] `scripts/protocol-zero.sh` exits 0 on all E1 source files
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E1-S2, PH-4-E4-S1

**Notes:** The Today's Log slot still renders in the zero-prediction state because a Tracker can log symptoms before their first complete cycle. Hiding it during the empty state would block the logging habit that generates the cycle data.

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

- [ ] All four stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] `TrackerHomeView` renders a scrollable feed with 6 correctly ordered slots
- [ ] `SkeletonCard` shimmer animates in simulator and collapses to static under accessibilityReduceMotion
- [ ] `TrackerHomeViewModel.load()` completes and sets `isLoading = false` against an in-memory SwiftData store in a unit test
- [ ] Zero-prediction empty state renders correctly in a Preview with `predictionSnapshot = nil`
- [ ] Phase objective is advanced: the Home tab content area is navigable and loading-aware
- [ ] cadence-design-system skill: no hardcoded hex values; all color references use `Color("CadenceToken")`
- [ ] swiftui-production skill: `LazyVStack` used for feed; `@Observable` used (not `ObservableObject`); no `AnyView`; view body under 50 lines
- [ ] cadence-motion skill: shimmer 1.2s loop confirmed; reduced-motion gate confirmed
- [ ] cadence-xcode-project skill: all new Swift files added to `project.yml`; `.pbxproj` not modified directly
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No force unwraps, hardcoded hex values, or `print()` calls in any committed Swift file

## Source References

- PHASES.md: Phase 5 -- Tracker Home Dashboard (in-scope: vertical ScrollView feed with LazyVStack, 32pt card gaps; skeleton loading placeholders per §13; empty/first-launch states)
- Design Spec v1.1 §12.2 (Tracker Home Dashboard -- feed order: 6 sections)
- Design Spec v1.1 §5 (spacing tokens: space-16 = 16pt horizontal inset, space-32 = 32pt inter-card gap)
- Design Spec v1.1 §13 (loading states: skeleton placeholders on card surfaces; never full-screen spinners)
- cadence-motion skill (skeleton shimmer: 1.2s loop, left-to-right; static opacity 0.4 under reduceMotion)
- swiftui-production skill (LazyVStack for feed views, @Observable, view body extraction at 50 lines)
- cadence-data-layer skill (SwiftData model access via ModelContext injection)
- cadence-testing skill (DI via ModelContext parameter for testability)
