# Auth Screen and Session Integration

**Epic ID:** PH-2-E2
**Phase:** 2 -- Authentication & Onboarding
**Estimated Size:** M
**Status:** Draft

---

## Objective

Build the authentication screen exactly as specified in Design Spec §12.1 and integrate all three auth providers (Apple, Google, email/password) via `supabase-swift`. Establish the Supabase client singleton with credentials loaded from a non-hardcoded configuration source. Wire an auth state listener so the AppCoordinator (PH-2-E3) can react to sign-in and sign-out events. Phase 2 ends when a user can authenticate through any of the three providers and the session persists across cold launches.

## Problem / Context

Every Supabase API call in Phase 2 and beyond requires a valid JWT from an active session. The auth screen is the sole entry point for obtaining that JWT. Without this epic, no user can authenticate, no session exists for the AppCoordinator to check, and all onboarding data writes (PH-2-E4, PH-2-E5) are blocked.

Source authority: Design Spec v1.1 §12.1 defines every visual element on the auth screen. Supabase Auth docs (supabase.com/docs/reference/swift) define the `supabase-swift` SDK API for Apple, Google, and email auth.

## Scope

### In Scope

- `AuthView.swift` -- full layout per Design Spec §12.1 (wordmark, tagline, Apple CTA, Google CTA, divider, email field, password field with show/hide toggle, forgot password link, Continue CTA, sign-in/sign-up mode toggle link)
- `SupabaseClient.swift` -- shared Supabase client initialization (URL + anon key from `xcconfig` or `Info.plist`, not hardcoded)
- `supabase-swift` package dependency added to `project.yml` Swift Package Manager section
- Sign in with Apple: `ASAuthorizationAppleIDProvider` + nonce + `supabase.auth.signInWithIdToken(credentials:)` + full-name capture via `updateUser`
- Sign in with Google: OAuth web flow via `supabase.auth.signInWithOAuth(provider: .google, redirectTo:)` + URL scheme handler in app target
- Email/password: sign-up and sign-in modes, toggled in-place by the "Already have an account? Sign in" / "New here? Create account" link
- Form validation: email format check (RFC 5322 basic pattern), password minimum 8 characters, non-empty required fields, Continue CTA disabled while any required field is empty
- Auth state listener using `supabase.auth.authStateChanges` async stream -- surfaces `signedIn`, `signedOut`, and `tokenRefreshed` events to the AppCoordinator via a published property or callback
- Error state rendering: invalid credentials, email already in use, network failure, invalid email format -- inline below the relevant field or below the CTA
- Forgot password: calls `supabase.auth.resetPasswordForEmail(:)`, replaces CTA area with confirmation message

### Out of Scope

- Role selection and post-auth routing -- owned by AppCoordinator (PH-2-E3)
- Session persistence routing (cold launch skip to shell) -- owned by AppCoordinator (PH-2-E3-S3)
- Supabase provider configuration on the backend (Apple, Google OAuth app IDs) -- Phase 1 deliverable; this epic assumes they are already configured
- Onboarding screens -- Phase 2 E4 and E5
- Password reset deep-link handler and reset confirmation screen -- post-MVP; Phase 2 delivers only the reset email dispatch and a confirmation message in the auth screen

## Dependencies

| Dependency                                                                                                                                                 | Type | Phase/Epic | Status   | Risk |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------- | -------- | ---- |
| Supabase project URL and anon key available (Phase 1 output)                                                                                               | FS   | PH-1       | Open     | High |
| Apple and Google auth providers configured in Supabase dashboard                                                                                           | FS   | PH-1       | Open     | High |
| Buildable project with Phase 0 color and typography assets                                                                                                 | FS   | PH-0       | Resolved | Low  |
| `CadenceBackground`, `CadenceCard`, `CadenceTerracotta`, `CadenceBorder`, `CadenceTextPrimary`, `CadenceTextSecondary`, `CadenceTextOnAccent` color assets | FS   | PH-0       | Resolved | Low  |
| AppCoordinator shell to receive auth state change (wiring only, not blocking implementation)                                                               | SS   | PH-2-E3    | Open     | Low  |

## Assumptions

- `supabase-swift` is the only iOS Supabase client. The anon key is a public key by design (RLS enforces data access); it does not need to be treated as a secret, but it must not be hardcoded in source -- it belongs in an `xcconfig` file or `Info.plist` that is gitignored or populated from CI environment variables.
- The Google sign-in flow uses the OAuth web flow (opens an ASWebAuthenticationSession), not the native Google Sign-In SDK. No additional third-party dependency is required beyond `supabase-swift`.
- Apple Sign In captures the user's full name only on the first authorization. The full name from `ASAuthorization.credential.fullName` is passed to `supabase.auth.updateUser(user: UserAttributes(data: ["full_name": fullName]))` immediately after sign-in. On subsequent sign-ins, the full name is already stored in user metadata.
- The `users.role` column in the public `users` table is NOT written in this epic. Role selection and the `users` row upsert are owned by PH-2-E3.
- Both sign-up and sign-in for email/password use the same screen, toggled in-place. There is no separate route for each mode.
- The auth screen has no navigation bar and no back button. It is a root destination in the app flow.

## Risks

| Risk                                                                                                 | Likelihood | Impact | Mitigation                                                                                                                    |
| ---------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Phase 1 Supabase project URL not available when Phase 2 begins (blocking Phase 1 dependency)         | Medium     | High   | Use a temporary `.xcconfig.local` with a dummy URL for UI development; replace with real credentials when Phase 1 is complete |
| Apple Sign In nonce generation or token verification fails on first implementation                   | Medium     | Medium | Follow Supabase `auth-apple` guide verbatim; validate with a test Apple ID in the simulator                                   |
| Google OAuth redirect URL scheme not registered in `project.yml`                                     | Low        | Medium | Add `CFBundleURLSchemes` entry and URL scheme registration in `project.yml` as part of this epic                              |
| `supabase.auth.authStateChanges` stream lifecycle (stream leaks if not properly cancelled on deinit) | Low        | Low    | Subscribe via `.task` modifier in a coordinator-owned view, which automatically cancels on view disappear                     |

---

## Stories

### S1: Auth screen static layout

**Story ID:** PH-2-E2-S1
**Points:** 5

Implement the full visual layout of `AuthView` per Design Spec §12.1. All interactive elements are present and styled but carry no functional behavior in this story -- buttons do nothing, fields accept text, the mode-toggle link does nothing. Purpose: lock the layout and pass design review before wiring auth logic.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Auth/AuthView.swift` exists and compiles clean
- [ ] Background is `Color("CadenceBackground")` full-screen
- [ ] Wordmark "Cadence" renders in `.largeTitle` (34pt) semibold, `Color("CadenceTextPrimary")`, horizontally centered
- [ ] Tagline "Track your cycle. Share what matters." renders in `.subheadline`, `Color("CadenceTextSecondary")`, centered, directly below wordmark
- [ ] "Sign in with Apple" button matches Primary CTA spec: 50pt height, 14pt corner radius, `#000000` fill, white `headline` semibold label, full container width with 16pt horizontal inset
- [ ] "Sign in with Google" button is a secondary outlined button: `CadenceCard` fill, 1pt `CadenceBorder` stroke, 14pt corner radius, 50pt height, `CadenceTextPrimary` label, same width as Apple button
- [ ] Divider "or" uses 1pt `CadenceBorder` horizontal lines flanking the word, `caption1`, `CadenceTextSecondary`
- [ ] Email field: `CadenceCard` fill, 1pt `CadenceBorder` stroke, 10pt corner radius, `.body` placeholder "Email" in `CadenceTextSecondary`, email keyboard type
- [ ] Password field: `CadenceCard` fill, 1pt `CadenceBorder` stroke, 10pt corner radius, `.body` placeholder "Password" in `CadenceTextSecondary`, trailing "Show" text button in `.callout` `CadenceTerracotta`, secure text entry by default
- [ ] "Forgot password?" link: `.footnote`, `CadenceTerracotta`, right-aligned
- [ ] "Continue" CTA: full-width Primary CTA Button, `CadenceTerracotta` fill, 50pt height, 14pt corner radius, white `headline` semibold label
- [ ] "Already have an account? Sign in" line: `.footnote` `CadenceTextSecondary` with inline "Sign in" in `CadenceTerracotta`
- [ ] All interactive elements have a minimum touch target of 44x44pt enforced via `.frame(minWidth: 44, minHeight: 44)` where the visual element is smaller
- [ ] `project.yml` updated with `Cadence/Views/Auth/AuthView.swift` in the `Sources` group

**Dependencies:** None (Phase 0 color/type assets are prerequisite)
**Notes:** This story deliberately contains no auth logic. Its sole acceptance gate is visual correctness against §12.1. A second engineer can implement S2-S4 in parallel once S1 layout is locked.

---

### S2: Email/password authentication and mode toggle

**Story ID:** PH-2-E2-S2
**Points:** 5

Wire email/password fields to `supabase-swift` auth calls. Implement the sign-up / sign-in mode toggle so users switch between `signUp` and `signIn` flows without leaving the screen. The Continue CTA dispatches the correct call based on current mode. This story depends on S5 (Supabase client init) for the `supabase` instance.

**Acceptance Criteria:**

- [ ] `AuthViewModel.swift` (or equivalent `@Observable` class) drives auth state; the view is stateless beyond layout
- [ ] Default mode on screen load is sign-up ("New user" / "Continue" = create account)
- [ ] Tapping the mode-toggle link switches between sign-up and sign-in modes; the CTA label changes to "Sign in" in sign-in mode
- [ ] Continue CTA calls `supabase.auth.signUp(email:password:)` in sign-up mode and `supabase.auth.signIn(email:password:)` in sign-in mode
- [ ] Continue CTA shows an inline `ProgressView` and is disabled while the auth call is in-flight; button width does not change during loading (Design Spec §10.3)
- [ ] On successful sign-in/sign-up, the ViewModel exposes the resulting `Session` and triggers the auth state listener path (S5) -- the ViewModel does not perform navigation directly
- [ ] On error, a non-destructive inline error message appears below the CTA in `.footnote` `CadenceTextSecondary` with a `warning.fill` SF Symbol (not a red color -- Design Spec §13)
- [ ] "Show" password toggle correctly toggles between `SecureField` and `TextField` with no layout shift
- [ ] "Forgot password?" tap calls `supabase.auth.resetPasswordForEmail(:)` with the current email field value and replaces the CTA area with a "Check your email" confirmation message
- [ ] Form validation: Continue CTA is disabled if email is empty, password is empty, or email does not match `[^@]+@[^.]+\..+` pattern

**Dependencies:** PH-2-E2-S1 (layout), PH-2-E2-S5 (Supabase client)
**Notes:** The `AuthViewModel` must be injectable for testing without a live Supabase connection (cadence-testing skill DI requirement). Introduce a protocol or closure-based auth interface if needed.

---

### S3: Sign in with Apple native integration

**Story ID:** PH-2-E2-S3
**Points:** 5

Implement native Sign in with Apple using `AuthenticationServices`. Generate a SHA256 nonce, initiate the `ASAuthorizationAppleIDProvider` request with nonce and `.fullName` + `.email` scopes, extract the ID token from the credential, and call `supabase.auth.signInWithIdToken(credentials:)`. Capture full name on first sign-in and write it to user metadata via `updateUser`.

**Acceptance Criteria:**

- [ ] Tapping "Sign in with Apple" presents the native Apple authorization sheet (ASAuthorizationController)
- [ ] A cryptographically random nonce is generated per sign-in attempt and its SHA256 hash is sent in the request; the raw nonce is held in memory for the Supabase call
- [ ] The `.fullName` and `.email` scopes are requested
- [ ] `ASAuthorization.credential.identityToken` is extracted as a UTF-8 string and passed to `supabase.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))`
- [ ] If `ASAuthorization.credential.fullName` contains a non-nil given or family name, it is saved via `supabase.auth.updateUser(user: UserAttributes(data: ["full_name": ...]))` immediately after sign-in
- [ ] On success, the resulting session is published to the auth state listener (same path as email sign-in)
- [ ] On user cancellation (`ASAuthorizationError.canceled`), no error message is shown -- the auth screen returns to idle state
- [ ] On non-cancellation error, the inline error pattern from S2 is used
- [ ] The "Sign in with Apple" capability is added to the app target in `project.yml`

**Dependencies:** PH-2-E2-S1 (layout), PH-2-E2-S5 (Supabase client), Phase 1 (Apple provider configured in Supabase dashboard)
**Notes:** Apple's identity token does not include full name in claims after the first authorization. The name is available only in the `ASAuthorizationAppleIDCredential.fullName` field on first sign-in. This is a known Apple limitation documented in Supabase Auth guides.

---

### S4: Sign in with Google OAuth

**Story ID:** PH-2-E2-S4
**Points:** 3

Implement Sign in with Google via the OAuth web flow using `supabase.auth.signInWithOAuth(provider: .google, redirectTo:)`. This opens an `ASWebAuthenticationSession`. Register the URL callback scheme in `project.yml` and handle the redirect in the app's URL handling path.

**Acceptance Criteria:**

- [ ] Tapping "Sign in with Google" calls `supabase.auth.signInWithOAuth(provider: .google, redirectTo: URL(string: "cadence://auth-callback")!)` and opens `ASWebAuthenticationSession`
- [ ] `CFBundleURLSchemes` in `project.yml` target `info` includes `cadence` to handle the `cadence://` redirect
- [ ] On successful Google sign-in, the `cadence://auth-callback` URL is received by the app delegate or `@main` App struct scene callback and forwarded to `supabase.auth.session` (session is auto-set by the SDK after OAuth callback)
- [ ] On user cancellation of the web auth session, no error is shown -- the auth screen returns to idle state
- [ ] On non-cancellation error, the inline error pattern from S2 is used
- [ ] The resulting session is published to the auth state listener (same path as S2 and S3)

**Dependencies:** PH-2-E2-S1 (layout), PH-2-E2-S5 (Supabase client), Phase 1 (Google provider configured in Supabase dashboard)
**Notes:** No native Google Sign-In SDK is used -- this is the `supabase-swift` OAuth web flow only, avoiding a third-party dependency.

---

### S5: Supabase client initialization and auth state listener

**Story ID:** PH-2-E2-S5
**Points:** 3

Create `Cadence/App/SupabaseClient.swift` with the shared `SupabaseClient` instance. Load the project URL and anon key from `Info.plist` (populated from an `xcconfig` file). Create the `xcconfig` file and add it to `.gitignore`. Add the `supabase-swift` Swift Package dependency to `project.yml`. Implement the auth state listener using `supabase.auth.authStateChanges` and expose session state to the AppCoordinator.

**Acceptance Criteria:**

- [ ] `supabase-swift` package is declared in `project.yml` under `packages` and pinned to an exact version
- [ ] `Cadence/App/SupabaseClient.swift` exposes `let supabase: SupabaseClient` initialized with `URL` and anon key read from `Bundle.main.infoDictionary` (keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`)
- [ ] `Config.xcconfig` (gitignored) provides `SUPABASE_URL` and `SUPABASE_ANON_KEY` values; `Config.xcconfig.example` (committed) documents required keys with placeholder values
- [ ] No Supabase URL or anon key appears as a literal string in any committed Swift file
- [ ] `AuthState.swift` (or equivalent) contains an `@Observable` class that subscribes to `supabase.auth.authStateChanges` and publishes `currentSession: Session?`
- [ ] The auth state changes subscription is initiated in a `Task` stored in the class; the `Task` is cancelled on deinit
- [ ] `SignedIn`, `SignedOut`, and `TokenRefreshed` auth change events update `currentSession` correctly
- [ ] `xcodegen generate` succeeds after `project.yml` package addition

**Dependencies:** Phase 1 (Supabase project URL and anon key)
**Notes:** The `AuthState` observable is injected into the SwiftUI environment from the `@main` App struct so both `AuthView` and `AppCoordinator` can observe it.

---

### S6: Error state rendering and form validation enforcement

**Story ID:** PH-2-E2-S6
**Points:** 3

Consolidate all error display logic, enforce form-level validation state on the Continue CTA, and verify the 40% disabled opacity on the button when inputs are invalid. This story hardens the auth flow against edge cases missed in S2 (network error, rate limit, malformed inputs).

**Acceptance Criteria:**

- [ ] Continue CTA renders at 40% opacity when disabled (email empty, password empty, or invalid email format), matching Design Spec §10.3 disabled state
- [ ] Inline error messages (below CTA) use `.footnote` style, `CadenceTextSecondary` color, and a `warning.fill` SF Symbol -- never `CadenceDestructive` (red) per Design Spec §13
- [ ] Network error (`URLError`) produces the message "Check your connection and try again" in the error area
- [ ] Invalid credentials error produces "Incorrect email or password" without revealing which field is wrong
- [ ] "Email already in use" (sign-up mode only) produces "An account with this email already exists. Sign in instead."
- [ ] All error messages are cleared when the user begins editing the email or password fields
- [ ] Forgot password link is disabled and shown at 40% opacity when the email field is empty
- [ ] Forgot password confirmation message is not dismissible -- the user must navigate back by tapping "Sign in" mode toggle
- [ ] SwiftLint reports no violations on `AuthView.swift` and `AuthViewModel.swift`

**Dependencies:** PH-2-E2-S2
**Notes:** "Sign up" error messages must not expose whether an email is registered (OWASP account enumeration). "An account with this email already exists" is acceptable only because Supabase Auth returns a distinct error code for this case -- it is not a timing or enumeration attack. If the error code is ambiguous, show a generic message.

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
- [ ] Integration with AppCoordinator verified end-to-end: auth state change triggers routing to role selection
- [ ] Phase objective is advanced: a new user can create an account and a returning user can sign in via all three providers
- [ ] Applicable skill constraints satisfied: `cadence-design-system` (all auth screen colors/typography/spacing/corner radii), `swiftui-production` (@Observable AuthViewModel, no AnyView, no force unwraps), `cadence-xcode-project` (project.yml package declaration and new source files), `cadence-accessibility` (44pt touch targets on all interactive elements), `cadence-supabase` (typed supabase-swift client, no hardcoded credentials)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- [ ] No hardcoded Supabase URL or anon key in any committed file
- [ ] `Config.xcconfig` is in `.gitignore`; `Config.xcconfig.example` is committed
- [ ] Sign in with Apple and Google tested on a physical device or simulator with real credentials
- [ ] Source document alignment verified: auth screen visual elements match Design Spec §12.1 exactly

## Source References

- Design Spec v1.1 §12.1 (auth screen -- all visual elements)
- Design Spec v1.1 §10.3 (Primary CTA Button spec -- loading state, disabled opacity)
- Design Spec v1.1 §13 (error state pattern -- non-destructive warning.fill, no red)
- Design Spec v1.1 §14 (accessibility -- 44pt touch targets, Dynamic Type)
- MVP Spec §1 (onboarding and role selection -- auth as entry point)
- MVP PRD v1.0 §5 (security -- no third-party analytics, Supabase encrypted at rest)
- PHASES.md: Phase 2 -- Authentication & Onboarding (In-Scope items 3-4)
- Supabase Swift API Reference: `auth-signinwithidtoken`, `auth-signinwithoauth`, `auth-signup`, `auth-signin`
