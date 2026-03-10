# Partner Sharing Status Strip

**Epic ID:** PH-5-E2
**Phase:** 5 -- Tracker Home Dashboard
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement `SharingStatusStrip`: the top-of-feed component that communicates the Tracker's current partner sharing state (active or paused) via a color-coded pill strip with a system toggle. The strip renders correctly in both states, animates between them with a 0.2s crossfade, and gates on reduced motion. Phase 5 wires it to `TrackerHomeViewModel` placeholders; Phase 8 replaces those placeholders with live `partner_connections` data.

## Problem / Context

The Sharing Status Strip is the Tracker's primary in-app signal that sharing is active. Design Spec §10.5 defines two visually distinct states: active (low-prominence `CadenceSageLight`) and paused (high-contrast `CadencePrimary`). The CadencePrimary token is the only known Phase 5 blocker: it appears in §7 of the Design Spec with values `#1C1410` light / `#F2EDE7` dark, but is absent from §3's color table. PHASES.md explicitly blocks the paused-strip background on designer confirmation of this token.

The active-state crossfade between states (0.2s easeInOut per cadence-motion skill and Design Spec §11) requires a `withAnimation` block gated on `accessibilityReduceMotion`. If omitted, the state change is jarring because the strip is positioned at the top of the feed and is the first thing the eye lands on.

In Phase 5, `TrackerHomeViewModel.isSharingPaused` and `isPartnerConnected` are hardcoded `false`. The strip is therefore always in the active state when shown. The toggle interaction fires a closure but performs no Supabase write in Phase 5 -- that write is Phase 8. This is intentional and documented in the story Notes fields.

**Source references that define scope:**

- Design Spec v1.1 §10.5 (Sharing Status Strip: active state -- CadenceSageLight bg, subheadline CadenceTextSecondary, system toggle on; paused state -- high-contrast CadencePrimary bg, subheadline semibold inverse-primary text, toggle off; corner radius 12pt; padding 12pt vertical / 16pt horizontal)
- Design Spec v1.1 §7 (CadencePrimary: `#1C1410` light, `#F2EDE7` dark -- referenced only here, absent from §3 table; blocked pending designer confirmation)
- Design Spec v1.1 §11 (Sharing paused state change: 0.2s crossfade on strip background color)
- cadence-motion skill (0.2s easeInOut crossfade; reduced-motion gate: instant state change)
- cadence-accessibility skill (44pt minimum touch target on toggle; VoiceOver label on strip)
- PHASES.md Phase 5 in-scope: "Partner Sharing Status Strip per §10.5 (active: CadenceSageLight, paused: CadencePrimary -- blocked pending designer confirmation; 0.2s crossfade on state change)"
- PHASES.md Phase Notes (Known blocker: "Do not add a placeholder. Block the sharing strip background in Phase 5 until the designer confirms the value.")

## Scope

### In Scope

- `Cadence/Views/Tracker/Home/SharingStatusStrip.swift`: `struct SharingStatusStrip: View` with parameters `isPaused: Bool`, `onToggle: (Bool) -> Void`
- Active state (`isPaused == false`): `HStack` with `Text("Sharing with your partner")` in `.font(.subheadline)` and `Color("CadenceTextSecondary")`; `Toggle("", isOn: activeBinding)` in a system toggle style; background `Color("CadenceSageLight")`; `RoundedRectangle(cornerRadius: 12)` shape; `.padding(.vertical, 12).padding(.horizontal, 16)`
- Paused state (`isPaused == true`): same `HStack` structure; `Text("Sharing paused")` in `.font(.subheadline)` `.fontWeight(.semibold)` and `Color("CadenceTextPrimary")`; background `Color("CadencePrimary")`; same corner radius and padding; **S2 is blocked until `CadencePrimary` is confirmed by designer and added to `Colors.xcassets`**
- 0.2s crossfade on background color change: `withAnimation(.easeInOut(duration: 0.2))` wrapping the `isPaused` state change handler; gated on `@Environment(\.accessibilityReduceMotion)` -- when `reduceMotion == true`, no animation is applied
- Strip hidden entirely when `isPartnerConnected == false` -- the strip is not shown to Trackers without an active partner connection
- Slot 1 in `TrackerHomeView` feeds `SharingStatusStrip(isPaused: viewModel.isSharingPaused, onToggle: { _ in })` -- the `onToggle` closure is a no-op in Phase 5; Phase 8 replaces it with a `partner_connections` write
- `accessibilityLabel` on the strip: `"Partner sharing \(isPaused ? "paused" : "active")"` applied to the outer container
- `accessibilityLabel` on the toggle: `"Pause sharing"` (active) or `"Resume sharing"` (paused); minimum `.frame(minWidth: 44, minHeight: 44)` on the toggle's hit area via `.contentShape(Rectangle())` on the wrapping view
- `project.yml` updated for `SharingStatusStrip.swift`; `xcodegen generate` exits 0

### Out of Scope

- Writing `is_paused` changes to `partner_connections` in Supabase (Phase 8)
- Reading `partner_connections` data to determine `isPartnerConnected` or `isSharingPaused` (Phase 8)
- The paused state's effect on the Partner Dashboard (Phase 9 -- Partner cards crossfade to paused state)
- Notification dispatch on sharing pause (Phase 10)
- The "Sharing paused" card on the Partner Dashboard (Phase 9)

## Dependencies

| Dependency                                                                                                                                            | Type     | Phase/Epic | Status | Risk                                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| PH-5-E1 complete: `TrackerHomeView` feed scaffold exists with slot 1 ready; `TrackerHomeViewModel` exposes `isSharingPaused` and `isPartnerConnected` | FS       | PH-5-E1    | Open   | High -- strip integrates into slot 1                                                                                |
| `CadenceSageLight`, `CadenceTextSecondary`, `CadenceTextPrimary` color assets exist                                                                   | FS       | PH-0-E2    | Open   | Low -- established in Phase 0                                                                                       |
| `CadencePrimary` color asset confirmed by designer and added to `Colors.xcassets`                                                                     | External | Designer   | Open   | **High -- S2 (paused state background) is blocked until this is resolved; see PHASES.md Phase Notes known blocker** |

## Assumptions

- The toggle in the strip controls `isSharingPaused`, not a connection on/off switch. Toggling off sharing sets `is_paused = true`; it does not disconnect the partner.
- The strip is always shown in Phase 5 with `isSharingPaused = false` (hardcoded in `TrackerHomeViewModel`). The visual state of the strip in Phase 5 is always the active (CadenceSageLight) variant.
- S2 (paused state) can be implemented visually in Phase 5 only after `CadencePrimary` is added to `Colors.xcassets`. If the token is not confirmed before Phase 5 wraps, S2 ships blocked and is resolved at the start of Phase 8 before sharing writes are wired.
- The strip occupies the first slot in the `LazyVStack` but is conditionally hidden. When hidden (no partner connected), no empty space is left in slot 1 -- the conditional uses `if viewModel.isPartnerConnected { SharingStatusStrip(...) }`.

## Risks

| Risk                                                                                                     | Likelihood | Impact | Mitigation                                                                                                                                                                                                        |
| -------------------------------------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CadencePrimary` designer confirmation does not arrive before Phase 5 ends                               | Medium     | Low    | Paused state (S2) is a documented blocked story. Active state (S1) and animation (S3) ship without it. Phase 8 unblocks S2. The product impact is zero because `isSharingPaused` is hardcoded `false` in Phase 5. |
| 0.2s crossfade on `SharingStatusStrip` causes layout reflow if the strip's height changes between states | Low        | Low    | Active and paused states have identical padding and corner radius -- height does not change between states; only background color and text content change. Verify in simulator.                                   |
| Toggle tap target smaller than 44pt on some device sizes                                                 | Medium     | Medium | Apply `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` to the `Toggle` wrapping view; verify with Accessibility Inspector in simulator                                                             |

---

## Stories

### S1: SharingStatusStrip -- active state UI

**Story ID:** PH-5-E2-S1
**Points:** 3

Implement `SharingStatusStrip` with the active state fully rendered: `CadenceSageLight` background, subheadline secondary text, system toggle on. The component is wired into `TrackerHomeView` slot 1 and conditionally hidden when `isPartnerConnected == false`.

**Acceptance Criteria:**

- [ ] `Cadence/Views/Tracker/Home/SharingStatusStrip.swift` exists with `struct SharingStatusStrip: View`
- [ ] Parameters: `isPaused: Bool`, `onToggle: (Bool) -> Void`
- [ ] Active state layout: `HStack` with `Text("Sharing with your partner")` in `.subheadline` / `CadenceTextSecondary`; `Spacer()`; system `Toggle` with empty label string bound to `!isPaused`
- [ ] Active state background: `Color("CadenceSageLight")` on `RoundedRectangle(cornerRadius: 12)`
- [ ] Padding: `.padding(.vertical, 12).padding(.horizontal, 16)` applied to the `HStack`
- [ ] Width: `.frame(maxWidth: .infinity)` -- fills `LazyVStack` column
- [ ] `TrackerHomeView` slot 1: `if viewModel.isPartnerConnected { SharingStatusStrip(isPaused: viewModel.isSharingPaused, onToggle: { _ in }) }` -- strip is hidden when no partner connected
- [ ] Strip is not visible in simulator with `isPartnerConnected = false` (default in Phase 5)
- [ ] A SwiftUI Preview shows the active state with `isPaused = false` and `isPartnerConnected = true` hardcoded
- [ ] `project.yml` updated; `xcodebuild build` exits 0
- [ ] No hardcoded hex values

**Dependencies:** PH-5-E1

**Notes:** The `Toggle` binding inverts `isPaused` -- when `isPaused == false` (active), the toggle is `isOn: true`. The toggle `valueChanged` callback fires `onToggle(!isPaused)`. In Phase 5, `onToggle` is a no-op. In Phase 8, it writes to `partner_connections.is_paused`.

---

### S2: SharingStatusStrip -- paused state UI

**Story ID:** PH-5-E2-S2
**Points:** 2

Implement the paused variant of `SharingStatusStrip`: high-contrast `CadencePrimary` background, semibold inverse-primary text label, toggle off. **This story is blocked until `CadencePrimary` is added to `Colors.xcassets` with designer-confirmed values.**

**Acceptance Criteria:**

- [ ] `CadencePrimary` color asset exists in `Colors.xcassets` with light mode `#1C1410` and dark mode `#F2EDE7` values, added by Dinesh or designer confirmation (not added speculatively)
- [ ] Paused state (`isPaused == true`): background `Color("CadencePrimary")`; `Text("Sharing paused")` in `.subheadline` `.fontWeight(.semibold)` `Color("CadenceTextPrimary")`; toggle `isOn: false`
- [ ] Active state text `"Sharing with your partner"` continues to use `CadenceTextSecondary` (unchanged)
- [ ] Paused state corner radius, padding, and width are identical to active state (only background and text content change)
- [ ] A SwiftUI Preview shows both `isPaused = false` and `isPaused = true` side by side
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E2-S1; External: `CadencePrimary` color asset confirmed and added

**Notes:** Do not use a fallback color for `CadencePrimary` or add a conditional `Color("CadencePrimary") ?? Color.black` guard. `Color("CadencePrimary")` will render as a clear color if the asset is absent -- this is the correct behavior to surface the missing token during development rather than silently masking it.

---

### S3: 0.2s crossfade animation between active and paused states

**Story ID:** PH-5-E2-S3
**Points:** 2

Implement the 0.2s easeInOut crossfade that fires when `isPaused` transitions between states. Gate the animation on `accessibilityReduceMotion` -- instant state change with no animation when the user has reduced motion enabled.

**Acceptance Criteria:**

- [ ] `@Environment(\.accessibilityReduceMotion) private var reduceMotion` declared in `SharingStatusStrip`
- [ ] The background color transition between `CadenceSageLight` and `CadencePrimary` is wrapped in `withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2))` driven by a `.animation(.easeInOut(duration: 0.2), value: isPaused)` modifier on the background view when `reduceMotion == false`
- [ ] When `reduceMotion == true`, the state change is instant -- no `.animation` modifier is applied
- [ ] In simulator with reduced motion disabled: toggling `isPaused` in a Preview causes a smooth 0.2s background color crossfade -- no abrupt jump
- [ ] In simulator with reduced motion enabled (Settings > Accessibility > Reduce Motion): toggling `isPaused` causes an instant color change with no visible animation frame
- [ ] Text content change (label string) transitions simultaneously with the background -- no stagger between text and background
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E2-S2

**Notes:** The `.animation(.easeInOut(duration: 0.2), value: isPaused)` approach is preferred over `withAnimation {}` blocks because the view's body re-renders when `isPaused` changes and the modifier handles the interpolation. The cadence-motion skill specifies 0.2s easeInOut for the sharing strip state change (Design Spec §11: "Sharing paused state change: 0.2s crossfade on strip background color").

---

### S4: Accessibility -- VoiceOver labels and 44pt touch target verification

**Story ID:** PH-5-E2-S4
**Points:** 2

Apply VoiceOver labels to the strip container and toggle, verify the toggle's touch target meets the 44pt minimum, and confirm Dynamic Type scaling does not clip the label text at large type sizes.

**Acceptance Criteria:**

- [ ] Outer container `HStack` has `.accessibilityLabel("Partner sharing \(isPaused ? "paused" : "active")")` applied
- [ ] The system `Toggle` has a non-empty accessibility label: `.accessibilityLabel(isPaused ? "Resume sharing" : "Pause sharing")`
- [ ] Toggle's effective touch target is at least 44x44pt -- verified with Accessibility Inspector in the iOS 26 simulator; if the system `Toggle` control is smaller than 44pt in its default rendering, a `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` is applied to the toggle
- [ ] At AX3 Dynamic Type, the strip label text does not clip within the horizontal padding; if the label wraps to two lines, the strip height expands naturally (no fixed-height container on the `HStack`)
- [ ] No `.lineLimit(1)` applied to the strip label text (text must be allowed to wrap at large type sizes)
- [ ] `scripts/protocol-zero.sh` exits 0 on `SharingStatusStrip.swift`
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E2-S1

---

### S5: Integration into TrackerHomeView and end-to-end strip verification

**Story ID:** PH-5-E2-S5
**Points:** 2

Verify `SharingStatusStrip` integrated in the live feed, confirm it hides correctly when `isPartnerConnected = false`, confirm the skeleton card in slot 1 transitions to the strip when loading completes, and confirm no layout regressions on the rest of the feed.

**Acceptance Criteria:**

- [ ] With `viewModel.isPartnerConnected = false` (Phase 5 default): slot 1 is empty -- no strip, no skeleton, no gap; the feed begins at slot 2 (Cycle Status skeleton) with 0pt gap above it
- [ ] With `viewModel.isPartnerConnected = true` (forced in a Preview): slot 1 shows the active-state strip; the first 32pt gap appears between the strip and slot 2
- [ ] `LazyVStack(spacing: 32)` gap between strip and the next card is exactly 32pt -- no extra spacing from within the strip itself
- [ ] Skeleton in slot 1 (`SkeletonCard(height: 52)`) is shown when `viewModel.isLoading == true` regardless of `isPartnerConnected` state (skeleton always shows during loading phase)
- [ ] After `viewModel.isLoading = false` and `isPartnerConnected = false`: slot 1 slot clears (no skeleton, no strip)
- [ ] After `viewModel.isLoading = false` and `isPartnerConnected = true`: slot 1 shows the strip
- [ ] Full feed scrolls without jitter in the simulator at the transition from skeleton to live state
- [ ] `scripts/protocol-zero.sh` exits 0 on all E2 source files
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] `xcodebuild build` exits 0

**Dependencies:** PH-5-E2-S1, PH-5-E1-S2

**Notes:** Skeleton in slot 1 shows regardless of `isPartnerConnected` because `isLoading = true` means data has not been fetched yet -- `isPartnerConnected` is unknown until load completes. This avoids a flash where slot 1 appears empty during load then suddenly shows the strip.

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
- [ ] Active state renders in simulator with correct CadenceSageLight background
- [ ] S2 (paused state) is either complete (CadencePrimary confirmed) or formally documented as blocked with Phase 8 as resolution target
- [ ] 0.2s crossfade verified in simulator; instant transition verified under reduced motion
- [ ] Strip absent from feed when `isPartnerConnected = false`
- [ ] Phase objective is advanced: Sharing Status Strip slot is functional in the live feed
- [ ] cadence-design-system skill: no hardcoded hex; CadenceSageLight, CadencePrimary referenced by token
- [ ] cadence-motion skill: 0.2s easeInOut crossfade; reduced-motion instant transition
- [ ] cadence-accessibility skill: 44pt touch target on toggle; VoiceOver labels on strip and toggle
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`

## Source References

- PHASES.md: Phase 5 -- Tracker Home Dashboard (in-scope: Partner Sharing Status Strip per §10.5; known blocker: CadencePrimary token)
- Design Spec v1.1 §10.5 (Sharing Status Strip: active and paused visual specs, corner radius 12pt, padding 12/16)
- Design Spec v1.1 §7 (Elevation table: CadencePrimary `#1C1410` light / `#F2EDE7` dark -- paused strip background; absent from §3 color table)
- Design Spec v1.1 §11 (sharing paused state change: 0.2s crossfade on strip background)
- cadence-motion skill (0.2s easeInOut crossfade; reduced-motion gating rule)
- cadence-accessibility skill (44pt touch targets; VoiceOver label patterns)
- cadence-design-system skill (token enforcement; CadenceSageLight usage)
