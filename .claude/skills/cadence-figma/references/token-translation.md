# Token Translation Reference

Complete lookup tables for translating raw Figma MCP output to Cadence design tokens.
Source of truth: `docs/Cadence_Design_Spec_v1.1.md` v1.1, March 2026.

---

## Color Tokens

All colors are defined as named Color assets in `Cadence/Assets.xcassets/Colors/`. Use `Color("TokenName")` in Swift. Never use conditional light/dark logic — the asset handles adaptive values.

| Token | Light hex | Dark hex | Primary usage |
|---|---|---|---|
| `CadenceBackground` | `#F5EFE8` | `#1C1410` | App-wide background behind all content |
| `CadenceCard` | `#FFFFFF` | `#2A1F18` | Card and sheet surfaces |
| `CadenceTerracotta` | `#C07050` | `#D4896A` | Primary accent — period data, CTAs, active chips, active tab icon |
| `CadenceSage` | `#7A9B7A` | `#8FB08F` | Secondary accent — fertile window, ovulation, insight cards |
| `CadenceSageLight` | `#EAF0EA` | `#1E2B1E` | Sage-tinted surfaces — insight card bg, sharing strip active, fertility highlight |
| `CadenceTextPrimary` | `#1C1C1E` | `#F2EDE7` | Body copy, headings |
| `CadenceTextSecondary` | `#6C6C70` | `#98989D` | Subtitles, metadata, placeholder text |
| `CadenceTextOnAccent` | `#FFFFFF` | `#FFFFFF` | Text on terracotta fills (active chips, filled CTAs) |
| `CadenceBorder` | `#E0D8CF` | `#3A2E26` | Card inner stroke, chip default outline, input borders |
| `CadenceDestructive` | system red | system red | Account deletion, disconnect — use `Color(.systemRed)` or `.red` |

### Unresolved Gap: CadencePrimary

| Pseudo-token | Light hex | Dark hex | Usage |
|---|---|---|---|
| `CadencePrimary` (UNRESOLVED) | `#1C1410` | `#F2EDE7` | Paused sharing strip ONLY — §7 of spec |

**Status:** Referenced in spec §7 Elevation table but absent from §3 Color table. Implementation of the paused sharing strip state is **blocked** until the designer confirms whether:
- This token should be added to the color asset catalog, OR
- An existing token (e.g. `CadenceTextPrimary` inverted) should be used instead

Do not hardcode `#1C1410` or `#F2EDE7`. Do not create an xcassets entry without explicit approval.

### Color Translation Quick Reference

When the Figma MCP returns a hex value, map it as follows:

| MCP hex (light) | MCP hex (dark) | → Swift |
|---|---|---|
| `#F5EFE8` | `#1C1410` | `Color("CadenceBackground")` |
| `#FFFFFF` (surfaces) | `#2A1F18` | `Color("CadenceCard")` |
| `#C07050` | `#D4896A` | `Color("CadenceTerracotta")` |
| `#7A9B7A` | `#8FB08F` | `Color("CadenceSage")` |
| `#EAF0EA` | `#1E2B1E` | `Color("CadenceSageLight")` |
| `#1C1C1E` | `#F2EDE7` | `Color("CadenceTextPrimary")` |
| `#6C6C70` | `#98989D` | `Color("CadenceTextSecondary")` |
| `#FFFFFF` (on terracotta) | `#FFFFFF` | `Color("CadenceTextOnAccent")` |
| `#E0D8CF` | `#3A2E26` | `Color("CadenceBorder")` |
| system red | system red | `Color(.systemRed)` |

---

## Typography Tokens

System font (SF Pro / San Francisco) throughout. All tokens use Dynamic Type — no fixed-size text containers except the single sanctioned countdown numeral.

| Token name | SwiftUI style | Size | Weight | Usage |
|---|---|---|---|---|
| `display` | `.largeTitle` | 34pt | Semibold | Cycle phase name on Tracker Home |
| `title1` | `.title` | 28pt | Semibold | Dashboard card headings |
| `title2` | `.title2` | 22pt | Regular | Sheet / screen titles |
| `title3` | `.title3` | 20pt | Medium | Section headers within cards |
| `headline` | `.headline` | 17pt | Semibold | Button labels, active chip text |
| `body` | `.body` | 17pt | Regular | Primary body copy |
| `callout` | `.callout` | 16pt | Regular | Insight body text |
| `subheadline` | `.subheadline` | 15pt | Regular | Card sub-labels, secondary copy |
| `footnote` | `.footnote` | 13pt | Regular | Timestamps, metadata |
| `caption1` | `.caption` | 12pt | Regular | Chip default state labels |
| `caption2` | `.caption2` | 11pt | Regular | Section eyebrow labels (TODAY'S LOG, INSIGHT) |

### Countdown Numeral Exception

The large countdown number (days until period / ovulation) uses:
```swift
.font(.system(size: 48, weight: .medium, design: .rounded))
```
This must scale with `accessibilityLargeText`. It is the **only** place `.system(size:weight:design:)` is used.

### Usage Rules

- Eyebrow labels (`TODAY'S LOG`, `INSIGHT`) → `.caption2` + `.uppercased()` + `Color("CadenceTextSecondary")`
- White text → strictly on terracotta fills only → `Color("CadenceTextOnAccent")`
- Never pure black — `CadenceTextPrimary` (`#1C1C1E`) is the darkest sanctioned text color

---

## Spacing Tokens

Named constants must be defined in a `CadenceSpacing` enum or struct before use. Never use raw integer padding.

```swift
enum CadenceSpacing {
    static let space4:  CGFloat = 4
    static let space8:  CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space44: CGFloat = 44
}
```

| Token | Value | Canonical usage |
|---|---|---|
| `space4` | 4pt | Icon-to-label clearance |
| `space8` | 8pt | Chip grid interior padding, compact card sections |
| `space12` | 12pt | Related element separation within a card |
| `space16` | 16pt | Standard screen margin — all content insets from safe area edges |
| `space20` | 20pt | Card internal padding — primary content inset |
| `space24` | 24pt | Major section breaks within a scroll view |
| `space32` | 32pt | Between distinct cards in a feed |
| `space44` | 44pt | Minimum touch target size — enforced on all interactive elements |

---

## Corner Radius Tokens

| Component | Radius | SwiftUI |
|---|---|---|
| Screen-level cards (DataCard, InsightCard) | 16pt | `.cornerRadius(16)` |
| Symptom chips | Capsule | `.clipShape(Capsule())` |
| Flow level chips | Capsule | `.clipShape(Capsule())` |
| Confidence / status badges | Capsule | `.clipShape(Capsule())` |
| Period toggle buttons | 12pt | `.cornerRadius(12)` |
| Primary CTA buttons | 14pt | `.cornerRadius(14)` |
| Input fields (email, password, notes textarea) | 10pt | `.cornerRadius(10)` |
| Calendar day cells | 10pt | `.cornerRadius(10)` |
| Sharing status strip | 12pt | `.cornerRadius(12)` |
| Log Sheet / bottom sheet | 20pt top-only | Native system sheet — do not override |
| Tab bar | System (Liquid Glass) | iOS 26 system — do not override |

Any radius value returned by the Figma MCP that does not appear in this table is drift. Round to the nearest sanctioned value and flag for review.

---

## Elevation (Surface Layering)

Depth is created through color contrast and 1pt border strokes, not drop shadows.

| Surface | Fill | Stroke | Shadow |
|---|---|---|---|
| App background | `CadenceBackground` | — | None |
| Card / data surface | `CadenceCard` | 1pt `CadenceBorder` | None |
| Insight card | `CadenceSageLight` | 1pt `CadenceBorder` | None |
| Sharing strip (active) | `CadenceSageLight` | — | None |
| Sharing strip (paused) | `CadencePrimary` (UNRESOLVED) | — | None |
| Bottom sheet / Log Sheet | `CadenceCard` | — | System shadow |
| Tab bar / nav bar | `ultraThinMaterial` (Liquid Glass) | — | System |
