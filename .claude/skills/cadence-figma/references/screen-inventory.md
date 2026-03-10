# Screen Inventory

All confirmed screen frames in the Cadence Figma file.
Source: PDF export of `h3DwhdSjoP29U0VcCVRfTG` — "Cadence — Design System & Screens".

Node IDs are marked TBD — obtain by calling `get_metadata` when MCP budget allows.
Frame names below reflect the naming conventions visible in the PDF; actual Figma layer names may vary slightly.

---

## Authentication & Onboarding

| Frame | Description | Status label (from PDF) | Expected node ID |
|---|---|---|---|
| Auth screen | Sign in with Apple, Sign in with Google, email/password fields, wordmark, tagline | (root screen) | TBD |
| Role selection | "How will you use Cadence?" — Tracker vs. Partner choice | Set up Cadence | TBD |
| Cycle setup | Last period date picker, cycle length (default 28d), period length (default 5d) | Set up Cadence | TBD |
| Partner code entry | 6-character code input, Connect CTA | (connection flow) | TBD |
| Confirm Connection | "Alex wants to connect" — 6 permission category toggles, Confirm/Decline | Confirm Connection | TBD |

---

## Tracker Flow

| Frame | Description | Observed data in PDF | Expected node ID |
|---|---|---|---|
| Tracker Home — Active | Full dashboard with sharing strip, cycle card, countdown, today's log, CTA, insight | "Follicular phase", "Cycle day 12 of 28", "16 days until next period", "Sharing with Alex", Cramps/Fatigue/Bloating chips active | TBD |
| Tracker Home — Loading | Skeleton placeholder state | "Dashboard -- Loading" label | TBD |
| Log Sheet | Bottom sheet with period toggles, flow chips, symptom chips, notes, private toggle, save CTA | "Log entry", Friday March 7 2026, all chips visible | TBD |
| Calendar | Month grid with period/prediction/fertile window visual states | Tab bar Calendar tab | TBD |
| Reports — Active | Cycle consistency stats, symptom frequency by phase, recent cycles timeline | "Regular", SD 1.2 days, avg 29d cycle, avg 5d period, Cramps 85%, Bloating 55%, Headache 32% | TBD |
| Reports — Empty State | Pre-data placeholder | "Your reports will appear here once you've logged 2 full cycles." | TBD |
| Settings — Tracker | Cycle defaults, partner sharing toggles, notifications, account | Cycle 28d, Period 5d, "Connected to Alex", "Pause sharing", all 6 sharing categories | TBD |
| Invite Partner | Code share screen | "Share this code with your partner", "Expires in 23 hours, 47 minutes" | TBD |

---

## Partner Flow

| Frame | Description | Observed data in PDF | Expected node ID |
|---|---|---|---|
| Partner Home — Active | Bento 2-up grid (Phase, Countdown, Symptoms, Notes cards) | Tab: "Her Dashboard" | TBD |
| Partner Home — Sharing Paused | Single "Sharing paused" state card | "Sarah has paused sharing" | TBD |
| Partner Home — No Sharing | All categories off placeholder | "She hasn't turned on sharing yet. Check back soon." | TBD |
| Partner Notifications | Push notification history by category | Period/Symptom/Fertile window grouped, Feb–Mar entries | TBD |
| Partner Settings | Account, Connection, Notifications, Privacy & Security | "Connected to Sarah", "Connected since Feb 10, 2026", alex@example.com | TBD |

---

## Design System Pages

The Figma file name includes "Design System & Screens" — the file is expected to contain:
- Color styles / variables (10 tokens)
- Text styles (11 typography tokens)
- Component pages: Symptom Chip variants, Period Toggle Button, Primary CTA, Data Card, Sharing Status Strip, Countdown Card, Cycle Status Card

These component pages are the target for Code Connect mappings. Obtain their node IDs via `get_metadata` when MCP budget is available.

---

## Chip Inventory (Confirmed from Log Sheet Frame)

### Symptom Chips
| Chip label | Privacy status |
|---|---|
| Cramps | Shareable |
| Headache | Shareable |
| Bloating | Shareable |
| Mood change | Shareable (if share_mood enabled) |
| Fatigue | Shareable |
| Acne | Shareable |
| Discharge | Shareable |
| Exercise | Shareable |
| Poor sleep | Shareable |
| Sex | **Never shared** — permanent lock icon (`lock.fill`, 11pt) regardless of state |

### Flow Level Chips
Spotting · Light · Medium · Heavy

### Period Toggles
Period started · Period ended (equal-width pill pair)

---

## Confirm Connection Permission Categories (Confirmed from Figma)

In the order shown on the "Confirm Connection" screen:
1. Period predictions — "When your next period is expected"
2. Cycle phase — "Which phase of your cycle you're in"
3. Symptoms — "Logged symptoms (never includes sex)"
4. Mood — "Mood changes when logged"
5. Fertile window — "Fertile window dates and status"
6. Daily notes — "Notes from non-private days"

All categories default to off. Sex is excluded from all sync payloads regardless of any toggle state.
