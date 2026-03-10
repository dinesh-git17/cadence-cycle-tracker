# Color Token Asset Catalog

**Epic ID:** PH-0-E2
**Phase:** 0 -- Project Foundation
**Estimated Size:** M
**Status:** Draft

---

## Objective

Populate `Cadence/Resources/Colors.xcassets` with all 10 design system color tokens defined in Design Spec v1.1 §3, each as a named colorset with explicit light-mode and dark-mode component values in the correct decimal format. This catalog is the sole source of color truth for every Swift source file in the project -- once it exists, no hardcoded hex value or `Color(red:green:blue:)` call in Swift is ever justified.

## Problem / Context

Design Spec v1.1 §3 mandates: "All colors are defined as named Color assets in xcassets with explicit light and dark mode values. No hardcoded hex values in Swift source files." The `no-hex-in-swift` hook enforces this at the tooling level.

If `Colors.xcassets` does not exist before any UI work begins, every Phase 2+ engineer either blocks waiting for the catalog or introduces hardcoded hex values that accumulate as hook violations. Establishing the complete color token set in Phase 0 -- before any feature code is written -- makes all UI phases independently unblocked with respect to color.

The dark-mode contrast issue from Design Spec v1.0 is resolved in v1.1: `CadenceTerracotta` is `#D4896A` in dark mode (bumped from `#C07050`) and `CadenceSage` is `#8FB08F` in dark mode (bumped from `#7A9B7A`). These resolved values must be used -- never the v1.0 values.

**Known blocker:** `CadencePrimary` is referenced in Design Spec §7 (paused sharing strip background) but is absent from §3 (color table). Do not add a placeholder `CadencePrimary.colorset` -- it is blocked pending designer confirmation and is explicitly excluded from Phase 0 scope.

**Source references that define scope:**

- Design Spec v1.1 §3 (complete color token table with light/dark hex values)
- cadence-xcode-project skill §5.1 (Colors.xcassets complete token registry and hex-to-decimal conversion table)
- cadence-xcode-project skill §6.1 (color asset Contents.json format)
- PHASES.md Phase 0 in-scope: "all 10 design system color assets in Colors.xcassets (including both light and dark values)"

## Scope

### In Scope

- `Cadence/Resources/Colors.xcassets/` directory with a catalog-root `Contents.json`
- 10 named colorsets, one per design token:
  1. `CadenceBackground.colorset` -- `#F5EFE8` light / `#1C1410` dark
  2. `CadenceCard.colorset` -- `#FFFFFF` light / `#2A1F18` dark
  3. `CadenceTerracotta.colorset` -- `#C07050` light / `#D4896A` dark
  4. `CadenceSage.colorset` -- `#7A9B7A` light / `#8FB08F` dark
  5. `CadenceSageLight.colorset` -- `#EAF0EA` light / `#1E2B1E` dark
  6. `CadenceTextPrimary.colorset` -- `#1C1C1E` light / `#F2EDE7` dark
  7. `CadenceTextSecondary.colorset` -- `#6C6C70` light / `#98989D` dark
  8. `CadenceTextOnAccent.colorset` -- `#FFFFFF` light / `#FFFFFF` dark
  9. `CadenceBorder.colorset` -- `#E0D8CF` light / `#3A2E26` dark
  10. `CadenceDestructive.colorset` -- system red reference (no RGB components)
- All colorset `Contents.json` files use decimal component strings in the `0.000`--`1.000` range, `color-space: srgb`, `idiom: universal`, `alpha: 1.000`
- `CadenceDestructive.colorset/Contents.json` uses the `platform: ios, reference: systemRed` format (no RGB components)
- Each colorset has exactly two color entries: one with no `appearances` key (any/light) and one with `"appearance": "luminosity", "value": "dark"`

### Out of Scope

- `CadencePrimary.colorset` -- blocked pending designer confirmation; do not add even as a placeholder
- `CadenceMark` colorset -- not listed in Design Spec §3; deferred to Phase 2 if needed for splash rendering
- Image assets of any kind (no PNGs, no image sets in `Colors.xcassets`)
- Swift source files referencing the color tokens (Phase 2+ concern)
- Color usage validation in rendered UI (no UI exists in Phase 0)

## Dependencies

| Dependency                                             | Type | Phase/Epic | Status | Risk                                                                    |
| ------------------------------------------------------ | ---- | ---------- | ------ | ----------------------------------------------------------------------- |
| PH-0-E1 (Cadence/Resources/ directory and project.yml) | FS   | PH-0-E1    | Open   | Low -- E1 creates the Resources/ parent directory and project structure |

## Assumptions

- All hex values in Design Spec v1.1 §3 are final and locked. The v1.1 dark-mode terracotta and sage corrections are intentional and must not be reverted to v1.0 values.
- Decimal conversions from cadence-xcode-project skill §5.1 are correct. Spot-check: `#C07050` = R:0.753, G:0.439, B:0.314. Verify one value manually before batch-writing all tokens.
- `CadenceTextOnAccent` is `#FFFFFF` in both light and dark mode -- this is intentional. The token is always white text on terracotta fills. Do not apply a dark-mode inversion.
- `CadenceDestructive` uses iOS system red semantics -- it must not be defined as RGB components. Doing so breaks semantic color expectations and prevents the system from applying appropriate accessibility adjustments.

## Risks

| Risk                                                                                      | Likelihood | Impact | Mitigation                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Decimal rounding error in a component value                                               | Low        | Medium | Use the cadence-xcode-project skill §5.1 hex-to-decimal table as the authoritative source. Verify spot-check: divide each hex byte by 255 to 3 decimal places.                                         |
| `CadenceDestructive` incorrectly authored with RGB components instead of system reference | Low        | High   | System red must use the reference format. If authored with RGB, the color will not adapt to high-contrast accessibility modes and will fail accessibility review in Phase 13.                          |
| Extra colorset added beyond the 10-token set (e.g., a placeholder CadencePrimary)         | Low        | High   | Any colorset not in the 10-token list is a governance violation. The `no-hex-in-swift` hook and cadence-design-system skill enforcement will catch usage, but the asset must not be introduced at all. |

---

## Stories

### S1: Create Colors.xcassets directory and catalog root

**Story ID:** PH-0-E2-S1
**Points:** 1

Create the `Cadence/Resources/Colors.xcassets/` directory and its catalog-root `Contents.json`. This is the container that Xcode recognizes as an asset catalog -- the root `Contents.json` must exist before any colorset directories are added.

**Acceptance Criteria:**

- [ ] `Cadence/Resources/Colors.xcassets/Contents.json` exists with exactly `{"info": {"author": "xcode", "version": 1}}`
- [ ] No image assets, imageset directories, or appiconset directories exist inside `Colors.xcassets`
- [ ] `Cadence/Resources/Colors.xcassets/` contains no colorset directories yet (this story creates only the catalog root)
- [ ] Xcode does not emit an asset catalog parse error when `xcodebuild build` is run after this directory is created

**Dependencies:** PH-0-E1 (the `Cadence/Resources/` parent directory must exist)

---

### S2: Add CadenceBackground and CadenceCard color sets

**Story ID:** PH-0-E2-S2
**Points:** 2

Create `CadenceBackground.colorset` and `CadenceCard.colorset` inside `Colors.xcassets`, each with a `Contents.json` containing correct light-mode and dark-mode color component entries in decimal format.

**Acceptance Criteria:**

- [ ] `Colors.xcassets/CadenceBackground.colorset/Contents.json` exists with two color entries:
  - Any/light entry: R:0.961, G:0.937, B:0.910, A:1.000, color-space:srgb, idiom:universal, no appearances key
  - Dark entry: R:0.110, G:0.078, B:0.063, A:1.000, color-space:srgb, idiom:universal, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceCard.colorset/Contents.json` exists with two color entries:
  - Any/light entry: R:1.000, G:1.000, B:1.000, A:1.000, color-space:srgb, idiom:universal
  - Dark entry: R:0.165, G:0.122, B:0.094, A:1.000, color-space:srgb, idiom:universal, appearances:[{appearance:luminosity, value:dark}]
- [ ] Both `Contents.json` files contain `"info": {"author": "xcode", "version": 1}`
- [ ] No hex string values appear in either `Contents.json` (all values are decimal strings: `"0.961"`, not `"0xF5"`)

**Dependencies:** PH-0-E2-S1

---

### S3: Add CadenceTerracotta, CadenceSage, and CadenceSageLight color sets

**Story ID:** PH-0-E2-S3
**Points:** 2

Create the three accent and surface color sets. `CadenceTerracotta` and `CadenceSage` use the v1.1 dark-mode corrected values. This is the most error-prone batch because v1.0 values must not be used.

**Acceptance Criteria:**

- [ ] `Colors.xcassets/CadenceTerracotta.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.753, G:0.439, B:0.314, A:1.000, color-space:srgb
  - Dark: R:0.831, G:0.537, B:0.416, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceSage.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.478, G:0.608, B:0.478, A:1.000, color-space:srgb
  - Dark: R:0.561, G:0.690, B:0.561, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceSageLight.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.918, G:0.941, B:0.918, A:1.000, color-space:srgb
  - Dark: R:0.118, G:0.169, B:0.118, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] No colorset in this story uses the v1.0 dark-mode terracotta value (R:0.753, G:0.439, B:0.314) for the dark entry -- v1.1 dark value (R:0.831) is the required value
- [ ] All three `Contents.json` files contain `"info": {"author": "xcode", "version": 1}`

**Dependencies:** PH-0-E2-S1

**Notes:** The v1.1 correction to `CadenceTerracotta` dark mode (from `#C07050` to `#D4896A`) is a ~15% luminance increase to meet WCAG AA against `#1C1410` (the dark `CadenceBackground`). Using the v1.0 value is a contrast failure. Design Spec v1.1 §3 "Dark Mode Contrast Notes" documents this explicitly.

---

### S4: Add CadenceTextPrimary, CadenceTextSecondary, and CadenceTextOnAccent color sets

**Story ID:** PH-0-E2-S4
**Points:** 2

Create the three text color sets. `CadenceTextOnAccent` is `#FFFFFF` in both light and dark mode -- this is intentional and must not be modified to an adaptive value.

**Acceptance Criteria:**

- [ ] `Colors.xcassets/CadenceTextPrimary.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.110, G:0.110, B:0.118, A:1.000, color-space:srgb
  - Dark: R:0.949, G:0.929, B:0.906, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceTextSecondary.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.424, G:0.424, B:0.439, A:1.000, color-space:srgb
  - Dark: R:0.596, G:0.596, B:0.616, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceTextOnAccent.colorset/Contents.json` exists with two color entries, both with R:1.000, G:1.000, B:1.000, A:1.000 -- the dark entry has the appearances key, but the color value is identical to the light entry
- [ ] All three `Contents.json` files contain `"info": {"author": "xcode", "version": 1}`
- [ ] `CadenceTextOnAccent` has no dynamic component variation between light and dark -- it is always pure white

**Dependencies:** PH-0-E2-S1

---

### S5: Add CadenceBorder and CadenceDestructive color sets

**Story ID:** PH-0-E2-S5
**Points:** 2

Create `CadenceBorder.colorset` with RGB decimal components and `CadenceDestructive.colorset` using the iOS system color reference format. These are the final two tokens completing the 10-token set.

**Acceptance Criteria:**

- [ ] `Colors.xcassets/CadenceBorder.colorset/Contents.json` exists with two color entries:
  - Any/light: R:0.878, G:0.847, B:0.812, A:1.000, color-space:srgb
  - Dark: R:0.227, G:0.180, B:0.149, A:1.000, color-space:srgb, appearances:[{appearance:luminosity, value:dark}]
- [ ] `Colors.xcassets/CadenceDestructive.colorset/Contents.json` exists with a single color entry using the reference format: `{"color": {"platform": "ios", "reference": "systemRed"}, "idiom": "universal"}` -- no RGB component values
- [ ] `CadenceDestructive.colorset/Contents.json` contains `"info": {"author": "xcode", "version": 1}`
- [ ] `Colors.xcassets` now contains exactly 10 colorset directories: CadenceBackground, CadenceCard, CadenceTerracotta, CadenceSage, CadenceSageLight, CadenceTextPrimary, CadenceTextSecondary, CadenceTextOnAccent, CadenceBorder, CadenceDestructive -- no others
- [ ] No colorset named `CadencePrimary` exists anywhere in `Colors.xcassets`

**Dependencies:** PH-0-E2-S1

**Notes:** `CadenceDestructive` uses `"systemRed"` as a semantic color reference rather than RGB values. This ensures the color adapts to high-contrast and accessibility modes. The cadence-xcode-project skill §6.1 provides the exact JSON format. There is no light/dark variant entry for `CadenceDestructive` -- system colors handle adaptation internally.

---

### S6: Validate all 10 color sets in Xcode asset catalog viewer

**Story ID:** PH-0-E2-S6
**Points:** 1

Open the populated `Colors.xcassets` in Xcode's asset catalog editor and verify that each colorset displays the correct colors in both Any Appearance and Dark Appearance previews. This catches `Contents.json` format errors that are not caught by a build-only verification.

**Acceptance Criteria:**

- [ ] `xcodebuild build -scheme Cadence` exits 0 after all 10 colorsets are present (confirms no asset catalog parse errors)
- [ ] Opening `Colors.xcassets` in Xcode's asset catalog editor shows exactly 10 color sets with no warning icons
- [ ] Toggling the Xcode canvas appearance to Dark in the asset editor shows visually distinct dark values for all tokens that have different light/dark values (CadenceBackground, CadenceCard, CadenceTerracotta, CadenceSage, CadenceSageLight, CadenceTextPrimary, CadenceTextSecondary, CadenceBorder)
- [ ] `CadenceTextOnAccent` shows identical white in both appearances in the Xcode editor
- [ ] `CadenceDestructive` shows a system red swatch with an "S" indicator (system color) in the Xcode editor
- [ ] No `.DS_Store` files or non-colorset files exist inside `Colors.xcassets` at commit time

**Dependencies:** PH-0-E2-S2, PH-0-E2-S3, PH-0-E2-S4, PH-0-E2-S5

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

- [ ] All six stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] `Colors.xcassets` contains exactly 10 colorsets and no other assets
- [ ] `CadencePrimary.colorset` does not exist
- [ ] All colorset `Contents.json` files use decimal string components (no hex strings)
- [ ] `CadenceDestructive.colorset` uses the system color reference format, not RGB components
- [ ] `xcodebuild build -scheme Cadence` exits 0 after all 10 colorsets are present
- [ ] Phase objective is advanced: all design token color assets are present and resolvable before any feature code is written
- [ ] cadence-xcode-project skill constraints satisfied: Colors.xcassets is the only place color values are defined; no color assets in Images.xcassets; all 10 tokens from §5.1 registry present; Contents.json format per §6.1
- [ ] cadence-design-system skill constraints satisfied: all 10 tokens from Design Spec v1.1 §3 are present with the correct v1.1 dark-mode values
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Source document alignment verified: all color values match Design Spec v1.1 §3 table exactly

## Source References

- PHASES.md: Phase 0 -- Project Foundation (in-scope: all 10 design system color assets in Colors.xcassets including both light and dark values; blocker: CadencePrimary excluded)
- Design Spec v1.1 §3 (color system: complete token table with light/dark hex values and dark-mode contrast notes)
- cadence-xcode-project skill §5 (asset catalog governance: Colors.xcassets is the only place colors are defined)
- cadence-xcode-project skill §5.1 (Colors.xcassets complete token registry with hex-to-decimal conversion table)
- cadence-xcode-project skill §6.1 (color asset Contents.json format: decimal components, two-entry requirement, system color reference format for CadenceDestructive)
