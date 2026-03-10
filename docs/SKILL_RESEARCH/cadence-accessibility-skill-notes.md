# cadence-accessibility Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-accessibility/SKILL.md`
**Package output:** `.claude/skills/skill-creator/cadence-accessibility.skill`

---

## Files Read

| File                                                 | Purpose                                                                                                                       |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/skill-creator/SKILL.md`              | Skill creation process and conventions                                                                                        |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference                                                                                                         |
| `docs/Cadence-design-doc.md`                         | MVP PRD v1.0 — screen specs, VoiceOver requirements per screen                                                                |
| `docs/Cadence_Design_Spec_v1.1.md`                   | Design system v1.1 — §2 Platform, §3 Color, §4 Typography, §10.1 Chip, §11 Motion, §12.5 Partner Dashboard, §14 Accessibility |

---

## Skill-Creator Location Used

`/Users/Dinesh/Desktop/cadence-cycle-tracker/.claire/skills/skill-creator/`

Scripts used:

- `quick_validate.py` — validation passed on first run (no angle brackets in description)
- `package_skill.py` — produced `cadence-accessibility.skill`

---

## Sources Used

### Claude Code Skill Standards

- Local `skill-creator` SKILL.md and `references/schemas.md` — authoritative for this project's conventions.

### Apple Official Sources

- **Apple HIG — Accessibility / Layout**: Minimum touch target 44×44pt. `contentShape(Rectangle())` for expanding hit area beyond visual bounds.
- **Apple HIG — Accessibility / Motion**: `accessibilityReduceMotion` — respect it by eliminating animation, not slowing it.
- **SwiftUI Documentation — `accessibilityLabel(_:)`**: Replaces the default description with a custom label. Required for all non-trivially-labeled controls.
- **SwiftUI Documentation — `accessibilityAddTraits(_:)` / `accessibilityRemoveTraits(_:)`**: Modifies VoiceOver interaction model (e.g. removing `.isButton` from read-only chips).
- **SwiftUI Documentation — `@ScaledMetric`**: Scales a numeric value proportionally to a Dynamic Type category. Used for the 48pt countdown numeral.
- **SwiftUI Documentation — `@Environment(\.dynamicTypeSize)`**: Reads the current Dynamic Type size, enabling layout adaptation at threshold values.
- **Apple Developer Documentation — `DynamicTypeSize`**: Enum with cases including `.accessibility1` through `.accessibility5`. `.accessibility1` is the trigger point for the Bento grid collapse per the Cadence spec.
- **Apple HIG — Accessibility / Color and Contrast**: System minimum 4.5:1 for normal text, 3:1 for large text. Cadence spec verifies specific pairs against these thresholds.

### WCAG Primary Sources

- **WCAG 2.1 Success Criterion 1.4.3 — Contrast (Minimum)**: Level AA requires 4.5:1 for normal text, 3:1 for large text (18pt+ or 14pt+ bold).
- **WCAG 2.1 Success Criterion 1.4.1 — Use of Color**: Color must not be the only visual differentiator. Cadence handles this via fill pattern (solid vs. band) for period vs. fertile window.

---

## Cadence-Specific Accessibility Facts Extracted from Docs

| Fact                                                               | Source                 |
| ------------------------------------------------------------------ | ---------------------- |
| 44×44pt minimum touch target on all interactive elements           | Design Spec §2, §14    |
| `.frame(minWidth: 44, minHeight: 44)` with `contentShape`          | Design Spec §14        |
| All custom animations gated on `accessibilityReduceMotion`         | Design Spec §11, §14   |
| Instant state changes under reduceMotion, hold durations preserved | Design Spec §11        |
| Symptom chip VoiceOver: `"{name}, {selected/unselected}"`          | Design Spec §14        |
| Sex chip lock icon label: `"Private - not shared with partner"`    | Design Spec §14        |
| All text uses system Dynamic Type tokens, no fixed-size text       | Design Spec §2, §4     |
| Countdown 48pt numeral must scale with accessibilityLargeText      | Design Spec §4         |
| Partner Bento grid collapses 2-up → 1-up at Accessibility1         | Design Spec §12.5, §14 |
| CadenceTerracotta on #F5EFE8 → WCAG AA 4.5:1 verified              | Design Spec §3         |
| CadenceTerracotta on #FFFFFF → WCAG AA                             | Design Spec §3         |
| Dark mode Terracotta #D4896A on #1C1410 → WCAG AA                  | Design Spec §3         |
| Dark mode Sage #8FB08F on #1C1410 → WCAG AA                        | Design Spec §3         |
| Terracotta and sage never sole visual differentiators              | Design Spec §14        |
| Period vs fertile window: fill (solid) vs band — not color alone   | Design Spec §14        |
| Password show/hide toggle announces state change to VoiceOver      | PRD §8.1               |
| SIWA button: system accessibility handled by Apple                 | PRD §8.1               |

---

## Ambiguities and Resolutions

### 1. CadencePrimary token undefined in color table

**Ambiguity:** Design Spec §7 references `CadencePrimary` for the sharing strip paused surface. The token appears in the spec text but is not defined in §3 color table. Contrast of this surface against its text cannot be verified from the spec alone.
**Resolution:** Skill flags this as a known gap. The paused strip contrast must be confirmed with the designer before shipping. The skill does not fabricate a ratio.

### 2. CadenceTextSecondary contrast

**Ambiguity:** The spec does not explicitly verify `CadenceTextSecondary` (`#6C6C70` light / `#98989D` dark) contrast ratios. It is used for subtitles, metadata, and secondary copy — some of which appear near or on interactive elements.
**Resolution:** Skill requires verification of CadenceTextSecondary on interactive elements against the 3:1 WCAG AA minimum for UI components. Does not claim it passes without verification.

### 3. `@ScaledMetric` for 48pt countdown

**Ambiguity:** The spec says the 48pt numeral "must scale with `accessibilityLargeText`" but does not specify the Dynamic Type reference category to scale relative to.
**Resolution:** Used `@ScaledMetric(relativeTo: .largeTitle)` as the closest named Dynamic Type category in intent (the numeral is a display-scale element). This is a conservative interpretation — if the designer specifies a different reference category, update accordingly.

### 4. Period toggle buttons — toggle vs action semantics

**Ambiguity:** "Period started" / "Period ended" are styled as toggle-like pill buttons, but functionally they trigger events (start/end period), not persistent toggle state.
**Resolution:** Skill distinguishes these from symptom chips: they use action button semantics (no `{selected/unselected}` suffix), following standard button `accessibilityLabel` patterns.

### 5. Reduced motion overlap with cadence-motion skill

**Ambiguity:** Reduced motion is already governed by `cadence-motion`. Including it here creates cross-skill overlap.
**Resolution:** The overlap is intentional and acknowledged in the skill. `cadence-motion` is the motion implementation authority; `cadence-accessibility` is the accessibility contract gate. The reduced motion rule must appear in both because: (a) the accessibility checklist must be self-contained for screen review, and (b) engineers may run either skill in isolation.

---

## Key Enforcement Rules Encoded

1. 44×44pt on all interactive elements — `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())`
2. `accessibilityReduceMotion` gating on every custom animation
3. Chip label format: `"{name}, {selected/unselected}"` — explicit, never implicit
4. Sex chip lock icon: `"Private - not shared with partner"` — not hidden
5. `isReadOnly` chips: remove `.isButton` trait
6. Countdown 48pt: `@ScaledMetric(relativeTo: .largeTitle)`
7. Bento grid: `dynamicTypeSize >= .accessibility1` → 1-up `VStack`
8. Contrast: reference only spec-verified pairs; flag CadencePrimary gap
9. Colorblind: period vs fertile window differentiated by fill pattern + color
10. Screen-level checklist: all items must pass before shipping
