# Liquid Glass iOS 26 Skill — Extraction Notes

**Generated:** March 7, 2026
**Skill created:** `.claude/skills/liquid-glass-ios26/SKILL.md`
**Skill format reference:** `.claude/skills/skill-creator/SKILL.md` (project-local)

---

## Source Documents Read

| Document | Version | Role |
| --- | --- | --- |
| `docs/Cadence_Design_Spec_v1.1.md` | v1.1 · March 2026 | Design authority for tab bar, nav bar, and chrome intent |
| `docs/Cadence-design-doc.md` | v1.0 · March 7, 2026 | iOS 26 design posture, system chrome boundaries, Tracker IA |

---

## Official Anthropic Sources Used for Skill Format

- `.claude/skills/skill-creator/SKILL.md` (project-local skill-creator)
  - SKILL.md anatomy (YAML frontmatter, body structure, progressive disclosure)
  - 500-line limit
  - Description-as-trigger-mechanism requirement
  - "Pushy" description guidance to prevent under-triggering

---

## Apple / Primary Sources Used for Liquid Glass Research

| Source | Type | Key Information Extracted |
| --- | --- | --- |
| Apple Developer Documentation — `glassEffect(_:in:)` | Official (JS-gated, partially accessible) | API exists, iOS 26+ availability confirmed |
| Apple Developer Documentation — Adopting Liquid Glass | Official (JS-gated, partially accessible) | Navigation layer principle confirmed |
| Apple Developer Documentation — Applying Liquid Glass to custom views | Official (JS-gated, partially accessible) | GlassEffectContainer grouping rules confirmed |
| WWDC25 Session 323 — "Build a SwiftUI app with the new design" | Official Apple video | Tab bar floating behavior, structural Tab API, automatic glass on recompile, toolbarBackground placement rule |
| Donny Wals — "Exploring tab bars on iOS 26" | Authoritative community (aligns with Apple guidance) | tabBarMinimizeBehavior, accessory views, layering philosophy |
| jorgemrht.dev — "Liquid Glass Tab Bar in SwiftUI" | Authoritative community | toolbarBackground must live in Tab content, not TabView; structural Tab API |
| dev.to — "Liquid Glass in Swift: Official Best Practices" | Community (summarizes Apple guidance) | Navigation layer principle, glass-on-glass prohibition, glassEffect as navigation-only |
| github.com/conorluddy/LiquidGlassReference | Third-party reference (not Apple official) | glassEffect() ordering rule: must come AFTER .background() |
| ioscompatibility.com/modifiers/glass-effect | Community | @available(iOS 26, *), ultraThinMaterial as fallback |

**Note:** Apple's official documentation pages for `glassEffect` and related APIs require JavaScript to render and were not directly readable. The Apple WWDC25 session video and community sources that explicitly reference Apple documentation were used as the next-best primary source. Rules derived from non-Apple sources are marked conservatively in the skill.

---

## Cadence-Specific Facts Extracted from the Docs

From `Cadence_Design_Spec_v1.1.md`:
- §1: "Liquid Glass chrome for system surfaces" — establishes glass as the chrome layer
- §2: "`ultraThinMaterial` for tab bars and navigation bars", "Standard `TabView` and `NavigationStack` — no custom navigation chrome"
- §6 Corner Radii: "Tab bar: System (Liquid Glass) — iOS 26 native — do not override"
- §7 Elevation: "Tab bar / nav bar: `ultraThinMaterial` (Liquid Glass). System-managed. Do not override."
- §9 Tab Bar Icons: Active tint = CadenceTerracotta (#C07050 / #D4896A dark), Inactive = CadenceTextSecondary, 25pt medium weight
- §9: Center Log tab = `plus.circle.fill`, permanently filled, always CadenceTerracotta, never inactive/outlined
- §12.2 Tracker Home: Nav bar title = "Cadence" or empty, `ultraThinMaterial`

From `Cadence-design-doc.md`:
- §5 iOS 26 Design Posture: "Use system Liquid Glass for: TabBar, NavigationBar, sheet backgrounds, system alerts"
- §5: "Use custom components for: dashboard cards, symptom chips, calendar grid..." (explicitly NOT the tab bar or nav bar)
- Tracker IA: 5 tabs — Home (1), Calendar (2), Log (3, center modal intercept), Reports (4), Settings (5)

---

## Ambiguity and Conflicts Found

### 1. glassEffect() vs .background() ordering rule
**Source:** `github.com/conorluddy/LiquidGlassReference` (third-party, non-Apple official)
**Claim:** `glassEffect()` must be applied after `.background()` because glass samples what is rendered behind it.
**Apple confirmation status:** Could not directly verify from Apple's JS-gated docs. The underlying logic is technically sound (SwiftUI modifier ordering creates new views in sequence; glass renders as an overlay that samples its environment). The rule aligns with general SwiftUI modifier-ordering behavior principles documented by Apple.
**Resolution:** The skill encodes the rule as stated (glass after background) with the technical explanation. It is marked as derived from community sources, not Apple docs directly.

### 2. `toolbarBackground(.glass, for:)` API
**Source:** Some community references mention this API.
**Apple confirmation status:** Unverified. Not found in directly readable Apple docs.
**Resolution:** The skill notes this as "verify against Xcode 26 SDK release notes before use." It does not make `toolbarBackground(.glass)` a primary recommendation.

### 3. `ultraThinMaterial` vs iOS 26 Liquid Glass relationship
**Finding:** In iOS 26, `ultraThinMaterial` as used in the spec (§2, §7) appears to be the Cadence team's semantic label for the Liquid Glass tab bar and nav bar material. Apple's iOS 26 implementation uses `glassEffect()` for custom surfaces, but the standard `TabView` and `NavigationStack` bars receive glass automatically without specifying the material explicitly.
**Resolution:** The skill disambiguates: `ultraThinMaterial` = pre-iOS 26 fallback material; `glassEffect()` = iOS 26 custom surface API; automatic system glass = the default for tab bar and nav bar. References to "ultraThinMaterial" in the Cadence spec are treated as intent (use Liquid Glass chrome), not as literal API usage on the navigation bars.

### 4. Permanently filled Log tab implementation
**Finding:** Apple's tab bar APIs apply system active/inactive tinting. Overriding this for the center button (always terracotta, regardless of selection) is not explicitly documented in Apple's SwiftUI `Tab` API docs.
**Resolution:** The skill uses `foregroundStyle` override on the icon as the conservative pattern. Flags this as requiring verification during implementation.

---

## Key Enforcement Rules Encoded in the Skill

| Rule | Source |
| --- | --- |
| `glassEffect()` must come after `.background()` in modifier chain | GitHub reference + SwiftUI modifier logic |
| Tab bar and nav bar glass is automatic — do not override | WWDC25 session 323, Apple docs, Cadence spec §7 |
| `toolbarBackground()` must live in Tab content, not on TabView | jorgemrht.dev (aligned with Apple API behavior) |
| Glass is navigation-layer only — never applied to content cards | Apple docs, Cadence spec §7, PRD §5 |
| `glassEffect()` requires `@available(iOS 26, *)` guard with `ultraThinMaterial` fallback | ioscompatibility.com, general iOS availability patterns |
| No `GlassEffectContainer` nesting | Apple docs (GlassEffectContainer) |
| Glass cannot sample other glass — use GlassEffectContainer | Apple docs, WWDC25 session 323 |
| Log tab = permanently terracotta `plus.circle.fill`, no inactive state | Cadence spec §9 |
| Log tab intercepts to sheet, does not navigate | Cadence spec §12.3 |
| No `shadow()` on Liquid Glass surfaces | Apple design guidance |
| No competing overlays (borders, veils) on tab bar or nav bar | jorgemrht.dev, Cadence spec §7 |
