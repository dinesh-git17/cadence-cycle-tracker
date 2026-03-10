# cadence-xcode-project Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-xcode-project/SKILL.md`
**Package path:** `.claude/skills/skill-creator/cadence-xcode-project.skill`

---

## Local Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure, YAML frontmatter requirements, 500-line limit, description as trigger mechanism |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schemas for evals and grading |
| `.claude/skills/cadence-design-system/SKILL.md` | Reference skill — format, tone, enforcement pattern |
| `docs/Cadence_Design_Spec_v1.1.md` | Color token definitions (hex values, 11 tokens), xcassets spec |
| `docs/Cadence-design-doc.md` | MVP PRD — Tracker/Partner role split, feature scope |
| `docs/Cadence_MVP_Spec.md` | Target structure, tab counts, data model, out-of-scope items |
| `docs/Cadence_SplashScreen_Spec.md` | **Primary source** for source group layout (`Cadence/Views/Splash/`), asset catalog paths (`Colors.xcassets`, `Images.xcassets`), image asset names, `CadenceMark` color token |
| `.claude/skills/cadence-navigation/SKILL.md` | View file naming conventions (`TrackerShell`, `PartnerShell`, etc.) |

---

## skill-creator Location Used

`.claude/skills/skill-creator/` (project-local install)

- `init_skill.py` is NOT present in this install — consistent with prior skill creation sessions (noted in MEMORY.md)
- Skill directory created manually
- Validated with `python -m scripts.quick_validate` from skill-creator directory → `Skill is valid!`
- Packaged with `python -m scripts.package_skill` → `cadence-xcode-project.skill`

---

## Official Anthropic Sources Used

| Source | Used For |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` (local) | Canonical skill structure, YAML frontmatter spec, 500-line limit, description as primary trigger mechanism, `skill-name/SKILL.md` anatomy |

The skill-creator SKILL.md is the authoritative Anthropic-aligned standard for this project. No external Anthropic URLs were required — the local skill is the governance document.

---

## XcodeGen / Apple Authoritative Sources Used

| Source | Used For |
|---|---|
| `https://yonaskolb.github.io/XcodeGen/Docs/ProjectSpec.html` | `project.yml` structure, targets, sources, `createIntermediateGroups`, `groupSortPosition`, `excludes`/`includes` patterns, why `.pbxproj` should not be edited directly |
| `https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/Named_Color.html` | Named color Contents.json structure — `colors` array, `components`, `color-space`, `idiom`, `info` block |
| `https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/ImageSetType.html` | Image set Contents.json structure — `images` array, `scale`, `filename`, `idiom`, `info` block |
| Apple Asset Catalog Format Reference (archive) | App Icon `.appiconset` with iOS 18+ alternate appearance (dark/tinted) entries |

---

## Cadence-Specific Facts Extracted

### Repository Status
Pre-implementation as of March 7, 2026. No `project.yml`, no `.xcodeproj`, no Swift source files, no `xcassets` directories exist yet. The skill defines the intended structure from first principles grounded in the spec documents.

### Target Structure
- **Single target:** `Cadence` (iOS application, iOS 26)
- **No test targets, extensions, frameworks, or widgets** in beta MVP scope (confirmed: `docs/Cadence_MVP_Spec.md` "Out of Scope for Beta")
- **Bundle identifier:** `com.cadence.tracker` (inferred — not stated in docs; flagged as assumption in skill)

### Source Group Layout
Derived from `Cadence_SplashScreen_Spec.md` (`Cadence/Views/Splash/`, `Cadence/Resources/`) and navigation conventions from `cadence-navigation` skill (`TrackerShell`, `PartnerShell`, `LogSheetView`):
- `Cadence/App/`
- `Cadence/Views/Splash/`, `Tracker/`, `Partner/`, `Auth/`, `Log/`, `Shared/`
- `Cadence/ViewModels/`
- `Cadence/Models/`
- `Cadence/Services/`
- `Cadence/Resources/Colors.xcassets/`, `Images.xcassets/`

### Asset Catalogs
- `Colors.xcassets` — 11 named color sets (10 from Design Spec §3 + `CadenceMark` from Splash Spec)
- `Images.xcassets` — 4 assets: `AppIcon.appiconset`, `cadence-mark-light.imageset`, `cadence-mark-dark.imageset`, `cadence-mark-tinted.imageset`

### Color Token Decimal Values
All 10 design system tokens + `CadenceMark` converted from hex to sRGB decimal for `Contents.json` components.

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|---|---|
| No `project.yml` exists — cannot verify actual XcodeGen spec structure | Skill defines the **required** structure from spec documents. Noted as "does not exist yet" in skill header. |
| `bundle identifier` not stated in any doc | Used `com.cadence.tracker` as a reasonable inference. Not a governance rule — engineers set the actual identifier. |
| `CadencePrimary` token referenced in Design Spec §7 but not defined in §3 | Preserved existing gap flag from `cadence-design-system` skill. Added to skill's color registry as "flagged gap — do not create without designer confirmation." |
| `cadence-mark-*.png` assets: Splash Spec lists them as `Images.xcassets` image sets, but they are also described as App Icon variants in Design Spec §0 | Skill encodes both: reference imagesets (`cadence-mark-light.imageset` etc.) AND `AppIcon.appiconset` with light/dark/tinted appearances. The PNGs serve dual purpose: reference for Bézier tracing (Splash) + App Icon source files. |
| `AppIcon.appiconset` Contents.json for iOS 26 dark/tinted variants | Used the modern Xcode 16+ `appearances` array pattern (same as color assets: `"appearance": "luminosity"`, `"value": "dark"/"tinted"`). This matches Apple's documented behavior for alternate app icon appearances introduced in iOS 18. |
| `createIntermediateGroups` behavior for new files | XcodeGen docs confirm: with this option, files added under `Cadence/` are automatically included in the target on next `xcodegen generate`. No per-file `project.yml` entry needed for files under the sources path. |

---

## Key Enforcement Rules Encoded

1. **XcodeGen-only workflow** — `project.yml` → `xcodegen generate` → commit both; `.pbxproj` never edited directly
2. **New file rule** — add file to correct subdirectory, run `xcodegen generate`, commit `.xcodeproj` with new file
3. **Spec-project atomicity** — `project.yml` and `Cadence.xcodeproj` always committed together
4. **Single target** — one `Cadence` application target; no new targets without explicit spec change
5. **Source group conventions** — 7-directory layout enforced; Tracker/Partner views never mixed
6. **Asset catalog separation** — `Colors.xcassets` colors only, `Images.xcassets` images only
7. **Color registry lock** — 11 defined sets; no additions without designer sign-off
8. **Contents.json format** — two-entry `colors` array, decimal components, `"author": "xcode"`, `"version": 1`
9. **Color source-of-truth** — `Color("TokenName")` in Swift only; no hex literals, no `Color(red:green:blue:)`
10. **`CadencePrimary` gap** — flagged; do not create without designer confirmation
