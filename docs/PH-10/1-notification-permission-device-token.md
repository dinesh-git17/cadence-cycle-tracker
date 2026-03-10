# Notification Permission & Device Token Infrastructure

**Epic ID:** PH-10-E1
**Phase:** 10 -- Notifications
**Estimated Size:** M
**Status:** Draft

---

## Objective

Establish the iOS push authorization pipeline and device token lifecycle management required by all subsequent Phase 10 epics. Without a registered, persisted device token and a known authorization state, neither Tracker reminders nor Partner push notifications can deliver. This epic produces the `NotificationManager` service, the `device_tokens` Supabase table, and the complete authorization state machine.

## Problem / Context

The app has no push notification infrastructure. `UNUserNotificationCenter` is unconfigured, device tokens are not registered with the APNs backend, and there is no Supabase table to store them. Phase 10 requires both local notifications (Tracker reminders, E3) and remote push dispatch (Partner notifications, E2/E5). Both paths share the same authorization gate and device token registration flow, which must exist before either can function.

The `device_tokens` table is not present in the schema deployed in Phase 1 -- it is a new addition scoped to this phase. The APNs token environment (sandbox vs. production) must be tracked per row because sandbox and production tokens are not interchangeable.

Sources: MVP Spec §9 (reminders and notifications), cadence-supabase skill (Edge Function APNS dispatch pattern).

## Scope

### In Scope

- `NotificationManager` singleton conforming to a protocol for testability, managing all `UNUserNotificationCenter` interactions
- Provisional authorization request (`[.alert, .sound, .badge, .provisional]`) -- does not trigger system dialog; enables silent delivery immediately
- Authorization state machine handling all five `UNAuthorizationStatus` cases: `.notDetermined`, `.provisional`, `.authorized`, `.denied`, `.ephemeral`
- `device_tokens` Supabase schema migration: `id` (uuid PK), `user_id` (uuid FK auth.users ON DELETE CASCADE), `apns_token` (text NOT NULL), `environment` (text CHECK IN ('sandbox', 'production')), `created_at` (timestamptz), `updated_at` (timestamptz), UNIQUE (user_id, apns_token)
- RLS on `device_tokens`: owner write-only via `user_id = auth.uid()`; service role reads for Edge Function dispatch
- `UIApplicationDelegate` hooks: `didRegisterForRemoteNotificationsWithDeviceToken` and `didFailToRegisterForRemoteNotificationsWithError`
- Device token hex string conversion from `Data` (`map { String(format: "%02.2hhx", $0) }.joined()`)
- Token write to `device_tokens` via SyncCoordinator (local-first, queued); comparison against last-cached token before issuing a Supabase write
- Forced token refresh: re-call `registerForRemoteNotifications()` on a 7-day interval to catch server-side token invalidation; compare before writing
- `registerForRemoteNotifications()` called on main thread only after authorization status confirms `.authorized` or `.provisional`

### Out of Scope

- Tracker reminder scheduling (PH-10-E3)
- Partner notification dispatch business logic (PH-10-E2)
- Notification controls UI (PH-10-E4)
- Partner Notifications tab UI (PH-10-E5)
- Token revocation on 410 Unregistered response -- handled by the Edge Function (PH-10-E2-S4)
- AlarmKit integration -- not in MVP scope; standard `UNUserNotificationCenter` is the delivery mechanism for all Cadence notification types in this release

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| Supabase project live with auth.users table | FS | PH-1 | Resolved | Low |
| SyncCoordinator write queue operational | FS | PH-7 | Resolved | Low |
| Authenticated user session available at token registration time | FS | PH-2 | Resolved | Low |
| Xcode project configured with Push Notifications capability and APS environment entitlement | External | Apple Developer Portal | Open | Medium |
| APNs p8 key + Team ID + Key ID provisioned in Apple Developer Portal | External | Apple Developer Portal | Open | High |

## Assumptions

- The app targets iOS 26. `UNAuthorizationStatus.ephemeral` (App Clips) is handled defensively but will never fire in practice for the Cadence app.
- One device token per authenticated user per device is sufficient for the beta. Multi-device support per user is architecturally supported by the UNIQUE (user_id, apns_token) constraint.
- The Xcode project's Push Notifications capability and `aps-environment` entitlement (`development`/`production`) will be configured by Dinesh before E1-S4 is tested end-to-end.
- Token environment detection uses `Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil` as a heuristic for sandbox vs. production; the exact detection method may be adjusted per the active provisioning profile.
- `NotificationManager` is injected via the @Observable store pattern consistent with `cadence-testing` skill requirements (no singleton access in tests).

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| APNs p8 key not provisioned before implementation | High | High | E1-S4 can be built and unit-tested with a mock `NotificationManager`; end-to-end device testing gates on key availability. Flag to Dinesh at phase start. |
| `didFailToRegisterForRemoteNotificationsWithError` fires on first launch in simulator | High | Low | Simulator does not support APNs registration. `NotificationManager` treats simulator failures as no-ops and logs the error. Physical device testing is required for E1-S4 end-to-end. |
| User denies notification permission on first prompt | Medium | Medium | Provisional authorization never triggers the system dialog. Explicit upgrade prompt (shown after first value-add event) is covered in E4-S2. Denial state surfaces a "Enable in Settings" affordance per E4-S2. |
| Token cache stale after device restore | Low | Medium | Forced 7-day re-registration plus comparison against stored token before write covers this case. |

---

## Stories

### S1: NotificationManager Service -- Provisional Authorization

**Story ID:** PH-10-E1-S1
**Points:** 3

Implement `NotificationManager` as an `@Observable` class conforming to a `NotificationManaging` protocol. On first authenticated app launch (after sign-in, before any reminder toggle), request provisional authorization using `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional])`. Store the returned `Bool` and any `Error`. Expose `authorizationStatus: UNAuthorizationStatus` as a published property, refreshed on each `requestAuthorization` completion and on `applicationDidBecomeActive`.

**Acceptance Criteria:**

- [ ] `NotificationManager.requestProvisionalAuthorization()` calls `UNUserNotificationCenter.current().requestAuthorization(options:)` with `.provisional` included in the options set
- [ ] The system permission dialog does NOT appear during provisional authorization (verified on a physical device with a fresh install)
- [ ] `NotificationManager.authorizationStatus` reflects `.provisional` after successful provisional grant
- [ ] `NotificationManager` conforms to a `NotificationManaging` protocol; a `MockNotificationManager` can be injected in unit tests
- [ ] No call to `registerForRemoteNotifications()` is made within this story -- that is S4

**Dependencies:** None
**Notes:** Provisional authorization is the correct initial strategy for a health app. The system delivers silently to Notification Center without user consent. After the user sees a first notification and taps it, the OS upgrades the grant to `.authorized` automatically.

---

### S2: Authorization State Machine

**Story ID:** PH-10-E1-S2
**Points:** 3

Implement handling for all five `UNAuthorizationStatus` states within `NotificationManager`. Expose a computed `NotificationAuthState` enum (cases: `undetermined`, `provisional`, `authorized`, `denied`, `restricted`) derived from `UNAuthorizationStatus`. This enum drives UI in E4.

**Acceptance Criteria:**

- [ ] `NotificationManager.notificationAuthState` returns `.provisional` when `UNAuthorizationStatus == .provisional`
- [ ] `NotificationManager.notificationAuthState` returns `.authorized` when `UNAuthorizationStatus == .authorized`
- [ ] `NotificationManager.notificationAuthState` returns `.denied` when `UNAuthorizationStatus == .denied`
- [ ] `NotificationManager.notificationAuthState` returns `.undetermined` when `UNAuthorizationStatus == .notDetermined`
- [ ] `NotificationManager.notificationAuthState` returns `.restricted` when `UNAuthorizationStatus == .ephemeral` (treated as restricted for UI purposes)
- [ ] `authorizationStatus` is refreshed by calling `UNUserNotificationCenter.current().getNotificationSettings()` on each `applicationDidBecomeActive` notification
- [ ] Unit tests cover all five state mappings using `MockNotificationManager`

**Dependencies:** PH-10-E1-S1
**Notes:** `.denied` state drives E4-S2 (deep-link to iOS Settings). `.authorized` and `.provisional` both allow scheduling in E3.

---

### S3: device_tokens Supabase Schema Migration

**Story ID:** PH-10-E1-S3
**Points:** 2

Apply a new Supabase migration that creates the `device_tokens` table. The table must not conflict with any column in the existing 8-table schema deployed in Phase 1.

**Acceptance Criteria:**

- [ ] Migration applies cleanly against the live Supabase project (`supabase db push` exits 0 or equivalent)
- [ ] `device_tokens` table exists with columns: `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, `apns_token text NOT NULL`, `environment text NOT NULL CHECK (environment IN ('sandbox', 'production'))`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()`
- [ ] UNIQUE constraint on `(user_id, apns_token)` is present
- [ ] RLS enabled on `device_tokens`
- [ ] RLS policy: authenticated users can INSERT and UPDATE rows where `user_id = auth.uid()`; no SELECT or DELETE for user role (Edge Function uses service role)
- [ ] Migration is idempotent: running it twice does not error

**Dependencies:** PH-1 (Supabase project and auth.users table exist)
**Notes:** No SELECT policy for the user role is intentional -- device tokens are opaque to the client after write. The Edge Function accesses via service role key, bypassing RLS.

---

### S4: Device Token Registration and Supabase Write

**Story ID:** PH-10-E1-S4
**Points:** 5

Wire `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` and `didFailToRegisterForRemoteNotificationsWithError`. Convert the token `Data` to a lowercase hex string. Compare against the last locally persisted token (stored in `UserDefaults` with key `com.cadence.lastAPNsToken`). If the token is new or changed, write to `device_tokens` via `SyncCoordinator` (local-first queue). Call `UIApplication.shared.registerForRemoteNotifications()` on the main thread only after `authorizationStatus` is `.authorized` or `.provisional`.

**Acceptance Criteria:**

- [ ] `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` converts token `Data` to lowercase hex string using `map { String(format: "%02.2hhx", $0) }.joined()`
- [ ] If the converted hex token matches the value stored in `UserDefaults` for `com.cadence.lastAPNsToken`, no Supabase write is issued
- [ ] If the token differs from the cached value, a `SyncCoordinator` write is queued for `device_tokens` with `environment` set to `"sandbox"` on debug builds and `"production"` on release builds
- [ ] After a successful Supabase write, the new token is persisted to `UserDefaults` under `com.cadence.lastAPNsToken`
- [ ] `AppDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)` logs the error via structured logging (no `print()`); no crash; no retry
- [ ] `registerForRemoteNotifications()` is called only when `NotificationManager.notificationAuthState` is `.authorized` or `.provisional`
- [ ] Physical device test: launching the app on a device with a fresh install results in a new row in `device_tokens` with the correct token and environment

**Dependencies:** PH-10-E1-S1, PH-10-E1-S2, PH-10-E1-S3, PH-7 (SyncCoordinator)
**Notes:** Simulator does not support APNs registration. `didFailToRegisterForRemoteNotificationsWithError` always fires in the simulator. This is expected and non-fatal.

---

### S5: Token Deduplication and Forced 7-Day Refresh

**Story ID:** PH-10-E1-S5
**Points:** 2

Implement a forced token re-registration check: on each app launch, compare `Date.now` against the last-registered timestamp (stored in `UserDefaults` under `com.cadence.lastTokenRefreshDate`). If the gap exceeds 7 days, call `registerForRemoteNotifications()` unconditionally, regardless of whether the token appears to have changed. This catches server-side token invalidation that the client cannot detect.

**Acceptance Criteria:**

- [ ] On app launch, `UserDefaults` value for `com.cadence.lastTokenRefreshDate` is read
- [ ] If the stored date is absent or more than 7 days in the past, `UIApplication.shared.registerForRemoteNotifications()` is called on the main thread
- [ ] If the gap is less than 7 days and the cached token matches `com.cadence.lastAPNsToken`, `registerForRemoteNotifications()` is NOT called
- [ ] After each successful `didRegisterForRemoteNotificationsWithDeviceToken` callback, `com.cadence.lastTokenRefreshDate` is updated to `Date.now`
- [ ] Unit test: mock `NotificationManager` with a `lastTokenRefreshDate` set to 8 days ago -- verify `registerForRemoteNotifications()` is called

**Dependencies:** PH-10-E1-S4
**Notes:** Token invalidation can occur silently when a user restores from backup or when Apple rotates infrastructure. The 7-day interval is conservative for a beta cohort; adjust post-beta based on observed staleness rates.

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
- [ ] Phase objective is advanced: device tokens are persisted in Supabase and authorization state is known before any notification scheduling begins
- [ ] Applicable skill constraints satisfied: cadence-sync (SyncCoordinator write queue), cadence-supabase (RLS on device_tokens, service role access pattern), cadence-testing (NotificationManaging protocol, MockNotificationManager injectable)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: no drift from MVP Spec §9 and cadence-supabase skill

## Source References

- PHASES.md: Phase 10 -- Notifications (in-scope: notification permission request flow, iOS UNUserNotificationCenter, graceful denial handling; Edge Function full implementation)
- MVP Spec §9: Reminders and Notifications (controls, Partner notification types)
- cadence-supabase skill: Edge Function APNS dispatch pattern, device token storage schema
- cadence-sync skill: write queue pattern (local-first, SyncCoordinator)
- cadence-testing skill: @Observable DI pattern, MockNotificationManager contract
