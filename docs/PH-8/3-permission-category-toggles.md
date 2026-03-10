# Permission Category Toggle UI & Writes

**Epic ID:** PH-8-E3
**Phase:** 8 -- Partner Connection & Privacy Architecture
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the 6 permission category toggle UI within a `PartnerManagementView` surface and wire each toggle to an immediate Supabase write updating the corresponding `share_*` column in `partner_connections`. Changes take effect immediately with optimistic local state and rollback on failure. This is the primary ongoing control interface the Tracker uses to define what their Partner can see after the connection is live.

## Problem / Context

After a connection is established (E2), all six `share_*` columns are false -- the Partner sees nothing. Without this epic, the Tracker has no mechanism to enable any sharing. The permission toggles are the core of the product's privacy-first proposition: sharing is explicit, granular, and reversible at any time.

Each toggle maps directly to a `share_*` column that Supabase RLS evaluates for every Partner read query. An immediate Supabase write is mandatory -- a queued or deferred write creates a window where the Tracker believes they have enabled (or disabled) a category but the RLS policy has not yet been updated. This produces a subtle, hard-to-reproduce class of privacy bugs: the Partner either sees data the Tracker believes is blocked, or is blocked from data the Tracker believes is shared.

Optimistic local state applies, as defined in the cadence-motion skill: the toggle visually flips immediately on tap; the Supabase write happens asynchronously. On failure, the toggle reverts with a non-blocking error toast. The Tracker is never left in a state where the UI and the server diverge silently.

The Symptoms toggle carries a special annotation: "Sex is always private." This surfaces the Sex symptom exclusion invariant to the Tracker as a product guarantee, not just an implementation detail. The enforcement is in the data layer (E5), but the UX must communicate it.

**Source references that define scope:**

- MVP Spec §2 (Partner Sharing -- Permission Model: 6 categories, default off, Tracker explicitly opts in; Flow 4: Manage Sharing Permissions)
- cadence-privacy-architecture skill §1 (all `share_*` default false; Sex always excluded from Partner output regardless of share_symptoms)
- cadence-privacy-architecture skill §6 (immediate Supabase write required; optimistic rollback on failure)
- Design Spec v1.1 §12.2 (Partner Sharing Status Strip context on Home -- strip reflects active/paused state, not individual permission state)
- PHASES.md Phase 8 in-scope: "6 permission category toggles (period predictions, phase, symptoms, mood, fertile window, daily notes -- all default off); permission toggle writes to partner*connections.share*\* columns with immediate effect (Supabase write + RLS re-evaluation)"

## Scope

### In Scope

- `PermissionCategory` enum in `Cadence/Models/PermissionCategory.swift`: 6 cases (`.predictions`, `.phase`, `.symptoms`, `.mood`, `.fertileWindow`, `.notes`); each case has a computed `displayName: String` and `description: String` (short human-readable description, e.g. "Period dates and countdown" for `.predictions`); each case has a `columnName: String` returning the corresponding `partner_connections` column name (e.g. `"share_predictions"`)
- `PartnerPermissions` struct (defined or relocated to `Cadence/Models/PartnerPermissions.swift`): value type with six `Bool` properties matching `share_*` columns plus `is_paused: Bool`; mutable subscript `mutating func toggle(_ category: PermissionCategory)` that flips the relevant Bool; initialized from a `partner_connections` Supabase row
- `PartnerConnectionStore.setPermission(_ category: PermissionCategory, enabled: Bool) async throws` (extends store from E1/E2): applies optimistic `activePermissions[category] = enabled` on `@MainActor`; issues `supabase.from("partner_connections").update([category.columnName: enabled]).eq("tracker_id", auth.uid())`; on failure, reverts `activePermissions[category]` to the pre-tap value and posts a non-blocking toast
- `Cadence/Views/Settings/PermissionToggleRow.swift`: reusable row component; `init(category: PermissionCategory, isOn: Binding<Bool>)`; layout: category `displayName` in `body` + `CadenceTextPrimary` leading; `description` in `footnote` + `CadenceTextSecondary` below name; `Toggle(isOn:)` trailing; minimum touch area 44pt; no `.listRowBackground` override
- Symptoms row annotation: `PermissionToggleRow` for `.symptoms` renders an additional line below the description: "Sex is always kept private" in `caption1` + `CadenceTextSecondary`, italic; this annotation is not shown for other categories
- `Cadence/Views/Settings/PartnerManagementView.swift`: `@Observable`-backed view showing the full partner management surface; sections: (1) partner status header (partner name or "Connected partner", connection status badge); (2) "SHARING PERMISSIONS" section with 6 `PermissionToggleRow` instances rendered from `PermissionCategory.allCases`; (3) Pause sharing toggle row (E4 builds `PauseSharingToggleRow`; E3 reserves a section separator for it)
- Default-off state validation: when `PartnerConnectionStore.activePermissions` is initialized from a freshly confirmed connection row, all 6 `share_*` Bool properties are false; the toggle UI renders all 6 rows in off state; no special empty-state UI needed (all rows visible at all times)
- `ConnectionConfirmationView` (E2-S4) category name inline constants replaced with `PermissionCategory.allCases` iteration -- E3 closes the explicit placeholder note from E2
- `project.yml` updated with entries for `PermissionCategory.swift`, `PartnerPermissions.swift`, `PermissionToggleRow.swift`, `PartnerManagementView.swift`; `xcodegen generate` exits 0

### Out of Scope

- Pause sharing toggle row visual implementation -- PH-8-E4 (a section separator for it is reserved in `PartnerManagementView` here)
- Disconnect button in `PartnerManagementView` -- PH-8-E4
- Settings navigation tree that surfaces `PartnerManagementView` -- Phase 12 (the view is built here; navigation routing is Phase 12)
- Partner-side experience when permissions change -- Phase 9 (the Partner Dashboard Realtime subscription picks up `share_*` changes; that rendering is Phase 9's concern)
- Per-category notification configuration -- Phase 10
- Sex symptom data layer filtering logic -- PH-8-E5 (the annotation in this epic is informational UI only)

## Dependencies

| Dependency                                                                     | Type | Phase/Epic       | Status | Risk                                                                                |
| ------------------------------------------------------------------------------ | ---- | ---------------- | ------ | ----------------------------------------------------------------------------------- |
| Active `partner_connections` row with `connected_at IS NOT NULL`               | FS   | PH-8-E2          | Open   | Low -- E2 is a hard prerequisite; toggles have no meaning without a live connection |
| `PartnerConnectionStore` with `activePermissions: PartnerPermissions` property | FS   | PH-8-E1, PH-8-E2 | Open   | Low                                                                                 |
| `PrimaryButton` component                                                      | FS   | PH-4             | Open   | Low -- component exists                                                             |

## Assumptions

- `PartnerPermissions` is a value type (struct), not a reference type. `PartnerConnectionStore` holds a single `activePermissions` instance. Toggling a category produces a new struct value via copy-on-write, triggering `@Observable` change notification correctly.
- The `partner_connections` RLS policy allows the Tracker to update any `share_*` column on their own row. Confirm with Phase 1 RLS before implementation.
- `PermissionCategory.allCases` order in the rendered list matches the display order in MVP Spec §2 permission table: predictions, phase, symptoms, mood, fertile window, notes.

## Risks

| Risk                                                                                 | Likelihood | Impact                                                                     | Mitigation                                                                                                                                           |
| ------------------------------------------------------------------------------------ | ---------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Optimistic rollback race: two rapid toggle taps before first write resolves          | Low        | Low -- the second tap should be blocked while the first write is in flight | Disable the toggle for the category being written until the Supabase response resolves; use a `Set<PermissionCategory>` `pendingWrites` on the store |
| Phase 1 RLS does not allow Tracker to update individual `share_*` columns separately | Low        | High -- toggles would fail silently                                        | Verify with a direct Supabase client call in a test environment before building the full UI                                                          |

---

## Stories

### S1: PermissionCategory Enum + PartnerPermissions Struct

**Story ID:** PH-8-E3-S1
**Points:** 3

Define the `PermissionCategory` enum and `PartnerPermissions` struct that model the six sharing categories as first-class types. Extend `PartnerConnectionStore` with an `activePermissions: PartnerPermissions` property initialized from the Supabase row.

**Acceptance Criteria:**

- [ ] `PermissionCategory` is an enum with exactly 6 cases; each case has `displayName: String`, `description: String`, and `columnName: String` computed properties
- [ ] `displayName` values match MVP Spec §2 permission table exactly: "Period predictions and countdown", "Current cycle phase", "Symptoms", "Mood", "Fertile window", "Daily notes"
- [ ] `PermissionCategory.allCases` produces cases in the order listed above (CaseIterable conformance)
- [ ] `PartnerPermissions` is a struct with 6 Bool properties (`sharePredictions`, `sharePhase`, `shareSymptoms`, `shareMood`, `shareFertileWindow`, `shareNotes`) and one `isPaused: Bool` property; all default to false
- [ ] `PartnerPermissions` has a `subscript(_ category: PermissionCategory) -> Bool` getter and setter mapping each case to the corresponding Bool property
- [ ] `PartnerConnectionStore.activePermissions` initializes from the `partner_connections` Supabase row on store hydration
- [ ] Unit test: `PartnerPermissions` initialized with all false values has `subscript(.predictions) == false` for all cases
- [ ] Unit test: setting `activePermissions[.symptoms] = true` then reading it back returns `true`

**Dependencies:** PH-8-E1-S2 (store hydration exists)
**Notes:** `PermissionCategory.columnName` is used by `setPermission` in S4 to build the Supabase update dictionary. The mapping must be exact to the `partner_connections` column names defined in MVP Spec data model.

---

### S2: PermissionToggleRow Component

**Story ID:** PH-8-E3-S2
**Points:** 2

Implement the `PermissionToggleRow` reusable component with `init(category: PermissionCategory, isOn: Binding<Bool>)`. Renders category name, description, and system toggle. Meets 44pt touch target. Includes the Sex annotation variant for `.symptoms`.

**Acceptance Criteria:**

- [ ] `PermissionToggleRow(category: .predictions, isOn: $binding)` renders "Period predictions and countdown" in `body` weight with the toggle trailing
- [ ] Category `description` renders below the `displayName` in `footnote` + `CadenceTextSecondary`
- [ ] When `category == .symptoms`, an additional annotation line "Sex is always kept private" appears below the description in `caption1` + `CadenceTextSecondary`, italic style
- [ ] The toggle's effective touch area is minimum 44 x 44pt
- [ ] No hardcoded hex colors in the component; all tokens via `Color("CadenceTokenName")`
- [ ] Component renders correctly in both off (Bool = false) and on (Bool = true) states
- [ ] `PermissionToggleRow` does not contain any `@Observable` dependency -- it is driven entirely by the `isOn: Binding<Bool>` parameter

**Dependencies:** PH-8-E3-S1
**Notes:** Do not add a loading/disabled visual state in this story -- that is handled in S4 (the store's `pendingWrites` disables the binding from the parent).

---

### S3: PartnerManagementView Permission Section Layout

**Story ID:** PH-8-E3-S3
**Points:** 3

Implement `PartnerManagementView` with the partner status header section and the "SHARING PERMISSIONS" section rendering 6 `PermissionToggleRow` instances. Reserve a section separator for the E4 pause sharing toggle.

**Acceptance Criteria:**

- [ ] `PartnerManagementView` renders inside a `ScrollView` with a `LazyVStack(spacing: 0)` content container (per swiftui-production: LazyVStack for all feed views)
- [ ] Section 1 header: "Connected" badge in `caption1` + `CadenceSage` on `CadenceSageLight` background (capsule); partner display name in `title3` + `CadenceTextPrimary`
- [ ] "SHARING PERMISSIONS" eyebrow label in `caption2` uppercased + `CadenceTextSecondary` with `space-16` top padding
- [ ] 6 `PermissionToggleRow` instances rendered from `PermissionCategory.allCases` in a `VStack` within a `DataCard` (Design Spec §10.4); rows separated by 1pt `CadenceBorder` dividers (not system `Divider()` -- use a `Rectangle().fill(Color("CadenceBorder")).frame(height: 1)`)
- [ ] A clearly commented section separator (`// E4: PauseSharingToggleRow`) below the permission section -- this is a reserved position, not a placeholder stub (the comment marks insertion point for E4, which is an adjacent epic)
- [ ] No `AnyView` in the view hierarchy (swiftui-production constraint)
- [ ] View conforms to the 16pt horizontal safe-area inset requirement from Design Spec §5

**Dependencies:** PH-8-E3-S2, PH-8-E2 (active connection data for partner name)
**Notes:** `PartnerManagementView` takes `PartnerConnectionStore` via `@Environment` injection (not `@StateObject` or direct init parameter -- must be injectable for testing per cadence-testing skill).

---

### S4: PartnerConnectionStore.setPermission + Supabase Write with Optimistic Rollback

**Story ID:** PH-8-E3-S4
**Points:** 3

Implement `PartnerConnectionStore.setPermission(_ category: PermissionCategory, enabled: Bool) async throws` with optimistic local state, Supabase write, and rollback on failure. Wire `PermissionToggleRow` bindings in `PartnerManagementView` through this method.

**Acceptance Criteria:**

- [ ] `setPermission(.predictions, enabled: true)` immediately sets `activePermissions[.predictions] = true` on `@MainActor`, then issues the Supabase UPDATE
- [ ] The Supabase UPDATE payload is `[category.columnName: enabled]` -- a single-column update; does not include any other columns
- [ ] On Supabase write failure, `activePermissions[category]` is reverted to the pre-tap Bool value; a non-blocking toast appears (Design Spec §13 error pattern)
- [ ] While a write is in flight for a category, `PartnerManagementView` disables the toggle for that specific category only (other toggles remain interactive); a `Set<PermissionCategory>` named `pendingWrites` on the store tracks in-flight categories
- [ ] Unit test: mock successful write produces `activePermissions[category] == true` and `pendingWrites.isEmpty`
- [ ] Unit test: mock failed write reverts `activePermissions[category]` to `false` and `pendingWrites.isEmpty`
- [ ] `PartnerManagementView` bindings: each `PermissionToggleRow` passes `Binding(get: { store.activePermissions[category] }, set: { _ in Task { try await store.setPermission(category, enabled: ...) } })`

**Dependencies:** PH-8-E3-S1, PH-8-E3-S3
**Notes:** The `Binding` set closure fires `Task { try await ... }` -- the toggle tap is non-blocking. The `pendingWrites` set prevents the user from double-tapping while the write is in flight, but does not block other category toggles.

---

### S5: Default-Off Initialization Verification + ConnectionConfirmationView Category Replacement

**Story ID:** PH-8-E3-S5
**Points:** 2

Verify that a freshly confirmed connection produces all-false `PartnerPermissions` in the store, rendering all 6 toggles in the off state. Replace the E2-S4 inline category name constants in `ConnectionConfirmationView` with `PermissionCategory.allCases` iteration.

**Acceptance Criteria:**

- [ ] On `PartnerConnectionStore` hydration from a connection row with all `share_*` = false, `activePermissions.sharePredictions` through `activePermissions.shareNotes` all equal `false`
- [ ] `PartnerManagementView` renders all 6 toggles in off state when `activePermissions` is all-false
- [ ] `ConnectionConfirmationView` (E2-S4) "They will see:" section iterates `PermissionCategory.allCases` filtering `store.activePermissions[$0] == true` instead of the inline constant array
- [ ] `ConnectionConfirmationView` "They will not see:" section iterates `PermissionCategory.allCases` filtering `store.activePermissions[$0] == false`
- [ ] The `// Replace with PermissionCategory.allCases in E3` comment from E2-S4 is removed
- [ ] Unit test: `PartnerPermissions()` (default init) has all 6 `share_*` Bool properties == false

**Dependencies:** PH-8-E3-S1, PH-8-E2-S4
**Notes:** This story closes the explicit technical debt noted in E2-S4. It is a required part of Phase 8, not a cleanup item.

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
- [ ] End-to-end verified: toggling "Period predictions and countdown" to on updates the live Supabase `partner_connections` row `share_predictions = true` within the same user session
- [ ] End-to-end verified: toggling a category off while the Partner is connected produces an RLS re-evaluation that blocks the Partner's next read of that data type
- [ ] Phase objective is advanced: Tracker can control all 6 permission categories from the UI
- [ ] Applicable skill constraints satisfied: cadence-privacy-architecture (immediate write, optimistic rollback, no silent divergence), swiftui-production (@Observable, LazyVStack, no AnyView), cadence-design-system (no hardcoded hex), cadence-accessibility (44pt targets on all toggles)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility requirements verified: all 6 toggles have correct VoiceOver labels ("{category displayName}, on/off, toggle")
- [ ] No dead code, stubs, or placeholder comments (the E2-S4 inline constant comment removed in S5)
- [ ] Source document alignment verified: permission category names match MVP Spec §2 table exactly

## Source References

- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (in-scope: 6 permission category toggles, immediate Supabase write)
- MVP Spec §2 (Partner Sharing -- Permission Model table, Flow 4: Manage Sharing Permissions)
- cadence-privacy-architecture skill §1 (defaults to off, Sex always excluded)
- cadence-privacy-architecture skill §6 (write code that is safe without RLS; immediate write requirement)
- Design Spec v1.1 §10.5 (Partner Sharing Status Strip -- active state context)
- Design Spec v1.1 §5 (Spacing -- 16pt inset, space-20 card padding)
- swiftui-production skill (LazyVStack for feeds, @Observable, no AnyView)
