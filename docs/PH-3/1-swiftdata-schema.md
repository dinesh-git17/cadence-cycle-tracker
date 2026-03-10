# SwiftData Schema

**Epic ID:** PH-3-E1
**Phase:** 3 -- Core Data Layer & Prediction Engine
**Estimated Size:** M
**Status:** Draft

---

## Objective

Define all five local SwiftData `@Model` types (CycleProfile, PeriodLog, DailyLog, SymptomLog, PredictionSnapshot), their supporting enums, and the `SyncStatus` infrastructure that governs the offline write queue lifecycle. Register the `CadenceTests` unit test target in `project.yml`. Establish the in-memory `ModelContainer` factory used by all test cases and Xcode previews.

## Problem / Context

Every subsequent phase reads from SwiftData. Phase 4 (navigation shell + logging), Phase 5 (Home Dashboard), Phase 6 (Calendar), and Phase 7 (sync) all operate against this schema. If the schema is wrong -- missing fields, wrong optionality, missing `syncStatus`, duplicate open periods -- every downstream phase inherits the defect. Defining the schema in isolation, before any UI, allows the model layer to be unit-tested and verified before any UI surface depends on it.

Source authority: cadence-data-layer skill §2 (SwiftData Schema) is the primary reference. MVP PRD v1.0 Data Model defines the full column set including `goal_mode` on `cycle_profiles`, which the cadence-data-layer skill omits. Per CLAUDE.md §2, the MVP PRD (source #4) has higher authority than the skill (source #7) -- `goalMode` must be included on `CycleProfile`.

## Scope

### In Scope

- `SyncStatus` enum (`.pending`, `.synced`, `.error`) -- shared across all models
- `CycleProfile` @Model: `userId`, `averageCycleLength`, `averagePeriodLength`, `goalMode`, `predictionsEnabled`, `updatedAt`, `syncStatus`
- `GoalMode` enum (`.trackCycle`, `.tryingToConceive`) with `RawRepresentable` String backing for Supabase serialization
- `PeriodLog` @Model: `id`, `userId`, `startDate`, `endDate` (optional), `source`, `createdAt`, `updatedAt`, `syncStatus`
- `PeriodSource` enum (`.manual`, `.predicted`)
- `DailyLog` @Model: `id`, `userId`, `date`, `flowLevel` (optional), `sleepQualityPoor`, `notes` (optional), `isPrivate`, `createdAt`, `updatedAt`, `syncStatus`
- `FlowLevel` enum (`.spotting`, `.light`, `.medium`, `.heavy`)
- `SymptomLog` @Model: `id`, `dailyLogId`, `symptomType`, `createdAt`, `syncStatus`
- `SymptomType` enum (`.cramps`, `.headache`, `.bloating`, `.moodChange`, `.fatigue`, `.acne`, `.discharge`, `.exercise`, `.poorSleep`, `.sex`)
- `PredictionSnapshot` @Model: `id`, `userId`, `dateGenerated`, `predictedNextPeriod`, `predictedOvulation`, `fertileWindowStart`, `fertileWindowEnd`, `confidenceLevel`, `cyclesUsed`, `syncStatus`
- `ConfidenceLevel` enum (`.high`, `.medium`, `.low`)
- Open-period enforcement predicate: a static function that checks for an existing open `PeriodLog` (where `endDate == nil`) for a given `userId` before permitting a new open period write
- DailyLog uniqueness enforcement predicate: a static function that checks for an existing `DailyLog` for a given `(userId, date)` pair before permitting a new write
- `ModelContainerFactory.swift` -- `makeProductionContainer()` and `makeTestContainer()` functions
- `CadenceTests` unit test target registered in `project.yml`
- All new Swift source files registered in `project.yml` under `Cadence/Models/` source group

### Out of Scope

- Actual write operations for any model (writing belongs to ViewModels in Phase 4/5, or the PredictionEngine write path in PH-3-E2)
- Migrations for existing Supabase schema (Phase 1 deliverable, already complete)
- Partner-specific read-only model store (Phase 8/9 concern)
- SwiftData `@Relationship` macros between models (SymptomLog and DailyLog are linked via `dailyLogId` UUID, not a SwiftData relationship, to keep the sync layer simple)
- `@Query` usage in views (Phase 4/5)

## Dependencies

| Dependency                                                                                                                                 | Type | Phase/Epic | Status   | Risk |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ---- | ---------- | -------- | ---- |
| Buildable XcodeGen project with `Cadence/` source groups                                                                                   | FS   | PH-0       | Resolved | Low  |
| Phase 2 writes `cycle_profiles` row with `goal_mode` field -- confirms the GoalMode enum values `track`/`conceive` match the Postgres enum | FS   | PH-2-E4    | Open     | Low  |

## Assumptions

- `SymptomLog` does not use a SwiftData `@Relationship` to `DailyLog`. It stores `dailyLogId: UUID` as a plain UUID. This avoids cascade-delete complexity and keeps the sync layer's `PendingWrite` cases simple. The association is enforced by convention and by the DailyLog uniqueness check.
- `DailyLog.sleepQualityPoor: Bool` maps to the MVP Spec's `sleep_quality: Int (1-5)`. The binary `Bool` is a simplification: `false` = sleep quality not flagged, `true` = flagged poor. If the spec is revised to use the full 1-5 scale, update this field. For the MVP, the boolean is sufficient and avoids range validation complexity.
- `GoalMode` raw values are `"track"` and `"conceive"` (matching the Postgres enum from MVP PRD data model). These match what Phase 2 (PH-2-E4) writes to Supabase.
- `PeriodLog.endDate` is `Date?` (optional). A nil `endDate` means the period is currently in progress (open). This is an invariant, not a bug state.
- All `@Model` types default `syncStatus` to `.pending` on initialization. A record inserted into SwiftData is immediately considered pending sync.
- The `GoalMode` field is included on `CycleProfile` per the MVP PRD data model. The cadence-data-layer skill's `CycleProfile` definition omits it -- this is a gap in the skill. The MVP PRD (higher authority per CLAUDE.md §2) governs.

## Risks

| Risk                                                                                                         | Likelihood | Impact | Mitigation                                                                                        |
| ------------------------------------------------------------------------------------------------------------ | ---------- | ------ | ------------------------------------------------------------------------------------------------- |
| SwiftData `@Model` compiler errors on iOS 26 for a specific field type (e.g., optional enum stored property) | Low        | Medium | Test all 5 model definitions in a preview or unit test container before declaring the schema done |
| `GoalMode` raw values ("track"/"conceive") not matching the Phase 1 Postgres enum values                     | Low        | High   | Confirm against Phase 1 migration SQL before writing any tests that assert Codable serialization  |
| `SymptomType.sex` raw value -- must serialize to a string that does not change between versions              | Low        | Medium | Lock the raw value to `"sex"` explicitly; do not rely on Swift enum synthesis                     |

---

## Stories

### S1: SyncStatus enum and shared model enums

**Story ID:** PH-3-E1-S1
**Points:** 3

Define `SyncStatus` and all supporting enums used across models. Each enum conforms to `String, Codable` so it serializes correctly via SwiftData and Supabase. Register a new `Cadence/Models/` source group in `project.yml` with all files from this epic.

**Acceptance Criteria:**

- [ ] `Cadence/Models/SyncStatus.swift` exists with `enum SyncStatus: String, Codable { case pending, synced, error }`
- [ ] `Cadence/Models/GoalMode.swift` exists with `enum GoalMode: String, Codable { case trackCycle = "track"; case tryingToConceive = "conceive" }` -- raw values match Postgres enum strings exactly
- [ ] `Cadence/Models/PeriodSource.swift` exists with `enum PeriodSource: String, Codable { case manual, predicted }`
- [ ] `Cadence/Models/FlowLevel.swift` exists with `enum FlowLevel: String, Codable { case spotting, light, medium, heavy }`
- [ ] `Cadence/Models/SymptomType.swift` exists with all 10 cases: `cramps, headache, bloating, moodChange, fatigue, acne, discharge, exercise, poorSleep, sex` -- all with explicit raw String values matching Supabase enum strings
- [ ] `Cadence/Models/ConfidenceLevel.swift` exists with `enum ConfidenceLevel: String, Codable { case high, medium, low }`
- [ ] `project.yml` includes a `Cadence/Models/` source group containing all model Swift files for this epic
- [ ] Build succeeds without warnings after `xcodegen generate`

**Dependencies:** None
**Notes:** `SymptomType.sex` raw value must be `"sex"` explicitly -- do not use Swift's synthesized string (`"sex"` is already the enum case name, but explicit is safer). `moodChange` should serialize as `"mood_change"` to match the Supabase `mood` category -- verify the Postgres enum string before finalizing.

---

### S2: CycleProfile @Model

**Story ID:** PH-3-E1-S2
**Points:** 3

Define the `CycleProfile` SwiftData model with all fields from the MVP PRD data model. This is the one-per-Tracker row that seeds prediction input.

**Acceptance Criteria:**

- [ ] `Cadence/Models/CycleProfile.swift` exists with `@Model final class CycleProfile`
- [ ] Fields: `userId: UUID`, `averageCycleLength: Int` (default 28), `averagePeriodLength: Int` (default 5), `goalMode: GoalMode`, `predictionsEnabled: Bool` (default `true`), `updatedAt: Date`, `syncStatus: SyncStatus` (default `.pending`)
- [ ] `CycleProfile` has a memberwise initializer that sets all fields explicitly; defaults are applied at the call site in PH-2-E4, not inside the model
- [ ] `CycleProfile` conforms to no protocols beyond `@Model` -- no manual `Codable` conformance needed (SwiftData handles persistence)
- [ ] A `CycleProfile` instance can be inserted into an in-memory `ModelContainer` and retrieved without errors
- [ ] `project.yml` updated with `CycleProfile.swift`

**Dependencies:** PH-3-E1-S1 (GoalMode and SyncStatus enums)
**Notes:** Do not add `@Attribute(.unique)` on `userId` at the SwiftData level -- uniqueness is enforced at write time via an upsert in PH-2-E4, not at the model layer.

---

### S3: PeriodLog @Model and open-period enforcement

**Story ID:** PH-3-E1-S3
**Points:** 3

Define `PeriodLog` and the static enforcement predicate that ensures at most one open period (nil `endDate`) exists per user at any time.

**Acceptance Criteria:**

- [ ] `Cadence/Models/PeriodLog.swift` exists with `@Model final class PeriodLog`
- [ ] Fields: `id: UUID`, `userId: UUID`, `startDate: Date`, `endDate: Date?` (optional, nil = open period), `source: PeriodSource`, `createdAt: Date`, `updatedAt: Date`, `syncStatus: SyncStatus`
- [ ] `PeriodLog` contains a `static func openPeriodPredicate(userId: UUID) -> Predicate<PeriodLog>` that returns a predicate matching records where `userId == userId AND endDate == nil`
- [ ] A calling site using `FetchDescriptor<PeriodLog>(predicate: openPeriodPredicate(userId:))` in an in-memory container correctly finds 0 records when no open period exists and 1 record when one exists
- [ ] The predicate does not throw a compilation error on iOS 26 (verify `#Predicate` syntax compiles)
- [ ] `project.yml` updated with `PeriodLog.swift`

**Dependencies:** PH-3-E1-S1
**Notes:** The enforcement predicate is a data accessor, not the enforcement itself. Calling code (write path in PH-3-E2 and Phase 4 ViewModels) checks the predicate result before inserting a new open period. The predicate on `Date?` (optional property) must use `endDate == nil` which is valid in `#Predicate` on Swift 5.9+ (iOS 17+). Verify behavior on iOS 26.

---

### S4: DailyLog @Model and uniqueness enforcement

**Story ID:** PH-3-E1-S4
**Points:** 3

Define `DailyLog` and the static predicate that enforces the `(userId, date)` uniqueness constraint.

**Acceptance Criteria:**

- [ ] `Cadence/Models/DailyLog.swift` exists with `@Model final class DailyLog`
- [ ] Fields: `id: UUID`, `userId: UUID`, `date: Date`, `flowLevel: FlowLevel?` (optional), `sleepQualityPoor: Bool` (default `false`), `notes: String?` (optional), `isPrivate: Bool` (default `false`), `createdAt: Date`, `updatedAt: Date`, `syncStatus: SyncStatus`
- [ ] `DailyLog` contains a `static func existingLogPredicate(userId: UUID, date: Date) -> Predicate<DailyLog>` that matches records for a given user on a given calendar day
- [ ] The predicate uses calendar-day matching: normalize both `date` values to midnight using `Calendar.current.startOfDay(for:)` before comparison -- two timestamps on the same calendar day must match
- [ ] A `FetchDescriptor<DailyLog>(predicate: existingLogPredicate(userId:date:))` correctly finds 0 records for a date with no log and 1 record for a date that has one
- [ ] `project.yml` updated with `DailyLog.swift`

**Dependencies:** PH-3-E1-S1
**Notes:** The `date` field stores the day only (no time component) -- normalize on write by storing `Calendar.current.startOfDay(for: inputDate)`. This prevents duplicate logs from timestamps that differ only in time-of-day.

---

### S5: SymptomLog @Model

**Story ID:** PH-3-E1-S5
**Points:** 2

Define `SymptomLog` -- the child-of-DailyLog model. Uses `dailyLogId: UUID` (not a SwiftData `@Relationship`) as the foreign key.

**Acceptance Criteria:**

- [ ] `Cadence/Models/SymptomLog.swift` exists with `@Model final class SymptomLog`
- [ ] Fields: `id: UUID`, `dailyLogId: UUID`, `symptomType: SymptomType`, `createdAt: Date`, `syncStatus: SyncStatus`
- [ ] No `@Relationship` macro is used -- the parent link is a plain `UUID`
- [ ] A `FetchDescriptor<SymptomLog>(predicate: #Predicate { $0.dailyLogId == targetId })` correctly retrieves all symptoms for a given DailyLog ID from an in-memory container
- [ ] `project.yml` updated with `SymptomLog.swift`

**Dependencies:** PH-3-E1-S1
**Notes:** The absence of `@Relationship` is intentional (see Assumptions). Do not add cascade-delete behavior.

---

### S6: PredictionSnapshot @Model and ModelContainer factory

**Story ID:** PH-3-E1-S6
**Points:** 2

Define `PredictionSnapshot` and the two `ModelContainer` factory functions used throughout the project: one for production (on-disk persistent store) and one for in-memory test use.

**Acceptance Criteria:**

- [ ] `Cadence/Models/PredictionSnapshot.swift` exists with `@Model final class PredictionSnapshot`
- [ ] Fields: `id: UUID`, `userId: UUID`, `dateGenerated: Date`, `predictedNextPeriod: Date`, `predictedOvulation: Date`, `fertileWindowStart: Date`, `fertileWindowEnd: Date`, `confidenceLevel: ConfidenceLevel`, `cyclesUsed: Int`, `syncStatus: SyncStatus`
- [ ] `Cadence/Models/ModelContainerFactory.swift` exists with two functions:
  - `func makeProductionContainer() throws -> ModelContainer` -- creates a persistent on-disk container with all 5 model types registered
  - `func makeTestContainer() throws -> ModelContainer` -- creates an in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) with all 5 model types registered
- [ ] Both factory functions register all 5 model types: `CycleProfile.self, PeriodLog.self, DailyLog.self, SymptomLog.self, PredictionSnapshot.self`
- [ ] `makeTestContainer()` is used in PH-3-E3 unit tests and matches the pattern from cadence-testing skill §2 exactly
- [ ] `CadenceTests` unit test target is declared in `project.yml` under `targets` with `type: bundle.unit-test`, scheme `CadenceTests`, and `CadenceTests/` as the source directory
- [ ] `project.yml` updated with `PredictionSnapshot.swift` and `ModelContainerFactory.swift`
- [ ] Build compiles without warnings; `xcodegen generate` succeeds

**Dependencies:** PH-3-E1-S1, PH-3-E1-S2, PH-3-E1-S3, PH-3-E1-S4, PH-3-E1-S5
**Notes:** `makeProductionContainer()` is called from the `@main` App struct. `makeTestContainer()` is called from test `setUp` methods. The `--in-memory-store` launch argument (for UI tests) will call `makeTestContainer()` -- the branch logic lives in the App struct (wired in Phase 4). Phase 3 only defines the factory.

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
- [ ] All 5 @Model types can be inserted and retrieved from an in-memory ModelContainer without errors
- [ ] Open-period and DailyLog uniqueness predicates verified in isolation via manual test or unit test before PH-3-E3 tests are written
- [ ] Phase objective is advanced: the SwiftData schema is complete, correct, and ready for PredictionEngine and SyncCoordinator to depend on
- [ ] Applicable skill constraints satisfied: `cadence-data-layer` (all 5 models, syncStatus on every model, GoalMode per MVP PRD, no @Relationship on SymptomLog), `cadence-xcode-project` (project.yml updated with Models group and CadenceTests target), `swiftui-production` (no force unwraps in model definitions, no global mutable state)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No hardcoded values -- all enum raw strings match Supabase column/enum values exactly
- [ ] Source document alignment verified: all fields match MVP PRD Data Model section; GoalMode inclusion confirmed against MVP PRD §cycle_profiles

## Source References

- cadence-data-layer skill §2 (SwiftData Schema -- all 5 model definitions, SyncStatus, anti-pattern table)
- MVP PRD v1.0 Data Model (full column set including `goal_mode` on `cycle_profiles`, `is_private` on `daily_logs`)
- cadence-testing skill §2 (in-memory ModelContainer factory, test target architecture)
- cadence-xcode-project skill (project.yml source group conventions, test target registration)
- PHASES.md: Phase 3 -- Core Data Layer & Prediction Engine (In-Scope item 1)
