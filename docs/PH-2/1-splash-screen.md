# Splash Screen

**Epic ID:** PH-2-E1
**Phase:** 2 -- Authentication & Onboarding
**Estimated Size:** S
**Status:** Draft

---

## Objective

Implement the Cadence launch experience: a path-draw animation of the brand mark followed by the wordmark fade-in, completing in 2.35 seconds and signaling the parent coordinator via callback to trigger the crossfade to the auth screen. A reduced-motion path renders both elements instantly and holds for 0.4 seconds before signaling.

## Problem / Context

The splash screen is the first moment every user experiences on every app launch. `SplashView` and `CadenceMark` are the two Swift files that produce this experience. Neither exists in the project after Phase 0. The path-draw animation requires a custom `Shape` with Bezier coordinates. Without this epic, the app has no launch experience and the AppCoordinator (PH-2-E3) has nothing to present at startup.

Source authority: `Cadence_SplashScreen_Spec.md` v1.0 defines the full implementation including animation beats, stroke style, reduced-motion behavior, and the callback pattern for parent-driven transitions.

## Scope

### In Scope

- `CadenceMark` color asset (`CadenceMark.colorset`) -- light: `#C07050`, dark: `#EDE4D8`
- `CadenceMark.swift` -- custom `Shape` with placeholder Bezier coordinates (tracing the locked PNG is a Phase 14 pre-ship task)
- `SplashView.swift` -- animation state, layout, `onComplete` callback
- 4-beat animation sequence: background instant fill, path draw at 0.2s delay for 1.0s easeInOut, wordmark fade-in at 1.3s for 0.35s easeOut, `onComplete()` dispatched at 2.05s
- Stroke spec: 28pt line width, `.round` lineCap and lineJoin, color from `CadenceTerracotta` asset
- Reduced-motion path: both elements render at full state immediately, 0.4s hold, then `onComplete()`
- Dark mode: all colors from named assets -- no conditional Swift logic
- `project.yml` additions for `Cadence/Views/Splash/` source group and two Swift files

### Out of Scope

- Bezier coordinate tracing from the locked PNG -- Phase 14 pre-ship task (Splash Spec §Open Items)
- App icon asset registration -- Phase 0 or Phase 14 task, not Phase 2
- Custom typeface substitution -- post-beta open item (Design Spec §15)
- Splash-to-auth crossfade transition -- owned by AppCoordinator (PH-2-E3-S4), triggered by the `onComplete` callback

## Dependencies

| Dependency                                                    | Type | Phase/Epic | Status   | Risk |
| ------------------------------------------------------------- | ---- | ---------- | -------- | ---- |
| `CadenceBackground` color asset in xcassets                   | FS   | PH-0       | Resolved | Low  |
| `CadenceTerracotta` color asset in xcassets                   | FS   | PH-0       | Resolved | Low  |
| Buildable XcodeGen project with `Cadence/Views/` source group | FS   | PH-0       | Resolved | Low  |
| AppCoordinator to receive `onComplete` callback (for wiring)  | SS   | PH-2-E3    | Open     | Low  |

## Assumptions

- `CadenceMark` color asset is distinct from `CadenceTerracotta`. The mark uses `#EDE4D8` in dark mode (warm ivory) while `CadenceTerracotta` dark is `#D4896A`. Both require separate colorset files.
- Placeholder Bezier coordinates (from Splash Spec §Path Draw Architecture) are used as-is. The coordinates produce a stroke path that is structurally correct for the animation. Visual fidelity to the locked mark is deferred to Phase 14.
- `SplashView` is presented full-screen with no navigation chrome. It is not embedded in a `NavigationStack` or `TabView`.
- The `onComplete` callback fires once and is not called again. The parent is responsible for not presenting `SplashView` to returning users who are already authenticated (session persistence routing is PH-2-E3-S3).

## Risks

| Risk                                                                                                                                  | Likelihood | Impact | Mitigation                                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------- |
| `.trim(from:to:)` with `.stroke()` produces visual artifacts on certain device sizes                                                  | Low        | Low    | Test on 3 simulator sizes (SE, standard, Pro Max) before declaring done                                           |
| `@Environment(\.accessibilityReduceMotion)` not injected in test environment                                                          | Low        | Low    | Test manually with Accessibility > Reduce Motion enabled on simulator                                             |
| `DispatchQueue.main.asyncAfter` for the 2.05s `onComplete` dispatch is cancelled if the view disappears -- leads to missed navigation | Low        | Medium | Wrap dispatch in a `Task` stored in a `@State var animationTask: Task<Void, Never>?` and cancel in `.onDisappear` |

---

## Stories

### S1: CadenceMark color asset and Shape definition

**Story ID:** PH-2-E1-S1
**Points:** 3

Create the `CadenceMark.colorset` color asset with light and dark variants, then implement `CadenceMark` as a `Shape` conforming to the SwiftUI `Shape` protocol using the placeholder Bezier coordinates from Splash Spec §Path Draw Architecture. Register both the colorset and `CadenceMark.swift` in `project.yml`.

**Acceptance Criteria:**

- [ ] `Resources/Colors.xcassets/CadenceMark.colorset/Contents.json` exists with `light: #C07050` and `dark: #EDE4D8` correctly encoded in sRGB color space
- [ ] `Cadence/Views/Splash/CadenceMark.swift` exists, contains `struct CadenceMark: Shape` with a `path(in rect: CGRect) -> Path` implementation using percentage-based control points
- [ ] `CadenceMark` renders a visible curved stroke path (not a closed fill) when used as `.stroke()` in a preview at 160x120pt
- [ ] `project.yml` includes `Cadence/Views/Splash/CadenceMark.swift` under the `Sources` group and the `CadenceMark.colorset` under `Resources/Colors.xcassets`
- [ ] `xcodegen generate` succeeds without errors after `project.yml` changes
- [ ] No hardcoded hex values in `CadenceMark.swift` -- stroke color is passed by the caller, not defined inside the Shape

**Dependencies:** None
**Notes:** Bezier coordinates are the structural placeholders from Splash Spec lines 82-97. Do not trace the locked PNG here. The shape must be open (not closed) so `.trim(from:to:)` produces a draw-on effect from a single terminal.

---

### S2: SplashView static layout

**Story ID:** PH-2-E1-S2
**Points:** 2

Implement `SplashView` with the correct visual composition: `CadenceMark` as a stroked shape, wordmark text, and `CadenceBackground` fill -- with all elements centered as a single unit. No animation in this story; `drawProgress` and `wordmarkOpacity` are set to their final values (`1.0`) so the view is visually inspectable in preview.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Splash/SplashView.swift` exists and compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] `SplashView` renders `CadenceMark` at `160x120pt` frame, stroked with `Color("CadenceTerracotta")` at 28pt line width, `.round` lineCap and lineJoin
- [ ] Wordmark `Text("Cadence")` uses `.font(.system(.title2, design: .serif))` with `.fontWeight(.light)` and `.foregroundStyle(.primary)`
- [ ] Mark and wordmark are vertically stacked with exactly `24pt` between the bottom edge of the mark frame and the top of the wordmark
- [ ] The mark-wordmark pair is centered both horizontally and vertically on the screen (vertically centered as a group, not pinned to a grid row)
- [ ] Background is `Color("CadenceBackground")` filling the full screen including safe area (`.ignoresSafeArea()`)
- [ ] `SplashView` accepts `var onComplete: () -> Void` as a parameter
- [ ] `project.yml` includes `Cadence/Views/Splash/SplashView.swift`
- [ ] Xcode preview renders correctly in both light and dark mode

**Dependencies:** PH-2-E1-S1
**Notes:** No animation state in this story -- `drawProgress = 1.0` and `wordmarkOpacity = 1.0` as static values for layout verification. Animation is added in S3.

---

### S3: Animation sequence -- 4-beat path-draw

**Story ID:** PH-2-E1-S3
**Points:** 5

Add `@State` animation properties to `SplashView` and implement the 4-beat animation sequence exactly as specified in Splash Spec §Animation Sequence. The sequence fires on `.onAppear`. After the hold period, `onComplete()` is dispatched from a stored `Task` that is cancelled on `.onDisappear` to prevent navigation calls after view teardown.

**Acceptance Criteria:**

- [ ] `@State private var drawProgress: CGFloat = 0` and `@State private var wordmarkOpacity: Double = 0` are the initial values on appear
- [ ] Beat 1: path draw begins at `t=0.2s` with `.easeInOut(duration: 1.0)` animation on `drawProgress` from `0` to `1.0`
- [ ] Beat 2: wordmark fades in at `t=1.3s` with `.easeOut(duration: 0.35)` animation on `wordmarkOpacity` from `0` to `1.0`
- [ ] Beat 3: both elements visible with no motion between `t=1.65s` and `t=2.05s`
- [ ] Beat 4: `onComplete()` is called at `t=2.05s` via a stored `Task` (not a bare `DispatchQueue.asyncAfter`)
- [ ] The stored `Task` is cancelled in `.onDisappear` so `onComplete` is not called if the view is removed before the timer fires
- [ ] `CadenceMark().trim(from: 0, to: drawProgress)` is the modifier chain that drives the draw-on effect
- [ ] No new animation fires if `drawProgress` is already at `1.0` when the view appears (guard against double-appear)

**Dependencies:** PH-2-E1-S2
**Notes:** Use `Task { try? await Task.sleep(for: .seconds(2.05)); onComplete() }` pattern with `.task` modifier or store in `@State var animationTask`. Do not use `DispatchQueue.main.asyncAfter` -- it is not cancellable.

---

### S4: Reduced-motion path

**Story ID:** PH-2-E1-S4
**Points:** 2

Gate the animation sequence on `@Environment(\.accessibilityReduceMotion)`. When reduce motion is enabled, both elements render at full state immediately (no animations) and `onComplete()` fires after a 0.4-second hold. The `runEntrance()` function (or equivalent) branches on `reduceMotion` before scheduling any animation.

**Acceptance Criteria:**

- [ ] `@Environment(\.accessibilityReduceMotion) private var reduceMotion` is present in `SplashView`
- [ ] When `reduceMotion == true`: `drawProgress` is set to `1.0` without animation and `wordmarkOpacity` is set to `1.0` without animation on view appear
- [ ] When `reduceMotion == true`: `onComplete()` fires after a 0.4-second hold (no earlier, no later)
- [ ] When `reduceMotion == false`: the 4-beat animated sequence from S3 runs as specified
- [ ] The branch logic is in a private `runEntrance()` method called from `.onAppear` (or `.task`), not inlined into the body
- [ ] Both paths cancel their pending `onComplete` dispatch in `.onDisappear`
- [ ] Tested manually on iPhone 16 Pro simulator with Accessibility > Reduce Motion toggled on and off

**Dependencies:** PH-2-E1-S3
**Notes:** The hold duration of 0.4s under reduce motion is specified in Splash Spec §Reduced Motion. The animated path holds from 1.65s to 2.05s -- a 0.4s hold -- so the reduced-motion timing is consistent with the animated experience's hold duration.

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
- [ ] Integration with AppCoordinator verified: splash fires `onComplete`, coordinator crossfades to auth screen
- [ ] Phase objective is advanced: the app launches to a visible, animated splash screen
- [ ] Applicable skill constraints satisfied: `cadence-design-system` (CadenceMark colorset, CadenceTerracotta stroke, CadenceBackground fill, CadenceTextPrimary wordmark), `cadence-motion` (animation spec timing, reduced-motion gating), `swiftui-production` (@State usage, no force unwraps), `cadence-xcode-project` (project.yml additions for Views/Splash group), `cadence-accessibility` (reduceMotion env var consumed)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments in committed Swift files (Bezier coordinates are structural placeholders per spec, not stubs -- the distinction: they produce a valid renderable path)
- [ ] Source document alignment verified: animation timings match Splash Spec §Animation Sequence exactly

## Source References

- Splash Screen Spec v1.0 -- full spec (animation sequence, path-draw architecture, reduced motion, file structure)
- Design Spec v1.1 §3 (CadenceTerracotta, CadenceBackground color tokens)
- Design Spec v1.1 §4 (wordmark typography: `.title2`, `.light` weight)
- Design Spec v1.1 §11 (reduced motion rule: all custom animations gated on `accessibilityReduceMotion`)
- PHASES.md: Phase 2 -- Authentication & Onboarding (In-Scope items 1-2)
