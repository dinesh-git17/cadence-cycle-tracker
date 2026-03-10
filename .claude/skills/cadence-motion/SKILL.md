---
name: cadence-motion
description: Governs all animation and interaction patterns in the Cadence iOS SwiftUI app. Use this skill whenever implementing or reviewing any animation, gesture response, state transition, loading affordance, skeleton shimmer, or accessibility motion handling in Cadence. Covers the chip tap-down spring (scaleEffect 0.95, response 0.3, damping 0.7), 0.15s color cross-dissolve on chip toggle, sharing strip 0.2s crossfade, Partner Dashboard 0.25s easeInOut hide crossfade, and skeleton shimmer 1.2s loops. Enforces reduced-motion gating on every custom animation and flags any UI update that waits on a network response before reflecting user intent. Triggers on any Cadence view with interactive chips, animated state changes, loading placeholders, or motion accessibility requirements.
---

# Cadence Motion System

Authoritative motion governance for Cadence. Every custom animation and interaction feedback pattern is specified here. Do not introduce durations, spring values, or crossfade behavior not in this skill without flagging it as a gap requiring designer confirmation.

---

## Motion Tone

Motion in Cadence serves two purposes only:

1. **Affordance** — confirming that a tap or toggle registered.
2. **State communication** — making a data change legible.

Decorative animation with no functional role is prohibited. Every animated transition must map to one of these two purposes. The overall feel must be calm and warm — not clinical, not flashy.

---

## Sanctioned Animation Specifications

### 1. Chip Tap-Down (Press Feedback)

**Surfaces:** Symptom chips, flow-level chips, period toggle buttons — any tappable chip surface.

**Spec:** `scaleEffect(0.95)` on press-down. Spring: response `0.3`, damping fraction `0.7`.

```swift
struct ChipPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
```

**Rules:**

- Apply `ChipPressStyle` to all chip surfaces: `SymptomChip`, `FlowChip`, period toggle buttons.
- Never use a linear or easeIn curve for press feedback — the spring spec is required.
- `isReadOnly: Bool` chips must not animate on press. Disable the gesture and remove `ChipPressStyle`.
- Under `accessibilityReduceMotion`: no scale change. Button still registers the tap — only the visual spring is suppressed.

---

### 2. Chip Toggle Color Cross-Dissolve

**What changes on toggle:** Background (transparent → CadenceTerracotta), border (1pt CadenceBorder → none), text color (CadenceTextPrimary → CadenceTextOnAccent), font weight (regular → semibold).

**Spec:** 0.15s easeOut cross-dissolve. Padding stays fixed at 12pt H / 8pt V in both states — this prevents geometric jitter when font weight changes.

```swift
// Scope the animation to the isActive binding only
.animation(.easeOut(duration: 0.15), value: isActive)
```

**Rules:**

- The state change is instant. `isActive` flips immediately on tap — no waiting for the Supabase write.
- The 0.15s governs the visual cross-dissolve only (color, border, text color, weight).
- Under `accessibilityReduceMotion`: remove the animation modifier entirely. State flips instantly with no cross-dissolve.
- Do not animate padding, frame size, or corner radius — only color/appearance properties.

---

### 3. Sharing Strip State Crossfade

**What:** Partner Sharing Status Strip on Tracker Home transitions between:

- **Active**: CadenceSageLight background, "Sharing with [name]", CadenceTextSecondary
- **Paused**: CadencePrimary high-contrast background, "Sharing paused", semibold inverse primary

**Spec:** 0.2s crossfade on background color and text style.

```swift
.animation(.easeInOut(duration: 0.2), value: isPaused)
```

**Rules:**

- Under `accessibilityReduceMotion`: instant swap, no crossfade.
- The strip reflects the user's gesture immediately — do not wait for the Supabase write to `partner_connections.is_paused` before updating the strip.
- Corner radius stays at 12pt in both states. Padding stays at 12pt V / 16pt H. Only color and text properties animate.

---

### 4. Partner Dashboard Hide / Sharing Paused Crossfade

**What:** When the Tracker pauses sharing, the Partner home dashboard transitions from the bento grid to a single "Sharing paused" card.

**Spec:** 0.25s easeInOut crossfade between the two view states.

```swift
Group {
    if sharingPaused {
        SharingPausedCard()
            .transition(.opacity)
    } else {
        BentoDashboardGrid()
            .transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.25), value: sharingPaused)
```

**Rules:**

- Under `accessibilityReduceMotion`: instant swap, no crossfade.
- `sharingPaused` is driven by the `@Observable` ViewModel reading SwiftData. The Realtime event from Supabase arrives → `SyncCoordinator` writes `is_paused` to SwiftData → ViewModel updates → view transitions. The transition does not itself wait on any network call.

---

### 5. Skeleton Loading Shimmer

**What:** Card content placeholders shown while initial data loads from SwiftData or while the first Realtime event is pending.

**Spec:** 1.2s loop, left-to-right gradient shimmer over muted placeholder shapes.

```swift
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -300

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.4) // Static low-opacity placeholder — no animation
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color(.systemBackground).opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: phase)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1.2)
                                .repeatForever(autoreverses: false)
                            ) {
                                phase = geo.size.width + 300
                            }
                        }
                    }
                )
                .clipped()
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
```

**Rules:**

- Skeleton shimmer is a **loading affordance only**. Apply it exclusively to card placeholders during data fetch. Never on content that is already loaded.
- Under `accessibilityReduceMotion`: static low-opacity placeholder (opacity ~0.4). No loop. No motion.
- Never use a full-screen spinner. `ProgressView` is permitted inside CTA buttons only (inline, button width locked to prevent layout shift).
- Placeholder geometry must match the real content layout to prevent layout shift on load completion.
- Stop the shimmer and remove the placeholder the moment data arrives — do not keep the shimmer running alongside real content.

---

## Reduced Motion Requirements

Every custom animation in Cadence must be gated on `@Environment(\.accessibilityReduceMotion)`.

**The rule:**

- `reduceMotion == true` → state changes are instant. No cross-dissolve, no spring, no shimmer loop, no crossfade.
- `reduceMotion == false` → use the sanctioned animation from the timing table.

**Hold periods are preserved.** If a display duration exists (e.g., a toast timeout), that duration continues under reduced motion even when the enter/exit animation is instant.

**Standard gating pattern:**

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// For value-driven animations:
.animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)

// For withAnimation blocks:
if reduceMotion {
    isActive = true
} else {
    withAnimation(.easeOut(duration: 0.15)) {
        isActive = true
    }
}
```

Passing `nil` to `.animation(_:value:)` produces an instant state change — this is the correct reduced-motion behavior, not `.animation(.default)`.

---

## Responsiveness and Optimistic UI

**Rule: Never gate a user-visible UI state change on a network response.**

Cadence uses SwiftData as the client source of truth. All writes go to SwiftData first, then to Supabase via the `SyncCoordinator` write queue. The UI reads from `@Observable` ViewModels backed by SwiftData.

This means:

- **Chip toggles** reflect immediately. The symptom state updates in SwiftData before the Supabase write completes.
- **Sharing strip** pause/resume reflects immediately on the Tracker's device.
- **Period and flow logging** reflect immediately in the dashboard and calendar.
- **Log Sheet save** dismisses the sheet and reflects the optimistic state — the Supabase write is queued, not awaited.

**Anti-pattern — reject immediately:**

```swift
// WRONG: waits on network before updating UI
Button("Log symptom") {
    await supabaseClient.insert(symptom)  // UI blocked until network responds
    isActive = true
}

// CORRECT: optimistic update
Button("Log symptom") {
    isActive = true  // Instant — updates SwiftData and UI immediately
    Task { await syncCoordinator.enqueue(symptom) }
}
```

If you encounter animation or UI state predicated on an `async` network call completing before the visual update, flag it as a violation of Cadence's optimistic UI contract.

---

## Animation Timing Reference

| Pattern                    | Duration / Spec             | Curve             | Reduced Motion       |
| -------------------------- | --------------------------- | ----------------- | -------------------- |
| Chip press (spring)        | response: 0.3, damping: 0.7 | Spring            | Instant (no scale)   |
| Chip toggle cross-dissolve | 0.15s                       | easeOut           | Instant              |
| Sharing strip crossfade    | 0.2s                        | easeInOut         | Instant              |
| Partner Dashboard hide     | 0.25s                       | easeInOut         | Instant              |
| Skeleton shimmer loop      | 1.2s / loop                 | linear, repeating | Static placeholder   |
| Sheet presentation         | System                      | System            | System (iOS manages) |
| Navigation push            | System                      | System            | System (iOS manages) |
| Log Sheet dismiss          | System                      | System            | System (iOS manages) |

---

## Haptic Feedback

On Log save (Save CTA tapped in Log Sheet): `UIImpactFeedbackGenerator(.medium)`.

No toast is shown on save success — the UI state change is the confirmation. Do not add additional visual animation on save success beyond the sheet dismiss.

---

## Anti-Patterns — Reject Immediately

| Anti-pattern                                                           | Rule violated                          |
| ---------------------------------------------------------------------- | -------------------------------------- |
| Custom animation without `accessibilityReduceMotion` guard             | §14 Accessibility                      |
| UI state update after `await networkCall()`                            | Optimistic UI contract                 |
| Duration not in the timing table                                       | Animation drift                        |
| Shimmer applied to already-loaded content                              | Motion must serve a purpose            |
| Inconsistent spring values across similar chip surfaces                | Inconsistent press feedback            |
| Full-screen spinner                                                    | §13 States & Feedback                  |
| Custom transition on `NavigationStack` push                            | Spec §11 prohibits — use default push  |
| Custom transition on sheet present/dismiss                             | Native sheet only                      |
| `.animation(.default)` or bare `withAnimation {}` without `value:`     | Implicit animations cause side effects |
| Slower shimmer loop under reduced motion instead of static placeholder | Reduced motion requires no looping     |

---

## Enforcement Checklist

Before marking any animated view complete:

- [ ] `@Environment(\.accessibilityReduceMotion)` is read and respected
- [ ] Under `reduceMotion == true`, all custom animations produce instant state changes
- [ ] Hold/dwell periods are preserved under reduced motion even when animation is skipped
- [ ] UI state updates (chip toggles, strip state, log saves) do not wait on network responses
- [ ] Duration and curve match the timing table exactly — no ad-hoc values
- [ ] Skeleton shimmer is applied only to loading placeholders, never to loaded content
- [ ] Shimmer under reduced motion is a static opacity placeholder, not a slower or paused loop
- [ ] Chip press uses `ChipPressStyle` (spring response 0.3, dampingFraction 0.7)
- [ ] Crossfades use `.animation(_:value:)` scoped to the specific changing property
- [ ] No implicit animations wrapping unrelated state changes
- [ ] `isReadOnly` chips have no press animation
