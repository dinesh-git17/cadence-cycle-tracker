# Partner Bento Grid Components

**Epic ID:** PH-9-E2
**Phase:** 9 -- Partner Navigation Shell & Dashboard
**Estimated Size:** L
**Status:** Draft

---

## Objective

Implement PartnerDashboardViewModel with its complete state machine and all 4 Bento grid card types (Phase, Countdown, Symptoms, Notes) using the Data Card component. Deliver the full visual presentation layer -- including Bento layout, skeleton loading, and the Accessibility1 1-up collapse -- driven by stub data and ready for live Supabase binding in PH-9-E3.

## Problem / Context

The Partner Home Dashboard is the primary surface a Partner interacts with daily. Its 4 cards present the Tracker's current cycle state in curated, plain-language form. All 4 cards are built on the Data Card component (Design Spec §10.4) for visual consistency with other dashboard surfaces. Building the visual layer against stub data isolates visual correctness from data correctness and enables the Bento grid to be reviewed and adjusted before Realtime wiring is in place. The ViewModel state machine must exist before PH-9-E3 can bind live data to it. The Accessibility1 1-up collapse is a mandatory behavioral requirement, not an enhancement -- it must be implemented here, not deferred to the Phase 13 accessibility audit.

Source authority: Design Spec v1.1 §10.4 (Data Card spec), §12.5 (Partner Home Dashboard), §13 (skeleton loading), §14 (accessibility -- 1-up collapse); MVP Spec §4 (Partner home components); cadence-accessibility skill; cadence-design-system skill.

## Scope

### In Scope

- PartnerDashboardSnapshot value type: phaseLabel (String), countdownDays (Int?), symptomChipStates ([SymptomChipState]), notes (String?), isLoggedToday (Bool)
- PartnerDashboardViewModel (@Observable): state machine with cases .loading, .loaded(PartnerDashboardSnapshot), .paused, .empty, .error(message: String); stub initializer sets state to .loaded with preview data
- Phase card: 2-up square Data Card; phase label in headline style, CadenceTextPrimary; no secondary text in Phase 9 scope
- Countdown card: 2-up square Data Card; days integer in `system(size: 48, weight: .medium, design: .rounded)` at CadenceTerracotta; "days until next period" label in footnote style, CadenceTextSecondary
- Symptoms card: full-width rectangular Data Card; read-only SymptomChip grid using Phase 4 SymptomChip component with isReadOnly=true (no tap gesture, no press animation); chips use existing chip component with isReadOnly parameter
- Notes card: full-width rectangular Data Card; notes text in body style, CadenceTextPrimary; empty variant shows "No notes added today" in body style, CadenceTextSecondary
- Bento grid container: LazyVStack outer container; HStack 2-up row with equal card widths and 12pt horizontal gap for Phase and Countdown cards; VStack for Symptoms and Notes cards below; 16pt vertical spacing between all grid rows
- Data Card spec applied to all 4 cards: CadenceCard fill background, 1pt inner stroke at CadenceBorder, 16pt corner radius, 20pt uniform internal padding, no external drop shadow
- Accessibility 1-up collapse: detect @Environment(\.sizeCategory); when sizeCategory >= .accessibilityMedium, replace HStack 2-up with VStack 1-up for Phase and Countdown cards (full-width, same Data Card surface)
- Skeleton loading placeholder: per Design Spec §13, shimmer animation (1.2s loop, left-to-right gradient mask advancing across card surface) for each of the 4 card slots while ViewModel state is .loading; under @Environment(\.accessibilityReduceMotion), static fill at opacity 0.4 with no motion; shimmer color: CadenceCard with a CadenceBorder-tinted overlay gradient

### Out of Scope

- Live Supabase data binding and PartnerDataService (PH-9-E3)
- Realtime subscription lifecycle management (PH-9-E3)
- Paused state card UI and crossfade animation (PH-9-E4)
- permission-gated conditional rendering based on share_* flag values (PH-9-E3 -- driven by what RLS returns)
- Reports, Calendar, or Log content (out of scope for Partner role entirely)
- Mood indicator as a separate card (spec §12.5 names 4 cards: Phase, Countdown, Symptoms, Notes; mood is captured as a chip within the Symptoms card if the symptom set includes a mood entry)

## Dependencies

| Dependency | Type | Phase/Epic | Status | Risk |
| --- | --- | --- | --- | --- |
| PartnerTabView shell with NavigationStack (Her Dashboard tab content slot) | FS | PH-9-E1 | Unresolved (same phase) | Low |
| SymptomChip component with isReadOnly: Bool parameter | FS | PH-4 | Resolved | Medium |
| CadenceCard, CadenceBorder, CadenceTerracotta, CadenceTextPrimary, CadenceTextSecondary color assets | FS | PH-0 | Resolved | Low |
| Data Card component (if already extracted as a reusable view in Phase 5 or prior) | SS | PH-5 | Open | Low |

## Assumptions

- SymptomChip from Phase 4 accepts `isReadOnly: Bool` parameter and, when true, suppresses the tap gesture handler, the scaleEffect press animation, and the color cross-dissolve toggle animation; verify before implementing Symptoms card
- PartnerDashboardSnapshot fields map directly to daily_logs and prediction_snapshots table columns from the Phase 3 SwiftData schema; no additional fields are inferred
- The Countdown card uses the same 48pt numeral size as the Tracker Home Countdown Row (Design Spec §12.2) -- this is fixed-size, not a Dynamic Type token; the Phase 13 accessibility audit handles the accessibilityLargeText override for this numeral
- LazyVStack is the correct container for the Bento grid per swiftui-production skill (no ScrollView-less VStack for variable-length content)
- The 2-up square cards (Phase, Countdown) use equal-width sizing via `.frame(maxWidth: .infinity)` on each card within the HStack; no GeometryReader required

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| SymptomChip from Phase 4 does not have isReadOnly parameter implemented | Medium | High | Read SymptomChip.swift source before writing Symptoms card; add isReadOnly parameter to Phase 4 component as a prerequisite change if absent |
| Skeleton shimmer animation implementation diverges from §13 spec (1.2s loop, left-to-right) | Low | Low | Use a gradient mask animation with keyframe timing anchored at 1.2s; test on device with animation inspector |
| Accessibility1 threshold sizeCategory value differs from .accessibilityMedium | Low | Medium | Test collapse behavior on simulator with Accessibility-L text size setting; confirm that .accessibilityMedium maps to "Accessibility-L" in iOS Simulator accessibility settings |

---

## Stories

### S1: PartnerDashboardViewModel state machine

**Story ID:** PH-9-E2-S1
**Points:** 3

Implement PartnerDashboardViewModel as an @Observable class with a BentoViewState enum covering all display states. Include PartnerDashboardSnapshot as a value type. Initialize with stub preview data for development and testing.

**Acceptance Criteria:**

- [ ] PartnerDashboardViewModel is marked @Observable (no ObservableObject / @Published)
- [ ] BentoViewState enum has cases: .loading, .loaded(PartnerDashboardSnapshot), .paused, .empty, .error(message: String)
- [ ] PartnerDashboardSnapshot is a struct (value type) with fields: phaseLabel: String, countdownDays: Int?, symptomChipStates: [SymptomChipState], notes: String?, isLoggedToday: Bool
- [ ] PartnerDashboardViewModel exposes `var viewState: BentoViewState` as its primary state property
- [ ] A static `PartnerDashboardViewModel.preview` instance exists with viewState = .loaded(PartnerDashboardSnapshot stub) for use in SwiftUI previews
- [ ] No Supabase client, network calls, or SyncCoordinator references are present in this story's implementation (data binding is PH-9-E3)

**Dependencies:** None

---

### S2: Phase and Countdown 2-up square cards

**Story ID:** PH-9-E2-S2
**Points:** 3

Implement PhaseCardView and CountdownCardView as individual SwiftUI views backed by PartnerDashboardSnapshot fields. Both render in a 2-up HStack with equal widths using the Data Card component surface.

**Acceptance Criteria:**

- [ ] PhaseCardView renders inside a Data Card surface (CadenceCard background, 1pt CadenceBorder stroke, 16pt corner radius, 20pt padding)
- [ ] Phase label is displayed in headline style, CadenceTextPrimary; label text is sourced from PartnerDashboardSnapshot.phaseLabel
- [ ] CountdownCardView renders inside a Data Card surface with the same spec as PhaseCardView
- [ ] Days integer renders in `Font.system(size: 48, weight: .medium, design: .rounded)` at Color("CadenceTerracotta")
- [ ] "days until next period" label renders in footnote style, CadenceTextSecondary, below the numeral
- [ ] When PartnerDashboardSnapshot.countdownDays is nil, CountdownCardView shows "--" in place of the numeral without crashing
- [ ] Both cards use `.frame(maxWidth: .infinity)` within the containing HStack to achieve equal widths
- [ ] No hardcoded hex color values appear in either card's Swift implementation

**Dependencies:** PH-9-E2-S1

---

### S3: Symptoms card with read-only SymptomChip grid

**Story ID:** PH-9-E2-S3
**Points:** 3

Implement SymptomsCardView as a full-width Data Card containing a FlowLayout grid of SymptomChip components with isReadOnly=true. The card must not accept any touch input on the chips.

**Acceptance Criteria:**

- [ ] SymptomsCardView renders as a full-width Data Card (same surface spec as S2 cards)
- [ ] SymptomChip components are rendered with isReadOnly=true; no tap gesture handler fires when a chip is tapped
- [ ] When isReadOnly=true, the chip does not execute scaleEffect(0.95) press animation on touch down
- [ ] When isReadOnly=true, the chip does not execute the 0.15s easeOut color cross-dissolve on interaction
- [ ] VoiceOver accessibilityLabel on each chip follows the pattern "{symptom name}, selected" or "{symptom name}, unselected" (no "double tap to toggle" hint)
- [ ] When PartnerDashboardSnapshot.symptomChipStates is empty, SymptomsCardView shows "No symptoms logged today" in body style, CadenceTextSecondary
- [ ] The chip grid wraps to multiple rows when chip count exceeds the card width (no horizontal overflow or truncation)

**Dependencies:** PH-9-E2-S1
**Notes:** Read SymptomChip.swift from Phase 4 before implementing. If isReadOnly parameter is absent, add it to SymptomChip as a prerequisite change. File the change against Phase 4 scope and verify the hook does not flag a mixed commit.

---

### S4: Notes card

**Story ID:** PH-9-E2-S4
**Points:** 2

Implement NotesCardView as a full-width Data Card displaying the Tracker's daily notes text. Handle the empty-notes case with a styled placeholder string.

**Acceptance Criteria:**

- [ ] NotesCardView renders as a full-width Data Card (same surface spec as other cards)
- [ ] Notes text is displayed in body style, CadenceTextPrimary, left-aligned within the card padding
- [ ] When PartnerDashboardSnapshot.notes is nil or empty string, card shows "No notes added today" in body style, CadenceTextSecondary
- [ ] NotesCardView contains no interactive elements (no edit button, no tap gesture on the notes text)
- [ ] Notes text does not truncate for long content -- it wraps within the card width (no `.lineLimit(1)` or fixed-height text container)

**Dependencies:** PH-9-E2-S1

---

### S5: Bento grid layout container

**Story ID:** PH-9-E2-S5
**Points:** 3

Implement the Bento grid layout container as a ScrollView + LazyVStack that arranges the 4 cards in the correct 2-up / full-width pattern with specified spacing. The container renders against the .loaded state of PartnerDashboardViewModel.

**Acceptance Criteria:**

- [ ] Bento grid uses a ScrollView containing a LazyVStack as the outer container (per swiftui-production skill; no VStack in a ScrollView)
- [ ] Phase and Countdown cards appear in an HStack with a 12pt horizontal gap and equal widths (`.frame(maxWidth: .infinity)` on each card)
- [ ] Symptoms card appears below the 2-up row as a full-width card
- [ ] Notes card appears below the Symptoms card as a full-width card
- [ ] Vertical spacing between all grid rows (2-up row to Symptoms, Symptoms to Notes) is 16pt
- [ ] The grid renders without clipping on iPhone SE (375pt width) and iPhone 16 Pro Max (430pt width) -- no overflow or card truncation
- [ ] The outer ScrollView has no fixed height; it scrolls the full card stack when content exceeds the visible viewport

**Dependencies:** PH-9-E2-S2, PH-9-E2-S3, PH-9-E2-S4

---

### S6: Accessibility 1-up collapse at Accessibility1 threshold

**Story ID:** PH-9-E2-S6
**Points:** 3

Implement the mandatory Bento grid collapse to 1-up vertical stack at the Accessibility1 Dynamic Type threshold (ContentSizeCategory.accessibilityMedium and above). At this threshold, the Phase and Countdown HStack is replaced with a VStack of two full-width cards.

**Acceptance Criteria:**

- [ ] @Environment(\.sizeCategory) is read in the Bento grid container view
- [ ] When sizeCategory >= .accessibilityMedium, the Phase and Countdown cards render in a VStack (each full-width) instead of an HStack
- [ ] When sizeCategory < .accessibilityMedium, the Phase and Countdown cards render in the 2-up HStack layout
- [ ] The Symptoms and Notes full-width cards are unaffected by the threshold (they are already full-width)
- [ ] The collapse layout change produces no visual overlap, overflow, or truncation at the Accessibility-L simulator setting
- [ ] There is no animation on the layout switch (layout changes must not animate per cadence-accessibility rules -- instant switch only)

**Dependencies:** PH-9-E2-S5

---

### S7: Skeleton loading placeholders

**Story ID:** PH-9-E2-S7
**Points:** 3

Implement skeleton loading placeholders for each of the 4 Bento card slots. Placeholders render when PartnerDashboardViewModel.viewState is .loading. The shimmer animation runs at 1.2s loop with a left-to-right gradient mask, gated on accessibilityReduceMotion.

**Acceptance Criteria:**

- [ ] When ViewModel.viewState == .loading, 4 card-shaped skeleton placeholders render in the Bento grid layout (2 square, 2 full-width) at correct sizes and positions
- [ ] Each skeleton uses CadenceCard fill with a shimmer gradient mask: a semi-transparent CadenceBorder-tinted gradient that animates from left edge to right edge in 1.2s and loops continuously
- [ ] @Environment(\.accessibilityReduceMotion) is read; when true, skeleton renders at static opacity 0.4 with no gradient animation
- [ ] Skeleton card shapes use the same 16pt corner radius as Data Cards (consistent sizing, no layout shift when content loads)
- [ ] No full-screen spinner or ProgressView is used during the loading state (per Design Spec §13: "Never full-screen spinners")
- [ ] Transitioning from .loading to .loaded replaces skeletons with live card content without a flash of unstyled content

**Dependencies:** PH-9-E2-S5
**Notes:** The shimmer gradient can be implemented using a LinearGradient with a phase offset driven by a withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) on a @State offset value. Wrap in the reduceMotion check before starting the animation.

---

## Story Point Reference

| Points | Meaning |
| --- | --- |
| 1 | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour. |
| 2 | Small. One component or function, minimal unknowns. Half a day. |
| 3 | Medium. Multiple files, some integration. One day. |
| 5 | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8 | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days. |
| 13 | Very large. Should rarely appear. If it does, consider splitting the story. A week. |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Integration with PH-9-E1 verified: Bento grid renders correctly in the Her Dashboard tab of PartnerTabView
- [ ] Phase objective is advanced: the Partner Home Dashboard visual layer is complete and reviewable against Design Spec §12.5 with stub data
- [ ] cadence-design-system skill constraints satisfied: all color references use Color("CadenceToken") -- no hardcoded hex values; all typography uses Design Spec type tokens
- [ ] swiftui-production skill constraints satisfied: no AnyView usage, all views extracted at >50 line threshold, LazyVStack used for Bento grid outer container, no GeometryReader for equal-width cards (use .frame(maxWidth:.infinity))
- [ ] cadence-accessibility skill constraints satisfied: Bento 1-up collapse at .accessibilityMedium implemented and tested; SymptomChip VoiceOver labels correct; all interactive elements (if any) have 44pt minimum targets
- [ ] cadence-motion skill constraints satisfied: skeleton shimmer gates on accessibilityReduceMotion; no custom animations run without gating
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility 1-up collapse verified on iPhone simulator at Accessibility-L text size setting
- [ ] No dead code, stubs (except where explicitly noted as Phase 13 deferred), or placeholder comments
- [ ] Source document alignment verified: card layout, Data Card surface spec, and skeleton spec match Design Spec v1.1 §10.4, §12.5, and §13 exactly

## Source References

- PHASES.md: Phase 9 -- Partner Navigation Shell & Dashboard (in-scope items 3, 8, 9)
- Design Spec v1.1 §10.4 (Data Card -- background, border, corner radius, padding, Insight variant)
- Design Spec v1.1 §12.5 (Partner Home Dashboard -- 4 card types, 2-up layout, 1-up collapse threshold)
- Design Spec v1.1 §13 (States & Feedback -- skeleton loading, never full-screen spinners)
- Design Spec v1.1 §14 (Accessibility -- 1-up Bento collapse at Accessibility1, VoiceOver chip labels)
- Design Spec v1.1 §11 (Motion & Interaction -- skeleton shimmer 1.2s loop, reduced motion gating)
- MVP Spec §4 (Partner Home Dashboard -- Phase, Countdown, Symptoms, Notes, empty state)
- cadence-design-system skill (color tokens, typography scale)
- cadence-accessibility skill (44pt targets, reduceMotion, VoiceOver, Dynamic Type, 1-up collapse)
- cadence-motion skill (skeleton shimmer spec, reduced motion static fallback)
- swiftui-production skill (@Observable, view extraction, LazyVStack rule, AnyView ban)
