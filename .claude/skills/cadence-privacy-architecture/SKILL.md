---
name: cadence-privacy-architecture
description: "Enforces Cadence's asymmetric sharing model in code. Governs isPrivate as a master override before any RLS evaluation, validates Partner-facing queries never over-expose Tracker fields, enforces Sex symptom exclusion from all sync payloads, and reviews Supabase query construction for RLS policy alignment. Use whenever implementing or reviewing any code that touches sharing permissions, sync payloads, Partner-visible data, privacy flags, or Supabase query construction in Cadence. Triggers on any question about Tracker/Partner data boundaries, isPrivate semantics, share_* flag enforcement, Sex symptom handling, RLS alignment, or payload construction privacy in this codebase."
---

# Cadence Privacy Architecture

Authoritative governance for Cadence's privacy model, asymmetric sharing, and Supabase RLS alignment. The Tracker owns all data absolutely. The Partner is a constrained read-only participant. RLS is defense-in-depth — not the sole or primary privacy control.

---

## 1. Asymmetric Sharing Model

Cadence has a strict asymmetric design: the Tracker writes, the Partner reads — but only what the Tracker has explicitly permitted.

**Core invariants:**

- Privacy defaults to off. Every shared data type requires an explicit opt-in toggle.
- The Partner client is architecturally read-only. It never writes to Tracker tables.
- All Tracker data belongs to the Tracker. The Partner receives a curated, permission-filtered projection — never the full record set.
- Realtime events received by the Partner client pass through Supabase RLS before delivery. The Partner client must not assume Realtime bypasses policy.

**Sharing permission categories** (all default `false`, Tracker-controlled):

| Column                 | What Partner sees when enabled                   |
| ---------------------- | ------------------------------------------------ |
| `share_predictions`    | Period countdown, predicted next period          |
| `share_phase`          | Cycle phase label and plain-language description |
| `share_symptoms`       | Symptom chips (Sex always excluded)              |
| `share_mood`           | Mood change chip if logged                       |
| `share_fertile_window` | Fertile window countdown and status              |
| `share_notes`          | Today's notes text (if entry not private)        |

---

## 2. Privacy Precedence Hierarchy

Evaluate in this exact order before any data reaches the Partner:

```
1. is_private == true?          → Block entire day. No data. No exceptions.
2. is_paused == true?           → Block all Partner access. No data.
3. symptom_type == .sex?        → Block this symptom. Always. No exceptions.
4. share_<category> == false?   → Block this data category.
5. RLS policy evaluation        → Backend enforcement (defense-in-depth).
```

Rules 1–4 are client-enforced — they apply before any Supabase query is executed or payload is built. RLS enforces rule 5 at the server — it is not a substitute for rules 1–4.

Do not invert this order. Do not delegate rule 1, 2, or 3 entirely to the backend.

---

## 3. `isPrivate` — Master Override

`daily_logs.is_private = true` makes the entire day invisible to the Partner. It overrides every `share_*` flag and every category permission. If `is_private == true`, zero fields from that day's `daily_logs`, `symptom_logs`, or associated records should appear in any Partner-facing payload.

**Client enforcement — apply before payload construction:**

```swift
// CORRECT: check isPrivate before building any partner payload
func partnerVisibleLogs(from logs: [DailyLog]) -> [DailyLog] {
    logs.filter { !$0.isPrivate }
}

// WRONG: skip the local check and rely on RLS alone
func partnerVisibleLogs(from logs: [DailyLog]) -> [DailyLog] {
    logs  // assumes RLS will filter private entries — do not rely on this alone
}
```

**Supabase query — include the filter even though RLS also enforces it:**

```swift
// Always include is_private = false in Partner-perspective queries
supabase
    .from("daily_logs")
    .select("date, flow_level, notes")
    .eq("user_id", trackerUserId)
    .eq("is_private", false)   // explicit — do not omit
```

Including the filter client-side has two benefits: it signals intent to the reader, and it prevents inadvertent data exposure if RLS policy is ever misconfigured.

**Rules:**

- Every sync operation that constructs a Partner-visible payload must filter `isPrivate` first.
- No sync, mapping, DTO, or serialization step may include records where `is_private = true`.
- The Log Sheet "Keep this day private" toggle sets this flag. It is a master override: the copy says "Your partner won't see anything from this day, even if sharing is on." The code must honor exactly this behavior.

---

## 4. Sex Symptom — Absolute Exclusion

`symptom_type == .sex` is NEVER included in any Partner-facing payload. This exclusion is unconditional — no permission flag, no feature flag, and no `share_*` toggle can override it.

**Exclusion must be enforced at every layer:**

```swift
// 1. Client-side payload filter (always apply)
extension SymptomType {
    var isPartnerVisible: Bool {
        self != .sex
    }
}

func partnerVisibleSymptoms(from symptoms: [SymptomLog]) -> [SymptomLog] {
    symptoms.filter { $0.symptomType.isPartnerVisible }
}

// 2. Supabase query — always include the neq filter for partner queries
supabase
    .from("symptom_logs")
    .select("daily_log_id, symptom_type")
    .neq("symptom_type", "sex")   // explicit — always include this

// WRONG: query without the sex exclusion
supabase
    .from("symptom_logs")
    .select("daily_log_id, symptom_type")  // no neq — relies on RLS alone
```

**Rules:**

- Any function, DTO, mapper, or serializer that handles `symptom_logs` for Partner output must exclude `sex` explicitly before passing data downstream.
- Never construct a shared payload builder that handles both Tracker-local and Partner-visible symptom output without the exclusion filter in place.
- The exclusion must appear in the Swift filtering layer AND in the Supabase query. RLS enforces it server-side; the client must enforce it redundantly.
- The Sex chip lock icon in the Log Sheet is a UI representation of this invariant. The invariant lives in the data layer — not in the UI alone.

---

## 5. Partner-Facing Query Construction

Partner queries must request only the fields they need. Never use broad selection patterns for Partner-facing queries.

**Least-privilege query pattern:**

```swift
// CORRECT: select only permitted fields for the enabled category
supabase
    .from("daily_logs")
    .select("date, notes")          // only notes — share_notes is enabled
    .eq("user_id", trackerUserId)
    .eq("is_private", false)

// WRONG: over-selection exposes fields the Partner should not receive
supabase
    .from("daily_logs")
    .select("*")                    // RLS may filter rows but not columns
    .eq("user_id", trackerUserId)
```

**Column selection rules by share category:**

| Category enabled       | Query columns                                                                     |
| ---------------------- | --------------------------------------------------------------------------------- |
| `share_phase`          | Consult `prediction_snapshots` — do not expose `daily_logs` fields                |
| `share_predictions`    | `predicted_next_period`, `predicted_ovulation`, `confidence_level`, `cycles_used` |
| `share_symptoms`       | `daily_log_id`, `symptom_type` — always `.neq("symptom_type", "sex")`             |
| `share_mood`           | Filter `symptom_type == "mood_change"` — subset of symptoms query                 |
| `share_fertile_window` | `fertile_window_start`, `fertile_window_end`, `predicted_ovulation`               |
| `share_notes`          | `date`, `notes` — only when `notes IS NOT NULL`                                   |

**Rules:**

- Construct queries programmatically from enabled categories. Do not build one universal `select(*)` query and rely on client-side filtering to redact columns.
- Supabase RLS enforces row-level access (who can read which rows). It does not automatically restrict columns — column restriction must be in the `select()` call.
- If a `share_*` flag is `false`, do not include the corresponding fields in the query at all. The query shape itself should reflect the permission state.

---

## 6. RLS Policy Alignment

Cadence's RLS policy for Partner read access requires all of:

1. A `partner_connections` row where `tracker_id = data owner` AND `partner_id = auth.uid()`
2. `partner_connections.is_paused = false`
3. The relevant `share_*` flag is `true`
4. `daily_logs.is_private = false` (for daily log rows)
5. `symptom_type != 'sex'` (for symptom_logs rows)

**Write code that is safe without RLS, not code that requires RLS to be safe.**

An overbroad query that would expose private data but happens to be blocked by RLS is a latent vulnerability: any RLS misconfiguration, policy migration error, or SDK behavior difference could expose data. Defense-in-depth means the client layer is correct independently.

```swift
// Code review checklist for any Partner-facing Supabase query:
// [ ] Does the select() include only columns needed for this permission category?
// [ ] Does the query filter is_private = false?
// [ ] Does the query exclude sex symptom_type?
// [ ] Is is_paused checked before executing the query (local state)?
// [ ] Would this query expose private data if RLS were removed?
//     If yes → fix the query, don't rely on RLS to catch it.
```

---

## 7. Architectural Boundaries

Keep these responsibilities strictly separated:

| Concern                                            | Owner                                                   | Must not touch                                            |
| -------------------------------------------------- | ------------------------------------------------------- | --------------------------------------------------------- |
| Privacy flag evaluation (`isPrivate`, `is_paused`) | Local business logic / ViewModel                        | Supabase SDK directly                                     |
| Sex symptom filtering                              | Dedicated filter function / `isPartnerVisible` property | Any code that builds shared payloads without it           |
| Column projection (which fields Partner sees)      | Supabase query `.select()` construction                 | Over-selection or `select(*)` for Partner                 |
| Row-level access enforcement                       | Supabase RLS policies                                   | Client query logic (RLS is defense-in-depth, not primary) |
| Partner Realtime subscription                      | `SyncCoordinator` read path                             | Tracker write path                                        |
| Tracker writes                                     | `SyncCoordinator` write path                            | Partner client — never                                    |

**Privacy logic must not be scattered.** Centralise `isPrivate` checks in a dedicated function or ViewModel method. Centralise sex symptom exclusion in a typed filter on `SymptomType`. Do not inline privacy logic ad hoc inside UI components, serializers, or notification handlers.

---

## 8. Sync Payload Construction

When building any payload for Supabase sync or Realtime:

**Tracker → Supabase (write path):**

- Write all fields the Tracker has logged, including `is_private` flag.
- Write `sex` symptom to `symptom_logs` — it is stored locally and remotely for Tracker history. It is excluded only from Partner-visible queries, not from storage.
- The `syncStatus` field is local only — never include it in the Supabase payload.

**Partner ← Supabase (read path):**

- Filter `is_private = false` before processing.
- Exclude `sex` symptom_type.
- Project only columns corresponding to enabled `share_*` flags.
- Never write to Tracker tables from the Partner client.

```swift
// WRONG: shared DTO used for both Tracker and Partner paths
struct DailyLogDTO: Codable {
    let date: Date
    let flowLevel: FlowLevel?
    let notes: String?
    let symptoms: [SymptomType]   // includes .sex — unsafe for Partner path
    let isPrivate: Bool           // exposes privacy flag to Partner DTO
    let syncStatus: String        // syncStatus should never leave the client
}

// CORRECT: separate DTOs for each direction
struct TrackerWritePayload: Encodable { ... }       // all fields, no syncStatus
struct PartnerReadProjection: Decodable { ... }     // only permitted fields, no isPrivate, no sex
```

---

## 9. Anti-Pattern Table

| Anti-pattern                                                              | Verdict                                                |
| ------------------------------------------------------------------------- | ------------------------------------------------------ |
| Relying on RLS alone for `isPrivate` enforcement                          | Reject — client must filter first                      |
| Relying on RLS alone for Sex symptom exclusion                            | Reject — client must filter and query must exclude     |
| `select("*")` in any Partner-facing query                                 | Reject — column projection must match permission state |
| Sex symptom included in Partner payload                                   | Reject — unconditional exclusion                       |
| Partner client writing to `daily_logs`, `symptom_logs`, or `period_logs`  | Reject — read-only                                     |
| Shared DTO for Tracker write and Partner read paths                       | Reject — separate models per direction                 |
| `syncStatus` field included in Supabase payload                           | Reject — local-only field                              |
| Privacy logic inlined in SwiftUI view body                                | Reject — centralise in ViewModel or filter function    |
| Query without `is_private = false` filter for Partner context             | Reject                                                 |
| Query without `neq("symptom_type", "sex")` for Partner symptom query      | Reject                                                 |
| Querying a category's data when the corresponding `share_*` flag is false | Reject — don't fetch what isn't permitted              |

---

## 10. Privacy Review Checklist

Before shipping any code that touches Partner data exposure, sync payloads, or Supabase query construction:

**Asymmetric model**

- [ ] Partner client contains no write calls to Tracker data tables
- [ ] Tracker data never flows to Partner outside the explicit `share_*` permission model

**`isPrivate` enforcement**

- [ ] All Partner-facing data pipelines filter `isPrivate == true` entries before payload construction
- [ ] Supabase Partner queries include `.eq("is_private", false)`
- [ ] Log Sheet "Keep this day private" toggle sets `isPrivate` as a master override

**Sex symptom exclusion**

- [ ] `SymptomType.isPartnerVisible` (or equivalent) filters out `.sex` before any Partner payload is built
- [ ] All Partner symptom queries include `.neq("symptom_type", "sex")`
- [ ] No shared payload builder passes `.sex` to Partner output without the filter

**Query shape**

- [ ] Partner queries use explicit column projection matching the enabled `share_*` flags
- [ ] No `select("*")` on Partner-facing queries
- [ ] Query is safe against a hypothetical RLS removal — would it still not expose private data?

**Payload separation**

- [ ] Tracker write DTOs and Partner read projections are separate types
- [ ] `syncStatus` is not included in any Supabase payload
