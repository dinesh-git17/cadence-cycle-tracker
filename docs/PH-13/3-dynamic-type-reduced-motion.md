# Dynamic Type and Reduced Motion Compliance

**Epic ID:** PH-13-E3
**Phase:** 13 -- Accessibility Compliance
**Estimated Size:** M
**Status:** Draft

---

## Objective

Verify that all text in the app scales correctly with Dynamic Type at all size categories through Accessibility5, that the 48pt countdown numeral scales via `@ScaledMetric`, that every custom animation is gated on `@Environment(\.accessibilityReduceMotion)`, and that the Partner Bento grid collapses from 2-up to 1-up at the Accessibility1 Dynamic Type threshold.

## Problem / Context

Design Spec v1.1 §2 mandates Dynamic Type compliance for all text and prohibits fixed-size text containers. §14 requires reduced motion gating on all custom animations and the Bento grid collapse. The cadence-accessibility skill §2, §4, and §5 define the precise implementation patterns for each requirement. These requirements were concurrent constraints during Phases 4-12 but are formally verified and remediated here as a cross-cutting audit pass.

The highest-risk items are: (1) the custom 48pt countdown numeral, which uses `.system(size: 48)` and requires `@ScaledMetric(relativeTo: .largeTitle)` to remain compliant; (2) fixed-height containers added during rapid feature delivery that clip text at Accessibility3; (3) animations added in Phase 4-9 that may lack `accessibilityReduceMotion` guards; and (4) the Bento grid layout branch, which must detect `dynamicTypeSize >= .accessibility1` at render time.

## Scope

### In Scope

- Countdown numeral `@ScaledMetric(relativeTo: .largeTitle)` implementation (base 48pt, scales proportionally to .largeTitle Dynamic Type category)
- Full-app Dynamic Type audit at: Default, xLarge, Accessibility1, Accessibility3 -- any text truncation, clipping, or container overflow is a violation requiring remediation
- Detection and remediation of `.lineLimit(1)` on body content that clips text without a fallback
- Detection and remediation of fixed-height containers (`.frame(height: N)`) that clip text at large Dynamic Type sizes
- Chip animation reduced motion gating: `scaleEffect(0.95)` spring (response 0.3, dampingFraction 0.7) and color cross-dissolve (0.15s easeOut) gated on `@Environment(\.accessibilityReduceMotion)`
- Sharing strip animation reduced motion gating: 0.2s easeInOut crossfade on pause/resume
- Partner Dashboard crossfade reduced motion gating: 0.25s easeInOut hide to "Sharing paused" card
- Skeleton shimmer reduced motion gating: 1.2s shimmer loop replaced with static opacity ~0.4 placeholder when `reduceMotion == true`
- Partner Bento grid Accessibility1 collapse: `dynamicTypeSize >= .accessibility1` -> `VStack(spacing: 16)`; below -> `HStack(spacing: 12)`; verified at Accessibility1 and Accessibility5
- `performAccessibilityAudit(for: .dynamicType)` sweep across all audited screens

### Out of Scope

- Dynamic Type support for Splash screen animation (spec defers this to post-beta custom typeface evaluation; the Splash is transient)
- Motion changes to animations not defined in the cadence-motion skill (no new animation patterns are introduced here)
- `dynamicTypeSize` range limiting as a remediation strategy -- capping Dynamic Type range is never a first resort; layouts must be made to accommodate the text, not the other way around
- Notification or push-related UI (Phase 10 scope; included only if already implemented and failing the audit)

## Dependencies

| Dependency                                                                                                                        | Type | Phase/Epic         | Status | Risk |
| --------------------------------------------------------------------------------------------------------------------------------- | ---- | ------------------ | ------ | ---- |
| All UI phases complete -- all animated components, countdown row, Partner Bento grid, skeleton loading, sharing strip implemented | FS   | PH-0 through PH-12 | Open   | Low  |
| Countdown row component implemented with the 48pt numeral                                                                         | FS   | PH-5-E3            | Open   | Low  |
| Skeleton loading implemented in Tracker Home and Partner Dashboard                                                                | FS   | PH-5-E1            | Open   | Low  |
| Sharing strip implemented with pause/resume animation                                                                             | FS   | PH-5-E2            | Open   | Low  |
| Partner Dashboard sharing paused crossfade implemented                                                                            | FS   | PH-9-E4            | Open   | Low  |
| Partner Bento grid implemented with Phase and Countdown side-by-side cards                                                        | FS   | PH-9-E2            | Open   | Low  |

## Assumptions

- The `@ScaledMetric(relativeTo: .largeTitle)` pattern is the authoritative implementation for the 48pt countdown numeral, as specified in the cadence-accessibility skill §4. The `relativeTo: .largeTitle` anchor is intentional -- it scales the custom size proportionally to the .largeTitle Dynamic Type category, preserving the design intent at accessibility sizes.
- `reduceMotion == true` means the animation argument to `.animation(_:value:)` is `nil`, producing an instant state change with no cross-dissolve, no spring, and no layout shift. A slower animation is not an acceptable substitute for `nil`.
- The skeleton shimmer static placeholder uses `opacity(0.4)` on the placeholder shape, not a slower shimmer loop. The loop must be fully eliminated, not slowed.
- `@Environment(\.accessibilityReduceMotion)` reads the system setting at view render time. No caching or lazy evaluation is introduced -- the binding is live.
- The Bento grid collapse applies only to the 2-up square card pair (Phase, Countdown). Full-width rectangular cards (Symptoms, Notes) are already single-column and require no collapse logic.

## Risks

| Risk                                                                                                                                                                          | Likelihood | Impact | Mitigation                                                                                                                                                                            |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Multiple fixed-height containers added across Phases 5-12 clip text at Accessibility3                                                                                         | Medium     | High   | Systematic audit at Accessibility3 Dynamic Type in Simulator; replace `.frame(height: N)` with `.frame(minHeight: N)` where height was used to enforce visual rhythm, not clip text.  |
| `@ScaledMetric` scaling curve does not match design intent at Accessibility5 (numeral becomes disproportionately large)                                                       | Low        | Medium | Measure at Accessibility5; if the scaled size is unacceptable, clamp with `countdownSize.clamped(to: 48...96)` and document the design rationale for the cap.                         |
| The Bento grid collapse changes layout at Accessibility1 but the card content inside each card still clips at Accessibility3                                                  | Medium     | Medium | Audit each card's content (text labels, number displays) independently at Accessibility3 after the grid collapse is verified.                                                         |
| Animations added in Phases 4-12 use `withAnimation { }` blocks rather than `.animation(_:value:)` modifier -- reduceMotion guard requires wrapping in `withOptionalAnimation` | Medium     | Medium | Audit for `withAnimation` callsites; refactor to the `.animation(reduceMotion ? nil : ..., value:)` pattern or to a `withOptionalAnimation` utility. Document every changed callsite. |

---

## Stories

### S1: Countdown Numeral @ScaledMetric Implementation

**Story ID:** PH-13-E3-S1
**Points:** 3

Verify or implement `@ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 48` in the countdown row component. The countdown Text view must use `countdownSize` as the font size argument rather than a literal `48`. Verify at Default, xLarge, Accessibility1, and Accessibility3 Dynamic Type that the numeral scales and does not clip its container.

**Acceptance Criteria:**

- [ ] The countdown row component declares `@ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 48`
- [ ] The countdown Text view uses `.font(.system(size: countdownSize, weight: .medium, design: .rounded))` -- the literal `48` does not appear as a hardcoded argument to `.system(size:)`
- [ ] At Default Dynamic Type, the numeral renders at or near 48pt -- no visible change from the pre-audit state
- [ ] At Accessibility1 Dynamic Type, the numeral is visibly larger and the containing countdown card expands to accommodate it without clipping
- [ ] At Accessibility3 Dynamic Type, the numeral renders at its maximum scaled size; the Countdown Row card does not clip the number; the two Countdown cards side-by-side remain legible (or the layout switches -- if the card layout is broken at Accessibility3 because of the large numeral, document the finding and determine if a layout adaptation is required)
- [ ] The `no-hex-in-swift` hook reports no violations on modified files
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** None
**Notes:** If the countdown numeral already uses `@ScaledMetric`, this story is a verification pass only -- document the finding, confirm the ACs, and close. The story delivers the verification artifact regardless.

---

### S2: Full Dynamic Type Text Audit and Fixed Container Remediation

**Story ID:** PH-13-E3-S2
**Points:** 5

Run the app at Default, xLarge, Accessibility1, and Accessibility3 Dynamic Type sizes and walk every screen. Flag any text that is truncated, clipped, or hidden by a fixed-height container. Remediate each violation by replacing fixed frame heights with minimum heights, removing inappropriate `.lineLimit(1)` usage, or restructuring layouts that cannot accommodate large text without functional breakage.

**Acceptance Criteria:**

- [ ] At Accessibility3 Dynamic Type, no text on Tracker Home, Log Sheet, Calendar, Auth, Tracker Settings, Partner Dashboard, or Partner Settings is truncated by a fixed container height -- all cards expand to accommodate text
- [ ] At Accessibility1 Dynamic Type, no text surface shows a layout overflow or content collision (text running into adjacent text blocks or out of its parent card)
- [ ] `.lineLimit(1)` usage on body content (body, subheadline, callout, footnote text styles) is removed or replaced with `.lineLimit(1).minimumScaleFactor(0.8)` where wrapping is not feasible -- each instance is justified with an inline comment
- [ ] Fixed `.frame(height: N)` constraints that clip text are replaced with `.frame(minHeight: N)` where the minimum is required for visual rhythm but the height must be able to grow
- [ ] `.font(.system(size: N))` usages without `@ScaledMetric` backing (excluding the countdown numeral which is covered in S1) are replaced with a system Dynamic Type font token or a `@ScaledMetric`-backed variable
- [ ] `performAccessibilityAudit(for: .dynamicType)` run in XCUITest against Tracker Home, Log Sheet, Calendar, and Partner Dashboard produces zero unsuppressed violations
- [ ] All remediations are isolated to layout constraints and font declarations -- no logic changes, no feature additions
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified files

**Dependencies:** PH-13-E3-S1
**Notes:** Walk-through methodology: use the Simulator's Settings app to set Dynamic Type size (Settings > Accessibility > Display & Text Size > Larger Text). Test at xLarge and then drag to Accessibility1. Accessibility3 requires manually selecting the 7th notch. `performAccessibilityAudit(for: .dynamicType)` catches clip violations programmatically. Both approaches are required -- the audit catches measured clipping; the walk-through catches visual overflow that the audit may not flag.

---

### S3: Chip Animation Reduced Motion Gating

**Story ID:** PH-13-E3-S3
**Points:** 3

Gate all chip interaction animations on `@Environment(\.accessibilityReduceMotion)`. The two chip animations defined in the cadence-motion skill are: (1) the tap-down spring (`scaleEffect(0.95)`, response 0.3, dampingFraction 0.7) and (2) the toggle color cross-dissolve (0.15s easeOut). Under `reduceMotion == true`, both must produce an instant state change with no intermediate animation.

**Acceptance Criteria:**

- [ ] SymptomChip and FlowChip views each declare `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
- [ ] The tap-down `scaleEffect(0.95)` spring is applied as `.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)` -- a `nil` animation value produces instant state change
- [ ] The color cross-dissolve on toggle uses `.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)` -- instant when `reduceMotion == true`
- [ ] No layout shift occurs under `reduceMotion == true` -- the chip renders immediately in its new state without positional movement
- [ ] Manual verification: enable Reduce Motion in Simulator (Settings > Accessibility > Motion > Reduce Motion); tap a chip; confirm no spring and no cross-dissolve -- the chip state changes instantly
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified files

**Dependencies:** None
**Notes:** The cadence-motion and cadence-accessibility skills both gate on `@Environment(\.accessibilityReduceMotion)`. The source of truth for animation values (response: 0.3, dampingFraction: 0.7, 0.15s easeOut) is the cadence-motion skill. This story is the accessibility gate -- do not change the animation values, only add the nil-branch gating.

---

### S4: State Transition Animations Reduced Motion Gating

**Story ID:** PH-13-E3-S4
**Points:** 3

Gate three additional animations on `@Environment(\.accessibilityReduceMotion)`: (1) the sharing strip 0.2s easeInOut crossfade on pause/resume, (2) the Partner Dashboard 0.25s easeInOut crossfade to "Sharing paused" card, and (3) the skeleton shimmer 1.2s loop replaced by a static opacity placeholder when `reduceMotion == true`.

**Acceptance Criteria:**

- [ ] The sharing strip background crossfade uses `.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isPaused)` -- instant under `reduceMotion == true`
- [ ] The Partner Dashboard sharing paused crossfade uses `.animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isSharingPaused)` -- instant under `reduceMotion == true`
- [ ] The skeleton shimmer `ViewModifier` checks `reduceMotion`; when `true`, the modifier applies a static `opacity(0.4)` to the placeholder without any loop animation; when `false`, the 1.2s left-to-right shimmer runs as specified in the cadence-motion skill
- [ ] No reduced-speed shimmer loop exists under `reduceMotion == true` -- the loop is eliminated entirely, not slowed
- [ ] Manual verification with Reduce Motion enabled: navigate to Tracker Home while loading to confirm skeleton shows a static muted shape with no shimmer; pause sharing and confirm the strip changes instantly; confirm Partner Dashboard shows the paused card instantly
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified files

**Dependencies:** PH-13-E3-S3
**Notes:** The skeleton shimmer static opacity value is ~0.4 as specified in the cadence-motion skill. This is the opacity of the placeholder rectangle, not a cross-dissolve value. Under `reduceMotion == false`, the shimmer overlay uses a full-opacity gradient mask sweeping left-to-right.

---

### S5: Partner Bento Grid Accessibility1 Collapse

**Story ID:** PH-13-E3-S5
**Points:** 3

Verify or implement the Partner Bento grid Accessibility1 collapse. At `dynamicTypeSize >= .accessibility1`, the Phase and Countdown 2-up square card pair must render in a `VStack(spacing: 16)`. Below `.accessibility1`, they must render in an `HStack(spacing: 12)`. Full-width rectangular cards (Symptoms, Notes) are already single-column and do not require adaptation. Test the collapse at Accessibility1 and Accessibility5.

**Acceptance Criteria:**

- [ ] The Partner Bento grid layout reads `@Environment(\.dynamicTypeSize) private var dynamicTypeSize` and uses the value to branch the Phase + Countdown card container
- [ ] At `dynamicTypeSize >= .accessibility1`, Phase and Countdown cards are in `VStack(spacing: 16)` -- no HStack
- [ ] At `dynamicTypeSize < .accessibility1`, Phase and Countdown cards are in `HStack(spacing: 12)` -- the standard 2-up layout
- [ ] At Accessibility1 Dynamic Type, both Phase and Countdown cards in the VStack are fully legible -- all text inside each card is visible, no truncation
- [ ] At Accessibility5 Dynamic Type (maximum), both cards remain legible in the VStack; card height expands to contain text
- [ ] The Symptoms and Notes full-width rectangular cards are unaffected by the layout branch -- they remain full-width at all Dynamic Type sizes
- [ ] The layout transition from HStack to VStack occurs with no animation (instant layout branch swap) -- no `.transition()` or `.animation()` on the layout container change
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified files

**Dependencies:** PH-13-E3-S2
**Notes:** The `isAccessibilitySize` computed property (`dynamicTypeSize >= .accessibility1`) is the pattern in the cadence-accessibility skill §5. The `AnyLayout` pattern (`AnyLayout(VStackLayout()) / AnyLayout(HStackLayout())`) is an alternative to the `if/else` branch; both are acceptable. The `if/else` branch is simpler and preferred unless `AnyLayout` is already used in the codebase for this component.

---

### S6: performAccessibilityAudit(.dynamicType) Sweep

**Story ID:** PH-13-E3-S6
**Points:** 3

Write an XCUITest that runs `performAccessibilityAudit(for: .dynamicType)` against the main screens of the app to confirm zero Dynamic Type violations survive into the shipped build. This test runs in the `CadenceTests` UI test target and serves as the regression gate for all S2-S5 Dynamic Type and layout remediations.

**Acceptance Criteria:**

- [ ] `AccessibilityDynamicTypeAuditTests` file exists under `CadenceTests/Accessibility/`; registered in `project.yml` under the CadenceTests target
- [ ] The test sets the simulator Dynamic Type size to `Accessibility1` before each screen audit (using `XCUIApplication().launchArguments` with `"-UIPreferredContentSizeCategoryName UIContentSizeCategoryAccessibilityMedium"` or equivalent)
- [ ] `performAccessibilityAudit(for: .dynamicType)` is called against: Tracker Home, Log Sheet, Calendar, Partner Dashboard
- [ ] The audit passes with zero unsuppressed violations against all audited screens
- [ ] Any known, documented layout constraints that prevent full Accessibility5 compliance are recorded as suppressions in the test with an inline comment specifying the element, the constraint, and the phase in which it will be resolved
- [ ] The test is deterministic -- no network dependency, runs from local SwiftData or mock state
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** PH-13-E3-S1, PH-13-E3-S2, PH-13-E3-S5
**Notes:** The XCUITest `launchArgument` to set a fixed Dynamic Type size: add `"-UIPreferredContentSizeCategoryName"` and `"UIContentSizeCategoryAccessibilityMedium"` (maps to Accessibility1) to `XCUIApplication().launchArguments` before `app.launch()`. This forces a repeatable test environment regardless of the simulator's current system setting.

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
- [ ] `performAccessibilityAudit(for: .dynamicType)` passes with zero unsuppressed violations against all audited screens at Accessibility1
- [ ] On-device (or Simulator) walk-through at Accessibility3 confirms no text truncation or container overflow on any screen
- [ ] Reduce Motion enabled on-device confirms no chip spring, no cross-dissolve, no shimmer loop, no sharing strip animation, no Partner Dashboard crossfade -- all state changes are instant
- [ ] Phase objective is advanced: Dynamic Type scales all text surfaces; all custom animations are reduced-motion gated; Bento grid collapses at Accessibility1
- [ ] Applicable skill constraints satisfied: cadence-accessibility §2 (reduced motion gating), §4 (Dynamic Type -- countdown @ScaledMetric, validation at 4 sizes), §5 (Bento grid Accessibility1 collapse), §9 (Reduced Motion and Dynamic Type checklist sections), cadence-motion (animation values unchanged -- only gating added)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 13 -- Accessibility Compliance (in-scope: Dynamic Type verification, reduced motion gating audit, Bento grid 1-up collapse at Accessibility1)
- Design Spec v1.1 §2 (Platform assumptions -- Dynamic Type: all text must scale; no fixed-size text containers)
- Design Spec v1.1 §4 (Typography -- countdown numeral: .system(size: 48) must scale with accessibilityLargeText)
- Design Spec v1.1 §11 (Motion & Interaction -- Reduced Motion: all custom animations gated on accessibilityReduceMotion, instant state changes, no layout shift)
- Design Spec v1.1 §12.5 (Partner Home Dashboard -- Bento grid collapses from 2-up to 1-up at Accessibility1 threshold)
- Design Spec v1.1 §14 (Accessibility -- Dynamic Type requirement, Bento grid requirement, Reduced Motion requirement)
- cadence-accessibility skill §2 (Reduced Motion Gating -- nil animation pattern, skeleton shimmer static placeholder)
- cadence-accessibility skill §4 (Dynamic Type Validation -- @ScaledMetric pattern, four-size validation requirement)
- cadence-accessibility skill §5 (Partner Bento Grid -- Accessibility1 Collapse implementation)
- cadence-accessibility skill §9 (Screen Accessibility Checklist -- Reduced Motion and Dynamic Type sections)
- cadence-motion skill (Animation specs -- chip spring, cross-dissolve, sharing strip, skeleton shimmer values)
