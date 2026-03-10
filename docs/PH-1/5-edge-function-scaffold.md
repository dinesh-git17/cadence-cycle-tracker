# Edge Function Directory Scaffold

**Epic ID:** PH-1-E5
**Phase:** 1 -- Supabase Backend
**Estimated Size:** M
**Status:** Draft

---

## Objective

Establish the `supabase/functions/` directory structure, shared utility modules, and scaffolded entry-point files for the three Edge Functions required by Cadence: `generate-invite`, `redeem-invite`, and `notify-partner`. Each scaffold is a deployable, JWT-validating Deno function that returns a structured `501` response until its full implementation in Phase 8 (`generate-invite`, `redeem-invite`) and Phase 10 (`notify-partner`). The scaffold locks the request/response contract so downstream phases implement against a defined interface, not a blank file.

## Problem / Context

Edge Functions must be deployed to Supabase before they can be invoked by the iOS client or by database webhooks. Deploying a function for the first time in Phase 8 or Phase 10 requires the deployment infrastructure and shared utilities to already exist -- waiting until the implementation phase to establish the scaffold means Phase 8 engineers also bear the cost of CLI setup, shared module architecture decisions, and function naming conventions, at the same time they are writing the actual business logic.

The three functions have distinct implementation phases:

- `generate-invite` and `redeem-invite`: partner connection flow (Phase 8)
- `notify-partner`: APNS push dispatch (Phase 10)

But their contracts -- the request shape they accept, the response shape they return, and the authentication they enforce -- are fully derivable from source documents today. Locking these contracts in Phase 1 gives Phase 8 and Phase 10 a stable implementation target.

Each scaffold enforces JWT validation on every request. This is non-negotiable per cadence-supabase skill §7.4: Edge Functions must validate the calling user's JWT before acting. A function that accepts unauthenticated requests is an open endpoint -- any knowledge of the function URL is sufficient to invoke it.

The shared `_shared/` utilities (`cors.ts`, `supabaseAdmin.ts`) are reused across all three functions. Defining them once in Phase 1 prevents duplication and divergence in Phase 8 and Phase 10.

**Source references that define scope:**

- cadence-supabase skill §7 (Edge Function patterns: directory structure, push dispatch pattern, JWT validation, function naming)
- cadence-supabase skill §5.1 (generate-invite: server-side code generation, no client-side code gen)
- cadence-supabase skill §5.2 (redeem-invite: validation steps, partner_id assignment, invite_code clearing)
- PHASES.md Phase 1 in-scope: "Edge Function directory scaffold for APNS push dispatch (implementation deferred to Phase 10)"
- PHASES.md Phase Notes Phase 1: "Edge Function directory scaffold (full implementation in Phase 10)"
- CLAUDE.md §3.1 (no stub files, no scaffolding comments -- each function is a valid, deployable Deno module)
- Supabase Edge Functions Docs: `Deno.serve`, `_shared/` structure, `npm:` prefix for external deps

## Scope

### In Scope

- `supabase/functions/` directory (if not already created by `supabase init` in Epic 1)
- `supabase/functions/_shared/cors.ts`: CORS headers object and `corsHeaders` export for handling preflight OPTIONS requests
- `supabase/functions/_shared/supabaseAdmin.ts`: Supabase admin client initialized with `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` environment variables; used only in functions that require service role access (generate-invite, redeem-invite)
- `supabase/functions/generate-invite/index.ts`: JWT-validated Deno function; accepts `POST` with `{ tracker_id: string }` body; returns `{ error: "not_implemented", implemented_in: "PH-8", function: "generate-invite" }` with HTTP 501
- `supabase/functions/redeem-invite/index.ts`: JWT-validated Deno function; accepts `POST` with `{ invite_code: string }` body; returns `{ error: "not_implemented", implemented_in: "PH-8", function: "redeem-invite" }` with HTTP 501
- `supabase/functions/notify-partner/index.ts`: JWT-validated Deno function; accepts `POST` with `{ tracker_id: string, event_type: string }` body; returns `{ error: "not_implemented", implemented_in: "PH-10", function: "notify-partner" }` with HTTP 501
- `supabase functions deploy generate-invite`, `supabase functions deploy redeem-invite`, `supabase functions deploy notify-partner` all exit 0
- `deno check` (or equivalent TypeScript validation) exits 0 on all three function files and both shared modules

### Out of Scope

- Actual invite code generation logic (Phase 8)
- Actual invite code redemption logic (Phase 8)
- APNS push dispatch logic (Phase 10)
- `device_tokens` table interaction (Phase 10)
- Database webhook configuration triggering `notify-partner` on `daily_logs` INSERT (Phase 10)
- `supabase functions serve` local development environment configuration beyond basic deployment verification
- Any function not named `generate-invite`, `redeem-invite`, or `notify-partner`

## Dependencies

| Dependency                                                                 | Type     | Phase/Epic | Status | Risk                                                              |
| -------------------------------------------------------------------------- | -------- | ---------- | ------ | ----------------------------------------------------------------- |
| PH-1-E1-S2 complete (CLI linked, supabase/ directory exists)               | FS       | PH-1-E1-S2 | Open   | High -- cannot deploy functions without CLI linkage               |
| `SUPABASE_SERVICE_ROLE_KEY` available (from Supabase project API settings) | External | None       | Open   | Low -- available immediately after project creation in PH-1-E1-S1 |
| Deno runtime available for local `deno check`                              | External | None       | Open   | Low -- `brew install deno`                                        |

## Assumptions

- Deno is the correct Edge Function runtime. Supabase Edge Functions use Deno Deploy. `Deno.serve` (not the deprecated `serve` from deno.land/std) is the correct server entry point.
- External npm dependencies use the `npm:` prefix (e.g., `npm:@supabase/supabase-js`). No bare specifiers.
- The `SUPABASE_SERVICE_ROLE_KEY` environment variable is available to Edge Functions at runtime via `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`. It is set as a Supabase secret via `supabase secrets set` and never committed to the repository.
- The `_shared/` directory is the only place for shared code between functions. Direct cross-function imports are prohibited per Supabase Edge Functions documentation.
- The 501 response body for each function includes an `implemented_in` field (e.g., `"PH-8"`) as a machine-readable indicator for the iOS client to surface a useful error message during development, rather than an opaque 5xx.
- TypeScript strict mode is not explicitly required in Phase 1 scaffold files -- `deno check` default behavior is sufficient. Phase 8 and Phase 10 apply full type strictness when implementing.

## Risks

| Risk                                                                         | Likelihood | Impact | Mitigation                                                                                                                                                          |
| ---------------------------------------------------------------------------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Deno version on local machine incompatible with Supabase Deploy Deno version | Low        | Medium | Check Supabase docs for the current Deno version used on Edge Functions (verify before S5); pin function imports to versions compatible with that Deno release      |
| `supabase functions deploy` fails due to import resolution errors            | Medium     | Low    | Run `deno check [function-file]` locally before deploying; fix all TypeScript errors before deployment attempt                                                      |
| `SUPABASE_SERVICE_ROLE_KEY` accidentally committed                           | Low        | High   | Add `supabase/.env` and any local secrets files to `.gitignore` before writing `supabaseAdmin.ts`; verify with `git grep SERVICE_ROLE_KEY` before committing        |
| Function name changes in Phase 8/10 invalidate the Phase 1 scaffold          | Low        | Medium | Function names are locked in cadence-supabase skill §7.1 (`generate-invite`, `redeem-invite`, `notify-partner`) -- treat them as immutable per the skill governance |

---

## Stories

### S1: Create \_shared/cors.ts utility module

**Story ID:** PH-1-E5-S1
**Points:** 2

Create the CORS headers module shared across all three Edge Functions. Every Edge Function must handle preflight OPTIONS requests correctly or the iOS Supabase client will fail on cross-origin requests in development and test environments.

**Acceptance Criteria:**

- [ ] `supabase/functions/_shared/cors.ts` exists
- [ ] The file exports a `corsHeaders` constant of type `Record<string, string>` containing at minimum: `"Access-Control-Allow-Origin": "*"`, `"Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"`
- [ ] The file exports a `handleCors(req: Request): Response | null` function that returns a `new Response("ok", { headers: corsHeaders })` for OPTIONS requests and `null` for all other methods
- [ ] `deno check supabase/functions/_shared/cors.ts` exits 0 with no TypeScript errors
- [ ] No hardcoded Supabase URLs, keys, or project references in this file
- [ ] `scripts/protocol-zero.sh` exits 0 on this file
- [ ] `scripts/check-em-dashes.sh` exits 0 on this file

**Dependencies:** PH-1-E1-S2

**Notes:** `"Access-Control-Allow-Origin": "*"` is appropriate for the beta because the Supabase JS client (used in development) makes requests from `localhost`. For a production App Store release, this should be scoped to the specific app origin. The MVP beta does not require this restriction. The `handleCors` utility pattern prevents every function from duplicating the OPTIONS check.

---

### S2: Create \_shared/supabaseAdmin.ts utility module

**Story ID:** PH-1-E5-S2
**Points:** 2

Create the Supabase admin client module. The admin client uses the service role key, which bypasses RLS. It is required for Edge Functions that must perform privileged operations: `generate-invite` (inserts into `partner_connections` server-side) and `redeem-invite` (updates `partner_connections.partner_id` server-side). The admin client must never be instantiated in a context where the calling user could influence the service role key.

**Acceptance Criteria:**

- [ ] `supabase/functions/_shared/supabaseAdmin.ts` exists
- [ ] The file exports a `createAdminClient()` function that returns a Supabase client initialized with `Deno.env.get('SUPABASE_URL')` and `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`
- [ ] The function throws an explicit `Error('SUPABASE_URL is not set')` if `SUPABASE_URL` is undefined, and `Error('SUPABASE_SERVICE_ROLE_KEY is not set')` if `SUPABASE_SERVICE_ROLE_KEY` is undefined
- [ ] The import for `@supabase/supabase-js` uses the `npm:` prefix: `import { createClient } from 'npm:@supabase/supabase-js@2'`
- [ ] No hardcoded service role key, URL, or any credential value in this file
- [ ] `deno check supabase/functions/_shared/supabaseAdmin.ts` exits 0 with no TypeScript errors
- [ ] `scripts/protocol-zero.sh` exits 0 on this file
- [ ] `scripts/check-em-dashes.sh` exits 0 on this file

**Dependencies:** PH-1-E5-S1

**Notes:** `createAdminClient()` returns a new client instance per call rather than a module-level singleton. Edge Functions are stateless -- each invocation is a fresh Deno isolate. Module-level singletons in Edge Functions are an anti-pattern because the client initialization could fail silently if the environment variable is missing at module load time. Per-call initialization with explicit error throwing is safer. The service role key is set via `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=[key]` before deployment -- it is never in a committed file.

---

### S3: Scaffold generate-invite Edge Function

**Story ID:** PH-1-E5-S3
**Points:** 3

Create `supabase/functions/generate-invite/index.ts` with full JWT validation, correct request type enforcement, CORS handling, and a structured 501 response documenting the implementation phase. The function signature must match the contract defined in cadence-supabase skill §5.1 exactly.

**Acceptance Criteria:**

- [ ] `supabase/functions/generate-invite/index.ts` exists
- [ ] The function uses `Deno.serve(async (req: Request) => { ... })` as the entry point
- [ ] CORS preflight is handled by calling `handleCors(req)` from `_shared/cors.ts` at the top of the handler; if `handleCors` returns a non-null Response, that Response is returned immediately
- [ ] JWT validation extracts the `Authorization` header; if missing or not in `Bearer [token]` format, the function returns HTTP 401 with body `{ "error": "missing_authorization" }`
- [ ] The function only accepts `POST` requests; non-POST requests return HTTP 405 with body `{ "error": "method_not_allowed" }`
- [ ] Request body is parsed as JSON; if parsing fails, the function returns HTTP 400 with body `{ "error": "invalid_json" }`
- [ ] The function checks that the parsed body contains `tracker_id` (string); if missing, returns HTTP 400 with body `{ "error": "missing_required_field", "field": "tracker_id" }`
- [ ] For all valid requests that pass the above checks, the function returns HTTP 501 with body `{ "error": "not_implemented", "implemented_in": "PH-8", "function": "generate-invite" }`
- [ ] All responses include the CORS headers from `_shared/cors.ts`
- [ ] `deno check supabase/functions/generate-invite/index.ts` exits 0 with no TypeScript errors
- [ ] `supabase functions deploy generate-invite` exits 0
- [ ] Invoking the deployed function with `curl -X POST -H "Authorization: Bearer [anon-key]" -H "Content-Type: application/json" -d '{"tracker_id":"00000000-0000-0000-0000-000000000000"}' [function-url]` returns HTTP 501 with the expected body

**Dependencies:** PH-1-E5-S1, PH-1-E5-S2

**Notes:** The JWT validation in this scaffold uses the `Authorization: Bearer [token]` header presence check. It does not decode and validate the JWT signature -- that is Supabase's built-in JWT verification which occurs before the function handler is called when the function is invoked via the Supabase client (the client automatically injects the user's session token). The presence check guards against totally unauthenticated requests from tools like curl that do not use the Supabase client. Phase 8 implementation will use `createAdminClient()` from `_shared/supabaseAdmin.ts` to perform privileged database operations after the JWT is verified.

---

### S4: Scaffold redeem-invite and notify-partner Edge Functions

**Story ID:** PH-1-E5-S4
**Points:** 3

Create `supabase/functions/redeem-invite/index.ts` and `supabase/functions/notify-partner/index.ts` following the same structural pattern as `generate-invite`, with request schemas and 501 responses appropriate to their distinct contracts.

**Acceptance Criteria:**

- [ ] `supabase/functions/redeem-invite/index.ts` exists with the same structural pattern as `generate-invite`
- [ ] `redeem-invite` required body field is `invite_code` (string); missing `invite_code` returns HTTP 400 with `{ "error": "missing_required_field", "field": "invite_code" }`
- [ ] `redeem-invite` 501 response body: `{ "error": "not_implemented", "implemented_in": "PH-8", "function": "redeem-invite" }`
- [ ] `supabase/functions/notify-partner/index.ts` exists with the same structural pattern
- [ ] `notify-partner` required body fields are `tracker_id` (string) and `event_type` (string); if either is missing, returns HTTP 400 with `{ "error": "missing_required_field", "field": "[missing-field-name]" }`
- [ ] `notify-partner` 501 response body: `{ "error": "not_implemented", "implemented_in": "PH-10", "function": "notify-partner" }`
- [ ] `deno check supabase/functions/redeem-invite/index.ts` exits 0
- [ ] `deno check supabase/functions/notify-partner/index.ts` exits 0
- [ ] `supabase functions deploy redeem-invite` exits 0
- [ ] `supabase functions deploy notify-partner` exits 0
- [ ] Both functions return HTTP 401 when invoked without an `Authorization` header
- [ ] Both functions return HTTP 405 when invoked with a GET request
- [ ] `scripts/protocol-zero.sh` exits 0 on both files
- [ ] `scripts/check-em-dashes.sh` exits 0 on both files

**Dependencies:** PH-1-E5-S1, PH-1-E5-S2, PH-1-E5-S3

**Notes:** `notify-partner` accepts `event_type` as a plain string in the scaffold rather than an enum because the exhaustive event type set is defined in Phase 10. The Phase 10 implementation will add a type guard that rejects unrecognized `event_type` values. The scaffold accepts any string to avoid prematurely locking a contract that Phase 10 will own. `redeem-invite` intentionally uses the service role client (from `_shared/supabaseAdmin.ts`) in its Phase 8 implementation -- the scaffold does not call `createAdminClient()` yet, but the import is present and available.

---

### S5: Verify all three functions are deployed and returning correct responses

**Story ID:** PH-1-E5-S5
**Points:** 2

Confirm all three deployed Edge Functions are reachable, enforce authentication, and return the expected 501 response for valid authenticated requests. This is the Phase 1 deployment readiness gate for Phase 8 and Phase 10.

**Acceptance Criteria:**

- [ ] `supabase functions list` output includes `generate-invite`, `redeem-invite`, `notify-partner` with status `ACTIVE`
- [ ] `generate-invite` returns HTTP 401 when invoked without Authorization header
- [ ] `generate-invite` returns HTTP 501 with `{ "error": "not_implemented", "implemented_in": "PH-8" }` when invoked with a valid Authorization header and a body containing `{ "tracker_id": "[valid-uuid]" }`
- [ ] `redeem-invite` returns HTTP 401 when invoked without Authorization header
- [ ] `redeem-invite` returns HTTP 501 with `{ "error": "not_implemented", "implemented_in": "PH-8" }` when invoked with valid auth and `{ "invite_code": "123456" }` body
- [ ] `notify-partner` returns HTTP 401 when invoked without Authorization header
- [ ] `notify-partner` returns HTTP 501 with `{ "error": "not_implemented", "implemented_in": "PH-10" }` when invoked with valid auth and `{ "tracker_id": "[valid-uuid]", "event_type": "symptom_logged" }` body
- [ ] All function files are committed to `supabase/functions/[function-name]/index.ts` and `supabase/functions/_shared/[module].ts`
- [ ] `scripts/protocol-zero.sh` exits 0 on all committed function files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all committed function files
- [ ] `SUPABASE_SERVICE_ROLE_KEY` does not appear in any committed file (verify with `git grep SERVICE_ROLE_KEY`)

**Dependencies:** PH-1-E5-S1, PH-1-E5-S2, PH-1-E5-S3, PH-1-E5-S4

**Notes:** Use the Supabase anon key (from `.env.supabase`) as the Authorization Bearer token for the curl verification tests in this story -- not the service role key. The anon key is a valid JWT that passes Supabase's JWT validation, making it suitable for testing authenticated function invocations in Phase 1. The actual user JWT (from a real sign-in session) is used in Phase 8 and Phase 10 integration testing.

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
- [ ] All three functions deployed and `ACTIVE` in Supabase
- [ ] All three functions enforce JWT validation and return structured 501 responses
- [ ] Phase objective is advanced: Edge Function infrastructure is live; Phase 8 and Phase 10 can deploy implementations without CLI or infrastructure setup
- [ ] cadence-supabase skill §7 constraints: function names match canonical names; directory structure matches `supabase/functions/_shared/` pattern; JWT validation enforced; no client-side APNS dispatch
- [ ] CLAUDE.md §5: `SUPABASE_SERVICE_ROLE_KEY` not in any committed file
- [ ] `scripts/protocol-zero.sh` exits 0 on all function files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all function files
- [ ] `deno check` passes on all five TypeScript files

## Source References

- PHASES.md: Phase 1 -- Supabase Backend (in-scope: Edge Function directory scaffold for APNS push dispatch, implementation deferred to Phase 10)
- PHASES.md Phase Notes Phase 1: "Edge Function directory scaffold (full implementation in Phase 10)"
- cadence-supabase skill §7 (Edge Function patterns: directory structure, function names, push dispatch contract, JWT validation requirement)
- cadence-supabase skill §5.1 (generate-invite contract: server-side only, tracker_id input)
- cadence-supabase skill §5.2 (redeem-invite contract: invite_code input, partner_id assignment)
- CLAUDE.md §3.1 (no stub files, no scaffolding comments -- valid deployable modules only)
- Supabase Edge Functions documentation: `Deno.serve`, `_shared/` structure, `npm:` import prefix
