# Motion System, Haptics, and Accessibility Compliance

**Epic ID:** PH-4-E5
**Phase:** 4 -- Tracker Navigation Shell & Core Logging
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `ChipPressStyle`, `ShimmerModifier`, and the chip toggle cross-dissolve animation; apply them to all Phase 4 interactive surfaces; and perform a full reduced-motion compliance audit across every animated view produced in Phase 4. This epic makes Phase 4 motion-complete: the chip spring is consistent across all consumers, the cross-dissolve is scoped to the `isActive` value only, the shimmer is available for Phase 5's loading states, and no animated surface in Phase 4 lacks an `accessibilityReduceMotion` gate.

## Problem / Context

Animation correctness in Cadence is a design requirement, not a polish pass. The cadence-motion skill defines exact timing values for four interaction patterns that appear in Phase 4: the chip tap-down spring (`scaleEffect(0.95)`, response `0.3`, dampingFraction `0.7`), the chip toggle cross-dissolve (`0.15s easeOut`), the skeleton shimmer (`1.2s linear repeating`), and all reduced-motion gates. Any deviation from these specifications -- a different spring value, a missing `accessibilityReduceMotion` check, an implicit `.animation(.default)` -- is a motion spec violation that the cadence-motion enforcement checklist will flag.

The reduced-motion requirement is an accessibility requirement. iOS VoiceOver users are not the only audience for `accessibilityReduceMotion` -- many users with vestibular disorders, motion sensitivity, or epilepsy conditions enable Reduce Motion. A chip that ignores `reduceMotion == true` and still performs the spring scale is an accessibility failure by any WCAG 2.2 standard.

`ChipPressStyle` is implemented as a `ButtonStyle` so it is reusable by injection: `SymptomChip`, `PeriodToggle` buttons, and any future chip surfaces automatically pick up the correct press behavior by applying `.buttonStyle(ChipPressStyle())`. This avoids per-chip animation duplication.

`ShimmerModifier` is implemented now (Phase 4) because it is immediately needed by Phase 5's Tracker Home feed skeleton loading. If it is deferred to Phase 5, Phase 5 must implement it at the same time as the feed content, increasing Phase 5 complexity. Implementing it in Phase 4 as a reusable `ViewModifier` available via a `.shimmer()` extension costs 3 story points in Phase 4 and saves effort in Phase 5, Phase 9, and Phase 11 (all of which have skeleton loading states).

**Source references that define scope:**

- cadence-motion skill §1 (chip tap-down spring: scaleEffect 0.95, response 0.3, damping 0.7; `ChipPressStyle` code pattern)
- cadence-motion skill §2 (chip toggle cross-dissolve: 0.15s easeOut; scoped to `isActive` value; instant under reduceMotion)
- cadence-motion skill §5 (skeleton shimmer: 1.2s linear repeat; static opacity under reduceMotion)
- cadence-motion skill §Reduced Motion Requirements (every custom animation gated; nil animation = instant)
- cadence-motion skill §Haptic Feedback (UIImpactFeedbackGenerator .medium on Log save -- note: haptic is wired in PH-4-E2-S5; this epic verifies the motion system context only)
- Design Spec v1.1 §11 (motion table: chip tap-down spring, toggle cross-dissolve)
- Design Spec v1.1 §13 (skeleton loading shimmer)
- Design Spec v1.1 §14 (reduced motion: all custom animations gated on `@Environment(\.accessibilityReduceMotion)`)
- PHASES.md Phase 4 in-scope: "chip tap-down spring animation (scaleEffect 0.95, response 0.3, damping 0.7); chip toggle cross-dissolve (0.15s easeOut, instant state change); reduced motion gating on all animations"
- cadence-accessibility skill (accessibilityReduceMotion gate; 44pt targets already verified in E3/E4)

## Scope

### In Scope

- `Cadence/Views/Shared/ChipPressStyle.swift`: `struct ChipPressStyle: ButtonStyle` implementing `scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)` with `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)` when `reduceMotion == false`; under `reduceMotion == true`, no scale change occurs, the tap still registers
- Apply `.buttonStyle(ChipPressStyle())` to: `SymptomChip` (when `isReadOnly == false`), both `PeriodToggle` buttons
- `Cadence/Views/Shared/ShimmerModifier.swift`: `struct ShimmerModifier: ViewModifier` implementing the 1.2s linear repeating gradient shimmer per cadence-motion skill §5 code pattern; under `reduceMotion == true`, renders static `opacity(0.4)` placeholder with no animation loop; `extension View { func shimmer() -> some View { modifier(ShimmerModifier()) } }`
- Chip toggle cross-dissolve wired into `SymptomChip`: `.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)` scoped to the `isActive` parameter -- applied to the chip's outer container so background, border, text color, and font weight all transition together
- `PeriodToggle` button state cross-dissolve: same 0.15s easeOut scoped to each button's active binding
- `PrimaryButton` loading state transition: no custom animation is required (the `ProgressView` appears/disappears instantly -- the `isLoading` state change is not animated per the motion spec; width-lock prevents jitter without needing animation)
- Reduced-motion compliance audit: verify every `@Observable` ViewModel in Phase 4 that drives animated state reads `@Environment(\.accessibilityReduceMotion)` in the view consuming it -- chip toggles, period toggles, and the shimmer modifier
- `project.yml` updated for new Swift files; `xcodegen generate` exits 0

### Out of Scope

- Sharing strip crossfade (0.2s easeInOut): implemented in Phase 5 when the strip is built
- Partner Dashboard hide crossfade (0.25s easeInOut): Phase 9
- Haptic feedback invocation: wired in PH-4-E2-S5 (`UIImpactFeedbackGenerator .medium` on Save tap); this epic verifies the motion system context but does not re-implement the haptic
- Navigation push and sheet presentation transitions: system-managed, no custom animation required or permitted
- `@accessibilityLargeText` Dynamic Type scaling: verified in PH-4-E4-S4

## Dependencies

| Dependency                                                                   | Type | Phase/Epic | Status | Risk                                                                       |
| ---------------------------------------------------------------------------- | ---- | ---------- | ------ | -------------------------------------------------------------------------- |
| PH-4-E3 complete (SymptomChip: chip visual states without animation)         | FS   | PH-4-E3    | Open   | High -- ChipPressStyle is applied to SymptomChip; the component must exist |
| PH-4-E4 complete (PeriodToggle, PrimaryButton: components without animation) | FS   | PH-4-E4    | Open   | High -- ChipPressStyle is applied to PeriodToggle buttons                  |
| PH-4-E2 complete (Log Sheet: chip grid and period toggle section in place)   | FS   | PH-4-E2    | Open   | Medium -- animation compliance verified in the Log Sheet context           |

## Assumptions

- `ChipPressStyle` is a shared `ButtonStyle` in `Cadence/Views/Shared/`. It is not defined inside `SymptomChip.swift`. This allows it to be applied to any future chip-like surface without importing or modifying SymptomChip.
- The cross-dissolve `.animation(_:value:)` is applied to `SymptomChip`'s outer container view with `value: isActive`. Since `isActive` is a non-binding value parameter, `SymptomChip` must redraw when `isActive` changes -- SwiftUI's value comparison handles this correctly for `Bool`.
- `ShimmerModifier` uses `GeometryReader` internally to measure the view width for the gradient offset calculation. This is an accepted `GeometryReader` use case per the swiftui-production skill (GeometryReader is permitted when the geometry is genuinely needed and is scoped to the modifier, not a full-screen layout).
- The `@Environment(\.accessibilityReduceMotion)` environment value is read inside the `ViewModifier`'s `body` and inside `ChipPressStyle`'s `makeBody` -- not passed as a parameter from the outside.

## Risks

| Risk                                                                                                                      | Likelihood | Impact | Mitigation                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.animation(_:value:)` on `SymptomChip` outer container causes ALL property changes to animate, not just color/appearance | Medium     | Medium | Scope the animation modifier with `value: isActive` -- only changes triggered by `isActive` mutations animate; changes to `label` or `isSexChip` (which do not drive animation) are unaffected by the `value:` scoping |
| `ShimmerModifier` `GeometryReader` causes layout shifts in the shimmer overlay                                            | Low        | Low    | The `GeometryReader` is inside the `.overlay`, not wrapping the content -- it measures the overlay geometry, not the content frame; verify no layout shift in Preview                                                  |
| `ChipPressStyle` spring does not feel snappy enough or is inconsistent with other spring usages                           | Low        | Medium | Spring values are locked per the cadence-motion skill (response: 0.3, dampingFraction: 0.7); do not tune independently; if the feel is wrong, flag it as a motion spec gap requiring designer confirmation             |
| `accessibilityReduceMotion` check returns wrong value in unit tests                                                       | Low        | Low    | Unit tests for Phase 4 motion logic mock the environment value; see cadence-testing skill for dependency injection patterns                                                                                            |

---

## Stories

### S1: ChipPressStyle ButtonStyle -- spring tap-down with reduceMotion gate

**Story ID:** PH-4-E5-S1
**Points:** 3

Implement `ChipPressStyle` and apply it to all Phase 4 chip surfaces: `SymptomChip` interactive instances and both `PeriodToggle` buttons.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/ChipPressStyle.swift` exists with `struct ChipPressStyle: ButtonStyle`
- [ ] `makeBody` reads `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
- [ ] Press animation: `scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)` applied to `configuration.label`
- [ ] Spring: `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)` applied only when `!reduceMotion`
- [ ] Under `reduceMotion == true`: no scale change on press; the tap still registers and the button action fires
- [ ] `SymptomChip` (when `isReadOnly == false`) has `.buttonStyle(ChipPressStyle())` applied to its `Button` wrapper -- replaces the previous `.buttonStyle(.plain)` placeholder
- [ ] Both `PeriodToggle` buttons have `.buttonStyle(ChipPressStyle())` applied
- [ ] In the iOS 26 simulator with Reduce Motion OFF: tapping a symptom chip produces a visible 0.95x scale press animation with a spring release
- [ ] In the iOS 26 simulator with Reduce Motion ON (Settings > Accessibility > Motion > Reduce Motion): tapping a chip shows no scale change; the tap registers; the toggle state changes
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded spring values outside `ChipPressStyle.swift` -- all chip surfaces use `ChipPressStyle`, not inline spring animations

**Dependencies:** PH-4-E3, PH-4-E4

**Notes:** Apply `ChipPressStyle` in `SymptomChip.swift` by replacing `.buttonStyle(.plain)` with `.buttonStyle(ChipPressStyle())`. In `PeriodToggle.swift`, apply `.buttonStyle(ChipPressStyle())` to each button. Verify the spring spec matches exactly: `response: 0.3, dampingFraction: 0.7`. Using `.bouncy`, `.snappy`, or `.smooth` spring presets is prohibited -- the exact response/damping values from the cadence-motion skill are required.

---

### S2: Chip toggle cross-dissolve -- 0.15s easeOut, reduceMotion gate

**Story ID:** PH-4-E5-S2
**Points:** 2

Wire the 0.15s easeOut cross-dissolve to `SymptomChip`'s `isActive` state transition and `PeriodToggle`'s active state transitions. The state change (chip selected/deselected) is always instant -- only the visual cross-dissolve animates.

**Acceptance Criteria:**

- [ ] `SymptomChip` outer container has `.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)` applied with `@Environment(\.accessibilityReduceMotion) private var reduceMotion` read inside `SymptomChip`
- [ ] The animation is scoped to `value: isActive` only -- changes to `label`, `isSexChip`, or any other parameter do not trigger the cross-dissolve
- [ ] State change (`isActive` flip in the caller's ViewModel) is instant -- the cross-dissolve governs visual appearance only; the underlying data state updates immediately on tap before the animation begins
- [ ] `PeriodToggle` "Period started" button: `.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: periodStarted.wrappedValue)` applied to the button's background/text container
- [ ] `PeriodToggle` "Period ended" button: same animation scoped to `value: periodEnded.wrappedValue`
- [ ] Under `reduceMotion == true`: chip and toggle state changes are instant visual swaps (nil animation produces instant state change)
- [ ] No implicit `.animation(.default)` or bare `withAnimation {}` blocks anywhere in SymptomChip.swift or PeriodToggle.swift
- [ ] In the iOS 26 simulator with Reduce Motion OFF: tapping a symptom chip produces a smooth 0.15s color cross-dissolve
- [ ] In the iOS 26 simulator with Reduce Motion ON: tapping a chip produces an instant state change with no visual transition
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E5-S1, PH-4-E3, PH-4-E4

**Notes:** The cross-dissolve applies to ALL visual properties that change on toggle: background fill, border presence, text color, font weight. These all change together because they are all conditionally rendered based on `isActive`. The `.animation(_:value:)` scoped to `isActive` will animate all property changes triggered by `isActive` mutations -- this is the correct behavior.

---

### S3: ShimmerModifier -- 1.2s loop, static placeholder under reduceMotion

**Story ID:** PH-4-E5-S3
**Points:** 3

Implement `ShimmerModifier` as a reusable `ViewModifier` with the `shimmer()` view extension. This modifier is used by Phase 5 (Tracker Home skeleton loading), Phase 9 (Partner Dashboard loading), and Phase 11 (Reports loading) -- implementing it in Phase 4 eliminates duplication across all three phases.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/ShimmerModifier.swift` exists with `struct ShimmerModifier: ViewModifier`
- [ ] Modifier reads `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
- [ ] Under `reduceMotion == false`: applies a `LinearGradient` overlay (clear → `Color(.systemBackground).opacity(0.6)` → clear) that animates from left to right using a `@State private var phase: CGFloat` offset; animation is `.linear(duration: 1.2).repeatForever(autoreverses: false)` started in `.onAppear`
- [ ] The gradient overlay uses `GeometryReader` inside the `.overlay` to measure the content width and compute the end position for `phase`
- [ ] Under `reduceMotion == true`: applies `.opacity(0.4)` to the content with no animation -- static low-opacity placeholder
- [ ] `extension View { func shimmer() -> some View { modifier(ShimmerModifier()) } }` is defined in the same file
- [ ] Shimmer stops when the view disappears (`.onDisappear` resets `phase` to prevent memory/animation state leak)
- [ ] The shimmer animation does NOT loop under `reduceMotion == true` -- verified with Reduce Motion ON in simulator
- [ ] A SwiftUI Preview shows a `RoundedRectangle` with `.shimmer()` applied, both with and without reduce motion (toggle via `@Environment` override in preview)
- [ ] `project.yml` updated; `xcodebuild build` exits 0

**Dependencies:** PH-4-E5-S1

**Notes:** The `ShimmerModifier` targets `Color(.systemBackground).opacity(0.6)` for the highlight color rather than `Color.white.opacity(0.6)` -- this adapts correctly to dark mode where white shimmer on dark card surfaces would be incorrect. Verify the shimmer appearance in both light and dark mode in the Preview. `.clipped()` must be applied after the overlay to prevent the gradient from bleeding outside the view bounds.

---

### S4: Reduced motion compliance audit -- all Phase 4 animated surfaces

**Story ID:** PH-4-E5-S4
**Points:** 2

Systematically verify every animated surface in Phase 4 has a correct `accessibilityReduceMotion` gate. This is a gate, not an enhancement -- any Phase 4 view with custom animation that lacks this check fails the Phase 4 Definition of Done.

**Acceptance Criteria:**

- [ ] `SymptomChip.swift`: `@Environment(\.accessibilityReduceMotion)` is present; cross-dissolve animation is nil when `reduceMotion == true`
- [ ] `ChipPressStyle.swift`: `@Environment(\.accessibilityReduceMotion)` is present; scale animation is nil when `reduceMotion == true`
- [ ] `PeriodToggle.swift`: `@Environment(\.accessibilityReduceMotion)` is present; toggle cross-dissolve is nil when `reduceMotion == true`
- [ ] `ShimmerModifier.swift`: `@Environment(\.accessibilityReduceMotion)` is present; shimmer is replaced with static opacity when `reduceMotion == true`
- [ ] `TrackerShell.swift`: no custom animations present (sheet presentation is system-managed; tab transitions are system-managed; the onChange interceptor performs synchronous state changes, not animated ones) -- confirmed by code review
- [ ] `LogSheetView.swift`: no custom animations beyond chip surfaces; sheet detent transitions are system-managed
- [ ] A Bash grep confirms no bare `withAnimation {` calls (without explicit value binding or reduceMotion gate) exist in any Phase 4 Swift file: `grep -r "withAnimation {" Cadence/Views/ Cadence/ViewModels/` returns 0 results
- [ ] A Bash grep confirms no `.animation(.default)` or `.animation(Animation.` calls exist in any Phase 4 Swift file (only `.animation(_:value:)` pattern is permitted)
- [ ] `scripts/protocol-zero.sh` exits 0 on all Phase 4 Swift files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all Phase 4 Swift files
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E5-S1, PH-4-E5-S2, PH-4-E5-S3

**Notes:** The grep check for `withAnimation {` (with a literal open-brace and no explicit `value:`) catches the anti-pattern of implicit animations. The correct pattern is `withAnimation(.easeOut(duration: 0.15)) { state = newValue }` used only when `.animation(_:value:)` cannot be applied -- which should be rare in Phase 4. If any `withAnimation {` without explicit parameters is found, replace it with the `value:` scoped `.animation` pattern.

---

### S5: Phase 4 full motion and accessibility sign-off

**Story ID:** PH-4-E5-S5
**Points:** 2

Run the cadence-motion skill enforcement checklist and the cadence-accessibility skill enforcement checklist against all Phase 4 surfaces. Confirm Phase 4 is motion-complete and accessibility-compliant before declaring the phase done.

**Acceptance Criteria:**

- [ ] cadence-motion skill enforcement checklist: all items checked against Phase 4 surfaces (list confirmed in story Notes)
- [ ] cadence-accessibility skill: all interactive chips have 44pt targets (verified from PH-4-E3-S1 and E4); VoiceOver labels correct (verified from PH-4-E3-S4 and E4-S4); Sex chip lock icon label verified
- [ ] Reduce Motion ON: every chip tap, period toggle, and shimmer in Phase 4 produces an instant state change with no visual motion
- [ ] Reduce Motion OFF: chip tap produces 0.95x spring; chip toggle produces 0.15s easeOut cross-dissolve; shimmer produces 1.2s repeating gradient
- [ ] No animation duration or spring value in Phase 4 source files deviates from the cadence-motion skill timing table
- [ ] Phase 4 source file grep: `grep -rn "\.spring\|easeOut\|easeIn\|linear\|duration" Cadence/` returns ONLY values from the allowed set: spring(response: 0.3, dampingFraction: 0.7), easeOut(duration: 0.15), linear(duration: 1.2) -- no other durations or curves
- [ ] `swiftlint-on-edit.sh` hook reported no unresolved warnings on any Phase 4 Swift file
- [ ] `scripts/protocol-zero.sh` exits 0 on all Phase 4 source files
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Final `xcodebuild build` exits 0 with zero warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

**Dependencies:** PH-4-E5-S1, PH-4-E5-S2, PH-4-E5-S3, PH-4-E5-S4

**Notes:** cadence-motion checklist items to verify for Phase 4:

1. `@Environment(\.accessibilityReduceMotion)` read and respected -- E3, E4, E5 chips and toggles
2. Under `reduceMotion == true`, all custom animations produce instant state changes -- verified in S4
3. Hold/dwell periods are preserved under reduced motion -- no dwell periods in Phase 4 surfaces
4. UI state updates do not wait on network responses -- verified in PH-4-E2-S5 (onSave fires before sync enqueue)
5. Duration and curve match timing table exactly -- verified in S5 grep
6. Skeleton shimmer applied only to loading placeholders -- ShimmerModifier is the sole shimmer mechanism
7. Shimmer under reduceMotion is static opacity, not a slower loop -- verified in S3
8. Chip press uses ChipPressStyle (spring response 0.3, dampingFraction 0.7) -- verified in S1
9. Crossfades use `.animation(_:value:)` scoped to specific changing property -- verified in S2
10. No implicit animations wrapping unrelated state changes -- verified in S4 grep
11. `isReadOnly` chips have no press animation -- verified in PH-4-E3-S4

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
- [ ] ChipPressStyle applied to all Phase 4 chip and toggle surfaces
- [ ] Cross-dissolve (0.15s easeOut) applied to SymptomChip and PeriodToggle
- [ ] ShimmerModifier available for Phase 5/9/11 loading states
- [ ] Every animated surface gates on `@Environment(\.accessibilityReduceMotion)`
- [ ] Phase objective is advanced: Phase 4 is motion-complete; cadence-motion skill checklist fully satisfied
- [ ] cadence-motion skill enforcement checklist: all 11 items verified (documented in S5 Notes)
- [ ] cadence-accessibility skill: reduceMotion compliance confirmed on all animated surfaces
- [ ] swiftui-production skill: no implicit animations; no `.animation(.default)`; all animations use `value:` scoping
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- [ ] No custom spring, duration, or curve values outside the cadence-motion timing table

## Source References

- PHASES.md: Phase 4 -- Tracker Navigation Shell & Core Logging (in-scope: chip tap-down spring, toggle cross-dissolve, reduced motion gating)
- Design Spec v1.1 §11 (motion table: chip tap-down spring spec, toggle cross-dissolve spec)
- Design Spec v1.1 §13 (skeleton loading: shimmer spec)
- Design Spec v1.1 §14 (accessibility: reduced motion gating on all custom animations)
- cadence-motion skill §1 (ChipPressStyle code pattern, spring values)
- cadence-motion skill §2 (chip toggle cross-dissolve: 0.15s easeOut, instant state change, value scoping)
- cadence-motion skill §5 (skeleton shimmer: 1.2s linear repeat, static placeholder under reduceMotion)
- cadence-motion skill §Reduced Motion Requirements (nil animation = instant; all custom animations gated)
- cadence-motion skill enforcement checklist (11-item pre-merge gate)
- cadence-accessibility skill (accessibilityReduceMotion compliance; 44pt targets)
