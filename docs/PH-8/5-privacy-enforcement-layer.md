# Privacy Enforcement Layer

**Epic ID:** PH-8-E5
**Phase:** 8 -- Partner Connection & Privacy Architecture
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement the full client-side privacy enforcement stack as defined in the cadence-privacy-architecture skill: `SymptomType.isPartnerVisible` for unconditional Sex exclusion, `PartnerDataFilter` for `isPrivate` and `is_paused` client-side guards, `PartnerQueryBuilder` for column-projected Supabase query construction per active `share_*` flags, and separate `TrackerWritePayload`/`PartnerReadProjection` DTOs. Unit tests verify all five levels of the privacy precedence hierarchy against the live business logic. This epic establishes the data access patterns that Phase 9 (Partner Dashboard) will consume -- getting it wrong here means Phase 9 is built on an incorrect foundation.

## Problem / Context

Supabase RLS enforces row-level access. It does not restrict columns. A Partner query that uses `select("*")` on `daily_logs` will receive every column in the row -- including `is_private`, `flow_level`, `notes`, `mood`, and `sleep_quality` -- for any row the RLS policy permits. RLS controls _whether_ the Partner can see a row, not _which fields_ arrive in the response payload. Column restriction is the client's responsibility.

The cadence-privacy-architecture skill §6 states this explicitly: "Write code that is safe without RLS, not code that requires RLS to be safe." A query that would expose private data but happens to be blocked by RLS is a latent vulnerability -- any RLS migration error, Supabase SDK behavior change, or policy misconfiguration becomes a privacy incident. The client layer must be independently correct.

The cadence-privacy-architecture skill §2 defines the five-rule precedence hierarchy:

```
1. is_private == true?         -- Block entire day. No data. No exceptions.
2. is_paused == true?          -- Block all Partner access. No data.
3. symptom_type == .sex?       -- Block this symptom. Always.
4. share_<category> == false?  -- Block this data category.
5. RLS policy evaluation       -- Backend enforcement (defense-in-depth).
```

Rules 1-4 are client-enforced. Phase 8 E5 implements rules 1-4. Without this epic, Phase 9 cannot build the Partner Dashboard against a correct data access layer -- the queries would default to over-selection and RLS would be the sole protection, which is a rejected pattern in this codebase.

This epic also establishes the DTO separation boundary: `TrackerWritePayload` for the write path (all Tracker-logged fields, no `syncStatus`) and `PartnerReadProjection` for the read path (only permitted fields, no `is_private` field, no `sex` symptom type, no `syncStatus`). Shared DTOs for both paths are explicitly rejected by the anti-pattern table in skill §9.

**Source references that define scope:**

- cadence-privacy-architecture skill §2 (privacy precedence hierarchy -- all five rules)
- cadence-privacy-architecture skill §3 (`isPrivate` master override -- client filter before payload construction)
- cadence-privacy-architecture skill §4 (Sex symptom absolute exclusion -- `isPartnerVisible`, Supabase `neq` filter, dual-layer enforcement)
- cadence-privacy-architecture skill §5 (Partner-facing query construction -- column projection table per share category)
- cadence-privacy-architecture skill §8 (sync payload construction -- separate DTOs per direction)
- cadence-privacy-architecture skill §9 (anti-pattern table -- rejected patterns this epic must avoid)
- MVP Spec §2 (RLS Policy Summary -- four conditions required for Partner read access)
- PHASES.md Phase 8 in-scope: "privacy architecture enforcement: isPrivate evaluated before any RLS condition, Sex symptom type excluded from all sync payloads regardless of share_symptoms flag, Partner-facing query column projection enforced (no over-exposure of Tracker fields)"

## Scope

### In Scope

- `SymptomType` extension in `Cadence/Models/SymptomType.swift`: `var isPartnerVisible: Bool { self != .sex }`; no other logic in this property; sex exclusion is the sole purpose
- `Cadence/Services/PartnerDataFilter.swift`: struct or enum namespace with three static functions:
  - `partnerVisibleLogs(from logs: [DailyLog]) -> [DailyLog]`: filters `!log.isPrivate`
  - `partnerVisibleSymptoms(from symptoms: [SymptomLog]) -> [SymptomLog]`: filters `symptom.symptomType.isPartnerVisible`
  - `isPausedGuard(isPaused: Bool) -> Bool`: returns `!isPaused` (true = Partner can receive data; false = block)
  - All three functions are pure (no side effects, no async, no Supabase dependency) -- testable in isolation
- `Cadence/Services/PartnerQueryBuilder.swift`: builds Supabase `.select()` column strings and required filter conditions from a `PartnerConnectionPermissions` input (a snapshot of active `share_*` flags); produces query configurations for each table:
  - `daily_logs`: always includes `.eq("is_private", false)` filter; columns projected per enabled categories (see cadence-privacy-architecture skill §5 column selection table)
  - `symptom_logs`: always includes `.neq("symptom_type", "sex")` filter; columns: `daily_log_id`, `symptom_type`; only queried when `share_symptoms == true` or `share_mood == true`
  - `prediction_snapshots`: columns per enabled categories (`predicted_next_period`, `confidence_level` for `share_predictions`; phase data from `prediction_snapshots` for `share_phase`; etc.)
  - Never produces a `select("*")` configuration for any Partner-facing query
  - Returns a `PartnerQueryConfiguration` value type with `.selectColumns: String`, `.filters: [(column: String, value: AnyHashable)]`
- `Cadence/Models/DTOs/TrackerWritePayload.swift`: `Encodable` struct for Tracker-to-Supabase writes; fields: `date`, `flowLevel`, `mood`, `sleepQuality`, `notes`, `isPrivate` (all Tracker-logged fields from `daily_logs`); does NOT include `syncStatus`, `id`, or `userId` (those are set by the server or the auth context); separate `TrackerSymptomWritePayload: Encodable` for `symptom_logs` writes: `dailyLogId`, `symptomType` (all types including `.sex` -- sex is stored for Tracker history; excluded only from Partner read path)
- `Cadence/Models/DTOs/PartnerReadProjection.swift`: `Decodable` struct for Partner-from-Supabase reads from `daily_logs`; fields: `date`, `notes` (only if `share_notes` enabled), `flowLevel` (only if `share_predictions` or similar context); does NOT include `isPrivate`, `sleepQuality`, `mood` (mood comes from symptom logs, not this DTO); `PartnerSymptomProjection: Decodable` for `symptom_logs` reads: `dailyLogId`, `symptomType` -- `symptomType` is typed as `PartnerVisibleSymptomType` (a subset enum that is initialized from raw value and returns `nil` for `"sex"`, preventing it from appearing in decoded results even if the server sends it inadvertently)
- `PartnerVisibleSymptomType` enum in `Cadence/Models/DTOs/PartnerReadProjection.swift`: all `SymptomType` cases except `.sex`; `init?(rawValue: String)` returns `nil` for `"sex"` explicitly
- Privacy enforcement integration into `PartnerConnectionStore`: `PartnerConnectionStore.partnerVisibleData(for date: Date) -> PartnerVisibleDayData?` method applies all four client-side rules in precedence order before returning data; returns `nil` if `is_paused`, if the day `is_private`, or if all enabled categories produce empty results
- `CadenceTests/Privacy/PartnerDataFilterTests.swift`: unit tests covering:
  - `isPrivate` master override: a `DailyLog` with `isPrivate = true` produces zero entries from `partnerVisibleLogs`
  - `is_paused` guard: `isPausedGuard(isPaused: true)` returns false
  - Sex symptom exclusion: an array containing `SymptomLog(.sex)` produces zero entries from `partnerVisibleSymptoms`
  - Mixed array exclusion: `[.cramps, .sex, .fatigue]` through `partnerVisibleSymptoms` returns `[.cramps, .fatigue]` only
  - Column projection: `PartnerQueryBuilder` configured with `share_notes = true, share_phase = false` produces a `selectColumns` string containing "notes" but not phase-related columns
  - Over-selection guard: `PartnerQueryBuilder` never produces `select("*")` for any permission configuration
  - `PartnerVisibleSymptomType` nil-init: `PartnerVisibleSymptomType(rawValue: "sex")` returns `nil`
- `project.yml` updated with entries for `PartnerDataFilter.swift`, `PartnerQueryBuilder.swift`, `TrackerWritePayload.swift`, `PartnerReadProjection.swift`, `PartnerDataFilterTests.swift` under appropriate source and test groups; `xcodegen generate` exits 0

### Out of Scope

- `SyncCoordinator` Partner read path -- Phase 9 (this epic establishes the filter functions, query builder, and DTOs; the actual Supabase fetch call from the Partner Dashboard ViewModel is Phase 9's responsibility to assemble using these primitives)
- `is_private` SwiftData write path -- Phase 3/4 (the `DailyLog.isPrivate` property exists; this epic enforces the flag in the Partner-facing query path, not the write path)
- `is_paused` Supabase RLS policy -- Phase 1 (established; this epic enforces `is_paused` on the client independently as defense-in-depth)
- `syncStatus` handling in the write queue -- Phase 7 (`SyncCoordinator` manages `syncStatus`; this epic produces `TrackerWritePayload` which explicitly excludes it)
- Per-category notification payload construction -- Phase 10

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| `PartnerConnectionStore` with `activePermissions: PartnerPermissions` | SS | PH-8-E3 | Open | Medium -- `PartnerQueryBuilder` must be calibrated against real `share_*` flag definitions from E3; can be built in parallel but integration requires E3 to be complete |
| `SymptomType` enum exists in the codebase with a `.sex` case | FS | PH-4 | Open | Low -- Phase 4 defines all symptom types |
| `DailyLog` SwiftData model with `isPrivate: Bool` property | FS | PH-3 | Open | Low -- Phase 3 defines the data model |
| Live partner connection for integration test validation | FS | PH-8-E2 | Open | Low -- unit tests use mocks; end-to-end validation requires a live connection |

## Assumptions

- `SymptomType` is an enum defined in Phase 4 with a `.sex` case. The `isPartnerVisible` extension adds a computed property to the existing type -- it does not define a new type or replace the existing enum.
- `PartnerQueryBuilder` produces query configurations but does not execute Supabase calls. Execution is the responsibility of the Phase 9 ViewModel that consumes the builder output. This separation makes the builder unit-testable without a Supabase client.
- Unit tests run against mock/stub data with no live network dependency (cadence-testing skill: "no real network calls in tests; mock or stub external services").
- `PartnerVisibleSymptomType` is a separate enum, not a subset protocol on `SymptomType`. The separation makes it impossible to accidentally pass a `[SymptomType]` (which could contain `.sex`) to a function expecting `[PartnerVisibleSymptomType]` without an explicit conversion step.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `PartnerQueryBuilder` column projection table becomes stale if `partner_connections` schema changes | Low | High -- incorrect column selection exposes wrong data or produces query errors | Tie `PartnerQueryBuilder` column selection to `PermissionCategory.columnName` (E3 enum); if a category is added or renamed, the enum is the single source of truth |
| E5 primitives are built before E3 finalizes `PartnerPermissions` shape | Medium | Low -- minor interface mismatch | E5 can use a local `PartnerConnectionPermissions` snapshot struct for building and testing; adapt to E3's `PartnerPermissions` type in the integration story (S5) |
| `PartnerVisibleSymptomType` nil-init: server sends unexpected `symptom_type` values | Low | Low -- unknown types are silently dropped by `init?(rawValue:)` | This is the correct behavior; unknown symptom types from the server should not crash the client |

---

## Stories

### S1: SymptomType.isPartnerVisible + PartnerDataFilter

**Story ID:** PH-8-E5-S1
**Points:** 3

Add `isPartnerVisible: Bool` to `SymptomType` and implement the `PartnerDataFilter` struct with three pure static filter functions. Write unit tests for all filter functions.

**Acceptance Criteria:**

- [ ] `SymptomType.isPartnerVisible` returns `false` for `.sex` and `true` for all other cases
- [ ] Adding a new case to `SymptomType` without updating `isPartnerVisible` produces a compiler warning (exhaustive switch or explicit default) -- the property must use an explicit switch, not a simple `self != .sex` comparison, to ensure future symptom additions are consciously evaluated
- [ ] `PartnerDataFilter.partnerVisibleLogs(from:)` returns only logs where `isPrivate == false`; an empty input returns an empty output
- [ ] `PartnerDataFilter.partnerVisibleSymptoms(from:)` returns only symptom logs where `symptomType.isPartnerVisible == true`
- [ ] `PartnerDataFilter.isPausedGuard(isPaused:)` returns `false` when `isPaused == true` and `true` when `isPaused == false`
- [ ] Unit test: `partnerVisibleLogs([privateLog, publicLog])` returns `[publicLog]` only
- [ ] Unit test: `partnerVisibleSymptoms([SymptomLog(.sex), SymptomLog(.cramps)])` returns `[SymptomLog(.cramps)]` only
- [ ] Unit test: `partnerVisibleSymptoms([SymptomLog(.sex)])` returns `[]`
- [ ] All three functions have no `async`, no `throws`, no Supabase dependency
- [ ] `scripts/protocol-zero.sh` exits 0 on all new files

**Dependencies:** PH-4 (SymptomType enum must exist with .sex case), PH-3 (DailyLog model must have isPrivate property)
**Notes:** The switch on `isPartnerVisible` must list every case explicitly. A future `.cervicalMucus` case added to `SymptomType` without updating this switch must produce a compiler error or warning -- not silently return true or false.

---

### S2: PartnerQueryBuilder with Column-Projected Query Construction

**Story ID:** PH-8-E5-S2
**Points:** 5

Implement `PartnerQueryBuilder` that produces a `PartnerQueryConfiguration` value type from a `PartnerConnectionPermissions` snapshot. Covers `daily_logs`, `symptom_logs`, and `prediction_snapshots` queries. Never produces `select("*")`.

**Acceptance Criteria:**

- [ ] `PartnerQueryConfiguration` value type has: `table: String`, `selectColumns: String`, `filters: [(column: String, operator: QueryOperator, value: AnyHashable)]`
- [ ] `PartnerQueryBuilder.dailyLogsQuery(permissions:)` always includes `.eq("is_private", false)` in filters; column selection matches cadence-privacy-architecture skill §5 exactly per enabled flags
- [ ] `PartnerQueryBuilder.symptomLogsQuery(permissions:)` always includes `.neq("symptom_type", "sex")` in filters; returns `nil` when both `share_symptoms == false` and `share_mood == false` (no point querying)
- [ ] `PartnerQueryBuilder.predictionsQuery(permissions:)` returns `nil` when both `share_predictions == false` and `share_phase == false` and `share_fertile_window == false`
- [ ] No query configuration produced by `PartnerQueryBuilder` contains `"*"` in the `selectColumns` string -- verified by unit test
- [ ] Unit test: `PartnerConnectionPermissions` with all permissions false produces `symptomLogsQuery == nil` and `predictionsQuery == nil` and `dailyLogsQuery` with only `date` column (minimum viable projection for date-only display)
- [ ] Unit test: `share_notes = true` produces `dailyLogsQuery` `selectColumns` containing "notes"
- [ ] Unit test: `share_notes = false` produces `dailyLogsQuery` `selectColumns` NOT containing "notes"
- [ ] Unit test: `share_symptoms = true` produces `symptomLogsQuery` with `neq("symptom_type", "sex")` filter present

**Dependencies:** PH-8-E5-S1 (SymptomType.isPartnerVisible conceptually informs the neq filter constant)
**Notes:** `PartnerQueryBuilder` does not execute Supabase calls -- it only builds query configurations. The consuming ViewModel (Phase 9) calls `supabase.from(config.table).select(config.selectColumns)` and applies `config.filters`. This separation is what makes the builder unit-testable without a live Supabase client.

---

### S3: TrackerWritePayload + PartnerReadProjection Separate DTOs

**Story ID:** PH-8-E5-S3
**Points:** 3

Define `TrackerWritePayload` and `TrackerSymptomWritePayload` (Encodable, write path) and `PartnerReadProjection`, `PartnerSymptomProjection`, `PartnerVisibleSymptomType` (Decodable, read path). No shared DTO is permitted.

**Acceptance Criteria:**

- [ ] `TrackerWritePayload: Encodable` has fields: `date: Date`, `flowLevel: FlowLevel?`, `mood: String?`, `sleepQuality: Int?`, `notes: String?`, `isPrivate: Bool`; does NOT include `id`, `userId`, `syncStatus`, `createdAt`
- [ ] `TrackerSymptomWritePayload: Encodable` has fields: `dailyLogId: UUID`, `symptomType: SymptomType`; all `SymptomType` cases are encodable (including `.sex`, which is stored for Tracker history)
- [ ] `PartnerReadProjection: Decodable` does NOT include `isPrivate`, `sleepQuality`, `syncStatus` fields
- [ ] `PartnerSymptomProjection: Decodable` has `dailyLogId: UUID`, `symptomType: PartnerVisibleSymptomType` where `PartnerVisibleSymptomType` is a subset enum excluding `.sex`
- [ ] `PartnerVisibleSymptomType` `init?(rawValue: String)` returns `nil` for `"sex"` explicitly; does not produce a runtime crash for unknown values -- they decode to `nil` and are filtered out
- [ ] Compiler error if a function parameter typed `[PartnerReadProjection]` is passed a `[TrackerWritePayload]` -- confirmed by the type separation (no shared protocol)
- [ ] Unit test: decoding JSON `{"symptom_type": "sex"}` into `PartnerSymptomProjection` produces `nil` for `symptomType` (or decoding failure handled gracefully)
- [ ] Unit test: encoding `TrackerSymptomWritePayload(symptomType: .sex)` produces valid JSON (sex is stored, not excluded from Tracker writes)

**Dependencies:** PH-3 (DailyLog schema defines the fields), PH-4 (SymptomType enum)
**Notes:** `PartnerVisibleSymptomType` is defined in `PartnerReadProjection.swift` -- it is a DTO-layer type, not a domain type. The domain type `SymptomType` remains the source of truth for the Tracker's data model.

---

### S4: Privacy Enforcement Unit Tests

**Story ID:** PH-8-E5-S4
**Points:** 5

Write the full unit test suite in `CadenceTests/Privacy/PartnerDataFilterTests.swift` covering all five rules of the privacy precedence hierarchy and the anti-patterns from cadence-privacy-architecture skill §9.

**Acceptance Criteria:**

- [ ] Test file exists at `CadenceTests/Privacy/PartnerDataFilterTests.swift`
- [ ] Test: `isPrivate` master override -- a `DailyLog` with `isPrivate = true` containing a non-empty symptoms array produces zero items from the full `partnerVisibleData(for:)` pipeline (both log and symptoms blocked)
- [ ] Test: `is_paused` guard -- `isPausedGuard(isPaused: true)` returns `false`; a `PartnerConnectionStore` with `activePermissions.isPaused = true` calling `partnerVisibleData(for:)` returns `nil`
- [ ] Test: Sex symptom exclusion -- `partnerVisibleSymptoms` on `[.sex, .cramps, .sex, .fatigue]` returns exactly `[.cramps, .fatigue]`
- [ ] Test: column over-selection guard -- `PartnerQueryBuilder` with any valid permission configuration never produces `"*"` in any query's `selectColumns` string (tested across all 64 possible `share_*` boolean combinations -- use `XCTestCase.continueAfterFailure = false` with a parameterized loop)
- [ ] Test: PartnerVisibleSymptomType decoding -- raw value "sex" decodes to `nil`; raw value "cramps" decodes to `.cramps`
- [ ] Test: `share_notes = false` -- `PartnerQueryBuilder.dailyLogsQuery` does not include "notes" in `selectColumns`
- [ ] Test: `share_notes = true, share_phase = false` -- "notes" present, phase columns absent
- [ ] Test: no live Supabase calls in any test -- all tests use value types or mock-injected stores
- [ ] All tests named per `test_<unit>_<scenario>_<expected>` convention (cadence-testing skill)

**Dependencies:** PH-8-E5-S1, PH-8-E5-S2, PH-8-E5-S3
**Notes:** The 64-combination column over-selection guard test is the most important. It verifies that no accidentally broad configuration can slip through. Use `(0..<64).forEach { mask in ... }` iterating over bit positions for the 6 `share_*` flags. This test is O(64) and runs in under 1ms -- it is not excessive.

---

### S5: PartnerDataFilter + PartnerQueryBuilder Integration into PartnerConnectionStore

**Story ID:** PH-8-E5-S5
**Points:** 3

Integrate `PartnerDataFilter` and `PartnerQueryBuilder` into `PartnerConnectionStore` via a `partnerVisibleData(for date: Date) -> PartnerVisibleDayData?` method that applies all four client-side privacy rules in precedence order. Replace any E3-era temporary permission snapshots with the canonical `PartnerPermissions` type from E3.

**Acceptance Criteria:**

- [ ] `PartnerConnectionStore.partnerVisibleData(for date: Date) -> PartnerVisibleDayData?` exists and applies rules in this exact order: (1) `isPausedGuard` returns false -> `nil`; (2) `partnerVisibleLogs` filters out private day -> `nil`; (3) `partnerVisibleSymptoms` applied to symptom results; (4) `PartnerQueryBuilder` used to construct any Supabase queries for Partner-visible data
- [ ] `PartnerVisibleDayData` is a value type (struct) containing only the fields the Partner is permitted to see based on current `activePermissions`
- [ ] If `PartnerQueryBuilder` used a temporary `PartnerConnectionPermissions` snapshot struct in S2, it is replaced with `PartnerPermissions` from E3 (no two types representing the same concept)
- [ ] The method returns `nil` rather than an empty `PartnerVisibleDayData` when the day is fully blocked (paused or private) -- callers can test `nil` without inspecting internal fields
- [ ] Unit test: `partnerVisibleData` with `isPaused = true` returns `nil` regardless of `isPrivate` state
- [ ] Unit test: `partnerVisibleData` with `isPaused = false, isPrivate = true` returns `nil`
- [ ] Unit test: `partnerVisibleData` with `isPaused = false, isPrivate = false, share_symptoms = true` returns non-nil with symptoms array not containing `.sex`

**Dependencies:** PH-8-E5-S1, PH-8-E5-S2, PH-8-E5-S3, PH-8-E3-S1
**Notes:** Phase 9 will call `PartnerConnectionStore.partnerVisibleData(for:)` to populate the Partner Dashboard. This is the contract surface that Phase 9 depends on. The return type `PartnerVisibleDayData` must be stable before Phase 9 begins.

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
- [ ] Integration verified: `partnerVisibleData(for:)` called against a live Supabase-connected store with `is_private = true` entries confirms zero data returned to Partner path
- [ ] Integration verified: `partnerVisibleData(for:)` with `share_symptoms = true` confirms `.sex` symptom never appears in results, regardless of what was logged
- [ ] Privacy review checklist from cadence-privacy-architecture skill §10 passes completely for all new files
- [ ] Phase objective is advanced: the privacy enforcement layer is in place as a stable contract surface for Phase 9 to consume
- [ ] Applicable skill constraints satisfied: cadence-privacy-architecture (all five rules implemented, anti-pattern table respected), cadence-testing (unit tests, DI, no live Supabase, named per convention), swiftui-production (no force unwraps), cadence-data-layer (offline-first data access)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] All privacy unit tests pass (minimum 9 test functions per S4 acceptance criteria)
- [ ] No `select("*")` string present anywhere in `PartnerQueryBuilder.swift` (verified by grep)
- [ ] No shared DTO type used for both Tracker write and Partner read paths (verified by code review)
- [ ] `syncStatus` string not present in `TrackerWritePayload` or `PartnerReadProjection` (verified by grep)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified against cadence-privacy-architecture skill §9 anti-pattern table -- all rejected patterns are absent

## Source References

- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (in-scope: privacy architecture enforcement layer)
- cadence-privacy-architecture skill §2 (privacy precedence hierarchy)
- cadence-privacy-architecture skill §3 (isPrivate master override)
- cadence-privacy-architecture skill §4 (Sex symptom absolute exclusion)
- cadence-privacy-architecture skill §5 (Partner-facing query construction, column selection table)
- cadence-privacy-architecture skill §6 (RLS alignment -- write code safe without RLS)
- cadence-privacy-architecture skill §8 (sync payload construction -- separate DTOs)
- cadence-privacy-architecture skill §9 (anti-pattern table)
- MVP Spec §2 (RLS Policy Summary -- four conditions for Partner read access)
- cadence-testing skill (unit test contract, DI on @Observable stores, no live Supabase)
