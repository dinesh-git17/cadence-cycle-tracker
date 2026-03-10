# Partner Onboarding

**Epic ID:** PH-2-E5
**Phase:** 2 -- Authentication & Onboarding
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement the Partner onboarding code-entry screen that accepts a 6-digit invite code, validates it against the `partner_connections` table in Supabase, and routes the user to the Partner shell stub on success. This screen is the Phase 2 boundary for Partner onboarding -- the full connection handshake, confirmation screen, and permission write are Phase 8. Phase 2 delivers a valid, testable code-entry UI that proves the Partner routing path end-to-end.

## Problem / Context

A Partner who opens the app cannot proceed beyond role selection without a valid invite code. Without this epic, the Partner onboarding path is a dead end: the AppCoordinator routes to `.partnerOnboarding` but there is no view there. The code-entry screen and its Supabase validation call are the minimum viable gate that confirms a code is real and unexpired before the user is granted access to the Partner shell.

The Phase 2 code validation is intentionally read-only (a lookup, not a write). It confirms the code exists in `partner_connections` where `partner_id IS NULL` (not yet consumed) and where `created_at` is within the 24-hour expiry window. The actual `partner_id` write and full connection handshake are Phase 8 work. This split means Phase 2 can be built and tested independently of Phase 8's connection architecture.

Source authority: MVP Spec §2 (Partner Sharing -- Connection Flow, invite code mechanics), MVP Spec User Flow 2, PHASES.md Phase 2 (in-scope: invite code entry screen + code validation) and Phase 8 (out-of-scope: full connection handshake).

## Scope

### In Scope

- `PartnerOnboardingView.swift` -- code entry screen with text field, CTA, and error/confirmation states
- `PartnerOnboardingViewModel.swift` -- @Observable class owning input state, Supabase validation call, and routing signal
- 6-digit invite code input: single `TextField` with `.numberPad` keyboard, 6-character input limit, CTA disabled until exactly 6 digits are entered
- Paste handling: if a 6-digit numeric string is pasted, it is accepted and the CTA is enabled
- Invite code validation: query `partner_connections` where `invite_code = input AND partner_id IS NULL AND created_at > now() - interval '24 hours'`; the query is a read-only `select` -- no writes in this epic
- Validated invite code stored in `PartnerOnboardingViewModel` (and/or passed to AppCoordinator) for Phase 8 to consume during the connection handshake
- Loading state on CTA during validation query
- Three distinct error states: code not found, code expired (> 24 hours old), code already used (`partner_id IS NOT NULL`)
- Success state: route to `.partnerShell` stub via AppCoordinator
- `project.yml` additions for two new Swift files

### Out of Scope

- Full partner connection handshake (writing `partner_id` and `connected_at` to `partner_connections`) -- Phase 8
- Confirmation screen ("Dinesh will be able to see: ...") -- Phase 8 (Phase 8 Notes explicitly: "full connection handshake, confirmation screen, and permission management")
- Permission category review or any read of `share_*` columns -- Phase 8
- Invite code generation (Tracker side, in Settings) -- Phase 8
- Re-entry of an invite code after connection is established -- not applicable; Phase 8 handles the one-time handshake

## Dependencies

| Dependency                                                                                                 | Type | Phase/Epic | Status | Risk   |
| ---------------------------------------------------------------------------------------------------------- | ---- | ---------- | ------ | ------ |
| `AppCoordinator` routing to `.partnerOnboarding` and `.partnerShell`                                       | FS   | PH-2-E3    | Open   | Low    |
| Authenticated Supabase session                                                                             | FS   | PH-2-E2    | Open   | Low    |
| `partner_connections` table schema with `invite_code`, `partner_id`, `created_at` columns                  | FS   | PH-1       | Open   | Medium |
| RLS policy on `partner_connections` allowing an authenticated non-owner user to read rows by `invite_code` | FS   | PH-1       | Open   | High   |

## Assumptions

- The `partner_connections` table uses Supabase's auto-generated `created_at timestamptz` column as the invite code creation timestamp. The 24-hour expiry is computed as `created_at > now() - interval '24 hours'` in the Supabase query or as a client-side date comparison after fetching the row.
- The RLS policy on `partner_connections` allows any authenticated user to SELECT rows by matching `invite_code`. Without this policy, the validation query will return 0 rows for all inputs regardless of whether the code exists. This is a Phase 1 deliverable risk (High) that must be verified before PH-2-E5 testing.
- A validated invite code is stored in the PartnerOnboardingViewModel (in memory) after successful validation. The AppCoordinator may hold a reference to the validated code string for Phase 8 to retrieve during the handshake. No local persistence of the code beyond the in-memory session is required.
- The Partner enters only the code -- no Tracker name, no permissions review in Phase 2. The phase ends after routing to the Partner shell stub.
- The Partner shell stub presented after code validation is the same `.partnerShell` stub case used for returning Partners. The distinction between "newly validated" and "already connected" Partner routing is a Phase 8 concern.
- The invite code entry screen is a single screen with no back button. A Partner without a valid code cannot proceed. This is by design (MVP Spec §1: "A Partner without a connection code cannot proceed past onboarding").

## Risks

| Risk                                                                                                     | Likelihood | Impact | Mitigation                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 1 RLS on `partner_connections` does not permit the SELECT by invite_code (most likely Phase 1 gap) | High       | High   | Confirm the RLS policy explicitly with the backend engineer before starting S3. If the policy is absent, the validation query will silently return 0 rows and all codes will appear invalid. |
| Invite code in the table uses a different column name than assumed (`invite_code` vs. `code` or similar) | Low        | Medium | Verify column name against Phase 1 migration before coding S3                                                                                                                                |
| Code validation query timing out on slow connection gives a confusing experience                         | Low        | Low    | Set a 10-second timeout on the Supabase query; show a specific "Taking too long -- check your connection" error on timeout                                                                   |
| Partner enters a valid code but the Tracker disconnects between validation and Phase 8 handshake         | Low        | Medium | Phase 2 concern is validation only -- Phase 8 handles the stale-code edge case during the write                                                                                              |

---

## Stories

### S1: Partner onboarding screen layout

**Story ID:** PH-2-E5-S1
**Points:** 3

Implement `PartnerOnboardingView` with the invite code text field, explanatory copy, Continue CTA, and the three distinct error message containers. The error containers are present but hidden (zero opacity or conditional) in this story -- they will be shown/hidden in S4. No Supabase calls.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Onboarding/PartnerOnboardingView.swift` and `Cadence/ViewModels/PartnerOnboardingViewModel.swift` exist and compile clean
- [ ] Screen title "Enter your invite code" in `.title2` (22pt regular) `CadenceTextPrimary`, horizontally centered
- [ ] Explanatory copy "Your partner shared a 6-digit code with you. Enter it below to connect." in `.subheadline`, `CadenceTextSecondary`, centered, below the title
- [ ] Invite code `TextField` with placeholder "000000" in `CadenceTextSecondary`, `.body` input text in `CadenceTextPrimary`, `CadenceCard` fill, 1pt `CadenceBorder`, 10pt corner radius
- [ ] Code field is at least 44pt tall (minimum touch target)
- [ ] "Continue" Primary CTA button: `CadenceTerracotta`, 50pt height, 14pt corner radius, full container width with 16pt horizontal inset
- [ ] Error message area below the CTA is present in the layout (sized for one line of `.footnote` text with `warning.fill` icon); when no error is active, this area is hidden with `.hidden()` and does not shift layout
- [ ] 16pt horizontal screen margins; 24pt vertical spacing between major layout sections
- [ ] No navigation bar back button -- this screen has no escape route
- [ ] `project.yml` updated with both Swift files

**Dependencies:** PH-2-E3-S1 (AppCoordinator routes to this view)
**Notes:** The layout reserves space for error messages to prevent layout shift when errors appear. Use `ViewThatFits` or a fixed-height container for the error area if needed.

---

### S2: 6-digit numeric input enforcement

**Story ID:** PH-2-E5-S2
**Points:** 2

Constrain the invite code text field to accept exactly 6 numeric digits. Enforce this via `.onChange` on the field value. Handle paste: if a pasted string is 6+ characters, truncate to the first 6 numeric characters. The Continue CTA is enabled only when exactly 6 digits are present.

**Acceptance Criteria:**

- [ ] `TextField` has `.keyboardType(.numberPad)` set
- [ ] Input is capped at 6 characters via an `.onChange` binding that strips non-numeric characters and truncates at length 6
- [ ] Pasting a 7-digit string truncates to the first 6 digits; pasting "ABC123" retains "123" and pads nothing (user must complete remaining digits manually)
- [ ] Pasting a valid 6-digit string (e.g., "482901") sets the field to "482901" and enables the Continue CTA
- [ ] Continue CTA `isDisabled` binding is `true` when `code.count != 6`
- [ ] The field does not accept spaces, letters, or special characters at any point during typing
- [ ] Input is trimmed of any leading/trailing whitespace on binding update

**Dependencies:** PH-2-E5-S1
**Notes:** Use a computed binding or `.onChange` modifier to enforce constraints rather than a custom `UITextField` wrapper. Avoid UIKit in this implementation per Design Spec §2 (SwiftUI throughout).

---

### S3: Invite code validation against Supabase

**Story ID:** PH-2-E5-S3
**Points:** 5

Wire the Continue CTA to a Supabase `partner_connections` SELECT query in `PartnerOnboardingViewModel`. The query checks that the code exists, is unclaimed (`partner_id IS NULL`), and is within the 24-hour expiry window. Return a typed result enum (`CodeValidationResult`) to the view layer. Store the validated code in the ViewModel for Phase 8 handshake consumption.

**Acceptance Criteria:**

- [ ] Tapping Continue dispatches a `Task` in `PartnerOnboardingViewModel` that calls `supabase.from("partner_connections").select("id, invite_code, created_at, partner_id").eq("invite_code", value: code).limit(1).execute()`
- [ ] Continue CTA shows inline `ProgressView` and is disabled during the query (Design Spec §10.3 loading state)
- [ ] `CodeValidationResult` enum contains cases: `.valid(connectionId: UUID)`, `.notFound`, `.expired`, `.alreadyUsed`
- [ ] If the query returns 0 rows: result is `.notFound`
- [ ] If the query returns 1 row and `partner_id` is non-null: result is `.alreadyUsed`
- [ ] If the query returns 1 row, `partner_id` is null, and `created_at` is more than 24 hours ago: result is `.expired`
- [ ] If the query returns 1 row, `partner_id` is null, and `created_at` is within 24 hours: result is `.valid(connectionId:)` with the connection UUID
- [ ] On `.valid`, the connection ID is stored in `PartnerOnboardingViewModel.validatedConnectionId: UUID?` and the AppCoordinator is signaled to route to `.partnerShell`
- [ ] The query has a 10-second timeout; if exceeded, a `.networkError` case is returned
- [ ] `PartnerOnboardingViewModel` is injectable for testing (the Supabase query is behind a protocol or closure)

**Dependencies:** PH-2-E5-S2 (6-digit input gating), PH-2-E3 (AppCoordinator for routing), Phase 1 (partner_connections table + RLS SELECT policy)
**Notes:** The 24-hour expiry check is performed on the client side after fetching the row -- compare `row.created_at` to `Date.now - 86400 seconds`. This avoids requiring a Postgres function. If Phase 1 adds a generated `expires_at` column, the query filter can be simplified.

---

### S4: Error state rendering and success routing

**Story ID:** PH-2-E5-S4
**Points:** 3

Wire `CodeValidationResult` from S3 to the visible error states in the view. Show the correct message for each non-valid case. On `.valid`, trigger the AppCoordinator route transition to `.partnerShell`. Verify all three error states are visually correct and match the Design Spec §13 error pattern.

**Acceptance Criteria:**

- [ ] On `.notFound`: error area shows "Code not found. Check the code and try again." in `.footnote` `CadenceTextSecondary` with `warning.fill` SF Symbol; the code field is cleared for re-entry
- [ ] On `.expired`: error area shows "This code has expired. Ask your partner for a new one." in `.footnote` `CadenceTextSecondary` with `warning.fill` SF Symbol
- [ ] On `.alreadyUsed`: error area shows "This code has already been used." in `.footnote` `CadenceTextSecondary` with `warning.fill` SF Symbol
- [ ] On `.networkError` (timeout): error area shows "Could not connect. Check your network and try again." in `.footnote` `CadenceTextSecondary` with `warning.fill` SF Symbol
- [ ] Error messages use no red color (`CadenceDestructive` / `.red`) -- the Design Spec §13 error pattern is non-destructive
- [ ] Error messages appear without layout shift (the error area container from S1 is shown/hidden via opacity, not inserted/removed)
- [ ] On `.valid`, the AppCoordinator routes to `.partnerShell` via `coordinator.currentRoute = .partnerShell` with the 0.3s crossfade from PH-2-E3-S4
- [ ] The error area is hidden (not just empty) when the user starts re-entering a code after an error
- [ ] All error message strings are defined as constants (not inline string literals) to support future localization

**Dependencies:** PH-2-E5-S3
**Notes:** The cleared code field on `.notFound` provides a natural retry affordance. On `.expired` and `.alreadyUsed`, the field is not cleared -- the user may want to inspect or copy the code before contacting their partner.

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
- [ ] End-to-end verified: a Partner user enters a valid 6-digit code generated by a seeded `partner_connections` row in Supabase and routes to the `.partnerShell` stub
- [ ] All three error cases (not found, expired, already used) verified against real Supabase data in the development environment
- [ ] Phase objective is advanced: the Partner routing path from onboarding to shell stub is complete and testable
- [ ] Applicable skill constraints satisfied: `swiftui-production` (@Observable ViewModel, no force unwraps, no AnyView), `cadence-design-system` (all tokens, error pattern from §13), `cadence-xcode-project` (project.yml additions), `cadence-supabase` (typed Codable result, RLS-aligned SELECT query, no over-exposure of partner_connections columns), `cadence-testing` (ViewModel injectable for unit tests without live Supabase), `cadence-privacy-architecture` (read-only validation -- no partner data exposed in this query beyond the connection ID needed for Phase 8)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No dead code or placeholder comments
- [ ] Source document alignment verified: Phase 2 boundary is code-entry + validation only; no handshake or permission data is read

## Source References

- MVP Spec §2 (Partner Sharing -- Connection Flow, invite code, 24-hour expiry)
- MVP Spec User Flow 2 (Partner Onboarding sequence -- steps 1-5, Phase 2 covers steps 1-4 only; step 5 confirmation screen is Phase 8)
- MVP PRD v1.0 Data Model (partner_connections table: id, tracker_id, partner_id, invite_code, connected_at)
- Design Spec v1.1 §12.1 (input field visual style reference -- CadenceCard fill, 10pt corner radius)
- Design Spec v1.1 §13 (error state -- warning.fill, no CadenceDestructive)
- Design Spec v1.1 §10.3 (Primary CTA Button -- loading state, disabled opacity)
- PHASES.md: Phase 2 -- Authentication & Onboarding (In-Scope item 9)
- PHASES.md: Phase 8 -- Partner Connection & Privacy Architecture (boundary: full handshake is Phase 8, not Phase 2)
