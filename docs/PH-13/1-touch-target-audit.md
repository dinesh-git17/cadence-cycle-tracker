# Touch Target Audit and Remediation

**Epic ID:** PH-13-E1
**Phase:** 13 -- Accessibility Compliance
**Estimated Size:** M
**Status:** Draft

---

## Objective

Verify that every interactive element across all implemented Cadence screens meets the 44x44pt minimum tappable area requirement defined in Design Spec v1.1 §14, and remediate any violations found. This epic produces no new features -- its output is a clean `performAccessibilityAudit(for: .hitRegion)` result on every screen the app ships with.

## Problem / Context

Design Spec v1.1 §2 and §14 mandate a 44x44pt minimum touch target on all interactive elements. This requirement was an ongoing constraint during Phases 4-12, but each phase prioritized functional delivery. Cross-screen elements (icon-only buttons, small toggles, chip rows at compact Dynamic Type sizes) are the most common violation vectors. Shipping without this pass means the app fails Apple's own accessibility guidelines and exposes users with motor impairments to sub-threshold targets on every screen.

The cadence-accessibility skill §1 defines the precise enforcement pattern: `.frame(minWidth: 44, minHeight: 44)` paired with `.contentShape(Rectangle())` on elements whose visual bounds fall short of the threshold. This epic applies that pattern everywhere it is missing.

## Scope

### In Scope

- SymptomChip and FlowChip (Log Sheet + Calendar day detail) touch target verification and remediation
- Period toggle buttons ("Period started" / "Period ended") touch target verification
- All Primary CTA buttons across all screens (Log Sheet Save, auth Continue, onboarding Continue) touch target verification
- Calendar day cells (all 6 states: period, predicted, fertile, ovulation, today, empty) touch target verification -- tappable area, not visual size
- Day detail sheet close and interactive elements touch target verification
- Icon-only buttons on all screens: Auth screen password show/hide toggle, notification mute icon in Partner Notifications tab, close/dismiss icons on all sheets and modal surfaces
- Sharing permission toggles, Log Sheet privacy toggle, and notification preference toggles touch target verification on their containing tap rows
- XCUITest `performAccessibilityAudit(for: .hitRegion)` sweep on: Tracker Home, Log Sheet, Calendar, Calendar day detail, Auth, Partner Dashboard, Partner Notifications, Tracker Settings, and Partner Settings screens

### Out of Scope

- Tab bar items (system TabView handles 44pt tap regions automatically on iOS 26 -- no explicit frame needed)
- System Toggle component hit area (UIKit-backed; iOS guarantees 44pt on system Toggle -- verify but do not override the native control)
- Any new interactive component not already implemented in Phases 0-12
- Feature or interaction changes of any kind

## Dependencies

| Dependency                                                                                                                                                      | Type | Phase/Epic         | Status | Risk |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ------------------ | ------ | ---- |
| All UI phases complete: Tracker Home, Log Sheet, Calendar, Tracker Settings, Partner Navigation, Partner Dashboard, Partner Settings, Reports, Auth, Onboarding | FS   | PH-0 through PH-12 | Open   | Low  |
| SymptomChip and FlowChip components implemented                                                                                                                 | FS   | PH-4-E3            | Open   | Low  |
| Calendar day cells implemented                                                                                                                                  | FS   | PH-6-E1            | Open   | Low  |
| Partner Bento grid implemented                                                                                                                                  | FS   | PH-9-E2            | Open   | Low  |

## Assumptions

- Chip height renders at or near 44pt at Default Dynamic Type via the 8pt top/bottom vertical padding on a 28pt cap-height label, as specified in the cadence-accessibility skill §1. The audit verifies this assumption and remediates if not met.
- System TabView on iOS 26 provides 44pt tap regions on tab bar items without explicit frame modifiers -- this is verified but not remediated via Swift code.
- The day detail sheet close affordance is a native `presentationDetents` drag indicator, system-managed; its 44pt region is Apple's responsibility, not Cadence's.
- `performAccessibilityAudit(for: .hitRegion)` in XCUITest catches the same violations that Xcode Accessibility Inspector flags. Both tools are used: Inspector for fast per-element inspection during development, XCUITest for regression.

## Risks

| Risk                                                                                                        | Likelihood | Impact | Mitigation                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chip vertical padding renders below 44pt on compact Dynamic Type sizes (xSmall)                             | Low        | Medium | Enforce `.frame(minHeight: 44)` at the chip root level as the spec requires; verify at xSmall Dynamic Type in Simulator.                             |
| Adding `.frame(minWidth: 44, minHeight: 44)` to chips shifts surrounding layout (e.g., wrapping chip grids) | Low        | Medium | Apply frame to the Button wrapper, not the chip label -- visual bounds stay unchanged. Verify in Log Sheet at both .medium and .large sheet detents. |
| Calendar cell tap region inflated by `.contentShape` conflicts with multi-day fertile window band rendering | Low        | High   | Apply `.contentShape(Rectangle())` scoped to the individual cell, not the row container. Test at Default and Accessibility3 Dynamic Type.            |
| Icon-only buttons in sheets dismissed before audit completes                                                | Low        | Low    | Navigate to each sheet programmatically in XCUITest to audit its elements before dismissal.                                                          |

---

## Stories

### S1: Chip Component Touch Targets

**Story ID:** PH-13-E1-S1
**Points:** 3

Audit and remediate 44x44pt touch targets on SymptomChip and FlowChip across all appearances: Log Sheet chip grid, Calendar day detail read-only chip display, and Tracker Home "Today's Log" card chip row. Apply `.frame(minWidth: 44, minHeight: 44)` to the Button wrapper of each interactive chip. Confirm read-only chip appearances do not carry an interactive frame (they are not tappable -- no contentShape needed).

**Acceptance Criteria:**

- [ ] Every SymptomChip rendered in the Log Sheet chip grid has a minimum 44x44pt tappable area, confirmed by Xcode Accessibility Inspector showing no hitRegion violation on any chip at Default Dynamic Type
- [ ] Every FlowChip rendered in the Log Sheet has a minimum 44x44pt tappable area, confirmed by the same Inspector check
- [ ] Read-only SymptomChip instances (Tracker Home "Today's Log" display, Partner Bento Symptoms card) do not receive interactive frame modifiers -- they have no tap handler and must not mislead Accessibility Inspector into reporting them as interactive targets
- [ ] Chip touch target passes at both Default and Accessibility3 Dynamic Type sizes without layout overflow in the chip grid
- [ ] No chip visual appearance changes as a result of frame expansion (padding is adjusted on the container, not by scaling the visible label)
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all modified Swift files

**Dependencies:** None
**Notes:** The cadence-accessibility skill §1 specifies chip height >= 44pt via 8pt top/bottom padding on a 28pt cap-height label. If the existing implementation already meets this, mark verified and document. If it does not, apply `.frame(minHeight: 44)` to the Button root, not to the inner label Text view.

---

### S2: Period Toggle and Primary CTA Touch Targets

**Story ID:** PH-13-E1-S2
**Points:** 2

Verify that the two period toggle buttons ("Period started", "Period ended") and all Primary CTA buttons across all screens (Log Sheet Save, auth Continue, onboarding Continue CTAs) meet the 44x44pt minimum. These are full-width or near-full-width buttons and are unlikely to violate, but must be confirmed before sign-off.

**Acceptance Criteria:**

- [ ] "Period started" and "Period ended" buttons in the Log Sheet each have a minimum height of 44pt, confirmed by Accessibility Inspector at Default Dynamic Type
- [ ] Log Sheet Save CTA (pinned above keyboard at `.medium` detent) has a minimum height of 44pt; frame does not collapse when the soft keyboard is presented
- [ ] Auth screen Continue CTA has a minimum height of 44pt
- [ ] All onboarding screen Continue CTAs have a minimum height of 44pt
- [ ] No button listed above shows a hitRegion violation in Xcode Accessibility Inspector on the Simulator
- [ ] No visual changes to any button as a result of this verification pass

**Dependencies:** None
**Notes:** These buttons are specified as full-width Primary CTA style with 14pt corner radius (Design Spec §6). The `space-44` spacing token is 44pt and matches the required minimum. If the implementation uses `space-44` as button height, this story is a verification pass only.

---

### S3: Calendar Day Cell and Day Detail Touch Targets

**Story ID:** PH-13-E1-S3
**Points:** 3

Verify and remediate 44x44pt tappable areas on calendar day cells and any interactive elements within the day detail bottom sheet. The calendar grid layout constrains cell dimensions to the available width divided by 7 -- at narrow screen widths, the horizontal dimension may fall below 44pt. Apply `.contentShape(Rectangle())` to expand the hit region without altering the cell's visual bounds.

**Acceptance Criteria:**

- [ ] Every tappable calendar day cell (all 6 states: period, predicted, fertile, ovulation, today, empty/selectable) has a `.contentShape(Rectangle())` applied so that taps anywhere within the calendar row height activate the correct cell, even if the visual size is narrower than 44pt
- [ ] Tapping the expanded hit region of a day cell does not trigger the wrong cell -- each cell's tap region is bounded to its column slot, not the full row
- [ ] At Accessibility3 Dynamic Type, day cells remain tappable and do not produce overlapping hit regions
- [ ] Month navigation previous/next arrow buttons each have a minimum 44x44pt tappable area, confirmed by Accessibility Inspector
- [ ] The day detail bottom sheet is `.medium` detent -- the drag indicator is system-managed (no explicit frame needed); this is documented as verified
- [ ] Any interactive elements within the day detail sheet (edit entry CTA, close action) have a minimum 44x44pt tappable area
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** PH-13-E1-S1
**Notes:** The calendar cell hit region expansion uses `.contentShape(Rectangle())` on the cell's Button, not a frame modifier, to avoid shifting the grid layout. The fertile window continuous band renders behind cells and must not intercept the cell's tap -- verify z-order is correct after contentShape expansion.

---

### S4: Icon-Only Button Touch Targets

**Story ID:** PH-13-E1-S4
**Points:** 3

Audit and remediate all icon-only buttons across all screens. These are the highest-risk touch target violations because their visual footprint (12-25pt icon) is far below the 44pt threshold. Apply `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` to every icon-only interactive element.

**Acceptance Criteria:**

- [ ] Auth screen password show/hide toggle (plain text "Show"/"Hide" button trailing in the password field) has a minimum 44x44pt tappable area; confirmed by Accessibility Inspector showing no hitRegion violation
- [ ] Notification mute icon button in the Partner Notifications tab (if present as an icon-only control) has a minimum 44x44pt tappable area
- [ ] All sheet close/dismiss icon buttons (xmark, chevron.down, or equivalent) across Log Sheet, day detail sheet, and any modal surface have a minimum 44x44pt tappable area
- [ ] Tracker Settings and Partner Settings back navigation buttons (system NavigationStack back button) are system-managed -- documented as verified, no override needed
- [ ] No icon button shows a hitRegion violation in Xcode Accessibility Inspector on any screen in the app
- [ ] No visual change to any icon as a result of frame expansion (the icon renders at its designed size; only the hit region expands)
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift files

**Dependencies:** None
**Notes:** The `.frame(minWidth: 44, minHeight: 44)` modifier is applied to the Button view containing the Image, not to the Image itself. `.contentShape(Rectangle())` ensures the expanded frame is the hit-testable region, not the image bounds.

---

### S5: Toggle Row Touch Targets

**Story ID:** PH-13-E1-S5
**Points:** 2

Verify that the system Toggle components in sharing permission toggles, the Log Sheet privacy toggle, and notification preference toggles present an adequate tappable area. The system Toggle on iOS 26 is UIKit-backed and provides its own 44pt hit region; the containing row must not accidentally restrict the hit region through an overlapping clip shape or fixed-height container smaller than 44pt.

**Acceptance Criteria:**

- [ ] The Log Sheet "Keep this day private" toggle row has a minimum height of 44pt end-to-end; tapping anywhere in the row label triggers the toggle (system `.toggleStyle(.switch)` behavior)
- [ ] Each sharing permission category toggle row in Tracker Settings (Phase 8) has a minimum height of 44pt; the row's `.contentShape` does not restrict the system Toggle's native tap region
- [ ] Each notification preference toggle row in both Tracker Settings (Phase 10) and Partner Settings (Phase 10) has a minimum height of 44pt
- [ ] Xcode Accessibility Inspector shows no hitRegion violation on any toggle row in the app
- [ ] No toggle label or system Toggle component has its hit region clipped by a parent container using `.frame(height: N)` where N < 44

**Dependencies:** None
**Notes:** iOS system Toggle (.toggleStyle(.switch)) provides its own 44pt touch area on the switch thumb, but the label side of the row must also be tappable to the same region. If the row uses a fixed height < 44pt, replace with `.frame(minHeight: 44)`.

---

### S6: XCUITest performAccessibilityAudit(.hitRegion) Sweep

**Story ID:** PH-13-E1-S6
**Points:** 5

Write an XCUITest that navigates to each major screen in the app and calls `performAccessibilityAudit(for: .hitRegion)` to verify zero hitRegion violations survive into the test suite. This test runs in the `CadenceTests` (UI test) target and serves as the regression gate for all S1-S5 fixes.

**Acceptance Criteria:**

- [ ] `AccessibilityHitRegionAuditTests` file exists under `CadenceTests/Accessibility/`; it is registered in `project.yml` under the CadenceTests target
- [ ] The test navigates to and audits: Tracker Home, Log Sheet (opened via center tab), Calendar, Auth screen (from a signed-out state), Partner Dashboard
- [ ] `try app.performAccessibilityAudit(for: .hitRegion)` is called on each screen and the test passes (throws no `XCTAssertionFailure` unless suppressed)
- [ ] Any known false-positive suppressions are documented in the test via an `issues.filter` closure with an inline comment naming the element and the reason it is excluded
- [ ] The test passes clean (zero unsuppressed hitRegion violations) after all S1-S5 remediations are applied
- [ ] The test is deterministic -- it does not depend on network state or Supabase connectivity (all screens must render from local SwiftData or mock state)
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`

**Dependencies:** PH-13-E1-S1, PH-13-E1-S2, PH-13-E1-S3, PH-13-E1-S4, PH-13-E1-S5
**Notes:** `performAccessibilityAudit(for:)` is available in Xcode 15+ via the `Testing` framework extension on `XCUIApplication`. The audit type `.hitRegion` specifically checks elements whose `frame.size.width < 44 || frame.size.height < 44`. Suppression example:

```swift
try app.performAccessibilityAudit(for: .hitRegion) { issue in
    // System drag indicator on sheets -- Apple's responsibility
    issue.element?.identifier == "SheetDragIndicator"
}
```

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
- [ ] `performAccessibilityAudit(for: .hitRegion)` passes with zero unsuppressed violations on all audited screens
- [ ] Xcode Accessibility Inspector shows no hitRegion violations on any interactive element across all screens
- [ ] Phase objective is advanced: every interactive element in the shipping app meets the 44x44pt minimum tappable area requirement
- [ ] Applicable skill constraints satisfied: cadence-accessibility §1 (touch target enforcement pattern), swiftui-production (no force unwraps, no dead code), cadence-xcode-project (all new test files added to project.yml)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] Accessibility requirements verified per cadence-accessibility skill §1 and §9
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from Design Spec v1.1 §14 touch target requirement

## Source References

- PHASES.md: Phase 13 -- Accessibility Compliance (in-scope: 44pt touch target audit across chips, buttons, toggles, calendar cells, tab bar items, day detail sheet interactions)
- Design Spec v1.1 §2 (Platform assumptions -- strict 44x44pt minimum touch targets across all interactive elements)
- Design Spec v1.1 §14 (Accessibility -- all interactive elements: 44x44pt minimum touch target, use .frame(minWidth: 44, minHeight: 44) with contentShape if needed)
- cadence-accessibility skill §1 (Touch Targets -- 44x44pt minimum, implementation pattern, anti-pattern table)
- cadence-accessibility skill §9 (Screen Accessibility Checklist -- Touch Targets section)
- Apple Developer Documentation: `XCUIApplication.performAccessibilityAudit(for:issueHandler:)` (Xcode 15+)
