# Partner Notification Tab & Mute Controls

**Epic ID:** PH-10-E5
**Phase:** 10 -- Notifications
**Estimated Size:** S
**Status:** Draft

---

## Objective

Implement the Partner's Notifications tab (tab 2 in the Partner shell) with a delivered notification history list and per-category mute controls. The tab was stubbed in Phase 9; this epic delivers the full implementation. Mute preferences are persisted to the Partner's `reminder_settings` row in Supabase, which the Edge Function reads before dispatch.

## Problem / Context

The Partner Notifications tab currently renders stub content from Phase 9. The Partner has no way to mute notification categories, and the delivered notification history is not surfaced anywhere in the app. Without this epic, the Partner notification experience is one-directional and unconfigurable -- which undermines the product's trust posture. The ability for the Partner to mute categories they find intrusive is explicitly specified in MVP Spec §9 as a required control.

The mute state storage uses the Partner's own `reminder_settings` row (seeded at connection acceptance in Phase 8). The Edge Function (E2) checks the Partner's `notify_partner_*` columns before dispatch. This epic closes the loop: Partner sets mute state in-app -> mute state syncs to Supabase -> Edge Function respects it.

Sources: MVP Spec §9 (Partner mute controls, Partner notification types), Design Spec v1.1 §8 (Partner tab 2: Notifications -- push notification history for shared cycle events), PHASES.md Phase 10 in-scope (Partner controls: mute per notification category).

## Scope

### In Scope

- `PartnerNotificationsView`: SwiftUI view replacing the Phase 9 stub, structured as a `List` with two sections: "Recent notifications" and "Preferences"
- Notification history section: reads delivered notifications via `UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler:)` filtered to `cadence_notification_type` keys; displays each item as a row with: notification body text, relative timestamp (`"2 hours ago"` using `RelativeDateTimeFormatter`), and a leading SF Symbol icon determined by `cadence_notification_type`
- Empty state: when no delivered notifications exist, renders `"No notifications yet"` in `body` style, `CadenceTextSecondary`, vertically centered in the section
- Badge reset: on `PartnerNotificationsView.onAppear`, call `UNUserNotificationCenter.current().setBadgeCount(0)`
- Preferences section: three `Toggle` rows for Partner mute preferences -- `"Period predictions"`, `"Symptom updates"`, `"Fertile window"` -- bound to the Partner's `ReminderSettings.notifyPartnerPeriod`, `.notifyPartnerSymptoms`, `.notifyPartnerFertile` respectively (inverted semantics: `true` = receive, `false` = muted)
- Toggle mutations write to the Partner's `ReminderSettings` SwiftData row and queue a SyncCoordinator write, syncing to Supabase `reminder_settings` for Edge Function consumption
- Partner's `ReminderSettings` row is seeded with all three `notify_partner_*` flags = `true` at connection acceptance (Phase 8); if no row exists, `PartnerNotificationsView` creates one with defaults on first render
- All toggle controls meet 44x44pt minimum touch target per cadence-accessibility skill
- `bell.fill` SF Symbol icon in the tab bar, tinted `CadenceTerracotta` when active (matches Design Spec v1.1 §9 Partner tab icon spec)

### Out of Scope

- Tracker notification controls (PH-10-E4)
- Full Partner Settings tab (PH-12)
- Server-side notification history persistence -- delivered notification history is read from `UNUserNotificationCenter.getDeliveredNotifications()` only; no `notification_history` Supabase table is created
- Notification content extensions or rich notification formatting (post-beta)
- Notification action buttons (post-beta)
- AlarmKit (not used for any Partner notification type)

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| Partner 3-tab shell with Notifications tab stub (Phase 9) | FS | PH-9 | Open | Low |
| `ReminderSettings` SwiftData model (PH-10-E3-S1) | FS | PH-10-E3 | Open | Low |
| SyncCoordinator write queue for Partner reminder_settings writes (Phase 7) | FS | PH-7 | Resolved | Low |
| Edge Function mute check against Partner's notify_partner_* columns (PH-10-E2) | SS | PH-10-E2 | Open | Low |
| `NotificationManager` device token registered for Partner device (PH-10-E1) | FS | PH-10-E1 | Open | Low |
| Partner connection active (Phase 8) | FS | PH-8 | Open | Low |

## Assumptions

- The Partner's `reminder_settings` row is created with all `notify_partner_*` flags = `true` when the Partner accepts a connection invitation in Phase 8. If the Phase 8 implementation did not seed this row, E5-S3 seeds it on first `PartnerNotificationsView` render.
- `UNUserNotificationCenter.getDeliveredNotifications()` returns all notifications delivered to the device since the last `removeAllDeliveredNotifications()` call. For the beta cohort, this history is sufficient. No date-range filtering is applied.
- `cadence_notification_type` is a key present in the `userInfo` dictionary of all Cadence notifications (set in PH-10-E2-S3 payload construction). If a delivered notification lacks this key, it is filtered out of the history list.
- Notification history rows are read-only. No swipe-to-delete or clear-all action is implemented in this phase.
- The `RelativeDateTimeFormatter` output is locale-dependent and acceptable for the beta cohort. No custom date formatting is applied.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `getDeliveredNotifications` returns an empty array immediately after a push arrives (race condition on iOS) | Low | Low | History refreshes on `onAppear` -- if the tab is already visible when a notification arrives, a `onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))` refresh triggers. |
| Partner's `reminder_settings` row absent (Phase 8 did not seed it) | Medium | Low | E5-S3 seeds a default row on first render. The worst case is the Partner receives one notification batch before muting -- acceptable for beta. |
| Mute toggle propagation delay: Partner mutes, Edge Function fires before Supabase write completes | Low | Low | SyncCoordinator queues the write immediately after local SwiftData mutation. Under normal connectivity, the write reaches Supabase within seconds. The Edge Function reads on each dispatch event (no caching). For beta latency is acceptable. |

---

## Stories

### S1: Partner Notification History List

**Story ID:** PH-10-E5-S1
**Points:** 3

Replace the Phase 9 Notifications tab stub with `PartnerNotificationsView`. Implement the delivered notification history section by reading from `UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler:)`. Filter to Cadence notifications using the `cadence_notification_type` key. Display each as a row with icon, body text, and relative timestamp.

**Acceptance Criteria:**

- [ ] `PartnerNotificationsView` replaces the Phase 9 stub and renders when the Partner taps tab 2 in the Partner shell
- [ ] On `onAppear`, `UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler:)` is called and the result is stored in a `@State` array
- [ ] Notifications are filtered to those whose `request.content.userInfo["cadence_notification_type"]` is non-nil
- [ ] Each history row renders: a leading SF Symbol icon (period prediction: `calendar`, symptom: `heart`, fertile: `leaf`; all tinted `CadenceTerracotta`), the notification `body` string, and a relative timestamp using `RelativeDateTimeFormatter` (`unitsStyle: .full`, `dateTimeStyle: .named`)
- [ ] Notifications are sorted by `date` descending (most recent first)
- [ ] When `getDeliveredNotifications` returns an empty array, an empty state renders: `Text("No notifications yet")` in `body` style, `CadenceTextSecondary`, vertically centered in the list section
- [ ] History list uses `LazyVStack` within a `List` section to avoid pre-rendering off-screen rows (per swiftui-production skill)
- [ ] Refreshes on `applicationDidBecomeActive` notification (Partner switches back to the app after receiving a push)

**Dependencies:** PH-9 (Partner shell with tab 2 stub), PH-10-E2 (delivered notifications must have `cadence_notification_type` in userInfo)
**Notes:** SF Symbol icon selection per notification type: `cadence_notification_type = "period_prediction"` -> `calendar`, `"symptom_logged"` -> `heart`, `"fertile_window"` -> `leaf.fill`. All system symbols, no custom assets required.

---

### S2: Badge Reset on Tab Open

**Story ID:** PH-10-E5-S2
**Points:** 1

Clear the app badge count when the Partner opens the Notifications tab. This prevents stale badge counts after the Partner reviews their notifications.

**Acceptance Criteria:**

- [ ] `PartnerNotificationsView.onAppear` calls `UNUserNotificationCenter.current().setBadgeCount(0)` (iOS 17+ API; use `UIApplication.shared.applicationIconBadgeNumber = 0` as the `#available` fallback for iOS 16 if needed, but the primary target is iOS 26)
- [ ] After the call, the app icon badge count is 0 (verified on physical device: badge visible before tab open, absent after)
- [ ] `setBadgeCount(0)` is called only within `PartnerNotificationsView`, not in other tab views

**Dependencies:** PH-10-E5-S1
**Notes:** `UNUserNotificationCenter.setBadgeCount(_:)` requires notification authorization. If authorization is `.denied`, the call silently no-ops. No error handling is required.

---

### S3: Partner Mute State Persistence

**Story ID:** PH-10-E5-S3
**Points:** 3

Ensure the Partner's `ReminderSettings` SwiftData row is seeded at first render if absent. Bind the mute toggle state to the Partner's `notify_partner_*` properties and queue Supabase writes via SyncCoordinator on mutation.

**Acceptance Criteria:**

- [ ] On `PartnerNotificationsView` first render, if no `ReminderSettings` row exists for the Partner's `userId` in SwiftData, a new row is inserted with `notifyPartnerPeriod = true`, `notifyPartnerSymptoms = true`, `notifyPartnerFertile = true` and all other fields at defaults
- [ ] Mutating any `notify_partner_*` property on the Partner's `ReminderSettings` row triggers a SyncCoordinator queued write to Supabase `reminder_settings` within the same runloop turn
- [ ] After the write is processed, querying `reminder_settings` in Supabase for the Partner's `user_id` reflects the updated value (verified via Supabase dashboard during integration testing)
- [ ] If a `ReminderSettings` row already exists (seeded in Phase 8), `PartnerNotificationsView` reads it without creating a duplicate row
- [ ] Unit test: render `PartnerNotificationsView` with mock SwiftData context containing no `ReminderSettings` row -- verify a row is inserted with all `notify_partner_*` = true after render

**Dependencies:** PH-10-E3-S1 (ReminderSettings model), PH-7 (SyncCoordinator)
**Notes:** The `ReminderSettings` row seeded here is separate from any Tracker's row. The Partner's row uses the same columns; the Edge Function distinguishes between rows by `user_id` when checking mute state.

---

### S4: Partner Mute Controls UI

**Story ID:** PH-10-E5-S4
**Points:** 2

Add a "Preferences" section to `PartnerNotificationsView` containing three `Toggle` controls for per-category mute. Each toggle is bound to the Partner's `ReminderSettings` via the view model.

**Acceptance Criteria:**

- [ ] `PartnerNotificationsView` includes a `"Preferences"` section below `"Recent Notifications"` with three toggles: `"Period predictions"`, `"Symptom updates"`, `"Fertile window"`
- [ ] Each toggle is bound to the Partner's `ReminderSettings.notifyPartnerPeriod`, `.notifyPartnerSymptoms`, `.notifyPartnerFertile` respectively
- [ ] Toggle is `true` = receive notifications for this category; `false` = muted (toggle label text is phrased as a preference to receive, not a "mute" label)
- [ ] Toggle tint is `Color("CadenceTerracotta")`
- [ ] Each toggle row has a minimum touch target of 44x44pt
- [ ] Toggling any switch to `false` and then triggering the corresponding dispatch condition (via integration test with the Edge Function in sandbox) results in NO notification being delivered to the device
- [ ] Toggling any switch back to `true` and re-triggering the dispatch condition results in a notification delivered to the device
- [ ] Text labels use `body` type token; `"Symptom updates"` label does not mention the Sex symptom specifically

**Dependencies:** PH-10-E5-S3, PH-10-E2 (Edge Function reads mute state)
**Notes:** The mute control end-to-end test (last two acceptance criteria) requires the Edge Function to be deployed to the Supabase sandbox project and a physical device with a valid APNs token registered. This is an integration test and may be conducted outside the standard unit test suite.

---

## Story Point Reference

| Points | Meaning |
| --- | --- |
| 1 | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour. |
| 2 | Small. One component or function, minimal unknowns. Half a day. |
| 3 | Medium. Multiple files, some integration. One day. |
| 5 | Significant. Cross-cutting concern, multiple components, multiple testing required. 2-3 days. |
| 8 | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days. |
| 13 | Very large. Should rarely appear. If it does, consider splitting the story. A week. |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration with dependencies verified end-to-end
- [ ] Phase objective is advanced: Partner can view notification history, mute per-category, and mute state is respected by the Edge Function
- [ ] Applicable skill constraints satisfied: cadence-design-system (no hardcoded hex, Color("CadenceTerracotta"), system type tokens), cadence-accessibility (44x44pt touch targets, Dynamic Type), swiftui-production (LazyVStack for history list, no AnyView), cadence-navigation (Partner Notifications tab replaces stub correctly, NavigationStack isolation from Tracker tree maintained)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] No hardcoded hex values in Swift source (no-hex-in-swift hook exits clean)
- [ ] End-to-end mute test: Partner mutes "Period predictions" -> Tracker's period prediction dispatch condition fires -> no notification delivered to Partner device
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §9 Partner mute controls, Design Spec v1.1 §8 Partner tab 2 spec

## Source References

- PHASES.md: Phase 10 -- Notifications (in-scope: Partner controls -- mute per notification category; notification payload content)
- MVP Spec §9: Reminders and Notifications (Partner mute controls, Partner notification types)
- Design Spec v1.1 §8: Information Architecture (Partner tab 2: Notifications -- push notification history for shared cycle events)
- Design Spec v1.1 §9: Tab Bar Icons (Partner Notifications: bell / bell.fill, active: bell.fill tinted CadenceTerracotta)
- cadence-navigation skill: Partner shell isolation, NavigationStack pattern
- cadence-design-system skill: Color tokens, type scale
- cadence-accessibility skill: 44x44pt touch targets, Dynamic Type
- swiftui-production skill: LazyVStack, @Observable binding pattern
