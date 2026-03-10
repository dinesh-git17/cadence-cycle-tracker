---
name: cadence-supabase
description: "Governs all Cadence Supabase architecture: project configuration on org dinbuilds, the exact RLS policy structure for asymmetric Tracker/Partner data access, Realtime channel setup for the Partner Dashboard, Edge Function patterns for APNS push dispatch, typed supabase-swift client enforcement, and the full partner connection flow and permission checklist sync model. Use this skill whenever writing, reviewing, or designing any Supabase-backed feature in Cadence — including auth integration, database migrations, RLS policies, Realtime subscriptions, Edge Functions, Swift client queries, partner connection logic, or permission flag handling. Triggers on any question about Supabase tables, RLS, partner_connections, share_* flags, is_paused, is_private, invite_code flow, Realtime channels, Edge Functions, APNS push, SupabaseClient initialization, typed query construction, auth session handling, or the Supabase sync layer in this codebase."
---

# Cadence Supabase — Architecture Governance Skill

**Authority:** This skill is the authoritative governance layer for all Supabase architecture decisions in Cadence. It owns project configuration expectations, RLS policy structure, Realtime channel patterns, Edge Function patterns, typed Swift client discipline, and Supabase-backed partner/share flows.

**Account state (verified March 7, 2026 via Supabase MCP):**

- Organization: `dinbuilds` (ID: `hekdjznkviujumcsbqip`, plan: free)
- Projects: **none** — the Cadence Supabase project does not yet exist
- This skill governs the intended Cadence project architecture for the project that will be created on this account

**Repository state:** Pre-implementation — no Swift source files, no Supabase client code, no service layers exist yet. All architecture defined here is prospective, grounded in locked Cadence docs.

**Companion skills:** `cadence-privacy-architecture` (RLS alignment + payload privacy), `cadence-sync` (SyncCoordinator write queue), `cadence-data-layer` (SwiftData schema + offline-first)

---

## 1. Project Configuration Governance

**Single Supabase project** for Cadence. Name: `cadence`. Region: nearest to primary beta cohort. Create on org `dinbuilds`.

**Environment variables — never hardcode in Swift source:**

```swift
// Load from Info.plist entries backed by .xcconfig, never literals
let supabaseURL = URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "")!
let supabaseKey = (Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String) ?? ""
```

**SupabaseClient is a singleton.** One instance per app lifecycle, initialized at startup, injected into services.

```swift
// Services/SupabaseClient.swift
import Supabase

let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
```

**Never** scatter `SupabaseClient(...)` initializations across view files or ViewModels. All Supabase access goes through the singleton via service layer.

**Supabase project checklist (before any implementation begins):**

- [ ] Project created on org `dinbuilds` via Supabase dashboard
- [ ] `SUPABASE_URL` and `SUPABASE_ANON_KEY` placed in `.xcconfig` (gitignored)
- [ ] Auth → Email enabled; Apple OAuth provider configured
- [ ] `supabase-swift` added via Swift Package Manager: `github.com/supabase/supabase-swift`
- [ ] RLS enabled on every table at creation — never off

---

## 2. Data Model — Source of Truth

The following 8 tables are the canonical Cadence schema. Do not add, remove, or rename tables or columns without an explicit spec update.

```sql
-- users: Supabase Auth UID is the primary key
users          (id uuid PK, created_at timestamptz, role text CHECK('tracker','partner'), timezone text)
cycle_profiles (user_id uuid FK→users, average_cycle_length int, average_period_length int,
                goal_mode text CHECK('track','conceive'), predictions_enabled bool)
partner_connections (id uuid PK, tracker_id uuid FK→users, partner_id uuid FK→users,
                     invite_code text, connected_at timestamptz, is_paused bool,
                     share_predictions bool, share_phase bool, share_symptoms bool,
                     share_mood bool, share_fertile_window bool, share_notes bool)
period_logs    (id uuid PK, user_id uuid FK→users, start_date date, end_date date,
                source text CHECK('manual','predicted'))
daily_logs     (id uuid PK, user_id uuid FK→users, date date, flow_level text,
                mood text, sleep_quality int, notes text, is_private bool DEFAULT true)
symptom_logs   (id uuid PK, daily_log_id uuid FK→daily_logs, symptom_type text)
prediction_snapshots (id uuid PK, user_id uuid FK→users, date_generated timestamptz,
                      predicted_next_period date, predicted_ovulation date,
                      fertile_window_start date, fertile_window_end date,
                      confidence_level text CHECK('high','medium','low'))
reminder_settings (id uuid PK, user_id uuid FK→users, remind_period bool,
                   remind_ovulation bool, remind_daily_log bool,
                   notify_partner_period bool, notify_partner_symptoms bool,
                   notify_partner_fertile bool, reminder_time time)
```

`is_private` defaults to `true` on `daily_logs` — opt-in sharing, not opt-in privacy.

---

## 3. RLS Policy Structure

**Every table has RLS enabled. No exceptions.**

**Principle of least privilege:** Grant only what is explicitly required. Any doubt → deny.

### 3.1 Ownership policies (all tables)

```sql
-- Pattern: Tracker/user owns their own rows
CREATE POLICY "owner_read" ON daily_logs FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "owner_insert" ON daily_logs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner_update" ON daily_logs FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "owner_delete" ON daily_logs FOR DELETE USING (user_id = auth.uid());
```

Apply this ownership pattern to: `cycle_profiles`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings`.

### 3.2 Partner read access — the critical policy

Partner read on `daily_logs` requires ALL four conditions simultaneously:

```sql
CREATE POLICY "partner_read_daily_logs" ON daily_logs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM partner_connections pc
    WHERE pc.tracker_id = daily_logs.user_id
      AND pc.partner_id = auth.uid()
      AND pc.is_paused = false
      AND pc.share_symptoms = true   -- or share_mood, share_notes per context
      AND daily_logs.is_private = false
  )
);
```

**Category-specific partner read policies:**

| Table                              | Condition columns in partner_connections                                |
| ---------------------------------- | ----------------------------------------------------------------------- |
| `daily_logs` (symptoms/mood/notes) | `is_paused = false`, relevant `share_*` flag, `is_private = false`      |
| `period_logs`                      | `is_paused = false`, `share_predictions = true`                         |
| `prediction_snapshots`             | `is_paused = false`, `share_predictions = true` OR `share_phase = true` |
| `partner_connections`              | Partner reads their own row: `partner_id = auth.uid()`                  |

**Never** grant partner access to: `cycle_profiles`, `symptom_logs` directly (join via `daily_logs` policy), `reminder_settings`, `users` beyond their own row.

### 3.3 `is_private` as master override

`is_private = true` on a `daily_log` row blocks Partner access regardless of all other flags. The RLS policy must check this as a hard gate — no application code can override it. See `cadence-privacy-architecture` skill for full contract.

### 3.4 `is_paused` as global override

`is_paused = true` on `partner_connections` blocks ALL Partner read access on `daily_logs`, `period_logs`, and `prediction_snapshots` — even when individual `share_*` flags are true. Every partner-read policy must include `pc.is_paused = false`.

### 3.5 `partner_connections` write policy

Only the Tracker can update `partner_connections`. The Partner cannot modify sharing flags.

```sql
CREATE POLICY "tracker_update_connection" ON partner_connections
  FOR UPDATE USING (tracker_id = auth.uid());
```

### 3.6 RLS policy review checklist

Before deploying any new or modified RLS policy:

- [ ] Policy uses `auth.uid()` — never client-provided user IDs
- [ ] Partner-read policies include `is_paused = false`
- [ ] Partner-read policies for `daily_logs` include `is_private = false`
- [ ] Write policies use `WITH CHECK` to prevent row injection
- [ ] `symptom_logs` is never directly read by Partner (partner reads via `daily_logs` JOIN only)
- [ ] Sex symptom rows excluded from any partner-facing query projection (per `cadence-privacy-architecture`)
- [ ] RLS is ON for the table before any data is written to it

---

## 4. Typed Swift Client Enforcement

**All Supabase table interactions use typed `Codable` structs.** No raw dictionary payloads, no `[String: Any]`, no untyped JSON in service layers.

**Swift model pattern:**

```swift
// Models/SupabaseModels.swift — transport-layer types, not domain models
struct DailyLogRow: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let date: Date
    let flowLevel: FlowLevel?
    let mood: String?
    let sleepQuality: Int?
    let notes: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, mood, notes
        case userId = "user_id"
        case flowLevel = "flow_level"
        case sleepQuality = "sleep_quality"
        case isPrivate = "is_private"
    }
}
```

**Query pattern — always project columns explicitly, never `.select("*")`:**

```swift
// Services/LogService.swift
func fetchDailyLog(for date: Date) async throws -> DailyLogRow? {
    try await supabase
        .from("daily_logs")
        .select("id, user_id, date, flow_level, mood, sleep_quality, notes, is_private")
        .eq("user_id", value: currentUserId)
        .eq("date", value: date.isoDateString)
        .single()
        .execute()
        .value
}
```

**Transport vs domain boundary:** `SupabaseModels.swift` types are transport shapes only. Domain models in `Cadence/Models/` are distinct. Service layer converts between them. ViewModels never call Supabase directly.

**Forbidden — reject immediately:**

- `supabase.from("daily_logs").select()` with no column projection on partner-facing queries
- Passing `[String: Any]` to `.insert()` or `.update()` — use typed structs
- Constructing RLS-relevant filters in ViewModels — filters belong in service layer only
- Calling `supabase.functions.invoke(...)` from a View or ViewModel

---

## 5. Partner Connection Flow

The partner connection flow is the most security-sensitive feature. Every step must be database-backed with server-side validation.

### 5.1 Invite code generation

- **Server-side only.** Generate the 6-digit invite code in a Supabase Edge Function or Postgres function — not in Swift client code.
- Store in `partner_connections.invite_code` with `connected_at = null` (pending) and `invited_at = now()`.
- Expiry: 24 hours from generation. Enforce expiry server-side (Edge Function or `CHECK` constraint).
- Only one pending or active connection per `tracker_id` (enforce with unique index).

```sql
-- Prevent multiple connections per Tracker
CREATE UNIQUE INDEX idx_one_connection_per_tracker
  ON partner_connections (tracker_id)
  WHERE partner_id IS NOT NULL;
```

### 5.2 Connection redemption (Partner side)

1. Partner submits invite code → Swift client calls Edge Function `redeem-invite` with code
2. Edge Function: validates code exists, is not expired, has no existing `partner_id`
3. Function sets `partner_connections.partner_id = auth.uid()`, `connected_at = now()`, clears `invite_code`
4. Returns connection summary to Tracker (via Realtime or polling) for confirmation screen
5. Tracker confirms → connection is live; RLS policies activate immediately

**Never** allow the Swift client to directly `UPDATE partner_connections SET partner_id = ...` — this must go through a validated Edge Function.

### 5.3 Disconnect

- Tracker calls authenticated RPC or Edge Function to delete the `partner_connections` row
- Row deletion → RLS policies immediately deny all Partner read access
- No soft-delete: deletion is the access revocation mechanism

### 5.4 Permission checklist sync

- `partner_connections` IS the permission checklist — `share_predictions`, `share_phase`, `share_symptoms`, `share_mood`, `share_fertile_window`, `share_notes`
- Tracker updates via authenticated PATCH: `supabase.from("partner_connections").update(...).eq("tracker_id", value: currentUserId)`
- Optimistic local update in ViewModel → background flush → Realtime confirms to Partner Dashboard
- `is_paused` is a single override: when `true`, all partner access is suspended regardless of `share_*` values
- The permission checklist is never computed client-side — the database state is the contract

---

## 6. Realtime Channel Setup

Realtime powers the Partner Dashboard live updates. Channel naming and lifecycle must be explicit and consistent.

### 6.1 Partner Dashboard channel

```swift
// Services/RealtimeService.swift
func subscribeToPartnerUpdates(trackerUserId: UUID) {
    channel = supabase.channel("partner-dashboard-\(trackerUserId.uuidString.lowercased())")

    channel
        .on(.postgresChanges,
            filter: ChannelFilter(event: "*", schema: "public", table: "daily_logs",
                                  filter: "user_id=eq.\(trackerUserId)")) { payload in
            Task { await self.handleDailyLogChange(payload) }
        }
        .on(.postgresChanges,
            filter: ChannelFilter(event: "*", schema: "public", table: "partner_connections",
                                  filter: "tracker_id=eq.\(trackerUserId)")) { payload in
            Task { await self.handleConnectionChange(payload) }
        }
        .subscribe()
}

func unsubscribeFromPartnerUpdates() {
    Task { await supabase.removeChannel(channel) }
}
```

### 6.2 Channel lifecycle rules

- **Subscribe** when the Partner Dashboard view appears (`task {}` modifier in SwiftUI)
- **Unsubscribe** when the view disappears (`onDisappear`) and on app background
- Never subscribe before the auth session is active
- Handle `.subscribed`, `.channelError`, `.closed` states explicitly — surface reconnect state via `cadence-sync` NWPathMonitor pattern
- One channel per purpose — do not bundle unrelated table subscriptions into one channel

### 6.3 Tracker-side Realtime (permission changes)

- If permissions change while Partner is viewing: `partner_connections` change event should trigger Partner Dashboard refresh
- Pause state change (`is_paused` flip): Realtime event → Partner sees "Sharing paused" card immediately
- Do not rely on polling for permission state — Realtime is the primary update mechanism

---

## 7. Edge Function Patterns — Push Dispatch

Push notifications to Partners must originate from the backend. The Swift client never dispatches APNS payloads directly.

### 7.1 Function structure

```
supabase/functions/
├── notify-partner/index.ts      # Partner push dispatcher
├── redeem-invite/index.ts       # Invite code redemption
└── generate-invite/index.ts     # Invite code generation
```

### 7.2 Push dispatch pattern (`notify-partner`)

```typescript
// supabase/functions/notify-partner/index.ts (Deno)
// Triggered by: database webhook on daily_logs INSERT, or called by client after log save
// 1. Receive event: { trackerId, eventType: 'symptom_logged' | 'period_expected' | 'fertile_window' }
// 2. Look up partner_connections WHERE tracker_id = trackerId AND is_paused = false
// 3. Check relevant notify_partner_* flag in reminder_settings
// 4. Look up Partner's device token from a device_tokens table
// 5. Construct APNS payload
// 6. Dispatch via fetch to APNS endpoint with JWT auth
```

**APNS private key** is stored only as a Supabase Edge Function secret (`supabase secrets set APNS_PRIVATE_KEY=...`). Never in Swift source, `.xcconfig`, or any client-readable location.

### 7.3 Client invocation (when needed)

```swift
// Only called from service layer, never from ViewModels or Views
try await supabase.functions.invoke(
    "notify-partner",
    options: .init(body: ["trackerId": currentUserId, "eventType": "symptom_logged"])
)
```

### 7.4 Edge Function rules

- Edge Functions never bypass RLS — they use the service role key only when absolutely necessary and document why
- All Edge Functions validate the calling user's JWT before acting
- APNS device tokens stored in a `device_tokens` table: `(user_id, token, platform, updated_at)` — with ownership RLS

---

## 8. Auth Session Integration

**Supabase Auth is the identity layer.** The `users.id` column equals the Supabase Auth UID.

```swift
// Services/AuthService.swift
func observeAuthState() {
    Task {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                await handleSignedIn(session: session)
            case .signedOut:
                await handleSignedOut()
            case .tokenRefreshed:
                break // supabase-swift handles token refresh automatically
            default:
                break
            }
        }
    }
}
```

- Never read `supabase.auth.session` synchronously in UI code — observe state changes
- `supabase-swift` handles JWT auto-refresh — do not manually manage token expiry
- Role (`tracker` / `partner`) is stored in `users.role`, NOT in JWT claims — fetch from `users` table after sign-in
- Sign in with Apple and email/password both use Supabase Auth; the `users` row is created via trigger on `auth.users` insert

---

## 9. Architectural Boundary Rules

| Concern                         | Owned by                         | Must NOT appear in                                      |
| ------------------------------- | -------------------------------- | ------------------------------------------------------- |
| SupabaseClient initialization   | `Services/SupabaseClient.swift`  | Views, ViewModels, Models                               |
| Typed query construction        | `Services/` layer                | ViewModels, Views                                       |
| Auth session observation        | `Services/AuthService.swift`     | ViewModels directly                                     |
| RLS-critical filters            | SQL policies + service layer     | Client-side only logic                                  |
| Realtime subscription lifecycle | `Services/RealtimeService.swift` | Views (manage via ViewModel)                            |
| Edge Function invocation        | `Services/` layer                | Views, ViewModels                                       |
| Partner connection logic        | `Services/PartnerService.swift`  | TrackerShell, Settings views                            |
| Permission checklist write      | `Services/PartnerService.swift`  | ViewModels (call service, don't directly call Supabase) |
| APNS key material               | Edge Function secrets            | Anywhere in iOS project                                 |

---

## 10. Anti-Pattern Reference

| Anti-pattern                                                     | Rule                 | Correction                                                 |
| ---------------------------------------------------------------- | -------------------- | ---------------------------------------------------------- |
| `SupabaseClient(...)` in a View                                  | §1 singleton rule    | Inject via service; initialize once at app start           |
| Hardcoded Supabase URL in Swift                                  | §1 env var rule      | Load from xcconfig → Info.plist                            |
| `.select("*")` on partner-facing query                           | §4 typed client      | Always project named columns                               |
| `[String: Any]` payload to `.insert()`                           | §4 typed client      | Use `Codable` struct                                       |
| RLS disabled on any table                                        | §3 RLS               | Enable RLS at table creation; never disable                |
| Partner-read policy missing `is_paused = false`                  | §3.4                 | Add `AND pc.is_paused = false` to every partner policy     |
| Partner-read policy on `daily_logs` missing `is_private = false` | §3.3                 | Add `AND daily_logs.is_private = false`                    |
| Invite code generated in Swift client                            | §5.1                 | Use `generate-invite` Edge Function                        |
| Partner directly `UPDATE`s `partner_connections`                 | §5.2                 | Redemption via `redeem-invite` Edge Function only          |
| APNS dispatch from Swift client                                  | §7                   | Push via `notify-partner` Edge Function only               |
| Realtime channel never unsubscribed                              | §6.2                 | Unsubscribe in `onDisappear` and app background            |
| Supabase calls in ViewModel directly                             | §9 boundary          | ViewModel calls service; service calls Supabase            |
| Sex symptom in partner-facing query projection                   | privacy-architecture | Always exclude `symptom_type = 'sex'` from partner queries |
| `users.role` read from JWT claims                                | §8                   | Query `users` table post-sign-in; JWT has no role claim    |
