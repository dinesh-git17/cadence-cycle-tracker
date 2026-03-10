# cadence-supabase Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-supabase/SKILL.md`
**Package path:** `.claude/skills/skill-creator/cadence-supabase.skill`

---

## Local Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure, YAML frontmatter, 500-line limit, description as trigger mechanism |
| `docs/Cadence-design-doc.md` | MVP PRD: Supabase stack, partner connection flow, notification types, auth approach |
| `docs/Cadence_MVP_Spec.md` | **Primary source**: full data model (8 tables with exact columns), RLS policy summary, tech stack confirmation (APNS via Edge Functions), connection flow steps, permission categories |
| `docs/Cadence_Design_Spec_v1.1.md` | Partner sharing status strip behavior, paused state UX, is_private flag UI contract |
| `.claude/skills/cadence-privacy-architecture/SKILL.md` | Sex symptom exclusion, is_private master override, cadence-supabase alignment points |
| `.claude/skills/cadence-sync/SKILL.md` | SyncCoordinator write queue, Realtime subscription lifecycle, NWPathMonitor context |
| `.claude/skills/cadence-data-layer/SKILL.md` | SwiftData schema and offline-first context relevant to transport boundary |

---

## skill-creator Location Used

`.claude/skills/skill-creator/` (project-local install)

- `init_skill.py` not present — consistent with all prior Cadence skills
- Skill directory created manually
- Validated with `python -m scripts.quick_validate ../cadence-supabase` → `Skill is valid!`
- Packaged with `python -m scripts.package_skill ../cadence-supabase` → `cadence-supabase.skill`

---

## Official Anthropic Sources Used for Skill Standards

| Source | Used For |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` (project-local) | Canonical skill structure, YAML frontmatter, 500-line limit, "pushy" description, anatomy |

---

## Supabase / Postgres / Apple Authoritative Sources Used

| Source | Used For |
|---|---|
| Supabase official docs (supabase.com/docs) | RLS policy syntax (`USING`, `WITH CHECK`, `auth.uid()`), Realtime channel API, Edge Function Deno pattern, `SupabaseClient` initialization |
| supabase-swift GitHub (github.com/supabase/supabase-swift) | Typed query pattern, `.from().select().execute().value`, `authStateChanges`, `functions.invoke()`, `channel().on(.postgresChanges)` |
| Postgres documentation | RLS policy semantics, `SECURITY DEFINER` vs `SECURITY INVOKER`, `EXISTS` subquery in policy USING clause |
| Apple Push Notification Service docs | APNS JWT auth pattern, payload structure — referenced for Edge Function push design |
| Swift Package Index (swiftpackageindex.com) | supabase-swift package availability confirmation for SPM |

---

## Supabase Account State (Inspected via MCP)

| Property | Value |
|---|---|
| Organization name | `dinbuilds` |
| Organization ID | `hekdjznkviujumcsbqip` |
| Plan | free |
| Projects | **None** — zero existing projects |
| Release channels allowed | `ga`, `preview` |

**Conclusion:** No Cadence Supabase project exists. The skill is written as governance for the Cadence project to be created on this account.

---

## Repository State Inspected

- Pre-implementation as of March 7, 2026: no Swift files, no Xcode project, no service layers, no DTOs
- No existing Supabase client code, no auth session code, no Realtime subscriptions, no Edge Functions
- Repo contains only: docs/, assets/ (logos), .claude/skills/
- All architecture in the skill is prospective, grounded in locked docs

---

## Cadence-Specific Backend Facts Extracted

### Data Model (from Cadence_MVP_Spec.md)
8 tables: `users`, `cycle_profiles`, `partner_connections`, `period_logs`, `daily_logs`, `symptom_logs`, `prediction_snapshots`, `reminder_settings`

Key columns governing access:
- `partner_connections.is_paused` — global pause override
- `partner_connections.share_*` — 6 category flags: predictions, phase, symptoms, mood, fertile_window, notes
- `daily_logs.is_private` — per-entry private flag (master override per row)

### RLS Policy Summary (from Cadence_MVP_Spec.md §RLS Policy Summary)
- Ownership: `user_id = auth.uid()` for all write access
- Partner read on `daily_logs`, `period_logs`, `prediction_snapshots`: requires live connection + `is_paused = false` + relevant `share_*` + `is_private = false` (for daily_logs)

### Partner Connection Flow (from Cadence_MVP_Spec.md §Connection Flow)
- 6-step flow: invite code → out-of-band share → Partner redemption → Tracker confirmation → live
- 6-digit code, 24h expiry
- One active connection per Tracker in beta
- Disconnect = immediate row deletion = immediate access revocation

### Push Notifications (from Cadence_MVP_Spec.md §Tech Stack)
- "Apple Push Notification Service via Supabase Edge Functions"
- 3 Partner notification types: period in X days, symptom logged, fertile window starts
- Tracker controls which partner notifications fire

### Sex Symptom Exclusion (from cadence-privacy-architecture skill)
- Sex symptom NEVER shared with Partner, regardless of `share_symptoms` flag
- Enforced at query column projection level, not relying solely on RLS

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|---|---|
| `invite_code` expiry mechanism not specified in docs (DB constraint vs. application logic vs. Edge Function) | Resolved conservatively: enforce in Edge Function (`redeem-invite`) with server-side timestamp check. Also documented as a candidate for DB `CHECK` constraint. No client-side expiry enforcement. |
| `users.role` storage: JWT claim vs. database table | MVP Spec defines `users.role` as a database column. Auth JWT from Supabase Auth does not include custom claims without additional setup. Skill encodes: read role from `users` table after sign-in, not from JWT. |
| Whether `symptom_logs` can be directly queried by Partner | Not addressed explicitly in RLS summary. Resolved conservatively: Partner reads symptoms via JOIN through `daily_logs` policy, not via a direct `symptom_logs` policy. Sex symptom exclusion applied at projection level. |
| `device_tokens` table not defined in data model | Push dispatch requires device token storage. Skill introduces `device_tokens (user_id, token, platform, updated_at)` as an implied required table, clearly documented as an addition not in the original spec. |
| APNS provider for Edge Functions | Docs say "APNS via Supabase Edge Functions" but don't specify HTTP/2 direct or FCM relay. Skill documents direct APNS HTTP/2 with JWT auth as the standard pattern for Deno Edge Functions. |

---

## Key Enforcement Rules Encoded

1. **SupabaseClient singleton** — one instance at app start, injected via services; never in Views/ViewModels
2. **Env var loading** — SUPABASE_URL and SUPABASE_ANON_KEY from xcconfig → Info.plist; never literals
3. **All 8 tables have RLS enabled** — no exceptions, enabled at creation
4. **4-condition partner read** — connection exists + is_paused=false + share_*=true + is_private=false
5. **is_paused as hard override** — every partner-read policy must include this check
6. **is_private as row-level override** — daily_logs only; blocks partner access regardless of share_symptoms
7. **Typed Swift client** — Codable structs for all table interactions; no [String: Any]
8. **Explicit column projection** — never .select("*") on partner-facing queries
9. **Transport/domain separation** — SupabaseModels.swift ≠ domain models in Models/
10. **Invite code server-side** — generated in Edge Function, not Swift client random
11. **Partner cannot update partner_connections** — only tracker_id = auth.uid() may UPDATE
12. **Realtime channel lifecycle** — subscribe on appear, unsubscribe on disappear + background
13. **Push dispatch in Edge Function** — APNS key never in client; notify-partner function owns dispatch
14. **Auth role from users table** — not JWT claims
15. **Sex symptom exclusion** — at query projection, not relying on RLS alone
