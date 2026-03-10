# Phase-to-Epic Mapping Reference

Derived from `docs/PHASES.md` Phase Notes "Likely epics" sections. Use as a starting point for decomposition -- refine against source documents before finalizing.

## Phase 0 -- Project Foundation (Est. 3-4 epics)

1. XcodeGen project spec + target configuration
2. xcassets color token setup (10 colors, light + dark)
3. CI workflow skeleton (lint, build jobs)
4. Enforcement scripts and hooks (SwiftLint, Protocol Zero, em-dash)

**Blocker:** CadencePrimary token undefined in Design Spec section 3. Do not add a placeholder.

## Phase 1 -- Supabase Backend (Est. 3-4 epics)

1. Supabase project creation + extension enablement
2. 8-table schema migration
3. RLS policy set
4. Auth provider configuration (Apple, Google, email/password)
5. Edge Function directory scaffold (full implementation in Phase 10)

**Note:** Items 3 and 4 may merge depending on complexity.

## Phase 2 -- Authentication & Onboarding (Est. 3 epics)

1. Splash screen (CadenceMark.swift, SplashView.swift, animation sequence, reduced motion path)
2. Auth screen UI + supabase-swift session integration
3. Role selection + AppCoordinator routing
4. Tracker onboarding form + cycle_profiles write
5. Partner onboarding invite code entry + validation

**Note:** Items 2-3 and 4-5 each pair naturally.

## Phase 3 -- Core Data Layer & Prediction Engine (Est. 4 epics)

1. SwiftData model definitions (all 5 entities)
2. Prediction algorithm implementation (next period, ovulation, fertile window)
3. Confidence scoring (all three thresholds, SD calculation)
4. Prediction edge case unit tests (10 required)
5. SyncCoordinator skeleton with write queue structure

**Note:** Items 2-3 are tightly coupled. Item 4 may merge with items 2-3 as test stories.

## Phase 4 -- Tracker Navigation Shell & Core Logging (Est. 5 epics)

1. 5-tab TabView with Liquid Glass chrome + Log tab modal intercept
2. Log Sheet content (period toggles, flow chips, symptom grid, notes, private flag, save CTA)
3. SymptomChip component (all states, Sex chip lock icon, isReadOnly parameter)
4. PeriodToggle + Primary CTA Button components
5. Motion spec implementation (chip spring, toggle cross-dissolve, sheet detents, reduced motion gating)

**Note:** Items 3-4 form a component library epic. Item 5 may distribute as stories across items 1-4.

## Phase 5 -- Tracker Home Dashboard (Est. 4 epics)

1. Sharing status strip (active/paused states, crossfade, CadencePrimary gap blocker)
2. Cycle Status Card + confidence badge
3. Countdown Row (both cards, 48pt numerals)
4. Today's Log Card + Insight Card + skeleton loading states

**Blocker:** CadencePrimary gap affects item 1. Insight Card derivation algorithm unspecified.

## Phase 6 -- Calendar View (Est. 3-4 epics)

1. Month grid layout + day state rendering (all 5 visual states from section 12.4)
2. Fertile window band + ovulation day indicator
3. Day-tap detail read-sheet (.medium detent)
4. Historical entry edit path via Log Sheet (pre-populated)

## Phase 7 -- Sync Layer (Est. 4 epics)

1. Write queue with offline-first guarantee + initial data pull
2. Last-write-wins conflict resolution + updated_at semantics
3. Realtime channel subscription setup (partner_connections, daily_logs)
4. NWPathMonitor offline indicator + exponential backoff retry + auth session resilience

## Phase 8 -- Partner Connection & Privacy Architecture (Est. 5 epics)

1. Invite code generation + partner_connections write
2. Partner onboarding code validation + connection handshake + confirmation screen
3. 6 permission category toggles UI (Settings surface)
4. Pause sharing + disconnect flows
5. Privacy enforcement layer (isPrivate before RLS, Sex symptom exclusion, Partner query column projection)

## Phase 9 -- Partner Navigation Shell & Dashboard (Est. 4 epics)

1. 3-tab Partner TabView + NavigationStack (isolated from Tracker)
2. Bento grid cards (Phase, Countdown, Symptoms, Notes) using Data Card
3. Paused sharing state (0.25s easeInOut crossfade)
4. Realtime subscription integration + read-only enforcement + empty states

**Note:** Items 3-4 may merge as they both involve Partner state rendering.

## Phase 10 -- Notifications (Est. 4 epics)

1. Tracker reminder scheduling (3 types, UNUserNotificationCenter, configurable advance days)
2. Partner push notification dispatch (3 types, APNS via Edge Function)
3. Edge Function full implementation
4. Notification permission request flow + reminder_settings UI
5. Partner mute controls

**Blocker:** Notification content specification is an open item per Design Spec section 15.

## Phase 11 -- Reports (Est. 3 epics)

1. Chart components + metric cards (pending chart type specification)
2. Reports data reads from SwiftData
3. 2-cycle minimum gate + empty state

**Blocker:** Reports screen spec is a post-alpha open item per Design Spec section 15.

## Phase 12 -- Settings (Est. 4 epics)

1. Tracker cycle defaults + partner management section
2. Reminder preferences + app lock (Face ID / Touch ID / passcode)
3. Delete all data (local + Supabase, confirmation)
4. Partner Settings (notification preferences, connection status, disconnect, account)

## Phase 13 -- Accessibility Compliance (Est. 3 epics)

1. Touch target audit + remediation across all interactive elements
2. VoiceOver accessibilityLabel audit (all chips, lock icon, nav elements)
3. Dynamic Type + reduced motion gating verification
4. WCAG AA on-device contrast audit (light and dark modes)

**Note:** Items 3-4 may merge as both are non-functional verification passes.

## Phase 14 -- Pre-TestFlight Hardening (Est. 4-5 epics)

1. CI/CD pipeline (GitHub Actions, Fastlane, secrets, simulator matrix)
2. Unit test coverage gate (80%+ on data + domain layers) + UI test suite
3. Device validation (dark mode contrast, performance, offline E2E)
4. Haptic library + CadenceMark Bezier finalization
5. TestFlight build distribution
