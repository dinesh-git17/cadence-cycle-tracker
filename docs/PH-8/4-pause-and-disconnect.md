# Pause Sharing & Disconnect Flows

**Epic ID:** PH-8-E4
**Phase:** 8 -- Partner Connection & Privacy Architecture
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the pause sharing toggle (immediate `is_paused` write to Supabase, 0.2s crossfade on the Tracker Home sharing strip) and the disconnect flow (confirmation dialog, `partner_connections` row deletion, immediate local state cleanup and re-entry to invite flow). Both operations must produce an immediate change in the Supabase-enforced state. After this epic, the Tracker has full lifecycle control over the partner relationship.

## Problem / Context

Pause sharing and disconnect are the Tracker's override mechanisms above the category-level toggles. MVP Spec §2 defines them precisely:

- **Pause:** "A single toggle that suspends all data sharing without disconnecting the relationship. The Partner sees a 'Sharing paused' state. No explanation required from the Tracker."
- **Disconnect:** "The Tracker can disconnect the partner at any time from Settings. Disconnection immediately revokes all data access."

These two operations exist at distinct positions in the cadence-privacy-architecture precedence hierarchy (skill §2). `is_paused = true` is rule 2 (evaluated after `is_private`, before any `share_*` flag). Disconnect removes the `partner_connections` row entirely, which causes all five RLS conditions to fail simultaneously -- no row means no access, regardless of what the Partner client attempts to read.

The pause toggle must also drive the Tracker Home sharing strip animation. Design Spec §10.5 defines two strip states (active = CadenceSageLight, paused = CadencePrimary high-contrast) and cadence-motion skill specifies a 0.2s easeInOut crossfade between them. This is the only Phase 8 animation that touches the Home screen -- the strip component exists from Phase 5, but the state wire-up to `PartnerConnectionStore.activePermissions.isPaused` is done here.

Disconnect is irreversible -- no soft delete, no recovery path. The `partner_connections` row is physically deleted. A confirmation dialog is required to prevent accidental disconnection. Design Spec §3 designates `CadenceDestructive` for destructive actions: "Account deletion, disconnect -- use `.red` color asset."

**Source references that define scope:**

- MVP Spec §2 (Partner Sharing -- Pause sharing behavior, Disconnect behavior, Connection Flow)
- cadence-privacy-architecture skill §2 (privacy precedence hierarchy -- `is_paused` is rule 2)
- Design Spec v1.1 §10.5 (Partner Sharing Status Strip -- active and paused states, strip background tokens)
- Design Spec v1.1 §11 (Motion -- sharing paused state change: 0.2s crossfade)
- cadence-motion skill (0.2s easeInOut crossfade on strip background, reduced-motion gating)
- PHASES.md Phase 8 in-scope: "pause sharing toggle (is_paused flag, immediate; Partner sees paused state); disconnect flow (partner_connections row deletion, immediate data access revocation)"

## Scope

### In Scope

- `PartnerConnectionStore.setPaused(_ paused: Bool) async throws` (extends store from E1/E2/E3): optimistic `activePermissions.isPaused = paused` on `@MainActor`; issues `supabase.from("partner_connections").update(["is_paused": paused]).eq("tracker_id", auth.uid())`; on failure, reverts `activePermissions.isPaused` and posts non-blocking toast; on success, no additional action (Partner Dashboard Realtime subscription handles Partner experience -- Phase 9)
- `Cadence/Views/Settings/PauseSharingToggleRow.swift`: row with "Pause sharing" in `body` + `CadenceTextPrimary` leading; "Your partner won't see any data while paused" in `footnote` + `CadenceTextSecondary` below; system `Toggle` trailing; 44pt touch target; wired to `PartnerConnectionStore.setPaused` via the same optimistic binding pattern as `PermissionToggleRow` in E3
- `PauseSharingToggleRow` inserted into `PartnerManagementView` at the reserved section separator position from E3-S3 (remove the section separator comment, insert the actual row)
- Tracker Home sharing strip crossfade: the Phase 5 `PartnerSharingStripView` component reads `PartnerConnectionStore.activePermissions.isPaused`; when `isPaused` changes, the strip background color animates from `CadenceSageLight` to the `CadencePrimary` paused token (`#1C1410` light / `#F2EDE7` dark) using `.animation(.easeInOut(duration: 0.2), value: isPaused)` on the strip's `background` modifier; gated on `!accessibilityReduceMotion` (instant swap under reduced motion)
- Note on `CadencePrimary` token: Design Spec §7 references this token for the paused strip but it is not in the §3 color table (flagged in MEMORY.md as a known spec gap). Confirm the value with Dinesh before implementing the paused strip color. If unresolved, use `CadenceTextPrimary` as a temporary stand-in and add a `// CadencePrimary unconfirmed -- see Design Spec §7 gap` comment
- Disconnect confirmation dialog in `PartnerManagementView`: a "Disconnect" button in `subheadline` + `CadenceDestructive` at the bottom of `PartnerManagementView`; tapping presents a `.confirmationDialog` (not a sheet) with title "Disconnect [partner name]?", message "This will immediately remove their access to your data. This cannot be undone.", "Disconnect" action in `.destructive` role, "Cancel" action in `.cancel` role
- `PartnerConnectionStore.disconnect() async throws`: issues `supabase.from("partner_connections").delete().eq("tracker_id", auth.uid())`; clears all local connection state: `connectionStatus = .none`, `activePermissions = PartnerPermissions()` (all defaults), `pendingConfirmationDetected = false`; after successful deletion, `PartnerManagementView` transitions to show the E1 invite section ("Invite a Partner" CTA)
- Post-disconnect UI transition in `PartnerManagementView`: `connectionStatus == .none` renders the invite section from E1's `InviteCodeView`; the permission toggles section and pause row are hidden; no intermediate "disconnecting..." state (the dialog dismiss is the visual confirmation)
- `project.yml` updated with entries for `PauseSharingToggleRow.swift`; `xcodegen generate` exits 0

### Out of Scope

- Partner client rendering the "Sharing paused" state card -- Phase 9 (the Partner Dashboard picks up `is_paused` via Realtime subscription and renders the paused card; this epic only writes the flag)
- Partner notification on disconnect -- Phase 10 (notification content spec is an open item per Design Spec §15)
- App lock, Face ID / passcode -- Phase 12 Settings
- `CadencePrimary` token confirmation -- External (Dinesh / designer; blocked per MEMORY.md gap note)

## Dependencies

| Dependency                                                          | Type     | Phase/Epic        | Status | Risk                                                                                                                                |
| ------------------------------------------------------------------- | -------- | ----------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `PartnerConnectionStore` with `activePermissions.isPaused` property | FS       | PH-8-E1, PH-8-E3  | Open   | Low -- E3 defines `PartnerPermissions` including `isPaused`                                                                         |
| `PartnerManagementView` with reserved pause section separator       | FS       | PH-8-E3           | Open   | Low                                                                                                                                 |
| Phase 5 `PartnerSharingStripView` component exists                  | FS       | PH-5              | Open   | Low -- strip component must exist for crossfade wire-up                                                                             |
| `CadencePrimary` token confirmed and in xcassets                    | External | Designer / Dinesh | Open   | High -- paused strip cannot use the correct background color until confirmed; `CadencePrimary` is the known spec gap from MEMORY.md |

## Assumptions

- `PartnerManagementView` (E3) conditionally renders either the connection management UI (pause, permissions, disconnect) or the invite UI (E1) based on `PartnerConnectionStore.connectionStatus`. E4 wires the post-disconnect transition between these two states.
- The Phase 5 `PartnerSharingStripView` reads `PartnerConnectionStore` from the environment. If Phase 5 wired the strip to a local `@State` variable or a different store, the wire-up in this epic must be revised.
- Disconnect is synchronous from the Tracker's perspective: the dialog confirms, the row is deleted, the UI transitions to the invite section. No "undo" mechanism.

## Risks

| Risk                                                                                  | Likelihood | Impact                                                                      | Mitigation                                                                                                               |
| ------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `CadencePrimary` token value not confirmed by time E4 is implemented                  | High       | Low (visual only) -- paused strip uses wrong background color               | Use `CadenceTextPrimary` as stand-in with explicit comment; do not block the epic                                        |
| Phase 5 sharing strip not wired to `PartnerConnectionStore` -- different state source | Medium     | Medium -- crossfade animation requires correct state source                 | Inspect Phase 5 `PartnerSharingStripView` source before wiring; if state source differs, refactor the wire-up point here |
| Disconnect fails mid-operation: row delete issued but local state already cleared     | Low        | Medium -- Tracker thinks they disconnected but Partner still has RLS access | Issue Supabase delete first; clear local state only on confirmed success response                                        |

---

## Stories

### S1: PartnerConnectionStore.setPaused + Supabase Write with Optimistic Rollback

**Story ID:** PH-8-E4-S1
**Points:** 3

Implement `PartnerConnectionStore.setPaused(_ paused: Bool) async throws` with optimistic local state, Supabase UPDATE, and rollback on failure. Matching the `setPermission` pattern from E3-S4 exactly (single-column update, `pendingPauseWrite` in-flight guard, toast on failure).

**Acceptance Criteria:**

- [ ] `setPaused(true)` immediately sets `activePermissions.isPaused = true` on `@MainActor`
- [ ] The Supabase UPDATE payload is `["is_paused": true]` -- single column, no other fields
- [ ] On Supabase write failure, `activePermissions.isPaused` reverts to its pre-call value; non-blocking toast appears
- [ ] A `Bool` property `pendingPauseWrite` on the store is `true` while the write is in flight; `PauseSharingToggleRow` disables the toggle while `pendingPauseWrite` is true
- [ ] Unit test: mock successful write produces `activePermissions.isPaused == true` and `pendingPauseWrite == false`
- [ ] Unit test: mock failed write reverts `activePermissions.isPaused == false` and `pendingPauseWrite == false`

**Dependencies:** PH-8-E3-S1 (PartnerPermissions includes `isPaused`)
**Notes:** This method writes `is_paused` only. It does not modify any `share_*` column. Pause is an overlay, not a flag change on individual permissions.

---

### S2: PauseSharingToggleRow Component

**Story ID:** PH-8-E4-S2
**Points:** 2

Implement `PauseSharingToggleRow` and insert it into `PartnerManagementView` at the reserved position from E3-S3.

**Acceptance Criteria:**

- [ ] `PauseSharingToggleRow` renders "Pause sharing" in `body` + `CadenceTextPrimary` leading; "Your partner won't see any data while paused" in `footnote` + `CadenceTextSecondary` below; system `Toggle` trailing
- [ ] Toggle is disabled while `PartnerConnectionStore.pendingPauseWrite == true`
- [ ] Effective touch area is minimum 44 x 44pt
- [ ] `PauseSharingToggleRow` inserted into `PartnerManagementView` immediately after the permission toggles section; the `// E4: PauseSharingToggleRow` comment from E3-S3 is removed
- [ ] `PartnerManagementView` section order after E4: (1) partner status header, (2) SHARING PERMISSIONS section with 6 category rows, (3) Pause sharing toggle, (4) Disconnect button
- [ ] No hardcoded hex colors

**Dependencies:** PH-8-E4-S1, PH-8-E3-S3
**Notes:** `PauseSharingToggleRow` is visually distinct from `PermissionToggleRow` -- it is not inside the permissions `DataCard`. It is a standalone row with 16pt horizontal padding outside the card.

---

### S3: Sharing Status Strip Crossfade Wire-Up

**Story ID:** PH-8-E4-S3
**Points:** 3

Wire `PartnerSharingStripView` (Phase 5 component) to `PartnerConnectionStore.activePermissions.isPaused` and implement the 0.2s easeInOut crossfade between active and paused background colors per Design Spec §10.5 and cadence-motion skill.

**Acceptance Criteria:**

- [ ] `PartnerSharingStripView` reads `PartnerConnectionStore` from `@Environment`
- [ ] When `isPaused == false` (active), strip background is `CadenceSageLight`; text is `subheadline` + `CadenceTextSecondary`; system toggle is on
- [ ] When `isPaused == true` (paused), strip background is the paused token (confirmed `CadencePrimary` or stand-in `CadenceTextPrimary` per the known gap); text is `subheadline` + semibold + inverse primary; system toggle is off
- [ ] Background color transition uses `.animation(.easeInOut(duration: 0.2), value: isPaused)` on the `background` modifier
- [ ] Under `@Environment(\.accessibilityReduceMotion) == true`, background changes instantly (no animation)
- [ ] If `CadencePrimary` token is not yet in xcassets, the stand-in comment `// CadencePrimary unconfirmed -- see Design Spec §7 gap` is present and the token name is not hardcoded as a hex string

**Dependencies:** PH-5 (PartnerSharingStripView must exist), PH-8-E4-S1
**Notes:** Do not add the crossfade to the sharing strip in Phase 5 retroactively -- this story adds the wire-up here. If Phase 5 already includes the animation as a stub, remove the stub and implement the real version with correct state binding.

---

### S4: Disconnect Confirmation Dialog + PartnerConnectionStore.disconnect Mutation

**Story ID:** PH-8-E4-S4
**Points:** 3

Implement the disconnect confirmation dialog in `PartnerManagementView` and `PartnerConnectionStore.disconnect() async throws`. Row deletion must succeed before local state is cleared.

**Acceptance Criteria:**

- [ ] "Disconnect" button at the bottom of `PartnerManagementView` in `subheadline` + `CadenceDestructive` color; minimum 44pt touch target
- [ ] Tapping "Disconnect" presents a `.confirmationDialog` with: title "Disconnect [partner name]?", message "This will immediately remove their access to your data. This cannot be undone.", a "Disconnect" action with `.destructive` role, a "Cancel" action with `.cancel` role
- [ ] Confirming calls `PartnerConnectionStore.disconnect()`
- [ ] `disconnect()` issues `supabase.from("partner_connections").delete().eq("tracker_id", auth.uid())` -- no conditional on `partner_id`; deletes the row regardless of confirmation state
- [ ] Local state is cleared only after the Supabase delete call resolves with success: `connectionStatus = .none`, `activePermissions = PartnerPermissions()`, `pendingConfirmationDetected = false`
- [ ] On Supabase delete failure, local state is NOT cleared; error toast is shown; "Disconnect" button re-enables
- [ ] Unit test: mock successful delete produces `connectionStatus == .none` with all `activePermissions` defaulted to false
- [ ] Unit test: mock failed delete leaves `connectionStatus == .active` unchanged

**Dependencies:** PH-8-E4-S2
**Notes:** "Disconnect" uses `.confirmationDialog`, not `.alert`. `.confirmationDialog` presents as an action sheet on iPhone (iOS 26 native) and is the correct pattern for multi-action destructive flows. Do not use `.sheet` for this.

---

### S5: Post-Disconnect State Reset + Re-Entry to Invite Flow

**Story ID:** PH-8-E4-S5
**Points:** 2

Ensure `PartnerManagementView` transitions correctly from connection management UI to the invite section after a successful disconnect, and that `PartnerConnectionStore` is in a clean state for E1's invite code generation to work.

**Acceptance Criteria:**

- [ ] After successful disconnect, `PartnerManagementView` renders the E1 invite section ("Invite a Partner" CTA) instead of the permission toggles + pause row + disconnect button
- [ ] The transition uses a crossfade or `.animation(.easeInOut(duration: 0.2), value: connectionStatus == .none)` on the view content swap (not an immediate hard cut)
- [ ] After disconnect, calling `PartnerConnectionStore.generateInviteCode()` (E1) succeeds -- no residual state from the previous connection blocks the one-connection guard
- [ ] `PartnerConnectionStore.pendingConfirmationDetected` is false after disconnect
- [ ] `PartnerConnectionStore.pendingWrites` (E3 in-flight set) is empty after disconnect (no lingering write guards from permission toggles)
- [ ] Unit test: post-disconnect store state has `connectionStatus == .none`, all `activePermissions` Bools == false, `pendingWrites.isEmpty == true`

**Dependencies:** PH-8-E4-S4, PH-8-E1-S5
**Notes:** The content swap (connection UI vs. invite UI) is driven by `connectionStatus`. No separate `@State` boolean for which section to show -- derive directly from `connectionStatus`.

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
- [ ] End-to-end verified: Tracker pauses sharing, Partner's next read against `daily_logs` returns zero rows (RLS blocks on `is_paused = true`)
- [ ] End-to-end verified: Tracker disconnects, Partner's next read against any Tracker table returns zero rows (RLS blocks on no `partner_connections` row)
- [ ] End-to-end verified: Tracker reconnects after disconnect via E1 invite code generation -- no state conflicts
- [ ] Phase objective is advanced: Tracker has full lifecycle control over the partner connection
- [ ] Applicable skill constraints satisfied: cadence-privacy-architecture (is_paused as rule 2 in precedence hierarchy, no silent state divergence), cadence-motion (0.2s crossfade, reduced-motion gating), swiftui-production, cadence-design-system (CadenceDestructive for disconnect button, no hardcoded hex), cadence-accessibility (44pt targets)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility: "Disconnect" button has VoiceOver label "Disconnect [partner name], button, destructive"
- [ ] If `CadencePrimary` token gap is unresolved, the stand-in comment is present and blocking item is noted
- [ ] No dead code, stubs, or placeholder comments (except the explicitly sanctioned `CadencePrimary` gap comment if unresolved)
- [ ] Source document alignment verified: pause behavior matches MVP Spec §2 ("suspends all data sharing without disconnecting"); disconnect behavior matches ("immediately revokes all data access")

## Source References

- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (in-scope: pause sharing, disconnect flow)
- MVP Spec §2 (Partner Sharing -- Pause sharing toggle, Disconnect, Connection Flow)
- cadence-privacy-architecture skill §2 (privacy precedence hierarchy -- is_paused is rule 2)
- Design Spec v1.1 §3 (CadenceDestructive for disconnect)
- Design Spec v1.1 §7 (CadencePrimary -- paused strip background token; known gap)
- Design Spec v1.1 §10.5 (Partner Sharing Status Strip -- active and paused states)
- Design Spec v1.1 §11 (Motion -- 0.2s crossfade on sharing paused state change)
- cadence-motion skill (crossfade spec, reduced-motion gating)
