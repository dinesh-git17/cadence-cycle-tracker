# SymptomChip Component

**Epic ID:** PH-4-E3
**Phase:** 4 -- Tracker Navigation Shell & Core Logging
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `SymptomChip.swift` as a fully-specified, reusable chip component satisfying all states defined in Design Spec §10.1: default and active visual states with fixed padding to prevent jitter, the Sex chip lock icon permanently rendered at 11pt, the `isReadOnly` parameter that disables the tap gesture for Partner dashboard use, and correct `accessibilityLabel` on every chip and its lock icon. `SymptomChip` is used in the Log Sheet symptom grid (Phase 4), the Tracker Home today's log card (Phase 5), and the Partner Bento dashboard (Phase 9) -- it must be implemented once and reused without modification.

## Problem / Context

`SymptomChip` is the most reused component in Cadence. It appears in at minimum four screens across two roles. Getting its API wrong in Phase 4 means breaking API changes cascade to Phase 5, Phase 9, and any other consumer. Specifically:

- The `isReadOnly: Bool` parameter is consumed in Phase 9 (Partner dashboard chips must not fire tap gestures). If this parameter is omitted or named differently in Phase 4, Phase 9 must make a breaking change.
- Fixed padding (12pt H / 8pt V in both states) prevents geometric jitter when font weight transitions from regular to semibold on toggle. If padding is variable or conditional, the chip resizes visually on toggle -- a motion spec violation.
- The Sex chip lock icon (`lock.fill` at 11pt) is always visible regardless of chip state. It is an accessibility requirement (Design Spec §14): the icon must have `accessibilityLabel` "Private - not shared with partner". If the lock icon appears conditionally or uses a different SF Symbol, Phase 4 fails the accessibility gate.
- The `isSexChip: Bool` parameter gates the lock icon. This must be a parameter, not derived from the label string -- stringly-typed chip identification is prohibited (CLAUDE.md §3.1).

**Source references that define scope:**

- Design Spec v1.1 §10.1 (SymptomChip: all visual properties, padding spec, default and active states)
- Design Spec v1.1 §14 (accessibility: VoiceOver label "{symptom name}, {selected/unselected}"; Sex chip lock icon label "Private - not shared with partner"; 44pt minimum touch target)
- PHASES.md Phase 4 in-scope: "SymptomChip component per §10.1 (default/active states, Sex chip lock icon at 11pt, isReadOnly parameter, 44pt touch target)"
- cadence-design-system skill (color tokens: CadenceTerracotta for active, CadenceBorder for default border, CadenceTextPrimary for default label, CadenceTextOnAccent for active label)
- cadence-motion skill (chip tap-down spring; cross-dissolve animation applied in PH-4-E5; this epic implements the visual states; E5 wires the animation)
- swiftui-production skill (44pt touch target: `.frame(minWidth: 44, minHeight: 44)` with appropriate `contentShape`)
- cadence-accessibility skill (accessibilityLabel pattern, Sex chip lock icon label, 44pt targets)

## Scope

### In Scope

- `Cadence/Views/Shared/SymptomChip.swift`: `struct SymptomChip: View` with parameters: `label: String`, `isActive: Bool`, `isReadOnly: Bool`, `isSexChip: Bool` (all non-optional; no default values -- callers must be explicit)
- Default state: transparent background, `1pt CadenceBorder` stroke as `overlay(RoundedRectangle(cornerRadius: 20).stroke(Color("CadenceBorder"), lineWidth: 1))`, `caption1` text style, `CadenceTextPrimary` color, `Regular` weight, `20pt` corner radius (capsule)
- Active state: `CadenceTerracotta` background fill, no border overlay, `headline` text style, `CadenceTextOnAccent` color, `Semibold` weight, `20pt` corner radius
- Fixed padding: `12pt` horizontal, `8pt` vertical in BOTH default and active states -- padding must not change on state transition to prevent size jitter
- Sex chip lock icon: when `isSexChip == true`, `Image(systemName: "lock.fill")` rendered at 11pt (`.font(.system(size: 11))`) to the right of the label text, visible in BOTH default and active states, color matches the label color for the current state
- `isReadOnly` parameter: when `true`, the chip has no tap gesture; no `Button` wrapper; no `ChipPressStyle` applied; VoiceOver does not announce the chip as interactive (use `.accessibilityAddTraits(.isStaticText)` when `isReadOnly`)
- `accessibilityLabel` on the chip's outer view: `"\(label), \(isActive ? "selected" : "unselected")"` per Design Spec §14
- `accessibilityLabel` on the lock icon image when `isSexChip == true`: `"Private - not shared with partner"` (applied with `.accessibilityLabel("Private - not shared with partner")`)
- Lock icon image: `.accessibilityHidden(false)` -- it must NOT be hidden from VoiceOver; it carries meaning
- Minimum touch target: `.frame(minWidth: 44, minHeight: 44)` on the Button wrapper with `.contentShape(Rectangle())` to expand the hit region beyond the visual chip size
- `project.yml` updated; `xcodegen generate` exits 0

### Out of Scope

- Animation (tap-down spring, cross-dissolve): implemented in PH-4-E5 by applying `ChipPressStyle` and `.animation(_:value:)` to all chip consumers
- Flow level chip single-select logic: handled in `LogSheetView` (PH-4-E2); `SymptomChip` is agnostic to selection semantics
- Skeleton shimmer variant (Phase 5 loading states): shimmer is applied by wrapping the chip in `ShimmerModifier`, not by modifying `SymptomChip` itself
- Data Card container wrapping chips (Phase 5, Phase 9)

## Dependencies

| Dependency                                                                                                                        | Type | Phase/Epic | Status | Risk                                                                                   |
| --------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | -------------------------------------------------------------------------------------- |
| PH-0-E2 complete (all color assets in Colors.xcassets: CadenceTerracotta, CadenceBorder, CadenceTextPrimary, CadenceTextOnAccent) | FS   | PH-0-E2    | Open   | Low -- color assets established in Phase 0                                             |
| `SymptomType` enum defined in Phase 3 data layer (for Log Sheet integration)                                                      | SS   | PH-3       | Open   | Low -- SymptomChip itself is agnostic to SymptomType; the enum is only used by callers |

## Assumptions

- `SymptomChip` has no knowledge of `SymptomType`. It is a pure display component: `label: String`, `isActive: Bool`. Callers are responsible for mapping `SymptomType` to a display label.
- `isActive` is a non-binding parameter (passed as a value, not `Binding<Bool>`). The caller (Log Sheet, Home card) owns the selection state and passes `isActive` on each render. The chip does not own its own selected state. This follows the swiftui-production skill's guidance on unidirectional data flow.
- The tap action is an `action: () -> Void` parameter. When `isReadOnly == false`, `SymptomChip` is wrapped in a `Button(action: action)`. When `isReadOnly == true`, the `Button` wrapper is omitted and the chip is a static `View`.

## Risks

| Risk                                                                                               | Likelihood | Impact | Mitigation                                                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fixed padding causes chip to render too tall at small Dynamic Type sizes                           | Low        | Low    | Test at default (body) and smallest Dynamic Type sizes; `caption1` at default size with 8pt vertical padding should comfortably fit within 44pt                                                                              |
| `foregroundStyle` not cascading correctly through Label + Image composition for Sex chip lock icon | Medium     | Low    | Use explicit `.foregroundStyle(isActive ? Color("CadenceTextOnAccent") : Color("CadenceTextPrimary"))` on the `Image(systemName: "lock.fill")` -- do not rely on implicit label color inheritance                            |
| `isReadOnly` chip VoiceOver behavior unclear (is it announced as interactive?)                     | Low        | Medium | When `isReadOnly == true`, omit the `Button` wrapper entirely; VoiceOver will not announce tap affordance without the Button semantic; add `.accessibilityAddTraits(.isStaticText)` to remove any lingering interactive hint |

---

## Stories

### S1: SymptomChip default state -- shape, colors, padding, touch target

**Story ID:** PH-4-E3-S1
**Points:** 3

Implement `SymptomChip` with the default (unselected) visual state: transparent background, 1pt `CadenceBorder` stroke, `caption1` text, `CadenceTextPrimary` color, fixed padding, capsule corner radius, and a correctly-expanded 44pt touch target.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Shared/SymptomChip.swift` exists with `struct SymptomChip: View`
- [ ] Parameters: `label: String`, `isActive: Bool`, `action: () -> Void`, `isReadOnly: Bool`, `isSexChip: Bool` -- all non-optional, no default values
- [ ] Default state (`isActive == false`): chip background is transparent, overlay is `RoundedRectangle(cornerRadius: 20).stroke(Color("CadenceBorder"), lineWidth: 1)`, text uses `.font(.caption)` (caption1 token = `.caption`), `Color("CadenceTextPrimary")`, regular weight
- [ ] Padding is exactly `12pt horizontal, 8pt vertical` applied as `.padding(.horizontal, 12).padding(.vertical, 8)` -- identical in both default and active states (no conditional padding)
- [ ] Corner radius is `20pt` (capsule equivalent for typical chip height)
- [ ] When `isReadOnly == false`, chip is wrapped in `Button(action: action)` with `ButtonStyle(.plain)` (animation is added in E5)
- [ ] `.frame(minWidth: 44, minHeight: 44)` applied to the Button with `.contentShape(Rectangle())`
- [ ] `accessibilityLabel` set to `"\(label), unselected"` when `isActive == false`
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex color values in `SymptomChip.swift`

**Dependencies:** PH-0-E2 (color assets)

**Notes:** The `ButtonStyle(.plain)` prevents SwiftUI from applying the default press dimming to the chip -- the custom `ChipPressStyle` from E5 provides the tap-down spring. Using `.plain` here means adding `ChipPressStyle` in E5 is an additive change with no conflict. Do not use `.borderless` style -- it behaves differently across iOS versions.

---

### S2: SymptomChip active state -- terracotta fill, headline weight

**Story ID:** PH-4-E3-S2
**Points:** 2

Add the active visual state to `SymptomChip`: CadenceTerracotta fill, no border overlay, headline weight, CadenceTextOnAccent text color. Confirm padding remains identical between states to prevent jitter.

**Acceptance Criteria:**

- [ ] Active state (`isActive == true`): background is `Color("CadenceTerracotta")` fill with `RoundedRectangle(cornerRadius: 20)` shape (no stroke overlay)
- [ ] Active state text: `.font(.headline)` (headline token), `Color("CadenceTextOnAccent")`, `.fontWeight(.semibold)`
- [ ] The border overlay (`RoundedRectangle.stroke`) is absent in the active state -- using `if isActive { ... } else { ... }` for the overlay, NOT for the padding
- [ ] Padding is IDENTICAL in both states: `.padding(.horizontal, 12).padding(.vertical, 8)` -- verified by confirming the chip visual width does not change between default and active with the same label string
- [ ] `accessibilityLabel` updates to `"\(label), selected"` when `isActive == true`
- [ ] Rendered chip in active state has no visible border stroke -- the CadenceTerracotta background replaces the border entirely
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E3-S1

**Notes:** Font weight change from regular to semibold shifts the character widths in San Francisco Pro by a small but perceptible amount. The fixed 12pt H / 8pt V padding absorbs this shift -- do not change the padding conditionally to compensate. If the chip still resizes visually on toggle, the font rendering is the cause; do not adjust padding in response. This behavior is accepted per the motion spec; the 0.15s cross-dissolve (E5) makes the weight change imperceptible in normal use.

---

### S3: Sex chip lock icon -- permanent, accessibility-labelled

**Story ID:** PH-4-E3-S3
**Points:** 2

Implement the Sex chip lock icon: `lock.fill` at 11pt, rendered to the right of the label in both default and active states, with the mandatory `accessibilityLabel` "Private - not shared with partner". This icon is a design and accessibility requirement, not decorative.

**Acceptance Criteria:**

- [ ] When `isSexChip == true`, an `Image(systemName: "lock.fill")` is placed to the right of the label text within an `HStack(spacing: 4)`
- [ ] Lock icon font size: `.font(.system(size: 11))` -- not a Dynamic Type token; locked at 11pt per Design Spec §10.1
- [ ] Lock icon color matches the label color for the current state: `Color("CadenceTextPrimary")` in default state, `Color("CadenceTextOnAccent")` in active state
- [ ] Lock icon is visible in BOTH default and active states -- no conditional hiding
- [ ] `.accessibilityLabel("Private - not shared with partner")` applied to the `Image` using `.accessibilityLabel(Text("Private - not shared with partner"))`
- [ ] `.accessibilityHidden(false)` confirmed: the lock icon is not hidden from VoiceOver (do not add `.accessibilityHidden(true)`)
- [ ] When `isSexChip == false`, NO `Image(systemName: "lock.fill")` renders (the HStack contains only the label text)
- [ ] Chip with `isSexChip == true` renders correctly at default and active states in a SwiftUI Preview
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E3-S2

**Notes:** The 11pt lock icon does not scale with Dynamic Type. This is intentional per the spec -- the lock icon is a symbolic indicator at a fixed decorative size. The label text itself does scale. The `HStack(spacing: 4)` gap between label and icon uses the `space-4` token (4pt). If `isSexChip` is `false`, the chip's content is just `Text(label)`, not an `HStack` -- avoid adding an HStack with a single child when the lock icon is absent.

---

### S4: isReadOnly parameter and VoiceOver accessibility

**Story ID:** PH-4-E3-S4
**Points:** 2

Implement the `isReadOnly` parameter that disables the tap gesture for Partner dashboard use, and verify all VoiceOver labels are correct across both read-only and interactive states on both default and active chips.

**Acceptance Criteria:**

- [ ] When `isReadOnly == true`: chip is NOT wrapped in a `Button`; no `action` parameter exists in the read-only code path; no `ChipPressStyle` is applicable (placeholder for E5 validation)
- [ ] When `isReadOnly == true`: `.accessibilityAddTraits(.isStaticText)` is applied to the chip's outer view to communicate non-interactivity to VoiceOver
- [ ] When `isReadOnly == false`: chip is wrapped in `Button(action: action)` -- interactive, VoiceOver announces as button
- [ ] VoiceOver label for interactive default chip: `"\(label), unselected"` -- verified by enabling VoiceOver in simulator and navigating to the chip
- [ ] VoiceOver label for interactive active chip: `"\(label), selected"`
- [ ] VoiceOver label for read-only chip (any state): `"\(label), \(isActive ? "selected" : "unselected")"` -- same label content, no "button" announcement
- [ ] VoiceOver label for Sex chip lock icon: "Private - not shared with partner" -- announced separately from the chip label
- [ ] A `SymptomChip` Preview shows all four combinations: `isActive: false, isReadOnly: false`; `isActive: true, isReadOnly: false`; `isActive: false, isReadOnly: true`; `isActive: true, isReadOnly: true`; Sex chip variants for each
- [ ] `scripts/protocol-zero.sh` exits 0 on `SymptomChip.swift`
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-4-E3-S3

**Notes:** Structurally, `SymptomChip` can be implemented with a single conditional: when `isReadOnly == false`, wrap the chip `ZStack` or `HStack` content in a `Button(action: action) { ... }`. When `isReadOnly == true`, render the chip content directly without the `Button` wrapper. This avoids complex conditional gesture disabling and produces clean VoiceOver semantics without additional accessibility overrides.

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
- [ ] SymptomChip renders correctly in all 4 state combinations (active/default x readOnly/interactive)
- [ ] Sex chip lock icon renders permanently with correct accessibility label
- [ ] 44pt touch targets verified on all interactive chip instances
- [ ] Phase objective is advanced: SymptomChip is production-ready and reusable; Phase 5, 9, Log Sheet can consume it without modification
- [ ] cadence-design-system skill: no hardcoded hex values; CadenceTerracotta, CadenceBorder, CadenceTextPrimary, CadenceTextOnAccent used as Color asset references
- [ ] cadence-accessibility skill: VoiceOver labels correct; 44pt targets; Sex chip lock icon label mandatory
- [ ] swiftui-production skill: no AnyView; no force unwraps; isActive is a value param, not Binding
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

## Source References

- PHASES.md: Phase 4 -- Tracker Navigation Shell & Core Logging (in-scope: SymptomChip per §10.1)
- Design Spec v1.1 §10.1 (SymptomChip: all visual properties, padding, default/active states, lock icon, isReadOnly)
- Design Spec v1.1 §14 (accessibility: VoiceOver chip labels, Sex chip lock icon label, 44pt targets)
- cadence-design-system skill (color token usage rules)
- cadence-accessibility skill (accessibilityLabel pattern, touch target enforcement)
- swiftui-production skill (unidirectional data flow, no AnyView, 44pt targets)
- cadence-motion skill (chip animation is E5's scope; this epic sets up the visual substrate)
