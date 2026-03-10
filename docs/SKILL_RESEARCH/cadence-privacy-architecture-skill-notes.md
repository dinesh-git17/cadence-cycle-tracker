# cadence-privacy-architecture Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-privacy-architecture/SKILL.md`
**Package output:** `.claude/skills/skill-creator/cadence-privacy-architecture.skill`

---

## Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill creation process and conventions |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — §6 Data Model, §6.4 partner_connections, §6.10 RLS Policy Summary, §7.5 Symptom Logging, §8.6 Log Sheet, §11 Partner Sharing System |
| `docs/Cadence_Design_Spec_v1.1.md` | Design system v1.1 — §1 Overview (privacy principles), §10.1 Chip (Sex chip lock icon) |

---

## Skill-Creator Location Used

`/Users/Dinesh/Desktop/cadence-cycle-tracker/.claude/skills/skill-creator/`

Scripts used:
- `quick_validate.py` — passed on first run (description was quoted to avoid YAML colon issues)
- `package_skill.py` — produced `cadence-privacy-architecture.skill`

---

## Sources Used

### Claude Code Skill Standards
- Local `skill-creator` SKILL.md and `references/schemas.md` — authoritative for this project's conventions.

### Supabase / Postgres / Privacy Architecture Sources
- **Supabase Documentation: Row Level Security** — RLS operates at the database layer; policies apply to all queries against a table regardless of client. RLS restricts rows, not columns — column projection must be done in the query `select()` call.
- **Supabase Documentation: Realtime** — Realtime events are filtered by RLS before delivery. The client cannot receive rows it lacks SELECT access to via RLS.
- **Postgres Documentation: Row Security Policies** — Policies are evaluated per-row for each operation. `SELECT` policies control read access; `WITH CHECK` policies control write access.
- **Defense-in-depth principle** (OWASP, security architecture best practice): Security controls should be layered. No single control should be the only defense. Client-side filtering + server-side RLS is the correct pattern, not one or the other alone.
- **Least-privilege data access** (OWASP, GDPR-aligned best practice): Queries should request only the minimum fields required. Over-fetching and relying on client-side redaction is a recognized privacy anti-pattern.

### Apple Sources
- **Apple Developer Documentation: SwiftData** — local data boundary for `syncStatus` (local-only field, never synced).
- **Apple Security Best Practices** — client-side validation before server-side enforcement is the correct layered approach for privacy-sensitive applications.

---

## Cadence-Specific Privacy Facts Extracted from Docs

### RLS Policy (PRD §6.10)
Partner read access on `daily_logs`, `period_logs`, `prediction_snapshots` requires ALL of:
1. `partner_connections` row: `tracker_id = data owner` AND `partner_id = auth.uid()`
2. `partner_connections.is_paused = false`
3. Relevant `share_*` flag = `true`
4. `daily_logs.is_private = false`
5. `symptom_type != 'sex'`

### Asymmetric Model (PRD §11)
- Privacy defaults to off; every category requires explicit opt-in
- Pause suspends all access instantly; partner sees only "Sharing paused"
- All categories in `partner_connections` default to `false`

### `isPrivate` Flag (PRD §11, §8.6)
- `daily_logs.is_private = true` → entire day invisible to Partner regardless of category flags
- "Keep this day private" toggle in Log Sheet — copy: "Your partner won't see anything from this day, even if sharing is on."
- Master override — overrides all share_* flags

### Sex Symptom (PRD §7.5, §11)
- Stored in `symptom_logs` — retained for Tracker history
- Excluded from ALL Partner-accessible queries at RLS layer
- "Cannot be overridden by any application-level flag"
- Sex chip shows lock icon in Log Sheet (UI enforcement)

### Share Categories (PRD §6.4)
- share_predictions, share_phase, share_symptoms, share_mood, share_fertile_window, share_notes — all `bool`, default `false`

### Partner Client (PRD §5, §8.10)
- Read-only. No write interactions.
- Separate read-only SwiftData store populated by Realtime events. Never written to by Partner client.

### syncStatus (PRD §12)
- Local field only: `pending | synced | error`
- Must never appear in Supabase payloads

---

## Ambiguities and Resolutions

### 1. `sex` stored locally — does it sync to Supabase?
**Ambiguity:** PRD §7.5 says sex is "stored in `symptom_logs` but excluded from all Partner-visible queries at the RLS layer." This implies it IS written to Supabase (for Tracker history), just excluded from Partner reads.
**Resolution:** Skill encodes this correctly — sex is written to `symptom_logs` for Tracker storage, and the RLS exclusion + client filter prevents Partner exposure. The Tracker write path includes sex; the Partner read path never does.

### 2. Client-side `isPrivate` check vs. full delegation to RLS
**Ambiguity:** PRD §6.10 says "This is enforced at the database layer, not the application layer." This could be read as "RLS only, no client-side check needed."
**Resolution:** Resolved conservatively in favor of defense-in-depth. Client-side filtering is not optional in a privacy-critical app — RLS misconfiguration or SDK behavior changes could expose data if client-side filtering is absent. The skill enforces both layers. The PRD statement means RLS is the authoritative enforcement layer, not that client-side filtering is prohibited.

### 3. Column projection — Supabase RLS handles rows, not columns
**Ambiguity:** The PRD focuses on row-level access control (RLS). Column-level access (which fields Partner sees) is not explicitly described as requiring query-level projection.
**Resolution:** Standard Supabase/Postgres behavior confirmed: RLS restricts rows, not columns. Column projection MUST be done in the `select()` call. Skill encodes this explicitly — `select("*")` is rejected for Partner queries.

### 4. `syncStatus` in payloads
**Ambiguity:** Not explicitly called out in privacy docs, but it's a local implementation field with no business meaning to Supabase.
**Resolution:** Treated as a local-only field that must never appear in any Supabase payload. Documented in skill's payload construction rules.

---

## Key Enforcement Rules Encoded

1. Privacy precedence hierarchy: isPrivate → is_paused → sex exclusion → share_* → RLS (in this order, all enforced)
2. `isPrivate = true` → zero data from that day in any Partner payload (client-side AND query filter)
3. `symptom_type == .sex` → excluded from every Partner-facing payload and query, unconditionally
4. Partner queries use explicit column projection matching enabled `share_*` flags — no `select("*")`
5. RLS is defense-in-depth, not the sole privacy control — client code must be safe without RLS
6. Partner client is read-only — no writes to Tracker tables
7. Separate DTOs for Tracker write path and Partner read path
8. `syncStatus` is a local-only field — never included in Supabase payloads
9. Privacy logic must be centralised — not scattered in UI components or ad-hoc serializers
10. Sex symptom is stored for Tracker history but filtered from all Partner exposure at both client and server layers
