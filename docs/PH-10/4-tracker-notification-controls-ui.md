# Tracker Notification Controls UI

**Epic ID:** PH-10-E4
**Phase:** 10 -- Notifications
**Estimated Size:** M
**Status:** Draft

---

## Objective

Build the in-app UI surface through which the Tracker configures all notification preferences: three reminder toggles, the advance days stepper, the reminder time picker, and three Partner notification send controls. Handles the notification permission prompt integration and the permission denied state deep-link. This is the primary configuration surface for Phase 10's notification system; the underlying scheduling (E3) and dispatch (E2) respond to state changes made here.

## Problem / Context

Without a controls surface, `ReminderSettings` properties cannot be mutated by the user and all notification features remain at default values (all disabled). The Tracker manages notifications from the Settings tab (tab 5 in the Tracker shell). This epic surfaces the full notification configuration hierarchy within that tab. The controls must reflect live `notificationAuthState` from `NotificationManager` -- showing the denied state UI when permission is revoked in iOS Settings and showing the permission prompt trigger when a first reminder is enabled from the `.notDetermined` state.

The Phase 12 Settings epic surfaces these controls within the full Settings navigation hierarchy. This epic builds the controls as standalone views that Phase 12 will compose; Phase 12 wires them into the Settings `NavigationStack`.

Sources: MVP Spec §9 (Tracker controls), MVP Spec §11 (Tracker settings: reminder preferences), Design Spec v1.1 §8 (Settings as tab 5), PHASES.md Phase 10 in-scope.

## Scope

### In Scope

- `NotificationRemindersView`: SwiftUI view presenting the three Tracker reminder toggles (`remindPeriod`, `remindOvulation`, `remindDailyLog`), advance days stepper for period reminder, and reminder time `DatePicker`
- `PartnerNotificationControlsView`: SwiftUI view presenting three Partner notification send toggles (`notifyPartnerPeriod`, `notifyPartnerSymptoms`, `notifyPartnerFertile`)
- Permission prompt trigger: when `notificationAuthState == .notDetermined` and the user enables any reminder toggle, call `NotificationManager.requestProvisionalAuthorization()` before committing the toggle state
- Permission denied state UI: when `notificationAuthState == .denied`, show an inline message -- `"Notifications are turned off for Cadence."` with a `"Turn On in Settings"` tappable link that calls `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` -- in place of the reminder toggles; toggles are not rendered
- Permission `.provisional` state: toggles are fully interactive; no prompt shown (provisional authorization is already granted)
- All toggle mutations write to `ReminderSettings` via the view model, which triggers `NotificationScheduler.syncSchedule` (E3-S5) and queues a SyncCoordinator write (E3-S1)
- Advance days stepper: integer stepper with range 1-7, label `"Days in advance"`, reflects `ReminderSettings.advanceDays`; visible only when `remindPeriod == true`
- Reminder time `DatePicker`: `DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)`, visible when any reminder toggle is `true`
- Partner notification controls: each toggle includes a descriptive label matching the notification type ("Send period prediction", "Send symptom updates", "Send fertile window reminder"); visible only when a Partner connection is active (`partner_connections` row exists with `is_paused = false`)
- If no Partner connection exists, `PartnerNotificationControlsView` is not rendered (Phase 12 Settings composes the view conditionally; E4 exposes the view and the condition for Phase 12 to use)
- All toggle controls meet 44x44pt minimum touch target per cadence-accessibility skill
- Dynamic Type: all text uses system type tokens; no fixed-size text

### Out of Scope

- Embedding these views into the full Settings NavigationStack hierarchy (PH-12)
- Partner mute controls -- surfaced in Partner Notifications tab (PH-10-E5)
- App lock, delete all data, cycle defaults, partner management (PH-12)
- Notification history list for Tracker (not a Phase 10 in-scope item; Tracker has no dedicated Notifications tab)
- Any animation on toggle state change beyond the system `Toggle` component's built-in animation

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| `ReminderSettings` SwiftData model (PH-10-E3-S1) | FS | PH-10-E3 | Open | Low |
| `NotificationScheduler.syncSchedule` (PH-10-E3-S5) | FS | PH-10-E3 | Open | Low |
| `NotificationManager.notificationAuthState` (PH-10-E1-S2) | FS | PH-10-E1 | Open | Low |
| `NotificationManager.requestProvisionalAuthorization()` (PH-10-E1-S1) | FS | PH-10-E1 | Open | Low |
| `partner_connections` data accessible in local SwiftData (Phase 8) | FS | PH-8 | Open | Low |

## Assumptions

- `NotificationRemindersView` and `PartnerNotificationControlsView` are standalone views with injected view models. Phase 12 composes them into the Settings hierarchy.
- `partner_connections` active status is read from the local SwiftData store established in Phase 8 -- no network call at render time.
- The reminder time `DatePicker` stores a `Date` in `ReminderSettings.reminderTime`; only hour and minute components are persisted.
- The "Send symptom updates" toggle label does not mention the Sex symptom specifically; it is excluded from dispatch by the Edge Function (PH-10-E2-S6) and is not surfaced to the Tracker as a separate control.
- No `CadencePrimary` token is used in these views. The §3 color table tokens are sufficient: `CadenceBackground`, `CadenceCard`, `CadenceTextPrimary`, `CadenceTextSecondary`, `CadenceTerracotta` for active toggle tint.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| System `Toggle` tint does not use `CadenceTerracotta` by default | High | Low | Apply `.tint(Color("CadenceTerracotta"))` to the `Toggle` components. |
| `openSettingsURLString` deep-link does not navigate to Cadence notification settings specifically | Low | Low | iOS routes `openSettingsURLString` to the app's Settings page; the user taps "Notifications" manually. This is the standard pattern; no deeper URL scheme is required. |
| `notificationAuthState` is stale after user grants permission in iOS Settings and returns to app | Medium | Low | `authorizationStatus` is refreshed on `applicationDidBecomeActive` (PH-10-E1-S2). Toggle UI re-renders on state change automatically via @Observable. |

---

## Stories

### S1: NotificationRemindersView -- Reminder Type Toggles

**Story ID:** PH-10-E4-S1
**Points:** 3

Build `NotificationRemindersView` displaying three system `Toggle` controls for `remindPeriod`, `remindOvulation`, and `remindDailyLog`. Each toggle is bound to the corresponding `ReminderSettings` property via the view model. Mutations trigger `NotificationScheduler.syncSchedule`. Toggle tint is `CadenceTerracotta`.

**Acceptance Criteria:**

- [ ] `NotificationRemindersView` renders three `Toggle` rows with labels: `"Period upcoming"`, `"Ovulation upcoming"`, `"Daily log reminder"`
- [ ] Each `Toggle` is bound to the corresponding `ReminderSettings` bool property via a view model binding
- [ ] Toggling any switch to `true` calls `NotificationScheduler.syncSchedule(settings:prediction:)` within the same runloop turn
- [ ] Toggling any switch to `false` calls `NotificationScheduler.syncSchedule(settings:prediction:)`, which cancels the corresponding pending notification request
- [ ] Toggle tint is `Color("CadenceTerracotta")` (no hardcoded hex)
- [ ] Each toggle row has a minimum touch target of 44x44pt
- [ ] Text labels use `body` type token; no fixed-size text
- [ ] View renders correctly at all Dynamic Type sizes from Default to Accessibility5 without text truncation

**Dependencies:** PH-10-E3-S1, PH-10-E3-S5, PH-10-E1-S2
**Notes:** This view is rendered only when `notificationAuthState != .denied`. The `.denied` state is handled in S2.

---

### S2: Permission Denied State and Prompt Integration

**Story ID:** PH-10-E4-S2
**Points:** 3

Implement the permission denied state UI within `NotificationRemindersView`. When `notificationAuthState == .denied`, the three reminder toggles are replaced by an informational row. Implement the permission prompt trigger for the `.notDetermined` state.

**Acceptance Criteria:**

- [ ] When `notificationAuthState == .denied`, reminder toggles are NOT rendered
- [ ] In their place, a `Text("Notifications are turned off for Cadence.")` in `footnote` style and `CadenceTextSecondary` color is shown, followed by a `Button("Turn On in Settings")` that calls `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
- [ ] `"Turn On in Settings"` button text uses `body` type token and `CadenceTerracotta` foreground color
- [ ] When `notificationAuthState == .notDetermined` and the user enables the first reminder toggle, `NotificationManager.requestProvisionalAuthorization()` is called before `ReminderSettings` is mutated
- [ ] If `requestProvisionalAuthorization()` returns a status of `.denied`, the toggle reverts to `false` and the denied state UI renders
- [ ] If `requestProvisionalAuthorization()` returns `.provisional` or `.authorized`, the toggle stays `true` and scheduling proceeds
- [ ] When `notificationAuthState == .provisional`, reminder toggles render normally with no permission prompt
- [ ] UI test: simulate `.denied` state via mock `NotificationManager` -- verify toggles are absent and "Turn On in Settings" button is present

**Dependencies:** PH-10-E4-S1, PH-10-E1-S1, PH-10-E1-S2
**Notes:** `URL(string: UIApplication.openSettingsURLString)!` -- the force-unwrap is acceptable here because `UIApplication.openSettingsURLString` is a compile-time constant guaranteed to be a valid URL by UIKit.

---

### S3: Advance Days Stepper and Reminder Time Picker

**Story ID:** PH-10-E4-S3
**Points:** 2

Add the advance days stepper and the reminder time `DatePicker` to `NotificationRemindersView`. The stepper appears only when `remindPeriod == true`. The time picker appears when any reminder toggle is `true`.

**Acceptance Criteria:**

- [ ] `Stepper("Days in advance: \(advanceDays)", value: $advanceDays, in: 1...7)` is rendered inline below the period toggle, visible only when `remindPeriod == true`
- [ ] `advanceDays` is bound to `ReminderSettings.advanceDays`; mutating it triggers `syncSchedule`
- [ ] Stepper enforces the range 1-7; values outside this range cannot be entered via UI or keyboard
- [ ] `DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)` is rendered below the three toggles, visible when at least one reminder toggle is `true`
- [ ] `reminderTime` is bound to `ReminderSettings.reminderTime`; mutating it triggers `syncSchedule`
- [ ] Mutating `advanceDays` reschedules the period upcoming reminder at the updated offset (verified: `getPendingNotificationRequests` returns a trigger with the new date after mutation)
- [ ] Mutating `reminderTime` reschedules the daily log reminder at the updated hour/minute (verified: `getPendingNotificationRequests` returns a trigger with the new `DateComponents`)
- [ ] Both controls are hidden (not just disabled) when their visibility condition is false

**Dependencies:** PH-10-E4-S1, PH-10-E3-S5
**Notes:** `displayedComponents: .hourAndMinute` constrains the DatePicker to time-only selection, which aligns with the `reminderTime` semantic (time of day, not a specific date).

---

### S4: Partner Notification Send Controls

**Story ID:** PH-10-E4-S4
**Points:** 2

Build `PartnerNotificationControlsView` with three `Toggle` controls for the Tracker's Partner notification send preferences: `notifyPartnerPeriod`, `notifyPartnerSymptoms`, `notifyPartnerFertile`. These controls gate whether the Edge Function dispatches each notification type.

**Acceptance Criteria:**

- [ ] `PartnerNotificationControlsView` renders three `Toggle` rows with labels: `"Send period prediction"`, `"Send symptom updates"`, `"Send fertile window reminder"`
- [ ] Each `Toggle` is bound to the corresponding `ReminderSettings` bool property
- [ ] Toggling any switch mutates `ReminderSettings` and queues a SyncCoordinator write, which syncs to Supabase `reminder_settings` (the Edge Function reads this value before dispatch)
- [ ] Toggle tint is `Color("CadenceTerracotta")`
- [ ] Each toggle row has a minimum touch target of 44x44pt
- [ ] `PartnerNotificationControlsView` is not rendered when no active Partner connection exists (the Phase 12 Settings parent view controls this condition; this view's DoD requires the conditional render to be documented in its public interface comment)
- [ ] `"Send symptom updates"` label does NOT mention "sex" or any specific symptom -- it is the generic category label only
- [ ] Text labels use `body` type token; no fixed-size text

**Dependencies:** PH-10-E3-S1, PH-10-E1-S2
**Notes:** These toggles control whether the Edge Function dispatches. They do not directly call the Edge Function -- the Edge Function reads `reminder_settings.notify_partner_*` from Supabase on each potential dispatch event. The Supabase write via SyncCoordinator is what makes the toggle effective.

---

### S5: End-to-End Notification Controls Integration

**Story ID:** PH-10-E4-S5
**Points:** 3

Wire `NotificationRemindersView` and `PartnerNotificationControlsView` into a single `NotificationSettingsView` that presents both sections. Verify the complete flow: toggle on -> schedule fires -> toggle off -> pending request removed. Verify Partner notification toggle propagates to Supabase and is read by Edge Function integration tests.

**Acceptance Criteria:**

- [ ] `NotificationSettingsView` renders `NotificationRemindersView` in a `"Reminders"` section and `PartnerNotificationControlsView` in a `"Partner Notifications"` section using a `List` with `listStyle(.insetGrouped)`
- [ ] Enabling `remindDailyLog` on a physical device results in a pending notification request retrievable via `UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler:)` within 1 second of the toggle action
- [ ] Disabling `remindDailyLog` on a physical device results in zero pending requests with identifier `"cadence.reminder.daily_log"` within 1 second of the toggle action
- [ ] Enabling `notifyPartnerPeriod` and syncing results in a `reminder_settings.notify_partner_period = true` row in Supabase for the Tracker's user ID (verified via Supabase dashboard during integration testing)
- [ ] `NotificationSettingsView` navigates correctly when pushed from a `NavigationStack` (no double-title, no layout shift)
- [ ] UI test: `NotificationSettingsView` with all toggles off -- toggle `remindPeriod` to on -- verify `NotificationScheduler.syncSchedule` was called (via mock)

**Dependencies:** PH-10-E4-S1, PH-10-E4-S2, PH-10-E4-S3, PH-10-E4-S4, PH-10-E3
**Notes:** `NotificationSettingsView` is the composable unit Phase 12 will embed in the full Settings tab hierarchy. It must be self-contained with no hard dependency on the Phase 12 `NavigationStack`.

---

## Story Point Reference

| Points | Meaning |
| --- | --- |
| 1 | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour. |
| 2 | Small. One component or function, minimal unknowns. Half a day. |
| 3 | Medium. Multiple files, some integration. One day. |
| 5 | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8 | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days. |
| 13 | Very large. Should rarely appear. If it does, consider splitting the story. A week. |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration with dependencies verified end-to-end
- [ ] Phase objective is advanced: a Tracker can enable, configure, and disable all notification types from the in-app controls
- [ ] Applicable skill constraints satisfied: cadence-design-system (no hardcoded hex, Color("CadenceTerracotta") for tint, system type tokens), cadence-accessibility (44x44pt touch targets on all toggles, Dynamic Type scaling), swiftui-production (@Observable binding pattern, no AnyView, view extraction)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] No hardcoded hex values in Swift source (no-hex-in-swift hook exits clean)
- [ ] Accessibility: all toggle rows pass 44x44pt touch target check via cadence-accessibility skill audit
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §9, §11, Design Spec v1.1 §8

## Source References

- PHASES.md: Phase 10 -- Notifications (in-scope: Tracker controls -- enable/disable per reminder type, enable/disable per Partner notification type; reminder_settings reads and writes; reminder_time field)
- MVP Spec §9: Reminders and Notifications (Tracker reminder types, Partner notification types, controls)
- MVP Spec §11: Privacy and Settings (Tracker settings: reminder preferences)
- Design Spec v1.1 §8: Information Architecture (Settings as Tracker tab 5)
- Design Spec v1.1 §14: Accessibility (44x44pt minimum touch targets, Dynamic Type)
- cadence-accessibility skill: touch target enforcement, Dynamic Type scaling
- cadence-design-system skill: Color tokens, type scale, no hardcoded hex
- swiftui-production skill: @Observable, view extraction, AnyView ban
