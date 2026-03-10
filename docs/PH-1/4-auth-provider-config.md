# Authentication Provider Configuration

**Epic ID:** PH-1-E4
**Phase:** 1 -- Supabase Backend
**Estimated Size:** M
**Status:** Draft

---

## Objective

Configure all three Supabase authentication providers (Sign in with Apple, Google OAuth, email/password), install the Postgres trigger that creates a `public.users` row on every new `auth.users` insert, and verify each auth path works end-to-end with test accounts. The auth configuration produced here is the identity layer that every subsequent phase's RLS policies, service layer calls, and session management depends on.

## Problem / Context

Supabase Auth manages the `auth.users` table internally. Application code accesses user identity exclusively via `auth.uid()` -- the UUID from the authenticated JWT. For the Cadence data model to work, every `auth.uid()` must have a corresponding row in `public.users` with the correct `role` field, because the iOS role-routing logic (Phase 2) and all RLS policies that check `user_id` depend on this row.

The Postgres trigger in this epic is the glue between the auth system and the application schema. Without it, a user can authenticate successfully but the application has no record of their role, timezone, or identity in the `public.users` table -- every subsequent phase that reads from `public.users` returns null.

Sign in with Apple is the primary authentication method for iOS users: App Store guidelines strongly recommend it and the target beta cohort (iOS users) expects it. Google OAuth is included as a secondary path. Email/password is the fallback for testing and any non-iOS device access. All three providers must be configured in Phase 1 because Phase 2 (auth screen implementation) hard-depends on these providers being active.

The Apple provider configuration requires credentials from an Apple Developer account (Team ID, Service ID, Key ID, private key). These credentials are secrets and must be stored in Supabase Auth settings only -- never in any file in the repository.

**Source references that define scope:**

- cadence-supabase skill §8 (auth session integration, role from users table not JWT claims, trigger pattern)
- PHASES.md Phase 1 in-scope: "Supabase auth: Sign in with Apple, Google, email/password providers"
- PHASES.md Phase 2 dependency on Phase 1: "Supabase auth providers configured"
- Design Spec v1.1 §12.1 (auth screen -- Apple, Google, email/password)
- MVP Spec §1 (onboarding and role selection -- Tracker and Partner roles)

## Scope

### In Scope

- Supabase Auth email/password provider enabled with `Confirm email` setting configured per beta requirements
- Supabase Auth Sign in with Apple provider configured with: Apple Team ID, Apple Service ID (bundle identifier), Apple Key ID, Apple private key (.p8 file content) -- stored in Supabase Auth settings
- Supabase Auth Google OAuth provider configured with: Google Client ID and Client Secret from Google Cloud OAuth 2.0 credentials -- stored in Supabase Auth settings
- Apple callback URL (`https://[project-ref].supabase.co/auth/v1/callback`) registered in the Apple Developer portal under the Service ID
- Google callback URL (`https://[project-ref].supabase.co/auth/v1/callback`) registered in the Google Cloud OAuth 2.0 client
- Postgres trigger `on_auth_user_created` on `auth.users` AFTER INSERT that calls `handle_new_user()` to insert a row into `public.users(id, created_at, role, timezone)` with `role` defaulting to `'tracker'` (role is updated by the app during onboarding)
- `handle_new_user()` trigger function defined as a `SECURITY DEFINER` function so it can insert into `public.users` despite RLS
- Migration file `supabase/migrations/[timestamp]_auth-trigger.sql` containing the trigger function and trigger
- End-to-end verification: test signup with each provider (email/password and, if test credentials are available, Apple and Google) confirms a row is created in `public.users`

### Out of Scope

- iOS `AuthService.swift` and `supabase-swift` session integration (Phase 2)
- Auth screen SwiftUI views (Phase 2)
- Role update during Tracker onboarding (Phase 2 -- the trigger inserts with `role = 'tracker'` as default; Partner role assignment is also Phase 2)
- Magic link / OTP authentication (not in MVP Spec)
- Phone authentication (not in MVP Spec)
- Multi-factor authentication (post-beta)
- Email template customization for verification emails
- Apple App Attest or device check (post-beta)

## Dependencies

| Dependency                                                 | Type     | Phase/Epic | Status | Risk                                                                                                 |
| ---------------------------------------------------------- | -------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------- |
| PH-1-E2-S1 complete (`public.users` table exists)          | FS       | PH-1-E2-S1 | Open   | High -- trigger cannot insert into a non-existent table                                              |
| PH-1-E3-S1 complete (`users` table has RLS policies)       | SS       | PH-1-E3-S1 | Open   | Medium -- trigger function runs as SECURITY DEFINER to bypass RLS; must confirm this works correctly |
| Apple Developer account with Sign in with Apple capability | External | None       | Open   | Medium -- requires Dinesh to have an active Apple Developer membership and a configured Service ID   |
| Google Cloud project with OAuth 2.0 credentials            | External | None       | Open   | Medium -- requires Dinesh to create credentials in Google Cloud Console                              |

## Assumptions

- The trigger function defaults `role = 'tracker'` because a new user who signs up without context is assumed to be tracking. The Partner role is assigned explicitly during Partner onboarding (Phase 2) via an update to `public.users.role`. This default-to-tracker assumption is safe: a Partner who accidentally lands in the Tracker experience will be corrected by the onboarding role selection screen.
- `SECURITY DEFINER` on `handle_new_user()` is the correct pattern for trigger functions that must bypass RLS. The function only inserts one row with the authenticated user's `auth.uid()` -- it cannot be exploited to insert arbitrary data.
- `Confirm email` setting for email/password will be disabled for beta (known test cohort, no need for email verification friction). Dinesh must confirm this before S1.
- The Apple Service ID is distinct from the iOS App Bundle ID. The Service ID is for web-based OAuth flow; the iOS Bundle ID (`com.cadence.tracker`) is used for native Sign in with Apple. Confirm with Dinesh which identifier to use for the Supabase Apple provider configuration.
- Google OAuth 2.0 credentials use the `Web application` type in Google Cloud Console. The authorized redirect URI is the Supabase callback URL.

## Risks

| Risk                                                                                   | Likelihood | Impact | Mitigation                                                                                                                                                          |
| -------------------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apple Developer portal configuration wrong (wrong Service ID or missing callback URL)  | Medium     | High   | Test with a real Apple ID test account before declaring S2 done; Apple auth errors are opaque and hard to debug after Phase 2 begins                                |
| Trigger function fails silently if `public.users` insert violates a constraint         | Low        | High   | Add error handling to `handle_new_user()` -- log to Postgres `raise warning` if insert fails; test with a duplicate ID (edge case if auth.users insert fires twice) |
| Google OAuth redirect URI mismatch blocks login                                        | Medium     | Medium | Test the Google auth flow with a real Google account in S5; verify the exact callback URL matches what is registered in Google Cloud Console                        |
| `role = 'tracker'` default means a Partner who signs up fresh is incorrectly defaulted | Low        | Low    | Phase 2 role selection screen corrects this; the default is not permanently binding                                                                                 |

---

## Stories

### S1: Enable email/password authentication

**Story ID:** PH-1-E4-S1
**Points:** 1

Enable the email/password provider in Supabase Auth settings. This is the simplest auth path and the one used for local development and automated testing throughout all subsequent phases.

**Acceptance Criteria:**

- [ ] Supabase Auth email/password provider is enabled (Supabase dashboard: Authentication > Providers > Email)
- [ ] `Confirm email` setting is disabled for beta (no email verification required for the private test cohort)
- [ ] `Secure email change` is enabled (prevents email hijacking if a user changes their email address)
- [ ] A test email signup (`POST /auth/v1/signup` or via Supabase dashboard Authentication > Users > Invite user) succeeds and creates an entry in `auth.users`
- [ ] The test signup does NOT yet create a row in `public.users` (trigger not yet installed; this confirms the trigger is required)
- [ ] The test user is deleted from `auth.users` after verification (do not leave test accounts in the project)

**Dependencies:** PH-1-E1-S1

**Notes:** The confirmation of "no public.users row yet" in this story's test is intentional -- it documents the problem this epic's trigger (S4) solves, giving a concrete before/after verification path.

---

### S2: Configure Sign in with Apple provider

**Story ID:** PH-1-E4-S2
**Points:** 3

Configure the Supabase Sign in with Apple OAuth provider using Apple Developer credentials. This is the primary authentication method for iOS users and must work before Phase 2 implements the auth screen.

**Acceptance Criteria:**

- [ ] Sign in with Apple provider is enabled in Supabase Auth settings (Authentication > Providers > Apple)
- [ ] Apple Team ID is entered (10-character alphanumeric string from Apple Developer account membership page)
- [ ] Apple Key ID is entered (the ID of the Sign in with Apple key generated in Apple Developer portal > Certificates, Identifiers & Profiles > Keys)
- [ ] Apple private key (.p8 file content) is entered and saved in Supabase Auth settings (this value is a secret -- confirm it is not stored in any file in the repository)
- [ ] Apple Service ID is entered (the identifier configured in Apple Developer portal > Identifiers > Services IDs -- distinct from the iOS app bundle ID)
- [ ] The Supabase callback URL (`https://[project-ref].supabase.co/auth/v1/callback`) is registered as a Return URL in the Apple Service ID configuration in the Apple Developer portal
- [ ] Supabase Auth > Providers > Apple shows status as configured (no error state)
- [ ] The Apple private key, Team ID, Key ID, and Service ID are NOT present in any committed file in the repository (verify with `git grep` for the Team ID)

**Dependencies:** PH-1-E4-S1

**Notes:** The Apple Developer portal steps to prepare for this story: (1) Create a Service ID under Identifiers if one does not exist; (2) Enable Sign in with Apple for the Service ID; (3) Add the Supabase callback URL as a Return URL; (4) Create a Sign in with Apple key under Keys if one does not exist; (5) Download the .p8 file (it can only be downloaded once). If Dinesh does not have an Apple Developer account, this story is blocked -- notify before proceeding to S3.

---

### S3: Configure Google OAuth provider

**Story ID:** PH-1-E4-S3
**Points:** 3

Configure the Supabase Google OAuth provider using Google Cloud Console credentials. Google OAuth provides a secondary sign-in path and is useful for testing on non-Apple devices.

**Acceptance Criteria:**

- [ ] Google OAuth provider is enabled in Supabase Auth settings (Authentication > Providers > Google)
- [ ] Google Client ID (from Google Cloud Console > APIs & Services > Credentials > OAuth 2.0 Client IDs) is entered in Supabase Auth settings
- [ ] Google Client Secret is entered in Supabase Auth settings (this value is a secret)
- [ ] The Supabase callback URL (`https://[project-ref].supabase.co/auth/v1/callback`) is listed as an Authorized redirect URI in the Google Cloud OAuth 2.0 client configuration
- [ ] The Google Cloud OAuth consent screen is configured with the app name `Cadence` and is in testing mode (not published) for beta
- [ ] Supabase Auth > Providers > Google shows status as configured (no error state)
- [ ] Google Client ID and Client Secret are NOT present in any committed file in the repository

**Dependencies:** PH-1-E4-S1

**Notes:** Google Cloud Console steps: (1) Create a project or use an existing one; (2) Enable the Google Identity API; (3) Create an OAuth 2.0 Client ID of type `Web application`; (4) Add the Supabase callback URL to Authorized redirect URIs; (5) Note the Client ID and Client Secret for Supabase configuration. The OAuth consent screen must list the correct scopes (`email`, `profile`, `openid`) -- no additional scopes are needed or permitted for Cadence.

---

### S4: Create Postgres trigger for public.users row on auth.users insert

**Story ID:** PH-1-E4-S4
**Points:** 3

Implement the `handle_new_user()` trigger function and the `on_auth_user_created` trigger on `auth.users`. This is the bridge between Supabase Auth and the application schema: every successful signup of any kind (email, Apple, Google) must produce a `public.users` row with the correct `id`, `created_at`, `role`, and `timezone`.

**Acceptance Criteria:**

- [ ] Migration file `supabase/migrations/[timestamp]_auth-trigger.sql` contains the `handle_new_user()` function and the `on_auth_user_created` trigger
- [ ] `handle_new_user()` is defined as `RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER`
- [ ] The function body inserts into `public.users(id, created_at, role, timezone)` with values `(NEW.id, NEW.created_at, 'tracker', 'UTC')`
- [ ] The function returns `NEW` after the insert
- [ ] The trigger is `CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE PROCEDURE handle_new_user()`
- [ ] `supabase db push` exits 0 with no errors after applying this migration
- [ ] `SELECT proname FROM pg_proc WHERE proname = 'handle_new_user'` returns the function
- [ ] `SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created'` returns the trigger
- [ ] A test email signup (using the test account from S1) confirms a row is created in `public.users` with `id` matching the `auth.users.id`, `role = 'tracker'`, `timezone = 'UTC'`
- [ ] The test user and their `public.users` row are deleted after verification
- [ ] `scripts/protocol-zero.sh` exits 0 on the migration file
- [ ] `scripts/check-em-dashes.sh` exits 0 on the migration file

**Dependencies:** PH-1-E2-S1, PH-1-E3-S1, PH-1-E4-S1

**Notes:** `SECURITY DEFINER` is required because `public.users` has RLS enabled and the trigger runs in the context of the `auth` schema, not as the authenticated user. Without `SECURITY DEFINER`, the trigger cannot bypass the RLS policy on `public.users`. The function inserts `role = 'tracker'` as the default -- this is not a permanent assignment; the onboarding flow in Phase 2 updates this field via an authenticated PATCH to `public.users` when a user selects the Partner role. The trigger must be idempotent under failure conditions: if the insert fails (e.g., duplicate key), the trigger should not crash the auth flow. Add `ON CONFLICT (id) DO NOTHING` to the insert statement.

---

### S5: Verify all three auth providers end-to-end

**Story ID:** PH-1-E4-S5
**Points:** 2

Confirm all three auth providers work end-to-end: a signup completes, a session is established, `auth.uid()` resolves to the new user's ID, and the `public.users` row is created by the trigger. This is the Phase 1 auth readiness gate for Phase 2.

**Acceptance Criteria:**

- [ ] Email/password signup via Supabase dashboard creates an entry in `auth.users` and a corresponding row in `public.users` with `role = 'tracker'`
- [ ] `SELECT * FROM public.users WHERE id = '[test-user-id]'` returns one row with the correct `id`, `created_at`, `role`, `timezone`
- [ ] Apple auth flow can be initiated from the Supabase Auth test page (full round-trip requires iOS device -- confirm the provider configuration is valid at the Supabase level; full iOS round-trip tested in Phase 2)
- [ ] Google OAuth flow completes round-trip from the Supabase Auth test page or a simple web redirect: a Google account can sign in and produce a session
- [ ] `SELECT auth.uid()` executed within a Supabase Edge Function invoked with a valid session token returns the correct user UUID
- [ ] All test accounts created during this story are deleted from `auth.users` after verification
- [ ] `SELECT count(*) FROM public.users` returns 0 after test cleanup (no orphaned rows)

**Dependencies:** PH-1-E4-S1, PH-1-E4-S2, PH-1-E4-S3, PH-1-E4-S4

**Notes:** The full Apple sign-in round-trip (native iOS flow via `ASAuthorizationController`) is tested in Phase 2 when the iOS auth screen is implemented. The verification here confirms the Supabase provider configuration is valid at the server level -- the Apple callback URL is correct, the key material is accepted by Supabase, and the provider shows no error state. If Apple auth cannot be tested at this stage due to missing iOS client, document the configuration as pending Phase 2 verification and flag it as an open risk.

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

- [ ] All five stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] All three auth providers active and verified in Supabase dashboard
- [ ] `on_auth_user_created` trigger confirmed functional via end-to-end signup test
- [ ] Phase objective is advanced: authenticated users produce a public.users row; Phase 2 can begin iOS auth implementation
- [ ] cadence-supabase skill §8 constraints: role stored in `users.role`, not JWT claims; trigger creates row on auth.users insert
- [ ] CLAUDE.md §5: no Apple or Google credentials in any committed file; verified with `git grep`
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] All test accounts deleted from auth.users; public.users count is 0 post-cleanup

## Source References

- PHASES.md: Phase 1 -- Supabase Backend (in-scope: Supabase auth: Sign in with Apple, Google, email/password providers)
- PHASES.md: Phase 2 dependency: "Phase 1 (Supabase auth providers configured, partner_connections table exists for invite code lookup)"
- Design Spec v1.1 §12.1 (auth screen: Apple, Google, email/password, forgot password, form validation)
- MVP Spec §1 (onboarding and role selection: Tracker and Partner roles)
- cadence-supabase skill §8 (auth session integration: role from users table, not JWT; authStateChanges pattern; trigger on auth.users insert)
