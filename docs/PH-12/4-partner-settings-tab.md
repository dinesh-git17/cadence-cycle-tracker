# Partner Settings Tab

**Epic ID:** PH-12-E4
**Phase:** 12 -- Settings
**Estimated Size:** M
**Status:** Draft

---

## Objective

Replace the Phase 9 Partner Settings tab stub with the full Partner Settings implementation: a root settings list with connection status, notification preferences, disconnect, and account actions. The connection status display shows the Tracker's name and connection date. The disconnect flow terminates the connection from the Partner's side. Account actions provide sign out and delete account paths. When this epic is complete, a Partner has full self-serve control over their connection and account from the Settings tab.

## Problem / Context

Phase 9 stubbed the Partner Settings tab (tab 3) to unblock navigation shell implementation. MVP Spec §11 and Design Spec v1.1 §8 define the Partner Settings content: "Account, notification preferences, disconnect." The Partner Settings tab is the Partner's only path to managing their connection or account. Without this epic, a Partner cannot disconnect, adjust notification preferences within Settings, or sign out.

The Partner Settings architecture must remain fully isolated from the Tracker's settings hierarchy. The cadence-navigation skill requires that Tracker and Partner trees never share `NavigationPath`, `ViewModels`, or tab state. `PartnerSettingsView` uses its own `NavigationStack` with `PartnerSettingsDestination` enum, entirely separate from the Tracker's `SettingsDestination` (PH-12-E1).

Disconnect from the Partner side is architecturally different from Tracker-initiated disconnect (PH-8-E4). PH-8-E4's `PartnerConnectionStore.disconnect()` deletes the `partner_connections` row using `tracker_id = auth.uid()`. Partner-initiated disconnect deletes the same row using `partner_id = auth.uid()`. The RLS policy must allow partners to delete their own connection row. Both operations produce the same outcome: the row is deleted and all shared data access is immediately revoked.

Notification preferences in Partner Settings are the same three mute toggles as in the Partner Notifications tab (PH-10-E5). Both surfaces bind to the same `ReminderSettings` SwiftData store. Design Spec v1.1 §8 lists "notification preferences" under Partner Settings -- this epic creates a Settings-accessible path to those preferences in addition to the Notifications tab path established in Phase 10.

**Source references that define scope:**

- Design Spec v1.1 §8 (Information Architecture -- Partner tab 3 Settings: Account, notification preferences, disconnect)
- MVP Spec §11 (Partner settings: Notification preferences, Connection status view or disconnect, Account settings)
- PHASES.md Phase 12 in-scope (Partner Settings: notification preferences, connection status display with connected_at, disconnect option, account settings: sign out, delete account)
- PH-10-E5 (PartnerNotificationsView mute controls -- same ReminderSettings backing store reused in this epic's notification preferences surface)
- cadence-navigation skill (Partner and Tracker navigation trees fully isolated)
- PH-8-E4 (disconnect architecture reference -- Partner-initiated disconnect uses partner_id, not tracker_id)

## Scope

### In Scope

- `PartnerSettingsDestination` enum in `Cadence/Views/Partner/Settings/PartnerSettingsDestination.swift`: `Hashable`; cases: `.notificationPreferences`, `.account`
- `PartnerSettingsView` in `Cadence/Views/Partner/Settings/PartnerSettingsView.swift`: `List`-based root view replacing the Phase 9 Partner Settings tab stub; sections: (1) "CONNECTION" -- connection status row (S2) + disconnect row (S4); (2) "NOTIFICATIONS" -- navigation link to notification preferences (S3); (3) "ACCOUNT" -- sign out and delete account rows (S5); uses `NavigationLink(value: PartnerSettingsDestination)` for navigable rows; `navigationDestination(for: PartnerSettingsDestination.self)` block routes to each destination; fully isolated from `TrackerSettingsView` and its `SettingsDestination` enum
- `PartnerSettingsViewModel` in `Cadence/ViewModels/PartnerSettingsViewModel.swift`: `@Observable` class; reads the Partner's `partner_connections` row from local SwiftData (the connection record cached by Phase 8 sync); exposes `trackerDisplayName: String` (Tracker's display name or `"your partner"` if name unavailable), `connectedAt: Date?`, `isConnected: Bool`; method `disconnect() async throws`; method `signOut() async throws`; method `deleteAccount() async throws`; `isLoading: Bool`
- Connection status display (S2): "CONNECTION" section renders a non-interactive row showing: `"Connected to [trackerDisplayName]"` in `body` + `CadenceTextPrimary`; below it, `"Connected [relative date]"` using `RelativeDateTimeFormatter` on `connectedAt` in `footnote` + `CadenceTextSecondary`; a `CadenceSage` `"Connected"` badge (`caption1`, capsule corner radius, `CadenceSageLight` background) in the row trailing area
- Notification preferences (S3): `PartnerSettingsDestination.notificationPreferences` routes to `PartnerNotificationPreferencesView` -- a standalone view containing only the three mute toggles from PH-10-E5-S4 (`"Period predictions"`, `"Symptom updates"`, `"Fertile window"`) bound to the same Partner `ReminderSettings` SwiftData store; this is a second entry point for the same preference data -- both this view and PH-10-E5's `PartnerNotificationsView` Preferences section reflect and write to the same store; toggle tint `Color("CadenceTerracotta")`
- `PartnerNotificationPreferencesView` in `Cadence/Views/Partner/Settings/PartnerNotificationPreferencesView.swift`: a `Form`-based view; extracts the three toggle rows from PH-10-E5's inline implementation (or duplicates them -- choose based on Phase 10 view structure; prefer extraction if it avoids duplicating bindings, duplication if extraction would break Phase 10 view's structure)
- Disconnect from Partner Settings (S4): "Disconnect" `Button` in the "CONNECTION" section, `body` style + `CadenceDestructive`; tap presents `.confirmationDialog` with title `"Disconnect from [trackerDisplayName]?"`, message `"You'll lose access to their cycle data. They won't be automatically notified."`, `"Disconnect"` action (`.destructive` role), `"Cancel"` (`.cancel` role); confirming calls `PartnerSettingsViewModel.disconnect()`
- `PartnerSettingsViewModel.disconnect() async throws`: issues `supabase.from("partner_connections").delete().eq("partner_id", auth.uid())`; on success, clears local `partner_connections` cached row in SwiftData and routes the Partner to the Partner onboarding code-entry screen (Phase 2); on failure, shows a non-blocking toast and keeps the Partner on `PartnerSettingsView`
- Partner account settings (S5): "ACCOUNT" section contains two buttons: `"Sign Out"` in `body` style (no destructive color -- sign out is reversible) with its own `.confirmationDialog`; `"Delete Account"` in `body` + `CadenceDestructive` with its own `.confirmationDialog`
- `PartnerSettingsViewModel.signOut() async throws`: identical flow to E3-S2 sign out (calls `supabase.auth.signOut()`, routes to auth root); may share logic with E3 via a shared `AuthSessionService` if one is introduced, or may call the same Supabase client method directly
- `PartnerSettingsViewModel.deleteAccount() async throws`: calls the same Edge Function as E3-S5 (`DELETE /functions/v1/delete-account`); Partner's data is minimal (only `reminder_settings`, `partner_connections` rows); purge those rows locally and in Supabase before calling the Edge Function; then routes to auth root
- `project.yml` updated with entries for `PartnerSettingsDestination.swift`, `PartnerSettingsView.swift`, `PartnerSettingsViewModel.swift`, `PartnerNotificationPreferencesView.swift`; `xcodegen generate` exits 0

### Out of Scope

- Tracker Settings (tab 5 of Tracker shell) -- PH-12-E1 through PH-12-E3
- App lock for Partner role (not specified in source documents)
- Partner notification history list (already implemented in PH-10-E5 in the Notifications tab -- this epic does not duplicate or replace it)
- Re-implementing PH-10-E5's mute toggle logic -- this epic creates a second surface backed by the same store, not a new implementation
- Partner ability to disconnect the Tracker (Partners can disconnect themselves; they cannot disconnect the Tracker from the Tracker's side -- that is Tracker-controlled)
- Connection request flow for a Partner who has no connection (the "enter invite code" flow is Phase 2 Partner onboarding; Phase 12 routes to it post-disconnect)

## Dependencies

| Dependency                                                                               | Type     | Phase/Epic | Status | Risk                                                                                                                                |
| ---------------------------------------------------------------------------------------- | -------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| Phase 9 Partner shell with Settings tab stub                                             | FS       | PH-9       | Open   | Low -- stub replacement target                                                                                                      |
| Partner's `partner_connections` cached row in local SwiftData (Phase 8 connection)       | FS       | PH-8       | Open   | Low                                                                                                                                 |
| `ReminderSettings` SwiftData model for Partner's mute preferences (PH-10-E3-S1)          | FS       | PH-10-E3   | Open   | Low                                                                                                                                 |
| Phase 10 `PartnerNotificationsView` mute toggle implementation (PH-10-E5-S4)             | SS       | PH-10-E5   | Open   | Low -- needed to determine whether to extract or duplicate toggle rows                                                              |
| Edge Function `delete-account` deployed (PH-1-E5 scaffold)                               | External | PH-1       | Open   | High -- same risk as PH-12-E3-S5                                                                                                    |
| Phase 2 app coordinator with Partner-role onboarding and auth routing                    | FS       | PH-2       | Open   | Medium -- post-disconnect routing requires a coordinator method to route to Partner onboarding code-entry                           |
| RLS policy: Partner can delete `partner_connections` row where `partner_id = auth.uid()` | FS       | PH-1-E3    | Open   | Medium -- if Phase 1 RLS only allows Tracker-initiated delete (via `tracker_id`), a new policy must be added before S4 can function |

## Assumptions

- The Phase 9 Partner shell's Settings tab stub is a `NavigationStack`-wrapped view. This epic replaces the stub's content view while keeping the `NavigationStack` wrapper. If Phase 9 did not wrap the Settings tab in a `NavigationStack`, this epic adds one.
- The Partner's `partner_connections` row is cached in local SwiftData as part of Phase 8's sync. `PartnerSettingsViewModel` reads `trackerDisplayName` and `connectedAt` from this local record without a network call.
- If `trackerDisplayName` is not stored in the local `partner_connections` cache (it may not be -- the MVP Spec data model does not include a tracker name column), fall back to `"your partner"`. Phase 8's local model may only store UUIDs. Confirm before implementing S2.
- The RLS policy allows Partners to delete their own `partner_connections` row. This was likely included in Phase 1 RLS, but it is a different policy condition from the Tracker's delete policy. Verify before implementing S4.
- Tracker's display name availability: the `users` table has `id` and `role` but no display name column per the MVP Spec data model. "Tracker name" in the connection status may need to come from the Supabase auth profile (`user_metadata`) if set during onboarding, or may default to `"your partner"`. Confirm with Dinesh if a display name is stored.

## Risks

| Risk                                                                                          | Likelihood | Impact                                          | Mitigation                                                                                                                                          |
| --------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 1 RLS does not include Partner-initiated delete policy for `partner_connections`        | Medium     | High -- S4 disconnect call returns RLS error    | Verify Phase 1 RLS policies before implementing S4; add a new Supabase migration to add `DELETE USING (partner_id = auth.uid())` if absent          |
| Tracker display name not stored locally or in `users` table                                   | High       | Low -- fallback to "your partner" is acceptable | Implement the fallback from the start; do not assume name availability                                                                              |
| `PartnerNotificationPreferencesView` extraction from PH-10-E5 breaks Phase 10 view            | Low        | Medium -- regression in Notifications tab       | Prefer duplication (same binding code in a new view) over risky extraction if Phase 10's `PartnerNotificationsView` is tightly coupled              |
| Post-disconnect routing in Phase 2 coordinator does not have a Partner onboarding entry point | Medium     | Medium -- Partner is stranded after disconnect  | Verify Phase 2 coordinator before implementing S4; add the routing method to the coordinator if absent; this is a one-line addition to Phase 2 code |

---

## Stories

### S1: PartnerSettingsView Root List + PartnerSettingsDestination Navigation

**Story ID:** PH-12-E4-S1
**Points:** 2

Define `PartnerSettingsDestination` enum and implement `PartnerSettingsView` as the root Partner Settings tab content. Replace the Phase 9 stub. All section rows use `NavigationLink(value: PartnerSettingsDestination)`. Fully isolated from Tracker navigation tree.

**Acceptance Criteria:**

- [ ] `PartnerSettingsDestination` is a `Hashable` enum with exactly 2 cases: `.notificationPreferences`, `.account`
- [ ] `PartnerSettingsView` is a `List`-based view with 3 sections: "CONNECTION", "NOTIFICATIONS", "ACCOUNT"; section headers use `caption2` uppercased `CadenceTextSecondary` style
- [ ] "NOTIFICATIONS" section contains one row: `"Notifications"` with `bell` SF Symbol leading icon; uses `NavigationLink(value: PartnerSettingsDestination.notificationPreferences)` -- no `NavigationLink(destination:)` deprecated form
- [ ] "ACCOUNT" section contains two `Button` rows: `"Sign Out"` in `body` style (no destructive color) and `"Delete Account"` in `body` + `CadenceDestructive` color
- [ ] `navigationDestination(for: PartnerSettingsDestination.self)` routes `.notificationPreferences` to `PartnerNotificationPreferencesView` (S3) and `.account` to `AccountView` pattern (S5 -- a sub-view of this epic, not PH-12-E3's `AccountView`)
- [ ] The Phase 9 Partner Settings tab stub is replaced; the Partner's Settings tab icon (`gearshape.fill`, `CadenceTerracotta` active tint) is unchanged
- [ ] `PartnerSettingsView` does not reference, import, or share state with `TrackerSettingsView`, `SettingsDestination`, or `PartnerConnectionStore` (the Tracker's store); zero shared types between the two settings hierarchies (cadence-navigation isolation constraint)
- [ ] `PartnerSettingsDestination.swift` and `PartnerSettingsView.swift` added to `project.yml`; `xcodegen generate` exits 0

**Dependencies:** Phase 9 Partner shell with Settings tab stub
**Notes:** The Partner's `NavigationStack` for the Settings tab is either already in place from Phase 9 or must be added here. Inspect Phase 9's Partner shell before writing -- do not add a second nested `NavigationStack` if one already wraps the Settings tab.

---

### S2: Connection Status Display

**Story ID:** PH-12-E4-S2
**Points:** 2

Implement the "CONNECTION" section's status row in `PartnerSettingsView`. Reads Partner's `partner_connections` local SwiftData cache for Tracker name and `connected_at`. Displays connection badge, name, and relative connection date. No network call at render time.

**Acceptance Criteria:**

- [ ] `PartnerSettingsViewModel` reads the Partner's `partner_connections` local SwiftData row on init; exposes `trackerDisplayName: String` (Tracker display name if available in the local record or user metadata, otherwise `"your partner"`), `connectedAt: Date?`
- [ ] The "CONNECTION" section renders a non-interactive row with: `"Connected to \(trackerDisplayName)"` in `body` + `CadenceTextPrimary`; below it, `"Connected \(relativeDate)"` using `RelativeDateTimeFormatter(.unitsStyle: .full, dateTimeStyle: .named)` on `connectedAt` in `footnote` + `CadenceTextSecondary`; a trailing `"Connected"` badge in `caption1` + `CadenceSage` on `CadenceSageLight` background with capsule corner radius
- [ ] If `connectedAt` is nil (edge case: row missing connected_at), the relative date label is omitted; the name label still renders
- [ ] If no `partner_connections` row exists in local SwiftData (Partner not connected), the "CONNECTION" section renders a single informational row: `"Not connected to a Tracker"` in `footnote` + `CadenceTextSecondary`; the "Disconnect" button (S4) is hidden
- [ ] `PartnerSettingsViewModel` is `@Observable`; connection data is read synchronously from SwiftData on init (no async Supabase query)
- [ ] `PartnerSettingsViewModel.swift` added to `project.yml`

**Dependencies:** PH-12-E4-S1, PH-8 (partner_connections local SwiftData cache)
**Notes:** If the local `partner_connections` SwiftData model does not store the Tracker's display name (the MVP Spec data model has no `tracker_name` column), display `"your partner"` and add a code comment explaining the limitation. Do not add a new Supabase query at render time to fetch the Tracker's profile.

---

### S3: Notification Preferences in Partner Settings

**Story ID:** PH-12-E4-S3
**Points:** 3

Implement `PartnerNotificationPreferencesView` -- a standalone `Form`-based view containing the three Partner mute toggles backed by the same `ReminderSettings` SwiftData store as PH-10-E5-S4. This is a second surface for the same preferences; both surfaces reflect live state via `@Observable`.

**Acceptance Criteria:**

- [ ] `PartnerNotificationPreferencesView` is a `Form`-based view navigable from `PartnerSettingsView` via `PartnerSettingsDestination.notificationPreferences`
- [ ] The view renders three `Toggle` rows with labels: `"Period predictions"`, `"Symptom updates"`, `"Fertile window"` -- identical labels to PH-10-E5-S4
- [ ] Each toggle is bound to the Partner's `ReminderSettings.notifyPartnerPeriod`, `.notifyPartnerSymptoms`, `.notifyPartnerFertile` respectively via the same `@Observable` store as PH-10-E5 uses
- [ ] Toggling any preference in `PartnerNotificationPreferencesView` immediately reflects in PH-10-E5's `PartnerNotificationsView` Preferences section (and vice versa) -- both surfaces observe the same `@Observable` store instance
- [ ] Toggle tint is `Color("CadenceTerracotta")`
- [ ] Each toggle row has a minimum touch target of 44 x 44pt
- [ ] Text labels use `body` type token; `"Symptom updates"` does not mention the Sex symptom
- [ ] A `footnote` + `CadenceTextSecondary` description below the toggle section reads: `"Manage which notifications you receive from your partner's cycle activity."`
- [ ] Mutating any toggle queues a SyncCoordinator write to Supabase `reminder_settings` (same behavior as PH-10-E5-S3 -- the store handles this automatically via `@Observable` mutation observation)
- [ ] `PartnerNotificationPreferencesView.swift` added to `project.yml`

**Dependencies:** PH-12-E4-S1, PH-10-E5-S3 (Partner ReminderSettings store)
**Notes:** Do not create a second view model for these toggles if PH-10-E5 already has one. Inject the same view model instance via environment. If PH-10-E5's view model is not environment-injectable (it was implemented as a local `@State`), extract it to a shared `@Observable` class injected at the Partner shell level before implementing this story.

---

### S4: Partner-Initiated Disconnect Flow

**Story ID:** PH-12-E4-S4
**Points:** 3

Implement the "Disconnect" `Button` in the "CONNECTION" section and `PartnerSettingsViewModel.disconnect() async throws`. Partner-initiated disconnect deletes the `partner_connections` row using `partner_id = auth.uid()`. On success, clears local state and routes to Partner onboarding.

**Acceptance Criteria:**

- [ ] A `"Disconnect"` `Button` appears in the "CONNECTION" section below the connection status row, rendered in `body` + `CadenceDestructive`; minimum 44pt touch target
- [ ] Tapping "Disconnect" presents a `.confirmationDialog` with title `"Disconnect from \(trackerDisplayName)?"`, message `"You'll lose access to their cycle data. They won't be automatically notified."`, `"Disconnect"` action (`.destructive` role), `"Cancel"` (`.cancel` role)
- [ ] Confirming calls `PartnerSettingsViewModel.disconnect()` and sets `isLoading = true`
- [ ] `disconnect()` issues `supabase.from("partner_connections").delete().eq("partner_id", auth.uid())`; the filter uses `partner_id`, not `tracker_id` (this is the Partner-side delete -- distinct from PH-8-E4-S4 which used `tracker_id`)
- [ ] On successful Supabase delete: clears the local `partner_connections` SwiftData row for this Partner; updates `PartnerSettingsViewModel.isConnected = false`; routes the Partner to the Partner onboarding code-entry screen (Phase 2 coordinator method)
- [ ] On Supabase delete failure: non-blocking toast appears: `"Disconnect failed. Try again."` `isLoading` reverts to false; the Partner remains on `PartnerSettingsView`
- [ ] The "Disconnect" button and connection status row are hidden when `isConnected == false`
- [ ] Unit test: inject mock Supabase client returning success for DELETE on `partner_connections` where `partner_id = auth.uid()`; verify local SwiftData row is deleted and coordinator `routeToPartnerOnboarding()` is called
- [ ] Unit test: inject mock returning a Supabase error; verify `isLoading == false` and coordinator route is NOT called

**Dependencies:** PH-12-E4-S2, PH-1-E3 (RLS policy allowing partner_id-based delete), PH-2 (app coordinator with Partner onboarding routing)
**Notes:** The RLS policy for this delete (`partner_id = auth.uid()`) must be confirmed to exist in Phase 1 before implementing. If the policy is missing, a Supabase migration is required. This is the highest-risk item in this epic; resolve it before writing any Swift code for this story.

---

### S5: Partner Account Settings -- Sign Out + Delete Account

**Story ID:** PH-12-E4-S5
**Points:** 3

Implement the "ACCOUNT" section sign out and delete account flows in `PartnerSettingsView`. Each destructive action requires a `.confirmationDialog`. Sign out terminates the session. Delete account calls the same Edge Function as PH-12-E3-S5 and routes to auth.

**Acceptance Criteria:**

- [ ] Tapping "Sign Out" presents a `.confirmationDialog` with title `"Sign out of Cadence?"`, message `"You can sign back in at any time."`, `"Sign Out"` action (no `.destructive` role), `"Cancel"` (`.cancel` role)
- [ ] Confirming sign out calls `PartnerSettingsViewModel.signOut()` which calls `supabase.auth.signOut()` and routes to the auth root via Phase 2 coordinator; same behavior as PH-12-E3-S2 but for the Partner role
- [ ] Tapping "Delete Account" presents a `.confirmationDialog` with title `"Delete your account?"`, message `"This permanently deletes your Cadence account. This cannot be undone."`, `"Delete Account"` (`.destructive` role), `"Cancel"` (`.cancel` role)
- [ ] Confirming delete account calls `PartnerSettingsViewModel.deleteAccount()` which: (1) deletes Partner-owned local SwiftData rows (`reminder_settings`, local `partner_connections` mirror if present); (2) issues Supabase DELETE for `reminder_settings where user_id = auth.uid()` and `partner_connections where partner_id = auth.uid()`; (3) calls the `delete-account` Edge Function (same endpoint as PH-12-E3-S5); (4) calls `supabase.auth.signOut()` locally; (5) routes to the auth root
- [ ] On Edge Function failure, shows toast `"Account deletion failed. Contact support if this persists."` and routes to auth root anyway (local data is cleared)
- [ ] `isLoading == true` while any async account action is in flight; the active button shows an inline `ProgressView`; other buttons are disabled
- [ ] Unit test: sign out mock returns success; verify `supabase.auth.signOut()` called and `routeToAuth()` called
- [ ] Unit test: delete account Edge Function mock returns 200; verify `supabase.auth.signOut()` called and `routeToAuth()` called

**Dependencies:** PH-12-E4-S1, PH-12-E3-S5 (Edge Function endpoint -- same function, verified deployed), PH-2 (app coordinator auth routing)
**Notes:** The Partner's data footprint is small (only `reminder_settings` and `partner_connections`). Do not apply the Tracker's full 7-table DELETE sequence to the Partner -- only delete tables where the Partner is the data owner. The Partner never owns `daily_logs`, `period_logs`, `prediction_snapshots`, or `symptom_logs`.

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
- [ ] Integration verified end-to-end: Partner sees connection status with Tracker name and connected_at date; disconnect removes RLS access (Partner's next read against Tracker tables returns zero rows)
- [ ] Integration verified end-to-end: toggling "Period predictions" mute in Partner Settings reflects immediately in the Partner Notifications tab Preferences section (same store, same state)
- [ ] Integration verified end-to-end: Partner signs out -> auth screen; signing back in restores connection
- [ ] Integration verified end-to-end: Partner deletes account -> Supabase Auth user absent from dashboard -> auth screen
- [ ] Phase objective is advanced: a Partner can manage their connection and account from the Settings tab
- [ ] Applicable skill constraints satisfied: cadence-navigation (Partner and Tracker navigation trees fully isolated -- no shared NavigationPath, ViewModels, or SettingsDestination types), swiftui-production (@Observable, no AnyView, view extraction), cadence-design-system (CadenceDestructive token for destructive actions, no hardcoded hex, section eyebrow style), cadence-accessibility (44pt touch targets on all interactive elements), cadence-xcode-project (project.yml updated for all new files)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility: connection status row has `accessibilityLabel("Connected to [name] since [date]")`; disconnect button has `accessibilityLabel("Disconnect from [name]")`; both meet 44pt minimum
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: Partner Settings section content matches Design Spec v1.1 §8 ("Account, notification preferences, disconnect") and MVP Spec §11 Partner settings exactly

## Source References

- PHASES.md: Phase 12 -- Settings (in-scope: Partner Settings -- notification preferences, connection status display with connected_at, disconnect option, account settings: sign out, delete account)
- Design Spec v1.1 §8 (Information Architecture -- Partner tab 3 Settings: Account, notification preferences, disconnect)
- MVP Spec §11 (Partner settings: Notification preferences, Connection status view or disconnect, Account settings)
- Design Spec v1.1 §3 (CadenceDestructive: "Account deletion, disconnect -- use `.red` color asset")
- Design Spec v1.1 §9 (Tab Bar Icons -- Partner Settings: gearshape / gearshape.fill, active: gearshape.fill tinted CadenceTerracotta)
- PH-10-E5 (PartnerNotificationsView mute controls -- same ReminderSettings backing store)
- PH-8-E4 (disconnect architecture reference -- partner_id vs. tracker_id delete distinction)
- cadence-navigation skill (Tracker/Partner isolation requirement)
- swiftui-production skill (@Observable, LazyVStack for feeds, AnyView ban)
- cadence-accessibility skill (44pt touch targets, VoiceOver label patterns)
