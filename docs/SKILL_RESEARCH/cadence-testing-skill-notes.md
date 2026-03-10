# cadence-testing Skill — Creation Notes

**Date:** March 7, 2026
**Skill location:** `.claude/skills/cadence-testing/SKILL.md`
**Packaged to:** `.claude/skills/skill-creator/cadence-testing.skill`

---

## Local Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure conventions, YAML frontmatter, eval format, packaging workflow |
| `.claude/skills/skill-creator/references/schemas.md` | evals.json, grading.json, benchmark.json schemas |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — data model, RLS policy, prediction spec, share_* flags, isPrivate semantics |
| `docs/Cadence_Design_Spec_v1.1.md` | Design spec — Log Sheet structure, chip behavior, isPrivate toggle, center tab modal intercept |
| `.claude/skills/cadence-data-layer/SKILL.md` | PredictionEngine spec, confidence scoring thresholds, SwiftData schema, algorithm formulas |
| `.claude/skills/cadence-privacy-architecture/SKILL.md` | Privacy precedence hierarchy, isPrivate rules, sex exclusion contract, partner payload rules |
| `.claude/skills/cadence-sync/SKILL.md` | SyncCoordinator architecture, actor pattern, DI expectations, protocol surface |

---

## skill-creator Location

`.claude/skills/skill-creator/` — local project install.

Process followed: reviewed SKILL.md → wrote draft → created evals.json (3 test cases) → ran `python -m scripts.package_skill` → validated and packaged successfully to `cadence-testing.skill`.

---

## Official Anthropic Sources Used (Skill Standards)

- Skill structure: `skill-creator/SKILL.md` (locally installed, project-canonical authority)
- Schema: `skill-creator/references/schemas.md`
- Packaging: `skill-creator/scripts/package_skill.py` (ran and validated)

No external Anthropic sources were required — the locally installed skill-creator is the authoritative standard for this project.

---

## Authoritative Sources Used (Swift / SwiftUI / Testing)

| Topic | Source |
|---|---|
| SwiftData in-memory testing | `ModelConfiguration(isStoredInMemoryOnly: true)` — Apple SwiftData documentation; confirmed via HackingWithSwift SwiftData tutorials |
| @Observable DI patterns | Swift by Sundell (async DI); Jacob Bartlett's Observable testing article |
| XCUITest sheet/modal testing | Apple Developer XCTest docs; iOS Guru modal testing guide |
| UITest launch arguments for SwiftData | delasign.com UITest in-memory SwiftData pattern |
| Swift Testing `#expect` macro | Swift 5.10+ Testing framework (WWDC 2024-aligned) |
| Supabase client boundary isolation | Cadence's own cadence-sync skill (authoritative project source) |

---

## Cadence-Specific Testing Facts Extracted

### Repository State
- **No Swift files exist** — repo is pre-implementation (docs + skills only)
- **No `project.yml`** — XcodeGen spec not yet written
- **No test targets** — `CadenceTests` and `CadenceUITests` do not yet exist
- **No CI tooling** — no `.github`, Fastfile, or test plans present

### PredictionEngine (from cadence-data-layer skill)
- Pure Swift struct, takes `[PeriodLog]` or `ModelContext`, zero network deps, synchronous
- Algorithm: `nextPeriod = lastStart + avgCycle`, `ovulation = nextPeriod - 14`, `fertileStart = ovulation - 5`, `fertileEnd = ovulation`
- Uses most recent 3–6 completed periods (periods with `endDate != nil`)
- Confidence: 0-1 cycles=low, 2-3=medium, 4+ SD≤2.0=high, 4+ SD>2.0=medium
- SD=2.0 boundary: `≤` is inclusive → confidence=high
- Defaults when no history: cycleLength=28, periodLength=5

### SwiftData Models (5 core models)
- `CycleProfile`, `PeriodLog`, `DailyLog`, `SymptomLog`, `PredictionSnapshot`
- All carry `syncStatus: SyncStatus` (enum: pending/synced/error)
- `DailyLog.isPrivate: Bool` — master privacy override, default false
- `SymptomType.sex` — stored locally, always excluded from partner payloads
- At most one open `PeriodLog` (nil endDate) per user — enforced at write time

### Privacy Architecture (from cadence-privacy-architecture skill)
- Precedence: isPrivate → is_paused → sex → share_* → RLS
- isPrivate blocks entire day — all fields, all symptoms, no exceptions
- Sex symptom: unconditional exclusion, no flag overrides it
- Client must enforce rules 1–4 before RLS (RLS is defense-in-depth only)

### Log Sheet (from design spec §12.3)
- Bottom sheet, `.medium` (default) + `.large` detents
- Center tab intercept — `selectedTab` never becomes `.log`
- Contains: date header, period toggles, flow chips, symptom chip grid, notes, isPrivate toggle, Save CTA
- "Keep this day private" — master override; sets `DailyLog.isPrivate = true`

### Chip Toggle (from design spec §10.1 and §11)
- Instant state change on tap — no network wait, optimistic
- 0.15s easeOut cross-dissolve for color (motion skill)
- Sex chip shows lock icon permanently regardless of state

### SyncCoordinator (from cadence-sync skill)
- Declared as `actor`, singleton per app session, injected via `@Environment`
- Must be protocol-abstracted for unit testability
- Owns all Supabase I/O — no ViewModel or View touches Supabase SDK directly

---

## Ambiguities Found and Resolution

| Ambiguity | Resolution |
|---|---|
| No `project.yml` or Swift files exist — real target names unknown | Used conventional XcodeGen names `CadenceTests` / `CadenceUITests` per cadence-xcode-project skill conventions. Documented that targets do not yet exist. |
| cadence-build skill references `CadenceTests` scheme — confirmed | Cross-referenced: cadence-build SKILL.md encodes `CadenceTests` as the test scheme. Adopted. |
| `SymptomType.sex` is stored locally and remotely for Tracker history, excluded only from Partner queries | Skill correctly scopes sex exclusion to Partner-visible payload construction, not local storage. Consistent with cadence-privacy-architecture. |
| Role-switching in UI tests (Partner view assertion for isPrivate) | Acknowledged the limitation. Skill advises unit test fallback on filter function when full role switching is infeasible in UI test target. |
| Swift Testing (`#expect`) vs XCTest (`XCTAssert`) | Skill uses both — `#expect` in unit test examples (Swift Testing, iOS 17+), `XCTAssert` in UI tests (XCUITest is XCTest-based). No conflict. |

---

## Key Enforcement Rules Encoded in the Skill

1. **All 10 PredictionEngine edge cases are mandatory** — enumerated explicitly, not left to interpretation
2. **Fixed anchor dates in test fixtures** — `Date()` is rejected; CI determinism required
3. **SD=2.0 boundary explicitly required** — confidence=high at exactly 2.0 (≤ is inclusive)
4. **isPrivate master override must have independent tests** — not bundled with other privacy rules
5. **Sex symptom exclusion tested independently of share_symptoms flag** — unconditional by contract
6. **Each privacy precedence rule tested in isolation** — not just in combination
7. **No @Observable ViewModel holds a concrete Supabase type** — absolute DI rule
8. **FakeSyncCoordinator may not import any Supabase SDK type** — enforced by comment
9. **ModelContainer never shared across test cases** — fresh per test
10. **--in-memory-store launch argument mandatory for UI tests** — Supabase client must not initialize
11. **Element lookup by accessibilityIdentifier, never display text** — design copy changes must not break tests
12. **Chip toggle test must fail if a loading indicator is visible** — optimistic contract
13. **80%+ coverage is a release gate** — PredictionEngine 90%+, privacy filter 90%+, models 80%+, VMs 75%+
14. **Per-file coverage required** — 80% aggregate masking 0% on critical files is a failure
