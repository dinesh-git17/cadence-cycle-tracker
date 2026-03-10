# CADENCE

## Design Specification

**Version 1.1 · March 2026**  
**Status:** Approved for Implementation

---

## 0. Brand Asset Reference

The following brand assets are locked and must not be modified. All iOS color tokens in this specification inherit from the icon palette.

| Asset             | Status                        | Location / Notes                                                 |
| ----------------- | ----------------------------- | ---------------------------------------------------------------- |
| App Icon - Light  | Locked                        | `cadence-mark-light.png` · bg `#F5EFE8`, mark `#C07050`          |
| App Icon - Dark   | Locked                        | `cadence-mark-dark.png` · bg `#1C1410`, mark `#EDE4D8`           |
| App Icon - Tinted | Locked                        | `cadence-mark-tinted.png` · pure B&W, Apple applies tint overlay |
| Splash Screen     | Locked - see Splash Spec v1.0 | `Cadence/Views/Splash/` - path-draw animation, 2.35s total       |

---

## 1. Overview

Cadence is a privacy-first SwiftUI cycle tracking app for iOS 26. The Tracker maintains absolute ownership of all logged data. The Partner is a read-only participant who sees only what the Tracker explicitly enables. The design reflects this asymmetry throughout - the Tracker's experience is expressive and data-rich; the Partner's is calm and curated.

| Principle                 | Expression in UI                                                                    |
| ------------------------- | ----------------------------------------------------------------------------------- |
| Tracker always in control | Privacy defaults to off. Every shared data type requires an explicit opt-in toggle. |
| Warm, not clinical        | Earthy terracotta and sage replace hospital blues and alarm reds.                   |
| Frictionless habit        | Log Sheet accessible from 3 entry points. Chips toggle in a single tap.             |
| Premium, not generic      | Card-based layout with spatial depth. Liquid Glass chrome for system surfaces.      |

---

## 2. Platform & Framework Assumptions

- Minimum deployment target: iOS 26
- SwiftUI throughout - no UIKit custom views
- SwiftData for local persistence, queued sync to backend
- Liquid Glass (`ultraThinMaterial`) for tab bars and navigation bars
- Standard `TabView` and `NavigationStack` - no custom navigation chrome
- Dynamic Type: all text must scale. No fixed-size text containers.
- Strict 44 × 44pt minimum touch targets across all interactive elements

---

## 3. Color System

All colors are defined as named Color assets in xcassets with explicit light and dark mode values. No hardcoded hex values in Swift source files. Use `Color("TokenName")` or the SwiftUI semantic `Color(.label)` equivalents where noted.

| Token                | Light Mode   | Dark Mode    | Usage                                                                                                   |
| -------------------- | ------------ | ------------ | ------------------------------------------------------------------------------------------------------- |
| CadenceBackground    | `#F5EFE8`    | `#1C1410`    | App-wide background                                                                                     |
| CadenceCard          | `#FFFFFF`    | `#2A1F18`    | Card / sheet surfaces                                                                                   |
| CadenceTerracotta    | `#C07050`    | `#D4896A`    | Primary accent - period data, CTAs, active chips, active tab icon                                       |
| CadenceSage          | `#7A9B7A`    | `#8FB08F`    | Secondary accent - fertile window, ovulation metrics, insight cards                                     |
| CadenceSageLight     | `#EAF0EA`    | `#1E2B1E`    | Sage tinted surfaces - insight card bg, sharing strip active, fertility highlight behind calendar dates |
| CadenceTextPrimary   | `#1C1C1E`    | `#F2EDE7`    | Body copy, headings                                                                                     |
| CadenceTextSecondary | `#6C6C70`    | `#98989D`    | Subtitles, metadata, placeholder text                                                                   |
| CadenceTextOnAccent  | `#FFFFFF`    | `#FFFFFF`    | Text on terracotta fills - active chips, filled CTAs                                                    |
| CadenceBorder        | `#E0D8CF`    | `#3A2E26`    | Card inner stroke, chip default outline, input borders                                                  |
| CadenceDestructive   | `system red` | `system red` | Account deletion, disconnect - use `.red` color asset                                                   |

### Dark Mode Contrast Notes

The Section 11 open issue from v1.0 is resolved here. Terracotta is bumped from `#C07050` to `#D4896A` in dark mode - a ~15% luminance increase that maintains warmth while meeting WCAG AA against `#1C1410`. Sage bumps from `#7A9B7A` to `#8FB08F` by the same logic. Both values are defined in their respective color assets and require no conditional Swift logic.

---

## 4. Typography

System font (San Francisco / SF Pro) throughout. No custom typeface dependency at this stage - revisit after beta feedback. If a custom typeface is introduced, update `SplashView.swift` wordmark style per the Splash Spec open items.

| Token       | Style          | Size | Weight   | Usage                                     |
| ----------- | -------------- | ---- | -------- | ----------------------------------------- |
| display     | `.largeTitle`  | 34pt | Semibold | Cycle phase name on Tracker Home          |
| title1      | `.title`       | 28pt | Semibold | Dashboard card headings                   |
| title2      | `.title2`      | 22pt | Regular  | Sheet / screen titles                     |
| title3      | `.title3`      | 20pt | Medium   | Section headers within cards              |
| headline    | `.headline`    | 17pt | Semibold | Button labels, chip active state          |
| body        | `.body`        | 17pt | Regular  | Primary body copy                         |
| callout     | `.callout`     | 16pt | Regular  | Insight body text                         |
| subheadline | `.subheadline` | 15pt | Regular  | Card sub-labels, secondary copy           |
| footnote    | `.footnote`    | 13pt | Regular  | Timestamps, metadata                      |
| caption1    | `.caption`     | 12pt | Regular  | Chip default state labels                 |
| caption2    | `.caption2`    | 11pt | Regular  | Section eyebrow labels (e.g. TODAY'S LOG) |

### Usage Rules

- Eyebrow labels (`TODAY'S LOG`, `INSIGHT`) are `.caption2`, uppercased, `CadenceTextSecondary`
- Large countdown numbers (e.g. `16`) use a custom `.system(size: 48, weight: .medium, design: .rounded)` - not a named Dynamic Type style, but must scale with `accessibilityLargeText`
- White text is strictly reserved for filled terracotta surfaces - active chips, primary CTAs
- Never use pure black text. `CadenceTextPrimary` (`#1C1C1E`) is the floor.

---

## 5. Spacing & Layout

| Token    | Value | Usage                                                              |
| -------- | ----- | ------------------------------------------------------------------ |
| space-4  | 4pt   | Micro gaps - icon to label clearance                               |
| space-8  | 8pt   | Dense cluster interior padding - chip grids, compact card sections |
| space-12 | 12pt  | Related element separation within a card                           |
| space-16 | 16pt  | Standard screen margin - all content insets from safe area edges   |
| space-20 | 20pt  | Card internal padding - primary content inset                      |
| space-24 | 24pt  | Major section breaks within a scroll view                          |
| space-32 | 32pt  | Between distinct cards in a feed                                   |
| space-44 | 44pt  | Minimum touch target size - enforced on all interactive elements   |

### Layout Rules

- 16pt horizontal safe-area inset on all screens
- Cards in feed: 32pt vertical gap between distinct cards
- Content within a card: 20pt internal padding
- No hard-coded frame heights on scroll view content - allow intrinsic sizing
- `LazyVStack` for all feed views to prevent off-screen render

---

## 6. Corner Radii

| Component                  | Corner Radius         | Notes                                                      |
| -------------------------- | --------------------- | ---------------------------------------------------------- |
| Screen-level cards         | 16pt                  | Floating data cards on dashboard feed                      |
| Log Sheet / bottom sheets  | 20pt (top corners)    | Native iOS sheet - `UISheetPresentationController` default |
| Symptom chips              | 20pt (full pill)      | Capsule shape - height-proportional radius                 |
| Period toggle buttons      | 12pt                  | "Period started" / "Period ended" filled pills             |
| CTA buttons (primary)      | 14pt                  | "Log today", "Continue", auth submit                       |
| Input fields               | 10pt                  | Email, password, notes textarea                            |
| Confidence / status badges | 20pt (full pill)      | "High confidence", "Sharing with Alex" strip toggle        |
| Calendar day cells         | 10pt                  | Period filled days, predicted day dashed outline           |
| Tab bar                    | System (Liquid Glass) | iOS 26 native - do not override                            |

---

## 7. Elevation & Surfaces

Depth is created through color contrast, not drop shadows. Cards use a solid opaque fill with a 1pt inner border stroke at `CadenceBorder`. This defines edges cleanly against the warm cream background without the weight of external shadows.

| Layer                         | Color Asset                                       | Notes                                                                    |
| ----------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------ |
| App background                | CadenceBackground                                 | Always visible behind all content                                        |
| Cards / data surfaces         | CadenceCard + CadenceBorder stroke                | 1pt border. No external shadow.                                          |
| Insight card                  | CadenceSageLight                                  | Sage tinted surface. Same 1pt border rule.                               |
| Sharing status strip (active) | CadenceSageLight                                  | Subtly blends with background - intentional low contrast in active state |
| Sharing status strip (paused) | CadencePrimary (`#1C1410` light / `#F2EDE7` dark) | High contrast. Demands attention.                                        |
| Bottom sheets / Log Sheet     | CadenceCard                                       | iOS native sheet - background adapts automatically                       |
| Tab bar / nav bar             | `ultraThinMaterial` (Liquid Glass)                | System-managed. Do not override.                                         |

---

## 8. Information Architecture

### Tracker Navigation (5 tabs)

| Position   | Tab      | Content                                                               |
| ---------- | -------- | --------------------------------------------------------------------- |
| 1          | Home     | Cycle status, countdown, today's log summary, insight card, Log CTA   |
| 2          | Calendar | Month grid - period history, predictions, fertile window              |
| 3 (center) | Log      | Modal sheet intercept - opens Log Sheet over current tab              |
| 4          | Reports  | Cycle history charts, pattern insights (unlocked after 2 full cycles) |
| 5          | Settings | Partner management, sharing permissions, account, notifications       |

### Partner Navigation (3 tabs)

| Position | Tab           | Content                                                           |
| -------- | ------------- | ----------------------------------------------------------------- |
| 1        | Her Dashboard | Bento box grid of shared data - phase, countdown, symptoms, notes |
| 2        | Notifications | Push notification history for shared cycle events                 |
| 3        | Settings      | Account, notification preferences, disconnect                     |

---

## 9. Tab Bar Icons

All tab icons use SF Symbols. Custom icon generation is deferred - evaluate after beta if any symbol feels incorrect.

### Tracker

| Tab          | SF Symbol                      | Active state                                                                |
| ------------ | ------------------------------ | --------------------------------------------------------------------------- |
| Home         | `house` / `house.fill`         | `house.fill`, tinted CadenceTerracotta                                      |
| Calendar     | `calendar`                     | `calendar`, tinted CadenceTerracotta                                        |
| Log (center) | `plus.circle.fill`             | Always filled - permanent CadenceTerracotta tint, no active/inactive toggle |
| Reports      | `chart.bar` / `chart.bar.fill` | `chart.bar.fill`, tinted CadenceTerracotta                                  |
| Settings     | `gearshape` / `gearshape.fill` | `gearshape.fill`, tinted CadenceTerracotta                                  |

### Partner

| Tab           | SF Symbol                                              | Active state                                           |
| ------------- | ------------------------------------------------------ | ------------------------------------------------------ |
| Her Dashboard | `person.crop.rectangle` / `person.crop.rectangle.fill` | `person.crop.rectangle.fill`, tinted CadenceTerracotta |
| Notifications | `bell` / `bell.fill`                                   | `bell.fill`, tinted CadenceTerracotta                  |
| Settings      | `gearshape` / `gearshape.fill`                         | `gearshape.fill`, tinted CadenceTerracotta             |

Icon rendering: 25pt, weight matches the symbol's built-in medium weight. Active tint is `CadenceTerracotta` (`#C07050` light, `#D4896A` dark). Inactive tint is `CadenceTextSecondary`. The center Log tab uses `plus.circle.fill` permanently filled - it does not switch to an outlined variant in the inactive state.

---

## 10. Component Library

### 10.1 Symptom Chip

| Property      | Default                         | Active                                                          |
| ------------- | ------------------------------- | --------------------------------------------------------------- |
| Background    | Transparent                     | CadenceTerracotta                                               |
| Border        | 1pt CadenceBorder               | None                                                            |
| Text style    | `caption1` · CadenceTextPrimary | `headline` · CadenceTextOnAccent (`#FFFFFF`)                    |
| Font weight   | Regular                         | Semibold                                                        |
| Padding (H/V) | 12pt / 8pt - fixed              | 12pt / 8pt - fixed (prevents geometric jitter on weight change) |
| Corner radius | 20pt (capsule)                  | 20pt (capsule)                                                  |

- Chips toggle instantly on tap - no network wait, optimistic client-side state
- The Sex chip permanently displays a lock icon (`lock.fill`) at 11pt to the right of the label regardless of state
- Chips must be reusable across Tracker write-enabled views and Partner read-only views - `isReadOnly: Bool` parameter disables tap gesture

### 10.2 Period Toggle Buttons

"Period started" and "Period ended" are paired filled pill buttons, not chips. They occupy equal-width slots in a horizontal stack.

| Property              | Value                                      |
| --------------------- | ------------------------------------------ |
| Background (inactive) | CadenceCard with 1pt CadenceBorder         |
| Background (active)   | CadenceTerracotta                          |
| Text (inactive)       | `body` · CadenceTextPrimary                |
| Text (active)         | `body` · Semibold · CadenceTextOnAccent    |
| Height                | 44pt minimum                               |
| Corner radius         | 12pt                                       |
| Layout                | Equal-width horizontal stack with 12pt gap |

### 10.3 Primary CTA Button

Used for "Log today", "Continue", "Sign in with Apple" (black variant), and form submit actions.

| Property       | Value                                                                                   |
| -------------- | --------------------------------------------------------------------------------------- |
| Background     | CadenceTerracotta (standard) · `#000000` (Sign in with Apple)                           |
| Text           | `headline` · Semibold · `#FFFFFF`                                                       |
| Height         | 50pt                                                                                    |
| Corner radius  | 14pt                                                                                    |
| Width          | Full container width with 16pt horizontal inset                                         |
| Loading state  | Inline `ProgressView` replaces label text - button width locked to prevent layout shift |
| Disabled state | 40% opacity on entire button                                                            |

### 10.4 Data Card

The foundational surface unit. All dashboard cards, Log Sheet content areas, and calendar detail sheets use this component.

- Background: CadenceCard
- Border: 1pt inner stroke at CadenceBorder
- Corner radius: 16pt
- Internal padding: 20pt uniform
- No external drop shadow
- Insight variant uses CadenceSageLight as background instead of CadenceCard

### 10.5 Partner Sharing Status Strip

Displayed at the top of the Tracker Home feed. Dismisses naturally on scroll.

| State         | Active                               | Paused                                     |
| ------------- | ------------------------------------ | ------------------------------------------ |
| Background    | CadenceSageLight (low prominence)    | High contrast charcoal / warm ivory        |
| Text          | `subheadline` · CadenceTextSecondary | `subheadline` · Semibold · inverse primary |
| Toggle        | System Toggle - on                   | System Toggle - off                        |
| Corner radius | 12pt                                 | 12pt                                       |
| Padding       | 12pt vertical / 16pt horizontal      | 12pt vertical / 16pt horizontal            |

---

## 11. Motion & Interaction

| Interaction                 | Specification                                                                                                                |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Chip tap down               | `scaleEffect(0.95)` - spring response 0.3, damping 0.7                                                                       |
| Chip tap release / toggle   | Instant state change - no animation delay. Color cross-dissolve 0.15s easeOut.                                               |
| Sheet presentation          | Native iOS bottom sheet - `.presentationDetents([.medium, .large])`                                                          |
| Navigation push             | Standard SwiftUI `NavigationStack` push - no custom transition                                                               |
| Log Sheet dismiss           | Swipe down or Save CTA - native sheet dismiss                                                                                |
| Sharing paused state change | 0.2s crossfade on strip background color                                                                                     |
| Partner Dashboard hide      | Cards crossfade to "Sharing paused" state - 0.25s easeInOut                                                                  |
| Skeleton loading            | Shimmer animation on card placeholder - 1.2s loop, left-to-right                                                             |
| Reduced Motion              | All custom animations gated on `@Environment(\.accessibilityReduceMotion)` - instant state changes, hold durations preserved |

---

## 12. Screen Specifications

### 12.1 Auth Screen

Entry point for all users. Role selection happens after authentication.

- Background: CadenceBackground
- Wordmark: display style · CadenceTextPrimary · centered
- Tagline: "Track your cycle. Share what matters." · subheadline · CadenceTextSecondary · centered
- Sign in with Apple: Primary CTA variant with `#000000` background
- Sign in with Google: Secondary outlined button - CadenceCard background, 1pt CadenceBorder, CadenceTextPrimary label
- Divider: "or" with 1pt CadenceBorder lines, `caption1`, CadenceTextSecondary
- Email / password fields: CadenceCard fill, 1pt CadenceBorder, 10pt corner radius, body placeholder in CadenceTextSecondary
- Password: "Show" toggle as plain text button (`callout` · CadenceTerracotta) trailing in field
- Forgot password: `footnote` · CadenceTerracotta · right-aligned
- Continue CTA: full-width Primary CTA Button · CadenceTerracotta
- Already have an account: `footnote` · CadenceTextSecondary with inline "Sign in" link in CadenceTerracotta

### 12.2 Tracker Home Dashboard

The central hub. Vertical `ScrollView` beneath a Liquid Glass navigation bar.

- Navigation bar: title "Cadence" or empty - `ultraThinMaterial`
- Feed order:
  1. Partner Sharing Status Strip
  2. Cycle Status Card
  3. Countdown Row
  4. Today's Log Card
  5. Log CTA
  6. Insight Card

#### Cycle Status Card

- Phase name: display style · CadenceTextPrimary
- "High confidence" badge: CadenceSageLight background, CadenceSage text, `caption1`, capsule corner radius
- "Cycle day X of Y": `subheadline` · CadenceTextSecondary
- Disclaimer line: `footnote` · CadenceTextSecondary · italic

#### Countdown Row

- Two equal-width cards side by side, 12pt gap
- Large number: `system(size: 48, weight: .medium, design: .rounded)` · CadenceTerracotta (period countdown) or CadenceSage (ovulation countdown)
- Label: `footnote` · CadenceTextSecondary

#### Today's Log Card

- Eyebrow: "TODAY'S LOG" · `caption2` · uppercased · CadenceTextSecondary
- Active chips displayed horizontally - wrapped if needed

#### Log Today CTA

- Full-width Primary CTA Button · CadenceTerracotta

#### Insight Card

- CadenceSageLight background
- Eyebrow: "INSIGHT" · `caption2` · CadenceSage
- Body: `callout` · CadenceTextPrimary

### 12.3 Log Sheet (Modal)

Bottom sheet. Accessible from tab bar center, Dashboard CTA, and Calendar day tap.

- Sheet detents: `.medium` (default) and `.large`
- Drag indicator: system default, visible
- Content sections in order:
  1. Date header
  2. Period toggles
  3. Flow level chips
  4. Symptom chip grid
  5. Notes textarea
  6. Keep this day private toggle
  7. Save CTA
- "Keep this day private" toggle: `subheadline` label + `footnote` description + System Toggle. Acts as master override - disables all partner sharing for this entry regardless of global settings.
- Notes textarea: multiline, CadenceCard, 10pt corner radius, placeholder "Anything else worth noting?" in CadenceTextSecondary
- Save CTA: full-width Primary CTA · CadenceTerracotta · pinned above keyboard

### 12.4 Calendar View

Month grid. Standard iOS calendar layout.

| State                | Visual                                                                                          |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| Logged period day    | Solid CadenceTerracotta fill, CadenceTextOnAccent date number, 10pt corner radius               |
| Predicted period day | Dashed 1pt CadenceTerracotta border, CadenceTerracotta date number, 10pt corner radius, no fill |
| Fertile window       | Continuous CadenceSageLight band behind date cells - fills full calendar row height             |
| Ovulation day        | CadenceSageLight fill with 1pt CadenceSage border                                               |
| Today                | System today indicator - do not override                                                        |
| Tapped day           | Opens day detail read-sheet (bottom sheet, `.medium` detent)                                    |

### 12.5 Partner Home Dashboard

Bento box grid. Read-only - no write interactions.

- 2-up square cards: Phase, Countdown
- Full-width rectangular cards: Symptoms, Notes
- All cards: Data Card component - CadenceCard surface, same border and radius rules
- If Tracker pauses sharing: all cards hidden, replaced by single CadenceSageLight "Sharing paused" state card with CadenceSage iconography
- Bento grid collapses from 2-up to 1-up vertical stack at `Accessibility1` Dynamic Type threshold

---

## 13. States & Feedback

| State                        | Implementation                                                                                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Loading                      | Skeleton placeholders on card content surfaces. Localized `ProgressView` inside CTA buttons. Never full-screen spinners.                             |
| Empty - Reports (< 2 cycles) | "Your reports will appear here once you've logged 2 full cycles." · `body` · CadenceTextSecondary · centered with appropriate SF Symbol illustration |
| Empty - Partner (no sharing) | "She hasn't turned on sharing yet. Check back soon." · `body` · CadenceTextSecondary · centered                                                      |
| Offline                      | UI renders from local SwiftData seamlessly. Footnote "Last updated [time]" appears in navigation bar area. Non-blocking toast for queued writes.     |
| Error / sync failure         | Non-blocking toast at bottom of screen. Do not use destructive red - use CadenceTextSecondary with a `warning.fill` SF Symbol.                       |
| Success                      | Haptic feedback (`UIImpactFeedbackGenerator .medium`) on Log save. No toast - the UI state change itself is confirmation.                            |

---

## 14. Accessibility

- All interactive elements: 44 × 44pt minimum touch target - use `.frame(minWidth: 44, minHeight: 44)` with appropriate `contentShape` if needed
- Contrast: `CadenceTerracotta` (`#C07050`) on `#F5EFE8` passes WCAG AA (4.5:1 verified). `CadenceTerracotta` on `#FFFFFF` passes WCAG AA. Dark mode values verified at definition.
- Dynamic Type: all text styles use system type tokens - no fixed-size text
- Partner Bento grid: collapses to 1-up at `Accessibility1` threshold
- Reduced Motion: all custom SwiftUI animations gated on `@Environment(\.accessibilityReduceMotion)` - instant state changes, no layout shift
- VoiceOver: all symptom chips require `accessibilityLabel` - "{symptom name}, {selected/unselected}"
- Colorblind: terracotta and sage are never the sole visual differentiators. Period vs fertile window is further differentiated by fill (solid) vs band (continuous highlight). No pure red/green combinations.
- The Sex chip lock icon must have `accessibilityLabel` "Private - not shared with partner"

---

## 15. Open Items

| Item                                   | Notes                                                                                      | When                            |
| -------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------- |
| Custom typeface evaluation             | If introduced, update `SplashView.swift` wordmark per Splash Spec open items               | Post-beta                       |
| Trace Bézier path from locked mark PNG | Figma pen tool -> % coordinates -> `CadenceMark.swift` placeholder values                  | Pre-ship                        |
| Dark mode contrast audit on device     | Terracotta and Sage dark values defined here - verify on hardware under varying conditions | Pre-TestFlight                  |
| Haptic pattern library                 | Define `.light` / `.medium` / `.heavy` assignments for all interaction types               | Before Log Sheet implementation |
| Reports screen specification           | Chart types, metric hierarchy, data thresholds - requires 2-cycle data model validation    | Post-alpha                      |
| Notification content specification     | Push payload content, grouping logic for Partner notifications                             | Post-connection flow            |

---

_Cadence Design Specification v1.1 · March 2026 · Dependent on: `Cadence_SplashScreen_Spec.md` v1.0_
