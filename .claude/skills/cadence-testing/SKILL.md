---
name: cadence-testing
description: "Defines the testing contract for Cadence. Unit tests cover the prediction algorithm edge cases, SwiftData model layer, and privacy override logic. UI tests cover the Log Sheet entry flow, chip toggle state, and the isPrivate master override. Enforces dependency injection on all @Observable stores for testability without a live Supabase connection. Target: 80%+ coverage on data and domain layers before TestFlight. Use this skill whenever writing, reviewing, or planning any tests for Cadence — including unit tests, UI tests, testability decisions, DI architecture, mock/fake design, SwiftData test isolation, or coverage gate enforcement. Triggers on any question about test targets, test coverage, mock Supabase, in-memory SwiftData, testing @Observable ViewModels, prediction algorithm tests, privacy logic tests, chip toggle UI tests, Log Sheet UI tests, isPrivate behavioral tests, or pre-TestFlight quality gates in this codebase."
---

# Cadence Testing

Authoritative governance for Cadence's testing strategy and quality gates. This skill owns the required test coverage areas, testability architecture expectations, and pre-TestFlight readiness criteria. Consult this skill before writing any test and before reviewing any test-adjacent code change.

---

## 1. Test Target Architecture

When the Xcode project is initialized via XcodeGen (`project.yml`), define two test targets:

| Target | Type | Scheme |
|---|---|---|
| `CadenceTests` | XCTest unit/integration | `CadenceTests` |
| `CadenceUITests` | XCUITest | `CadenceUITests` |

Both targets are registered in `project.yml` — never edit `.pbxproj` directly. See the `cadence-xcode-project` skill for target registration rules.

**Coverage tooling:** Enable "Gather coverage" in the `CadenceTests` scheme, scoped to the `Cadence` target only. When CI is added, use a `.xctestplan` file for portability — do not block test writing on it.

**File layout convention:**

```
CadenceTests/
  Domain/
    PredictionEngineTests.swift
    PrivacyFilterTests.swift
  Models/
    SwiftDataModelTests.swift
  Fakes/
    FakeSyncCoordinator.swift

CadenceUITests/
  LogSheetUITests.swift
  ChipToggleUITests.swift
  PrivacyOverrideUITests.swift
```

Tests mirror the app's source group structure. Unit tests live adjacent to the layer they exercise.

---

## 2. Dependency Injection — @Observable Stores

Every `@Observable` store that owns external dependencies must accept those dependencies via its initializer as protocol-typed values. No `@Observable` store may hold a concrete `SupabaseClient` or concrete `SyncCoordinator` as a stored property.

```swift
// CORRECT: protocol-typed, init-injected
protocol SyncCoordinatorProtocol: Actor {
    func enqueue(_ write: PendingWrite) async
    var isOnline: Bool { get }
}

@Observable class TrackerViewModel {
    private let sync: any SyncCoordinatorProtocol
    private let modelContext: ModelContext

    init(sync: any SyncCoordinatorProtocol, modelContext: ModelContext) {
        self.sync = sync
        self.modelContext = modelContext
    }
}

// WRONG: hardwired live dependency — untestable
@Observable class TrackerViewModel {
    private let sync = SyncCoordinator(supabase: SupabaseClient.shared) // REJECT
}
```

**Fake implementations for tests** live in `CadenceTests/Fakes/` and must not import any Supabase SDK type:

```swift
// FakeSyncCoordinator.swift
// No import of Supabase SDK permitted in this file.
actor FakeSyncCoordinator: SyncCoordinatorProtocol {
    private(set) var enqueuedWrites: [PendingWrite] = []
    var isOnline: Bool = true

    func enqueue(_ write: PendingWrite) async {
        enqueuedWrites.append(write)
    }
}
```

**`PredictionEngine`** requires no DI — it is a pure function struct. Pass `[PeriodLog]` directly in tests.

**SwiftData isolation** — create a fresh in-memory `ModelContainer` per test case:

```swift
func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: CycleProfile.self, PeriodLog.self, DailyLog.self,
             SymptomLog.self, PredictionSnapshot.self,
        configurations: config
    )
}
```

Never share a `ModelContainer` across test cases. Shared containers produce order-dependent failures.

---

## 3. Unit Test Contract — PredictionEngine

`PredictionEngine` is a pure Swift type with zero network dependency. All tests run synchronously and require no mocks.

**All 10 edge cases below must have a dedicated test:**

| Case | Input | Expected |
|---|---|---|
| Zero cycles | `[]` empty period log array | Defaults: cycle=28, period=5. Confidence=`.low`. `cyclesUsed=0`. |
| One completed cycle | Single PeriodLog (start+end) | Uses that cycle's length for avg. Confidence=`.low`. |
| Two completed cycles | Two PeriodLogs | Average of 2 lengths. Confidence=`.medium`. |
| Three completed cycles | Three PeriodLogs | Average of 3 lengths. Confidence=`.medium`. |
| Four cycles, SD ≤ 2.0 days | Four consistent PeriodLogs | Confidence=`.high`. |
| Four cycles, SD > 2.0 days | Four variable PeriodLogs | Confidence=`.medium`. |
| SD = 2.0 exactly | Boundary case | Confidence=`.high` (≤ 2.0 is inclusive). |
| Open period excluded | One open PeriodLog (endDate nil) | Not counted as completed cycle. |
| More than 6 cycles | 8 completed PeriodLogs | Uses only the most recent 6. |
| Algorithm spot-check | Last start Jan 1, avg cycle 28 | nextPeriod=Jan 29, ovulation=Jan 15, fertileStart=Jan 10, fertileEnd=Jan 15. |

**Test naming:** `test_predictionEngine_<scenario>_<expectedOutcome>()`
Example: `test_predictionEngine_fourCyclesSDUnder2Days_confidenceHigh()`

**Date arithmetic in fixtures:** Use a fixed anchor date (e.g., `Date(timeIntervalSinceReferenceDate: 0)`) and `Calendar.current.date(byAdding:)`. Never use `Date()` — it is non-deterministic across CI environments and time zones.

```swift
// CORRECT: deterministic fixture
let anchor = Date(timeIntervalSinceReferenceDate: 0)  // Jan 1, 2001 UTC
let period1Start = Calendar.current.date(byAdding: .day, value: -56, to: anchor)!
let period1End   = Calendar.current.date(byAdding: .day, value: -51, to: anchor)!
```

---

## 4. Unit Test Contract — SwiftData Model Layer

Use an in-memory `ModelContainer` (§2) for all SwiftData model tests.

**Required coverage areas:**

**syncStatus lifecycle:**
- Insert any model → assert `syncStatus == .pending`
- Simulate flush success → assert `syncStatus == .synced`
- Simulate flush failure (3 retries exhausted) → assert `syncStatus == .error`

**Open period enforcement (at most one open PeriodLog per user):**
- Insert a `PeriodLog` with `endDate == nil` → verify it is stored as the open period
- Insert a second `PeriodLog` with `endDate == nil` → verify the write-time check rejects it
- Insert a `PeriodLog` with both `startDate` and `endDate` set → verify it counts as a completed cycle

**DailyLog uniqueness:**
- Insert two `DailyLog` records with the same `(userId, date)` → verify the constraint is enforced

**Prediction recalculation trigger:**
- After writing a `PeriodLog` (via the write path), verify a new `PredictionSnapshot` exists in the ModelContext

**SymptomLog association:**
- Insert a `SymptomLog` referencing a `DailyLog.id` → verify the association is retrievable

---

## 5. Unit Test Contract — Privacy Override Logic

Privacy logic is contract-critical. Missing tests in this area are a release blocker.

**isPrivate master override — required tests:**

```swift
func test_privacyFilter_isPrivateTrue_blocksEntireDay() {
    let log = DailyLog(isPrivate: true, ...)
    let visible = partnerVisibleLogs(from: [log])
    #expect(visible.isEmpty)
}

func test_privacyFilter_isPrivateFalse_entryVisible() {
    let log = DailyLog(isPrivate: false, ...)
    let visible = partnerVisibleLogs(from: [log])
    #expect(visible.count == 1)
}

func test_privacyFilter_mixedBatch_onlyPrivateExcluded() {
    let logs = [DailyLog(isPrivate: true, ...), DailyLog(isPrivate: false, ...)]
    let visible = partnerVisibleLogs(from: logs)
    #expect(visible.count == 1)
    #expect(!visible[0].isPrivate)
}
```

**Sex symptom exclusion — required tests:**

```swift
func test_symptomFilter_sexSymptom_alwaysExcluded() {
    let symptoms: [SymptomLog] = [.sex, .cramps, .headache].map { SymptomLog($0) }
    let visible = partnerVisibleSymptoms(from: symptoms)
    #expect(!visible.map(\.symptomType).contains(.sex))
    #expect(visible.count == 2)
}

// Verify sex is excluded even when share_symptoms flag is true
func test_symptomFilter_shareSymptomsFlagTrue_sexStillExcluded() { ... }
```

**Precedence hierarchy — required tests:**

Test each rule independently — when only that rule fires and all others pass:

| Rule | Test scenario |
|---|---|
| Rule 1: `isPrivate == true` | All `share_*` flags are `true`, entry is private → zero partner data |
| Rule 2: `is_paused == true` | Connection is paused, `isPrivate == false` → zero partner data |
| Rule 3: `sex` symptom | `share_symptoms == true`, log is not private → `.sex` still excluded |
| Rule 4: `share_<category> == false` | That category's data absent from payload |

**Log Sheet isPrivate behavioral test:**
Verify that writing `DailyLog.isPrivate = true` to the ModelContext and reading it back produces `isPrivate == true`. The Log Sheet "Keep this day private" toggle is the primary write path for this field — its effect must be provable in isolation from the UI.

---

## 6. UI Test Contract — Log Sheet Entry Flow

UI tests verify the complete entry flow in a running simulator. All UI tests use an in-memory store via launch arguments.

```swift
override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--in-memory-store"]
    app.launch()
}
```

Handle `--in-memory-store` in the app entry point before `ModelContainer` is configured:

```swift
@main struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            let container = ProcessInfo.processInfo.arguments.contains("--in-memory-store")
                ? (try? makeTestContainer())
                : (try? makeProductionContainer())
            ContentView().modelContainer(container!)
        }
    }
}
```

**Required test cases:**

| Test | Steps | Assertion |
|---|---|---|
| Sheet presents from center tab | Tap center Log tab | Sheet visible; date header present |
| Period started | Tap "Period started" | Button reflects active state |
| Symptom chip toggle | Tap one chip | Chip reflects active state (selected) |
| Chip toggle off | Tap same chip again | Chip returns to unselected state |
| Notes input | Tap textarea, type text | Field contains typed text |
| isPrivate toggle | Tap "Keep this day private" | Toggle is on |
| Save dismisses | Fill minimum fields, tap Save | Sheet dismisses |

**Element lookup:** All Log Sheet interactive elements must have stable `accessibilityIdentifier` values set in the SwiftUI view. Never locate elements by display text — localized strings and design copy changes break tests.

```swift
// In SwiftUI view
Toggle("Keep this day private", isOn: $isPrivate)
    .accessibilityIdentifier("log_sheet_private_toggle")

// In UI test
app.switches["log_sheet_private_toggle"].tap()

// Sheet container
let sheet = app.otherElements["log_sheet_container"]
XCTAssertTrue(sheet.waitForExistence(timeout: 2.0))
```

---

## 7. UI Test Contract — Chip Toggle State

**Required test cases:**

| Test | Assertion |
|---|---|
| Default state | All chips unselected on Log Sheet open |
| Toggle on | Chip accessibility value or label reflects "selected" |
| Toggle off | Chip reverts to unselected |
| No loading indicator | State change visible immediately — no spinner or loading indicator present |
| Sex chip lock icon | Lock icon present on Sex chip regardless of selection state |

The chip toggle must not display a loading indicator at any point. If any activity indicator is visible after a chip tap, the test must fail — chip state is optimistic and instant by contract.

---

## 8. UI Test Contract — isPrivate Master Override

| Test | Steps | Assertion |
|---|---|---|
| Toggle present | Open Log Sheet | "Keep this day private" element exists |
| Toggle persists | Toggle on, close, reopen same date | Toggle remains on |
| Partner view excludes private day | Log private entry; open Partner Dashboard | No data for that day visible |

The third test requires the UI test environment to support role switching or a simulated Partner Dashboard state. If full role switching is not feasible in `CadenceUITests`, cover the exclusion behavior with a unit test on the filter function (§5) and assert the result. Do not leave this behavior entirely untested.

---

## 9. No Live Supabase in Tests

No test in `CadenceTests` or `CadenceUITests` may require a live Supabase connection. This is an absolute rule.

**Why:** Live Supabase connections produce flaky tests, CI credential failures, non-deterministic test state, and risk mutating production or staging data.

**How each layer is isolated:**

| Layer | Isolation mechanism |
|---|---|
| ViewModels | `FakeSyncCoordinator` injected at init |
| PredictionEngine | Takes `[PeriodLog]` — no network surface |
| SwiftData models | `ModelConfiguration(isStoredInMemoryOnly: true)` |
| UI tests | `--in-memory-store` launch arg; Supabase client not initialized |

When `--in-memory-store` is present, the `SupabaseClient` must not be initialized. Do not construct it conditionally and then skip calls — do not construct it at all.

---

## 10. Coverage Gate — 80%+ Before TestFlight

Data and domain layers must reach 80%+ line coverage before the first TestFlight build ships. This is a release gate, not a metric.

| Layer | Coverage target |
|---|---|
| `PredictionEngine.swift` | 90%+ (pure logic — no acceptable gaps) |
| Privacy filter logic | 90%+ |
| SwiftData models (all 5) | 80%+ |
| `@Observable` ViewModels | 75%+ |
| UI flows (Log Sheet, chips, isPrivate) | Covered by `CadenceUITests` |

**Excluded from the 80% gate:** SwiftUI `body` properties, `CadenceApp.swift` entry point, generated code.

Verify per-file coverage — an 80% aggregate that masks 0% on `PredictionEngine.swift` is a gate failure. Use Xcode's scheme coverage report or `xccov` to inspect file-level breakdown:

```bash
xcrun xccov view --report --json \
  $(ls ~/Library/Developer/Xcode/DerivedData/*/Logs/Test/*.xcresult | tail -1)
```

---

## 11. Anti-Pattern Table

| Anti-pattern | Verdict |
|---|---|
| Test calls `supabase.from(...).execute()` or any `SupabaseClient` method | Reject — no live network in tests |
| `@Observable` ViewModel init without protocol-typed `SyncCoordinator` | Reject — blocks unit testability |
| `ModelContainer` shared across test cases | Reject — order-dependent failures |
| `ModelContainer` backed by on-disk storage in tests | Reject — use `isStoredInMemoryOnly: true` |
| `PredictionEngine` test using `Date()` instead of a fixed anchor | Reject — non-deterministic across time zones |
| Privacy test missing the `isPrivate == true` case | Reject — contract-critical, release blocker |
| Sex symptom exclusion not tested independently of share flags | Reject — unconditional exclusion must have its own test |
| UI test locating elements by display text | Reject — use `accessibilityIdentifier` |
| UI test not using `--in-memory-store` launch argument | Reject — may read or corrupt persisted state |
| Chip toggle test that passes when a loading indicator is visible | Reject — toggle must be instant and optimistic |
| Coverage gate bypassed by excluding data/domain files from scope | Reject — all files in §10 must be included |
| `FakeSyncCoordinator` importing any Supabase SDK type | Reject — fake must have zero real network surface |
| Privacy precedence rules tested only in combination, not in isolation | Reject — each rule must be provable independently |

---

## 12. Enforcement Checklist

Before marking any test-adjacent PR complete:

**Unit tests — PredictionEngine**
- [ ] All 10 edge cases in §3 have dedicated tests
- [ ] Date fixtures use a fixed anchor date, not `Date()`
- [ ] `cyclesUsed` and `confidenceLevel` assertions match exact spec thresholds
- [ ] SD = 2.0 boundary case explicitly tested

**Unit tests — SwiftData**
- [ ] All model tests use `ModelConfiguration(isStoredInMemoryOnly: true)`
- [ ] Fresh container created per test, not shared
- [ ] `syncStatus` lifecycle transitions asserted (pending → synced → error)
- [ ] Open period enforcement tested

**Unit tests — Privacy**
- [ ] `isPrivate == true` blocks entire day from partner payload
- [ ] `sex` symptom excluded even when `share_symptoms == true`
- [ ] Each privacy precedence rule (§5) tested in isolation

**UI tests — Log Sheet**
- [ ] `--in-memory-store` launch argument active
- [ ] `continueAfterFailure = false` set
- [ ] All steps in §6 table have a passing test
- [ ] Elements located by `accessibilityIdentifier`

**UI tests — Chip toggle**
- [ ] Optimistic state verified (no loading indicator after tap)
- [ ] Toggle-on and toggle-off both tested

**UI tests — isPrivate**
- [ ] Toggle visible in Log Sheet
- [ ] Toggle effect persists across sheet re-open

**DI / testability**
- [ ] No `@Observable` ViewModel holds a concrete Supabase type
- [ ] `FakeSyncCoordinator` used in all ViewModel unit tests
- [ ] `PredictionEngine` tests pass `[PeriodLog]` directly

**Coverage**
- [ ] `PredictionEngine`: 90%+
- [ ] Privacy filter: 90%+
- [ ] SwiftData models: 80%+
- [ ] ViewModels: 75%+
- [ ] Coverage verified per-file, not just aggregate
