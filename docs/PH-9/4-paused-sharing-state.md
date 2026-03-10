# Paused Sharing State

**Epic ID:** PH-9-E4
**Phase:** 9 -- Partner Navigation Shell & Dashboard
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the paused sharing state: detect `is_paused` changes on the partner_connections Realtime channel, render the "Sharing paused" card UI using the Data Card Insight variant, and execute the 0.25s easeInOut crossfade between Bento content and the paused state -- with full reduced-motion gating and unit-tested state transitions.

## Problem / Context

The pause sharing toggle (Phase 8) gives the Tracker the ability to suspend all data sharing without disconnecting the relationship. When paused, the Partner must immediately see a neutral, non-alarming state rather than stale cycle data. The 0.25s easeInOut crossfade from Design Spec §11 prevents a jarring cut between the Bento grid and the paused card. The reduced-motion gate is mandatory -- the instant swap under accessibilityReduceMotion must be implemented, not assumed. Critically, `is_paused` changes arrive via the partner_connections Realtime channel, not the daily_logs channel, so this epic requires subscribing to a second channel beyond what PH-9-E3 established.

This state is a product requirement, not an edge case. The Tracker may pause sharing frequently (e.g., before a medical appointment, during a personal phase). The Partner must see this as a deliberate, respectful state -- not a broken app.

Source authority: Design Spec v1.1 §11 (Partner Dashboard hide: 0.25s easeInOut), §12.5 (paused state card spec), §10.4 (Data Card Insight variant -- CadenceSageLight background); MVP Spec §2 (pause sharing -- Partner sees "Sharing paused", no explanation required); cadence-motion skill.

## Scope

### In Scope

- partner_connections Realtime subscription in PartnerDashboardViewModel: subscribe to Postgres Changes on the specific partner_connections row (filtered by connection ID, not a full table subscription); observe is_paused field changes; transition ViewModel.viewState to .paused when is_paused becomes true
- Resume transition: when is_paused changes from true to false, transition ViewModel.viewState from .paused to .loading, then trigger PartnerDataService.fetchCurrentSnapshot() to reload fresh data, then transition to .loaded or .empty
- Paused state card UI: single full-width Data Card using the Insight variant (CadenceSageLight background per §10.4 Insight variant); SF Symbol `pause.circle` in CadenceSage; "Sharing paused" label in headline style, CadenceTextPrimary; no secondary explanatory text; no interactive elements
- Bento grid swap: when ViewModel.viewState == .paused, the 4 Bento cards are replaced by the paused state card; when ViewModel.viewState transitions away from .paused, the paused card is replaced by skeleton placeholders (while refetching) then Bento grid
- 0.25s easeInOut crossfade: `.animation(.easeInOut(duration: 0.25), value: viewState)` on the conditional view swap between Bento grid and paused card; crossfade is implemented via `.transition(.opacity)` on both the Bento grid group and the paused card
- Reduced motion gate: @Environment(\.accessibilityReduceMotion) read; when reduceMotion is true, nil animation is applied -- instant view swap with no crossfade
- Unit tests: given is_paused=true arrives via Realtime, ViewModel transitions to .paused; given is_paused=false after .paused, ViewModel transitions to .loading then completes to .loaded or .empty

### Out of Scope

- The pause sharing toggle UI on the Tracker side (Phase 8)
- The Partner Sharing Status Strip on the Tracker Home Dashboard (Phase 5/8)
- Any user-facing explanation of why sharing is paused (the spec states no explanation is required from the Tracker; the Partner sees a state only)
- Disconnection handling for the partner_connections channel (follows the same error retention pattern as PH-9-E3-S6; no additional error state is introduced)
- Multiple paused state variants (there is one paused state; no "paused by partner" vs "disconnected" distinction in the spec)

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| PartnerDashboardViewModel .paused state defined in BentoViewState enum | FS | PH-9-E2 | Unresolved (same phase) | Low |
| Realtime channel for daily_logs subscription lifecycle established | FS | PH-9-E3 | Unresolved (same phase) | Low |
| partner_connections table with is_paused column live in Supabase | FS | PH-8 | Resolved | Low |
| Pause sharing toggle writes is_paused=true to partner_connections row on toggle | FS | PH-8 | Resolved | Low |
| CadenceSageLight and CadenceSage color assets in xcassets | FS | PH-0 | Resolved | Low |

## Assumptions

- The partner_connections Realtime subscription uses a Postgres Changes filter of `eq("id", partner_connection_id)` to subscribe to a single row, not a full-table subscription; this avoids receiving other users' connection events
- The `pause.circle` SF Symbol is the correct iconography for the paused state card -- Design Spec §12.5 specifies "CadenceSage iconography" without naming the exact symbol; `pause.circle` is the most semantically accurate available symbol; flag for designer review before the Phase 13 accessibility audit
- The CadenceSageLight background for the paused card uses the Data Card Insight variant as specified in §10.4 -- no new color token or custom background is introduced
- Transitioning from .paused back to .loaded requires a re-fetch (not a cached snapshot) because the Tracker may have logged new data or changed permissions during the paused interval

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| SF Symbol for paused state iconography is incorrect per design intent | Medium | Low | Use pause.circle as the best available match; document in Notes card as pending designer confirmation; Phase 13 accessibility audit catches any final corrections |
| Race condition: is_paused=false Realtime event arrives before re-fetch completes, causing .loading flash | Low | Low | The .loading state with skeleton placeholders is a valid intermediate state; the skeleton from PH-9-E2-S7 covers this window acceptably |
| partner_connections Realtime subscription not established in Phase 7 SyncCoordinator (only daily_logs was established) | Medium | High | Read SyncCoordinator.swift to confirm whether partner_connections channel exists; if absent, create the subscription in this epic within PartnerDashboardViewModel (not in SyncCoordinator, which is Tracker-scoped) |

---

## Stories

### S1: partner_connections Realtime subscription for is_paused

**Story ID:** PH-9-E4-S1
**Points:** 3

Subscribe PartnerDashboardViewModel to the partner_connections Postgres Changes channel, filtered to the active connection row. On receiving a row update, read the is_paused value and transition ViewModel state accordingly.

**Acceptance Criteria:**

- [ ] PartnerDashboardViewModel subscribes to Postgres Changes on the partner_connections table, filtered by `eq("id", partnerConnectionId)`, on PartnerDashboardView.onAppear
- [ ] On receiving an UPDATE event where is_paused = true, ViewModel.viewState transitions to .paused
- [ ] On receiving an UPDATE event where is_paused = false while ViewModel.viewState == .paused, ViewModel.viewState transitions to .loading and PartnerDataService.fetchCurrentSnapshot() is called to reload data
- [ ] The partner_connections subscription lifecycle mirrors the daily_logs subscription: subscribe on .onAppear, unsubscribe on .onDisappear
- [ ] No retain cycles exist in the Realtime callback closure
- [ ] The subscription executes its callback on the main actor (ViewModel state mutation is main-actor-safe)

**Dependencies:** PH-9-E3-S2
**Notes:** Read SyncCoordinator.swift before implementing. If partner_connections Realtime subscription is not present in Phase 7, create it within PartnerDashboardViewModel directly -- do not add it to SyncCoordinator, which manages Tracker writes.

---

### S2: Paused state card UI

**Story ID:** PH-9-E4-S2
**Points:** 3

Implement PausedSharingCardView as a full-width Data Card using the Insight variant (CadenceSageLight background). Display `pause.circle` SF Symbol in CadenceSage and "Sharing paused" headline. No interactive elements.

**Acceptance Criteria:**

- [ ] PausedSharingCardView is a full-width Data Card with CadenceSageLight fill background (Insight variant per §10.4)
- [ ] Border is 1pt inner stroke at CadenceBorder; corner radius 16pt; internal padding 20pt uniform; no external drop shadow -- identical to standard Data Card spec
- [ ] SF Symbol `pause.circle` renders in CadenceSage, at image scale .large, centered above the label
- [ ] "Sharing paused" label renders in headline style, CadenceTextPrimary, centered below the icon
- [ ] No secondary text, explanatory copy, or action button is present on the card
- [ ] PausedSharingCardView contains no tap gesture or interactive modifier
- [ ] VoiceOver accessibilityLabel on the card is "Sharing paused" (the card as a whole; no sub-element labels required beyond the card label)
- [ ] No hardcoded hex color values appear in PausedSharingCardView

**Dependencies:** PH-9-E4-S1

---

### S3: 0.25s easeInOut crossfade animation

**Story ID:** PH-9-E4-S3
**Points:** 3

Implement the crossfade between the Bento grid view group and PausedSharingCardView. The transition uses `.transition(.opacity)` on both branches, driven by `.animation(.easeInOut(duration: 0.25), value: viewState)`. Reduced motion must produce an instant swap.

**Acceptance Criteria:**

- [ ] When ViewModel.viewState transitions to .paused, the Bento grid fades out and PausedSharingCardView fades in over 0.25s with easeInOut timing
- [ ] When ViewModel.viewState transitions from .paused to .loading (resume), PausedSharingCardView fades out and the skeleton loading placeholders fade in over 0.25s with easeInOut timing
- [ ] The crossfade uses `.transition(.opacity)` on the conditional branch views wrapped with `.animation(.easeInOut(duration: 0.25), value: viewState)`
- [ ] @Environment(\.accessibilityReduceMotion) is read; when reduceMotion is true, `.animation(nil, value: viewState)` is applied -- the swap is instantaneous with no opacity transition
- [ ] No layout shift occurs during the crossfade (the Bento grid and paused card occupy the same frame; one fades out as the other fades in using ZStack or if/else with matched geometry)
- [ ] The animation duration matches §11 exactly: 0.25s (not 0.2s, which is the sharing strip duration on the Tracker Home)

**Dependencies:** PH-9-E4-S2
**Notes:** The sharing strip (§11: 0.2s) and the Partner Dashboard hide (§11: 0.25s) are different durations. Use 0.25s here. Do not conflate them.

---

### S4: Unit tests for paused state transitions

**Story ID:** PH-9-E4-S4
**Points:** 2

Write unit tests verifying PartnerDashboardViewModel state machine transitions for the paused path. Tests use a mock Realtime event source and mock PartnerDataService.

**Acceptance Criteria:**

- [ ] Test: given ViewModel.viewState == .loaded(snapshot) and a simulated Realtime UPDATE with is_paused=true, ViewModel.viewState transitions to .paused
- [ ] Test: given ViewModel.viewState == .paused and a simulated Realtime UPDATE with is_paused=false, ViewModel.viewState transitions to .loading then to .loaded (mock PartnerDataService returns a fixture snapshot)
- [ ] Test: given ViewModel.viewState == .paused and a simulated Realtime UPDATE with is_paused=false, ViewModel.viewState transitions to .loading then to .empty (mock PartnerDataService returns nil)
- [ ] Test: given ViewModel.viewState == .empty and a simulated Realtime UPDATE with is_paused=true, ViewModel.viewState transitions to .paused
- [ ] All tests use a mock PartnerDataService and mock Realtime event source -- no live Supabase connection
- [ ] All tests pass without async sleep-based synchronization (use async/await with controlled task completion)

**Dependencies:** PH-9-E4-S1
**Notes:** PartnerDashboardViewModel must be dependency-injectable for the mock PartnerDataService to be substitutable. Verify this is true from PH-9-E2 before writing tests.

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
- [ ] Integration verified end-to-end: toggling is_paused=true on the Tracker side causes the Partner Dashboard to crossfade to the paused card within 2 Realtime update cycles; toggling back restores the Bento grid
- [ ] Phase objective fully satisfied: a Partner can open the app, see live cycle data (or a respectful paused state), and navigate the 3-tab shell
- [ ] cadence-motion skill constraints satisfied: 0.25s easeInOut crossfade implemented exactly per §11; instant swap under reduceMotion; no unapproved animation duration used
- [ ] cadence-design-system skill constraints satisfied: CadenceSageLight and CadenceSage used via Color("CadenceToken") -- no hardcoded hex values in PausedSharingCardView
- [ ] cadence-accessibility skill constraints satisfied: reduced motion gating on crossfade; VoiceOver accessibilityLabel on paused card
- [ ] cadence-testing skill constraints satisfied: all state transition tests pass; mock PartnerDataService injected; no live network in tests; no sleep-based synchronization
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Crossfade animation verified at 0.25s on device/simulator (use Xcode animation inspector or slow animations flag to confirm duration)
- [ ] Instant swap under reduceMotion verified in simulator with "Reduce Motion" enabled
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: paused card surface (Insight variant), crossfade duration (0.25s), and no explanatory text match Design Spec §10.4, §11, and §12.5 exactly

## Source References

- PHASES.md: Phase 9 -- Partner Navigation Shell & Dashboard (in-scope item 4: paused state, 0.25s crossfade)
- Design Spec v1.1 §10.4 (Data Card -- Insight variant: CadenceSageLight background)
- Design Spec v1.1 §11 (Motion & Interaction -- Partner Dashboard hide: cards crossfade to paused state, 0.25s easeInOut)
- Design Spec v1.1 §12.5 (Partner Home Dashboard -- paused state: CadenceSageLight card with CadenceSage iconography)
- MVP Spec §2 (Partner Sharing -- pause sharing: Partner sees "Sharing paused", no explanation required)
- cadence-motion skill (0.25s easeInOut crossfade spec, reduced motion gating rule)
- cadence-design-system skill (CadenceSageLight, CadenceSage tokens, Data Card Insight variant)
- cadence-accessibility skill (reduced motion instant swap, VoiceOver label)
- cadence-testing skill (state machine unit tests, DI, mock service pattern)
