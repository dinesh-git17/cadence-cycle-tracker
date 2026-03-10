# UI Test Suite

**Epic ID:** PH-14-E3
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** M
**Status:** Draft

---

## Objective

Deliver the complete `CadenceUITests` suite covering the Log Sheet entry flow, symptom chip toggle state, and `isPrivate` master override UI behavior. Every test runs against an in-memory store with no live Supabase connection, uses `accessibilityIdentifier` for all element lookups, and passes deterministically in CI. This is the final automated quality gate before a TestFlight build is permitted.

## Problem / Context

Phases 4, 5, 6, and 8 implemented the Log Sheet, symptom chips, Tracker Home, and privacy toggle respectively. No `XCUITest` coverage was written during those phases. Three behavioral flows are contract-critical and must have automated regression coverage before shipping to real users: (1) the complete Log Sheet entry path from center tab tap to Save dismiss, (2) chip toggle state correctness including the optimistic-immediate requirement, and (3) the `isPrivate` toggle behavior including persistence. cadence-testing skill §§6-8 defines exact required test cases for each flow. Without this epic, the UI test gate in CI is a structural pass (no tests = no failures) that provides false confidence.

## Scope

### In Scope

- `CadenceUITests` target test infrastructure: `setUp()` with `--in-memory-store` and `--uitesting` launch arguments, `continueAfterFailure = false`
- App entry point guard: `--in-memory-store` launch argument detection in `CadenceApp.swift` -- `SupabaseClient` must not be initialized when the flag is present
- `accessibilityIdentifier` wiring on all Log Sheet interactive elements: date header, "Period started", "Period ended", flow chip grid, symptom chip grid, notes textarea, "Keep this day private" toggle, Save CTA
- `LogSheetUITests.swift` -- 7 required test cases per cadence-testing skill §6
- `ChipToggleUITests.swift` -- 5 required test cases per cadence-testing skill §7
- `PrivacyOverrideUITests.swift` -- 3 required test cases per cadence-testing skill §8
- All new test files registered in `project.yml` under `CadenceUITests` target
- `xcrun simctl erase` step added to the `ui-tests` CI job before the test run

### Out of Scope

- Unit tests for privacy filter logic (Epic 2 -- PH-14-E2)
- `performAccessibilityAudit(.hitRegion)` sweep (Phase 13 -- PH-13-E1-S6)
- VoiceOver accessibilityLabel audit (Phase 13 scope)
- Partner Dashboard UI tests -- no write interactions exist on the Partner side; the `isPrivate` exclusion behavior is covered by the unit test in Epic 2 (PH-14-E2-S4) per cadence-testing skill §8's fallback
- Any test requiring a live Supabase connection

## Dependencies

| Dependency                                                                                                               | Type | Phase/Epic  | Status | Risk |
| ------------------------------------------------------------------------------------------------------------------------ | ---- | ----------- | ------ | ---- |
| Log Sheet fully implemented with all interactive elements (period toggles, chip grid, notes, isPrivate toggle, Save CTA) | FS   | PH-4-E2     | Open   | Low  |
| SymptomChip component implemented with tap handler and state                                                             | FS   | PH-4-E3     | Open   | Low  |
| `CadenceUITests` target registered in `project.yml` and `CadenceUITests` scheme present                                  | FS   | PH-0-E1     | Open   | Low  |
| Epic 2 DI infrastructure: `makeTestContainer()` and `--in-memory-store` handling pattern established                     | SS   | PH-14-E2-S1 | Open   | Low  |
| Epic 1 CI `ui-tests` job structure in place                                                                              | SS   | PH-14-E1    | Open   | Low  |

## Assumptions

- The app's entry point (`CadenceApp.swift`) has or will have a branch that detects `--in-memory-store` and skips `SupabaseClient` initialization entirely -- not a conditional skip of Supabase calls, but no construction of the client at all.
- All Log Sheet interactive elements are `Button`, `Toggle`, or `TextField` SwiftUI views that `XCUIApplication` can locate by `accessibilityIdentifier`.
- SymptomChip tap state is reflected in the element's `accessibilityValue` or `accessibilityLabel` in a way that XCUITest can assert ("selected" vs. "unselected").
- The `isPrivate` toggle's state persists across Log Sheet dismissal and re-presentation for the same date -- verifiable via an in-memory store that survives within the same test run.
- Tests run on `iPhone 16 Pro, iOS 26.0` simulator per the cadence-ci skill §5 matrix.

## Risks

| Risk                                                                                                                           | Likelihood | Impact | Mitigation                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------ | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `accessibilityIdentifier` strings added to SwiftUI views in this epic break existing snapshot or accessibility tests in PH-13  | Low        | Low    | `accessibilityIdentifier` does not affect visual rendering or accessibility tree semantics (it is a testing artifact). No snapshot tests exist in the current test suite. |
| SymptomChip does not expose a machine-readable selected/unselected state via `accessibilityValue`                              | Medium     | Medium | If the chip's accessibility state is not already set, add `.accessibilityValue(isSelected ? "selected" : "unselected")` in this epic as part of S2's identifier wiring.   |
| `--in-memory-store` launch argument guard requires a code change to `CadenceApp.swift` that was not anticipated during Phase 4 | Medium     | Medium | The guard is a two-line change in the `WindowGroup` body. It does not alter production behavior when the flag is absent.                                                  |
| UI tests are flaky on CI due to simulator state from the preceding `unit-tests` job                                            | Low        | Medium | `xcrun simctl erase "iPhone 16 Pro"` runs before the `ui-tests` job starts; this is included in S1's CI configuration requirement.                                        |

---

## Stories

### S1: UI Test Infrastructure and Launch Argument Guard

**Story ID:** PH-14-E3-S1
**Points:** 3

Establish the `CadenceUITests` base test class, `setUp()` pattern, and the in-memory store launch argument guard in the app entry point. These are prerequisites for all other stories in this epic.

**Acceptance Criteria:**

- [ ] `CadenceApp.swift` detects `ProcessInfo.processInfo.arguments.contains("--in-memory-store")` before constructing the `ModelContainer`; when the flag is present, `SupabaseClient` is not initialized and an in-memory `ModelContainer` is used
- [ ] A base `CadenceUITestCase` class (or `setUp()` pattern in each test file) sets: `continueAfterFailure = false`, `app.launchArguments = ["--uitesting", "--in-memory-store"]`, and calls `app.launch()` before each test
- [ ] Running `CadenceUITests` with the `--in-memory-store` flag produces no Supabase network traffic (confirmed by absence of any Supabase hostname in network proxy logs or by the guard branch executing as verified with a breakpoint locally)
- [ ] `xcrun simctl erase "iPhone 16 Pro"` is added to the `ui-tests` CI job step before the `xcodebuild test` command in `.github/workflows/ci.yml`
- [ ] `CadenceUITests` scheme is registered in `project.yml` and `xcodebuild test -scheme CadenceUITests` launches the simulator without error
- [ ] `scripts/protocol-zero.sh` exits 0 on `CadenceApp.swift` (modified file) and all new test infrastructure files

**Dependencies:** None within this epic; PH-14-E2-S1 established the `makeTestContainer()` pattern that informs the app entry point pattern here.
**Notes:** The in-memory `ModelContainer` in the app entry point must use the same five-model schema as `makeTestContainer()` in `CadenceTests`. Use the same helper or duplicate the configuration inline -- either is acceptable since this is a test-only code path.

---

### S2: accessibilityIdentifier Wiring

**Story ID:** PH-14-E3-S2
**Points:** 3

Assign stable `accessibilityIdentifier` values to every interactive element in the Log Sheet that will be exercised by the UI test suite. No test in this epic may locate an element by display text.

**Acceptance Criteria:**

- [ ] The following identifiers are applied to Log Sheet elements (using `.accessibilityIdentifier("id_string")`):
  - Log Sheet container: `"log_sheet_container"`
  - "Period started" button: `"log_period_start_button"`
  - "Period ended" button: `"log_period_end_button"`
  - Notes textarea: `"log_notes_field"`
  - "Keep this day private" toggle: `"log_sheet_private_toggle"`
  - Save CTA: `"log_sheet_save_button"`
  - Each SymptomChip button: `"chip_<symptom_name>"` (e.g., `"chip_cramps"`, `"chip_headache"`, `"chip_sex"`)
- [ ] Each SymptomChip has `.accessibilityValue(isSelected ? "selected" : "unselected")` set so `XCUITest` can assert selection state without relying on visual color state
- [ ] The Sex chip additionally has its lock icon element identified by `accessibilityIdentifier("chip_sex_lock_icon")` so its presence can be independently asserted
- [ ] Running `XCUIApplication().buttons["log_sheet_save_button"].exists` returns `true` when the Log Sheet is presented in the simulator
- [ ] `scripts/protocol-zero.sh` exits 0 on all modified Swift view files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all modified Swift view files

**Dependencies:** PH-14-E3-S1
**Notes:** `accessibilityIdentifier` values are lowercase snake_case strings. They must be stable -- once assigned and tests are written against them, changing the string breaks tests. Adding identifiers to views does not change their visual appearance or Dynamic Type scaling.

---

### S3: Log Sheet Entry Flow UI Tests

**Story ID:** PH-14-E3-S3
**Points:** 5

Author `LogSheetUITests.swift` with all 7 required test cases per cadence-testing skill §6. Each test is an independent `func test_*` method. Tests use `waitForExistence(timeout:)` for all async element detection.

**Acceptance Criteria:**

- [ ] `LogSheetUITests.swift` exists in `CadenceUITests/` and is registered in `project.yml`
- [ ] All 7 required test cases are present and passing:
  - `test_logSheet_presentsFromCenterTab`: tap center Log tab; assert `log_sheet_container` exists within 2.0s
  - `test_logSheet_periodStarted_reflectsActiveState`: tap `log_period_start_button`; assert button's `accessibilityValue` reflects active/selected state
  - `test_logSheet_chipToggleOn_reflectsSelectedState`: tap `chip_cramps`; assert `accessibilityValue == "selected"`
  - `test_logSheet_chipToggleOff_returnToUnselected`: tap `chip_cramps` twice; assert `accessibilityValue == "unselected"` after second tap
  - `test_logSheet_notesInput_containsTypedText`: tap `log_notes_field`, type "test note"; assert field value contains "test note"
  - `test_logSheet_isPrivateToggle_turnedOn`: tap `log_sheet_private_toggle`; assert `app.switches["log_sheet_private_toggle"].value as? String == "1"`
  - `test_logSheet_saveButton_dismissesSheet`: tap `log_period_start_button`, tap `log_sheet_save_button`; assert `log_sheet_container` no longer exists (sheet dismissed)
- [ ] No test locates any element by display text -- all lookups use `accessibilityIdentifier`
- [ ] All 7 tests pass with `xcodebuild test -scheme CadenceUITests` on `iPhone 16 Pro, iOS 26.0`
- [ ] `scripts/protocol-zero.sh` exits 0 on `LogSheetUITests.swift`

**Dependencies:** PH-14-E3-S2
**Notes:** `waitForExistence(timeout: 2.0)` is used on the sheet container after tab tap -- sheet presentation is animated and not instantaneous. For the dismiss test, use `waitForNonExistence(timeout: 2.0)` after tapping Save. If `waitForNonExistence` is not available on the Xcode 16 SDK, use `XCTAssertFalse(sheet.waitForExistence(timeout: 2.0))` after dismissal.

---

### S4: Chip Toggle State UI Tests

**Story ID:** PH-14-E3-S4
**Points:** 3

Author `ChipToggleUITests.swift` with all 5 required test cases per cadence-testing skill §7. The critical behavioral requirement is that chip state changes are optimistic and instant -- no loading indicator may be visible after a chip tap.

**Acceptance Criteria:**

- [ ] `ChipToggleUITests.swift` exists in `CadenceUITests/` and is registered in `project.yml`
- [ ] All 5 required test cases are present and passing:
  - `test_chipToggle_defaultState_allUnselected`: open Log Sheet; assert all chip `accessibilityValue` values are `"unselected"` before any tap
  - `test_chipToggle_toggleOn_chipReflectsSelected`: tap any chip; assert its `accessibilityValue == "selected"` immediately after tap
  - `test_chipToggle_toggleOff_chipReflectsUnselected`: tap same chip twice; assert `accessibilityValue == "unselected"` after second tap
  - `test_chipToggle_noLoadingIndicator_afterTap`: tap a chip; assert no `activityIndicator` or `progressIndicator` element exists in the app hierarchy within 0.5s after tap
  - `test_chipToggle_sexChipLockIcon_alwaysPresent`: assert `chip_sex_lock_icon` exists before and after toggling the Sex chip
- [ ] The `test_chipToggle_noLoadingIndicator_afterTap` test passes -- no `XCUIElementType.activityIndicator` or `.progressIndicator` is found after chip tap
- [ ] All 5 tests pass with `xcodebuild test -scheme CadenceUITests`
- [ ] `scripts/protocol-zero.sh` exits 0 on `ChipToggleUITests.swift`

**Dependencies:** PH-14-E3-S2, PH-14-E3-S3
**Notes:** The no-loading-indicator test is an explicit behavioral contract from the design spec §13 ("Haptic feedback on Log save. No toast -- the UI state change itself is confirmation") and the chip optimistic update requirement (cadence-motion skill, chip toggle 0.15s cross-dissolve with instant state change). If a loading indicator appears after chip tap, that is an implementation bug to fix -- not a test to weaken.

---

### S5: isPrivate Master Override UI Tests

**Story ID:** PH-14-E3-S5
**Points:** 3

Author `PrivacyOverrideUITests.swift` with 3 required test cases per cadence-testing skill §8. The isPrivate toggle presence and persistence tests are fully achievable in the in-memory store environment. The partner exclusion test is covered by the unit test in Epic 2 (PH-14-E2-S4) per the skill's fallback instruction.

**Acceptance Criteria:**

- [ ] `PrivacyOverrideUITests.swift` exists in `CadenceUITests/` and is registered in `project.yml`
- [ ] Three required test cases are present and passing:
  - `test_isPrivate_togglePresent_inLogSheet`: open Log Sheet; assert `app.switches["log_sheet_private_toggle"].exists == true`
  - `test_isPrivate_togglePersists_acrossSheetReopenForSameDate`: toggle on `log_sheet_private_toggle`, tap Save; reopen Log Sheet for the same date; assert `app.switches["log_sheet_private_toggle"].value as? String == "1"` (toggle is still on)
  - `test_isPrivate_toggleOff_byDefault`: open Log Sheet for a new date (no prior entry); assert `app.switches["log_sheet_private_toggle"].value as? String == "0"` (toggle defaults to off)
- [ ] The persistence test reopens the Log Sheet by tapping the same date's calendar cell or re-tapping the Log tab for the same date -- the mechanism must result in the same date's entry being loaded
- [ ] All 3 tests pass with `xcodebuild test -scheme CadenceUITests`
- [ ] `scripts/protocol-zero.sh` exits 0 on `PrivacyOverrideUITests.swift`

**Dependencies:** PH-14-E3-S3, PH-14-E3-S4
**Notes:** The persistence test requires that Log Sheet re-open loads the existing `DailyLog` for the same date from the in-memory store. This works correctly if the Log Sheet loads from the `ModelContext` at presentation time (not only when the view first appears on install). Verify this in the Simulator before writing the test. If the Log Sheet does not reload from the store on re-presentation, that is a Log Sheet implementation bug -- fix the Log Sheet before declaring this story done.

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
- [ ] All 15 UI test cases (7 Log Sheet + 5 chip toggle + 3 isPrivate) pass in CI with `xcodebuild test -scheme CadenceUITests`
- [ ] No test locates any element by display text -- all lookups use `accessibilityIdentifier`
- [ ] No test requires a live Supabase connection
- [ ] Chip toggle test explicitly verifies no loading indicator appears after tap
- [ ] `SupabaseClient` is not initialized when `--in-memory-store` is present in launch arguments
- [ ] Phase objective is advanced: UI test gate is satisfied; TestFlight build is unblocked from the UI test dimension
- [ ] Applicable skill constraints satisfied: cadence-testing §§6-8 (full UI test contract), §9 (no live Supabase), swiftui-production (no dead code, no force unwraps), cadence-xcode-project (all new files in project.yml)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: UI test suite -- Log Sheet, chip toggle, isPrivate)
- cadence-testing skill §6 (UI test contract -- Log Sheet entry flow, 7 required cases)
- cadence-testing skill §7 (UI test contract -- chip toggle state, 5 required cases, optimistic-instant requirement)
- cadence-testing skill §8 (UI test contract -- isPrivate master override, 3 required cases)
- cadence-testing skill §9 (no live Supabase in tests -- SupabaseClient must not be initialized under --in-memory-store)
- Design Spec v1.1 §10.1 (SymptomChip -- toggle instant on tap, no network wait)
- Design Spec v1.1 §12.3 (Log Sheet -- "Keep this day private" toggle as master override)
- cadence-privacy-architecture skill (isPrivate as master override before any RLS evaluation)
