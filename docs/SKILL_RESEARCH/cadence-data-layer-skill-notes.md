# cadence-data-layer Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-data-layer/SKILL.md`
**Package output:** `.claude/skills/skill-creator/cadence-data-layer.skill`

---

## Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill creation process and conventions |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — §5 Tech Stack, §6 Data Model, §7 Feature Specs (predictions), §12 Offline and Sync Architecture |
| `docs/Cadence_Design_Spec_v1.1.md` | Design system v1.1 — context for prediction display surfaces |

---

## Skill-Creator Location Used

`/Users/Dinesh/Desktop/cadence-cycle-tracker/.claude/skills/skill-creator/`

Scripts used:
- `quick_validate.py` — first run failed (unquoted colon in YAML description); fixed by quoting the description string; second run passed.
- `package_skill.py` — produced `cadence-data-layer.skill`

---

## Sources Used

### Claude Code Skill Standards
- Local `skill-creator` SKILL.md and `references/schemas.md` — authoritative for this project's conventions.

### Apple Official Sources
- **Apple Developer Documentation: SwiftData** — `@Model` macro, `ModelContext`, query and persistence patterns. iOS 17+; fully available on iOS 26.
- **WWDC23 Session 10187: "Meet SwiftData"** — model definition with `@Model`, container setup, context insert/save lifecycle.
- **WWDC23 Session 10189: "Model your schema with SwiftData"** — schema organization, relationships, optional properties.
- **Apple Developer Documentation: Network framework (`NWPathMonitor`)** — network path observation for triggering sync flushes on reconnect.
- **WWDC21 Session 10133: "Qualities of a great Mac app"** (offline-first principles applicable to iOS) — local-first architecture, deferred sync, local state as source of truth.
- **Apple Developer Documentation: Swift Concurrency** — `Task.detached` for background computation; actor isolation for data safety.

### Architectural Guidance
- **Offline-first pattern** (widely adopted, Apple-endorsed via SwiftData and local-first APIs): writes to local store immediately, sync deferred. This pattern is directly mandated in the PRD §12.
- **Deterministic local computation**: prediction engine as a pure function over local data — no network dependency, no `async throws` that can fail due to connectivity.

---

## Cadence-Specific Data-Layer Facts Extracted from Docs

### Prediction Algorithm (PRD §7.2)
| Prediction | Formula |
|---|---|
| Next period start | Last period start + average cycle length |
| Ovulation | Predicted next period start − 14 days |
| Fertile window start | Ovulation − 5 days |
| Fertile window end | Ovulation day |
| Average source | Mean of last 3–6 completed cycle/period lengths |

### Confidence Levels (PRD §7.2)
| Condition | Level |
|---|---|
| 4+ completed cycles, SD ≤ 2 days | High |
| 2–3 completed cycles | Medium |
| 4+ completed cycles, SD > 2 days | Medium |
| 0–1 completed cycles | Low |

### Offline / Sync (PRD §12)
- SwiftData = iOS source of truth; Supabase = authoritative remote
- syncStatus per model: `pending | synced | error`
- SyncCoordinator: ordered write queue, NWPathMonitor triggers flush
- Conflict resolution: last-write-wins on `updated_at` (multi-device: post-beta)
- Error: 3 retries → `syncStatus = .error` → non-blocking UI indicator
- Partner data: separate read-only ModelContext populated by Realtime; Partner never writes

### Recalculation Trigger (PRD §7.2)
- SyncCoordinator calls PredictionEngine after every write to `period_logs`
- New snapshot written to SwiftData and queued for Supabase sync immediately

### Display Requirement (PRD §7.2)
- Every prediction surface must show: "Based on your logged history — not medical advice." — visible without scrolling

### Schema (PRD §6)
- CycleProfile: averageCycleLength (default 28), averagePeriodLength (default 5)
- PeriodLog: startDate, endDate (nullable), source (manual/predicted)
- DailyLog: one per user per date, unique constraint
- SymptomLog: child of DailyLog; `sex` excluded from Partner queries at RLS layer (not local)
- PredictionSnapshot: predicted dates, confidence_level enum, cycles_used

---

## Ambiguities and Resolutions

### 1. "Last 3–6 cycles" — exact count
**Ambiguity:** The PRD says averages are computed from "last 3–6 completed cycles." It does not specify whether the implementation picks exactly 3, exactly 6, or a sliding window.
**Resolution:** Skill specifies: use the most recent completed periods up to a maximum of 6. If fewer than 3 exist, use all available (which may be 1 or 2). This is the most conservative and defensible reading.

### 2. "Low variance" definition
**Ambiguity:** The PRD defines High confidence as "4+ completed cycles, SD ≤ 2 days." The term "low variance" in the task brief requires interpretation.
**Resolution:** Mapped directly to the PRD threshold: SD ≤ 2.0 days = low variance = High confidence. The 2.0 day boundary is doc-grounded. Documented explicitly in the skill.

### 3. SD computation with fewer than 2 data points
**Ambiguity:** Standard deviation is undefined with fewer than 2 data points (you need at least 2 to compute SD).
**Resolution:** If SD cannot be computed (0 or 1 data points), treat SD as > 2.0 and score conservatively. This is consistent with the confidence table (0–1 cycles → Low regardless of SD).

### 4. `goal_mode` removed from beta
**Fact:** The PRD explicitly notes `goal_mode` (track/conceive) was removed from beta scope. The skill does not reference it and does not include it in the schema.

### 5. YAML colon in description
**Issue:** Initial frontmatter contained unquoted colons (e.g., "offline-first: all writes") causing YAML parse failure.
**Resolution:** Wrapped description in double quotes and replaced internal colon-space patterns with em-dash equivalents.

---

## Key Enforcement Rules Encoded

1. `PredictionEngine` has zero network imports or dependencies
2. Prediction inputs are local SwiftData records only
3. Algorithm formulas are exact per spec — no deviation without spec change
4. Averages from last 3–6 completed periods (use all if fewer than 3)
5. Confidence thresholds: 0–1 → low; 2–3 → medium; 4+ SD ≤ 2.0 → high; 4+ SD > 2.0 → medium
6. All models carry `syncStatus: SyncStatus`, default `.pending`
7. Write path: SwiftData first → PredictionEngine → enqueue for Supabase — all before any await on Supabase
8. SyncCoordinator is the sole Supabase gateway — no other type holds a Supabase client
9. Partner data uses a separate read-only ModelContext — Partner client never writes
10. Disclaimer "Based on your logged history — not medical advice." required on every prediction surface
