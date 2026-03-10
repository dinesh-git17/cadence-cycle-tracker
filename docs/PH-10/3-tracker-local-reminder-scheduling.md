# Tracker Local Reminder Scheduling

**Epic ID:** PH-10-E3
**Phase:** 10 -- Notifications
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the `reminder_settings` SwiftData model and the `NotificationScheduler` service that translates reminder preferences into `UNCalendarNotificationTrigger` requests for all three Tracker reminder types: period upcoming, ovulation upcoming, and daily log reminder. When Tracker settings change, the scheduler cancels stale pending requests and reschedules. The Tracker receives reminders entirely via local notifications -- no server round-trip is required.

## Problem / Context

The Tracker's three reminder types (period upcoming, ovulation upcoming, daily log reminder) are local iOS notifications scheduled via `UNUserNotificationCenter`. They require the `reminder_settings` data model (which also drives the Edge Function in E2 and the controls UI in E4), accurate prediction dates from `prediction_snapshots` (established in Phase 3), and a scheduling service that fires only when notification authorization is confirmed.

Without this epic, no Tracker reminder fires. The daily log reminder is the primary habit-formation mechanism for sustained Tracker engagement. Period and ovulation reminders are the primary value-add that justifies notification permission.

Sources: MVP Spec §9 (all three Tracker reminder types, controls), PHASES.md Phase 10 in-scope.

## Scope

### In Scope

- `ReminderSettings` SwiftData model: `id` (UUID), `userId` (String), `remindPeriod` (Bool, default false), `remindOvulation` (Bool, default false), `remindDailyLog` (Bool, default false), `notifyPartnerPeriod` (Bool, default false), `notifyPartnerSymptoms` (Bool, default false), `notifyPartnerFertile` (Bool, default false), `reminderTime` (Date, default 9:00 AM local time, time component only used for scheduling), `advanceDays` (Int, default 3, range 1-7)
- `ReminderSettings` SyncCoordinator integration: writes queue to Supabase `reminder_settings` table after local SwiftData commit
- `NotificationScheduler` service (`@Observable`, conforming to `NotificationScheduling` protocol for test injection)
- Period upcoming reminder: `UNCalendarNotificationTrigger` computed from `prediction_snapshots.next_period_start` minus `advanceDays` days; fires at `reminderTime` on that date; notification body: `"Your period is expected in {advanceDays} days"`
- Ovulation upcoming reminder: `UNCalendarNotificationTrigger` set to the day before `prediction_snapshots.ovulation_date` at `reminderTime`; notification body: `"Ovulation may be tomorrow"`; fires only when `prediction_snapshots.ovulation_date` is non-null
- Daily log reminder: recurring `UNCalendarNotificationTrigger` with `DateComponents` from `reminderTime` hour and minute; `repeats: true`; fires daily; notification body: `"Take a moment to log how you're feeling today"`
- Notification identifier naming: `"cadence.reminder.period"`, `"cadence.reminder.ovulation"`, `"cadence.reminder.daily_log"` -- used for targeted cancellation
- Rescheduling on mutation: when any `ReminderSettings` property changes, `NotificationScheduler` cancels existing pending requests for affected types and reschedules with updated parameters
- Cancellation when reminder type disabled: toggling `remindPeriod = false` removes the pending `"cadence.reminder.period"` request immediately
- No scheduling when `authorizationStatus` is `.denied` -- scheduler checks `NotificationManager.notificationAuthState` before calling `add()`
- Authorization upgrade trigger: if `authorizationStatus` is `.notDetermined` when the user first enables a reminder type, `NotificationManager.requestProvisionalAuthorization()` is called

### Out of Scope

- Notification controls UI -- toggles, time picker, advance days picker (PH-10-E4)
- Partner push dispatch -- the Edge Function handles server-sent Partner notifications (PH-10-E2)
- Notification permission denied state UI (PH-10-E4-S2)
- Prediction date generation -- provided by Phase 3 prediction engine via `prediction_snapshots`
- AlarmKit -- all Tracker reminders use standard `UNCalendarNotificationTrigger`

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| `reminder_settings` Supabase table deployed (Phase 1) | FS | PH-1 | Resolved | Low |
| `reminder_settings.advance_days` column migration (PH-10-E2-S1) | FS | PH-10-E2 | Open | Low |
| `prediction_snapshots` SwiftData model with `nextPeriodStart` and `ovulationDate` (Phase 3) | FS | PH-3 | Resolved | Low |
| SyncCoordinator write queue operational (Phase 7) | FS | PH-7 | Resolved | Low |
| `NotificationManager` with `NotificationManaging` protocol (PH-10-E1-S1) | FS | PH-10-E1 | Open | Low |
| `UNAuthorizationStatus` check via `NotificationManager.notificationAuthState` (PH-10-E1-S2) | FS | PH-10-E1 | Open | Low |

## Assumptions

- `ReminderSettings` has exactly one row per user in both SwiftData (local) and Supabase. Seeding occurs at account creation with all reminders disabled and `reminderTime` defaulting to 9:00 AM.
- The `reminderTime` field stores a `Date` in SwiftData; only the hour and minute components are used for `UNCalendarNotificationTrigger` `DateComponents`. The date portion is ignored.
- Scheduling uses the device's local timezone. `TimeZone.current` is used for `DateComponents`; no UTC conversion is applied to `reminderTime`.
- `prediction_snapshots.nextPeriodStart` and `prediction_snapshots.ovulationDate` are read from local SwiftData; no network call is made during scheduling.
- If `prediction_snapshots` contains no row (no predictions available yet), period and ovulation reminders are not scheduled. No error is surfaced to the user; the toggle remains visually enabled and schedules as soon as a prediction is available.
- Rescheduling on settings mutation is triggered by `@Observable` property observation in the view model; the scheduler is not polled.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `prediction_snapshots.nextPeriodStart` is null (no predictions yet) | Medium | Low | `NotificationScheduler` skips scheduling for period reminder silently; reschedules when the prediction engine produces a non-null date. No user-visible error. |
| Reminder fires on the wrong date due to timezone DST transition | Low | Medium | `UNCalendarNotificationTrigger` with `DateComponents` in `TimeZone.current` handles DST correctly; the OS adjusts delivery time automatically. |
| Daily log reminder accumulates duplicate notifications if rescheduling fires before cancellation completes | Low | Low | Cancellation of `"cadence.reminder.daily_log"` via `removePendingNotificationRequests(withIdentifiers:)` is synchronous from the caller's perspective before `add()` is called. |
| User disables notification permission in iOS Settings after reminders are scheduled | Medium | Low | Pending notifications are silently dropped by iOS when permission is revoked. On next `applicationDidBecomeActive`, `notificationAuthState` refreshes to `.denied` and the scheduler halts future scheduling. |

---

## Stories

### S1: ReminderSettings SwiftData Model and Sync Integration

**Story ID:** PH-10-E3-S1
**Points:** 3

Define the `ReminderSettings` SwiftData `@Model` class with all required properties. Integrate with SyncCoordinator so that any local mutation is queued for Supabase write. Read the user's existing row from Supabase on first authenticated launch (initial pull, per cadence-sync skill initial data pull contract).

**Acceptance Criteria:**

- [ ] `ReminderSettings` is a `@Model`-annotated SwiftData class with properties: `id: UUID`, `userId: String`, `remindPeriod: Bool = false`, `remindOvulation: Bool = false`, `remindDailyLog: Bool = false`, `notifyPartnerPeriod: Bool = false`, `notifyPartnerSymptoms: Bool = false`, `notifyPartnerFertile: Bool = false`, `reminderTime: Date` (defaults to 9:00 AM local), `advanceDays: Int = 3`
- [ ] `ReminderSettings` is inserted into `ModelContainer` alongside existing Phase 3 SwiftData models without migration errors
- [ ] Mutating any `ReminderSettings` property triggers a SyncCoordinator queued write to Supabase `reminder_settings` within the same runloop turn (local-first, no async delay before write is queued)
- [ ] On first authenticated launch after Phase 10 is deployed, the initial pull from Supabase populates the local `ReminderSettings` row if one exists
- [ ] If no `reminder_settings` row exists in Supabase for the user (new user), a default row is inserted locally with all reminders disabled and synced on next write queue flush
- [ ] Unit test: mutate `remindPeriod` on a `ReminderSettings` instance injected into a mock SyncCoordinator -- verify `enqueueWrite` is called

**Dependencies:** PH-1 (reminder_settings table), PH-10-E2-S1 (advance_days column), PH-7 (SyncCoordinator)
**Notes:** `ReminderSettings.reminderTime` stores a `Date` value. Only `hour` and `minute` components are consumed by `NotificationScheduler`. The `advanceDays` property maps to the `advance_days` column added in PH-10-E2-S1 -- this story depends on that migration being applied before the initial pull occurs.

---

### S2: Period Upcoming Reminder Scheduling

**Story ID:** PH-10-E3-S2
**Points:** 3

Implement `NotificationScheduler.schedulePeriodReminder(settings: ReminderSettings, prediction: PredictionSnapshot)`. Compute the target date as `prediction.nextPeriodStart` minus `settings.advanceDays` calendar days. Schedule a `UNCalendarNotificationTrigger` using `DateComponents` from the computed date at the hour/minute of `settings.reminderTime` in `TimeZone.current`. Use identifier `"cadence.reminder.period"`.

**Acceptance Criteria:**

- [ ] `UNCalendarNotificationRequest` with identifier `"cadence.reminder.period"` is added via `UNUserNotificationCenter.current().add(_:)`
- [ ] The trigger fires at `(nextPeriodStart - advanceDays days)` at the hour and minute of `reminderTime` in the device's local timezone
- [ ] Notification content: `title = "Cadence"`, `body = "Your period is expected in {advanceDays} days"`, `sound = .default`
- [ ] If `prediction.nextPeriodStart` is nil, no request is added and no error is thrown
- [ ] If `settings.remindPeriod = false`, no request is added
- [ ] If `notificationAuthState` is `.denied`, no request is added
- [ ] If a pending request with identifier `"cadence.reminder.period"` already exists, it is replaced (iOS behavior: `add()` with duplicate identifier replaces the existing request)
- [ ] Unit test: mock `PredictionSnapshot` with `nextPeriodStart = Date().advanced(by: 5 * 86400)` and `advanceDays = 3` -- verify trigger date is 2 days from now at `reminderTime` hour/minute

**Dependencies:** PH-10-E3-S1, PH-10-E1-S1, PH-10-E1-S2
**Notes:** iOS replaces a pending notification request when `add()` is called with an existing identifier. Explicit cancellation before rescheduling is not required for period/ovulation reminders, but is preferred for clarity. Rescheduling logic in S5 handles the explicit cancellation path.

---

### S3: Ovulation Upcoming Reminder Scheduling

**Story ID:** PH-10-E3-S3
**Points:** 2

Implement `NotificationScheduler.scheduleOvulationReminder(settings: ReminderSettings, prediction: PredictionSnapshot)`. Target date is the day before `prediction.ovulationDate`. Fires at `settings.reminderTime`. Identifier: `"cadence.reminder.ovulation"`.

**Acceptance Criteria:**

- [ ] `UNCalendarNotificationRequest` with identifier `"cadence.reminder.ovulation"` is added
- [ ] The trigger fires at `(ovulationDate - 1 day)` at the hour and minute of `reminderTime` in the device's local timezone
- [ ] Notification content: `title = "Cadence"`, `body = "Ovulation may be tomorrow"`, `sound = .default`
- [ ] If `prediction.ovulationDate` is nil, no request is added and no error is thrown
- [ ] If `settings.remindOvulation = false`, no request is added
- [ ] If `notificationAuthState` is `.denied`, no request is added
- [ ] Unit test: mock `PredictionSnapshot` with `ovulationDate = Date().advanced(by: 3 * 86400)` -- verify trigger date is 2 days from now

**Dependencies:** PH-10-E3-S1, PH-10-E1-S2
**Notes:** The advance offset for ovulation is hardcoded to 1 day (not configurable). Only the period upcoming reminder has a configurable `advanceDays`. This matches PHASES.md in-scope which specifies configurable advance days for period only.

---

### S4: Daily Log Reminder Scheduling

**Story ID:** PH-10-E3-S4
**Points:** 2

Implement `NotificationScheduler.scheduleDailyLogReminder(settings: ReminderSettings)`. Schedule a recurring `UNCalendarNotificationTrigger` using `DateComponents` with only `hour` and `minute` set from `settings.reminderTime`. `repeats: true`. Identifier: `"cadence.reminder.daily_log"`.

**Acceptance Criteria:**

- [ ] `UNCalendarNotificationRequest` with identifier `"cadence.reminder.daily_log"` is added with `repeats: true`
- [ ] The trigger fires daily at the hour and minute extracted from `settings.reminderTime` in the device's local timezone
- [ ] Notification content: `title = "Cadence"`, `body = "Take a moment to log how you're feeling today"`, `sound = .default`
- [ ] If `settings.remindDailyLog = false`, no request is added
- [ ] If `notificationAuthState` is `.denied`, no request is added
- [ ] `DateComponents` set on the trigger contains only `hour` and `minute`; no `day`, `month`, or `year` components (which would make it a one-time trigger)
- [ ] Unit test: mock `reminderTime` as 8:30 AM -- verify trigger `DateComponents.hour == 8` and `DateComponents.minute == 30` and trigger `repeats == true`

**Dependencies:** PH-10-E3-S1, PH-10-E1-S2
**Notes:** The daily log reminder is the highest-retention notification in Cadence. It fires regardless of whether the user has already logged today -- the OS delivers it and the app handles any "already logged" logic in the notification tap handler (if implemented post-beta). For beta, tapping the notification opens the app to the Log tab via the standard `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)` default behavior.

---

### S5: Reminder Rescheduling and Cancellation on Settings Mutation

**Story ID:** PH-10-E3-S5
**Points:** 3

Implement `NotificationScheduler.syncSchedule(settings: ReminderSettings, prediction: PredictionSnapshot?)`. This method is called whenever `ReminderSettings` mutates. It cancels all three pending reminder identifiers using `removePendingNotificationRequests(withIdentifiers:)` and reschedules only the reminders with their corresponding `remind*` flag set to `true`.

**Acceptance Criteria:**

- [ ] `syncSchedule` calls `UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cadence.reminder.period", "cadence.reminder.ovulation", "cadence.reminder.daily_log"])` before scheduling
- [ ] After cancellation, `schedulePeriodReminder` is called only if `settings.remindPeriod == true`
- [ ] After cancellation, `scheduleOvulationReminder` is called only if `settings.remindOvulation == true`
- [ ] After cancellation, `scheduleDailyLogReminder` is called only if `settings.remindDailyLog == true`
- [ ] `syncSchedule` is called by the view model when `ReminderSettings.reminderTime` changes (verified: pending daily log reminder reflects new time within the same app session)
- [ ] `syncSchedule` is called by the view model when `ReminderSettings.advanceDays` changes (verified: period reminder fires on the updated offset date, not the old one)
- [ ] `syncSchedule` is called when a reminder toggle changes from `true` to `false` (verified: `getPendingNotificationRequests` returns no request for the disabled identifier after the call)
- [ ] Unit test: call `syncSchedule` with `remindPeriod = true`, `remindOvulation = false`, `remindDailyLog = true` -- verify two requests added, zero for ovulation

**Dependencies:** PH-10-E3-S2, PH-10-E3-S3, PH-10-E3-S4
**Notes:** Calling `removePendingNotificationRequests` for non-existent identifiers is safe; iOS silently ignores the no-op. The full cancel-and-reschedule approach (rather than selective updates) avoids stale-identifier bugs when `reminderTime` or `advanceDays` changes.

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
- [ ] Phase objective is advanced: all three Tracker reminder types schedule, deliver, and cancel correctly on a physical device
- [ ] Applicable skill constraints satisfied: cadence-data-layer (SwiftData model, offline-first write path), cadence-sync (SyncCoordinator write queue for reminder_settings mutations), cadence-testing (NotificationScheduling protocol for test injection, unit tests for all scheduling paths)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Physical device test: period upcoming reminder delivers at correct date/time for a prediction 5 days out with `advanceDays = 2`
- [ ] Physical device test: daily log reminder fires daily at `reminderTime` with `repeats: true`
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §9 reminder types and PHASES.md in-scope

## Source References

- PHASES.md: Phase 10 -- Notifications (in-scope: Tracker reminder types, configurable advance days, reminder_time field, reminder_settings table reads and writes)
- MVP Spec §9: Reminders and Notifications (Tracker reminder types, controls)
- MVP Spec Data Model: `reminder_settings` table schema
- cadence-data-layer skill: SwiftData model conventions, offline-first write path
- cadence-sync skill: SyncCoordinator write queue, initial data pull
- cadence-testing skill: @Observable DI, NotificationScheduling protocol contract
