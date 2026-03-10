# cadence-sync Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-sync/SKILL.md`
**Skill-creator path:** `.claude/skills/skill-creator/`

---

## Local Files Read

| File | Purpose |
|------|---------|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure conventions, YAML frontmatter format, 1024-char description limit, 500-line body limit, imperative style, description-as-trigger pattern |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — sync architecture (§12), SyncCoordinator spec (§5), auth (§13), offline state (§8.5), NFRs (§16), symptom logging optimistic UI (§7.5) |
| `docs/Cadence_Design_Spec_v1.1.md` | Locked design spec v1.1 — offline/error states (§13), motion spec §11 (optimistic dismiss) |

---

## Skill-Creator Usage

Invoked via `Skill` tool (`skill-creator`). SKILL.md authored directly following all conventions from the skill-creator. Validated with `quick_validate.py` (pass).

---

## Anthropic Sources Used for Skill Standards

Project-local `skill-creator` at `.claude/skills/skill-creator/SKILL.md`. Key rules applied:
- YAML frontmatter: quoted description ≤1024 chars, `name` kebab-case
- All "when to use" in description frontmatter
- Body under 500 lines, imperative form
- No auxiliary files (README, etc.)

---

## Supabase / Apple / Authoritative Sources Used

| Source | Used for |
|--------|---------|
| `supabase.com/docs/reference/swift/subscribe` | Channel subscription API in Swift SDK |
| `supabase.com/docs/reference/swift/removechannel` | Channel removal/cleanup — prevents leaky subscriptions |
| `supabase.com/docs/reference/swift/removeallchannels` | Bulk channel cleanup |
| `supabase.com/docs/guides/realtime` | Realtime overview — cleanup 30s after disconnect, unused channels cause degradation |
| `supabase.com/docs/guides/realtime/postgres-changes` | Realtime Postgres changes subscription patterns |
| `supabase.com/docs/guides/auth/sessions` | Auth session lifecycle — short-lived access tokens, single-use refresh tokens |
| `supabase.com/docs/reference/swift/auth-refreshsession` | `getSession()` auto-refresh behavior in Swift SDK |
| `developer.apple.com/documentation/network/nwpathmonitor` | NWPathMonitor — strong reference requirement, background handler thread, pathUpdateHandler |
| `swift.org` / Swift Forums | Exponential backoff with `Task.sleep` in async Swift — no stdlib support yet, manual implementation required |
| `swiftbysundell.com/articles/retrying-an-async-swift-task/` | Retry pattern with Swift Concurrency (supplementary) |

---

## Cadence-Specific Sync Facts Extracted from Docs

### From Cadence-design-doc.md §5 Architecture
- Named component: `SyncCoordinator`
- Architecture: `SwiftUI Views ↕ @Observable ViewModels ↕ SwiftData (local store) ↕ SyncCoordinator ↕ Supabase Swift SDK`
- SyncCoordinator responsibilities: flush pending writes, receive Realtime events, mark `sync_status: pending | synced | error`, conflict resolution `updated_at` last-write-wins
- Realtime: "Supabase DB change listeners — filtered via RLS; no custom broadcast layer"

### From Cadence-design-doc.md §12 Offline and Sync Architecture
- SwiftData is local source of truth; Supabase is authoritative remote
- Ordered write queue, flushed on network restore via `NWPathMonitor`
- **3 retry attempts** before `syncStatus = .error`
- Conflict resolution: last-write-wins on `updated_at`. Multi-device post-beta.
- Realtime events received by SyncCoordinator → written to SwiftData → UI via @Observable
- Partner data: separate read-only SwiftData store, never written by Partner client
- Queue survives termination and resumes on next launch
- Realtime reconnect handled automatically by Swift SDK

### From Cadence-design-doc.md §13 Auth
- Supabase session token in iOS Keychain
- SDK handles refresh automatically
- On expiry: user shown auth screen

### From Cadence_Design_Spec_v1.1.md §13 States
- Offline: UI renders from SwiftData seamlessly
- "Last updated [time]" footnote in nav bar area
- Non-blocking toast for queued writes
- Error/sync failure: non-blocking toast, CadenceTextSecondary + `warning.fill` SF Symbol — not red
- Success: haptic feedback on Log save, no toast

### From Cadence-design-doc.md §16 NFRs
- Dashboard load from SwiftData: < 100ms
- Symptom log save (optimistic): < 50ms to UI update
- No data loss on termination (SwiftData persists before any network write)

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|-----------|-----------|
| Docs say "conflict resolution: last-write-wins on `updated_at`" but do not specify what happens if remote `updated_at` equals local | Resolved: equal timestamps treated as local-wins (no-op). Conservative choice — local writes are trusted, equal timestamps do not justify overwriting user data. Stated in skill. |
| Docs say "3 retries" but do not specify backoff duration or jitter | Resolved using exponential backoff standard practice: base 1s, multiply by 2^attempt, add random jitter 0–0.5s. This matches the general industry standard and avoids thundering-herd on server restore. Not prescribed in docs — encoded as the safe default. |
| Docs say "Realtime reconnect handled automatically by Swift SDK" — unclear if this covers channel reconnect after explicit `removeChannel` | Resolved conservatively: skill states the SDK reconnects WebSocket on network restore automatically, but explicit `removeChannel` destroys the subscription. Only recreate channel after explicit removal, not after a transient disconnect. |
| Auth docs say "SDK handles refresh automatically" — unclear if this means sync code needs to do nothing | Resolved: `supabase.auth.session` (the computed property) is the correct access point — it auto-refreshes before returning. However, `authStateChanges` must be observed to resume the write queue after `tokenRefreshed` events. Both patterns are stated in the skill. |
| Docs mention "non-blocking toast for queued writes" but do not specify exact trigger timing (on enqueue vs on flush attempt) | Resolved conservatively: toast appears when a write enters the queue while offline (`isOnline == false`). Not on every enqueue unconditionally — only when the user is offline. This matches the spirit of "queued writes" feedback. |

---

## Key Enforcement Rules Encoded

1. `SyncCoordinator` is the single owner of all Supabase SDK calls — no ViewModel touches Supabase directly
2. `enqueue()` returns before any network call — local SwiftData write is the only synchronous work
3. Queue is ordered; flush processes in insertion order to preserve causal consistency
4. Queue persists across app termination (written to SwiftData at enqueue time)
5. `applyRemote` compares `remote.updatedAt > local.updatedAt` — stale remote is discarded silently
6. `syncStatus == .pending` models are never overwritten by Realtime events
7. Retry: 3 attempts max, exponential backoff with jitter (base 1s), `Task.sleep` only
8. 401 errors: fetch fresh `supabase.auth.session` before retry; not counted against backoff budget
9. `authStateChanges` observed in `SyncCoordinator.init`; flush resumes on `tokenRefreshed`
10. `removeChannel` called before every re-subscribe to prevent duplicate subscriptions
11. Partner Dashboard unsubscribes in `.task {}` cleanup — not in `deinit`
12. Tracker flow holds zero Realtime subscriptions — reads from local SwiftData only
13. `NWPathMonitor` singleton inside `SyncCoordinator`; `pathUpdateHandler` dispatches to `@MainActor` for UI
14. Offline state surfaces as non-blocking footnote + optional toast — no feature gates
15. All Supabase calls in `async` functions on non-main actors, called via `Task {}` from UI layer
16. `SyncCoordinator` is `actor` — no `@MainActor`, no ViewModel-level Supabase calls
