# cadence-navigation Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-navigation/SKILL.md`
**Skill-creator path:** `.claude/skills/skill-creator/`

---

## Local Files Read

| File | Purpose |
|------|---------|
| `.claude/skills/skill-creator/SKILL.md` | Skill structure conventions, YAML frontmatter format, 500-line limit, progressive disclosure, description-as-trigger pattern |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference for evals, grading, benchmark |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — navigation architecture (§10), tab structure, Log Sheet spec (§8.6), deep link destinations (§14), user flows (§9) |
| `docs/Cadence_Design_Spec_v1.1.md` | Locked design spec v1.1 — IA table (§8), tab bar icons (§9), motion spec (§11), platform assumptions (§2), Log Sheet detents (§12.3) |
| `.claude/skills/cadence-motion/SKILL.md` | Cross-reference: optimistic UI contract, sheet/push transition rules |
| `.claude/skills/swiftui-production/SKILL.md` | Cross-reference: @Observable, @State, LazyVStack, AnyView ban |
| `.claude/skills/liquid-glass-ios26/SKILL.md` | Cross-reference: tab bar chrome, center Log icon behavior |

---

## Skill-Creator Usage

Invoked via the `Skill` tool (`skill-creator`). The full SKILL.md was read before authoring. The creation followed the direct-authoring path (no eval loop) as the spec was fully defined. SKILL.md created at `.claude/skills/cadence-navigation/SKILL.md`, validated with `quick_validate.py` (pass).

---

## Anthropic Sources Used for Skill Standards

The project-local install of the Anthropic skill-creator at `.claude/skills/skill-creator/` was the primary authority. Key conventions applied:
- YAML frontmatter: `name` (kebab-case) + `description` (quoted, ≤1024 chars, trigger-inclusive)
- Description is the primary trigger mechanism — all "when to use" belongs there
- SKILL.md body under 500 lines
- Imperative form throughout the body
- No auxiliary documentation files (README, CHANGELOG, etc.)
- Bundled resources (scripts/, references/) only added when needed — none required for this governance-only skill

---

## Apple / Authoritative Sources Used for Navigation Guidance

| Source | Used for |
|--------|---------|
| `developer.apple.com/documentation/swiftui/navigationstack` | NavigationStack API |
| `developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)` | Type-safe destination registration |
| `developer.apple.com/documentation/swiftui/bringing_robust_navigation_structure_to_your_swiftui_app` | NavigationPath, programmatic navigation, deep link pattern |
| `developer.apple.com/documentation/swiftui/view/presentationdetents(_:)` | Sheet detents API |
| `developer.apple.com/documentation/swiftui/environmentvalues/dismiss` | `@Environment(\.dismiss)` — modern dismiss action (iOS 15+) |
| `developer.apple.com/documentation/swiftui/tabview` | TabView selection binding, programmatic selection |
| `developer.apple.com/documentation/SwiftUI/Enhancing-your-app-content-with-tab-navigation` | Tab content builder, iOS 18 Tab struct |
| `developer.apple.com/videos/play/wwdc2022/10054/` | WWDC22 "SwiftUI cookbook for navigation" — NavigationPath, type-safe destinations, deep linking |
| `swiftbysundell.com/articles/swiftui-programmatic-navigation/` | Programmatic navigation patterns (supplementary) |
| `swiftbysundell.com/articles/dismissing-swiftui-modal-and-detail-views/` | Sheet dismiss patterns (supplementary) |

---

## Cadence-Specific Navigation Facts Extracted from Docs

### From Cadence-design-doc.md §10 Navigation Architecture
- `TabView` with programmatic tab selection
- Each tab has its own `NavigationStack`
- Sheets presented with `.sheet()`
- Log tab presents Log Sheet as modal — **active tab does not change**
- Tracker: 5 tabs — Home (0), Calendar (1), Log/center (2), Reports (3), Settings (4)
- Partner: 3 tabs — Her Dashboard (0), Notifications (1), Settings (2)

### From Cadence-design-doc.md §8.6 Log Sheet
- Modal sheet over any tab
- Entry points: Log tab center button, Dashboard "Log today" CTA, Calendar date tap
- Detents: `.medium` (default) and `.large`
- Dismiss: swipe down or Save CTA — immediate (optimistic)

### From Cadence-design-doc.md §14 Deep Links
| Trigger | Destination |
|---------|-------------|
| Tracker: period/ovulation reminder | Tracker Home tab |
| Tracker: daily log reminder | Log Sheet opens directly |
| Partner: any notification | Partner Home tab |

### From Cadence_Design_Spec_v1.1.md §8 IA
- Tab 3 center: "Modal sheet intercept — opens Log Sheet over current tab"
- Log icon: `plus.circle.fill` — always filled, no active/inactive toggle

### From Cadence_Design_Spec_v1.1.md §11 Motion
- Sheet presentation: `.presentationDetents([.medium, .large])` — native iOS bottom sheet
- Navigation push: standard SwiftUI NavigationStack push — no custom transition
- Log Sheet dismiss: swipe down or Save CTA — native

### From Cadence_Design_Spec_v1.1.md §2 Platform Assumptions
- iOS 26 minimum; standard `TabView` and `NavigationStack` — no custom navigation chrome

---

## Ambiguities Found and Resolutions

| Ambiguity | Resolution |
|-----------|-----------|
| Docs specify "programmatic tab selection" but not the exact mechanism (enum vs raw index, legacy `TabView(selection:)` vs iOS 18 `Tab` struct) | Resolved in favor of the iOS 18+ `Tab` struct with enum-backed `TrackerTab`/`PartnerTab`. Both APIs are available on iOS 26; the `Tab` struct is the current forward-leaning API and pairs naturally with the `onChange` intercept pattern. |
| Docs say Log Sheet is accessible from Dashboard CTA and Calendar date tap but do not specify how these views signal `TrackerShell` | Resolved conservatively: ViewModel method `openLogSheet()` signals upward. Explicit in skill. No deeper wiring specified in docs — this is the correct architectural default for parent-owned presentation state. |
| Deep link URL scheme (custom URL vs universal links) not specified in PRD §14 | Resolved: skill governs route-dispatch logic and role-guard pattern only. URL scheme format is deferred. Skill covers `onOpenURL` handler semantics without inventing a URL scheme. |
| iOS 18 bug where `NavigationStack` with `path:` inside new `TabView` pushed destinations twice (Apple Developer Forum thread) | Noted as a known platform issue. Skill enforces `NavigationStack` + `navigationDestination` as required — correct regardless of this bug. Engineers should verify on iOS 26 and file a radar if encountered. Not encoded as a rule change. |
| Whether `@Environment(\.dismiss)` in `LogSheetView` is acceptable or only the `onSave` callback should be used | Resolved: both are acceptable. `@Environment(\.dismiss)` routes up to the parent's binding owner via SwiftUI. What is prohibited is the child owning a *duplicate* `@State var isLogSheetPresented`. Both patterns are stated in the skill. |

---

## Key Enforcement Rules Encoded in the Skill

1. `TabView` is NOT wrapped in `NavigationStack` — each tab content has its own `NavigationStack`
2. Log tab tap: `selectedTab` reverts immediately, `isLogSheetPresented = true` fires in `onChange`
3. `selectedTab` never persists at `.log` — this is the invariant that enforces the modal intercept
4. Log Sheet always uses `.presentationDetents([.medium, .large])` — no custom detents without spec change
5. `isLogSheetPresented` owned exclusively by `TrackerShell` — not by any tab content view or `LogSheetView`
6. All push navigation uses `NavigationLink(value:)` + `navigationDestination(for:destination:)`
7. `navigationDestination` never inside a lazy container — non-deterministic push behavior
8. `NavigationPath` is per-tab, never shared across tabs or roles
9. Route enums are role-namespaced: `TrackerRoute` and `PartnerRoute` — never cross-referenced
10. Only one shell mounts at a time — `TrackerShell` and `PartnerShell` never coexist
11. Deep links are role-gated — handler checks `session.role` before mutating any state
12. Deep links clear `NavigationPath` to root before applying destination
13. Log Sheet opened from deep link uses `isLogSheetPresented = true` directly — not `selectedTab = .log`
14. Log Sheet dismiss is immediate — no network await before dismiss (optimistic UI)
15. System push and sheet transitions only — no custom `.transition()` on NavigationStack push or sheet
