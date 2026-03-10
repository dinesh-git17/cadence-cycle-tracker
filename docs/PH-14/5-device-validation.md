# Device Validation

**Epic ID:** PH-14-E5
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** M
**Status:** Draft

---

## Objective

Verify on physical hardware and in instrumented Simulator runs that the shipped app meets every non-functional requirement defined in the design spec and MVP spec: dark mode color contrast at WCAG AA on device, dashboard and calendar performance within spec, and full offline-to-online E2E data integrity. Document results in a signed-off validation checklist. No TestFlight build ships until all four validation stories are complete.

## Problem / Context

Three categories of validation cannot be confirmed by automated tests alone:

**Dark mode contrast** -- Design Spec v1.1 §3 Dark Mode Contrast Notes defines specific terracotta and sage dark values (`#D4896A`, `#8FB08F`) chosen to maintain WCAG AA (4.5:1) against `#1C1410`. Simulator color rendering approximates display behavior but does not account for display calibration, True Tone, Night Shift, or ambient light. On-device verification is the only way to confirm the spec's contrast claims hold at shipment. This is listed as a pre-TestFlight open item in Design Spec §15.

**Performance** -- MVP Spec Non-Functional Requirements specifies: Dashboard loads in under 1 second on WiFi, Calendar scrolling at 60fps, and logging a symptom feels immediate. These are measurable using Xcode Instruments (Time Profiler, Core Animation) against a device running the Release build (not Debug). A Debug build with compiler optimizations off is not representative.

**Offline E2E** -- MVP Spec NFR specifies offline logging with sync on reconnect and no data loss on app termination mid-log. The `SyncCoordinator` write queue and `NWPathMonitor` integration (cadence-sync skill) handle this in theory. Physical airplane mode testing with actual app termination confirms it in practice. This cannot be replicated by `FakeSyncCoordinator` in unit tests.

## Scope

### In Scope

- Dark mode on-device contrast verification: all color token pairings listed in Design Spec §3 against their dark mode backgrounds, using a WCAG contrast ratio tool
- Specific dark mode pairings to verify:
  - CadenceTerracotta (`#D4896A`) on CadenceBackground (`#1C1410`) -- WCAG AA required (4.5:1)
  - CadenceTerracotta (`#D4896A`) on CadenceCard (`#2A1F18`) -- WCAG AA required
  - CadenceSage (`#8FB08F`) on CadenceBackground -- advisory (used for secondary elements, not body text)
  - CadenceTextPrimary (`#F2EDE7`) on CadenceBackground (`#1C1410`) -- WCAG AA required
  - CadenceTextSecondary (`#98989D`) on CadenceBackground -- WCAG AA required for informational text
  - CadenceTextOnAccent (`#FFFFFF`) on CadenceTerracotta (`#D4896A`) -- WCAG AA required (chip active state, primary CTA)
- Performance validation: Dashboard cold start on WiFi, Calendar month scroll, Log Sheet first-chip-tap response -- measured via Xcode Instruments on Release build on physical iPhone
- Offline E2E: full airplane mode logging flow, write queue verification, sync on reconnect, no data loss on force-quit mid-log
- Documented validation checklist: device model, OS version, build number, tester, pass/fail per criterion

### Out of Scope

- Light mode contrast audit (Design Spec §14 notes light mode values verified at definition; audit is dark mode only per §15 open item)
- iPad testing -- deployment target is iPhone only for the beta
- Automated performance tests via `XCTMetric` -- the validation method is Instruments + manual timing, not XCTest performance suites (the spec does not require automated perf tests; they are post-beta tooling)
- Crashlytics integration and crash-free rate reporting -- no third-party analytics in the beta build per MVP Spec Privacy NFR

## Dependencies

| Dependency                                                                                                                           | Type     | Phase/Epic         | Status | Risk |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------------------ | ------ | ---- |
| All UI phases complete (0-13): every screen, component, and interaction is implemented                                               | FS       | PH-0 through PH-13 | Open   | Low  |
| Haptic finalization complete (CadenceMark Bezier and haptic library applied)                                                         | FS       | PH-14-E4           | Open   | Low  |
| `SyncCoordinator` write queue, `NWPathMonitor` offline indicator, and exponential backoff implemented                                | FS       | PH-7-E4            | Open   | Low  |
| Release build configuration is correct (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym` in Release) | FS       | PH-14-E1-S3        | Open   | Low  |
| Physical iPhone running iOS 26 available for on-device testing                                                                       | External | Dinesh             | Open   | Low  |

## Assumptions

- A Release scheme build is available for performance testing -- performance on Debug build with disabled optimizations is not representative of shipped behavior.
- `DWARF with dSYM File` is set for the Release build configuration in `project.yml` so that Instruments can symbolicate call stacks.
- The Supabase project is running and accessible from the test device for the sync portion of the offline E2E test.
- Xcode Instruments Time Profiler and Core Animation instrument are available on the test Mac.
- "Cold start" means the app is not in the Foreground Extended mode from a previous launch -- killed from the app switcher before timing.

## Risks

| Risk                                                                                                      | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A dark mode color pairing fails WCAG AA on device                                                         | Medium     | High   | The spec's WCAG AA claim for dark mode was made analytically in Design Spec §3. If a pairing fails on device, the color asset value must be adjusted and the dark mode variant updated in xcassets. This is a blocking fix before TestFlight.                 |
| Dashboard cold start exceeds 1 second on WiFi due to Supabase query latency                               | Medium     | Medium | Profile with Instruments to identify whether the bottleneck is network (adjust with skeleton loading -- already in spec), SwiftData fetch (optimize predicate), or layout (verify `LazyVStack` is in place). Fix the bottleneck; do not adjust the threshold. |
| App loses data during force-quit mid-log because SwiftData write is async                                 | Low        | High   | The write-path contract (cadence-sync skill, cadence-data-layer skill) requires SwiftData write to complete before the async Supabase enqueue. If force-quit between these two steps causes loss, fix the write ordering before TestFlight.                   |
| Sync does not complete after airplane mode reconnect due to `NWPathMonitor` not firing on the test device | Low        | Medium | Test with multiple reconnection attempts. If `NWPathMonitor` fails to fire, check that the monitor is started and the path update handler is registered before the first network request.                                                                     |

---

## Stories

### S1: Dark Mode On-Device Contrast Audit

**Story ID:** PH-14-E5-S1
**Points:** 3

Verify all specified dark mode color pairings meet WCAG AA (4.5:1 contrast ratio minimum) on a physical iPhone running iOS 26 in dark mode. Document results per pairing. Any failing pairing blocks TestFlight.

**Acceptance Criteria:**

- [ ] The following six dark mode pairings are each measured using a WCAG contrast tool (e.g., Apple's Accessibility Inspector color contrast tool, or Colour Contrast Analyser against exact hex values from Design Spec §3):
  - CadenceTerracotta `#D4896A` on CadenceBackground `#1C1410`: ratio >= 4.5:1 (pass/fail documented)
  - CadenceTerracotta `#D4896A` on CadenceCard `#2A1F18`: ratio >= 4.5:1 (pass/fail documented)
  - CadenceTextPrimary `#F2EDE7` on CadenceBackground `#1C1410`: ratio >= 4.5:1 (pass/fail documented)
  - CadenceTextSecondary `#98989D` on CadenceBackground `#1C1410`: ratio >= 3.0:1 minimum (UI component level, informational) -- document actual ratio
  - CadenceTextOnAccent `#FFFFFF` on CadenceTerracotta `#D4896A`: ratio >= 4.5:1 (pass/fail documented)
  - CadenceSage `#8FB08F` on CadenceBackground `#1C1410`: document actual ratio (advisory, not a hard gate)
- [ ] The audit is also performed visually on a physical iPhone 16 Pro in dark mode under ambient indoor lighting -- any pairing that passes analytically but appears unreadable on device is flagged for Dinesh's decision
- [ ] Any pairing that fails WCAG AA has its xcassets dark mode hex value corrected in `Colors.xcassets` before this story is marked done
- [ ] After any correction, the build is verified to compile and the corrected color renders correctly in Simulator dark mode
- [ ] Results are documented in a validation checklist entry with: device, OS version, date, tester (Dinesh), and pass/fail per pairing

**Dependencies:** None
**Notes:** WCAG AA requires 4.5:1 for normal text (< 18pt or < 14pt bold) and 3.0:1 for large text (>= 18pt or >= 14pt bold). CadenceTextSecondary is used for `subheadline` (15pt) and `footnote` (13pt) text -- these qualify as normal text and require 4.5:1. If `#98989D` on `#1C1410` fails 4.5:1 but passes 3.0:1, document the gap and escalate to Dinesh for a design decision before shipping.

---

### S2: Performance Validation

**Story ID:** PH-14-E5-S2
**Points:** 3

Profile the Release build on a physical iPhone using Xcode Instruments to verify Dashboard cold-start time < 1 second on WiFi, Calendar month scroll at 60fps, and Log Sheet chip-tap response feels immediate (< 100ms from tap to visual state change).

**Acceptance Criteria:**

- [ ] Dashboard cold-start time is measured from app launch to first meaningful paint (Tracker Home feed visible with skeleton or real data) using the Time Profiler instrument on a Release build -- result is < 1 second on WiFi
- [ ] If Dashboard cold-start exceeds 1 second, the bottleneck is identified in the Instruments trace (network, SwiftData, layout, or other) and fixed before this story is marked done
- [ ] Calendar month scroll is profiled using the Core Animation instrument; no dropped frames (< 60fps) occur during a single-finger drag scroll through 3 consecutive months
- [ ] Log Sheet chip tap latency: from the moment a chip is tapped to the moment its visual state (color fill, weight change) is visible, the elapsed time is < 100ms -- confirmed by frame-by-frame review in Core Animation instrument or slow-motion video
- [ ] Performance validation is run on a Release scheme build, not Debug -- the scheme is confirmed via `xcodebuild -list`; `Build Configuration` is `Release`
- [ ] Results (cold start time, min/avg/max fps during scroll, chip tap frame count) are documented in the validation checklist with: device model, iOS version, build number, instrument, and measured value

**Dependencies:** None
**Notes:** Instruments must attach to the Release build (not the Debug build). Use `Product > Profile` in Xcode (Cmd+I) to build with Release configuration and launch Instruments. The Time Profiler shows wall-clock time for the main thread -- look for the period between `applicationDidBecomeActive` and the first `body` invocation of `TrackerHomeView`. If `LazyVStack` is correctly in place (swiftui-production skill requirement), calendar scroll should be 60fps by construction; profile anyway to confirm.

---

### S3: Offline E2E Validation

**Story ID:** PH-14-E5-S3
**Points:** 5

Execute a full offline-to-online end-to-end test: log data while in airplane mode, force-quit mid-log, relaunch, verify data persists in SwiftData, re-enable network, and confirm the write queue flushes to Supabase with no data loss.

**Acceptance Criteria:**

- [ ] Enable airplane mode on a physical iPhone. Launch the app. Open Log Sheet. Select two symptoms. Tap Save. Verify: (1) Save completes without error; (2) the Log Sheet dismisses; (3) Tracker Home shows today's log summary with the two saved symptoms -- all without a network connection
- [ ] With airplane mode still enabled: open Log Sheet again. Enter notes ("offline test entry"). Force-quit the app (swipe up from app switcher) before tapping Save. Relaunch. Verify: the notes entry is not visible (it was not saved -- Save was not tapped). This confirms data is not persisted on partial input, not that data is lost
- [ ] Separately: open Log Sheet, enter data, tap Save, then immediately force-quit before the background sync can enqueue (< 500ms after Save). Relaunch. Verify: the entry's SwiftData record exists in the app (Tracker Home shows it) -- the local SwiftData write persisted across force-quit
- [ ] Re-enable network (disable airplane mode). Wait up to 30 seconds. Verify: the write queue flushes and the entry appears in the Supabase `daily_logs` table (confirm via Supabase dashboard or by opening Partner Dashboard if connected and symptoms are shared)
- [ ] Offline indicator ("Last updated [time]") appears in the navigation bar area when airplane mode is active -- confirmed visually
- [ ] Offline indicator disappears within 5 seconds of re-enabling network -- confirmed by observation
- [ ] All validation steps are documented in the checklist: device, iOS version, build number, airplane mode sequence, pass/fail per step, timestamp

**Dependencies:** PH-14-E4 (haptic finalization -- final product state)
**Notes:** The "force-quit after Save" test timing (< 500ms) is approximate. The goal is to confirm that SwiftData write is synchronous relative to the Save action -- the local write completes before any async network operation begins, per the cadence-data-layer and cadence-sync skill contract. If the entry does not survive a force-quit after Save, the write ordering in the Log Sheet ViewModel is incorrect (it is awaiting the network enqueue before completing the SwiftData write) -- fix the write ordering.

---

### S4: Validation Checklist and Sign-Off

**Story ID:** PH-14-E5-S4
**Points:** 2

Aggregate the results from S1-S3 into a single validation checklist. Dinesh signs off on the checklist before Epic 6 (TestFlight distribution) begins. Any open item on the checklist blocks TestFlight.

**Acceptance Criteria:**

- [ ] A validation checklist document exists (PR description, Notion page, or internal doc -- not committed to the repo unless in `docs/` and explicitly requested) covering all four categories: dark mode contrast, Dashboard performance, Calendar performance, and offline E2E
- [ ] Each checklist item records: test description, device model, iOS version, build number, measured value or pass/fail result, date, and tester
- [ ] All six dark mode contrast pairings from S1 have a documented pass result
- [ ] Dashboard cold-start measured value is documented and is < 1 second
- [ ] Calendar scroll measured as 60fps (or documented fps with justification if below)
- [ ] Offline E2E all four steps (save offline, force-quit recovery, sync on reconnect, offline indicator) documented as pass
- [ ] Dinesh has reviewed the checklist and given explicit sign-off (comment on PR or message confirming review) before Epic 6 begins
- [ ] No open P0/P1 items remain on the checklist at sign-off

**Dependencies:** PH-14-E5-S1, PH-14-E5-S2, PH-14-E5-S3
**Notes:** The validation checklist is not a committed artifact unless Dinesh wants it in `docs/`. Its purpose is a gate: Epic 6 does not start until Dinesh confirms it passes. If any checklist item fails, the fix is implemented (in the relevant feature epic or here) and the item is re-tested before sign-off.

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

- [ ] All stories in this epic are complete and merged (or S4 signed off -- the checklist may not be a committed file)
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] All six dark mode contrast pairings pass WCAG AA (4.5:1) or have a documented design decision if borderline
- [ ] Dashboard cold-start < 1 second on WiFi on a physical device confirmed
- [ ] Calendar scroll at 60fps confirmed on a physical device
- [ ] Offline E2E: data persists through force-quit, write queue flushes on reconnect, no data loss
- [ ] Dinesh has signed off on the validation checklist
- [ ] Phase objective is advanced: the product is validated on real hardware against all NFRs before TestFlight distribution
- [ ] Applicable skill constraints satisfied: cadence-accessibility (WCAG AA contrast verification), cadence-sync (offline resilience, write queue, NWPathMonitor), cadence-data-layer (offline-first write path correctness)
- [ ] `scripts/protocol-zero.sh` exits 0 on any Swift files modified as a result of validation fixes
- [ ] `scripts/check-em-dashes.sh` exits 0 on any modified files

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: device validation -- dark mode contrast, performance, offline E2E)
- Design Spec v1.1 §3 Dark Mode Contrast Notes (terracotta #D4896A and sage #8FB08F -- WCAG AA verified at definition; on-device verification required pre-TestFlight)
- Design Spec v1.1 §14 Accessibility (contrast: CadenceTerracotta on #F5EFE8 passes WCAG AA 4.5:1; dark mode values verified at definition)
- Design Spec v1.1 §15 Open Items (dark mode contrast audit on device -- tagged Pre-TestFlight)
- MVP Spec Non-Functional Requirements (Performance: Dashboard < 1s on WiFi; Calendar 60fps; logging feels immediate. Reliability: offline logging, sync on reconnect, no data loss on app termination)
- cadence-sync skill (write queue, NWPathMonitor, offline indicator)
- cadence-data-layer skill (offline-first: all writes go to SwiftData immediately, Supabase sync queued via SyncCoordinator)
