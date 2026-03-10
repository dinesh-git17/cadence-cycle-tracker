---
name: phase-planner
description: Produces a deterministic docs/PHASES.md project execution map from source-of-truth design and product documents. Use this skill whenever a user asks to create a phase plan, project roadmap, implementation phases, execution map, or breakdown of a project into phases from existing design docs or PRDs. Also use it when a user wants to know "what phases does this project have" or "break this project into phases" or "create a PHASES.md". The skill enforces one-phase-one-goal discipline, explicit dependency ordering, traceable scope boundaries, and a completion standard. It produces planning artifacts that can be directly decomposed into epics without re-deriving project structure. Trigger on: "create phases", "phase plan", "PHASES.md", "implementation roadmap from design doc", "break project into phases", "project execution map", "planning artifact from PRD".
---

# Phase Planner

Produces a `docs/PHASES.md` project execution map from source-of-truth product and design documents. The output is a canonical, top-level planning artifact suitable for direct epic decomposition.

## When This Skill Applies

Use this skill when:

- A user has design docs, a PRD, or a product spec and wants a phased implementation plan
- A user wants to create or update `docs/PHASES.md`
- A repository has source-of-truth documents but no top-level execution sequencing

Do not use this skill to write epics, sprints, or tasks. This skill operates one level above those.

---

## Execution Order

Follow this sequence exactly. Do not skip steps. Do not reorder.

1. Research current technical writing and planning standards
2. Identify and read all source-of-truth documents
3. Synthesize planning principles from research + source docs
4. Draft `docs/PHASES.md`
5. Validate phase coverage against source documents
6. Write the file to disk
7. Run any enforcement scripts (protocol-zero, em-dash, linter) if configured

---

## Step 1: Research

Before writing anything, perform live web research on:

- Technical writing standards for engineering planning artifacts (2024-present)
- Phase planning and roadmap documentation patterns from high-performing engineering orgs
- Deterministic project decomposition methodology
- What makes a phase boundary clear vs. ambiguous
- How to write scope definitions that roll down cleanly into epics

Use WebSearch and WebFetch. Prioritize primary and institutional sources. If research returns insufficient signal, state that explicitly rather than proceeding with default assumptions.

Synthesize what you find before moving to Step 2. The research must influence the phase structure, not just appear in a footnote.

---

## Step 2: Source Document Inspection

Locate and read every source-of-truth document in the repository. Look in `docs/`, project root, and any subdirectory that appears to contain specs or PRDs.

For each document, extract:

- Feature areas and their scope
- Data models and system components
- Explicit out-of-scope declarations
- Open items with timing constraints (pre-ship, pre-TestFlight, post-beta, etc.)
- User flows and critical paths
- Technical constraints (platform, framework, third-party dependencies)
- Success criteria and completion definitions

If two source documents conflict on scope, flag the conflict explicitly. Do not resolve it by picking the more convenient interpretation. Halt and ask.

If a source document is ambiguous on something that affects phase boundaries, flag it as a known gap in the Phase Notes section.

---

## Step 3: Dependency Graph Construction

Before writing any phase, build the full dependency graph mentally:

- Which systems must exist before others can be built?
- Which components are reused across multiple phases?
- Which phases can logically run in parallel? (Document this -- do not assume parallelism silently.)
- What are the sequencing constraints from the platform and tech stack?

Sequence phases by dependency graph, not by feature salience or business priority.

---

## Step 4: Phase Design

Apply these rules to every phase:

**One phase, one primary goal.** If you can state two equally important goals for a phase, split it.

**Scope boundary is explicit, not implied.** Every phase has an In Scope and Out of Scope column. Work not listed as in scope for any phase is either out of scope for the project or a gap that must be called out.

**Phases are traceable.** Every phase must reference the source document sections that justify its scope. No phase content can be invented or inferred without a source reference.

**No speculative work.** Phases contain only work directly implied by the source documents. Do not add architecture for hypothetical future requirements.

**Epic-ready granularity.** Each phase should produce 3-6 epics when decomposed. Fewer than 3 epics: the phase is too small, merge it. More than 7 epics: the phase is too large, split it.

**Material progress.** A completed phase must leave the project in a materially better state. Infrastructure-only phases are legitimate only when they are prerequisites for multiple subsequent phases.

---

## Anti-Patterns to Reject

Refuse to produce output containing any of the following:

- **Umbrella phases**: "Implement the core features" or "Build the backend" -- these have no deterministic scope boundary
- **Speculative scope**: Work not traceable to a source document
- **Missing dependencies**: A phase that implicitly requires another phase's output without declaring it
- **Conflated concerns**: Auth + data layer + navigation in one phase because they are all "foundational"
- **Vague descriptions**: "Set up the project structure and prepare for development"
- **Missing out-of-scope**: Every phase must state what does NOT belong in it
- **Fake precision**: Epic counts like "12-15 epics" for a phase with 3 clearly separable concerns
- **AI slop phrasing**: "Exciting first phase", "robust implementation", "seamlessly integrated"

---

## Required Document Structure

`docs/PHASES.md` must contain these sections in this order:

```
# PHASES
## Purpose
## Source of Truth
## Planning Principles
## Phase Table
## Phase Notes
## Completion Standard
```

### Purpose Section

State what the document is, why it exists, and how it should be used. Make clear it is the canonical execution map derived from source documents, not a wish list or sprint plan.

### Source of Truth Section

List every source document by filename and path. State that phase definitions must remain aligned with those documents. State the conflict resolution rule: conflicts must be resolved explicitly, not guessed through.

Call out any known gaps or conflicts discovered during Step 2.

### Planning Principles Section

State the rules used to construct the phases. Must include at minimum:

- One phase = one primary objective
- Deterministic scope boundaries
- Explicit sequencing by dependency graph
- No speculative work
- Traceability to source documents
- Epic-ready granularity (3-6 epics per phase)

### Phase Table

Structured table with these columns (add more only if they materially improve clarity):

| Phase # | Phase Name | Description | Primary Goal | In Scope | Out of Scope | Dependencies | Est. Epics | Source References |

**Description** must be 4-5 substantive lines explaining: what the phase accomplishes, why it exists as a separate phase, and what category of implementation work belongs inside it. No filler.

**Est. Epics** must be a realistic integer or narrow range derived from the scope. Base it on how many distinct, independently shippable work streams the phase contains.

**Source References** must point to specific sections, headings, or feature areas in the named source documents.

### Phase Notes Section

One subsection per phase containing:

- Phase intent (1-2 sentences, specific)
- Sequencing rationale (why this phase is where it is in the order)
- Why it is separated from adjacent phases
- Likely epics (names only, not full specs)
- Any known ambiguities or blockers for this phase

Do not write the actual epics. Only provide enough structure so future epic writing is deterministic.

### Completion Standard Section

State explicitly: when all phases are complete, the project as defined by the source documents is complete.

State the gap handling rule: work not covered by any phase is either an omission (must be corrected) or post-v1 out-of-scope work (must be tracked separately).

---

## Quality Gate (Self-Check Before Writing to Disk)

Before writing the final file, verify:

1. Every phase has exactly one clearly stated primary goal
2. Every phase's In Scope list is traceable to a source document
3. No two phases have overlapping scope for the same work item
4. Every dependency is declared, not implied
5. No phase would produce fewer than 3 or more than 7 epics
6. The Out of Scope column exists and is non-empty for every phase
7. Phase Notes exist for every phase with a non-generic sequencing rationale
8. The Completion Standard defines what "done" means for the full project
9. No umbrella phases, no speculative scope, no AI slop phrasing
10. All known gaps and ambiguities from source documents are called out explicitly

If any check fails, revise before writing.

---

## Writing Style Rules

- Decisive, technical, authoritative voice
- No motivational language ("exciting", "powerful", "seamlessly")
- No hedge words ("might", "could potentially", "possibly")
- No preamble restating what the user asked for
- ASCII hyphens (--), not em dashes
- Straight quotes, not smart quotes
- Comments and descriptions written as a human engineer would: terse, specific, no filler
- Commit messages (if applicable): imperative mood, Conventional Commits format

---

## Output

Write the completed `docs/PHASES.md` to disk. Confirm the write. Do not return the full file contents in the conversation unless the user explicitly asks to see it -- instead, summarize what was produced and note any gaps or blockers found.

If enforcement scripts exist in the repository (protocol-zero.sh, check-em-dashes.sh), run them on the output file before confirming completion.
