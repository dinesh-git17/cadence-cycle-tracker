# Offline Resilience, Retry, and Auth Session Continuity

**Epic ID:** PH-7-E4
**Phase:** 7 -- Sync Layer
**Estimated Size:** M
**Status:** Draft

---

## Objective

Make `SyncCoordinator` resilient to network interruptions, transient Supabase errors, and auth token rotation. This epic delivers: an `NWPathMonitor`-driven online/offline state that triggers `flush()` on network restore; an `attempt()` retry function with exponential backoff and jitter (3 attempts, base 1s); 401 auth expiry handling that fetches a fresh session before retrying outside the backoff budget; `authStateChanges` observation that resumes queued writes after token refresh and tears down sync on sign-out; and the offline UI surface defined in Design Spec v1.1 §13 (nav bar footnote, queued writes toast, sync failure toast). After this epic, `SyncCoordinator` is production-complete and fully operational in adverse network conditions.

## Problem / Context

The flush loop from PH-7-E1 is a raw Supabase upsert with no retry. A single transient 503 from Supabase marks every entry `.error`. A 401 after a token rotation blocks all writes until the user manually restarts the app. Without `NWPathMonitor`, the flush loop never fires when the device goes offline and back online -- writes queue up indefinitely. Without `authStateChanges` observation, a token refresh that happens in the background (common on iOS: app in background, token expires, SDK refreshes) leaves the flush loop blocked on a 401 it cannot recover from.

The Design Spec §13 mandates specific offline UI: a `footnote` in the navigation bar area (not a full-screen blocker), a non-blocking toast for queued writes, and a sync failure indicator using `CadenceTextSecondary` with a `warning.fill` SF Symbol (never destructive red). This epic implements those UI surfaces by publishing `isOnline` and `lastSyncedAt` from `SyncCoordinator` that ViewModels observe.

Source authority: cadence-sync skill §5 (Auth Session Resilience), §6 (Exponential Backoff Retry), §7 (Offline Indicator State); Design Spec v1.1 §13 (Offline, Error/Sync Failure states).

## Scope

### In Scope

- `private let monitor = NWPathMonitor()` and `private let monitorQueue = DispatchQueue(label: "com.cadence.network")` on `SyncCoordinator`
- `@MainActor private(set) var isOnline: Bool = true` published from `SyncCoordinator` (replaces the hardcoded `true` from Phase 3)
- `@MainActor private(set) var lastSyncedAt: Date?` published from `SyncCoordinator`; updated after each successful `flush()` completion
- `func startMonitoring()` on `SyncCoordinator`: starts `NWPathMonitor`, registers `pathUpdateHandler`, dispatches `isOnline` updates to `@MainActor`, calls `flush()` on network restore (`path.status == .satisfied`)
- `func stopMonitoring()` on `SyncCoordinator`: cancels the monitor (called on `signedOut`)
- `private func attempt(_ write: PendingWrite, maxAttempts: Int) async throws` on `SyncCoordinator`: retries a single write up to `maxAttempts` times with exponential backoff (`base 1.0s * 2^attempt + random(0...0.5)`) using `Task.sleep`; on 401 error, fetches a fresh session via `supabase.auth.session` and retries immediately without incrementing the attempt counter
- `flush()` updated to call `attempt(write, maxAttempts: 3)` instead of calling Supabase directly (replaces PH-7-E1-S4's bare upsert call)
- `func observeAuthState() async` on `SyncCoordinator`: listens to `supabase.auth.authStateChanges`; on `.signedIn` and `.tokenRefreshed` calls `flush()` and `resubscribeIfNeeded()`; on `.signedOut` calls `cancelAllSync()` (implemented in PH-7-E3-S6) and `stopMonitoring()`
- `private func resubscribeIfNeeded() async`: if `partnerChannel != nil` and auth session is active, calls `subscribePartnerDashboard` with the stored `trackerUserId` -- prevents stale subscriptions after token refresh
- `startMonitoring()` and `observeAuthState()` called at app launch from `CadenceApp` or `AppCoordinator` (wired at the same point as PH-7-E1's environment injection)
- Offline UI surfaces: `isOnline` and `lastSyncedAt` observable from `SyncCoordinator`; the Tracker Home feed's `NavigationStack` toolbar reads these to display the offline footnote; a non-blocking toast view triggered by `SyncCoordinator.hasPendingWrites` (new published `Bool` property)
- `var hasPendingWrites: Bool` on `SyncCoordinator`: `@MainActor` published property, `true` when `pendingCount > 0`
- `syncStartMonitoring()` and `observeAuthState()` added to `SyncCoordinatorProtocol`; stub implementations added to `FakeSyncCoordinator`
- Unit tests for retry behavior, auth expiry handling, and offline state transitions

### Out of Scope

- Full-screen offline blockers or feature gates behind connectivity (explicitly prohibited by Design Spec §13)
- Partner Dashboard Realtime subscription lifecycle beyond the `resubscribeIfNeeded` call (Phase 9 owns the view-level subscription lifecycle)
- Retry after `syncStatus == .error` (error state is terminal per MVP; the user must make a new write to re-enqueue; automatic retry of `.error` entries is post-beta)
- Push notification retry (Phase 10)
- Custom `NWPathMonitor` in any ViewModel or View (SyncCoordinator is the single monitor owner)

## Dependencies

| Dependency                                                                              | Type | Phase/Epic | Status | Risk |
| --------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ---- |
| flush() implementation (this epic wraps it with attempt())                              | FS   | PH-7-E1-S4 | Open   | Low  |
| applyRemote() and syncStatus lifecycle (this epic's retry relies on correct syncStatus) | FS   | PH-7-E2    | Open   | Low  |
| cancelAllSync() (called from observeAuthState on signedOut)                             | FS   | PH-7-E3-S6 | Open   | Low  |
| subscribePartnerDashboard (called from resubscribeIfNeeded)                             | FS   | PH-7-E3-S2 | Open   | Low  |
| SyncCoordinator environment injection at app launch (wired in PH-7-E1)                  | SS   | PH-7-E1-S3 | Open   | Low  |

## Assumptions

- `NWPathMonitor.status == .satisfied` means a network path exists. A path existing does not guarantee a successful Supabase connection. Flush failure with `isOnline == true` is handled by the retry logic, not by connectivity state.
- The Supabase Swift SDK automatically refreshes access tokens in the background. `SyncCoordinator` does not manage token storage or refresh scheduling -- it observes `authStateChanges` as a side-channel notification that a new token is available and resumes the flush loop.
- A 401 error from Supabase means the current access token was stale at the time of the call. The correct response is: call `supabase.auth.session` (which triggers an internal refresh if needed), then retry the same upsert immediately. This retry does not count against the 3-attempt budget because the failure was caused by token rotation, not by a transient network error.
- `Task.sleep` is the only permitted wait mechanism in retry logic. `Thread.sleep`, `DispatchQueue.asyncAfter`, or any synchronous blocking mechanism is prohibited (per cadence-sync skill §6).
- The offline footnote ("Last updated [time]") is displayed in the navigation bar area of the Tracker Home and Partner Dashboard. Its implementation uses `.toolbar` with a `.bottomBar` placement displaying `footnote`-style text in `CadenceTextSecondary`. It does not overlay content or block interaction.
- The non-blocking toast for queued writes is a `ZStack` overlay anchored to the bottom of the screen, styled per Design Spec §13: `CadenceTextSecondary` color, `warning.fill` SF Symbol, `footnote` text. It appears when `hasPendingWrites == true` and disappears when `hasPendingWrites == false`. No `UIAlertController`.

## Risks

| Risk                                                                                                                         | Likelihood | Impact | Mitigation                                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pathUpdateHandler fires on a background thread; SwiftData write or UI update without @MainActor dispatch causes crashes      | High       | High   | All SwiftData writes and @MainActor property mutations explicitly dispatched via Task { @MainActor in ... } inside pathUpdateHandler; verified by S1 AC |
| NWPathMonitor fires .satisfied on a cellular path that immediately fails a Supabase connection (false-positive connectivity) | Medium     | Low    | flush() errors are handled by attempt() retry; 3 failures mark .error; no crash, no data loss                                                           |
| Token refresh and flush() race: two concurrent flush() calls both attempt to upsert the same model                           | Low        | Low    | SyncCoordinator is an actor; flush() is serial by actor isolation; second flush() call queues behind the first                                          |
| resubscribeIfNeeded() called on tokenRefreshed when the user is a Tracker (not a Partner) and has no partnerChannel          | Medium     | Low    | Guard in resubscribeIfNeeded: if partnerChannel == nil, no-op immediately                                                                               |

---

## Stories

### S1: NWPathMonitor integration -- isOnline and lastSyncedAt

**Story ID:** PH-7-E4-S1
**Points:** 5

Implement the `NWPathMonitor` singleton inside `SyncCoordinator`. Replace the hardcoded `isOnline: Bool { true }` from Phase 3 with a live `@MainActor` published property driven by `pathUpdateHandler`. Publish `lastSyncedAt` updated after each successful `flush()`.

**Acceptance Criteria:**

- [ ] `private let monitor = NWPathMonitor()` declared on `SyncCoordinator`
- [ ] `private let monitorQueue = DispatchQueue(label: "com.cadence.network")` declared on `SyncCoordinator`
- [ ] `@MainActor private(set) var isOnline: Bool = true` replaces the Phase 3 hardcoded computed property; `SyncCoordinatorProtocol` updated to declare `var isOnline: Bool { get }` (was already there from Phase 3 as a stub -- now backed by real state)
- [ ] `@MainActor private(set) var lastSyncedAt: Date?` declared on `SyncCoordinator`
- [ ] `func startMonitoring()` exists:
- [ ] ````swift
          monitor.pathUpdateHandler = { [weak self] path in
              let online = path.status == .satisfied
              Task { @MainActor [weak self] in
                  self?.isOnline = online
                  if online { await self?.flush() }
              }
          }
          monitor.start(queue: monitorQueue)
          ```
      ````
- [ ] `func stopMonitoring()` exists: calls `monitor.cancel()`
- [ ] After each successful `flush()` (all queue entries processed without error), `lastSyncedAt` is set to `Date()` on `@MainActor`
- [ ] No second `NWPathMonitor` instance is created anywhere in the codebase (enforced: grep for `NWPathMonitor()` must return exactly one result in the `Cadence/` source tree)
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S4 (flush() must exist to be called on network restore), PH-3-E4 (isOnline property already declared in protocol -- this story wires it to real state)
**Notes:** `weak self` capture in `pathUpdateHandler` prevents a retain cycle between the monitor (which `SyncCoordinator` owns) and `SyncCoordinator` itself. The `Task { @MainActor in }` dispatch is the correct pattern for crossing from a background DispatchQueue into the actor context. Do not call `Task { await syncCoordinator.flush() }` directly from the `pathUpdateHandler` lambda -- it must go through the `@MainActor` dispatch first to update `isOnline` before flushing.

---

### S2: hasPendingWrites published property

**Story ID:** PH-7-E4-S2
**Points:** 2

Add `hasPendingWrites: Bool` as an `@MainActor` published property on `SyncCoordinator` so that the offline toast UI can observe it without directly accessing `pendingCount` (which is actor-isolated and not safely readable from `@MainActor` without `await`).

**Acceptance Criteria:**

- [ ] `@MainActor private(set) var hasPendingWrites: Bool = false` declared on `SyncCoordinator`
- [ ] `hasPendingWrites` is set to `true` inside `enqueue()` after appending to the queue (before the function returns)
- [ ] `hasPendingWrites` is set to `false` inside `flush()` after the queue is empty (after all entries are processed)
- [ ] `SyncCoordinatorProtocol` declares `var hasPendingWrites: Bool { get }`
- [ ] `FakeSyncCoordinator` exposes `var hasPendingWrites: Bool = false` (publicly settable for test injection)
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S4 (flush() must be the place where hasPendingWrites resets), PH-7-E4-S1 (MainActor property pattern established)

---

### S3: attempt() exponential backoff and flush() update

**Story ID:** PH-7-E4-S3
**Points:** 5

Implement `attempt(_ write: PendingWrite, maxAttempts: Int) async throws` with exponential backoff and jitter. Update `flush()` to call `attempt(write, maxAttempts: 3)` instead of the direct Supabase upsert from PH-7-E1-S4.

**Acceptance Criteria:**

- [ ] `private func attempt(_ write: PendingWrite, maxAttempts: Int) async throws` exists on `SyncCoordinator` with this exact backoff schedule:
  - Attempt 1: immediate (no sleep before first try)
  - Attempt 2: sleep `1.0 * pow(2.0, 0.0) + Double.random(in: 0...0.5)` seconds (approximately 1-1.5s)
  - Attempt 3: sleep `1.0 * pow(2.0, 1.0) + Double.random(in: 0...0.5)` seconds (approximately 2-2.5s)
  - After 3 failures: rethrow `lastError`
- [ ] Sleep uses `try await Task.sleep(for: .seconds(delay))` -- no `Thread.sleep`, no `DispatchQueue.asyncAfter`
- [ ] A failing entry does not block subsequent queue entries: `attempt()` catches and stores `lastError` per attempt; only throws after all attempts are exhausted; `flush()` catches the throw, marks `.error`, and continues to the next queue entry
- [ ] `flush()` updated: replace `try await supabase.from(...).upsert(...).execute()` with `try await attempt(write, maxAttempts: 3)`
- [ ] The backoff loop variable `attempt` (0-indexed) maps to: attempt 0 = immediate, attempt 1 = ~1s wait, attempt 2 = ~2s wait
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E1-S4 (flush() to be updated)
**Notes:** The base delay is 1.0 seconds. The exponential is `base * 2^attempt`. For attempt index 0, the wait before the first try is 0 (no sleep). Sleep occurs after a failed attempt, before the next retry. So: try -> fail -> sleep 1s -> try -> fail -> sleep 2s -> try -> fail -> throw.

---

### S4: 401 auth expiry handling in attempt()

**Story ID:** PH-7-E4-S4
**Points:** 3

Extend `attempt()` to detect 401 HTTP errors from Supabase, fetch a fresh access session, and retry the upsert immediately without consuming one of the 3 backoff attempts.

**Acceptance Criteria:**

- [ ] `attempt()` catches errors that are Supabase HTTP errors with status code 401
- [ ] On 401: `_ = try await supabase.auth.session` is called (forces internal SDK token refresh); the upsert is retried once immediately (the retry does not count against `maxAttempts`)
- [ ] If the immediate post-401 retry also fails with a non-401 error, that failure is counted as one of the `maxAttempts` and the backoff schedule resumes from the current attempt index
- [ ] If the immediate post-401 retry succeeds, `attempt()` returns normally (no backoff applied)
- [ ] A raw access token (`session.accessToken`) is never stored in a local variable that persists across `attempt()` calls; `supabase.auth.session` is called freshly before each upsert
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E4-S3 (attempt() must exist to be extended)
**Notes:** The Supabase Swift SDK's `supabase.auth.session` computed property triggers a background refresh if the session is expired. It must be called with `await` immediately before the Supabase upsert call that follows it. Do not cache the result across async suspension points.

---

### S5: authStateChanges observation

**Story ID:** PH-7-E4-S5
**Points:** 5

Implement `func observeAuthState() async` on `SyncCoordinator` to listen to `supabase.auth.authStateChanges` and take the correct action for each relevant auth event: resume the write queue and Realtime subscriptions on sign-in and token refresh; tear down sync on sign-out.

**Acceptance Criteria:**

- [ ] `func observeAuthState() async` exists on `SyncCoordinator` with this structure:
- [ ] ```swift
      for await (event, _) in supabase.auth.authStateChanges {
          switch event {
          case .signedIn, .tokenRefreshed:
              Task { await flush() }
              await resubscribeIfNeeded()
          case .signedOut:
              await cancelAllSync()
              stopMonitoring()
          default:
              break
          }
      }
      ```
- [ ] `flush()` on `.signedIn` / `.tokenRefreshed` is dispatched via `Task {}` to avoid blocking the auth event loop
- [ ] `resubscribeIfNeeded() async` exists: if `partnerChannel != nil` (a prior subscription existed), calls `subscribePartnerDashboard` with the last known `trackerUserId`; if `partnerChannel == nil`, no-op
- [ ] `private var lastKnownTrackerUserId: UUID?` stored on `SyncCoordinator` and set when `subscribePartnerDashboard(trackerUserId:)` is called, so `resubscribeIfNeeded()` has the ID available
- [ ] `cancelAllSync()` from PH-7-E3-S6 is called on `.signedOut` -- this empties the queue, marks pending writes `.error`, unsubscribes Realtime, and stops the monitor
- [ ] `observeAuthState()` is called at app launch (from `CadenceApp` or `AppCoordinator`) inside a long-lived `Task {}` that is retained for the app lifetime
- [ ] Build compiles without warnings

**Dependencies:** PH-7-E3-S6 (cancelAllSync()), PH-7-E3-S2 (subscribePartnerDashboard), PH-7-E4-S3 (flush() with retry)
**Notes:** The `for await` loop on `authStateChanges` is an async sequence that does not terminate until `SyncCoordinator` is deallocated. It must run in a long-lived `Task` at app startup. Do not use a short-lived task or a task tied to a View's `.task {}` modifier for this -- the auth observer must outlive any single view.

---

### S6: Offline UI surfaces -- footnote, pending writes toast, sync failure toast

**Story ID:** PH-7-E4-S6
**Points:** 5

Implement the three offline UI states defined in Design Spec v1.1 §13: (1) "Last updated [time]" footnote in the navigation bar area when offline; (2) non-blocking "Saving -- will sync when online" toast when `hasPendingWrites == true` while offline; (3) non-blocking sync failure toast when any model has `syncStatus == .error`. All three use `CadenceTextSecondary` and `warning.fill` SF Symbol. None block app functionality.

**Acceptance Criteria:**

- [ ] A `SyncStatusBar` SwiftUI view exists (`Cadence/Views/Components/SyncStatusBar.swift`) that:
  - Displays `"Last updated \(lastSyncedAt.formatted(.relative(presentation: .named)))"` as `.footnote` styled text in `CadenceTextSecondary` when `isOnline == false`
  - Is invisible (`EmptyView`) when `isOnline == true`
  - Accepts `isOnline: Bool` and `lastSyncedAt: Date?` as parameters (no direct `SyncCoordinator` dependency -- pure View)
- [ ] `SyncStatusBar` is placed in the Tracker Home's `NavigationStack` toolbar using `.toolbar { ToolbarItem(placement: .bottomBar) { SyncStatusBar(...) } }` (not in the content scroll view)
- [ ] A `SyncToast` SwiftUI view exists (`Cadence/Views/Components/SyncToast.swift`) that:
  - Displays a horizontal pill with `warning.fill` SF Symbol at 13pt and a `footnote` message
  - `"Saving -- will sync when online"` message when `hasPendingWrites == true` and `isOnline == false`
  - `"Sync failed -- tap to retry"` message when a model has `syncStatus == .error` (detected via a `hasSyncErrors: Bool` property from `SyncCoordinator` -- see below)
  - Uses `CadenceTextSecondary` for both icon and text; background is `CadenceCard` with 1pt `CadenceBorder`; corner radius 20pt
  - Is anchored at the bottom of the screen via a `ZStack` overlay; does not overlap content when a keyboard is present (uses `.safeAreaInset(edge: .bottom)`)
- [ ] `@MainActor private(set) var hasSyncErrors: Bool = false` added to `SyncCoordinator`; set to `true` when any flush attempt marks a model `.error`; set to `false` when all `.error` models are re-enqueued (a new write on the same model clears the error flag)
- [ ] `hasSyncErrors` added to `SyncCoordinatorProtocol`
- [ ] `SyncToast` uses `Color("CadenceTextSecondary")` and `Color("CadenceCard")` -- no hardcoded hex values
- [ ] `SyncStatusBar` uses `Color("CadenceTextSecondary")` -- no hardcoded hex values
- [ ] Both views pass the `no-hex-in-swift` hook check
- [ ] Both views have `accessibilityLabel` set: `SyncStatusBar` reads "Offline. Last synced [relative time]" to VoiceOver; `SyncToast` reads its full message string
- [ ] `project.yml` updated with both new view files

**Dependencies:** PH-7-E4-S1 (isOnline, lastSyncedAt), PH-7-E4-S2 (hasPendingWrites), PH-7-E4-S3 (flush updates hasSyncErrors)
**Notes:** The "tap to retry" on `SyncToast` for `.error` state is a no-op in this story -- it opens a future path. The gesture recognizer may be attached with an empty action for now; the actual retry mechanism is post-beta. The requirement is that the toast exists and is visible, not that retry is functional.

---

### S7: Retry, auth resilience, and offline state unit tests

**Story ID:** PH-7-E4-S7
**Points:** 5

Write unit tests for the retry backoff schedule, 401 handling, auth event routing, and offline state transitions.

**Acceptance Criteria:**

- [ ] `CadenceTests/Sync/OfflineResilienceTests.swift` exists
- [ ] **Test 1 -- retry backoff schedule:** Mock Supabase that fails twice then succeeds -> assert `attempt()` makes 3 total calls with sleep durations in the correct range (approximately 1s and 2s; use a time measurement or a mock clock)
- [ ] **Test 2 -- max attempts then error:** Mock Supabase that always throws -> assert `attempt()` throws after exactly 3 calls; model has `syncStatus == .error`; queue is empty after `flush()`
- [ ] **Test 3 -- 401 triggers fresh session:** Mock Supabase that returns 401 once then succeeds -> assert `supabase.auth.session` was called exactly once; total upsert attempts are 2 (immediate retry after 401); `attempt()` attempt budget was not decremented by the 401 retry
- [ ] **Test 4 -- isOnline flips on path change:** Call `pathUpdateHandler` with a mock `.unsatisfied` path -> assert `isOnline == false`; call again with `.satisfied` -> assert `isOnline == true` and `flush()` was called
- [ ] **Test 5 -- hasPendingWrites truth:** Enqueue one write -> assert `hasPendingWrites == true`; flush with succeeding mock -> assert `hasPendingWrites == false`
- [ ] **Test 6 -- authState signedIn triggers flush:** Call the auth event handler with `.signedIn` -> assert `flush()` was called (via `FakeSyncCoordinator.flushCallCount == 1`)
- [ ] **Test 7 -- authState signedOut triggers cancelAllSync:** Call auth handler with `.signedOut` -> assert `cancelAllSync()` was called; `pendingCount == 0`; `isOnline` is irrelevant (stopped)
- [ ] All tests use mock Supabase client and `FakeSyncCoordinator` for isolation; no live network calls
- [ ] Test file added to `project.yml`

**Dependencies:** PH-7-E4-S5, PH-7-E4-S4, PH-7-E4-S3

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
- [ ] `NWPathMonitor` appears exactly once in the `Cadence/` source tree (inside `SyncCoordinator`) -- verified by grep
- [ ] `isOnline`, `lastSyncedAt`, `hasPendingWrites`, `hasSyncErrors` are all `@MainActor` properties -- no ViewModel or View accesses them from a background thread
- [ ] `attempt()` uses `Task.sleep` exclusively -- no `Thread.sleep` or `DispatchQueue.asyncAfter` anywhere in the retry path (verified by grep)
- [ ] `supabase.auth.session` is called without caching the result across `async` suspension points (verified by code review)
- [ ] `observeAuthState()` is wired at app launch in a long-lived `Task` -- not tied to any View lifecycle
- [ ] `SyncStatusBar` and `SyncToast` contain no hardcoded hex values; both pass the `no-hex-in-swift` hook
- [ ] Both UI components have valid `accessibilityLabel` values
- [ ] All 7 tests in `OfflineResilienceTests.swift` pass
- [ ] Phase 7 primary goal verified end-to-end: turn device to Airplane Mode -> log a period -> restore connectivity -> confirm SwiftData write reached Supabase (verified manually in Simulator with Supabase Table Editor)
- [ ] Applicable skill constraints satisfied: `cadence-sync` (§5 auth session resilience; §6 exponential backoff -- base 1s, 3 attempts, jitter, Task.sleep; §7 offline indicator state -- footnote + non-blocking toast; no full-screen offline blocker; single NWPathMonitor instance); `cadence-accessibility` (VoiceOver labels on both UI components); `cadence-design-system` (CadenceTextSecondary, CadenceCard, CadenceBorder tokens only; no hardcoded hex)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code, stubs, or placeholder comments

## Source References

- PHASES.md: Phase 7 -- Sync Layer (In-Scope: NWPathMonitor offline state; exponential backoff retry 3 attempts with jitter; Supabase auth session auto-refresh; non-blocking offline UI; sync failure toast)
- cadence-sync skill §5 (Auth Session Resilience -- supabase.auth.session, authStateChanges observer, 401 handling, Realtime does not need teardown on tokenRefreshed)
- cadence-sync skill §6 (Exponential Backoff Retry -- base 1s, 2^attempt, jitter 0-0.5s, Task.sleep, 401 is not counted against backoff budget)
- cadence-sync skill §7 (Offline Indicator State -- isOnline, lastSyncedAt, @MainActor, NWPathMonitor singleton, non-blocking toast, no full-screen offline state)
- cadence-sync skill §8 (UI-Thread Safety -- all Supabase calls in async functions on non-main actors)
- Design Spec v1.1 §13 (Offline: footnote "Last updated [time]" in nav bar area; Error/Sync Failure: non-blocking toast, CadenceTextSecondary + warning.fill, no destructive red)
- cadence-accessibility skill (44pt touch targets, VoiceOver labels, reduced motion gating on any toast animation)
- cadence-design-system skill (CadenceTextSecondary, CadenceCard, CadenceBorder token usage; no hardcoded hex)
- PH-7-E1 (flush() -- this epic replaces its direct upsert with attempt())
- PH-7-E3-S6 (cancelAllSync() -- called from auth observer on signedOut)
