---
name: cadence-accessibility
description: Implements the full Cadence accessibility contract. Enforces 44x44pt minimum touch targets, gates all custom animations on accessibilityReduceMotion, applies correct accessibilityLabel patterns to chips and the Sex chip lock icon, validates Dynamic Type scaling on all text and the 48pt countdown numeral, and ensures the Partner Bento grid collapses to 1-up at the Accessibility1 threshold. References WCAG AA contrast ratios exactly as defined in the Cadence design spec. Use whenever implementing or reviewing any Cadence screen, interactive component, text surface, or layout — no screen ships without passing this skill's checklist. Triggers on any Cadence SwiftUI view, chip component, accessibility audit, VoiceOver label question, Dynamic Type layout, or contrast verification.
---

# Cadence Accessibility Contract

Authoritative accessibility governance for Cadence. Every screen must pass this skill's checklist before it ships. All rules are derived from `Cadence_Design_Spec_v1.1.md` §14 and §2, cross-referenced with Apple HIG and WCAG 2.1 AA. Do not introduce accessibility workarounds not specified here without flagging them for designer review.

---

## 1. Touch Targets — 44×44pt Minimum

Every interactive element must present a minimum 44×44pt tappable area. This includes all symptom chips, flow chips, period toggle buttons, CTAs, toggles, navigation elements, and icon buttons.

**Implementation pattern:**

```swift
// If the visual size is smaller than 44pt, expand the hit area without
// changing the visual appearance:
SomeSmallIcon()
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
```

**Rules:**

- Apply `.frame(minWidth: 44, minHeight: 44)` to any interactive element whose rendered size may fall below the threshold.
- Add `.contentShape(Rectangle())` when the tappable area needs to extend beyond the visible bounds.
- Chip height is fixed at 44pt minimum via vertical padding (8pt top/bottom on 28pt line height). Verify this holds at all Dynamic Type sizes.
- The Log tab center `plus.circle.fill` icon: always 44×44pt tappable — system TabView handles this.
- Password show/hide toggle in Auth screen: must be 44×44pt. Use `.frame(minWidth: 44, minHeight: 44)` if the plain text button is too small.

**Anti-pattern — reject:**

```swift
// WRONG: icon button with no minimum frame
Button { action() } label: {
    Image(systemName: "xmark").font(.caption)  // renders at ~12pt — far below threshold
}

// CORRECT
Button { action() } label: {
    Image(systemName: "xmark").font(.caption)
}
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

---

## 2. Reduced Motion Gating

Every custom animation in Cadence must be gated on `@Environment(\.accessibilityReduceMotion)`. This is a duplicate checkpoint from `cadence-motion` — enforced here as an accessibility contract requirement.

**Rule:**

- `reduceMotion == true` → instant state change. No cross-dissolve, no spring, no shimmer loop.
- `reduceMotion == false` → sanctioned animation per `cadence-motion` skill.
- No layout shift occurs under either condition.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)
```

**Skeleton shimmer under reduced motion:** Replace the shimmer loop with a static low-opacity placeholder (opacity ~0.4). Do not run a slower loop — eliminate motion entirely.

---

## 3. Accessibility Labels — Chips

### Symptom Chips

Every symptom chip must expose its name and selection state to VoiceOver. The exact format defined in the spec is:

```
"{symptom name}, {selected/unselected}"
```

**Examples:** `"Cramps, selected"` · `"Headache, unselected"` · `"Fatigue, selected"`

**Implementation:**

```swift
struct SymptomChip: View {
    let symptom: SymptomType
    let isActive: Bool
    let isReadOnly: Bool

    var body: some View {
        ChipLabel(symptom: symptom, isActive: isActive)
            .accessibilityLabel("\(symptom.displayName), \(isActive ? "selected" : "unselected")")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
            .accessibilityRemoveTraits(isReadOnly ? .isButton : [])
    }
}
```

**Rules:**

- Never rely on the visible label text alone — always set `accessibilityLabel` explicitly.
- `isReadOnly` chips are not interactive: remove the `.isButton` trait so VoiceOver does not announce them as activatable.
- VoiceOver announcement on toggle: SwiftUI announces the new `accessibilityLabel` value after state change. This is sufficient — do not add redundant `accessibilityHint` for the toggle action unless UX review requests it.

### Sex Chip Lock Icon

The Sex chip always displays a lock icon (`lock.fill`) regardless of state. The lock icon must carry this exact accessible label:

```swift
Image(systemName: "lock.fill")
    .accessibilityLabel("Private - not shared with partner")
```

The lock icon must NOT be `.accessibilityHidden(true)`. Its meaning is functional, not decorative — it tells the user this data is private. Hiding it from VoiceOver removes critical privacy context.

### Flow Level Chips

Apply the same `"{label}, {selected/unselected}"` pattern:

```swift
.accessibilityLabel("\(flowLevel.displayName), \(isSelected ? "selected" : "unselected")")
```

### Period Toggle Buttons

"Period started" and "Period ended" buttons are action buttons, not toggles. Use `.accessibilityLabel` matching the button's visible label. Do not add a `{selected/unselected}` suffix — they trigger events, they do not toggle state.

---

## 4. Dynamic Type Validation

All text in Cadence must scale with Dynamic Type. No fixed-size text containers.

**Rules:**

- All labeled text uses system type tokens (SF Pro Dynamic Type). These scale automatically — verify no `.font(.system(size: N))` without `@ScaledMetric` backing.
- No `.lineLimit(1)` on body content without a truncation fallback — use `.minimumScaleFactor` or allow wrapping.
- No hardcoded container heights that clip text at large type sizes.

### Countdown Numerals — Special Case

The cycle countdown displays a large numeral using:

```swift
.font(.system(size: 48, weight: .medium, design: .rounded))
```

This is a custom size not tied to a Dynamic Type token. The spec requires it "must scale with `accessibilityLargeText`". Implement using `@ScaledMetric`:

```swift
@ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 48

Text(countdown)
    .font(.system(size: countdownSize, weight: .medium, design: .rounded))
```

`@ScaledMetric(relativeTo: .largeTitle)` scales the custom size proportionally to the `.largeTitle` Dynamic Type category, maintaining the design intent at accessibility sizes.

### Validation Requirement

Test at these Dynamic Type sizes at minimum:

- **Default** — no regression from baseline
- **xLarge** — readable, no clipping
- **Accessibility1** — layout adaptations apply (see §5)
- **Accessibility3** — maximum stress test: text wraps, cards expand, no truncation without intent

---

## 5. Partner Bento Grid — Accessibility1 Collapse

The Partner home dashboard presents data in a 2-up bento grid (two square cards side by side: Phase, Countdown). At the `Accessibility1` Dynamic Type threshold and above, the grid must collapse to a 1-up vertical stack.

**Implementation:**

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var isAccessibilitySize: Bool {
    dynamicTypeSize >= .accessibility1
}

var body: some View {
    if isAccessibilitySize {
        VStack(spacing: 16) {
            PhaseCard(viewModel: viewModel)
            CountdownCard(viewModel: viewModel)
        }
    } else {
        HStack(spacing: 12) {
            PhaseCard(viewModel: viewModel)
            CountdownCard(viewModel: viewModel)
        }
    }
}
```

**Rules:**

- The collapse applies to the 2-up square card pair (Phase, Countdown). Full-width rectangular cards (Symptoms, Notes) are already 1-up and do not require adaptation.
- At `Accessibility1` and above, use a `VStack`. Below `Accessibility1`, use the `HStack` 2-up layout.
- Both cards must remain fully legible in the 1-up layout — no truncation, no clipping.
- Test the collapse at exactly `Accessibility1` and at `Accessibility5` (maximum) to verify correctness.

---

## 6. WCAG AA Contrast — Cadence-Specific Ratios

The Cadence design spec has verified and documented specific WCAG AA contrast ratios. Reference these exact values. Do not substitute or estimate.

### Spec-Verified Contrast Pairs

| Foreground                         | Background                         | Ratio   | Standard   | Status     |
| ---------------------------------- | ---------------------------------- | ------- | ---------- | ---------- |
| CadenceTerracotta `#C07050`        | CadenceBackground `#F5EFE8`        | 4.5:1   | WCAG AA    | Verified ✓ |
| CadenceTerracotta `#C07050`        | CadenceCard `#FFFFFF`              | 4.5:1   | WCAG AA    | Verified ✓ |
| CadenceTerracotta `#D4896A` (dark) | CadenceBackground `#1C1410` (dark) | WCAG AA | Verified ✓ | Dark mode  |
| CadenceSage `#8FB08F` (dark)       | CadenceBackground `#1C1410` (dark) | WCAG AA | Verified ✓ | Dark mode  |

**WCAG AA thresholds:**

- Normal text (below 18pt regular / 14pt bold): minimum 4.5:1
- Large text (18pt+ regular or 14pt+ bold): minimum 3:1
- Interactive component boundaries: minimum 3:1

**Rules:**

- Never replace a spec-defined color with a custom value without re-verifying the contrast ratio.
- CadenceTextSecondary (`#6C6C70` light, `#98989D` dark) is used for metadata and secondary copy — verify it maintains 3:1 minimum against its background where it appears on interactive elements.
- The sharing strip paused state uses CadencePrimary high-contrast surface — this is a known spec gap (token not defined in §3 color table). Do not ship the paused strip without confirming the contrast pair with the designer.
- Colorblind safety: terracotta and sage are never the sole visual differentiators. Period days (solid fill) and fertile window (continuous band) are differentiated by fill pattern in addition to color. Never use pure red/green pairs.

---

## 7. VoiceOver — Additional Screen-Level Requirements

### Auth Screen

- Sign in with Apple button: uses system SIWA component — accessibility handled by Apple.
- Sign in with Google button: apply `accessibilityLabel("Sign in with Google")` if the Google SDK button does not expose an accessible label.
- Password show/hide toggle: must announce state change. Use a `Button` with an `accessibilityLabel` that reflects the current state: `"Show password"` or `"Hide password"`.

```swift
Button {
    isPasswordVisible.toggle()
} label: {
    Text(isPasswordVisible ? "Hide" : "Show")
}
.accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
```

### Calendar View

- Logged period days: `accessibilityLabel("Period day, [date]")`
- Predicted period days: `accessibilityLabel("Predicted period, [date]")`
- Fertile window days: `accessibilityLabel("Fertile window, [date]")`
- Private days: `accessibilityLabel("[date], private")`
- Today: system today indicator — do not override its accessibility presentation.

### Log Sheet

- Notes textarea: `accessibilityLabel("Notes")` with `accessibilityHint("Optional - anything else worth noting")`
- Privacy toggle: label must read "Keep this day private" matching the visible label. The toggle's on/off state is announced by the system toggle component.
- Save CTA: `accessibilityLabel("Save log")`

---

## 8. Anti-Pattern Table

| Anti-pattern                                                        | Rule violated                                  |
| ------------------------------------------------------------------- | ---------------------------------------------- |
| Interactive element below 44×44pt tappable area                     | §14 touch target                               |
| Custom animation without `accessibilityReduceMotion` guard          | §14 reduced motion                             |
| Shimmer loop at reduced speed under reduceMotion                    | Must be static placeholder — no looping        |
| Chip without `accessibilityLabel`                                   | §14 VoiceOver                                  |
| Sex chip lock icon hidden from VoiceOver                            | Lock is functional, not decorative             |
| `isReadOnly` chip retaining `.isButton` trait                       | VoiceOver incorrectly announces as activatable |
| Fixed-size text without `@ScaledMetric`                             | §2 Dynamic Type                                |
| Hardcoded container height that clips at Accessibility3             | §14 Dynamic Type                               |
| Partner Bento 2-up grid at Accessibility1 or above                  | §12.5 layout collapse                          |
| Color pair not matching spec-verified contrast                      | §3 / WCAG AA                                   |
| Terracotta/sage as sole differentiator for period vs fertile window | §14 colorblind                                 |
| Screen shipped without checklist pass                               | Accessibility contract                         |

---

## 9. Screen Accessibility Checklist

No screen is considered complete until all applicable items pass:

**Touch Targets**

- [ ] All interactive elements have a minimum 44×44pt tappable area
- [ ] `.contentShape(Rectangle())` applied where visible bounds are smaller than the hit target

**Reduced Motion**

- [ ] All custom animations gated on `@Environment(\.accessibilityReduceMotion)`
- [ ] `reduceMotion == true` → instant state change, no layout shift
- [ ] Skeleton shimmer → static opacity placeholder under reduceMotion

**Accessibility Labels**

- [ ] All symptom chips: `"{name}, {selected/unselected}"`
- [ ] Sex chip lock icon: `"Private - not shared with partner"` — not hidden
- [ ] Flow chips: `"{level}, {selected/unselected}"`
- [ ] `isReadOnly` chips have `.isButton` trait removed
- [ ] Auth password toggle announces current state ("Show password" / "Hide password")
- [ ] Calendar day cells have descriptive labels including date and state

**Dynamic Type**

- [ ] All text uses system type tokens or `@ScaledMetric`-backed custom sizes
- [ ] Countdown numeral uses `@ScaledMetric(relativeTo: .largeTitle)` with base 48pt
- [ ] No hardcoded container heights that clip text at Accessibility3
- [ ] Layout verified at: Default, xLarge, Accessibility1, Accessibility3

**Bento Grid**

- [ ] Partner dashboard 2-up grid collapses to 1-up `VStack` at `dynamicTypeSize >= .accessibility1`
- [ ] Both cards fully legible in the 1-up layout

**Contrast**

- [ ] All color pairs match spec-verified WCAG AA ratios from §3
- [ ] No custom color substitutions introduced without contrast re-verification
- [ ] CadencePrimary paused strip contrast confirmed with designer before shipping
- [ ] Period vs fertile window differentiated by fill pattern, not color alone
