# Account Management + Delete All Data

**Epic ID:** PH-12-E3
**Phase:** 12 -- Settings
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement the Tracker account management surface: an Account settings screen with sign out, delete all data, and delete account actions. Delete all data performs a confirmed, irreversible purge of the Tracker's local SwiftData store and all user-owned rows in Supabase across every table, then routes the Tracker back to cycle profile onboarding. Delete account calls a Supabase Edge Function to remove the Supabase Auth user record and then routes to the auth screen. Sign out is the non-destructive session termination path. All destructive actions require explicit confirmation before execution.

## Problem / Context

A health data app must give its users full control over their data. MVP Spec §11 lists "Delete all data" as a required Tracker setting. The Phase 12 in-scope explicitly includes "local SwiftData purge + Supabase data deletion for authenticated user, confirmation alert using CadenceDestructive." Without this epic, the Tracker has no self-serve path to remove their data, which is a basic privacy expectation and a TestFlight quality gate.

Delete all data and delete account are distinct operations:

- **Delete all data:** Removes all cycle history, predictions, logs, and settings. Leaves the Supabase Auth account intact. Routes the Tracker to onboarding (cycle profile setup) because `cycle_profiles` no longer exists.
- **Delete account:** Deletes the Supabase Auth user record entirely (requires server-side service-role execution via Edge Function). Routes to the auth screen. Implies all data is also deleted.

Supabase client-side DELETE operations can remove user-owned rows (RLS allows `user_id = auth.uid()` owner deletes). Supabase Auth user deletion cannot be done from the client SDK without the service role key, which must never appear in client code. An Edge Function with the service role key is the correct pattern. The Phase 1 Edge Function scaffold (PH-1-E5) provides the function deployment infrastructure.

Sign out is the simplest action: `supabase.auth.signOut()` terminates the session, clears the local JWT, and routes the user to the auth screen. Local SwiftData is not purged on sign out -- it persists so that if the Tracker signs back in, their cached data is available until the next sync.

**Source references that define scope:**

- MVP Spec §11 (Privacy and Settings -- Tracker settings: Delete all data, account settings including sign out)
- PHASES.md Phase 12 in-scope (delete all data: local SwiftData purge + Supabase data deletion for authenticated user, confirmation alert using CadenceDestructive)
- Design Spec v1.1 §3 (`CadenceDestructive` -- "Account deletion, disconnect -- use `.red` color asset")
- Design Spec v1.1 §13 (States -- confirmation dialogs for destructive actions implied by error/success state patterns)
- PH-1-E5 (Edge Function scaffold -- deployment target for delete-account function)
- cadence-privacy-architecture skill (user data must be fully deletable; Sex symptom data is part of `symptom_logs` and is deleted as part of the all-data purge)

## Scope

### In Scope

- `AccountView` in `Cadence/Views/Settings/AccountView.swift`: `Form`-based settings screen navigable from `TrackerSettingsView` via `SettingsDestination.account`; sections: (1) "ACCOUNT" section showing the Tracker's email address in `body` + `CadenceTextSecondary` (read from `supabase.auth.session?.user.email`); (2) "SESSION" section with a "Sign Out" `Button` in `body` + `CadenceDestructive`; (3) "DATA" section with a "Delete All Data" `Button` in `body` + `CadenceDestructive`; (4) "ACCOUNT" section with a "Delete Account" `Button` in `body` + `CadenceDestructive`; each destructive button presents a confirmation before executing its action
- `AccountViewModel` in `Cadence/ViewModels/AccountViewModel.swift`: `@Observable` class; exposes `userEmail: String` read from `supabase.auth.currentSession?.user.email ?? ""`; methods: `signOut() async throws`, `deleteAllData() async throws`, `deleteAccount() async throws`; `isLoading: Bool` property for loading state on in-flight operations
- Sign out flow: `AccountViewModel.signOut()` calls `supabase.auth.signOut()`; on success, notifies the app coordinator to route to the auth root (the same routing mechanism established in Phase 2 auth flow); does NOT purge SwiftData; on Supabase failure, throws a typed error and shows a non-blocking toast
- "Sign Out" confirmation: a `.confirmationDialog` with title `"Sign out of Cadence?"`, message `"You'll stay signed out until you sign back in. Your data won't be deleted."`, a `"Sign Out"` action (no `.destructive` role -- sign out is reversible), and a `"Cancel"` action (`.cancel` role)
- "Delete All Data" two-step confirmation: first tap presents a `.confirmationDialog` with title `"Delete all your data?"`, message `"This permanently deletes all your logged data, cycle history, predictions, and settings. Your account remains active. This cannot be undone."`, a `"Delete All Data"` action (`.destructive` role), and `"Cancel"` (`.cancel` role)
- Delete all data execution in `AccountViewModel.deleteAllData() async throws`: (1) local SwiftData purge -- fetch and delete all user-owned instances of `DailyLog`, `PeriodLog`, `PredictionSnapshot`, `SymptomLog`, `CycleProfile`, `ReminderSettings`; delete any `partner_connections`-mirroring local model if it exists in SwiftData; call `modelContext.save()`; (2) Supabase row deletion -- issue authenticated `DELETE` requests for each table: `daily_logs`, `period_logs`, `prediction_snapshots`, `symptom_logs`, `cycle_profiles`, `reminder_settings`, `partner_connections` each filtered by `user_id = auth.uid()` (RLS permits this); (3) on full success, route the Tracker to the onboarding cycle profile setup screen (the app coordinator detects the absence of `cycle_profiles` and shows onboarding, or the coordinator is explicitly driven to the onboarding flow after this call)
- Delete all data ordering: local purge first, then remote; if the remote deletion fails after the local purge succeeds, show a non-blocking toast `"Data deleted locally. Remote deletion failed -- try again."` and do not re-insert the local data (local deletion stands; the user's next session will trigger an empty state)
- `AccountView` loading state: while `isLoading == true`, the active action's button label is replaced by an inline `ProgressView`; other buttons are disabled; `isLoading` reverts to false on either success or failure
- "Delete Account" confirmation: a `.confirmationDialog` with title `"Delete your account?"`, message `"This permanently deletes your Cadence account and all associated data. This cannot be undone."`, a `"Delete Account"` action (`.destructive` role), and `"Cancel"` (`.cancel` role)
- Delete account execution in `AccountViewModel.deleteAccount() async throws`: (1) perform the full SwiftData purge and Supabase row deletion (reuses `deleteAllData()` internals); (2) call an authenticated `POST` to the Supabase Edge Function endpoint `/functions/v1/delete-account` (deployed in PH-1-E5 scaffold or as a new function in that phase's deployment group) with the user's JWT in the `Authorization` header; the Edge Function uses the service role key to call `supabase.auth.admin.deleteUser(userId)`; (3) on successful Edge Function response (HTTP 200), call `supabase.auth.signOut()` locally and route to the auth screen
- Delete account Edge Function contract: `POST /functions/v1/delete-account`, authenticated JWT required, no request body needed (user ID is derived from JWT on the server), expected response: `200 OK` with `{"success": true}`; on `4xx` or `5xx`, throw `AccountError.deletionFailed` and show a non-blocking toast; the user's auth account remains intact if the Edge Function call fails
- `project.yml` updated with entries for `AccountView.swift`, `AccountViewModel.swift`; `xcodegen generate` exits 0

### Out of Scope

- Partner Settings account section (sign out, delete account for Partner role) -- PH-12-E4
- Cached SwiftData data for a Partner user -- the Partner does not own Tracker data; their SwiftData cache (notification history, connection state) is separate and small enough to leave on sign out (it will reconcile on next sign-in)
- Exporting data before deletion (post-beta, not specified in MVP Spec)
- Recovery path after deletion (no undo; this is by design)
- Email/password change or re-authentication flows (post-beta account management, not specified in MVP Spec §11 for beta)
- Soft delete / tombstone pattern (all deletes are hard deletes in the beta; the `updated_at` conflict resolution in SyncCoordinator (PH-7) does not apply to deleted rows)

## Dependencies

| Dependency                                                                        | Type     | Phase/Epic | Status | Risk                                                                                                                                                  |
| --------------------------------------------------------------------------------- | -------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SettingsDestination.account` routing from `TrackerSettingsView` (PH-12-E1-S1)    | FS       | PH-12-E1   | Open   | Low                                                                                                                                                   |
| Supabase Auth session with signed-in Tracker (PH-2)                               | FS       | PH-2       | Open   | Low                                                                                                                                                   |
| All SwiftData `@Model` types exist with correct `userId` field (PH-3)             | FS       | PH-3       | Open   | Low                                                                                                                                                   |
| `ModelContext` injectable for SwiftData operations                                | FS       | PH-3       | Open   | Low                                                                                                                                                   |
| App coordinator routing mechanism for post-deletion navigation (PH-2)             | FS       | PH-2       | Open   | Medium -- the Phase 2 coordinator must expose a method to route to auth root or onboarding; verify before implementing S2                             |
| Edge Function endpoint `/functions/v1/delete-account` deployed (PH-1-E5 scaffold) | External | PH-1       | Open   | High -- if the Phase 1 scaffold did not deploy this function, it must be created as a new Edge Function deployment before S5 can be tested end-to-end |

## Assumptions

- The app coordinator established in Phase 2 (`AppCoordinator` or equivalent) exposes a method or state toggle that routes all roles to the auth screen. This method is called after both sign out and delete account.
- `cycle_profiles` absence post-deletion routes the Tracker to onboarding. The Phase 2 app coordinator checks for a `CycleProfile` row and shows onboarding when absent. If Phase 2 does not implement this check, S4 must explicitly route to the onboarding entry point.
- All SwiftData `@Model` types use `userId: String` (not a UUID type, matches `auth.uid()` which is a UUID string) for the ownership field. If any model uses a different field name or type, align before implementing S4.
- The `DELETE` RLS policies on all Supabase tables allow `user_id = auth.uid()` owner deletes. This was established in PH-1-E3 (RLS policies). If any table does not have an owner-delete policy, a new migration is required before S4.
- Supabase `DELETE` operations for multiple tables are issued sequentially (not in a transaction). If one fails mid-sequence, the tables already deleted remain deleted. This is acceptable for the beta; partial deletion is a degraded but not catastrophic state.

## Risks

| Risk                                                                                                                                                | Likelihood | Impact                                                                     | Mitigation                                                                                                                                            |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Edge Function for delete-account is not deployed in Phase 1 scaffold                                                                                | High       | Medium -- delete account feature cannot be end-to-end tested without it    | Treat the Edge Function deployment as a prerequisite for S5; create it as a new function in the PH-1 Supabase project if absent; document in S5 notes |
| Supabase row deletion fails midway (e.g., `symptom_logs` deleted but `daily_logs` fails)                                                            | Low        | Low -- partial deletion; user's next sign-in shows a partially empty state | Issue each DELETE sequentially and collect errors; surface a single toast after all attempts complete; local data is already purged regardless        |
| `ModelContext` is not injected at `AccountViewModel` level; direct `@Environment(\.modelContext)` access required                                   | Low        | Low -- view model cannot access context without the environment            | Pass `modelContext` as an init parameter to `AccountViewModel` or use `@Environment(\.modelContext)` in the view and pass it to the view model method |
| Post-deletion routing: app coordinator routes to auth screen but SwiftData models are already purged, causing fetch errors before routing completes | Low        | Low -- brief error state before routing                                    | Clear all SwiftData before issuing Supabase deletes; the local purge (S4) is the first operation                                                      |

---

## Stories

### S1: AccountView -- Screen Layout + Section Structure

**Story ID:** PH-12-E3-S1
**Points:** 2

Implement `AccountView` and `AccountViewModel` shell. Render the email display section and three destructive action buttons with correct styling. All destructive actions call placeholder async methods that are implemented in subsequent stories. No confirmation dialogs in this story -- those are wired in S2, S3, S5.

**Acceptance Criteria:**

- [ ] `AccountView` is a `Form`-based view navigable from `TrackerSettingsView` via `SettingsDestination.account`
- [ ] Section 1 ("ACCOUNT") displays the Tracker's email address via `AccountViewModel.userEmail` in `body` style + `CadenceTextSecondary` color; reads from `supabase.auth.currentSession?.user.email`
- [ ] Section 2 ("SESSION") contains a `"Sign Out"` `Button` in `body` style + `CadenceDestructive` color
- [ ] Section 3 ("DATA") contains a `"Delete All Data"` `Button` in `body` style + `CadenceDestructive` color
- [ ] Section 4 ("ACCOUNT") contains a `"Delete Account"` `Button` in `body` style + `CadenceDestructive` color
- [ ] Section headers use `caption2` uppercased `CadenceTextSecondary` style per Design Spec §4
- [ ] `AccountViewModel` is `@Observable`; exposes `userEmail: String`, `isLoading: Bool` (default false)
- [ ] While `isLoading == true`, the active action button label is replaced by an inline `ProgressView`; other action buttons are disabled (`.disabled(isLoading)`)
- [ ] `AccountView.swift` and `AccountViewModel.swift` added to `project.yml`; `xcodegen generate` exits 0
- [ ] No hardcoded hex colors; `CadenceDestructive` used via `Color("CadenceDestructive")`

**Dependencies:** PH-12-E1-S1 (SettingsDestination.account routing)
**Notes:** `CadenceDestructive` is defined in the design spec as "system red -- use `.red` color asset". If the xcassets definition uses the system red, `Color("CadenceDestructive")` resolves to system red. Do not use `Color.red` directly -- always use the token name.

---

### S2: Sign Out Flow

**Story ID:** PH-12-E3-S2
**Points:** 3

Implement the sign out confirmation dialog and `AccountViewModel.signOut() async throws`. The flow is: tap "Sign Out" -> `.confirmationDialog` appears -> confirm -> `supabase.auth.signOut()` -> route to auth root. Handle sign-out failure with a non-blocking toast.

**Acceptance Criteria:**

- [ ] Tapping "Sign Out" presents a `.confirmationDialog` (not `.alert`) with title `"Sign out of Cadence?"`, message `"You'll stay signed out until you sign back in. Your data won't be deleted."`, a `"Sign Out"` action with no `.destructive` role, and a `"Cancel"` action with `.cancel` role
- [ ] Confirming calls `AccountViewModel.signOut()` which sets `isLoading = true`, calls `supabase.auth.signOut()`, then routes to the auth root via the Phase 2 app coordinator
- [ ] On `supabase.auth.signOut()` success, local SwiftData is NOT purged -- only the session is terminated
- [ ] On `supabase.auth.signOut()` failure (network error), `isLoading` reverts to false, a non-blocking toast appears with message `"Sign out failed. Try again."`, the Tracker remains on `AccountView`
- [ ] After successful sign out, the app renders the auth screen (Phase 2 auth root); no Tracker content is visible
- [ ] Unit test: inject mock Supabase client returning success for `signOut()`; verify app coordinator `routeToAuth()` method is called
- [ ] Unit test: inject mock returning a network error; verify `isLoading == false` and app coordinator `routeToAuth()` is NOT called

**Dependencies:** PH-12-E3-S1, PH-2 (app coordinator with auth routing)
**Notes:** Supabase `supabase.auth.signOut()` is async and can throw. Do not call it on the main thread synchronously. Use `Task { try await ... }` in the button action, wrapped in `@MainActor` for state updates.

---

### S3: Delete All Data Confirmation Dialog

**Story ID:** PH-12-E3-S3
**Points:** 2

Wire the "Delete All Data" button to a two-step `.confirmationDialog`. Present the confirmation with the exact copy and button roles specified. On confirmation, set `isLoading = true` and call `AccountViewModel.deleteAllData()` (implemented in S4). The confirmation dialog itself is the full scope of this story.

**Acceptance Criteria:**

- [ ] Tapping "Delete All Data" presents a `.confirmationDialog` with title `"Delete all your data?"`, message `"This permanently deletes all your logged data, cycle history, predictions, and settings. Your account remains active. This cannot be undone."`, a `"Delete All Data"` action with `.destructive` role, and a `"Cancel"` action with `.cancel` role
- [ ] Cancelling the dialog returns to `AccountView` with no state change
- [ ] Confirming sets `AccountViewModel.isLoading = true` and calls `AccountViewModel.deleteAllData()` (which is a no-op stub at this story boundary -- S4 implements the execution)
- [ ] The `.confirmationDialog` uses the `.confirmationDialog(titleVisibility: .visible, presenting:)` SwiftUI API (not `.alert`); on iPhone, this renders as an action sheet from the bottom
- [ ] The "Delete All Data" destructive action renders in the system `.destructive` red color (provided by iOS automatically for the `.destructive` role; no manual color override needed)
- [ ] UI test: tap "Delete All Data" button -> verify `.confirmationDialog` is presented with correct title text
- [ ] UI test: tap "Cancel" -> verify `isLoading == false` and `AccountView` is still on screen

**Dependencies:** PH-12-E3-S1
**Notes:** `.confirmationDialog` is preferred over `.alert` for multi-option destructive flows on iOS per Apple HIG. Do not substitute with a custom modal sheet.

---

### S4: Delete All Data Execution -- SwiftData Purge + Supabase Row Deletion

**Story ID:** PH-12-E3-S4
**Points:** 5

Implement `AccountViewModel.deleteAllData() async throws`. Purge all user-owned SwiftData model instances across all `@Model` types. Issue authenticated `DELETE` requests to Supabase for all user-owned table rows. Route the Tracker to cycle profile onboarding on success. Handle partial failure gracefully.

**Acceptance Criteria:**

- [ ] `deleteAllData()` first fetches and deletes all instances of `DailyLog`, `PeriodLog`, `PredictionSnapshot`, `SymptomLog`, `CycleProfile`, `ReminderSettings` from the local `ModelContext` where `userId == auth.uid()` for each type; calls `modelContext.save()` after all deletes
- [ ] Any local SwiftData model that stores partner connection data (if one exists from Phase 8 local caching) is also deleted in this step
- [ ] After local purge, issues authenticated Supabase `DELETE` requests for each table: `daily_logs where user_id = auth.uid()`, `period_logs where user_id = auth.uid()`, `prediction_snapshots where user_id = auth.uid()`, `symptom_logs where user_id = auth.uid()`, `cycle_profiles where user_id = auth.uid()`, `reminder_settings where user_id = auth.uid()`, `partner_connections where tracker_id = auth.uid()` -- all 7 deletions executed sequentially
- [ ] Each Supabase DELETE is executed with the authenticated session JWT via the Supabase Swift client; RLS enforces that only the owner's rows are deleted
- [ ] If all 7 Supabase deletes succeed, the Tracker is routed to the cycle profile onboarding screen via the Phase 2 app coordinator (because `CycleProfile` no longer exists, the coordinator's onboarding check triggers)
- [ ] If any Supabase delete fails, a non-blocking toast appears: `"Data deleted locally. Some remote data could not be deleted -- try again from Settings."` The Tracker remains on or is returned to `AccountView`; `isLoading` reverts to false
- [ ] `isLoading` is set to false on both success and failure before any navigation
- [ ] Unit test: inject mock `ModelContext` and mock Supabase client returning success for all 7 deletes; verify `modelContext.save()` called once after all SwiftData deletions, app coordinator `routeToOnboarding()` called
- [ ] Unit test: inject mock where Supabase `DELETE` for `reminder_settings` fails; verify toast appears and `routeToOnboarding()` is NOT called; verify local SwiftData was still purged

**Dependencies:** PH-12-E3-S3, PH-3 (all SwiftData @Model types), PH-1 (RLS delete policies on all tables)
**Notes:** Use `try modelContext.delete(model: DailyLog.self, where: #Predicate { $0.userId == userId })` for each type (SwiftData batch delete API available in iOS 17+, confirmed available in iOS 26). Do not fetch-then-delete-individually -- use the predicate-based batch delete for efficiency. The `userId` local variable is obtained from `supabase.auth.currentUser?.id.uuidString` before the async Supabase calls.

**Do NOT use `ModelContainer.deleteAllData()`** -- this API has a documented bug where it disconnects the SwiftData store from the container but does not delete the underlying SQLite data; data reappears on the next cold launch. The predicate-based `modelContext.delete(model:where:)` + `modelContext.save()` sequence is the only reliable full-purge approach in iOS 26 (confirmed: Apple Developer Documentation, Hacking With Swift).

---

### S5: Delete Account -- Edge Function Call + Full Teardown

**Story ID:** PH-12-E3-S5
**Points:** 5

Implement `AccountViewModel.deleteAccount() async throws`. Wire the "Delete Account" confirmation dialog. Execute: data purge (reuse `deleteAllData()` internals), Edge Function call to `DELETE /functions/v1/delete-account`, local sign out, route to auth screen. Handle Edge Function failure without leaving the user in an inconsistent state.

**Acceptance Criteria:**

- [ ] Tapping "Delete Account" presents a `.confirmationDialog` with title `"Delete your account?"`, message `"This permanently deletes your Cadence account and all associated data. This cannot be undone."`, a `"Delete Account"` action (`.destructive` role), and `"Cancel"` (`.cancel` role)
- [ ] Confirming calls `AccountViewModel.deleteAccount()` which sets `isLoading = true`
- [ ] `deleteAccount()` first executes the same local SwiftData purge as `deleteAllData()` (extract shared purge logic into a private helper to avoid duplication)
- [ ] After local purge, issues Supabase row deletions (same 7 DELETE calls as `deleteAllData()`)
- [ ] After Supabase row deletions, calls the Edge Function: `supabase.functions.invoke("delete-account", invokeOptions: .init(method: .post))` with the authenticated session; expects `{"success": true}` in the response body
- [ ] On Edge Function HTTP 200 with `{"success": true}`: calls `supabase.auth.signOut()` locally and routes to the auth screen via the Phase 2 app coordinator; `isLoading` is set to false before routing
- [ ] On Edge Function non-200 response or network failure: shows a non-blocking toast `"Account deletion failed. Your data has been cleared locally. Contact support if this persists."` and routes to the auth screen anyway (the user's local data is gone; the auth record may linger but the local app is fully cleared)
- [ ] The Edge Function endpoint is `"delete-account"` (the Supabase Swift client resolves this to the full URL using the project URL configured at initialization)
- [ ] Unit test: inject mock Supabase client where Edge Function call returns `{"success": true}`; verify `signOut()` is called and app coordinator `routeToAuth()` is called
- [ ] Unit test: inject mock Edge Function returning 500; verify toast is shown, `signOut()` is still called, and `routeToAuth()` is still called (user is routed out even on failure)

**Dependencies:** PH-12-E3-S3, PH-12-E3-S4, PH-1-E5 (Edge Function scaffold + delete-account function deployed)
**Notes:** The shared purge logic between `deleteAllData()` and `deleteAccount()` should be extracted to a `private func purgeLocalData() throws` and `private func purgeRemoteData() async throws` pair. Duplication between these two methods violates the "one concern per function" rule.

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
- [ ] Integration verified end-to-end: Tracker signs out -> auth screen appears -> signing back in restores the session with existing data intact
- [ ] Integration verified end-to-end: Tracker deletes all data -> Supabase dashboard shows zero rows for `user_id` across all 7 tables -> app shows cycle profile onboarding
- [ ] Integration verified end-to-end: Tracker deletes account -> Supabase Auth user record is absent from the dashboard -> auth screen appears with no sign-in session
- [ ] Phase objective is advanced: Tracker has full self-serve control over their data and account
- [ ] Applicable skill constraints satisfied: swiftui-production (@Observable, no AnyView, no force unwraps), cadence-design-system (CadenceDestructive used via token, no hardcoded hex), cadence-privacy-architecture (all user data -- including Sex symptom entries in symptom_logs -- is fully deleted in the purge), cadence-xcode-project (project.yml updated for all new files)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility: all destructive buttons have VoiceOver labels; confirmation dialogs are fully accessible (iOS system `.confirmationDialog` meets accessibility standards automatically)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: delete all data behavior matches MVP Spec §11 and PHASES.md Phase 12 in-scope exactly; CadenceDestructive usage matches Design Spec v1.1 §3

## Source References

- PHASES.md: Phase 12 -- Settings (in-scope: delete all data -- local SwiftData purge + Supabase data deletion + CadenceDestructive confirmation; account settings)
- MVP Spec §11 (Privacy and Settings -- Tracker settings: Delete all data, beta-appropriate privacy posture)
- Design Spec v1.1 §3 (CadenceDestructive: "Account deletion, disconnect -- use `.red` color asset")
- Design Spec v1.1 §13 (States -- error toast pattern: non-blocking, CadenceTextSecondary + warning.fill)
- PH-1-E5 (Edge Function scaffold -- deployment infrastructure for delete-account function)
- cadence-privacy-architecture skill (full user data deletability requirement)
- swiftui-production skill (@Observable, view extraction)
