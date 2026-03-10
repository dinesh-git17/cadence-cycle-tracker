---
name: epic-decomposer
description: Decomposes docs/PHASES.md into implementation-ready epic documents saved to docs/PH-[#]/[order]-[name].md. Use this skill whenever the user asks to generate epics from PHASES.md, break a phase into epics, create epic documents, write implementation plans from the phase map, or produce story-level planning artifacts for any Cadence phase. Also triggers on "decompose phase", "epic breakdown", "write epics for phase N", "generate all epics", "planning artifacts from PHASES.md", or any request to turn the phase plan into actionable engineering work. This is the mandatory bridge between PHASES.md and implementation -- no epic document should be written without activating this skill first.
---

# Epic Decomposer

Transforms `docs/PHASES.md` into a complete set of implementation-ready epic documents. Each epic is a self-contained planning artifact with stories, acceptance criteria, story points, dependencies, and a Definition of Done.

## When This Skill Applies

Use this skill when:

- Dinesh asks to generate epics from `docs/PHASES.md`
- Dinesh asks to break a specific phase into epics
- Dinesh asks to create implementation plans, epic documents, or story breakdowns for any phase
- Dinesh asks to "plan phase N" or "write epics for phase N"
- Dinesh asks to generate all epics across all phases
- Any task requires converting phase-level scope into engineering work items

Do not use this skill to:

- Create or modify `docs/PHASES.md` itself (use `phase-planner` skill)
- Write sprint plans or task-level tickets
- Modify design specs or design docs
- Generate code or implementation artifacts

## Required Inputs

1. **`docs/PHASES.md`** -- the canonical phase map. Must exist and be read before any epic is written.
2. **Phase number(s)** -- which phase(s) to decompose. If not specified, ask Dinesh which phase to start with. Do not generate all 15 phases without explicit instruction.
3. **Source documents** -- `docs/CADENCE_DESIGN_DOCS/` contains the design spec (v1.1, locked), design doc (MVP PRD v1.0), MVP spec, and splash screen spec. Read the sections referenced by the target phase before writing epics.

## Optional Inputs

- Dinesh may provide additional context, scope refinements, or explicit epic boundaries.
- If a phase has a known blocker (documented in PHASES.md Phase Notes), Dinesh may provide a resolution or instruct to proceed with the blocker noted.

## Outputs

For each phase decomposed, this skill produces:

- A directory `docs/PH-[#]/` (created if it does not exist)
- One markdown file per epic: `docs/PH-[#]/[order]-[epic-name].md`
- Each file follows the Epic Document Template defined below

---

## Operating Procedure

Follow this sequence exactly. Do not skip steps. Do not reorder.

### Step 1: Read the Phase

Read `docs/PHASES.md`. Locate the target phase in both the Phase Table and Phase Notes sections. Extract:

- Primary goal
- In-scope items (complete list)
- Out-of-scope items
- Dependencies on prior phases
- Estimated epic count
- Source references
- Likely epics (from Phase Notes)
- Known blockers or ambiguities

### Step 2: Read Source Documents

Read every source document section referenced by the target phase. Extract:

- Feature specifications relevant to each likely epic
- Data models, API surfaces, or schema definitions
- UI component specifications, interaction patterns
- Acceptance criteria implied by the spec
- Open items or ambiguities that affect scope

If a referenced section is ambiguous or contradicts another source, HALT and ask Dinesh.

### Step 3: Determine Epic Boundaries

Decompose the phase into epics using these rules:

**One epic = one coherent implementation workstream.** An epic should represent a body of work that:

- Has a single clear objective
- Can be implemented, tested, and verified as a unit
- Produces a tangible, demonstrable outcome
- Would be assigned to one engineer (or one pair) without needing to split across unrelated subsystems

**Decomposition method -- capability-based by default:**

- Each epic delivers a distinct system capability or UI surface
- Split by architectural boundary (data layer vs. UI vs. network vs. infrastructure)
- Split by user-facing concern (one screen, one flow, one component family)

**Sizing constraints:**

- Minimum: An epic must contain at least 3 stories. Fewer means the epic is really just a story -- merge it into an adjacent epic.
- Maximum: An epic should contain no more than 10 stories. More means the epic is too broad -- split it.
- Target: 4-8 stories per epic.

**Boundary rules:**

- Epics must stay inside their parent phase boundary. No epic pulls work from another phase.
- Epics must not duplicate work done in another epic within the same phase.
- The union of all epics in a phase must fully cover the phase's in-scope list.
- When all epics of a phase are done, that phase's primary goal must be achieved.

**Use the "likely epics" from Phase Notes as a starting point**, but do not treat them as final. They are guidance, not constraints. If the source documents reveal a better decomposition, use it.

### Step 4: Write Epic Documents

For each epic, create a file following the Epic Document Template (below). Write all sections. Do not leave placeholders, stubs, or TODOs.

### Step 5: Validate Coverage

After writing all epics for a phase:

1. List every in-scope item from the Phase Table
2. For each item, identify which epic covers it
3. If any in-scope item is not covered by any epic, add it to the correct epic or create a new one
4. If any epic contains work not listed in the phase's in-scope, remove it or confirm it is implied by a source document reference
5. Verify the epic count matches the estimated range in PHASES.md (within +/-1)

### Step 6: Write Files

- Create `docs/PH-[#]/` if it does not exist
- Write each epic file to `docs/PH-[#]/[order]-[epic-name].md`
- Run `scripts/protocol-zero.sh` and `scripts/check-em-dashes.sh`
- Fix any violations before declaring done

---

## Epic Document Template

Every epic file must contain exactly these sections in this order.

```markdown
# [Epic Title]

**Epic ID:** PH-[phase#]-E[epic-order]
**Phase:** [phase#] -- [phase name]
**Estimated Size:** [S / M / L / XL]
**Status:** Draft

---

## Objective

[1-3 sentences. What this epic accomplishes and why it matters to the phase goal.
Must be specific enough that completion is verifiable.]

## Problem / Context

[Why this epic exists. What gap in the system it fills. What breaks or is
missing without it. Reference the source document sections that define the need.]

## Scope

### In Scope

- [Concrete item 1]
- [Concrete item 2]
- [...]

### Out of Scope

- [Concrete exclusion 1 -- state why it is excluded or which phase/epic owns it]
- [...]

## Dependencies

| Dependency       | Type             | Phase/Epic            | Status          | Risk              |
| ---------------- | ---------------- | --------------------- | --------------- | ----------------- |
| [What is needed] | [FS/SS/External] | [PH-X-EY or external] | [Open/Resolved] | [Low/Medium/High] |

**Dependency types:**

- FS (Finish-to-Start): Must complete before this epic starts
- SS (Start-to-Start): Must start before this epic starts
- External: Outside the repository (designer confirmation, third-party API, etc.)

## Assumptions

- [Assumption 1 -- state what is assumed true without verification]
- [...]

## Risks

| Risk               | Likelihood        | Impact            | Mitigation            |
| ------------------ | ----------------- | ----------------- | --------------------- |
| [Risk description] | [Low/Medium/High] | [Low/Medium/High] | [Mitigation strategy] |

---

## Stories

### S1: [Story Title]

**Story ID:** PH-[phase#]-E[epic-order]-S1
**Points:** [1/2/3/5/8/13]

[1-3 sentence description of what this story delivers and why.]

**Acceptance Criteria:**

- [ ] [Criterion 1 -- independently testable, binary pass/fail]
- [ ] [Criterion 2]
- [ ] [...]

**Dependencies:** [None, or PH-X-EY-SZ]
**Notes:** [Implementation constraints, edge cases, or references. Omit if none.]

### S2: [Story Title]

[Same structure as S1. Repeat for all stories.]

---

## Story Point Reference

Points use the Fibonacci scale and represent relative effort within this project:

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
- [ ] Integration with dependencies verified end-to-end
- [ ] Phase objective is advanced (this epic's contribution is demonstrable)
- [ ] Applicable skill constraints satisfied ([list specific skills])
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] [If Swift code] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] [If UI code] Accessibility requirements verified per cadence-accessibility skill
- [ ] [If data layer code] Offline-first write path verified
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified (no drift from design spec or design doc)

## Source References

- PHASES.md: Phase [#] -- [phase name]
- [Design Spec v1.1 section(s)]
- [Design Doc section(s)]
- [MVP Spec section(s)]
- [Other source document references]
```

---

## File Naming Rules

**Path:** `docs/PH-[#]/[order]-[epic-name].md`

- `[#]` = phase number, zero-indexed, no zero-padding (0, 1, 2, ... 14)
- `[order]` = integer position within the phase, starting at 1
- `[epic-name]` = lowercase kebab-case, concise, descriptive of the primary workstream
- No spaces, underscores, or special characters in filenames
- Filenames must be stable -- once assigned, they do not change unless the epic is fundamentally restructured

**Examples:**

```
docs/PH-0/1-xcodegen-project-scaffold.md
docs/PH-0/2-color-token-assets.md
docs/PH-0/3-ci-workflow-skeleton.md
docs/PH-0/4-enforcement-scripts.md
docs/PH-1/1-supabase-project-setup.md
docs/PH-1/2-schema-migration.md
docs/PH-1/3-rls-policies.md
docs/PH-1/4-auth-provider-config.md
docs/PH-4/1-tracker-tabview-shell.md
docs/PH-4/2-log-sheet.md
docs/PH-4/3-symptom-chip-component.md
```

**Directory creation:** If `docs/PH-[#]/` does not exist, create it before writing epic files for that phase.

---

## Decomposition Quality Rules

### Epics must not:

- **Be mini-phases.** If an epic has its own multi-step dependency chain and 10+ stories, it is too large. Split it.
- **Be dressed-up stories.** If an epic has fewer than 3 stories and takes less than a day, it is too small. Merge it.
- **Mix unrelated systems.** An epic covering both "SwiftData schema" and "Calendar UI rendering" conflates two distinct concerns.
- **Leak across phases.** An epic in Phase 4 must not include work scoped to Phase 5 in PHASES.md.
- **Duplicate work.** Two epics in the same phase must not both implement the same component, API, or data model.
- **Contain speculative scope.** Every story in an epic must trace to a source document or an in-scope item in PHASES.md.

### Epics must:

- **Have a single clear objective** that is a subset of the phase's primary goal
- **Be independently verifiable** -- an engineer can confirm the epic is done without waiting for other epics in the phase
- **Cover the full in-scope list** when combined with sibling epics in the same phase
- **Respect the dependency graph** -- if epic 2 depends on epic 1, order them accordingly

### Stories must:

- **Be completable in 1-3 days.** Stories estimated above 8 points should be scrutinized for splitting opportunities.
- **Deliver an observable outcome.** A finished story should change what is testable, visible, or measurable.
- **Have testable acceptance criteria.** Every criterion must be binary pass/fail. No "should work well" or "looks good."
- **Not duplicate acceptance criteria from other stories.** If two stories share a criterion, one of them is redundant.

---

## Story Point Calibration

All epics in this project use the same Fibonacci scale. Consistency is enforced by including the Story Point Reference table in every epic document.

**Calibration anchors for Cadence:**

| Points | Cadence Example                                                             |
| ------ | --------------------------------------------------------------------------- |
| 1      | Add a single color token to xcassets with light/dark variants               |
| 2      | Implement one SymptomChip visual state (selected appearance)                |
| 3      | Build the PeriodToggle component with tap handling and animation            |
| 5      | Implement the full Log Sheet layout with period type selection and save CTA |
| 8      | Build the prediction algorithm with 3 confidence tiers and all edge cases   |
| 13     | Full SyncCoordinator with write queue, conflict resolution, and retry logic |

---

## Anti-Hallucination Rules

- Do not invent features, screens, or components not present in source documents
- Do not infer acceptance criteria beyond what the design spec and design doc specify
- Do not assume API signatures, data model fields, or UI layouts without reading the relevant spec section
- Do not assign story points based on vibes -- use the calibration anchors above
- If a source document is ambiguous about a story's scope, flag it in the story's Notes field and mark the acceptance criteria as "pending spec clarification"
- If PHASES.md Phase Notes names a "likely epic" but the source documents do not support it as a distinct workstream, merge it into an adjacent epic and note the merge decision

## Failure Conditions

Refuse to produce output if any of the following apply:

- `docs/PHASES.md` does not exist or has not been read
- The target phase's source document references have not been read
- An in-scope item from the Phase Table has no covering epic
- An epic contains work from outside the target phase's scope
- A story has no acceptance criteria
- A story has acceptance criteria that are not independently testable
- The DoD section is missing or incomplete
- Any epic file would contain placeholder text ("TODO", "TBD", "implement later")

---

## Validation Checklist

Run this checklist after generating all epics for a phase. Every item must pass.

### Coverage

- [ ] Every in-scope item from PHASES.md Phase Table has a covering story in at least one epic
- [ ] No epic contains work from outside the phase's in-scope list (unless justified by a source document)
- [ ] The union of all epics fully achieves the phase's primary goal

### Boundaries

- [ ] No epic pulls work from a different phase
- [ ] No two epics in the same phase duplicate the same work
- [ ] Each epic has a single clear objective

### Structure

- [ ] Every epic file follows the Epic Document Template exactly
- [ ] Every epic has an ID matching the pattern PH-[#]-E[order]
- [ ] Every story has an ID matching the pattern PH-[#]-E[order]-S[number]
- [ ] Every story has acceptance criteria (minimum 2 per story)
- [ ] Every story has a point estimate from the Fibonacci scale
- [ ] Every epic has a complete DoD section
- [ ] Every epic has at least one source reference

### Sizing

- [ ] No epic has fewer than 3 stories
- [ ] No epic has more than 10 stories
- [ ] No story exceeds 13 points
- [ ] Stories above 8 points have been evaluated for splitting

### Files

- [ ] All files saved to `docs/PH-[#]/[order]-[epic-name].md`
- [ ] Filenames are lowercase kebab-case
- [ ] Epic ordering within the phase reflects dependency order
- [ ] `scripts/protocol-zero.sh` exits 0 on all generated files
- [ ] `scripts/check-em-dashes.sh` exits 0 on all generated files

### Quality

- [ ] No placeholder text, TODOs, or stubs in any epic file
- [ ] No AI-slop phrasing ("robust", "seamless", "exciting", "I hope this helps")
- [ ] No em dashes (use -- instead)
- [ ] No smart quotes (use straight quotes)
- [ ] Acceptance criteria are specific and testable, not vague
- [ ] Dependencies reference concrete epic/story IDs or external items
- [ ] Risks include realistic mitigations, not generic hedging
