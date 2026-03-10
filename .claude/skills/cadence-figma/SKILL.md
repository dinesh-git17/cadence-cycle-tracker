---
name: cadence-figma
description: Bridges the Cadence Figma file (h3DwhdSjoP29U0VcCVRfTG — Design System & Screens) to SwiftUI implementation. Governs all design-to-code translation for Cadence: pulling live node design context via the Figma MCP before implementing any UI, translating raw Figma values (hex colors, point sizes, numeric spacings) into Cadence token references, and managing Code Connect mappings for implemented SwiftUI components. Always use this skill when implementing any Cadence screen or component derived from Figma — even when the request is stated as "build the home screen", "implement the chip", or "make it match the design". Triggers on: Figma URL inspection for any Cadence view, raw hex color appearing in SwiftUI source, spacing value or corner radius lookup, Code Connect mapping for any Cadence component, drift between Figma file and locked design spec, screen fidelity audit, or any question about which token or component structure a Figma node should map to. Do not skip this skill for "simple" components — every Figma-derived SwiftUI view requires MCP inspection before implementation.
---

# cadence-figma

Authoritative governance layer for translating the Cadence Figma file into SwiftUI. This skill owns:

- Node inspection requirements via the Figma MCP
- Token translation rules (raw Figma values → Cadence token references)
- Code Connect mapping discipline for implemented SwiftUI components
- Drift detection and resolution between Figma, the locked design spec, and the codebase

**Locked Figma file:** `h3DwhdSjoP29U0VcCVRfTG` — "Cadence — Design System & Screens"
**File URL base:** `https://www.figma.com/design/h3DwhdSjoP29U0VcCVRfTG/Cadence-%E2%80%94-Design-System---Screens?node-id=NODE_ID`
**Design contract:** `docs/Cadence_Design_Spec_v1.1.md` is the locked authority. Figma is the visual ground truth. When they conflict, document and resolve conservatively — do not silently normalize either source.
**PDF fallback:** `docs/Cadence — Design System & Screens.pdf` — use when MCP budget is exhausted.

---

## 1. Figma MCP Usage

### Required Before Implementation

Before implementing or modifying any Cadence SwiftUI view that derives its layout, spacing, color, or component structure from a Figma design:

1. Call `get_design_context` with the target `nodeId` and `fileKey=h3DwhdSjoP29U0VcCVRfTG`.
2. Call `get_screenshot` with the same parameters for visual ground truth.
3. Translate all returned raw values to Cadence token references before writing any Swift.

Never implement Figma-driven UI from memory, doc inference alone, or screenshots without prior MCP inspection. The `get_design_context` call is mandatory — not optional.

### Rate Limit Awareness

The connected account (Starter/View plan) receives **6 Figma MCP tool calls per month**. This is a shared monthly budget.

Spend calls efficiently:
- Use `get_metadata` first on large frames to map child nodes, then call `get_design_context` on specific children.
- Do not call `get_design_context` on entire page roots — target the component or section being implemented.
- Token lookup never requires an MCP call — use `references/token-translation.md`.
- `get_screenshot` counts against the limit — call once per implementation session.

**Dev Mode is unavailable** (requires a paid Figma plan). The desktop MCP server therefore cannot be used. The remote MCP is rate-limited to 6 calls/month (currently exhausted).

**Always ask Dinesh for a screenshot of the relevant screen or component before implementing any UI.** This is the primary visual reference path. Ask specifically: "Can you share a screenshot of the [screen/component name] from Figma?" Do not proceed with implementation based on doc inference alone.

Fallback when no screenshot is available: use the PDF export at `docs/Cadence — Design System & Screens.pdf` for visual reference and apply token translation manually. Add a code comment: `// Visual reference: Cadence — Design System & Screens.pdf. Screenshot unavailable.`

### MCP Call Pattern

```
fileKey: h3DwhdSjoP29U0VcCVRfTG
nodeId:  extracted from Figma URL — convert 1-2 URL format to 1:2 for tool calls

clientLanguages:   "swift"
clientFrameworks:  "swiftui"
```

Correct call sequence per component:
1. `get_design_context(fileKey="h3DwhdSjoP29U0VcCVRfTG", nodeId="X:Y", clientLanguages="swift", clientFrameworks="swiftui")`
2. `get_screenshot(fileKey="h3DwhdSjoP29U0VcCVRfTG", nodeId="X:Y")`
3. Translate all values via §2 rules
4. Implement in SwiftUI, validate against screenshot

---

## 2. Token Translation

The Figma MCP returns raw values: hex strings, numeric point sizes, integer spacings. **Raw values must never appear in SwiftUI source when a sanctioned Cadence token exists.** Translate before writing a single line of Swift.

Full lookup tables are in `references/token-translation.md`. Core rules follow.

### 2.1 Color Translation

| MCP returns (light mode hex) | SwiftUI token |
|---|---|
| `#C07050` | `Color("CadenceTerracotta")` |
| `#F5EFE8` | `Color("CadenceBackground")` |
| `#FFFFFF` on card/surface | `Color("CadenceCard")` |
| `#7A9B7A` | `Color("CadenceSage")` |
| `#EAF0EA` | `Color("CadenceSageLight")` |
| `#1C1C1E` | `Color("CadenceTextPrimary")` |
| `#6C6C70` | `Color("CadenceTextSecondary")` |
| `#FFFFFF` on terracotta fill | `Color("CadenceTextOnAccent")` |
| `#E0D8CF` | `Color("CadenceBorder")` |
| system red | `Color(.systemRed)` |

Dark mode counterparts (`#D4896A`, `#1C1410`, `#2A1F18`, etc.) map to the same token — they are encoded in the xcassets color asset, not in Swift source. Never use conditional dark/light hex logic in Swift.

**Known unresolved gap — `CadencePrimary`:** The design spec §7 references `CadencePrimary` (`#1C1410` light / `#F2EDE7` dark) for the paused sharing strip. This token is not defined in §3 of the locked color table. Do not hardcode the hex value. Do not invent the token asset without designer confirmation. Flag implementation of the paused sharing strip state as blocked pending resolution.

### 2.2 Typography Translation

| If MCP returns | Use Cadence token | SwiftUI style |
|---|---|---|
| 34pt Semibold | `display` | `.font(.largeTitle).fontWeight(.semibold)` |
| 28pt Semibold | `title1` | `.font(.title).fontWeight(.semibold)` |
| 22pt Regular | `title2` | `.font(.title2)` |
| 20pt Medium | `title3` | `.font(.title3).fontWeight(.medium)` |
| 17pt Semibold | `headline` | `.font(.headline)` |
| 17pt Regular | `body` | `.font(.body)` |
| 16pt Regular | `callout` | `.font(.callout)` |
| 15pt Regular | `subheadline` | `.font(.subheadline)` |
| 13pt Regular | `footnote` | `.font(.footnote)` |
| 12pt Regular | `caption1` | `.font(.caption)` |
| 11pt Regular | `caption2` | `.font(.caption2)` |
| 48pt Medium Rounded | countdown numeral | `.font(.system(size: 48, weight: .medium, design: .rounded))` |

The 48pt countdown numeral is the **only** sanctioned use of `.system(size:weight:design:)`. All other text must use Dynamic Type tokens.

### 2.3 Spacing Translation

| MCP value | Swift constant | Usage |
|---|---|---|
| 4pt | `CadenceSpacing.space4` | Icon-to-label clearance |
| 8pt | `CadenceSpacing.space8` | Chip grid interior, compact sections |
| 12pt | `CadenceSpacing.space12` | Related element separation within card |
| 16pt | `CadenceSpacing.space16` | Standard screen margin, content inset |
| 20pt | `CadenceSpacing.space20` | Card internal padding |
| 24pt | `CadenceSpacing.space24` | Major section breaks in scroll view |
| 32pt | `CadenceSpacing.space32` | Between distinct cards in feed |
| 44pt | `CadenceSpacing.space44` | Minimum touch target size |

If the MCP returns a spacing value not in this list (e.g. 6pt, 10pt, 14pt), do not use it as a magic number. Round to the nearest sanctioned token and document the rounding in a code comment, or flag it as Figma drift requiring designer review.

### 2.4 Corner Radius Translation

| Component | Value | SwiftUI form |
|---|---|---|
| DataCard, InsightCard | 16pt | `.cornerRadius(16)` |
| Symptom chips, flow chips, badges | capsule | `.clipShape(Capsule())` |
| Primary CTA button | 14pt | `.cornerRadius(14)` |
| Input fields | 10pt | `.cornerRadius(10)` |
| Period toggle buttons | 12pt | `.cornerRadius(12)` |
| Calendar day cells | 10pt | `.cornerRadius(10)` |
| Sharing status strip | 12pt | `.cornerRadius(12)` |
| Log Sheet / bottom sheet | 20pt top-only | System sheet — do not override |
| Tab bar | System (Liquid Glass) | System — do not override |

Any corner radius value from the MCP not in this table is Figma drift. Do not implement it — resolve to the nearest sanctioned value or flag for designer confirmation.

---

## 3. Node-to-Component Mapping

The Figma file contains a design system section (components, variants, tokens) and a screens section (full-screen mocks). See `references/component-map.md` for the complete registry.

### Core Component Conventions

| Figma component name | Expected SwiftUI file | Key parameters |
|---|---|---|
| Symptom Chip / Chip | `Cadence/Views/Components/SymptomChip.swift` | `isSelected: Bool`, `isReadOnly: Bool` |
| Flow Level Chip | `Cadence/Views/Components/FlowLevelChip.swift` | Same capsule shape as SymptomChip |
| Period Toggle Button | `Cadence/Views/Components/PeriodToggleButton.swift` | Equal-width pair, 12pt radius |
| Primary CTA Button | `Cadence/Views/Components/PrimaryCTAButton.swift` | Full-width, 14pt radius, 50pt height |
| Data Card | `Cadence/Views/Components/DataCard.swift` | `style: DataCardStyle` — `.standard` / `.insight` |
| Sharing Status Strip | `Cadence/Views/Components/SharingStatusStrip.swift` | `.active` / `.paused` states |
| Countdown Card | `Cadence/Views/Components/CountdownCard.swift` | Paired 48pt numeral cards |
| Cycle Status Card | `Cadence/Views/Components/CycleStatusCard.swift` | Phase name, confidence badge, day label |

**Naming rule:** SwiftUI struct names must match Figma component names semantically. `Symptom Chip` in Figma → `SymptomChip` struct in Swift. Renaming requires a documented deviation entry in `references/component-map.md`.

**Chip symptom inventory (confirmed from Figma file):**
Cramps, Headache, Bloating, Mood change, Fatigue, Acne, Discharge, Exercise, Poor sleep, Sex (lock icon permanent regardless of state).

**Flow level inventory (confirmed from Figma file):**
Spotting, Light, Medium, Heavy.

### Screen Frames Confirmed in File

See `references/screen-inventory.md` for the full list. Confirmed frame categories:

- **Auth flow:** Sign in screen, Role selection ("I track my cycle" / "My partner tracks their cycle"), Cycle setup (onboarding)
- **Tracker:** Home Dashboard (active state), Home Dashboard (loading), Log Sheet, Calendar, Reports, Reports empty state, Settings
- **Connection flow:** Invite Partner (code share), Enter partner code, Confirm Connection (permission checklist)
- **Partner:** Her Dashboard (active), Her Dashboard (sharing paused), Her Dashboard (all categories off), Partner Notifications, Partner Settings

---

## 4. Code Connect Governance

### Plan Constraint

Code Connect CLI requires an Organization or Enterprise Figma plan. The current account (Starter/View) does not support it. The `send_code_connect_mappings` MCP tool additionally requires published components in a team library, which requires a paid plan.

**Current state:** Maintain component mappings locally in `references/component-map.md`. When the Figma account is upgraded to Organization or Enterprise:
1. Publish all design system components to the team library.
2. Migrate entries from `references/component-map.md` to live `send_code_connect_mappings` calls.

### Mapping Protocol (when Code Connect is active)

For each implemented SwiftUI component, create a Code Connect mapping immediately after the component ships — not in a batch later:

```
send_code_connect_mappings(
  fileKey="h3DwhdSjoP29U0VcCVRfTG",
  nodeId="FIGMA_COMPONENT_NODE_ID",
  mappings=[{
    nodeId: "FIGMA_COMPONENT_NODE_ID",
    componentName: "SymptomChip",
    source: "Cadence/Views/Components/SymptomChip.swift",
    label: "SwiftUI"
  }]
)
```

Rules:
- `componentName` must exactly match the Swift struct name as exported.
- `source` must be the path relative to the project root.
- When a component is renamed or moved in the codebase, update the mapping immediately.
- A stale mapping (pointing to a non-existent file) is a harder failure than no mapping — it actively misleads the MCP context. Remove or correct before the next sync.

### Local Registry

Until Code Connect is active, `references/component-map.md` is the mapping registry. Every newly implemented SwiftUI component that corresponds to a Figma component gets an entry added immediately — not batched. The registry is the handoff contract between design and code.

---

## 5. Drift Detection and Resolution

Drift exists when any of these three sources disagree:
1. `docs/Cadence_Design_Spec_v1.1.md` — locked design contract
2. Figma file `h3DwhdSjoP29U0VcCVRfTG` — visual ground truth
3. SwiftUI codebase — implementation reality

### Detection Triggers

During any MCP inspection or implementation review, compare:
- Color hex values: MCP output vs. spec §3 table vs. xcassets definition
- Spacing values: MCP points vs. spec §5 tokens vs. Swift constants
- Component structure: Figma variants vs. Swift enum cases / initializer parameters
- Component naming: Figma component name vs. Swift struct name
- Corner radii: MCP values vs. spec §6 table

### Resolution Rules

| Conflict type | Resolution |
|---|---|
| Figma value differs from locked spec | Spec is authoritative. Treat Figma as stale. Do not implement the Figma value without designer sign-off. |
| Spec references a token not in §3 color table | Block implementation. Flag as gap (see `CadencePrimary`). Await designer confirmation. |
| Swift source uses raw hex/number when token exists | Hard violation — replace with token unconditionally. |
| Figma structure differs from implemented Swift component | Document deviation in a code comment citing both sources. Update `references/component-map.md`. |
| Naming mismatch between Figma and Swift | Prefer Figma naming unless there is a documented override in `references/component-map.md`. |

Never silently normalize drift. Every unresolved discrepancy requires either a resolution commit or an explicit `// DESIGN DRIFT: [description] — awaiting resolution` comment.

---

## 6. Anti-Patterns (Blocking)

These are hard rejections caught in review and must be corrected before any PR merges:

1. **Implementing Figma-driven UI without calling `get_design_context` first.** Memory, doc inference, and screenshots alone are not substitutes.

2. **Raw hex values in SwiftUI.** Any `Color(hex: "#C07050")`, `.foregroundColor(.init(red: ...))`, or literal hex string in Swift source when a `Color("Cadence*")` token exists.

3. **Magic spacing numbers.** `.padding(12)`, `.spacing(8)`, `.frame(width: 32)` without a `CadenceSpacing` constant reference.

4. **Unsanctioned corner radii.** `cornerRadius(15)`, `cornerRadius(6)`, or any value not present in §2.4. "Close enough" is not acceptable.

5. **Inventing Figma node names.** Never reference a Figma component name not confirmed in the actual file via MCP inspection or PDF export. The spec describes intent — Figma names the components.

6. **Stale Code Connect mappings.** Any mapping whose `source` path does not exist in the codebase must be corrected or removed before the next sync. Stale mappings corrupt the MCP context window.

7. **Silencing discrepancies.** If a Figma value conflicts with the spec, the conflict must be documented — never resolved by silently picking one.

8. **Implementing `CadencePrimary` paused-strip color without designer confirmation.** This is an explicitly flagged open gap. The color values are known but the token is not yet sanctioned in the design spec.

---

## 7. Implementation Checklist

Before marking any Figma-derived screen or component implementation complete:

- [ ] `get_design_context` called for the relevant Figma node
- [ ] `get_screenshot` captured and compared against final implementation
- [ ] All colors resolve to `Color("Cadence*")` tokens — zero hex literals in Swift source
- [ ] All spacing resolves to `CadenceSpacing` constants — zero magic numbers
- [ ] All typography uses Dynamic Type tokens (or the single sanctioned `.system(size: 48, ...)` exception)
- [ ] All corner radii match the §2.4 table exactly
- [ ] Component naming matches Figma (or deviation is documented)
- [ ] `references/component-map.md` updated if a new component was implemented
- [ ] Drift between Figma, spec, and code is resolved or flagged
- [ ] `cadence-design-system` skill checklist also cleared (this skill does not replace it — both must pass)

---

## Reference Files

Read these when the SKILL.md inline tables are insufficient:

- `references/token-translation.md` — Full color, typography, spacing, and radius lookup tables including all dark-mode hex values
- `references/component-map.md` — Component registry: Figma node name → SwiftUI file path, status, and known deviations
- `references/screen-inventory.md` — All confirmed screen frames in the Figma file with frame names from PDF inspection
