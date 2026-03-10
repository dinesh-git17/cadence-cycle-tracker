# Cadence — Splash Screen Specification
# `Cadence/Views/Splash/SplashView.swift`

**Version:** 1.0  
**Status:** Approved for Implementation  
**Scope:** iOS 26 · SwiftUI · Path-draw animation

---

## Overview

The splash screen is the first moment a user experiences Cadence on every launch. It consists of two elements: the Cadence mark rendered as an animated SwiftUI `Shape` that draws itself in real time, followed by the wordmark appearing beneath it. No tagline. No loading indicator. The sequence is calm, unhurried, and complete in under 2.5 seconds.

---

## Composition

```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│       [Cadence mark]        │  ← centered, ~160pt wide bounding box
│                             │
│         Cadence             │  ← wordmark, 24pt below mark bottom edge
│                             │
│                             │
│                             │
└─────────────────────────────┘
```

The mark and wordmark are treated as a single centered unit — vertically and horizontally centered as a group on the screen. Equal negative space on all four sides of the pair.

---

## Visual Tokens

| Token | Value | Notes |
|---|---|---|
| Background | `#F5EFE8` | Warm cream — instant fill, no animation |
| Mark color (light) | `#C07050` | Terracotta |
| Mark color (dark) | `#EDE4D8` | Warm ivory — auto via color asset |
| Wordmark color | `.primary` | System — adapts to light/dark automatically |
| Mark bounding box | `160 × 120pt` | Proportions derived from locked PNG asset |
| Wordmark size | `28pt` | `Font.system(.title2, design: .serif)` or custom font when defined |
| Wordmark weight | `.light` | Refined, not heavy |
| Spacing (mark → wordmark) | `24pt` | Fixed, not proportional |

> Typography note: if a custom typeface is defined in the design system, substitute it here. Until then, `.system(.title2, design: .serif)` is the placeholder — it matches the warmth of the app's heading style without introducing a dependency.

---

## Animation Sequence

| Beat | t (seconds) | What | Details |
|---|---|---|---|
| 0 | `0.0s` | Background fills | Instant — no animation |
| 1 | `0.2s` | Path draw begins | `trim(from: 0, to: 1)` — `1.0s` `.easeInOut` |
| 2 | `1.3s` | Wordmark fades up | `opacity 0 → 1` — `0.35s` `.easeOut` |
| 3 | `1.65s` | Hold | Both elements visible, no motion |
| 4 | `2.05s` | Transition to auth | `0.3s` crossfade — `opacity 0` on SplashView |

**Total duration:** ~2.35 seconds from launch to auth screen visible.

---

## Path Draw — Architecture

### The Shape

The Cadence mark is implemented as a custom `Shape` conforming to SwiftUI's `Shape` protocol. The path is defined using cubic Bézier curves whose control points are expressed as percentage multipliers of the frame's width and height — making the shape resolution-independent and safe to use at any size.

```swift
// Cadence/Views/Splash/CadenceMark.swift

struct CadenceMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Control points derived from locked brand asset geometry.
        // Values below are PLACEHOLDERS — replace with traced coordinates
        // from the final PNG asset before shipping.
        path.move(to: CGPoint(
            x: rect.width * 0.18,
            y: rect.height * 0.72
        ))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.80, y: rect.height * 0.26),
            control1: CGPoint(x: rect.width * 0.20, y: rect.height * 0.16),
            control2: CGPoint(x: rect.width * 0.62, y: rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.64, y: rect.height * 0.70),
            control1: CGPoint(x: rect.width * 0.96, y: rect.height * 0.40),
            control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.66)
        )
        return path
    }
}
```

> **Implementation note:** The Bézier control points above are structural placeholders. Before shipping, trace the locked `cadence-mark-light.png` asset in Figma using the Pen tool, read off anchor and handle positions as percentages of the bounding box, and replace these values. This is a ~1 hour task deferred to final implementation.

### The Trim Animation

SwiftUI's `.trim(from:to:)` modifier drives the draw-on effect. Animating `drawProgress` from `0` to `1` causes the stroke to render progressively from start terminal to end terminal.

```swift
// Inside SplashView
@State private var drawProgress: CGFloat = 0

CadenceMark()
    .trim(from: 0, to: drawProgress)
    .stroke(
        Color("CadenceTerracotta"),     // color asset — resolves to #C07050 light, #EDE4D8 dark
        style: StrokeStyle(
            lineWidth: 28,
            lineCap: .round,
            lineJoin: .round
        )
    )
    .frame(width: 160, height: 120)
    .onAppear {
        withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
            drawProgress = 1.0
        }
    }
```

`lineCap: .round` gives both terminals their tapered, lifted-brush quality for free — no additional geometry required.

### Wordmark

```swift
@State private var wordmarkOpacity: Double = 0

Text("Cadence")
    .font(.system(.title2, design: .serif))
    .fontWeight(.light)
    .foregroundStyle(.primary)
    .opacity(wordmarkOpacity)
    .onAppear {
        withAnimation(.easeOut(duration: 0.35).delay(1.3)) {
            wordmarkOpacity = 1.0
        }
    }
```

---

## Reduced Motion

All animation is gated on `@Environment(\.accessibilityReduceMotion)`. When the user has enabled Reduce Motion in iOS Settings:

- `drawProgress` is set to `1.0` immediately with no animation — the mark appears fully drawn at once
- `wordmarkOpacity` is set to `1.0` immediately with no animation
- Hold duration is preserved at `0.4s` before transitioning to auth

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private func runEntrance() {
    if reduceMotion {
        drawProgress = 1.0
        wordmarkOpacity = 1.0
    } else {
        withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
            drawProgress = 1.0
        }
        withAnimation(.easeOut(duration: 0.35).delay(1.3)) {
            wordmarkOpacity = 1.0
        }
    }
}
```

---

## Dark Mode

The background color, mark color, and wordmark color all resolve automatically via:

- **Background:** A `Color` asset named `CadenceBackground` with light value `#F5EFE8` and dark value `#1C1410`
- **Mark:** A `Color` asset named `CadenceMark` with light value `#C07050` and dark value `#EDE4D8`
- **Wordmark:** `.primary` — system-provided, resolves correctly in both modes

No conditional logic in the view. Color assets do all the work.

---

## Transition to Auth

The splash-to-auth transition is a crossfade driven by a parent coordinator. After the hold period, the `SplashView` fades out at `opacity 0` over `0.3s` while the `AuthView` fades in simultaneously.

```swift
// SplashView signals completion via a callback, not a NavigationLink.
// The parent (AppCoordinator or ContentView) owns the transition.

var onComplete: () -> Void

// Called after hold period
DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
    onComplete()
}
```

The parent applies the transition:

```swift
withAnimation(.easeInOut(duration: 0.3)) {
    showSplash = false
}
```

---

## File Structure

```
Cadence/
  Views/
    Splash/
      SplashView.swift          ← root view, owns animation state
      CadenceMark.swift         ← Shape definition, Bézier path
  Resources/
    Colors.xcassets/
      CadenceBackground.colorset/  ← light: #F5EFE8, dark: #1C1410
      CadenceMark.colorset/        ← light: #C07050, dark: #EDE4D8
    Images.xcassets/
      cadence-mark-light.png    ← locked asset (reference for path tracing)
      cadence-mark-dark.png     ← locked asset (reference only)
      cadence-mark-tinted.png   ← locked asset (App Icon tinted variant)
```

---

## Implementation Checklist

- [ ] Create `CadenceMark.swift` — `Shape` with placeholder Bézier coordinates
- [ ] Create `SplashView.swift` — animation state, layout, reduced motion path
- [ ] Create `CadenceBackground` color asset (light + dark)
- [ ] Create `CadenceMark` color asset (light + dark)
- [ ] Add App Icon assets (light, dark, tinted) to `Images.xcassets`
- [ ] Wire `SplashView` into `ContentView` / `AppCoordinator` with crossfade transition
- [ ] **Final step:** Trace locked PNG in Figma → replace placeholder Bézier coordinates in `CadenceMark.swift`
- [ ] Test reduced motion path on device with Accessibility > Reduce Motion enabled
- [ ] Test dark mode on device

---

## Open Items

| Item | Owner | When |
|---|---|---|
| Trace Bézier control points from locked PNG | Designer / Dinesh | Pre-ship, after screens complete |
| Confirm typeface once design system is defined | Designer | Design spec phase |
| Confirm wordmark tracking / letter-spacing | Designer | Design spec phase |

---

*Cadence Splash Screen Spec — v1.0 — March 7, 2026*  
*Dependent on: locked brand mark assets (light, dark, tinted) — complete*
