# Supporting Components -- DataCard, PeriodToggle, PrimaryButton

**Epic ID:** PH-4-E4
**Phase:** 4 -- Tracker Navigation Shell & Core Logging
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement three shared UI components used throughout the Cadence component library: `DataCard` (the foundational card surface from Design Spec §10.4), `PeriodToggle` (the paired period-started / period-ended pill buttons from §10.2), and `PrimaryButton` (the full-width CTA from §10.3 with loading and disabled states). These components are consumed immediately by the Log Sheet (PH-4-E2) and reused across Phase 5 (Tracker Home), Phase 9 (Partner Dashboard), and Phase 11 (Reports) without modification to their public API.

## Problem / Context

`DataCard` is the foundational surface unit. Design Spec §10.4 says: "All dashboard cards, Log Sheet content areas, and calendar detail sheets use this component." Every feed card in Phase 5, every Bento card in Phase 9, and the Log Sheet's internal layout containers are DataCard instances. If the DataCard specification (CadenceCard fill, 1pt CadenceBorder stroke, 16pt corner radius, 20pt internal padding, no external shadow) is not locked in Phase 4, each consuming phase will implement its own inline card styling -- producing visual drift that requires a design audit to correct.

`PeriodToggle` is the only control in the app with paired-button semantics. "Period started" and "Period ended" occupy equal-width slots. They can be independently active (a user can mark period started and period ended in the same session if they're logging retrospectively), so they are NOT a radio group. This independent-state model is a common misconception -- implementing it as mutually exclusive would be a data-layer bug.

`PrimaryButton` has a loading state that locks the button width to prevent layout shift when the `ProgressView` replaces the label. This is a motion spec requirement (Design Spec §10.3: "button width locked to prevent layout shift"). The naive implementation -- replacing `Text("Save log")` with `ProgressView()` inside the same button -- causes the button to resize if `ProgressView` has a different intrinsic size. The button must use `.frame(maxWidth: .infinity)` and fix its height at 50pt so width and height do not change during the loading transition.

**Source references that define scope:**

- Design Spec v1.1 §10.4 (DataCard: CadenceCard, 1pt CadenceBorder, 16pt corner, 20pt padding, no shadow; Insight variant: CadenceSageLight)
- Design Spec v1.1 §10.2 (PeriodToggle: started/ended pair, equal-width, CadenceCard inactive / CadenceTerracotta active, 44pt height, 12pt corner, 12pt gap between buttons)
- Design Spec v1.1 §10.3 (PrimaryButton: CadenceTerracotta, headline semibold, 50pt height, 14pt corner, full-width, loading state width-locked, disabled at 40% opacity)
- Design Spec v1.1 §6 (corner radius: DataCard = 16pt, PeriodToggle buttons = 12pt, PrimaryButton = 14pt)
- PHASES.md Phase 4 in-scope: "PeriodToggle component per §10.2; Primary CTA Button per §10.3"
- cadence-accessibility skill (44pt touch targets on PeriodToggle buttons, PrimaryButton height 50pt >= 44pt)
- cadence-design-system skill (no hardcoded hex values; CadenceCard, CadenceBorder, CadenceTerracotta as Color assets)
- cadence-motion skill (PeriodToggle uses ChipPressStyle from E5; PrimaryButton loading state -- width locked)

## Scope

### In Scope

- `Cadence/Views/Shared/DataCard.swift`: `struct DataCard<Content: View>: View` with a `@ViewBuilder content: () -> Content` parameter and an `isInsight: Bool` parameter (default `false`) for the CadenceSageLight insight variant; applies `CadenceCard` (or `CadenceSageLight` when `isInsight == true`) background fill, `1pt CadenceBorder` stroke overlay, `16pt` corner radius on `RoundedRectangle`, `20pt` uniform padding, no `.shadow()` modifier
- `Cadence/Views/Shared/PeriodToggle.swift`: `struct PeriodToggle: View` with parameters `periodStarted: Binding<Bool>`, `periodEnded: Binding<Bool>`, and two `action` closures (`onStarted: () -> Void`, `onEnded: () -> Void`); renders as `HStack(spacing: 12)` with two `Button` instances each in a `RoundedRectangle(cornerRadius: 12)` of equal width via `frame(maxWidth: .infinity)`; inactive state: `CadenceCard` fill, `1pt CadenceBorder` stroke, `body` style, `CadenceTextPrimary`; active state: `CadenceTerracotta` fill, `body` semibold, `CadenceTextOnAccent`; minimum height `44pt` via `.frame(minHeight: 44)`
- `Cadence/Views/Shared/PrimaryButton.swift`: `struct PrimaryButton: View` with parameters `label: String`, `isLoading: Bool`, `isDisabled: Bool`, `action: () -> Void`; background `CadenceTerracotta`, text `headline` semibold `CadenceTextOnAccent`, height `50pt` fixed via `.frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)` (width-lock prevents layout shift on loading transition), corner radius `14pt`, loading state renders `ProgressView()` (system default, white tint on terracotta) instead of `Text(label)`, disabled state applies `.opacity(0.4)` to the entire button, disabled blocks the `action` call
- `accessibilityLabel` on `PeriodToggle` "Period started" button: `"Period started, \(periodStarted ? "selected" : "unselected")"` ; "Period ended" button: `"Period ended, \(periodEnded ? "selected" : "unselected")"`
- `PrimaryButton` `accessibilityLabel`: `label` string; when loading, add accessibilityHint `"Loading"` so VoiceOver announces the wait state
- `project.yml` updated for all three files; `xcodegen generate` exits 0

### Out of Scope

- DataCard used in Phase 5 Home dashboard (Phase 5 creates the card instances; this epic defines the component only)
- `PeriodToggle` `ChipPressStyle` animation (applied in PH-4-E5 to all chip and toggle surfaces)
- `PrimaryButton` loading state animation (the `ProgressView` itself animates; no additional custom animation is added here)
- The "Sign in with Apple" black variant of `PrimaryButton` (Phase 2 auth screen; not used in Phase 4; deferred to avoid pre-mature specialization)

## Dependencies

| Dependency                                                                                                                                    | Type | Phase/Epic | Status | Risk                                       |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ------------------------------------------ |
| PH-0-E2 (all required color assets: CadenceCard, CadenceBorder, CadenceTerracotta, CadenceSageLight, CadenceTextPrimary, CadenceTextOnAccent) | FS   | PH-0-E2    | Open   | Low -- color assets established in Phase 0 |

## Assumptions

- `DataCard` is a generic view wrapper. Callers pass any `Content` view as the body. The 20pt internal padding is applied by `DataCard` -- callers must not add redundant internal padding.
- `PeriodToggle` buttons are independently stateful: both can be active simultaneously (e.g., when logging a completed past period). They are NOT mutually exclusive. The `periodStarted` and `periodEnded` bindings are independent booleans in `LogSheetViewModel`.
- `PrimaryButton` is always full-width within its container. The `.frame(maxWidth: .infinity)` means the containing view's width drives the button width -- callers apply their own horizontal insets (16pt per Design Spec §5).
- The 40% opacity on `PrimaryButton` disabled state applies `.opacity(0.4)` to the whole button including background and text. The `.disabled(isDisabled)` modifier prevents the `action` closure from firing. Both must be applied.

## Risks

| Risk                                                                           | Likelihood | Impact | Mitigation                                                                                                                                                                                |
| ------------------------------------------------------------------------------ | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PrimaryButton` layout shifts when switching between `Text` and `ProgressView` | Medium     | Medium | Use `.frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)` to lock both dimensions; verify by toggling `isLoading` in a Preview and confirming the button frame does not change size |
| `DataCard` generic `@ViewBuilder` doesn't compile with all Content types       | Low        | Low    | Test with a `Text` content, a `VStack` content, and a `LazyVStack` content in Previews before declaring done                                                                              |
| `PeriodToggle` equal-width layout breaks if one label is significantly wider   | Low        | Low    | Both labels are fixed strings "Period started" and "Period ended" -- similar length; `frame(maxWidth: .infinity)` on each button distributes space equally regardless                     |

---

## Stories

### S1: DataCard component -- foundational card surface

**Story ID:** PH-4-E4-S1
**Points:** 2

Implement `DataCard`: the foundational surface unit used by all dashboard cards, Log Sheet areas, and calendar detail sheets. The insight variant swaps `CadenceCard` background for `CadenceSageLight`.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/DataCard.swift` exists with `struct DataCard<Content: View>: View`
- [ ] Parameters: `content: () -> Content` as `@ViewBuilder`, `isInsight: Bool` (no default value -- callers must be explicit)
- [ ] Standard variant (`isInsight == false`): background is `Color("CadenceCard")`, overlay is `RoundedRectangle(cornerRadius: 16).stroke(Color("CadenceBorder"), lineWidth: 1)`, no `.shadow()` modifier
- [ ] Insight variant (`isInsight == true`): background is `Color("CadenceSageLight")`, same 1pt `CadenceBorder` stroke, same corner radius, no shadow
- [ ] Internal padding: `.padding(20)` uniform on the content
- [ ] Corner radius: `16pt` via `RoundedRectangle(cornerRadius: 16).fill(backgroundColor).overlay(RoundedRectangle(cornerRadius: 16).stroke(...))`
- [ ] No external drop shadow on either variant
- [ ] A SwiftUI Preview shows both variants side by side with a `Text("Card content")` body
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values in `DataCard.swift`

**Dependencies:** PH-0-E2

**Notes:** The implementation pattern that avoids double-clipping: apply `.clipShape(RoundedRectangle(cornerRadius: 16))` to the content, then use `.overlay(RoundedRectangle(cornerRadius: 16).stroke(...))` on the clipped view. This renders the border on the outside of the clip boundary, not inside. Alternatively, use `.background(RoundedRectangle(cornerRadius: 16).fill(color).stroke(Color("CadenceBorder"), lineWidth: 1))` with SwiftUI's `ShapeStyle` composition -- verify this compiles correctly in Xcode 26 before committing.

---

### S2: PeriodToggle component -- started/ended pill pair

**Story ID:** PH-4-E4-S2
**Points:** 3

Implement `PeriodToggle`: the paired period-started and period-ended pill buttons with independent active states, equal-width layout, and 44pt minimum height.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/PeriodToggle.swift` exists with `struct PeriodToggle: View`
- [ ] Parameters: `periodStarted: Binding<Bool>`, `periodEnded: Binding<Bool>`, `onStarted: () -> Void`, `onEnded: () -> Void`
- [ ] Layout: `HStack(spacing: 12)` containing two `Button` instances, each with `.frame(maxWidth: .infinity)`
- [ ] "Period started" button inactive state: `CadenceCard` background fill, `1pt CadenceBorder` stroke, `.font(.body)`, `CadenceTextPrimary`, regular weight
- [ ] "Period started" button active state: `CadenceTerracotta` fill, no stroke, `.font(.body)`, `CadenceTextOnAccent`, `.fontWeight(.semibold)`
- [ ] "Period ended" button: same visual rules as "Period started" but driven by `periodEnded` binding
- [ ] Both buttons have `.frame(minHeight: 44)` -- 44pt minimum touch target height
- [ ] Corner radius: `12pt` via `RoundedRectangle(cornerRadius: 12)`
- [ ] Both buttons can be active simultaneously (independent booleans -- not mutually exclusive)
- [ ] `accessibilityLabel` on "Period started" button: `"Period started, \(periodStarted.wrappedValue ? "selected" : "unselected")"`
- [ ] `accessibilityLabel` on "Period ended" button: `"Period ended, \(periodEnded.wrappedValue ? "selected" : "unselected")"`
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-4-E4-S1

**Notes:** The `onStarted` and `onEnded` action closures are called after toggling the binding. Sequence: button tapped → `periodStarted.wrappedValue.toggle()` → `onStarted()`. The callback is for the Log Sheet to respond to period state changes (e.g., triggering a PeriodLog write). The tap-down spring animation from `ChipPressStyle` is applied to `PeriodToggle` buttons in PH-4-E5 -- this story uses `ButtonStyle(.plain)` as the placeholder style.

---

### S3: PrimaryButton component -- loading, disabled, full-width CTA

**Story ID:** PH-4-E4-S3
**Points:** 3

Implement `PrimaryButton` with its three display states (normal, loading, disabled), locked dimensions to prevent layout shift on loading transition, and accessibility compliance.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/PrimaryButton.swift` exists with `struct PrimaryButton: View`
- [ ] Parameters: `label: String`, `isLoading: Bool`, `isDisabled: Bool`, `action: () -> Void`
- [ ] Background: `Color("CadenceTerracotta")` on `RoundedRectangle(cornerRadius: 14)`
- [ ] Normal state: `Text(label)` in `.font(.headline)`, `.fontWeight(.semibold)`, `Color("CadenceTextOnAccent")`
- [ ] Loading state: `ProgressView()` replaces `Text(label)` -- `ProgressView` tinted to `CadenceTextOnAccent` via `.tint(Color("CadenceTextOnAccent"))`
- [ ] Loading state: button frame does NOT change size -- `.frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)` applied to the outer container before the background modifier
- [ ] Disabled state: `.opacity(0.4)` applied to the entire `Button` view; `.disabled(isDisabled)` prevents action firing
- [ ] Height: exactly `50pt` minimum and maximum -- button cannot be taller or shorter than 50pt
- [ ] Width: `.frame(maxWidth: .infinity)` -- caller's container width drives button width; 16pt horizontal inset applied by the caller, not by `PrimaryButton`
- [ ] `accessibilityLabel` is `label`; when `isLoading == true`, `.accessibilityHint("Loading")` is added
- [ ] A SwiftUI Preview shows all three states (normal, loading, disabled) side by side
- [ ] `project.yml` updated; `xcodebuild build` exits 0

**Dependencies:** PH-4-E4-S1

**Notes:** The width lock is implemented by applying `.frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)` to the Button's label view BEFORE the `.background(...)` modifier. Using `.frame(...)` on the Button itself (after all modifiers) can sometimes produce different layout behavior. Verify the button does not visually resize when switching between `isLoading = true` and `isLoading = false` in a Preview with `@State` toggle.

---

### S4: Component accessibility and Dynamic Type compliance verification

**Story ID:** PH-4-E4-S4
**Points:** 2

Verify that all three components satisfy 44pt minimum touch target requirements and Dynamic Type scaling across the AX1-AX5 range. `PrimaryButton`'s 50pt fixed height must scale text without clipping at large Dynamic Type sizes.

**Acceptance Criteria:**

- [ ] `PeriodToggle` buttons: `.frame(minHeight: 44)` present; at AX3 Dynamic Type, the `.body` text fits within the 44pt minimum without clipping -- verified in simulator
- [ ] `PrimaryButton`: at AX5 Dynamic Type, `headline` text inside the 50pt fixed height does not clip (if text wraps at AX5, use `.minimumScaleFactor(0.8)` to prevent clipping -- document the choice with a comment referencing Design Spec §14)
- [ ] `DataCard`: card content scales freely with Dynamic Type; no fixed-height containers inside `DataCard` itself
- [ ] `PeriodToggle` VoiceOver: tapping each button in VoiceOver announces the label and selected state correctly -- verified with VoiceOver on simulator
- [ ] `PrimaryButton` VoiceOver: announces label and "Loading" hint when loading -- verified
- [ ] No `.fixedSize()` or fixed-height `.frame(height:)` modifiers on text-containing views within any of the three components (except `PrimaryButton`'s intentional 50pt height and `PeriodToggle`'s 44pt minimum)
- [ ] `scripts/protocol-zero.sh` exits 0 on all three component files
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E4-S1, PH-4-E4-S2, PH-4-E4-S3

**Notes:** AX5 is the largest standard Dynamic Type size (not accessibility extra-large). Test in the iOS 26 simulator using Settings > Accessibility > Display & Text Size > Larger Text. If `PrimaryButton`'s headline text clips at AX5 inside the 50pt frame, add `.minimumScaleFactor(0.8)` and `.lineLimit(1)` -- this is a documented exception per WCAG AA and matches Apple's own CTA button behavior at extreme sizes.

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
- [ ] DataCard, PeriodToggle, PrimaryButton render correctly in Previews and simulator
- [ ] `PrimaryButton` frame does not shift between normal and loading states
- [ ] `PeriodToggle` buttons are independently toggleable (not mutually exclusive)
- [ ] All three components satisfy 44pt minimum touch targets
- [ ] Phase objective is advanced: supporting components are production-ready; Log Sheet (E2), Phase 5, Phase 9 can consume them
- [ ] cadence-design-system skill: no hardcoded hex values in any component file
- [ ] cadence-accessibility skill: 44pt targets, accessibilityLabel on all interactive elements, Dynamic Type scaling verified
- [ ] swiftui-production skill: no AnyView; no force unwraps; no GeometryReader without justification
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

## Source References

- PHASES.md: Phase 4 -- Tracker Navigation Shell & Core Logging (in-scope: PeriodToggle component per §10.2; Primary CTA Button per §10.3)
- Design Spec v1.1 §10.2 (PeriodToggle: all visual specs, equal-width, 44pt, 12pt corner)
- Design Spec v1.1 §10.3 (PrimaryButton: CadenceTerracotta, 50pt height, 14pt corner, loading state width-lock, 40% opacity disabled)
- Design Spec v1.1 §10.4 (DataCard: CadenceCard, 1pt border, 16pt corner, 20pt padding, insight variant, no shadow)
- Design Spec v1.1 §6 (corner radius table: DataCard 16pt, period toggles 12pt, CTA 14pt)
- cadence-accessibility skill (44pt touch targets, VoiceOver labels, Dynamic Type)
- cadence-design-system skill (color token enforcement, no hardcoded hex)
