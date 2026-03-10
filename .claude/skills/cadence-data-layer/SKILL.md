---
name: cadence-data-layer
description: "Owns the Cadence local prediction engine and SwiftData schema. Governs the rolling-average cycle algorithm computed from last 3-6 completed cycles in local SwiftData history. Defines exact confidence scoring thresholds (4+ cycles with SD of 2 days or less = high; 2-3 cycles or 4+ with SD above 2 days = medium; 0-1 cycles = low). Enforces offline-first — all writes go to SwiftData immediately, Supabase sync is always queued via SyncCoordinator. Prediction logic is strictly local and deterministic, never touches the network layer. Use when implementing or reviewing SwiftData models, prediction calculation, confidence scoring, offline write paths, sync queue behavior, or any data-layer architectural boundary in Cadence. Triggers on any question about SwiftData schema, cycle prediction, offline behavior, sync status, or local-first data flow in this codebase."
---

# Cadence Data Layer

Authoritative governance for Cadence's local data architecture, SwiftData schema, and prediction engine. All prediction logic is local, deterministic, and offline-capable. The network layer never participates in prediction and never blocks user-visible writes.

---

## 1. Architecture Overview

```
SwiftUI Views
    ↕ @Observable ViewModels (read from SwiftData)
SwiftData (local source of truth)
    ↕ SyncCoordinator (write queue + Realtime intake)
Supabase Swift SDK
    ↕ Supabase Postgres + RLS
```

**Ownership rules:**
- SwiftData is the iOS client's source of truth. All UI reads from SwiftData.
- Supabase is the authoritative remote store. It is not the source of truth for immediate UX state.
- The `PredictionEngine` reads only from SwiftData. It has zero dependency on Supabase, URLSession, or any network type.
- `SyncCoordinator` owns all Supabase I/O. It writes pending local records to Supabase and writes incoming Realtime events back to SwiftData.

---

## 2. SwiftData Schema

All models carry `syncStatus` for the offline write queue. Never omit it.

```swift
enum SyncStatus: String, Codable {
    case pending, synced, error
}
```

### Core Models

**CycleProfile** — one per Tracker user.

```swift
@Model class CycleProfile {
    var userId: UUID
    var averageCycleLength: Int    // default 28; recalculated from last 3–6 completed cycles
    var averagePeriodLength: Int   // default 5; recalculated from last 3–6 completed cycles
    var predictionsEnabled: Bool   // default true
    var updatedAt: Date
    var syncStatus: SyncStatus
}
```

**PeriodLog** — one row per logged period.

```swift
@Model class PeriodLog {
    var id: UUID
    var userId: UUID
    var startDate: Date
    var endDate: Date?             // nil until period ends; nil means open period
    var source: PeriodSource       // .manual or .predicted
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
}

enum PeriodSource: String, Codable { case manual, predicted }
```

**DailyLog** — one row per user per date. Unique on `(userId, date)`.

```swift
@Model class DailyLog {
    var id: UUID
    var userId: UUID
    var date: Date
    var flowLevel: FlowLevel?      // nil if not logged
    var sleepQualityPoor: Bool     // default false
    var notes: String?
    var isPrivate: Bool            // default false; master privacy override
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
}

enum FlowLevel: String, Codable { case spotting, light, medium, heavy }
```

**SymptomLog** — child of DailyLog.

```swift
@Model class SymptomLog {
    var id: UUID
    var dailyLogId: UUID
    var symptomType: SymptomType
    var createdAt: Date
    var syncStatus: SyncStatus
}

enum SymptomType: String, Codable {
    case cramps, headache, bloating, moodChange, fatigue,
         acne, discharge, exercise, poorSleep, sex
}
```

**PredictionSnapshot** — written by `PredictionEngine` after every period_log write.

```swift
@Model class PredictionSnapshot {
    var id: UUID
    var userId: UUID
    var dateGenerated: Date
    var predictedNextPeriod: Date
    var predictedOvulation: Date
    var fertileWindowStart: Date
    var fertileWindowEnd: Date
    var confidenceLevel: ConfidenceLevel
    var cyclesUsed: Int            // how many completed cycles fed into averages
    var syncStatus: SyncStatus
}

enum ConfidenceLevel: String, Codable { case high, medium, low }
```

**Schema rules:**
- Every model must have `syncStatus`. New and modified records start as `.pending`.
- Never store user-facing prediction results in a model that lacks `syncStatus` — snapshots must be queued like any other write.
- `sex` symptom is stored locally but excluded from all Partner-visible queries at the RLS layer. No local filtering needed — the exclusion is remote-only.
- At most one open `PeriodLog` (where `endDate == nil`) per user at a time. Enforce at write time.

---

## 3. Prediction Algorithm

The `PredictionEngine` is a pure Swift type. It takes completed `PeriodLog` records as input and produces a `PredictionSnapshot` as output. It has no initializer parameters that reference a network type, URLSession, or Supabase client.

### Inputs (from SwiftData history)

- `completedPeriods`: `[PeriodLog]` — only periods where `endDate != nil`, sorted by `startDate` descending.
- `lastPeriodStartDate`: `completedPeriods.first?.startDate`
- `averageCycleLength`: mean of the last 3–6 cycle lengths (start-to-start interval between consecutive periods)
- `averagePeriodLength`: mean of the last 3–6 period lengths (`endDate - startDate` in days)
- `standardDeviation`: SD of the cycle lengths used in the average

Use the most recent 3–6 completed periods. If fewer than 3 completed periods exist, use all available. If none exist, use defaults (cycle length 28, period length 5).

### Calculation Rules

```swift
// All arithmetic is calendar-day arithmetic (no time components)
predictedNextPeriod   = lastPeriodStartDate + averageCycleLength (days)
predictedOvulation    = predictedNextPeriod - 14 (days)
fertileWindowStart    = predictedOvulation - 5 (days)
fertileWindowEnd      = predictedOvulation
```

These are the exact formulas from the product spec. Do not modify them without a spec change.

### Confidence Scoring

Confidence is derived from `cyclesUsed` and `standardDeviation` of cycle lengths.

| Condition | Confidence |
|---|---|
| 0–1 completed cycles | Low |
| 2–3 completed cycles | Medium |
| 4+ completed cycles AND SD ≤ 2 days | High |
| 4+ completed cycles AND SD > 2 days | Medium |

```swift
func confidence(cyclesUsed: Int, standardDeviation: Double) -> ConfidenceLevel {
    switch cyclesUsed {
    case 0, 1:
        return .low
    case 2, 3:
        return .medium
    default:
        return standardDeviation <= 2.0 ? .high : .medium
    }
}
```

**SD threshold:** The 2-day SD boundary is defined in the product spec. Do not adjust it without a spec change. If SD cannot be computed (fewer than 2 data points), treat it as > 2.0 and score conservatively.

### Recalculation Trigger

Recalculate and write a new `PredictionSnapshot` to SwiftData after **every write to `PeriodLog`** — specifically on `endDate` write (period end triggers the most meaningful recalculation) and on `startDate` write (new period starts reset the open-period state).

`SyncCoordinator` calls the `PredictionEngine` synchronously on the write path, before flushing to Supabase. The snapshot is written to SwiftData and marked `.pending` immediately. It does not wait for the Supabase write to complete.

### Display Requirement

Every prediction surface must include this disclaimer, visible without scrolling:

> "Based on your logged history — not medical advice."

This is a product requirement, not an accessibility note. Enforce it in every view that renders predicted dates or the fertile window.

---

## 4. Offline-First Write Contract

**The rule:** Writes go to SwiftData first. Always. Supabase sync is always queued. User-visible state never waits on a network response.

### Write Path

```swift
// CORRECT: offline-first write
func logPeriodStart(date: Date) async {
    // 1. Write to SwiftData immediately (syncStatus = .pending)
    let log = PeriodLog(startDate: date, source: .manual, syncStatus: .pending)
    modelContext.insert(log)
    try? modelContext.save()

    // 2. Recalculate predictions from SwiftData history (local, synchronous)
    let snapshot = predictionEngine.recalculate(context: modelContext)
    modelContext.insert(snapshot)
    try? modelContext.save()

    // 3. Enqueue for Supabase sync (does NOT block the above)
    await syncCoordinator.enqueue(log)
    await syncCoordinator.enqueue(snapshot)
}

// WRONG: remote-first write
func logPeriodStart(date: Date) async {
    try await supabase.from("period_logs").insert(log)  // blocks on network
    modelContext.insert(log)  // UI updates only after network round-trip
}
```

### Sync Status Lifecycle

```
Insert/update → syncStatus = .pending
SyncCoordinator flushes → Supabase write succeeds → syncStatus = .synced
SyncCoordinator flushes → Supabase write fails (3 retries) → syncStatus = .error
```

- `NWPathMonitor` signals network availability → `SyncCoordinator` flushes `.pending` queue in order.
- Conflict resolution: last-write-wins on `updatedAt`. Multi-device conflict resolution is post-beta.
- On `.error`: a non-blocking indicator appears on the affected UI element. Do not block the user from continued logging.

### Read Path

- UI reads from SwiftData via `@Observable` ViewModels.
- Realtime events arrive → `SyncCoordinator` writes them to SwiftData → ViewModel updates → UI refreshes.
- Partner dashboard reads Partner-visible Tracker data from a separate read-only SwiftData store populated by Realtime events. The Partner client never writes to this store.

---

## 5. Network Isolation for Prediction

The `PredictionEngine` must have zero coupling to the network layer.

**Enforced constraints:**

```swift
// CORRECT: PredictionEngine has no network dependencies
struct PredictionEngine {
    func recalculate(context: ModelContext) -> PredictionSnapshot { ... }
}

// WRONG: prediction depends on network
struct PredictionEngine {
    let supabaseClient: SupabaseClient  // REJECT — no network dependency in prediction
    func recalculate() async throws -> PredictionSnapshot {
        let history = try await supabaseClient.from("period_logs").select()  // REJECT
        ...
    }
}
```

**Rules:**
- `PredictionEngine` takes a `ModelContext` or a plain array of `PeriodLog` — never a network client.
- Prediction computation must be synchronous. If it must be async (e.g., large dataset), use a background Swift actor or `Task.detached` — never an `async throws` path that can fail due to network.
- `PredictionEngine` must never `import` network-related modules or reference any type from the Supabase SDK.
- The snapshot written by `PredictionEngine` is immediately readable from SwiftData. Its `syncStatus` starts as `.pending` — the snapshot will sync to Supabase when connectivity allows, but the local value is already authoritative.

---

## 6. Architectural Boundaries

Keep these concerns strictly separated:

| Concern | Owner | May not touch |
|---|---|---|
| SwiftData schema and local reads/writes | `ModelContext` / `@Model` types | Supabase SDK, URLSession |
| Prediction calculation | `PredictionEngine` | Supabase SDK, URLSession, ModelContext writes |
| Supabase I/O and Realtime | `SyncCoordinator` | Prediction logic, business rules |
| User-facing state | `@Observable` ViewModels | Direct Supabase calls |
| Partner data (read-only) | Separate read-only `ModelContext` | Never written to by Partner client |

`SyncCoordinator` is the single gateway between SwiftData and Supabase. No other type should hold a Supabase client reference or make direct Supabase calls.

---

## 7. Anti-Pattern Table

| Anti-pattern | Verdict |
|---|---|
| `PredictionEngine` calling Supabase or URLSession | Reject — prediction is local-only |
| `PredictionEngine` marked `async throws` due to network | Reject — network failure must not affect prediction |
| UI write blocked on Supabase confirmation | Reject — offline-first |
| `syncStatus` field missing from a writable model | Reject — every model needs it |
| More than one open `PeriodLog` (nil endDate) per user | Reject — enforce at write time |
| Confidence scoring deviating from spec thresholds | Reject — thresholds are product spec |
| SD threshold other than 2.0 days without spec change | Reject |
| Prediction using remote history instead of local SwiftData | Reject |
| `SyncCoordinator` embedding prediction logic | Reject — sync is transport only |
| Prediction recalculation skipped after `PeriodLog` write | Reject — must recalculate on every period write |
| Partner ModelContext allowing writes | Reject — read-only |
| Disclaimer "Based on your logged history..." omitted from prediction surface | Reject — product requirement |

---

## 8. Enforcement Checklist

Before marking any data-layer component complete:

**Schema**
- [ ] All `@Model` types have `syncStatus: SyncStatus` (default `.pending` on create)
- [ ] `PeriodLog.endDate` is optional (`Date?`)
- [ ] At most one open `PeriodLog` per user enforced at write time
- [ ] Partner data uses a separate read-only `ModelContext`

**Prediction Engine**
- [ ] `PredictionEngine` has no import of Supabase SDK or URLSession
- [ ] Inputs are local SwiftData records only (ModelContext or [PeriodLog])
- [ ] Algorithm matches spec exactly: next period = last start + avg cycle, ovulation = next period - 14, fertile start = ovulation - 5, fertile end = ovulation
- [ ] Averages computed from last 3–6 completed periods
- [ ] Confidence: 0–1 cycles → low; 2–3 → medium; 4+ SD ≤ 2.0 → high; 4+ SD > 2.0 → medium
- [ ] Recalculation triggered on every `PeriodLog` write
- [ ] New snapshot written to SwiftData before Supabase enqueue

**Offline-First**
- [ ] Every write goes to SwiftData first with `syncStatus = .pending`
- [ ] No `try await supabaseClient` call on the UI write path
- [ ] `SyncCoordinator` is the sole Supabase gateway
- [ ] `.error` state shows non-blocking indicator — does not block further logging

**Prediction Surfaces**
- [ ] Disclaimer "Based on your logged history — not medical advice." visible without scrolling on every prediction surface
