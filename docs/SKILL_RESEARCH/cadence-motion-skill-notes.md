# cadence-motion Skill — Creation Notes

**Created:** March 7, 2026
**Skill path:** `.claude/skills/cadence-motion/SKILL.md`
**Package output:** `.claude/skills/skill-creator/cadence-motion.skill`

---

## Files Read

| File | Purpose |
|---|---|
| `.claude/skills/skill-creator/SKILL.md` | Skill creation process and conventions |
| `.claude/skills/skill-creator/references/schemas.md` | JSON schema reference for evals/benchmark |
| `docs/Cadence-design-doc.md` | MVP PRD v1.0 — optimistic UI contract, feature specs |
| `docs/Cadence_Design_Spec_v1.1.md` | Design system v1.1 — authoritative motion and accessibility specs |

---

## Skill-Creator Location Used

`/Users/Dinesh/Desktop/cadence-cycle-tracker/.claude/skills/skill-creator/`

Scripts used:
- `quick_validate.py` — structural validation (passed)
- `package_skill.py` — produced `cadence-motion.skill`

Note: `init_skill.py` referenced in the loaded skill-creator instructions is not present in this installation. Scaffold was created manually, consistent with the approach used for `cadence-design-system` and `liquid-glass-ios26`.

---

## Sources Used

### Claude Code Skill Standards
- Local `skill-creator` SKILL.md and `references/schemas.md` — authoritative for this project's skill conventions.
- Key standards applied: YAML frontmatter with `name` + `description`, description as primary trigger mechanism with explicit trigger phrases, body under 500 lines, imperative form throughout.

### SwiftUI and Apple Motion/Accessibility Guidance
- **Apple HIG — Accessibility / Motion**: Guidance to respect `UIAccessibility.isReduceMotionEnabled` / SwiftUI `@Environment(\.accessibilityReduceMotion)`, preserve content meaning without animation, avoid looping animations under reduced motion.
- **Apple HIG — Animation**: Animation should reinforce spatial relationships and confirm interactions; never decorative without purpose.
- **SwiftUI Documentation — `ButtonStyle`**: `ButtonStyle` / `PrimitiveButtonStyle` is the correct SwiftUI mechanism for reusable press feedback.
- **SwiftUI Documentation — `Animation`**: `.animation(_:value:)` with explicit `value:` parameter scopes animations to a single binding, preventing implicit side effects.
- **SwiftUI Documentation — `withAnimation`**: `nil` animation produces instant state change — correct reduced-motion pattern.
- **Apple Human Interface Guidelines — Loading**: Skeleton screens preferred over spinners for content-loading states; never full-screen blocker.
- **Supabase Realtime + SwiftData integration**: Realtime events arrive → SyncCoordinator writes to SwiftData → @Observable ViewModel updates → view reflects. UI does not wait on network.

---

## Cadence-Specific Motion Facts Extracted from Docs

All values sourced from `Cadence_Design_Spec_v1.1.md` §11 Motion & Interaction and §14 Accessibility, and `Cadence-design-doc.md` §7.5 Symptom Logging / §8.6 Log Sheet.

| Pattern | Spec | Source |
|---|---|---|
| Chip tap-down scale | `scaleEffect(0.95)` | Design Spec §11 |
| Chip tap-down spring | response: 0.3, dampingFraction: 0.7 | Design Spec §11 |
| Chip toggle cross-dissolve | 0.15s easeOut | Design Spec §11 |
| Sharing strip crossfade | 0.2s | Design Spec §11 |
| Partner Dashboard hide crossfade | 0.25s easeInOut | Design Spec §11 |
| Skeleton shimmer | 1.2s loop, left-to-right | Design Spec §11 |
| Reduced motion | Instant state changes, hold durations preserved | Design Spec §11, §14 |
| Optimistic UI | SwiftData update precedes Supabase write | PRD §7.5, §8.6 |
| Haptic on Log save | `UIImpactFeedbackGenerator(.medium)` | Design Spec §13 |
| No full-screen spinner | `ProgressView` inside CTAs only | Design Spec §13 |
| Chip padding fixed 12/8pt | Prevents geometric jitter on weight change | Design Spec §10.1 |
| `isReadOnly` chips | No press animation | Design Spec §10.1 |

---

## Ambiguities and Conflicts Found

### 1. "Hold durations preserved" — no durations defined
**Conflict:** Design Spec §11 states "hold durations preserved" under reduced motion, but no hold or dwell durations are defined anywhere in the spec for any Cadence animation pattern.
**Resolution:** The skill encodes the principle (hold periods are preserved, only the animation is suppressed) without inventing specific values. Applied conservatively. If toast timeout durations are later defined, they fall under this rule by default.

### 2. `CadencePrimary` token used in sharing strip — not in color table
**Conflict:** Design Spec §7 references `CadencePrimary` (`#1C1410` light / `#F2EDE7` dark) for the paused strip surface, but this token is not in the §3 color table.
**Resolution:** This is a known gap flagged in the `cadence-design-system` skill. The motion skill references `CadencePrimary` by name only (consistent with the design spec text), without resolving its token definition. The motion skill does not own color definitions.

### 3. Spring API form
**Ambiguity:** iOS 17+ introduced `Animation.spring(duration:bounce:)` alongside the older `.spring(response:dampingFraction:blendDuration:)`. The spec states "spring response 0.3, damping 0.7" — these map to the older API's parameters.
**Resolution:** The skill uses `.spring(response: 0.3, dampingFraction: 0.7)` which is available on iOS 17+ and therefore on the iOS 26 minimum target. This is a direct translation of the spec values. If the team wishes to express this in the newer bounce API, `bounce ≈ 0` corresponds to `dampingFraction 0.7` but the mapping is approximate. Use the spec values as written.

---

## Key Enforcement Rules Encoded

1. **Spring required** — `ChipPressStyle` with response 0.3 / dampingFraction 0.7 on all chip surfaces.
2. **Cross-dissolve scoped** — `.animation(_:value:)` with explicit value binding; never bare `withAnimation {}`.
3. **Reduced motion gating** — `@Environment(\.accessibilityReduceMotion)` read in every view that animates.
4. **Instant under reduced motion** — `nil` animation, not a slower variant.
5. **Optimistic UI** — state updates precede network writes. Any `await networkCall()` before a UI update is a blocking violation.
6. **Shimmer is affordance-only** — loading placeholders only; removed the moment data arrives.
7. **No full-screen spinners** — `ProgressView` inside CTAs only.
8. **Native sheet and push transitions** — no custom overrides on NavigationStack push or sheet present/dismiss.
9. **Timing table is exhaustive** — any duration or curve not in the table requires designer sign-off before implementation.
