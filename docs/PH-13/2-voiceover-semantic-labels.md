# VoiceOver Semantic Labels

**Epic ID:** PH-13-E2
**Phase:** 13 -- Accessibility Compliance
**Estimated Size:** M
**Status:** Draft

---

## Objective

Apply correct `accessibilityLabel`, `accessibilityHint`, and accessibility trait configurations to every interactive and informational element across all Cadence screens, ensuring VoiceOver users receive accurate, complete, and contextually meaningful announcements for every element the app presents.

## Problem / Context

Design Spec v1.1 §14 specifies exact VoiceOver label formats for SymptomChips, the Sex chip lock icon, and other components. The cadence-accessibility skill §3 extends these requirements to flow chips, period toggle buttons, calendar day cells, Log Sheet elements, and Auth screen controls. During feature phases, VoiceOver labeling was deferred to this dedicated audit pass. Without correct labels, VoiceOver users cannot distinguish chip selection state, cannot understand calendar day meaning, and are not informed of the Sex chip's privacy significance. These are not cosmetic gaps -- they are functional failures for blind and low-vision users.

Sources: Design Spec v1.1 §14 (symptom chip format, Sex chip lock icon label, colorblind safety); cadence-accessibility skill §3 (chip labels, flow chips, period toggles), §7 (Auth screen, Calendar view, Log Sheet screen-level VoiceOver requirements); PHASES.md Phase 13 in-scope list.

## Scope

### In Scope

- `accessibilityLabel` on all SymptomChip instances: `"{symptom.displayName}, {selected/unselected}"`
- `accessibilityAddTraits(.isSelected)` on active SymptomChips
- `accessibilityRemoveTraits(.isButton)` on `isReadOnly` SymptomChip instances
- `accessibilityLabel` on all FlowChip instances: `"{flowLevel.displayName}, {selected/unselected}"`
- `accessibilityLabel` on "Period started" and "Period ended" buttons matching visible label text (no selected/unselected suffix -- these are action triggers, not toggle state)
- `accessibilityLabel("Private - not shared with partner")` on the Sex chip `lock.fill` icon; icon must NOT be `.accessibilityHidden(true)`
- Calendar day cell `accessibilityLabel` for all 6 states: period day, predicted period, fertile window, ovulation day, private day, today
- Log Sheet `accessibilityLabel("Notes")` + `accessibilityHint("Optional, anything else worth noting")` on the notes textarea
- Log Sheet privacy toggle label "Keep this day private" matches visible label; system toggle announces on/off state
- Log Sheet Save CTA `accessibilityLabel("Save log")`
- Auth screen Google Sign In button `accessibilityLabel("Sign in with Google")` if the SDK button does not expose its own label
- Auth screen password show/hide toggle `accessibilityLabel` reflecting current state: "Show password" or "Hide password"
- Partner Bento grid cell labels: Phase card, Countdown card, Symptoms card, Notes card each have descriptive `accessibilityLabel` values
- `performAccessibilityAudit(for: .sufficientElementDescription)` sweep across all audited screens

### Out of Scope

- `accessibilityHint` additions beyond those specified in the cadence-accessibility skill §7 (no speculative UX additions)
- VoiceOver announcements for network or sync state changes (not a spec requirement in Phase 13)
- Custom VoiceOver rotor actions (post-beta scope)
- Navigation bar title VoiceOver behavior (system-managed by NavigationStack -- not overridden)

## Dependencies

| Dependency                                                                                                  | Type | Phase/Epic         | Status | Risk |
| ----------------------------------------------------------------------------------------------------------- | ---- | ------------------ | ------ | ---- |
| All UI phases complete -- all chip, calendar, Log Sheet, auth, and Partner Dashboard components implemented | FS   | PH-0 through PH-12 | Open   | Low  |
| SymptomChip, FlowChip, SymptomType enum implemented with displayName                                        | FS   | PH-4-E3            | Open   | Low  |
| Calendar day cell views implemented                                                                         | FS   | PH-6-E1            | Open   | Low  |
| Log Sheet implemented with notes, privacy toggle, Save CTA                                                  | FS   | PH-4-E2            | Open   | Low  |
| Partner Bento grid cards implemented                                                                        | FS   | PH-9-E2            | Open   | Low  |
| Auth screen implemented                                                                                     | FS   | PH-2-E2            | Open   | Low  |

## Assumptions

- `SymptomType.displayName` is a computed property on the `SymptomType` enum returning the human-readable name for each case (e.g., `.cramps` -> `"Cramps"`). This property must exist and be used for `accessibilityLabel` construction -- it must not be hardcoded.
- The Sex chip is a SymptomChip with `symptomType == .sex`. The lock icon is a decorative affordance rendered inside the chip in addition to the chip label. Both the chip itself (via S1 label) and the lock icon (via S3 label) require independent accessibility treatment.
- Calendar day cells use a `date: Date` parameter to construct `accessibilityLabel` strings with localized date formatting via `DateFormatter` with `dateStyle: .full, timeStyle: .none`.
- Partner Bento cells in a "Sharing paused" state must carry a label indicating the card is unavailable (e.g., `"Phase data, unavailable - sharing paused"`), not the stale last-seen data.
- The `isReadOnly` trait removal on SymptomChips applies only where chips are explicitly rendered in a non-interactive context. The `SymptomChip` component must expose an `isReadOnly: Bool` parameter that toggles trait removal.

## Risks

| Risk                                                                                          | Likelihood | Impact | Mitigation                                                                                                                                                            |
| --------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SymptomType.displayName` does not exist -- labels must be hardcoded                          | Low        | Medium | Check the PH-4 Swift source before writing label construction; if displayName is missing, add it to the enum as part of this story's remediation.                     |
| Google Sign In SDK button exposes its own accessibilityLabel that conflicts with the override | Medium     | Low    | Query the button's existing label via Accessibility Inspector before overriding. If the SDK label is already "Sign in with Google", the override is a no-op.          |
| VoiceOver traversal order on Partner Bento grid is wrong (reads cells in incorrect sequence)  | Medium     | Medium | Apply `.accessibilitySortPriority(_:)` to force reading order: Phase -> Countdown -> Symptoms -> Notes. Test on-device with VoiceOver enabled.                        |
| Period day cell label does not include the date string, making it indistinguishable           | High       | High   | Verify the existing calendar cell implementation includes the date in its label. If not, this is a remediation (new label construction logic added to the cell view). |

---

## Stories

### S1: SymptomChip and FlowChip accessibilityLabel and Trait Enforcement

**Story ID:** PH-13-E2-S1
**Points:** 3

Apply the spec-defined `accessibilityLabel` format and trait configuration to all interactive SymptomChip and FlowChip instances. Ensure that `isReadOnly` chips remove the `.isButton` trait so VoiceOver does not announce them as activatable. Verify on-device with VoiceOver that toggling a chip causes VoiceOver to announce the updated label.

**Acceptance Criteria:**

- [ ] Every interactive SymptomChip has `.accessibilityLabel("\(symptom.displayName), \(isActive ? "selected" : "unselected")")` applied -- label uses the enum's `displayName` property, not a hardcoded string
- [ ] Active SymptomChips have `.accessibilityAddTraits(.isSelected)` applied
- [ ] Inactive SymptomChips do not carry `.isSelected` trait
- [ ] SymptomChip instances where `isReadOnly == true` have `.accessibilityRemoveTraits(.isButton)` applied so VoiceOver announces them without an action affordance
- [ ] Every interactive FlowChip has `.accessibilityLabel("\(flowLevel.displayName), \(isSelected ? "selected" : "unselected")")` applied
- [ ] After toggling any SymptomChip or FlowChip with VoiceOver enabled on a physical device or Simulator, VoiceOver announces the updated label (e.g., "Cramps, selected" then "Cramps, unselected" on second tap)
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** None
**Notes:** Do not add `accessibilityHint` to chips -- the cadence-accessibility skill §3 explicitly states VoiceOver's announcement of the new `accessibilityLabel` on state change is sufficient. No hint needed for the toggle action.

---

### S2: Period Toggle Button Labels

**Story ID:** PH-13-E2-S2
**Points:** 2

Apply `accessibilityLabel` to the "Period started" and "Period ended" period toggle buttons in the Log Sheet. These are action triggers (they fire an event) rather than toggles (they do not cycle between on/off states), so the label must match the visible button text with no `{selected/unselected}` suffix.

**Acceptance Criteria:**

- [ ] "Period started" button has `accessibilityLabel("Period started")` -- label matches the visible text exactly
- [ ] "Period ended" button has `accessibilityLabel("Period ended")` -- label matches the visible text exactly
- [ ] Neither period toggle button carries a `{selected/unselected}` suffix, consistent with the cadence-accessibility skill §3 guidance that these are action triggers, not toggle state
- [ ] VoiceOver on-device announces "Period started, button" when focused on the first button and "Period ended, button" when focused on the second -- the `.isButton` trait is present (these are interactive)
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** None

---

### S3: Sex Chip Lock Icon accessibilityLabel

**Story ID:** PH-13-E2-S3
**Points:** 2

Apply the spec-mandated `accessibilityLabel("Private - not shared with partner")` to the `lock.fill` SF Symbol rendered inside the Sex chip. Confirm the icon is NOT hidden from VoiceOver. Verify on-device that VoiceOver announces the lock icon as a distinct element within the Sex chip traversal.

**Acceptance Criteria:**

- [ ] The `lock.fill` Image inside the Sex chip has `.accessibilityLabel("Private - not shared with partner")` applied
- [ ] The lock icon does NOT have `.accessibilityHidden(true)` -- the icon's privacy meaning is functional, not decorative
- [ ] VoiceOver on-device, when the Sex chip receives focus, announces the chip's own label followed by the lock icon label in traversal order
- [ ] The lock icon's label is static and does not change based on chip selection state -- the privacy meaning is unconditional for the Sex chip
- [ ] No other chip in the app carries this lock icon label; the implementation is scoped to the Sex chip variant only
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-13-E2-S1
**Notes:** Per cadence-accessibility skill §3, the lock icon is NOT `.accessibilityHidden(true)`. If the existing implementation has `accessibilityHidden(true)` on this icon, removing it is a correctness fix, not a feature addition.

---

### S4: Calendar Day Cell accessibilityLabels

**Story ID:** PH-13-E2-S4
**Points:** 3

Apply descriptive `accessibilityLabel` strings to all 6 calendar day cell states so VoiceOver users understand the meaning of each date without relying on color or fill pattern. Label strings include the date and the cycle state. The today indicator uses Apple's system rendering and must not be overridden.

**Acceptance Criteria:**

- [ ] Logged period day cell: `accessibilityLabel("Period day, \(date.formatted(date: .long, time: .omitted))")` -- example: "Period day, January 15, 2026"
- [ ] Predicted period day cell: `accessibilityLabel("Predicted period, \(date.formatted(date: .long, time: .omitted))")` -- example: "Predicted period, January 28, 2026"
- [ ] Fertile window day cell: `accessibilityLabel("Fertile window, \(date.formatted(date: .long, time: .omitted))")` -- example: "Fertile window, January 18, 2026"
- [ ] Ovulation day cell: `accessibilityLabel("Ovulation day, \(date.formatted(date: .long, time: .omitted))")` -- example: "Ovulation day, January 19, 2026"
- [ ] Private day cell (where `isPrivate == true` on the DailyLog): `accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), private")` -- example: "January 20, 2026, private"
- [ ] Today indicator: system-provided -- no `accessibilityLabel` override; this is documented as verified
- [ ] Empty/unlogged day cell: `accessibilityLabel("\(date.formatted(date: .long, time: .omitted))")` with no state suffix
- [ ] VoiceOver traversal of the month grid reads cells in left-to-right, top-to-bottom order (Sunday through Saturday per locale)
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** None
**Notes:** Use `date.formatted(date: .long, time: .omitted)` (Swift `FormatStyle`) rather than `DateFormatter` for locale-correct output. A day cell can overlap states (e.g., a logged period day within a fertile window) -- define priority ordering for the label: period logged > fertile window > ovulation > predicted > private > empty. Apply only the highest-priority label to avoid a compound announcement.

---

### S5: Log Sheet VoiceOver Labels

**Story ID:** PH-13-E2-S5
**Points:** 3

Apply the spec-defined `accessibilityLabel` and `accessibilityHint` to the Log Sheet notes textarea, privacy toggle, and Save CTA. Verify that the system Toggle for the privacy row announces the correct label text and that its on/off state changes are announced automatically by the system toggle component.

**Acceptance Criteria:**

- [ ] Notes `TextEditor` or `TextField` has `.accessibilityLabel("Notes")` and `.accessibilityHint("Optional, anything else worth noting")` applied
- [ ] The "Keep this day private" toggle row label matches the visible label text exactly; the system Toggle announces its state as "on" or "off" automatically -- no additional `accessibilityValue` override needed
- [ ] The Save CTA has `.accessibilityLabel("Save log")` applied
- [ ] VoiceOver traversal of the Log Sheet in `.medium` detent reads elements top-to-bottom: date header, period toggles (in order: started/ended), flow chips, symptom chips, notes field, privacy toggle, Save CTA
- [ ] After Save is tapped with VoiceOver active, VoiceOver receives the state change (Log Sheet dismisses) -- no additional post-save announcement is specified; the sheet dismiss is the confirmation
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-13-E2-S1, PH-13-E2-S2
**Notes:** The cadence-accessibility skill §7 Log Sheet section defines these exact label and hint values. Do not deviate from the exact strings specified.

---

### S6: Auth Screen and Partner Bento Grid VoiceOver

**Story ID:** PH-13-E2-S6
**Points:** 3

Apply VoiceOver labels to the Auth screen Google Sign In button and password show/hide toggle, and to all four Partner Bento grid card cells. Also run `performAccessibilityAudit(for: .sufficientElementDescription)` across all audited screens to catch any remaining elements with empty or inadequate labels.

**Acceptance Criteria:**

- [ ] Auth screen Google Sign In button: if the Google SDK button does not expose `accessibilityLabel("Sign in with Google")` by default, apply it explicitly; confirmed by Accessibility Inspector showing the label on the button element
- [ ] Auth screen password show/hide toggle: `accessibilityLabel` reads "Show password" when the field is obscured and "Hide password" when the field is revealed; the label updates dynamically as the user toggles
- [ ] Partner Bento Phase card has `accessibilityLabel("Cycle phase, \(phaseName)")` -- example: "Cycle phase, Luteal"
- [ ] Partner Bento Countdown card has `accessibilityLabel("Days until period, \(days)")` -- example: "Days until period, 8"
- [ ] Partner Bento Symptoms card has `accessibilityLabel("Symptoms, \(symptomList)")` where `symptomList` is a comma-separated list of active symptom display names -- example: "Symptoms, Cramps, Fatigue"
- [ ] Partner Bento Notes card has `accessibilityLabel("Notes, \(noteText)")` or `accessibilityLabel("Notes, no notes for today")` when empty
- [ ] When sharing is paused, each Partner Bento card has `accessibilityLabel("\(cardType), unavailable, sharing paused")` to communicate the unavailable state
- [ ] `performAccessibilityAudit(for: .sufficientElementDescription)` runs against Tracker Home, Log Sheet, Calendar, Auth, and Partner Dashboard; the audit produces zero unsuppressed violations
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-13-E2-S1, PH-13-E2-S3, PH-13-E2-S4, PH-13-E2-S5
**Notes:** `performAccessibilityAudit(for: .sufficientElementDescription)` catches elements whose `accessibilityLabel` is empty, nil, or set to a raw accessibility identifier string. Run it in `AccessibilityLabelAuditTests` under `CadenceTests/Accessibility/`. Suppressions (if any) must be documented with an inline comment. The Partner Bento label strings for Symptoms are constructed by joining `symptom.displayName` values with ", "; the sex symptom is excluded because the Partner view enforces this exclusion at the data layer.

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
- [ ] VoiceOver enabled on-device (or Simulator with VoiceOver) traverses all audited screens and announces correct, meaningful labels for every element
- [ ] `performAccessibilityAudit(for: .sufficientElementDescription)` passes with zero unsuppressed violations across all audited screens
- [ ] Phase objective is advanced: VoiceOver labels correct on all chips and icons, per the phase completion standard
- [ ] Applicable skill constraints satisfied: cadence-accessibility §3 (chip labels, flow chips, period toggles, Sex chip lock icon), §7 (Auth screen, Calendar view, Log Sheet screen-level requirements), §9 (Accessibility Labels checklist section), cadence-privacy-architecture (sex symptom excluded from Partner Bento label construction)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: label strings match Design Spec v1.1 §14 exactly; no label text invented without spec backing

## Source References

- PHASES.md: Phase 13 -- Accessibility Compliance (in-scope: VoiceOver accessibilityLabel on all SymptomChips "{symptom name}, {selected/unselected}"; Sex chip lock icon "Private - not shared with partner")
- Design Spec v1.1 §14 (Accessibility -- VoiceOver symptom chip format, Sex chip lock icon label)
- cadence-accessibility skill §3 (Accessibility Labels -- Chips: SymptomChip format, Sex chip lock icon, FlowChip pattern, Period toggle buttons)
- cadence-accessibility skill §7 (VoiceOver -- Auth screen, Calendar view, Log Sheet screen-level requirements)
- cadence-accessibility skill §9 (Screen Accessibility Checklist -- Accessibility Labels section)
- cadence-privacy-architecture skill (Sex symptom exclusion from Partner-facing data)
- Apple Developer Documentation: `accessibilityLabel(_:)`, `accessibilityAddTraits(_:)`, `accessibilityRemoveTraits(_:)`, `accessibilityHint(_:)`
