# Component Mapping Registry

Maps Figma design components to their SwiftUI implementation counterparts.
This is the local Code Connect substitute until the Figma account is upgraded to Organization/Enterprise.

**Update this file immediately when a component is implemented or renamed.**
Do not batch registry updates.

---

## How to Use This Registry

When implementing a new component from Figma:
1. Call `get_design_context` for the Figma component node.
2. Implement the SwiftUI component.
3. Add an entry to this registry before the implementation PR merges.

When Code Connect becomes available (Org/Enterprise plan):
- Migrate each entry to a `send_code_connect_mappings` call with `label: "SwiftUI"`.
- Use the `figmaNodeId` from this registry as the `nodeId` parameter.

---

## Component Registry

### Primitive Components

| Figma component name | SwiftUI file | Status | Figma node ID | Notes |
|---|---|---|---|---|
| Symptom Chip / Chip | `Cadence/Views/Components/SymptomChip.swift` | Not implemented | TBD — inspect via MCP | `isSelected: Bool`, `isReadOnly: Bool`, Sex chip permanent lock icon |
| Flow Level Chip | `Cadence/Views/Components/FlowLevelChip.swift` | Not implemented | TBD | Variant of capsule chip — Spotting, Light, Medium, Heavy |
| Period Toggle Button | `Cadence/Views/Components/PeriodToggleButton.swift` | Not implemented | TBD | Equal-width horizontal pair, 12pt radius, 44pt min height |
| Primary CTA Button | `Cadence/Views/Components/PrimaryCTAButton.swift` | Not implemented | TBD | 50pt height, 14pt radius, full-width, loading/disabled states |
| Data Card | `Cadence/Views/Components/DataCard.swift` | Not implemented | TBD | `style: .standard` or `.insight`; 16pt radius; 20pt padding; 1pt CadenceBorder stroke |
| Sharing Status Strip | `Cadence/Views/Components/SharingStatusStrip.swift` | Not implemented | TBD | `.active` (CadenceSageLight) / `.paused` (CadencePrimary — BLOCKED) |
| Countdown Card | `Cadence/Views/Components/CountdownCard.swift` | Not implemented | TBD | Paired narrow cards; 48pt `.system(size:48,weight:.medium,design:.rounded)` numeral |
| Cycle Status Card | `Cadence/Views/Components/CycleStatusCard.swift` | Not implemented | TBD | Phase name (display token), confidence badge (capsule, CadenceSageLight), day label |

### Screen-Level Components

| Figma frame name | SwiftUI file | Status | Notes |
|---|---|---|---|
| Auth screen | `Cadence/Views/Auth/AuthView.swift` | Not implemented | Sign in with Apple (black CTA), Google (outlined), email/password fields |
| Role selection | `Cadence/Views/Auth/RoleSelectionView.swift` | Not implemented | "I track my cycle" / "My partner tracks their cycle" |
| Cycle setup | `Cadence/Views/Onboarding/CycleSetupView.swift` | Not implemented | Last period date, cycle length, period length fields |
| Tracker Home Dashboard | `Cadence/Views/Tracker/Home/TrackerHomeView.swift` | Not implemented | LazyVStack feed: strip → cycle card → countdown → log card → CTA → insight |
| Log Sheet | `Cadence/Views/Tracker/Log/LogSheet.swift` | Not implemented | `.presentationDetents([.medium, .large])`, isPrivate toggle |
| Calendar View | `Cadence/Views/Tracker/Calendar/CalendarView.swift` | Not implemented | Period, prediction, fertile window, ovulation visual states |
| Reports View | `Cadence/Views/Tracker/Reports/ReportsView.swift` | Not implemented | Cycle consistency, symptom frequency, recent cycles chart |
| Reports Empty State | `Cadence/Views/Tracker/Reports/ReportsView.swift` | Not implemented | "Your reports will appear here once you've logged 2 full cycles." |
| Tracker Settings | `Cadence/Views/Tracker/Settings/TrackerSettingsView.swift` | Not implemented | Cycle defaults, partner sharing, notifications, account |
| Invite Partner | `Cadence/Views/Tracker/Settings/InvitePartnerView.swift` | Not implemented | Share code, expiry, copy/share actions |
| Confirm Connection | `Cadence/Views/Tracker/Settings/ConfirmConnectionView.swift` | Not implemented | Permission checklist (6 categories), Confirm/Decline |
| Partner Code Entry | `Cadence/Views/Partner/Onboarding/PartnerCodeEntryView.swift` | Not implemented | 6-character code input, Connect CTA |
| Partner Home Dashboard | `Cadence/Views/Partner/Dashboard/PartnerDashboardView.swift` | Not implemented | Bento 2-up grid (Phase, Countdown, Symptoms, Notes) |
| Partner Dashboard — Sharing Paused | `Cadence/Views/Partner/Dashboard/PartnerDashboardView.swift` | Not implemented | Single CadenceSageLight "Sarah has paused sharing" state card |
| Partner Dashboard — No Sharing | `Cadence/Views/Partner/Dashboard/PartnerDashboardView.swift` | Not implemented | "She hasn't turned on sharing yet. Check back soon." |
| Partner Notifications | `Cadence/Views/Partner/Notifications/PartnerNotificationsView.swift` | Not implemented | Push notification history grouped by category |
| Partner Settings | `Cadence/Views/Partner/Settings/PartnerSettingsView.swift` | Not implemented | Account, Connection (to Sarah), Notifications, Privacy & Security |

---

## Known Deviations

Document all cases where SwiftUI naming deviates from Figma naming here.

| Figma name | Swift name | Reason |
|---|---|---|
| (none recorded yet) | | |

---

## Code Connect Migration Checklist

When the account is upgraded to Organization or Enterprise:

- [ ] Publish all design system components to team library in Figma
- [ ] For each row above with status "Implemented": call `send_code_connect_mappings` with `label: "SwiftUI"`
- [ ] Verify `componentName` exactly matches the Swift struct name (case-sensitive)
- [ ] Verify `source` path is relative to project root and the file exists
- [ ] Remove superseded local registry entries after confirming MCP reflects the mapping

---

## Figma File Reference

- **File key:** `h3DwhdSjoP29U0VcCVRfTG`
- **File name:** Cadence — Design System & Screens
- **Account:** dinbuilds / dind.dev@gmail.com (Starter/View — 6 MCP calls/month)
- **Node IDs:** Obtain by calling `get_metadata(fileKey="h3DwhdSjoP29U0VcCVRfTG", nodeId="0:1")` when MCP budget allows, then drilling into component sections
