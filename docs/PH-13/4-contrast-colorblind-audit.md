# Contrast and Colorblind Audit

**Epic ID:** PH-13-E4
**Phase:** 13 -- Accessibility Compliance
**Estimated Size:** M
**Status:** Draft

---

## Objective

Verify that all color pairings in the Cadence app meet WCAG 2.2 Level AA contrast requirements in both light and dark mode through on-device measurement, confirm that period and fertile window states are visually differentiated by means other than color alone, and resolve the open CadencePrimary token gap that affects the sharing strip paused state.

## Problem / Context

Design Spec v1.1 §14 specifies four contrast pairs and declares them WCAG AA verified. §15 flags dark mode on-device verification as an open pre-TestFlight item. The cadence-accessibility skill §6 defines the exact token-to-ratio mapping and flags the CadencePrimary token gap as a known blocker: the sharing strip paused state references CadencePrimary (`#1C1410` light / `#F2EDE7` dark) but this token is not defined in §3 of the design spec's color table. Shipping without this confirmed means the highest-contrast affordance in the app -- the paused sharing strip -- could ship with an undefined color or a fallback that fails contrast.

The colorblind audit addresses the §14 requirement that terracotta and sage never be the sole visual differentiators between period and fertile window states. Period days use solid fill; fertile window uses a continuous band. Under Deuteranopia and Protanopia simulation, this differentiation must remain apparent.

WCAG 2.2 Level AA is the operative standard for 2026. WCAG 3.0 (APCA-based) remains a Working Draft and is not yet an accepted compliance target for App Store submission or legal accessibility requirements.

## Scope

### In Scope

- Light mode WCAG AA on-device audit: CadenceTerracotta (#C07050) on CadenceBackground (#F5EFE8) -- 4.5:1; CadenceTerracotta (#C07050) on CadenceCard (#FFFFFF) -- 4.5:1; CadenceSage (#7A9B7A) on CadenceSageLight (#EAF0EA) -- verified or flagged
- Dark mode WCAG AA on-device audit (§15 open item): CadenceTerracotta (#D4896A) on CadenceBackground (#1C1410); CadenceSage (#8FB08F) on CadenceBackground (#1C1410) -- both spec-declared AA compliant; confirmed on physical hardware or Simulator dark mode
- CadenceTextSecondary contrast verification: #6C6C70 (light) on #F5EFE8 -- at least 3:1 for non-text UI components; #98989D (dark) on #1C1410 -- at least 3:1; note that secondary text used as body copy requires 4.5:1 -- audit usage context
- Colorblind differentiation audit: period solid fill vs. fertile window continuous band differentiated under Protanopia and Deuteranopia simulation in Xcode Accessibility Inspector Color Filters
- CadencePrimary paused strip token confirmation and contrast verification: confirm token values with Dinesh, add to xcassets if missing, verify contrast of strip background against strip text/iconography
- `performAccessibilityAudit(for: .contrast)` sweep against all audited screens as a final verification gate

### Out of Scope

- Non-Cadence color pairs (system colors applied by SwiftUI, system Toggle, system navigation bar -- Apple owns their contrast compliance)
- WCAG AAA compliance (7:1 normal text, 4.5:1 large text) -- not a Cadence requirement
- APCA / WCAG 3.0 compliance evaluation -- WCAG 3.0 is not a Recommendation as of 2026
- Dark mode contrast on physical device models not available to Dinesh -- Simulator dark mode is the minimum required; hardware verification is advisory

## Dependencies

| Dependency                                                                                                                                                                                       | Type     | Phase/Epic | Status | Risk   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ---------- | ------ | ------ |
| All color token xcassets defined: CadenceBackground, CadenceCard, CadenceTerracotta, CadenceSage, CadenceSageLight, CadenceTextPrimary, CadenceTextSecondary, CadenceTextOnAccent, CadenceBorder | FS       | PH-0-E2    | Open   | Low    |
| Sharing strip paused state implemented                                                                                                                                                           | FS       | PH-5-E2    | Open   | Low    |
| Calendar period and fertile window visual states implemented                                                                                                                                     | FS       | PH-6-E1    | Open   | Low    |
| Partner Dashboard implemented                                                                                                                                                                    | FS       | PH-9-E1    | Open   | Low    |
| Designer or Dinesh confirms CadencePrimary token values for paused strip (known spec gap)                                                                                                        | External | N/A        | Open   | Medium |

## Assumptions

- The light mode contrast ratios declared in Design Spec v1.1 §14 (4.5:1 for CadenceTerracotta on Background and on white) are accurate. The on-device audit validates rather than re-derives these values.
- Dark mode contrast was declared resolved in Design Spec v1.1 §3 ("Dark Mode Contrast Notes"), which bumped Terracotta to #D4896A and Sage to #8FB08F. The §15 action item is to confirm these values hold on physical hardware under varying lighting conditions.
- CadenceSage (#7A9B7A) on CadenceSageLight (#EAF0EA) may fall below 4.5:1 for normal text -- the fertile window band uses CadenceSageLight as a background surface, not CadenceSage on CadenceSageLight for text. The relevant pair for text-on-surface is CadenceTextPrimary on CadenceSageLight, not Sage on SageLight. Confirm the actual text pair in use before labeling a violation.
- CadenceTextSecondary is used for metadata, timestamps, and placeholder text -- contexts where 3:1 minimum (SC 1.4.11 non-text contrast) applies for interactive components, while 4.5:1 applies if TextSecondary is used as the sole identifier of content in body copy. Audit by usage context.
- Colorblind differentiation does not require that period red and fertile green be perceptually identical under simulation -- it requires that the two states remain distinguishable by a property other than hue. Fill pattern (solid vs. band) satisfies this requirement.

## Risks

| Risk                                                                                                        | Likelihood | Impact | Mitigation                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CadencePrimary token not added to xcassets during Phase 5 (PH-5-E2 left the gap unresolved)                 | Medium     | High   | Check the Phase 5 xcassets implementation directly; if the token is absent, add it in this epic after designer confirmation of the values.                                                                                           |
| CadenceTextSecondary #6C6C70 fails 4.5:1 on CadenceBackground #F5EFE8 when used as body copy (not metadata) | Low        | High   | Audit actual usage context: if TextSecondary appears as primary body copy on any screen, it is a violation requiring text color remediation (switch to CadenceTextPrimary).                                                          |
| Dark mode audit on Simulator does not replicate hardware-specific display calibration differences           | Medium     | Low    | Document Simulator dark mode results; flag for hardware validation before TestFlight distribution (Phase 14).                                                                                                                        |
| CadencePrimary paused strip contrast cannot be confirmed without designer input                             | Medium     | High   | The token values are documented in the spec notes (#1C1410 light / #F2EDE7 dark). If Dinesh confirms these, the audit proceeds using those values. If the designer changes them, xcassets and contrast re-verification are required. |

---

## Stories

### S1: Light Mode WCAG AA On-Device Contrast Audit

**Story ID:** PH-13-E4-S1
**Points:** 3

Run on-device (or Simulator light mode) contrast measurements for all spec-defined Cadence color pairs using Xcode Accessibility Inspector Color Contrast Calculator or the Colour Contrast Analyser macOS app. Document each result. Flag any pair that fails 4.5:1 for normal text or 3:1 for large text / UI components. Remediate any violation by adjusting the xcassets color value with designer approval.

**Acceptance Criteria:**

- [ ] CadenceTerracotta (#C07050) on CadenceBackground (#F5EFE8) measured contrast ratio is >= 4.5:1; result documented (expected: 4.5:1 per spec)
- [ ] CadenceTerracotta (#C07050) on CadenceCard (#FFFFFF) measured contrast ratio is >= 4.5:1; result documented (expected: 4.5:1 per spec)
- [ ] CadenceSage (#7A9B7A) on CadenceSageLight (#EAF0EA): ratio measured and documented; if used as text on surface, must be >= 4.5:1 for normal text or >= 3:1 for large text; usage context confirmed before determining pass/fail
- [ ] CadenceTextPrimary (#1C1C1E) on CadenceBackground (#F5EFE8) measured ratio is >= 7:1 (expected; document result)
- [ ] CadenceTextSecondary (#6C6C70) on CadenceBackground (#F5EFE8) measured ratio documented; pass/fail determined by usage context (3:1 minimum for metadata/UI components, 4.5:1 if used as body copy)
- [ ] CadenceTextOnAccent (#FFFFFF) on CadenceTerracotta (#C07050) measured ratio documented for active chip and filled CTA text legibility (must be >= 4.5:1)
- [ ] All results recorded in a single audit document at `docs/PH-13/contrast-audit-results.md`; each row includes: foreground token and hex, background token and hex, measured ratio, threshold, pass/fail
- [ ] Any failing pair has a remediation applied (xcassets color value updated) and re-measured before this story is closed

**Dependencies:** None
**Notes:** Tool recommendation: Colour Contrast Analyser (macOS, free, TPGi) -- eyedropper mode picks hex values directly from the running Simulator. Xcode Accessibility Inspector also provides a Color Contrast Calculator in the Window menu. Both produce the same WCAG AA ratio; use whichever is faster. The `contrast-audit-results.md` file is a doc artifact, not a source file -- exempt from `protocol-zero.sh` and `check-em-dashes.sh` by file type.

---

### S2: Dark Mode WCAG AA On-Device Contrast Audit

**Story ID:** PH-13-E4-S2
**Points:** 3

Verify the dark mode color pairs defined in Design Spec v1.1 §3 using Simulator dark mode and, where possible, physical device. Dark mode Terracotta (#D4896A) and Sage (#8FB08F) were bumped from v1.0 specifically to meet WCAG AA against the dark background (#1C1410). This story confirms the bumped values hold on-device as the §15 open item requires.

**Acceptance Criteria:**

- [ ] CadenceTerracotta dark (#D4896A) on CadenceBackground dark (#1C1410) measured contrast ratio is >= 4.5:1 for normal text usage; result documented
- [ ] CadenceSage dark (#8FB08F) on CadenceBackground dark (#1C1410) measured contrast ratio is >= 4.5:1; result documented
- [ ] CadenceTextPrimary dark (#F2EDE7) on CadenceBackground dark (#1C1410) measured ratio documented (expected high -- informational)
- [ ] CadenceTextSecondary dark (#98989D) on CadenceBackground dark (#1C1410) ratio measured and classified by usage context; if the ratio falls below 3:1 on any interactive element, it is flagged and remediated
- [ ] CadenceTextOnAccent (#FFFFFF) on CadenceTerracotta dark (#D4896A) measured ratio documented for active chip and filled CTA legibility in dark mode
- [ ] All dark mode results appended to `docs/PH-13/contrast-audit-results.md` with a "Dark Mode" column label
- [ ] §15 open item is closed: the dark mode on-device audit result is documented, and if the values hold, the item is marked resolved; if any value fails, remediation and re-measurement complete before story closure
- [ ] If physical hardware verification is performed, the device model and iOS version are recorded

**Dependencies:** PH-13-E4-S1
**Notes:** Enable dark mode in Simulator via Device > Appearance > Dark (Xcode 14+) or via the Simulator's own Settings app. Use the same Colour Contrast Analyser eyedropper in dark mode -- verify the simulator is in dark mode before measuring. Physical hardware verification is recommended but not blocking -- document Simulator results as the minimum requirement and flag hardware verification for Phase 14 if Dinesh's device is not available during this pass.

---

### S3: CadenceTextSecondary Contrast Classification by Usage

**Story ID:** PH-13-E4-S3
**Points:** 2

Audit every usage of CadenceTextSecondary in the app to confirm it is applied only in contexts where the applicable contrast threshold is 3:1 (non-text UI component or large text), not 4.5:1 (normal text body copy). CadenceTextSecondary is specified for metadata, timestamps, subtitles, and placeholder text -- not primary body copy. Any screen where TextSecondary renders as the sole reading-critical text on a surface must be flagged.

**Acceptance Criteria:**

- [ ] All occurrences of `Color("CadenceTextSecondary")` (and any equivalent `CadenceTextSecondary` token usage) in the Swift codebase are enumerated (use Grep across `Cadence/` sources)
- [ ] Each occurrence is classified: metadata/secondary label (3:1 threshold applies) or primary informational text (4.5:1 threshold applies)
- [ ] Any occurrence where CadenceTextSecondary is used as the primary reading-critical content on a surface is remediating by switching to CadenceTextPrimary; change is minimal and scoped to the affected view only
- [ ] CadenceTextSecondary (#6C6C70 light) on CadenceBackground (#F5EFE8): measured ratio documented; classified against its actual usage context to determine WCAG threshold
- [ ] CadenceTextSecondary (#98989D dark) on CadenceBackground (#1C1410): measured ratio documented; classified against usage context
- [ ] The `scripts/protocol-zero.sh` and `scripts/check-em-dashes.sh` exit 0 on any modified Swift files
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS` if any Swift files are modified

**Dependencies:** PH-13-E4-S1, PH-13-E4-S2
**Notes:** WCAG 2.2 SC 1.4.3 (4.5:1 for normal text, 3:1 for large text) applies to text that users read as content. SC 1.4.11 (3:1 for non-text contrast) applies to UI component state indicators, boundaries, and graphical elements. CadenceTextSecondary on timestamps and eyebrow labels falls under 3:1 (non-essential metadata). CadenceTextSecondary as the only text on an insight card falls under 4.5:1 (it is body content). Classify per instance.

---

### S4: Colorblind Differentiation Audit

**Story ID:** PH-13-E4-S4
**Points:** 3

Simulate Protanopia and Deuteranopia in Xcode Accessibility Inspector to verify that the calendar's period (solid CadenceTerracotta fill) and fertile window (continuous CadenceSageLight band) visual states remain distinguishable by a property other than hue. The non-color differentiator is fill pattern: solid fill vs. background band. This story confirms that differentiator survives the two most common red-green deficiency simulations.

**Acceptance Criteria:**

- [ ] Xcode Accessibility Inspector Color Filters set to Deuteranopia: the Calendar view is screenshotted and inspected; period days (solid fill) and fertile window days (band, no fill) are visually distinguishable from each other by fill pattern alone, not hue
- [ ] Xcode Accessibility Inspector Color Filters set to Protanopia: same inspection performed; same pass criterion applies
- [ ] Ovulation day (CadenceSageLight fill with 1pt CadenceSage border) is distinguishable from both period days and fertile window days under both simulations
- [ ] No pure red/green color pair introduced in Phases 4-12 is present in the Calendar view or any other screen
- [ ] If any visual state is identified as color-only differentiated (no fill pattern, shape, or label difference), a remediation is applied: add an icon, pattern, or secondary shape cue to the affected state
- [ ] Audit result and screenshots (where taken) are appended to `docs/PH-13/contrast-audit-results.md` with simulation mode noted
- [ ] `scripts/protocol-zero.sh` exits 0 on any modified Swift files

**Dependencies:** PH-13-E4-S1
**Notes:** Enable Color Filters: Xcode > Open Developer Tool > Accessibility Inspector > Settings tab > Color Filters > select Deuteranopia or Protanopia. The simulator screen updates in real time. The fertile window's CadenceSageLight band is the key differentiator -- it spans the full calendar row height as a background behind date cells, which remains geometrically distinct from the period day solid fill even without color perception. Confirm this remains true visually.

---

### S5: CadencePrimary Paused Strip Token Confirmation and Contrast Verification

**Story ID:** PH-13-E4-S5
**Points:** 5

Resolve the known CadencePrimary token spec gap. The sharing strip paused state references CadencePrimary (`#1C1410` light / `#F2EDE7` dark) but this token is not defined in Design Spec v1.1 §3's color table. This story confirms the token values with Dinesh, adds the xcassets definition if it does not exist, and verifies the paused strip contrast ratio between the CadencePrimary background and the strip's text or iconography.

**Acceptance Criteria:**

- [ ] Dinesh has confirmed the CadencePrimary token values: `#1C1410` (light mode background) and `#F2EDE7` (dark mode background) -- confirmation is documented in `docs/PH-13/contrast-audit-results.md` with date and source
- [ ] If `CadencePrimary` does not exist in `Cadence/Assets.xcassets/Colors/`, it is added per the cadence-xcode-project skill's `Contents.json` format, with light value `#1C1410` and dark value `#F2EDE7`, and the project.yml is updated if required
- [ ] The sharing strip paused state implementation references `Color("CadencePrimary")` -- no hardcoded hex value in Swift source; the `no-hex-in-swift` hook exits 0
- [ ] The contrast ratio of any text or icon rendered on the CadencePrimary surface in the paused strip is measured: text on `#1C1410` (light) and text on `#F2EDE7` (dark); documented in `docs/PH-13/contrast-audit-results.md`
- [ ] The measured contrast ratio meets WCAG AA (>= 4.5:1 for normal text, >= 3:1 for large text / UI components)
- [ ] If the contrast fails, remediation is applied (text color adjusted to meet threshold) before story closure
- [ ] `xcodegen generate` succeeds after any xcassets or project.yml changes
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0

**Dependencies:** PH-13-E4-S1, PH-13-E4-S2
**Notes:** The CadencePrimary token gap is documented in the cadence-design-system skill and cadence-accessibility skill §6. The design spec §7 provides the hex values in the Elevation & Surfaces table row for the sharing strip paused state. These values (#1C1410 light / #F2EDE7 dark) are the starting point. Dinesh's confirmation closes the spec gap formally. If the Phase 5 PH-5-E2 implementation already added CadencePrimary to xcassets, this story verifies the existing definition is correct and tests contrast -- it is not necessarily a new file creation.

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
- [ ] `docs/PH-13/contrast-audit-results.md` exists and documents every measured contrast pair, its ratio, the applicable WCAG threshold, and its pass/fail result
- [ ] All spec-declared WCAG AA pairs confirmed on-device or in Simulator: Terracotta on Background (light), Terracotta on white (light), Terracotta on Background (dark), Sage on Background (dark)
- [ ] §15 open item resolved: dark mode on-device audit documented and closed
- [ ] CadencePrimary token gap resolved: token exists in xcassets, values confirmed with Dinesh, contrast verified
- [ ] Colorblind audit documented: calendar period vs. fertile window remains distinguishable under Deuteranopia and Protanopia simulation
- [ ] Phase objective is advanced: WCAG AA contrast verified on device in both light and dark mode
- [ ] Applicable skill constraints satisfied: cadence-accessibility §6 (WCAG AA contrast -- Cadence-specific ratios, CadencePrimary paused strip note, colorblind safety), cadence-xcode-project (xcassets Contents.json format for any new token), cadence-design-system (no hardcoded hex in Swift, token-only references)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] No hex literals in any modified Swift source file (enforced by `no-hex-in-swift` hook)
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 13 -- Accessibility Compliance (in-scope: WCAG AA contrast on-device audit CadenceTerracotta on CadenceBackground and on white, dark mode values; colorblind audit period vs. fertile window fill differentiation; dark mode contrast audit §15 open item)
- Design Spec v1.1 §3 (Color System -- all 10 token definitions, dark mode contrast notes bumping Terracotta to #D4896A and Sage to #8FB08F)
- Design Spec v1.1 §7 (Elevation & Surfaces -- CadencePrimary paused strip: #1C1410 light / #F2EDE7 dark)
- Design Spec v1.1 §14 (Accessibility -- contrast: CadenceTerracotta on #F5EFE8 passes 4.5:1; on #FFFFFF passes 4.5:1; dark mode verified at definition; colorblind: fill type and band type differentiation)
- Design Spec v1.1 §15 (Open Items -- dark mode contrast audit on device: pre-TestFlight)
- cadence-accessibility skill §6 (WCAG AA Contrast -- spec-verified contrast pairs table, CadenceTextSecondary 3:1 minimum, CadencePrimary paused strip gap, colorblind safety rules)
- cadence-design-system skill (color token enforcement, no hardcoded hex)
- cadence-xcode-project skill (xcassets Contents.json format for color tokens)
- WCAG 2.2 SC 1.4.3 (Contrast Minimum -- AA: 4.5:1 normal text, 3:1 large text)
- WCAG 2.2 SC 1.4.11 (Non-text Contrast -- AA: 3:1 for UI components and graphical objects)
