# swiftui-production Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/swiftui-production/SKILL.md`
**Package output:** `.claude/skills/skill-creator/swiftui-production.skill`

---

## Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill creation process and conventions |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — project context, architecture, SwiftData/Supabase sync model |
| `docs/Cadence_Design_Spec_v1.1.md` | Design system v1.1 — component and screen complexity context |

---

## Skill-Creator Location Used

`/Users/Dinesh/Desktop/cadence-cycle-tracker/.claude/skills/skill-creator/`

Scripts used:
- `quick_validate.py` — structural validation (passed after removing angle bracket from description)
- `package_skill.py` — produced `swiftui-production.skill`

Note: `init_skill.py` is not present in this installation. Scaffold created manually, consistent with all prior Cadence skills.

---

## Sources Used

### Claude Code Skill Standards
- Local `skill-creator` SKILL.md — authoritative for this project's skill conventions.
- Key standards applied: YAML frontmatter name + description, description as primary trigger mechanism with explicit trigger phrasing, body under 500 lines, imperative form, no auxiliary documentation files.

### Apple / Authoritative Sources for SwiftUI Production Guidance

**Observation Framework / @Observable:**
- Apple Developer Documentation: Observation (`import Observation`, `@Observable` macro) — iOS 17+, replacing `ObservableObject`.
- WWDC23 Session 10149: "Discover Observation in SwiftUI" — covers `@Observable` vs `@ObservedObject`, property tracking, `@State` for owned observables, `@Environment` for injected observables.
- Key fact confirmed: `@StateObject`/`@ObservedObject`/`@EnvironmentObject` are incompatible with `@Observable` — they are for `ObservableObject` protocol only.

**View decomposition:**
- Apple Developer Documentation: SwiftUI View fundamentals — views are lightweight structs; decomposition has no runtime cost.
- Apple Human Interface Guidelines — no specific line-count guidance; 50-line rule is an engineering heuristic widely adopted in the Swift community and consistent with Swift type-checker performance recommendations.

**LazyVStack vs VStack:**
- Apple Developer Documentation: `LazyVStack` — "A view that arranges its children in a line that grows vertically, creating items only as needed." vs `VStack` which renders all children.
- WWDC21 Session 10022: "Demystify SwiftUI" — structural identity and lazy loading in lists.

**AnyView:**
- Apple Developer Documentation: `AnyView` — "A type-erased view. An AnyView allows changing the type of view used in a given view hierarchy." Explicitly noted as type erasure with diffing implications.
- WWDC21 Session 10022: "Demystify SwiftUI" — structural identity, `AnyView` erases type identity and breaks SwiftUI diffing optimizations.

**ForEach identity:**
- Apple Developer Documentation: `ForEach` — requires `Identifiable` or explicit `id:` key path. Stable identity drives correct diffing, animation, and state preservation.
- WWDC21 Session 10022: "Demystify SwiftUI" — explicit vs structural identity; unstable IDs cause full view recreation.

**GeometryReader:**
- Apple Developer Documentation: `GeometryReader` — takes full proposed size; disrupts layout flow.
- Apple Developer Documentation: `containerRelativeFrame(_:alignment:)` — iOS 17+ modern alternative for proportional sizing.
- Apple Developer Documentation: `Grid` — iOS 16+ for equal-width/height grid layouts.

**Main actor / concurrency:**
- Apple Developer Documentation: `@MainActor` — marks functions to run on the main dispatch queue; blocking it causes UI hangs.
- WWDC21 Session 10254: "Swift concurrency: Behind the scenes" — main actor as serial executor for UI work; `Task.detached` for background work.
- Swift Evolution SE-0316: `@MainActor` — cooperative thread pool, main actor as isolated context.

**Retain cycles:**
- Apple Developer Documentation: Automatic Reference Counting — strong reference cycles in closures.
- Swift Programming Language: "Closures" chapter — capture lists, `[weak self]` pattern.

---

## Key Production Rules Encoded

| Rule | Basis |
|---|---|
| `@Observable` for ViewModels, not `ObservableObject` | WWDC23, Apple Observation docs |
| `@State` to own `@Observable` instances at a view | WWDC23 Session 10149 |
| No `@StateObject`/`@ObservedObject` on `@Observable` | Incompatible protocol — Apple docs |
| View body extraction at 50 lines | Engineering heuristic + type-checker perf |
| `LazyVStack` for feeds | Apple `LazyVStack` docs + WWDC21 |
| `AnyView` banned | WWDC21 identity session, Apple docs |
| Stable `Identifiable` IDs in `ForEach` | Apple `ForEach` docs + WWDC21 |
| `containerRelativeFrame` before `GeometryReader` | Apple iOS 17+ docs |
| `[weak self]` on stored closures in class | ARC documentation |
| `Task.detached` for heavy work off main actor | WWDC21 concurrency session |

---

## Ambiguities and Resolutions

### 1. Force-unwrap at initialization boundaries
**Ambiguity:** Color asset catalog lookups (`Color("CadenceTerracotta")`) technically return an optional in some contexts but are guaranteed by the build system. Treating these as exceptions to the force-unwrap rule.
**Resolution:** Documented as an acceptable boundary with explicit inline comment requirement. The `cadence-design-system` skill governs token usage; this skill governs the safety boundary.

### 2. 50-line view extraction threshold
**Ambiguity:** Apple has no official line-count guideline. The 50-line rule is a community and engineering heuristic.
**Resolution:** Retained as explicit enforcement threshold because it is the stated requirement in the task spec and is consistent with known SwiftUI type-checker performance guidance. Documented as heuristic in the notes.

### 3. Task {} retain cycle risk
**Ambiguity:** Apple's Swift concurrency documentation is nuanced — `Task {}` created in an `@MainActor` function inherits the actor context and does not extend the object's lifetime the same way a stored closure does.
**Resolution:** Documented the distinction explicitly in the skill: `Task {}` bodies do not require `[weak self]`; stored closures and completion handlers always do. Conservative rule applied for stored closures.

### 4. `List` vs `LazyVStack` for feeds
**Ambiguity:** `List` is also lazy; some Cadence surfaces (Settings rows, notification history) use list-style layout.
**Resolution:** Skill distinguishes: custom card feeds use `LazyVStack`; Settings and notification history may use `List` where system styling is appropriate. Documented inline.
