# Invite Code Generation

**Epic ID:** PH-8-E1
**Phase:** 8 -- Partner Connection & Privacy Architecture
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the Tracker-side invitation flow: generate a cryptographically random, unique 6-digit invite code; persist a pending `partner_connections` row with a 24-hour expiry and all `share_*` flags false; enforce the one-active-connection beta constraint; and surface the code to the Tracker in a dedicated view for out-of-band sharing. This epic is the prerequisite for E2 -- no connection handshake can occur until a valid pending row exists.

## Problem / Context

The partner connection handshake depends entirely on a short-lived, unique invite code as its authentication token. If the code is not unique, a malicious party could connect to the wrong Tracker. If expiry is not enforced, stale codes accumulate and may be guessed. If the one-active-connection constraint is not enforced, the Tracker could end up in a state where two partner_id candidates compete for the same tracker_id row, producing undefined behavior in all downstream permission management.

MVP Spec §2 defines the full connection flow and states: "Only one active partner connection is permitted per Tracker in the beta." The one-connection constraint is a beta business rule, not a technical limitation -- the schema supports multiple rows, but the product does not. Enforcing it here, at code generation time, prevents the state from ever entering an inconsistent condition.

The `PartnerConnectionStore` introduced in this epic is the `@Observable` source of truth for all connection state across E2, E3, E4, and E5. Getting its shape right here prevents cascading refactors in subsequent epics.

**Source references that define scope:**

- MVP Spec §2 (Partner Sharing -- Connection Flow: 6-digit code, 24h expiry, one-connection beta constraint)
- MVP Spec §2 (Data Model: `partner_connections` schema -- `tracker_id`, `partner_id`, `invite_code`, `connected_at`, `is_paused`, all `share_*` columns)
- cadence-privacy-architecture skill §1 (privacy defaults to off -- all `share_*` flags false at row creation)
- PHASES.md Phase 8 in-scope: "Invite code generation in Tracker Settings (6-digit, unique, 24h expiry, written to partner_connections table)"

## Scope

### In Scope

- `Cadence/Services/InviteCodeService.swift`: generates a 6-digit code using `SystemRandomNumberGenerator`; pads to 6 digits with leading zeros if needed; queries `partner_connections` to verify uniqueness on the `invite_code` column; retries up to 5 times on collision; throws a typed error after 5 failed attempts
- `Cadence/ViewModels/PartnerConnectionStore.swift` (initial shape, extended in E2/E3/E4): `@Observable` class; properties: `connectionStatus: PartnerConnectionStatus` (enum `.none`, `.pendingCode(code: String, expiresAt: Date)`, `.pendingConfirmation`, `.active`), `activePermissions: PartnerPermissions` (struct mirroring all 6 `share_*` columns plus `is_paused`); method `generateInviteCode() async throws`; initialized by querying the current `partner_connections` row for `tracker_id = auth.uid()` at app launch
- `partner_connections` pending row insert: `tracker_id = auth.uid()`, `invite_code = generatedCode`, `expires_at = Date() + 86400` (stored as ISO8601 timestamptz), all six `share_*` columns = false, `is_paused = false`, `partner_id = null`, `connected_at = null`
- `Cadence/Views/Settings/InviteCodeView.swift`: displays the 6-digit code formatted with a centered space or hyphen separator for readability; copy-to-clipboard button using `UIPasteboard.general.string`; "Expires in 24 hours" label in `footnote` + `CadenceTextSecondary`; "Share code" affordance using `ShareLink` (SwiftUI native); disables "Generate Code" CTA while code is pending (prevent duplicate rows)
- One-active-connection guard in `PartnerConnectionStore.generateInviteCode()`: before issuing the insert, queries `partner_connections` for any row where `tracker_id = auth.uid()` and (`partner_id IS NOT NULL` or `expires_at > now()`); throws `PartnerConnectionError.alreadyConnected` or `.pendingCodeExists` respectively
- Code expiry recovery: on `PartnerConnectionStore` init, if the loaded row has `expires_at < now()` and `partner_id IS NULL`, delete the expired row before presenting the invite section; after deletion, `connectionStatus` reverts to `.none` and the "Generate new code" CTA becomes available
- `project.yml` updated with entries for `InviteCodeService.swift`, `PartnerConnectionStore.swift`, `InviteCodeView.swift` under their respective source groups; `xcodegen generate` exits 0 after changes

### Out of Scope

- Connection finalization (writing `partner_id`, `connected_at`) -- PH-8-E2
- Permission toggle UI -- PH-8-E3
- Pause sharing and disconnect flows -- PH-8-E4
- Privacy enforcement data layer -- PH-8-E5
- Full Settings navigation tree that surfaces `InviteCodeView` -- Phase 12 Settings (the view is built here; navigation routing is Phase 12)
- Push notification to Tracker when a Partner enters the code -- Phase 10

## Dependencies

| Dependency                                                         | Type | Phase/Epic | Status | Risk                                                                                                                                             |
| ------------------------------------------------------------------ | ---- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `partner_connections` table schema exists in Supabase              | FS   | PH-1       | Open   | Low -- Phase 1 is a hard prerequisite for Phase 8                                                                                                |
| RLS policy: Tracker can insert their own `partner_connections` row | FS   | PH-1       | Open   | Low                                                                                                                                              |
| Auth session producing `auth.uid()` for Tracker                    | FS   | PH-2       | Open   | Low                                                                                                                                              |
| `SyncCoordinator` write queue available for Supabase insert        | SS   | PH-7       | Open   | Medium -- sync must be active for writes to propagate; if Phase 7 is incomplete, direct Supabase client write is the fallback for this epic only |

## Assumptions

- The `partner_connections` table has an `expires_at` column (timestamptz) added as part of Phase 1 schema. If the Phase 1 schema omitted this column, a migration must be applied before this epic begins.
- `invite_code` has a unique index on the `partner_connections` table (Phase 1). Without it, the uniqueness check requires a full-table scan rather than an index lookup, which is acceptable for beta but must be called out.
- The 6-digit code is sufficient entropy for a private beta cohort. A known-user beta with low volume means brute-force risk is negligible.
- `PartnerConnectionStore` is injected into `TrackerShell` via the environment and shared across all Settings and Home surfaces that need connection state.

## Risks

| Risk                                                                              | Likelihood | Impact                                                            | Mitigation                                                                                                               |
| --------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `partner_connections.expires_at` column missing from Phase 1 schema               | Medium     | High -- epic cannot proceed                                       | Confirm Phase 1 schema before starting; apply migration if needed                                                        |
| Race condition: two Trackers generate the same code simultaneously                | Low        | Medium -- duplicate code produces broken connection for one party | Uniqueness index on `invite_code` + retry logic in `InviteCodeService` covers this case                                  |
| `PartnerConnectionStore` shape incorrect here causes cascading refactors in E2-E4 | Medium     | Medium                                                            | Review store design against E2/E3/E4 scope before implementing; treat this epic's store shape as a design decision point |

---

## Stories

### S1: InviteCodeService -- Code Generation with Uniqueness Check

**Story ID:** PH-8-E1-S1
**Points:** 3

Implement `InviteCodeService.generate() async throws -> String` using `SystemRandomNumberGenerator` to produce a cryptographically unpredictable 6-digit string. Before returning, query `partner_connections` for an existing row with that code. Retry up to 5 times on collision. Throw `InviteCodeError.generationFailed` after 5 attempts.

**Acceptance Criteria:**

- [ ] `InviteCodeService.generate()` returns a string of exactly 6 decimal digit characters (e.g. "042781")
- [ ] Calling `generate()` 1000 times produces no repeated values in a local test (probabilistic -- collision at 1/10^6 probability)
- [ ] If a mock Supabase client returns `alreadyExists` on the first 4 attempts and `success` on the 5th, `generate()` returns successfully (retry logic works up to 5 attempts)
- [ ] If a mock Supabase client returns `alreadyExists` on all 5 attempts, `generate()` throws `InviteCodeError.generationFailed`
- [ ] No `print()` or `debugPrint()` statements in committed code
- [ ] `scripts/protocol-zero.sh` exits 0 on this file

**Dependencies:** None
**Notes:** Use `var rng = SystemRandomNumberGenerator()` and `Int.random(in: 0...999999, using: &rng)` formatted with `String(format: "%06d", value)`. Do not use `arc4random` or `UUID`-based truncation.

---

### S2: PartnerConnectionStore -- Initial Shape and App-Launch Hydration

**Story ID:** PH-8-E1-S2
**Points:** 2

Define `PartnerConnectionStore` as an `@Observable` class with `connectionStatus: PartnerConnectionStatus`, a `PartnerConnectionStatus` enum, and an `init(supabase: SupabaseClient)` that queries the existing `partner_connections` row for the current Tracker at launch and populates `connectionStatus` from the result.

**Acceptance Criteria:**

- [ ] `PartnerConnectionStatus` enum has exactly four cases: `.none`, `.pendingCode(code: String, expiresAt: Date)`, `.pendingConfirmation`, `.active`
- [ ] `PartnerConnectionStore.init(supabase:)` executes a Supabase query on `partner_connections` where `tracker_id = auth.uid()` and populates `connectionStatus` based on the row state (no row = `.none`, pending code row = `.pendingCode`, pending confirmation row = `.pendingConfirmation`, active row = `.active`)
- [ ] `PartnerConnectionStore` conforms to `@Observable` (not `ObservableObject`)
- [ ] Dependency injection via `init(supabase:)` -- no singleton access, no global state
- [ ] Unit test: mock Supabase returning no row produces `connectionStatus == .none`
- [ ] Unit test: mock Supabase returning a row with `partner_id = null` and `expires_at` in the future produces `connectionStatus == .pendingCode(...)`

**Dependencies:** None (store shape is defined here independently of the Supabase connection)
**Notes:** `PartnerConnectionStatus.pendingCode` carries the code string and expiry date because `InviteCodeView` needs both without a secondary Supabase fetch.

---

### S3: partner_connections Pending Row Insert

**Story ID:** PH-8-E1-S3
**Points:** 3

Implement `PartnerConnectionStore.generateInviteCode() async throws` to call `InviteCodeService.generate()`, insert the `partner_connections` pending row into Supabase, and update `connectionStatus` to `.pendingCode(code:expiresAt:)` on success.

**Acceptance Criteria:**

- [ ] On successful insert, `connectionStatus` transitions to `.pendingCode(code: generatedCode, expiresAt: Date() + 86400)` on the main actor
- [ ] The inserted row has `tracker_id = auth.uid()`, `invite_code = generatedCode`, `expires_at = now() + 86400 seconds`, all six `share_*` columns = false, `is_paused = false`, `partner_id = null`, `connected_at = null`
- [ ] On Supabase write failure, `connectionStatus` remains unchanged and the method throws a typed error (does not silently fail)
- [ ] The method is annotated `@MainActor` or uses `await MainActor.run` for all `connectionStatus` mutations
- [ ] No duplicate row is possible: the one-connection guard in S4 must pass before this insert executes (S3 and S4 are logically sequential; S4 is a pre-condition check that S3 depends on being wired by the caller)

**Dependencies:** PH-8-E1-S1 (InviteCodeService must exist), PH-8-E1-S2 (store shape must exist)
**Notes:** Write through SyncCoordinator queue if Phase 7 is complete; write directly via `supabase.from("partner_connections").insert(...)` if Phase 7 queue is not yet available for this operation. Document the decision in a code comment.

---

### S4: InviteCodeView -- Code Display, Copy, and Generate CTA

**Story ID:** PH-8-E1-S4
**Points:** 3

Implement `InviteCodeView` rendering the code display surface. When `connectionStatus == .none`, renders a "Invite a Partner" CTA button. When `connectionStatus == .pendingCode(...)`, renders the formatted code, copy button, `ShareLink`, and expiry label. Loading state while generate is in flight.

**Acceptance Criteria:**

- [ ] When `connectionStatus == .none`, a "Invite a Partner" button is visible; tapping it calls `PartnerConnectionStore.generateInviteCode()` and shows an inline `ProgressView` during the async call
- [ ] When `connectionStatus == .pendingCode(code: "042781", expiresAt:)`, the view displays "042 781" (space-separated groups of 3) in a `headline` style centered in a `DataCard`
- [ ] Copy button copies the raw 6-digit string (no spaces) to `UIPasteboard.general.string`
- [ ] `ShareLink` opens the iOS share sheet with the plain text message "Here's my Cadence invite code: 042781"
- [ ] Expiry label reads "Expires in 24 hours" in `footnote` + `CadenceTextSecondary`
- [ ] No hardcoded hex colors in the view; all colors use `Color("CadenceTokenName")` form
- [ ] Touch targets for copy button and "Invite a Partner" CTA meet 44pt minimum

**Dependencies:** PH-8-E1-S2 (store), PH-8-E1-S3 (generate method)
**Notes:** The `ShareLink` wraps a plain `String` item. No custom activity types needed.

---

### S5: One-Active-Connection Guard + Expired Code Recovery

**Story ID:** PH-8-E1-S5
**Points:** 3

Wire the one-connection guard into `PartnerConnectionStore.generateInviteCode()` and implement expired code detection and cleanup in the store's init path.

**Acceptance Criteria:**

- [ ] If `connectionStatus == .active`, calling `generateInviteCode()` throws `PartnerConnectionError.alreadyConnected` without executing any Supabase write
- [ ] If `connectionStatus == .pendingCode(...)` with a non-expired code, calling `generateInviteCode()` throws `PartnerConnectionError.pendingCodeExists` without executing any Supabase write or deleting the existing row
- [ ] On store init, if the loaded row has `expires_at < Date()` and `partner_id == nil`, the store issues a Supabase delete for that row and sets `connectionStatus = .none`
- [ ] After expired row deletion, calling `generateInviteCode()` succeeds and inserts a fresh row
- [ ] Unit test: mock returning an active connection row causes `generateInviteCode()` to throw without issuing an insert
- [ ] Unit test: mock returning an expired pending row causes init to delete the row (delete call is observable on the mock)

**Dependencies:** PH-8-E1-S2, PH-8-E1-S3
**Notes:** Both guard conditions check local `connectionStatus` state, not a fresh Supabase query -- the store is authoritative after init hydration.

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
- [ ] Integration with dependencies verified end-to-end: a generated invite code appears as a row in the live Supabase `partner_connections` table with correct field values
- [ ] Phase objective is advanced: a Tracker can generate an invite code and see it on screen
- [ ] Applicable skill constraints satisfied: cadence-privacy-architecture (all `share_*` false at row creation), swiftui-production (@Observable, no AnyView, no force unwraps), cadence-design-system (no hardcoded hex), cadence-accessibility (44pt targets), cadence-xcode-project (project.yml updated)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility requirements verified per cadence-accessibility skill
- [ ] Offline-first write path verified: if Supabase is unreachable, `generateInviteCode()` fails gracefully with a typed error (no silent discard)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: `partner_connections` row shape matches MVP Spec data model exactly

## Source References

- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (in-scope: invite code generation)
- MVP Spec §2 (Partner Sharing -- Connection Flow, Data Model: partner_connections schema)
- cadence-privacy-architecture skill §1 (privacy defaults to off -- all share\_\* false at row creation)
- Design Spec v1.1 §8 (Information Architecture -- Settings tab context for Tracker)
