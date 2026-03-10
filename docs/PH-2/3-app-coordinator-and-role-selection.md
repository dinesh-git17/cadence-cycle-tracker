# App Coordinator and Role Selection

**Epic ID:** PH-2-E3
**Phase:** 2 -- Authentication & Onboarding
**Estimated Size:** S
**Status:** Draft

---

## Objective

Implement the `AppCoordinator` @Observable class and `RoleSelectionView` that collectively own the entire pre-shell routing state machine: splash -> auth -> role selection -> onboarding -> main shell stub. After Phase 2, every user path from cold launch to a shell stub is driven by this coordinator without any direct navigation in child views. Session persistence is checked at launch so returning authenticated users bypass splash and auth.

## Problem / Context

SwiftUI applications with multi-phase onboarding flows require a single root-level coordinator that owns app-wide routing state. Without this epic, the splash callback, auth session state, and onboarding completions have nowhere to route. Every subsequent phase (PH-2-E4, PH-2-E5, Phase 4, Phase 9) depends on the `AppCoordinator` being in place to accept navigation signals from child views.

Design Spec §8 defines role-based IA (5-tab Tracker, 3-tab Partner). The role selection screen is the gate between authentication and the correct onboarding path. Setting the wrong role or failing to persist it corrupts every downstream routing decision.

Source authority: PHASES.md Phase 2 intent ("Splash -> auth -> role selection -> role-appropriate onboarding -> landing in the correct main shell stub"), Design Spec §8 (IA), MVP Spec §1 (onboarding and role selection).

## Scope

### In Scope

- `AppCoordinator.swift` -- `@Observable` class with `AppRoute` enum covering all Phase 2 routes
- `AppRoute` enum cases: `.splash`, `.auth`, `.roleSelection`, `.trackerOnboarding`, `.partnerOnboarding`, `.trackerShell`, `.partnerShell`
- Root `ContentView.swift` (or `@main App` body) -- `switch` on `AppCoordinator.currentRoute` to present the correct view
- Session persistence check at cold launch: if `supabase.auth.session` returns a non-nil session and the `users` table has a `role` set, route directly to `.trackerShell` or `.partnerShell` without presenting splash
- `RoleSelectionView.swift` -- two-option screen (Tracker / Partner), upserts the `users` row with the selected role, signals the coordinator
- Public `users` table row upsert on role selection (sets `id`, `role`, `timezone`)
- Crossfade transitions: splash-to-auth uses `0.3s easeInOut` opacity transition per Splash Spec; all other route transitions use the same 0.3s crossfade for visual consistency
- Stub views for `.trackerShell` and `.partnerShell` that display a minimal placeholder (role name + "-- shell coming in Phase 4/9") to verify routing is correct
- `project.yml` additions for all new source files

### Out of Scope

- Full Tracker 5-tab shell (Phase 4)
- Full Partner 3-tab shell (Phase 9)
- Deep link dispatch (Phase 4, post-shell)
- Sign-out routing (the session-cleared path routes back to `.auth` via the auth state listener -- the mechanism is implemented here, but sign-out action lives in Settings, Phase 12)
- Push notification routing (Phase 10)

## Dependencies

| Dependency                                                          | Type | Phase/Epic | Status   | Risk   |
| ------------------------------------------------------------------- | ---- | ---------- | -------- | ------ |
| `SplashView` with `onComplete` callback                             | FS   | PH-2-E1    | Open     | Low    |
| `AuthView` and auth state listener (`AuthState` observable)         | FS   | PH-2-E2    | Open     | Low    |
| `SupabaseClient` singleton and `supabase.auth.session` availability | FS   | PH-2-E2-S5 | Open     | Low    |
| Public `users` table schema (id, role, timezone columns)            | FS   | PH-1       | Open     | Medium |
| Buildable project with Phase 0 color assets                         | FS   | PH-0       | Resolved | Low    |

## Assumptions

- No database trigger auto-populates `public.users` from `auth.users` in Phase 1. The iOS app performs an upsert to `public.users` on role selection. If Phase 1 adds a trigger, the upsert becomes an update -- behavior is identical, the trigger just pre-creates the row.
- `AppRoute.trackerShell` and `AppRoute.partnerShell` in Phase 2 are stub views. They are replaced (not removed) when Phase 4 and Phase 9 implement the real shells. The `AppRoute` enum and `ContentView` switch remain the correct home for these cases.
- Session persistence check reads `supabase.auth.session` synchronously on cold launch. If the session is expired and cannot be refreshed, the coordinator routes to `.auth`.
- Role is stored in `public.users.role`. The AppCoordinator determines which shell to show by reading `public.users` after authentication, not by caching the role locally in `UserDefaults`. This prevents stale role state after sign-out.
- The `users.role` enum values are `tracker` and `partner` (string-typed in Postgres; mapped to a Swift `UserRole` enum in the iOS client).

## Risks

| Risk                                                                                               | Likelihood | Impact | Mitigation                                                                                                       |
| -------------------------------------------------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------- |
| Session check on cold launch blocks the main thread while querying Supabase                        | Low        | High   | Perform session check in a `Task` on app launch; display splash (or a blank background) until the check resolves |
| `public.users` row not found after authentication (Phase 1 schema issue or RLS policy gap)         | Medium     | Medium | On nil row result after auth, route to role selection regardless -- treat missing row as first-time user         |
| AppCoordinator retain cycle in closures passed to child views                                      | Low        | Medium | Child views receive `AppCoordinator` as a binding or via environment; closures capture `[weak coordinator]`      |
| Transition crossfades cause layout artifacts if views are not fully loaded before opacity animates | Low        | Low    | Verify on simulator with animation inspector; use `.transition(.opacity)` consistently                           |

---

## Stories

### S1: AppCoordinator state machine and root view

**Story ID:** PH-2-E3-S1
**Points:** 5

Implement the `AppCoordinator` @Observable class with the `AppRoute` enum and the root `ContentView` that switches views based on `coordinator.currentRoute`. Wire `AppCoordinator` into the SwiftUI environment from the `@main` App struct. This story includes the session check at cold launch that determines the initial route.

**Acceptance Criteria:**

- [ ] `Cadence/App/AppCoordinator.swift` exists containing `@Observable final class AppCoordinator`
- [ ] `AppRoute` enum is defined with cases: `.splash`, `.auth`, `.roleSelection`, `.trackerOnboarding`, `.partnerOnboarding`, `.trackerShell`, `.partnerShell`
- [ ] `AppCoordinator.currentRoute: AppRoute` is the single source of truth for all navigation state; no child view sets the route directly
- [ ] `ContentView` contains a `switch coordinator.currentRoute` that maps each case to the correct view; no `if`/`else if` chains
- [ ] On cold launch with no session: initial route is `.splash`
- [ ] On cold launch with a valid existing session AND a `public.users` row with a non-nil role: initial route is `.trackerShell` or `.partnerShell` based on stored role (splash is skipped)
- [ ] On cold launch with a valid session but no `public.users` row (first-time user who authenticated on a previous launch but did not complete onboarding): initial route is `.roleSelection`
- [ ] The session check runs in a `Task` on app launch; a blank `CadenceBackground` screen is shown for the duration of the async check (no flash of the wrong view)
- [ ] `AppCoordinator` is injected into the SwiftUI environment as `@Environment(AppCoordinator.self)` in the `@main` App struct
- [ ] `project.yml` includes `Cadence/App/AppCoordinator.swift`

**Dependencies:** PH-2-E2-S5 (SupabaseClient singleton)
**Notes:** The `AppCoordinator` must not hold strong references to child ViewModels. Child ViewModels are created by the views that need them, with the coordinator passed in for route-change signaling via a closure or method call.

---

### S2: Role selection screen and users row upsert

**Story ID:** PH-2-E3-S2
**Points:** 3

Implement `RoleSelectionView` with two option buttons (Tracker / Partner). On selection, upsert the `public.users` row with the authenticated user's id, selected role, and device timezone. Signal the `AppCoordinator` to route to the correct onboarding path.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Onboarding/RoleSelectionView.swift` exists and compiles clean
- [ ] Screen has two options: "I track my cycle" (Tracker) and "My partner tracks their cycle" (Partner), styled as Primary CTA Buttons per Design Spec §10.3 (CadenceTerracotta fill for the selected option, CadenceCard fill for the unselected option)
- [ ] Both buttons are 50pt height, 14pt corner radius, full container width with 16pt horizontal inset
- [ ] Tapping a button triggers a `supabase.from("users").upsert(...)` call with `id: session.user.id`, `role: selectedRole`, `timezone: TimeZone.current.identifier`
- [ ] While the upsert is in-flight, both buttons display an inline `ProgressView` on the tapped button and disable both (prevents double-tap)
- [ ] On successful upsert, `AppCoordinator.currentRoute` is set to `.trackerOnboarding` (Tracker) or `.partnerOnboarding` (Partner)
- [ ] On upsert failure, an inline error message appears below both buttons using the non-destructive error pattern (`.footnote`, `CadenceTextSecondary`, `warning.fill` SF Symbol)
- [ ] No navigation bar, no back button -- this view has no escape route; the only path forward is role selection
- [ ] `project.yml` updated with `Cadence/Views/Onboarding/RoleSelectionView.swift`

**Dependencies:** PH-2-E3-S1 (AppCoordinator routing), PH-2-E2-S5 (SupabaseClient), Phase 1 (users table + RLS allowing insert for authenticated user)
**Notes:** The `users` row upsert uses `onConflict: "id"` to handle the case where a row already exists (returning user re-selecting a role). The `role` column update is idempotent.

---

### S3: Session persistence routing on cold launch

**Story ID:** PH-2-E3-S3
**Points:** 3

Extend the `AppCoordinator` cold-launch session check from S1 to fully handle the returning authenticated user path. A user who completed onboarding previously must land directly in their role-appropriate shell stub without seeing splash, auth, or role selection. Verify the sign-out path (auth state listener receives `signedOut` event) routes back to `.auth`.

**Acceptance Criteria:**

- [ ] A user with a valid non-expired session and a `public.users` row with `role = "tracker"` lands on `.trackerShell` stub within 1 second of cold launch (no splash, no auth screen)
- [ ] A user with a valid non-expired session and a `public.users` row with `role = "partner"` lands on `.partnerShell` stub within 1 second of cold launch
- [ ] A user with an expired session (or `supabase.auth.session` returning nil) lands on `.auth` after the session check resolves, with no transition to splash
- [ ] When the `AuthState` observable receives a `signedOut` event (from PH-2-E2-S5), `AppCoordinator.currentRoute` is immediately set to `.auth`
- [ ] The `supabase.auth.session` refresh (token refresh on a valid-but-near-expiry session) is handled transparently -- the `TokenRefreshed` event does not change the route
- [ ] The blank `CadenceBackground` holding screen (from S1) is visible for no more than 2 seconds on any device; if the session check takes longer, the holding screen remains until the check completes

**Dependencies:** PH-2-E3-S1, PH-2-E2-S5 (AuthState observable)
**Notes:** Session persistence does not use `UserDefaults`. The supabase-swift SDK handles session storage in the iOS Keychain. `supabase.auth.session` is the authoritative source. Do not cache the session anywhere else.

---

### S4: Screen transition animations

**Story ID:** PH-2-E3-S4
**Points:** 2

Apply the correct crossfade transitions when `AppCoordinator.currentRoute` changes. The splash-to-auth transition is a 0.3s easeInOut opacity fade per Splash Spec §Transition to Auth. All subsequent route transitions within the onboarding flow use the same 0.3s crossfade for consistency.

**Acceptance Criteria:**

- [ ] `ContentView` wraps the view switch in `withAnimation(.easeInOut(duration: 0.3))` triggered by `AppCoordinator.currentRoute` changes
- [ ] The `SplashView` fades out at opacity 0 over 0.3s while the `AuthView` fades in simultaneously (crossfade, not sequential fade)
- [ ] Auth -> RoleSelection transition uses the same 0.3s crossfade (no slide, no push)
- [ ] RoleSelection -> TrackerOnboarding and RoleSelection -> PartnerOnboarding use the same 0.3s crossfade
- [ ] Onboarding -> shell stub uses the same 0.3s crossfade
- [ ] `@Environment(\.accessibilityReduceMotion)` is checked in `ContentView`; when true, all route transitions are instant (no animation)
- [ ] No transition artifacts (white flash, layout jump) on any simulator size

**Dependencies:** PH-2-E3-S1
**Notes:** Use `.transition(.opacity)` on the view produced by the switch. The animation is driven by `withAnimation` wrapping the route mutation, not by `.animation()` on the view itself.

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
- [ ] End-to-end routing verified: cold launch (new user) -> splash -> auth -> role selection -> tracker onboarding -> tracker shell stub
- [ ] End-to-end routing verified: cold launch (new user) -> splash -> auth -> role selection -> partner onboarding -> partner shell stub
- [ ] Cold launch with existing session routes directly to correct shell stub without splash
- [ ] Sign-out event routes to auth screen
- [ ] Phase objective is advanced: the app's front-door state machine is complete and deterministic
- [ ] Applicable skill constraints satisfied: `swiftui-production` (@Observable AppCoordinator, no retain cycles, no AnyView), `cadence-navigation` (coordinator-owned navigation state, role isolation), `cadence-xcode-project` (project.yml updated for all new files), `cadence-motion` (0.3s crossfade spec, reduced-motion gating), `cadence-supabase` (typed supabase-swift client for users upsert)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No direct navigation calls in child views -- all route changes go through `AppCoordinator`
- [ ] Source document alignment verified: routes match PHASES.md Phase 2 intent and Design Spec §8 IA

## Source References

- PHASES.md: Phase 2 -- Authentication & Onboarding (intent, sequencing rationale, in-scope items 5-6)
- Design Spec v1.1 §8 (information architecture -- Tracker 5-tab, Partner 3-tab)
- Splash Screen Spec v1.0 §Transition to Auth (0.3s easeInOut crossfade, callback pattern)
- MVP Spec §1 (onboarding and role selection -- role options, Partner connection code requirement)
- MVP Spec User Flows 1-2 (Tracker and Partner onboarding sequences)
- MVP PRD v1.0 Data Model (users table: id, role, timezone)
