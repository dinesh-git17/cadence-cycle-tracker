# cadence-figma Skill — Creation Notes

**Created:** March 7, 2026
**Skill location:** `.claude/skills/cadence-figma/`
**Skill creator path reviewed:** `.claude/skills/skill-creator/SKILL.md`

---

## Local Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure, SKILL.md format, frontmatter requirements, progressive disclosure model, reference file conventions |
| `docs/Cadence_Design_Spec_v1.1.md` | Locked design contract v1.1 — all token definitions, component specs, screen specs |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — product context, component inventory, partner sharing model |
| `docs/Cadence — Design System & Screens.pdf` | Figma PDF export — visual screen inventory, frame names, chip/component content (extracted via `pdftotext` after installing poppler) |

---

## Figma File Inspected

| Property | Value |
|---|---|
| File key | `h3DwhdSjoP29U0VcCVRfTG` |
| File name | Cadence — Design System & Screens |
| Account | dinbuilds / dind.dev@gmail.com |
| Plan | Starter / View seat |
| MCP calls available | 6 per month |
| MCP calls used this session | ~5 (whoami ×2 rate-exempt, 1 failed probe, 1 successful auth, 1 rate-limited) |
| Direct MCP inspection achieved | Partial — account hit monthly limit before `get_metadata` succeeded. File structure obtained via PDF export (`pdftotext`). |

### Figma MCP Attempts Log

1. `mcp__figma-remote-mcp__whoami` → success (rate-exempt), confirmed account
2. `mcp__figma-remote-mcp__get_metadata(fileKey="cadence", nodeId="")` → failed (invalid file key)
3. `mcp__claude_ai_Figma__whoami` → success (rate-exempt), confirmed same account
4. `mcp__figma-remote-mcp__get_metadata(fileKey="h3DwhdSjoP29U0VcCVRfTG", nodeId="0:1")` → rate limit exhausted

**Resolution:** Used `pdftotext` on the PDF export to extract all visible text content from screen frames, providing sufficient context for node naming, chip inventory, screen structure, and component state enumeration.

---

## Authoritative Sources Used

### Claude Code Skill Standards (Anthropic)
- `skill-creator` SKILL.md at `.claude/skills/skill-creator/SKILL.md` — primary authority for skill structure, frontmatter format, progressive disclosure model (metadata → SKILL.md body → references), and 500-line limit for SKILL.md body

### Figma / Code Connect / Design-to-Code Guidance
- `file://figma/docs/code-connect-integration.md` (Figma MCP resource) — Code Connect CLI vs. UI mapping behavior, CodeConnectSnippet structure, plan requirements
- `file://figma/docs/skill-code-connect-components.md` (Figma MCP resource) — `send_code_connect_mappings` API, label values for SwiftUI (`"SwiftUI"`), workflow: `get_code_connect_suggestions` → scan → `send_code_connect_mappings`
- `file://figma/docs/skill-implement-design.md` (Figma MCP resource) — `get_design_context` → `get_screenshot` → translate → validate workflow
- `file://figma/docs/plans-access-and-permissions.md` (Figma MCP resource) — rate limit documentation (6 calls/month for Starter/View)
- `file://figma/docs/local-server-installation.md` (Figma MCP resource) — how the desktop MCP works (selection-based vs. link-based), Claude Code integration pattern

---

## Key Facts Extracted

### From Design Spec v1.1

**Color tokens (10):**
CadenceBackground, CadenceCard, CadenceTerracotta, CadenceSage, CadenceSageLight, CadenceTextPrimary, CadenceTextSecondary, CadenceTextOnAccent, CadenceBorder, CadenceDestructive

**Typography tokens (11):**
display (.largeTitle/34pt/Semibold), title1 (.title/28pt/Semibold), title2 (.title2/22pt), title3 (.title3/20pt), headline (.headline/17pt), body (.body/17pt), callout (.callout/16pt), subheadline (.subheadline/15pt), footnote (.footnote/13pt), caption1 (.caption/12pt), caption2 (.caption2/11pt)

**Single exception:** 48pt `.system(size: 48, weight: .medium, design: .rounded)` for countdown numerals.

**Spacing tokens (8):** 4, 8, 12, 16, 20, 24, 32, 44pt — named via `CadenceSpacing` enum

**Corner radii:** cards=16pt, chips=capsule, CTA=14pt, inputs=10pt, period toggles=12pt, calendar cells=10pt, sharing strip=12pt, sheets=system/20pt top-only

**Component library:** SymptomChip, Period Toggle Buttons, Primary CTA Button, Data Card, Sharing Status Strip — all fully specced with state/token/layout details

### From Figma PDF Export

**18 confirmed screen frames:**
- Auth, Role Selection, Cycle Setup
- Tracker: Home (active + loading), Log Sheet, Calendar, Reports (active + empty), Settings, Invite Partner
- Connection: Confirm Connection, Partner Code Entry
- Partner: Her Dashboard (active + paused + no-sharing), Partner Notifications, Partner Settings

**10 symptom chips confirmed:** Cramps, Headache, Bloating, Mood change, Fatigue, Acne, Discharge, Exercise, Poor sleep, Sex

**4 flow chips confirmed:** Spotting, Light, Medium, Heavy

**6 sharing permission categories confirmed:** Period predictions, Cycle phase, Symptoms, Mood, Fertile window, Daily notes (all default off; Sex never included in any sync payload)

**Report stats visible on screen:** Avg 29d cycle (SD 1.2d), avg 5d period, "Regular" consistency, symptom frequency by phase (Cramps 85%, Bloating 55%, Headache 32%)

### Repository Structure (Pre-Implementation)
- No Swift files exist yet — full pre-implementation phase
- No Code Connect files exist
- No token constant files exist
- Expected structure: `Cadence/Views/Components/`, `Cadence/Views/Tracker/`, `Cadence/Views/Partner/`, `Cadence/Views/Auth/`, `Cadence/Views/Onboarding/`

---

## Ambiguities and Conflicts Found

### 1. CadencePrimary Token Gap (Existing, Confirmed)
**Conflict:** §7 Elevation table references `CadencePrimary (#1C1410 light / #F2EDE7 dark)` for the paused sharing strip background. This token is not defined in §3 Color table and does not exist as a named asset.
**Resolution:** Flagged in skill as a hard block. Implementation of the paused sharing strip state requires designer confirmation before the token is created in xcassets. Hex values are known; the token name and asset are not confirmed.

### 2. Figma Node IDs Not Obtained
**Conflict:** The MCP budget was exhausted before `get_metadata` could return the page/component node map. Node IDs for all Figma components are listed as TBD in `references/component-map.md` and `references/screen-inventory.md`.
**Resolution:** Documented as TBD with the MCP call pattern required to populate them. Engineers must call `get_metadata(fileKey="h3DwhdSjoP29U0VcCVRfTG", nodeId="0:1")` in the next budget period to populate node IDs before Code Connect mapping work begins.

### 3. Code Connect Not Available on Current Plan
**Conflict:** Code Connect CLI and `send_code_connect_mappings` MCP tool both require Organization or Enterprise plan. Account is Starter/View.
**Resolution:** Skill documents this constraint explicitly. Local `references/component-map.md` registry serves as the mapping substrate until the plan is upgraded. Migration path is fully specified in the registry file.

### 4. Figma Component Names vs. SwiftUI Names
**Conflict:** No Swift source exists yet, so actual naming conventions are not established. Figma uses human-readable names with spaces ("Symptom Chip", "Primary CTA Button"). Swift requires PascalCase without spaces.
**Resolution:** Skill specifies the mapping rule: convert Figma names to PascalCase Swift struct names (e.g., "Symptom Chip" → `SymptomChip`). Any deviations from this mechanical conversion must be documented in `references/component-map.md`.

### 5. Figma "Design System" Section Structure Unknown
**Conflict:** The file name implies a Design System section with component definitions, but without MCP access, component node IDs and variant properties are unknown.
**Resolution:** Screen-level content was obtained from the PDF. Component node IDs marked TBD. The skill provides the token translation tables as a local fallback so that implementation can proceed without burning MCP calls on token lookup.

---

## Key Enforcement Rules Encoded in Skill

1. `get_design_context` is mandatory before implementing any Figma-derived UI — not optional
2. Raw hex values are blocked in SwiftUI source when a `Color("Cadence*")` token exists
3. Raw spacing numbers are blocked in SwiftUI when a `CadenceSpacing` constant covers the value
4. Corner radii must match the §2.4 table in SKILL.md exactly — "close enough" is rejected
5. `CadencePrimary` paused strip implementation is hard-blocked pending designer confirmation
6. Code Connect mappings must be updated immediately on component rename/move — stale mappings are actively harmful
7. Drift between Figma, spec, and code must be documented, not silently resolved
8. Sex chip is never shareable — confirmed from both the spec and the Figma screen ("never includes sex")
9. MCP rate limit (6 calls/month) requires strategic call planning — token lookup must use local tables, not MCP calls
10. `cadence-design-system` skill checklist must also be cleared — cadence-figma governs the Figma bridge, not the full design system contract
