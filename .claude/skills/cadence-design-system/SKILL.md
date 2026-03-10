---
name: cadence-design-system
description: Enforces the locked Cadence design spec (v1.1) across all SwiftUI files. Knows every color token (CadenceTerracotta, CadenceSage, CadenceBackground, etc.), their light/dark hex values, the full type scale (11 tokens), spacing scale (8 tokens), and corner radius rules per component. Rejects hardcoded hex values, magic numbers, and system colors outside their sanctioned contexts. The single source of truth before any pixel is written. Use this skill whenever working on any SwiftUI file in the Cadence project, before writing any UI code, when reviewing existing SwiftUI views for design compliance, or when any question arises about colors, typography, spacing, corner radius, elevation, or component styling in the Cadence codebase. Trigger on any request involving Cadence UI, SwiftUI views, design tokens, visual styling, component layout, or design review for this project.
---

# Cadence Design System — Enforcement Skill (v1.1)

**Authoritative source:** `docs/Cadence_Design_Spec_v1.1.md` · March 2026 · Approved for Implementation

This skill is the design governance layer for every SwiftUI file in the Cadence project. When the spec and the implementation conflict, the spec wins. When this skill and an engineer's intuition conflict, this skill wins. When an open item in the spec conflicts with a closed rule here, flag it and hold pending designer sign-off.

---

## Governance Rules (Non-Negotiable)

These rules apply to every SwiftUI file without exception:

1. **No hardcoded hex values in Swift source.** All colors must reference named Color assets from xcassets using `Color("TokenName")` or the semantic SwiftUI equivalents where the spec explicitly sanctions them.
2. **No magic numbers for spacing.** Every padding, gap, inset, and frame dimension must map to a spacing token defined below. If a value is not in the spacing scale, it requires explicit designer sign-off.
3. **No magic numbers for corner radius.** Every `.cornerRadius()` or `.clipShape()` value must map to the component-specific radius table below. Do not invent radii.
4. **No arbitrary font sizes.** Every text element must use a named Dynamic Type style from the typography scale. The only sanctioned exception is the 48pt countdown number (see Typography section).
5. **No system colors** except `CadenceDestructive` (`.red`). Do not use `Color.blue`, `Color.green`, `Color.primary`, `Color.secondary`, `Color.label`, or any other system semantic color unless the spec explicitly names them.
6. **No external drop shadows.** Depth is created through color contrast and 1pt border strokes only. `shadow()` modifier is prohibited on card surfaces.
7. **No fixed-size text containers.** All text must support Dynamic Type scaling. Never set a fixed `.frame(height:)` on a text element.
8. **No UIKit custom views.** SwiftUI throughout. No `UIViewRepresentable` wrappers around UIKit views except where required by platform APIs (e.g., `UIImpactFeedbackGenerator`).
9. **All interactive elements: minimum 44×44pt touch target.** Use `.frame(minWidth: 44, minHeight: 44)` with `.contentShape(Rectangle())` where the visual element is smaller.
10. **All custom animations must be gated on `@Environment(\.accessibilityReduceMotion)`.** No exceptions.

---

## Color Tokens

All 10 tokens are defined as Color assets in xcassets with explicit light and dark appearance slots. The values below are locked — do not modify them.

| Token                | Light Mode | Dark Mode  | Sanctioned Usage                                                              |
| -------------------- | ---------- | ---------- | ----------------------------------------------------------------------------- |
| CadenceBackground    | `#F5EFE8`  | `#1C1410`  | App-wide background. Behind all content.                                      |
| CadenceCard          | `#FFFFFF`  | `#2A1F18`  | Card and bottom sheet surfaces.                                               |
| CadenceTerracotta    | `#C07050`  | `#D4896A`  | Primary accent: period data, CTAs, active chips, active tab icons.            |
| CadenceSage          | `#7A9B7A`  | `#8FB08F`  | Secondary accent: fertile window, ovulation metrics, insight cards.           |
| CadenceSageLight     | `#EAF0EA`  | `#1E2B1E`  | Sage tinted surfaces: insight card bg, active sharing strip, fertility bands. |
| CadenceTextPrimary   | `#1C1C1E`  | `#F2EDE7`  | All body copy and headings. Floor — never use pure black.                     |
| CadenceTextSecondary | `#6C6C70`  | `#98989D`  | Subtitles, metadata, placeholder text, timestamps.                            |
| CadenceTextOnAccent  | `#FFFFFF`  | `#FFFFFF`  | Text on terracotta fills only: active chips, filled CTAs.                     |
| CadenceBorder        | `#E0D8CF`  | `#3A2E26`  | 1pt inner border on cards, chip default outline, input field borders.         |
| CadenceDestructive   | system red | system red | Account deletion and disconnect actions only. Use `.red` color asset.         |

### Color Enforcement Rules

- `CadenceTextOnAccent` (#FFFFFF) is **only** sanctioned on filled `CadenceTerracotta` surfaces (active chips, primary CTAs, Sign in with Apple button). White text on any other surface is a violation.
- Pure black (`#000000`) text is prohibited. `CadenceTextPrimary` is the floor for all text.
- `CadenceTerracotta` on `CadenceBackground` passes WCAG AA (4.5:1 verified). `CadenceTerracotta` on `CadenceCard` (#FFFFFF) passes WCAG AA. These contrast relationships are locked.
- The terracotta and sage dark mode bumps (light → dark) are intentional luminance increases for WCAG AA compliance at `#1C1410`. Do not revert them.
- **Undocumented token flag:** `CadencePrimary` is referenced in §7 of the spec as `#1C1410` light / `#F2EDE7` dark for the paused Sharing Status Strip high-contrast state. This token is **not formally defined in §3**. Do not create a new xcassets entry for `CadencePrimary` without designer confirmation. Flag this gap before implementing the paused strip state.
- `Color("CadenceDestructive")` (system red) is sanctioned **only** for account deletion and disconnect CTAs. Do not use red for error states or validation feedback — the spec mandates `CadenceTextSecondary` with a `warning.fill` SF Symbol for errors.

---

## Typography Scale

System font (San Francisco / SF Pro) throughout. No custom typeface. All styles must support Dynamic Type.

| Token       | SwiftUI Style  | Size | Weight   | Primary Usage                                 |
| ----------- | -------------- | ---- | -------- | --------------------------------------------- |
| display     | `.largeTitle`  | 34pt | Semibold | Cycle phase name on Tracker Home              |
| title1      | `.title`       | 28pt | Semibold | Dashboard card headings                       |
| title2      | `.title2`      | 22pt | Regular  | Sheet and screen titles                       |
| title3      | `.title3`      | 20pt | Medium   | Section headers within cards                  |
| headline    | `.headline`    | 17pt | Semibold | Button labels, active chip text               |
| body        | `.body`        | 17pt | Regular  | Primary body copy, period toggle labels       |
| callout     | `.callout`     | 16pt | Regular  | Insight card body text                        |
| subheadline | `.subheadline` | 15pt | Regular  | Card sub-labels, secondary copy, strip labels |
| footnote    | `.footnote`    | 13pt | Regular  | Timestamps, metadata, legal disclaimer lines  |
| caption1    | `.caption`     | 12pt | Regular  | Chip default state labels, divider "or" text  |
| caption2    | `.caption2`    | 11pt | Regular  | Section eyebrow labels (TODAY'S LOG, INSIGHT) |

### Typography Enforcement Rules

- **Eyebrow labels** (`TODAY'S LOG`, `INSIGHT`): use `.caption2` style, `.uppercased()` modifier, `Color("CadenceTextSecondary")` — except the `INSIGHT` eyebrow which uses `Color("CadenceSage")`.
- **Countdown numbers** (e.g., "16 days"): use `.font(.system(size: 48, weight: .medium, design: .rounded))`. This is the **only** sanctioned use of a raw point size. It must still scale: use `@ScaledMetric` or verify compatibility with `accessibilityLargeText` settings.
- White text (`CadenceTextOnAccent`) on terracotta fills uses `.headline` (Semibold) for chips and CTAs — the weight communicates state, not just decoration.
- Never set `.font(.system(size: X))` for any value other than 48pt. All other text uses the named Dynamic Type styles above.

---

## Spacing Scale

Eight tokens covering the entire layout system. No other values are permitted without designer sign-off.

| Token    | Value | Primary Usage                                              |
| -------- | ----- | ---------------------------------------------------------- |
| space-4  | 4pt   | Micro gaps: icon-to-label clearance                        |
| space-8  | 8pt   | Dense cluster interior: chip grids, compact card sections  |
| space-12 | 12pt  | Related element separation within a card                   |
| space-16 | 16pt  | Standard screen margin — all content insets from safe area |
| space-20 | 20pt  | Card internal padding — primary content inset              |
| space-24 | 24pt  | Major section breaks within a scroll view                  |
| space-32 | 32pt  | Vertical gap between distinct cards in a feed              |
| space-44 | 44pt  | Minimum touch target dimension on all interactive elements |

### Layout Enforcement Rules

- **16pt horizontal safe-area inset on every screen.** Apply as `.padding(.horizontal, 16)` from the safe area edge, not from the screen edge.
- **Cards in a feed: 32pt vertical gap** between distinct cards. Use `spacing: 32` in the `LazyVStack`.
- **Card internal padding: 20pt uniform.** Apply as `.padding(20)` inside the card surface view.
- **`LazyVStack` for all feed views** — not `VStack`. Off-screen cards must not render.
- No hard-coded `frame(height:)` on scroll view content. Allow intrinsic sizing.
- Equal-width layout for period toggle buttons: use a `HStack` with `maxWidth: .infinity` on each button, `spacing: 12`.
- Two equal-width Countdown cards side by side: `HStack(spacing: 12)` with `maxWidth: .infinity` on each.

---

## Corner Radius Rules

Component-specific. Applying the wrong radius to any component is a spec violation.

| Component                             | Radius         | Implementation                                                               |
| ------------------------------------- | -------------- | ---------------------------------------------------------------------------- |
| Screen-level cards (Data Card)        | 16pt           | `.cornerRadius(16)` or `.clipShape(RoundedRectangle(cornerRadius: 16))`      |
| Log Sheet / bottom sheets             | 20pt top only  | Native iOS sheet — do not override. `UISheetPresentationController` default. |
| Symptom chips                         | 20pt (capsule) | `.clipShape(Capsule())`                                                      |
| Period toggle buttons                 | 12pt           | `.cornerRadius(12)`                                                          |
| Primary CTA buttons                   | 14pt           | `.cornerRadius(14)`                                                          |
| Input fields (email, password, notes) | 10pt           | `.cornerRadius(10)`                                                          |
| Confidence / status badges            | 20pt (capsule) | `.clipShape(Capsule())`                                                      |
| Calendar day cells                    | 10pt           | `.cornerRadius(10)`                                                          |
| Partner Sharing Status Strip          | 12pt           | `.cornerRadius(12)`                                                          |
| Tab bar                               | System         | `ultraThinMaterial`. Do not override.                                        |
| Navigation bar                        | System         | `ultraThinMaterial`. Do not override.                                        |

---

## Elevation & Surface Rules

Cadence uses **no external drop shadows**. Depth is expressed through:

- Opaque fills (`CadenceCard`) against the warm cream background (`CadenceBackground`)
- 1pt inner border stroke at `CadenceBorder` on all card and input surfaces

| Surface Layer             | Color Asset             | Border                          |
| ------------------------- | ----------------------- | ------------------------------- |
| App background            | CadenceBackground       | None                            |
| Cards / data surfaces     | CadenceCard             | 1pt inner stroke, CadenceBorder |
| Insight card variant      | CadenceSageLight        | 1pt inner stroke, CadenceBorder |
| Sharing strip (active)    | CadenceSageLight        | None                            |
| Sharing strip (paused)    | Undocumented — flag gap | See color conflict note above   |
| Bottom sheets / Log Sheet | CadenceCard             | None (system sheet)             |
| Tab bar / nav bar         | `ultraThinMaterial`     | System-managed                  |

The 1pt border implementation pattern:

```swift
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .strokeBorder(Color("CadenceBorder"), lineWidth: 1)
)
```

Adjust `cornerRadius` to match the component's value from the radius table.

---

## Component-Specific Rules

### Symptom Chips

- Default: transparent background, 1pt `CadenceBorder` stroke, `caption1` style, `CadenceTextPrimary` text.
- Active: `CadenceTerracotta` fill, no border, `headline` style (Semibold), `CadenceTextOnAccent` text.
- Fixed padding: 12pt horizontal / 8pt vertical. Do not make this adaptive — prevents layout jitter on weight change.
- Chips must accept `isReadOnly: Bool` parameter to disable tap gesture for Partner views.
- The Sex chip must always display a `lock.fill` SF Symbol at 11pt to the right of the label, in all states.
- VoiceOver: `accessibilityLabel` required — format: `"{symptom name}, {selected/unselected}"`.
- Sex chip lock: `accessibilityLabel("Private - not shared with partner")`.

### Primary CTA Button

- Background: `CadenceTerracotta`. Exception: Sign in with Apple uses `#000000` (hardcoded — the only sanctioned raw hex in Swift source for this specific component per Apple's branding rules).
- Text: `headline` style, Semibold, `#FFFFFF`.
- Height: 50pt fixed.
- Corner radius: 14pt.
- Width: full container with 16pt horizontal inset.
- Loading state: `ProgressView` replaces label text. Button width must be locked to prevent layout shift.
- Disabled state: 40% opacity on the entire button (`opacity(0.4)`).

### Data Card

- Background: `CadenceCard`.
- Border: 1pt `CadenceBorder` inner stroke.
- Corner radius: 16pt.
- Internal padding: 20pt uniform.
- No shadow.
- Insight variant: replace `CadenceCard` with `CadenceSageLight`. Border rule unchanged.

### Period Toggle Buttons

- Inactive: `CadenceCard` background, 1pt `CadenceBorder` border, `body` style, `CadenceTextPrimary`.
- Active: `CadenceTerracotta` fill, `body` style Semibold, `CadenceTextOnAccent`.
- Height: 44pt minimum.
- Corner radius: 12pt.
- Layout: `HStack(spacing: 12)` with `.frame(maxWidth: .infinity)` on each button.

### Tab Bar Icons

- All icons use SF Symbols.
- Inactive tint: `CadenceTextSecondary`.
- Active tint: `CadenceTerracotta`.
- Rendering size: 25pt, medium weight.
- Center Log tab (`plus.circle.fill`): permanently filled — no inactive/outlined variant.

---

## Motion Rules

- Chip tap down: `scaleEffect(0.95)`, spring response 0.3, damping 0.7.
- Chip toggle color change: 0.15s easeOut cross-dissolve.
- Sheet presentation: native iOS `.presentationDetents([.medium, .large])`.
- Navigation: standard `NavigationStack` push — no custom transitions.
- Sharing strip state change: 0.2s crossfade.
- Partner Dashboard sharing-paused hide: 0.25s easeInOut crossfade on cards.
- Skeleton loading: shimmer, 1.2s loop, left-to-right.
- **All of the above must be gated on `@Environment(\.accessibilityReduceMotion)`** — instant state change when true, no layout shift.

---

## Pre-Implementation Checklist

Before writing any SwiftUI view code, verify against this list:

- [ ] Every color is a named xcassets token — no hex strings in Swift.
- [ ] Every spacing value maps to the 8-token scale.
- [ ] Every corner radius maps to the component-specific table.
- [ ] Every text element uses a named Dynamic Type style.
- [ ] Every interactive element has a 44×44pt minimum touch target.
- [ ] No external `shadow()` modifiers on card surfaces.
- [ ] All animations check `accessibilityReduceMotion`.
- [ ] Tab bar and nav bar use `ultraThinMaterial` — not overridden.
- [ ] `LazyVStack` used in all feed views.
- [ ] Cards carry a 1pt `CadenceBorder` inner stroke.
- [ ] The `CadencePrimary` token gap is flagged if the paused sharing strip is being implemented.

If any item cannot be checked off, stop and resolve it before committing code. The spec is the floor. There is no grace period for drift.
