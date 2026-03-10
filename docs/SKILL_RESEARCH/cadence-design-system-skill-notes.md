# Cadence Design System Skill — Extraction Notes

**Generated:** March 7, 2026
**Skill created:** `.claude/skills/cadence-design-system/SKILL.md`
**Skill format reference:** `.claude/skills/skill-creator/SKILL.md` (project-local skill-creator)

---

## Source Documents Used

| Document | Version | Role |
| --- | --- | --- |
| `docs/Cadence_Design_Spec_v1.1.md` | v1.1 · March 2026 | Primary design authority. All token definitions extracted from this file. |
| `docs/Cadence-design-doc.md` | v1.0 · March 7, 2026 | Product requirements. Read in full. Contains no conflicting design token definitions. Used to confirm platform context (iOS 26, SwiftUI, Liquid Glass, SwiftData). |

---

## Sections Used from Each Document

### Cadence_Design_Spec_v1.1.md
- §0 Brand Asset Reference — locked icon palette, hex values that seed the color system
- §2 Platform & Framework Assumptions — iOS 26, SwiftUI-only, no UIKit custom views, 44pt touch target, Dynamic Type requirement
- §3 Color System — all 10 named tokens with light/dark hex values and usage rules
- §4 Typography — 11-token scale, usage rules, eyebrow formatting, 48pt countdown exception
- §5 Spacing & Layout — 8-token spacing scale, layout rules (LazyVStack, 16pt margin, 32pt card gap, 20pt internal padding)
- §6 Corner Radii — all 9 component entries
- §7 Elevation & Surfaces — surface layer table, border rules, no-shadow doctrine, `CadencePrimary` reference (conflict — see below)
- §10 Component Library — Symptom Chip, Period Toggle Buttons, Primary CTA Button, Data Card, Partner Sharing Status Strip
- §11 Motion & Interaction — all animation specifications, reduced motion gate requirement
- §14 Accessibility — touch target, WCAG AA verification, VoiceOver requirements, colorblind considerations

### Cadence-design-doc.md (PRD)
- §5 Tech Stack and Architecture — confirms SwiftUI-only posture, Liquid Glass chrome doctrine, custom component boundaries
- Used to confirm no additional design tokens are defined outside the spec.

---

## Conflicts Found

### Conflict 1: `CadencePrimary` token undefined in §3

**Location:** §7 Elevation & Surfaces, row "Sharing status strip (paused)"
**Statement in spec:** `CadencePrimary (#1C1410 light / #F2EDE7 dark)`
**Issue:** `CadencePrimary` does not appear in the §3 Color System token table. It is referenced exactly once, for the paused state of the Sharing Status Strip.

**Analysis of the values:**
- `#1C1410` light = same as `CadenceBackground` dark mode value (a very dark warm brown)
- `#F2EDE7` dark = same as `CadenceTextPrimary` dark mode value (a warm near-white ivory)

These values describe an inverse high-contrast surface: charcoal in light mode, warm ivory in dark mode. This is semantically consistent with the "demands attention" description in the same row.

**Resolution:** Conservative. The skill flags this as an undocumented token gap. Engineers must not create a new `CadencePrimary` xcassets entry without explicit designer confirmation. The spec-provided values (#1C1410 / #F2EDE7) are documented in the notes only — not promoted to a named skill token. Implementation of the paused strip state must halt pending designer resolution.

---

## Final Rule Categories Encoded in the Skill

| Category | Token Count / Rules |
| --- | --- |
| Color tokens | 10 named tokens with light/dark hex and usage constraints |
| Color enforcement | 6 rules (no hex in Swift, white text restriction, pure black prohibition, WCAG notes, CadencePrimary gap flag, destructive usage restriction) |
| Typography scale | 11 tokens mapped to SF Pro Dynamic Type styles |
| Typography enforcement | 4 rules (eyebrow format, 48pt exception, white text weight, no raw point sizes) |
| Spacing scale | 8 tokens |
| Layout enforcement | 6 rules (16pt margin, 32pt card gap, 20pt internal padding, LazyVStack, no fixed scroll heights, equal-width stacks) |
| Corner radius | 10 component-specific values |
| Elevation / surfaces | No-shadow doctrine, 1pt border pattern, layer table |
| Component rules | 5 components (chips, CTAs, data cards, period toggles, tab icons) |
| Motion rules | 8 animation specifications, reduced motion gate |
| Pre-implementation checklist | 12-point gate before any SwiftUI commit |

---

## Notes on Skill Placement

The skill is installed project-locally at:

```
/Users/Dinesh/Desktop/cadence-cycle-tracker/.claude/skills/cadence-design-system/
```

This follows the same pattern as the project-local `skill-creator` skill already present in `.claude/skills/skill-creator/`. Project-local installation keeps the design governance co-located with the codebase it governs.
