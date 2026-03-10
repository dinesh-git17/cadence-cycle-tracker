# Asset and Haptic Finalization

**Epic ID:** PH-14-E4
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** M
**Status:** Draft

---

## Objective

Close the two pre-ship open items from Design Spec v1.1 §15 that are tagged for this phase: (1) define and implement the haptic pattern library across all Cadence interaction types, and (2) finalize `CadenceMark.swift` with the traced Bezier control points from the locked PNG asset. Both items were deferred during feature phases to avoid churn. Neither can ship as a placeholder.

## Problem / Context

Design Spec v1.1 §15 lists two open items relevant to Phase 14:

**Haptic pattern library** -- tagged "Before Log Sheet implementation" but deferred. Design Spec §13 specifies `UIImpactFeedbackGenerator .medium` on Log save as the one explicit assignment. All other interaction types (chip toggle, period toggle, sharing strip pause, error states) have no defined haptic assignment. Without a library, individual views implement haptics inconsistently or not at all, producing a product where some interactions give tactile feedback and others do not.

**Trace Bezier path from locked mark PNG** -- tagged "Pre-ship." The `CadenceMark.swift` Shape file currently contains placeholder control point values from the Splash Screen Spec ("`// Values below are PLACEHOLDERS -- replace with traced coordinates`"). Shipping with placeholder geometry produces a mark that does not match the locked brand asset. This violates the brand lock stated in Design Spec v1.1 §0.

Both items are bounded, well-understood tasks. Neither requires architectural change. Together they complete the visual and tactile finalization of the shipped product.

## Scope

### In Scope

- Haptic pattern library: a `HapticEngine` namespace or `HapticFeedback` enum that maps interaction types to `.sensoryFeedback` modifier values or `UIImpactFeedbackGenerator` calls
- Haptic assignments for all required interaction types:
  - Log save: `.medium` UIImpact (explicitly specified in Design Spec §13)
  - Symptom chip toggle on: `.sensoryFeedback(.selection, trigger:)` (SwiftUI declarative)
  - Period started / ended toggle: `.sensoryFeedback(.impact(weight: .medium), trigger:)`
  - Sharing strip pause toggle: `.sensoryFeedback(.start, trigger:)` (pause) / `.sensoryFeedback(.stop, trigger:)` (resume)
  - Error toast appearance: `.sensoryFeedback(.error, trigger:)`
  - Log Sheet save success (optimistic confirm): `UIImpactFeedbackGenerator(.medium).impactOccurred()` per Design Spec §13 explicit assignment
- Haptic implementation applied to all call sites: Log Sheet Save CTA, SymptomChip, PeriodToggle, sharing strip toggle, error toast
- `CadenceMark.swift` Bezier path finalization: replace all placeholder `CGPoint` values with traced coordinates from `cadence-mark-light.png`
- Reduced motion gating on all custom haptic calls where applicable (`.sensoryFeedback` modifiers are system-gated; `UIImpactFeedbackGenerator` calls are not auto-gated and must be wrapped in a `@Environment(\.accessibilityReduceMotion)` check)
- Splash screen verification after Bezier update: confirm `CadenceMark.swift` renders the mark correctly at both 160x120pt bounding box in light and dark mode

### Out of Scope

- Custom CoreHaptics patterns -- no synchronized audio/haptic requirement exists in the current spec
- Haptic feedback on navigation transitions (not specified in Design Spec §11)
- App icon asset changes (locked in Design Spec §0, managed in Phase 0 and Phase 2)
- Wordmark font change (post-beta per Design Spec §15)
- Any new visual feature not explicitly listed above

## Dependencies

| Dependency                                                                       | Type | Phase/Epic         | Status | Risk |
| -------------------------------------------------------------------------------- | ---- | ------------------ | ------ | ---- |
| Log Sheet Save CTA implemented with tap handler                                  | FS   | PH-4-E2            | Open   | Low  |
| SymptomChip tap handler implemented with optimistic state toggle                 | FS   | PH-4-E3            | Open   | Low  |
| Period toggle buttons implemented with state handling                            | FS   | PH-4-E2            | Open   | Low  |
| Sharing strip pause toggle implemented (Tracker Home)                            | FS   | PH-5-E2            | Open   | Low  |
| Error toast presentation mechanism implemented                                   | FS   | PH-7 or PH-5       | Open   | Low  |
| `CadenceMark.swift` exists with placeholder Bezier values per Splash Screen Spec | FS   | PH-2-E1            | Open   | Low  |
| Locked brand asset `cadence-mark-light.png` is in `Images.xcassets`              | FS   | PH-0-E2 or PH-2-E1 | Open   | Low  |

## Assumptions

- Figma has access to the locked `cadence-mark-light.png` asset (uploaded or linked). The Bezier trace is performed using Figma's Pen tool on the PNG, reading anchor point positions as percentage values of the 160x120pt bounding box.
- iOS 26 supports the full `.sensoryFeedback()` modifier API (introduced in iOS 17). The deployment target is iOS 26, so all `.sensoryFeedback` types are available without version checks.
- The sharing strip, Log Sheet, and error toast are all SwiftUI views where `.sensoryFeedback()` modifiers can be applied declaratively to a parent view triggered by a `@State` or `@Observable` property change.
- `UIImpactFeedbackGenerator` is used only for the Log save interaction, consistent with the Design Spec §13 explicit assignment. All other haptics use the declarative `.sensoryFeedback()` modifier.
- Reduced motion does not apply to haptic feedback -- Apple's own guidance distinguishes visual animation (gated by `accessibilityReduceMotion`) from haptic feedback (not gated). However, any haptic tied to an animation (e.g., chip tap-down `scaleEffect`) is only called when the animation executes, so reduced motion naturally suppresses paired haptics via the animation gate.

## Risks

| Risk                                                                                                    | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bezier trace produces a mark that does not match the PNG due to curve approximation                     | Medium     | Medium | Trace all anchor points and both handle positions for each cubic curve segment. Verify in Simulator at 1x and 2x (retina) by overlaying the `.trim(from: 0, to: 1)` stroke result against the PNG reference. Adjust control points until they match visually.                            |
| Figma Pen tool produces points in pixel units, not percentage coordinates                               | Low        | Low    | Divide all pixel coordinates by the PNG's pixel dimensions to get normalized values, then multiply by the `rect.width` and `rect.height` in `path(in:)`.                                                                                                                                 |
| Haptic feedback fires on the background thread if state updates are dispatched off main actor           | Low        | Medium | All `.sensoryFeedback()` calls are attached to SwiftUI view modifiers and are dispatched by the system on the main thread. `UIImpactFeedbackGenerator.impactOccurred()` must be called on the main thread -- ensure it is called from a `@MainActor` context in the Log Sheet ViewModel. |
| Sharing strip `.sensoryFeedback(.start/.stop)` is not the right feedback type and feels wrong on device | Low        | Low    | `.sensoryFeedback` types can be adjusted after on-device testing. The library definition in S1 is the canonical assignment -- if a type feels wrong on device, update the library and all call sites in the same PR.                                                                     |

---

## Stories

### S1: Haptic Pattern Library Definition

**Story ID:** PH-14-E4-S1
**Points:** 2

Define the canonical haptic pattern library as a Swift enum or namespace that maps Cadence interaction types to their haptic assignments. This is the single source of truth for all haptic behavior in the app.

**Acceptance Criteria:**

- [ ] A `HapticPattern` type (enum with static methods or a namespace) is defined in `Cadence/Core/HapticPattern.swift`
- [ ] The following interaction mappings are defined and documented with an inline comment citing the source:
  - `logSave`: `UIImpactFeedbackGenerator(.medium).impactOccurred()` -- cited from Design Spec §13
  - `chipToggle`: `.sensoryFeedback(.selection, trigger:)`
  - `periodToggle`: `.sensoryFeedback(.impact(weight: .medium), trigger:)`
  - `sharingPause`: `.sensoryFeedback(.start, trigger:)`
  - `sharingResume`: `.sensoryFeedback(.stop, trigger:)`
  - `errorToast`: `.sensoryFeedback(.error, trigger:)`
- [ ] `HapticPattern.swift` is registered in `project.yml` under the `Cadence` target
- [ ] No `print()` statement in `HapticPattern.swift`
- [ ] `scripts/protocol-zero.sh` exits 0 on `HapticPattern.swift`
- [ ] `scripts/check-em-dashes.sh` exits 0 on `HapticPattern.swift`

**Dependencies:** None
**Notes:** The library does not need to abstract `UIImpactFeedbackGenerator` into the same type as `.sensoryFeedback` -- they are different call patterns. `logSave` uses `UIImpactFeedbackGenerator` because the Design Spec explicitly names that class; all others use `.sensoryFeedback` for the declarative SwiftUI API. The library simply documents the canonical assignment, not a shared dispatcher.

---

### S2: Log Sheet and Chip Haptics

**Story ID:** PH-14-E4-S2
**Points:** 3

Apply haptic feedback to the Log Sheet Save CTA and the SymptomChip toggle interaction. These are the two highest-frequency haptic surfaces in the app.

**Acceptance Criteria:**

- [ ] The Log Sheet Save CTA calls `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` on the main thread immediately after the `save()` action is dispatched -- not before, not after an async await point
- [ ] `UIImpactFeedbackGenerator` is instantiated with `.prepare()` called when the Save button becomes enabled (not at view appear time) to reduce latency
- [ ] Every SymptomChip Button in the Log Sheet chip grid has `.sensoryFeedback(.selection, trigger: isSelected)` applied; the feedback fires on selection change, not on every tap (it is trigger-based, not `onChange` based)
- [ ] Tapping a chip rapidly (3 taps in 1 second) produces feedback on each state change without the system throttling the feedback -- the trigger value changes on each tap
- [ ] No chip haptic fires on initial Log Sheet presentation (chips are unselected by default, no trigger change occurs on appear)
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-14-E4-S1
**Notes:** `.sensoryFeedback(.selection, trigger:)` fires when the trigger value changes. Since `isSelected` is a `Bool`, toggling from `false` to `true` fires the feedback; toggling back fires it again. This is the correct behavior for a chip toggle. Do not use `.onChange(of:)` + `UIImpactFeedbackGenerator` for chips -- the declarative modifier is cleaner and handles system haptic throttling correctly.

---

### S3: Period Toggle, Sharing Strip, and Error Haptics

**Story ID:** PH-14-E4-S3
**Points:** 3

Apply haptic feedback to the period toggle buttons, the sharing strip pause/resume toggle, and the error toast presentation. These interactions are lower frequency but equally important for product feel.

**Acceptance Criteria:**

- [ ] The "Period started" button has `.sensoryFeedback(.impact(weight: .medium), trigger: isPeriodActive)` applied; feedback fires when `isPeriodActive` transitions from `false` to `true`
- [ ] The "Period ended" button has the same pattern with its own trigger variable
- [ ] The sharing strip pause toggle has `.sensoryFeedback(.start, trigger: isSharingActive)` that fires when sharing is paused (transition to `isSharingActive == false`) and `.sensoryFeedback(.stop, trigger: isSharingActive)` that fires when sharing is resumed -- or combined as a single `.sensoryFeedback(.impact(weight: .medium), trigger: isSharingActive)` if the single-trigger pattern is semantically sufficient
- [ ] The error toast view (non-blocking bottom-of-screen toast from Design Spec §13) has `.sensoryFeedback(.error, trigger: isErrorVisible)` applied; feedback fires when `isErrorVisible` transitions to `true`
- [ ] No haptic fires on any of these surfaces on initial view appearance (trigger values are not changing at appear time)
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-14-E4-S1, PH-14-E4-S2
**Notes:** The sharing strip pause/resume interaction uses a `is_paused` flag on the connection. The SwiftUI trigger for the haptic should be bound to the local `@State` or `@Observable` property that reflects the optimistic UI state (immediate) -- not to the Supabase-confirmed state (async). This is consistent with the optimistic update pattern in cadence-motion and cadence-sync skills.

---

### S4: CadenceMark Bezier Path Finalization

**Story ID:** PH-14-E4-S4
**Points:** 3

Replace the placeholder Bezier control points in `CadenceMark.swift` with coordinates traced from the locked `cadence-mark-light.png` asset. The traced path must match the visual shape of the locked PNG when rendered in the Simulator at the 160x120pt bounding box.

**Acceptance Criteria:**

- [ ] `CadenceMark.swift` contains no placeholder comment (`// Values below are PLACEHOLDERS`, `// replace with traced coordinates`, or equivalent)
- [ ] All `CGPoint` values in `path(in:)` are expressed as percentage multipliers of `rect.width` and `rect.height` (e.g., `x: rect.width * 0.18`) -- no hardcoded pixel values
- [ ] The rendered stroke in Simulator at 160x120pt visually matches the locked `cadence-mark-light.png` when overlaid at the same proportions -- verified by Dinesh on-device or in Simulator screenshot comparison
- [ ] The mark renders correctly in dark mode: `CadenceTerracotta` in light mode, `CadenceTextPrimary` / warm ivory (`#EDE4D8`) in dark mode per the `CadenceMark` color asset -- no conditional Swift color logic needed
- [ ] `.trim(from: 0, to: drawProgress).stroke(...)` animates the mark from start terminal to end terminal in a single continuous stroke -- no visible jump or discontinuity at any point in the draw animation
- [ ] `SplashView.swift` path-draw animation (`drawProgress: 0 -> 1`, 1.0s easeInOut, 0.2s delay) functions correctly with the finalized coordinates -- verified by running the splash sequence in Simulator
- [ ] Reduced motion path in `SplashView.swift` (`drawProgress = 1.0` immediately, no animation) renders the complete mark instantly -- verified in Simulator with Reduce Motion enabled in Accessibility settings
- [ ] `scripts/protocol-zero.sh` exits 0 on `CadenceMark.swift`
- [ ] `scripts/check-em-dashes.sh` exits 0 on `CadenceMark.swift`

**Dependencies:** None
**Notes:** The trace workflow: open Figma, import or reference `cadence-mark-light.png` (160x120pt), use the Pen tool to click on anchor points and drag handles along the mark's curves, read anchor point coordinates from Figma's X/Y display, divide by 160 (width) and 120 (height) to get percentage values, update `CadenceMark.swift`. For a mark with 2-3 curve segments, expect 3-4 `addCurve(to:control1:control2:)` calls. If the mark has multiple disconnected strokes, use `path.move(to:)` between them.

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
- [ ] `CadenceMark.swift` contains no placeholder comments; the rendered mark matches the locked PNG
- [ ] Haptic feedback fires for all six defined interaction types on a physical device (verified by Dinesh on iPhone -- haptics are not emulated in Simulator)
- [ ] No haptic fires on view appearance for any surface
- [ ] Phase objective is advanced: visual and tactile product feel is final; no placeholder assets or undefined haptic behaviors remain
- [ ] Applicable skill constraints satisfied: cadence-motion (all custom animations and interactions have haptic assignment; reduced motion gating where applicable), swiftui-production (no force unwraps, no dead code), cadence-xcode-project (new files registered in project.yml)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Design Spec v1.1 §13 (Log save haptic: UIImpactFeedbackGenerator .medium), §15 open items (haptic library and Bezier trace -- both closed)

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: haptic library + CadenceMark Bezier finalization)
- Design Spec v1.1 §13 (States and Feedback -- success haptic: UIImpactFeedbackGenerator .medium on Log save)
- Design Spec v1.1 §15 Open Items (Haptic pattern library: define .light/.medium/.heavy assignments -- Pre-ship; Trace Bezier path from locked mark PNG -- Pre-ship)
- Cadence_SplashScreen_Spec.md §Path Draw -- Architecture (CadenceMark.swift placeholder values note; Bezier finalization is final step of implementation checklist)
- cadence-motion skill (chip tap-down spring scaleEffect 0.95, 0.15s chip toggle; all interactions with motion have haptic assignment)
- Apple Developer Documentation: SensoryFeedback (iOS 17+), UIImpactFeedbackGenerator
