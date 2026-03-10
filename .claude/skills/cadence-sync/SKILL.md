---
name: cadence-sync
description: "Governs Cadence's Supabase sync layer via SyncCoordinator. Defines the write queue pattern (local SwiftData first, background async queue, never blocks UI), conflict resolution (last-write-wins on updated_at — stale remote never overwrites fresher local), and Realtime subscription lifecycle for the Partner Dashboard. Covers Supabase auth session resilience with auto-refresh event handling, exponential backoff retry (3 attempts max, bounded delay with jitter), and NWPathMonitor-driven offline indicator state. Use whenever implementing or reviewing SyncCoordinator, write queue, SwiftData sync, Realtime subscriptions, offline-first writes, conflict resolution, retry behavior, auth token handling, or offline indicator state in Cadence. Triggers on any question about SyncCoordinator, sync_status, pending writes, Supabase flush, Realtime channel, NWPathMonitor, offline state, or sync-layer architecture in this codebase."
---

# Cadence Sync Architecture

Authoritative governance for Cadence's Supabase sync layer. All sync concerns — write queue, conflict resolution, Realtime subscriptions, auth resilience, retry, and offline state — are owned by `SyncCoordinator`. No sync logic belongs in ViewModels or Views.

---

## 1. SyncCoordinator Ownership

`SyncCoordinator` is the single owner of all sync concerns. It is instantiated once per app session and injected via `@Environment`.

Responsibilities:
- Maintains the ordered write queue of pending SwiftData writes
- Flushes the queue to Supabase on network restore
- Receives Realtime events and writes them to SwiftData
- Tracks `sync_status` (`pending | synced | error`) on each model
- Manages Realtime channel subscriptions for the Partner flow
- Owns the `NWPathMonitor` and publishes connectivity state
- Handles auth session events; never caches access tokens directly

**Nothing outside `SyncCoordinator` touches the Supabase Swift SDK for data writes or subscriptions.**

---

## 2. Write Queue Pattern — Local First

Every user write lands in SwiftData immediately. The UI updates from SwiftData before any network round-trip begins. The queue flush is entirely background.

```swift
actor SyncCoordinator {
    private var queue: [PendingWrite] = []
    private let supabase: SupabaseClient

    // Called immediately on every user action — returns before any network work
    func enqueue(_ write: PendingWrite) async {
        write.model.syncStatus = .pending
        queue.append(write)
        // Persist queue to survive termination
        await persistQueue()
    }

    // Called by NWPathMonitor on network restore — runs entirely off main actor
    func flush() async {
        for write in queue {
            do {
                try await attempt(write, maxAttempts: 3)
                write.model.syncStatus = .synced
            } catch {
                write.model.syncStatus = .error
                // Non-blocking UI indicator — publish error state, do not throw to UI
            }
        }
        queue.removeAll { $0.model.syncStatus != .pending }
    }
}
```

**Rules:**
- `enqueue()` must return before any network call begins. No `await supabase...` inside `enqueue`.
- The queue is ordered. Flush processes entries in insertion order to preserve causal consistency.
- Queue state persists across termination (write to SwiftData or UserDefaults at enqueue time). On next launch, `SyncCoordinator.init` reloads and resumes the queue.
- `sync_status` on each SwiftData model reflects exactly its queue state. ViewModels read `sync_status` — they do not own it.
- UI reads `sync_status == .error` to show the non-blocking per-element indicator. It never reads raw Supabase error state.

---

## 3. Conflict Resolution — Last-Write-Wins on `updated_at`

When a Realtime event or a flush response carries a remote row, compare `updated_at` timestamps before writing to local SwiftData. A stale remote value must never overwrite a fresher local write.

```swift
// Inside SyncCoordinator — called when Realtime delivers a remote update
func applyRemote<T: SyncableModel>(_ remote: T, to local: T) {
    guard remote.updatedAt > local.updatedAt else {
        // Remote is stale or equal — discard; do not overwrite local
        return
    }
    // Remote is fresher — apply and mark synced
    local.update(from: remote)
    local.syncStatus = .synced
}
```

**Rules:**
- The comparison is strict: `remote.updatedAt > local.updatedAt`. Equal timestamps are treated as local-wins (no-op).
- `SyncableModel` protocol requires `updatedAt: Date` and `syncStatus: SyncStatus` on every synced SwiftData model.
- Never apply a Realtime payload to a model whose `syncStatus == .pending`. A pending local write is always fresher — the remote event will arrive again after the local write flushes.
- Multi-device conflict resolution is post-beta per the PRD. The `updated_at` rule is sufficient for the MVP single-device assumption.

---

## 4. Realtime Subscription Management — Partner Dashboard

`SyncCoordinator` owns all Realtime channel subscriptions. The Partner Dashboard subscribes to `daily_logs`, `period_logs`, and `prediction_snapshots` for the linked Tracker's `user_id`. Subscriptions are filtered at the channel level — never subscribe to all rows and filter client-side.

```swift
actor SyncCoordinator {
    private var partnerChannel: RealtimeChannelV2?

    func subscribePartnerDashboard(trackerUserId: UUID) async {
        // Remove any existing channel before creating a new one — prevents duplicates
        if let existing = partnerChannel {
            await supabase.removeChannel(existing)
        }
        partnerChannel = await supabase
            .channel("partner-dashboard-\(trackerUserId)")
            .on(.postgresChanges,
                filter: .init(event: .all, schema: "public", table: "daily_logs",
                              filter: "user_id=eq.\(trackerUserId)")) { [weak self] payload in
                Task { await self?.handleRemoteChange(payload) }
            }
            .subscribe()
    }

    func unsubscribePartnerDashboard() async {
        if let channel = partnerChannel {
            await supabase.removeChannel(channel)
            partnerChannel = nil
        }
    }
}
```

**Rules:**
- Always call `removeChannel` before re-subscribing. Duplicate active channels waste Realtime connections and cause duplicate event delivery.
- Call `unsubscribePartnerDashboard()` in the Partner shell's `onDisappear` / `task` cancellation cleanup — not in `deinit` of a ViewModel.
- The Tracker flow never holds Realtime subscriptions for Tracker data. Tracker reads from local SwiftData exclusively; Realtime is for pushing data to the Partner.
- If the connection drops, the Supabase Swift SDK automatically reconnects. Do not manually recreate the channel on network restore — the SDK handles WebSocket reconnect. Only resubscribe if the channel was explicitly removed.
- Realtime events deliver remote rows. Always pass received payloads through `applyRemote` — never write directly to SwiftData from a Realtime closure.

---

## 5. Auth Session Resilience

Never cache or reuse a raw Supabase access token across async boundaries. Access tokens are short-lived (configured per project; typically 5–60 minutes). The Supabase Swift SDK auto-refreshes sessions in the background.

```swift
// CORRECT: use getSession() which refreshes if needed
func flushOneWrite(_ write: PendingWrite) async throws {
    let session = try await supabase.auth.session  // auto-refreshes if needed
    // session.accessToken is fresh — SDK has handled refresh internally
    try await supabase
        .from(write.table)
        .upsert(write.payload)
        .execute()
}

// Also: observe auth state changes to pause/resume queue and subscriptions
func observeAuthState() {
    Task {
        for await event in supabase.auth.authStateChanges {
            switch event.event {
            case .signedIn, .tokenRefreshed:
                await flush()  // resume queued writes after token refresh
                await resubscribeIfNeeded()
            case .signedOut:
                await cancelAllSync()
            default:
                break
            }
        }
    }
}
```

**Rules:**
- Never store `session.accessToken` in a property and reuse it. Call `supabase.auth.session` (the computed property) immediately before each Supabase SDK call — the SDK refreshes internally if needed.
- Listen to `supabase.auth.authStateChanges` in `SyncCoordinator.init` to resume the write queue after a `tokenRefreshed` event.
- If a flush attempt fails with a 401, do not retry the same request with the old token. Fetch a fresh session first, then retry.
- Realtime subscriptions automatically reconnect through token refresh. Do not tear down and recreate channels on `tokenRefreshed` — only on `signedOut`.

---

## 6. Exponential Backoff Retry

The write queue retries each entry up to 3 times (per PRD §12) with exponential backoff and jitter. After 3 failures, set `syncStatus = .error` and move on — do not block the queue on a failing entry.

```swift
private func attempt(_ write: PendingWrite, maxAttempts: Int) async throws {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do {
            try await supabase
                .from(write.table)
                .upsert(write.payload)
                .execute()
            return  // success — done
        } catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                let baseDelay: Double = 1.0  // seconds
                let exponential = baseDelay * pow(2.0, Double(attempt))
                let jitter = Double.random(in: 0...0.5)
                try await Task.sleep(for: .seconds(exponential + jitter))
            }
        }
    }
    throw lastError!
}
```

**Backoff schedule (base 1s, no jitter cap):**

| Attempt | Wait before next try |
|---------|---------------------|
| 1 (first) | Immediate |
| 2 | ~1s + jitter |
| 3 | ~2s + jitter |
| After 3 | Mark `.error`, skip |

**Rules:**
- The retry loop is per-entry. A failing entry does not block subsequent entries in the queue.
- After marking `.error`, continue processing the rest of the queue. The error is surfaced via `sync_status` on the model — the user sees a non-blocking per-element indicator.
- `Task.sleep` is the only permitted wait mechanism inside retry logic. No `Thread.sleep`, no `DispatchQueue.asyncAfter`.
- 401 errors (auth expiry) are not retried with backoff — fetch a fresh session first (§5), then retry immediately without counting the auth retry against the 3-attempt budget.

---

## 7. Offline Indicator State

`SyncCoordinator` owns a single `NWPathMonitor` instance and publishes connectivity state. ViewModels read this state — they never create their own monitors.

```swift
actor SyncCoordinator {
    // Published on main actor for UI consumption
    @MainActor private(set) var isOnline: Bool = true
    @MainActor private(set) var lastSyncedAt: Date? = nil

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.cadence.network")

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
                if online { await self?.flush() }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
```

**UI surface rules (from Design Spec §13 States):**
- When `isOnline == false`: display `"Last updated [lastSyncedAt]"` as a `footnote` in the navigation bar area. Do not block any feature.
- When a write enters the queue: show a non-blocking toast "Saving — will sync when online." (CadenceTextSecondary + `warning.fill` SF Symbol). Not destructive red.
- When `syncStatus == .error` on a model: show a non-blocking per-element indicator. Do not use system alert. Do not prevent further use of the screen.
- No full-screen offline states. No feature gates behind connectivity.

**Rules:**
- `NWPathMonitor` is a singleton within `SyncCoordinator`. Never create a second monitor instance in a ViewModel or View.
- The monitor's `pathUpdateHandler` fires on `monitorQueue` (a background thread). Always dispatch UI state updates to `@MainActor`.
- `NWPathMonitor.status == .satisfied` means a network path exists — it does not guarantee a successful Supabase connection. A flush failure with connectivity showing `.satisfied` is handled by the retry logic (§6), not by connectivity state.

---

## 8. UI-Thread Safety

All Supabase calls, queue flushes, Realtime event handling, and retry waits execute off the main actor. `SyncCoordinator` is declared `actor` to serialize its internal state safely.

```swift
// WRONG: Supabase call on main actor, blocks UI
@MainActor func save(_ log: DailyLog) async {
    try await supabase.from("daily_logs").upsert(log).execute()  // network on main thread
    log.syncStatus = .synced
}

// CORRECT: enqueue locally, background sync
@MainActor func save(_ log: DailyLog) {
    log.syncStatus = .pending        // immediate — SwiftData write, no network
    modelContext.insert(log)         // SwiftData write, synchronous and fast
    Task { await syncCoordinator.enqueue(PendingWrite(log)) }  // fire and forget
}
```

**Rules:**
- `SyncCoordinator` functions that call Supabase are `async` and must be called inside `Task {}` from `@MainActor` contexts, never `await`-ed directly on the main actor without a wrapping `Task`.
- `Task.detached` is preferred for flush operations to ensure they are not inherited by any actor context.
- Never call `supabase.from(...).execute()` from a `@MainActor` function body directly — this blocks the main runloop while waiting for the network response.
- SwiftData writes (`modelContext.insert`, property mutations) are fast and synchronous — these are acceptable on the main actor.

---

## 9. Anti-Pattern Table

| Anti-pattern | Rule violated |
|---|---|
| `await supabase...execute()` inside a ViewModel before updating UI | Remote-first write — violates local-first contract |
| UI state update blocked until Supabase confirms write | Violates optimistic UI — cadence-motion skill |
| Remote Realtime payload written directly to SwiftData without freshness check | Stale remote overwrites fresher local — §3 |
| `SyncCoordinator` not called before resubscribing to Realtime | Duplicate subscription — wastes connections, duplicate events |
| Realtime channel left alive after Partner Dashboard is dismissed | Subscription leak — §4 |
| Tight retry loop without sleep (while loop + immediate retry) | No backoff — thrashes network and burns battery |
| Storing `session.accessToken` in a property and reusing it | Stale token — sync fails when token rotates |
| 401 error retried with backoff using the old token | Token not refreshed before retry — §5 |
| `NWPathMonitor` created in a ViewModel | Duplicated monitor — SyncCoordinator owns the single instance |
| Full-screen offline blocker | Violates Design Spec §13 — non-blocking indicator only |
| `Thread.sleep` or `DispatchQueue.asyncAfter` inside retry | Blocks actor — use `Task.sleep` |
| Sync queue not persisted across app termination | Data loss risk — queue must survive termination |
| Multiple `SyncCoordinator` instances | Breaks queue ordering and subscription deduplication |

---

## 10. Enforcement Checklist

Before marking any sync-adjacent code complete:

- [ ] User write updates SwiftData and UI before any `supabase...execute()` call
- [ ] `enqueue()` returns without awaiting a network response
- [ ] Queue entries are persisted to SwiftData (not only in-memory) so termination does not lose them
- [ ] Flush processes queue in insertion order
- [ ] `applyRemote` compares `remote.updatedAt > local.updatedAt` before any SwiftData write
- [ ] Models with `syncStatus == .pending` are never overwritten by Realtime events
- [ ] Retry uses `Task.sleep` with exponential backoff — base 1s, max 3 attempts
- [ ] 401 errors fetch a fresh `supabase.auth.session` before the next attempt, not counted in backoff
- [ ] `authStateChanges` observed in `SyncCoordinator.init`; queue resumes on `tokenRefreshed`
- [ ] Partner Dashboard calls `subscribePartnerDashboard` in `.task {}` and `unsubscribePartnerDashboard` in cleanup
- [ ] `removeChannel` called before every new `subscribe` on the same logical channel
- [ ] `NWPathMonitor` is the single instance inside `SyncCoordinator`; no ViewModel creates its own
- [ ] `pathUpdateHandler` dispatches UI state updates to `@MainActor`
- [ ] Offline state surfaces as footnote + optional toast — no feature blocking
- [ ] All Supabase calls are in `async` functions on non-main actors, called via `Task {}` from UI layer
- [ ] No `Thread.sleep`, `DispatchQueue.asyncAfter`, or synchronous blocking waits in any sync path
- [ ] `SyncCoordinator` is a singleton — one instance per app session, injected via `@Environment`
