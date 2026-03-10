# Cadence — MVP Product Requirements Document

> **Version:** 1.0 | **Status:** Approved for Implementation | **Date:** March 7, 2026

> **Distribution:** iOS Engineer · Backend Engineer · Designer

---

# 1. Product Overview

Cadence is a SwiftUI cycle tracking application with a Supabase backend. The defining feature is partner sharing: a Tracker controls, at category granularity, exactly what a connected Partner can read. Access control is enforced at the database level via Row Level Security — the Partner client is architecturally incapable of reading data the Tracker has not explicitly permitted.

The MVP targets a private beta via TestFlight. App Store submission is a post-beta milestone contingent on the core loop being validated with real users.

The product should feel calm, personal, and trustworthy. The opposite of clinical.

---

# 2. Goals and Success Metrics

## Product Goals

- Validate that the Tracker-controlled partner sharing model feels correct to both parties
- Validate that daily logging is frictionless enough to sustain habit formation
- Surface qualitative signal from a known cohort that shapes the post-beta roadmap

## Beta Definition of Success

- A Tracker can complete cycle setup in under 3 minutes
- A Tracker can invite a Partner and configure permissions in under 2 minutes
- A Partner opens the app and immediately understands where their partner is in their cycle
- Both parties describe the sharing experience as respectful, not clinical
- The core logging loop — period, symptoms, predictions — works reliably across at least one full cycle per Tracker
- Qualitative feedback from the beta cohort shapes the post-beta roadmap

## Metrics

**Activation**

- % of invited users who complete onboarding
- % of Trackers who log their first period in session one
- % of Tracker–Partner pairs who successfully connect within 24 hours of both joining

**Engagement**

- Log events per Tracker per month
- % of Trackers who return within 7 days of first session
- % of connected Partners who open the app at least once per week

**Partner sharing**

- % of Trackers who invite a Partner
- Distribution of permission categories enabled
- Pause sharing usage rate (proxy for friction or discomfort)

**Qualitative**

- Does the Partner view feel useful or intrusive?
- Which permission categories do Trackers actually enable in practice?
- What does the Partner wish they could see that they currently cannot?
- What does the Tracker wish they could hide more granularly?

---

# 3. Target Users

## Tracker

The person logging their cycle. Controls all data and all sharing permissions. Initiates every partner connection. The primary user of the product. Wants to understand cycle patterns over time. May want a partner to be more aware without sharing everything. Values control and privacy. Does not want a clinical experience.

## Partner

The person receiving shared data. Read-only access to what the Tracker has explicitly permitted. Does not log their own cycle data in the beta. Wants to be present and aware without being intrusive. Does not want to feel like they are surveilling their partner.

## Beta Cohort

Known users only. TestFlight distribution. No public App Store release in this phase.

---

# 4. Scope

## In Scope for Beta

- Tracker onboarding and cycle setup
- Partner onboarding and connection via invite code
- Tracker home dashboard
- Partner home dashboard
- Calendar view (Tracker only)
- Period logging
- Symptom logging
- Cycle predictions (rule-based, client-side)
- Partner sharing with category-level permission model
- Pause sharing toggle
- Per-entry private flag
- Reminders and partner notifications via APNS
- Reports view (Tracker only)
- App lock via Face ID / passcode
- Account deletion
- Settings (Tracker and Partner)

## Out of Scope

See Section 18.

---

# 5. Tech Stack and Architecture

| Layer             | Choice                                      | Notes                                                           |
| ----------------- | ------------------------------------------- | --------------------------------------------------------------- |
| iOS               | SwiftUI, iOS 26 minimum                     | Liquid Glass chrome; custom data surfaces                       |
| Local persistence | SwiftData                                   | iOS 17+; fully available on iOS 26                              |
| Offline sync      | Custom write queue over SwiftData           | See Section 12                                                  |
| Backend           | Supabase (Postgres + Auth + Realtime + RLS) |                                                                 |
| Realtime          | Supabase DB change listeners                | Filtered via RLS; no custom broadcast layer                     |
| Auth              | Email/password + SIWA + Google Sign-In      | SIWA required by Apple when any third-party auth is present     |
| Notifications     | APNS via Supabase Edge Functions            |                                                                 |
| Prediction logic  | Client-side                                 | Deterministic arithmetic; runs against SwiftData; works offline |
| Distribution      | TestFlight (internal group)                 | App Store post-beta                                             |
| Analytics         | None in beta                                | No third-party SDKs                                             |
| HealthKit         | Excluded                                    | Post-beta consideration                                         |

## iOS 26 Design Posture

Cadence adopts iOS 26's Liquid Glass design language for system chrome: navigation bars, tab bars, sheets, and modals. Custom components are defined for all data-carrying surfaces. This gives the app a native feel at zero cost while preserving full design control over surfaces that carry the product's emotional weight.

**Use system Liquid Glass for:** TabBar, NavigationBar, sheet backgrounds, system alerts and action sheets.

**Use custom components for:** dashboard cards, symptom chips, calendar grid and day cells, prediction indicators, confidence badges, Partner dashboard cards, permission toggle rows, invite code display.

## Architecture Overview

```
SwiftUI Views
    ↕ @Observable ViewModels
SwiftData (local store)
    ↕ SyncCoordinator
Supabase Swift SDK
    ↕ Supabase Postgres + RLS
```

The `SyncCoordinator` is responsible for flushing pending SwiftData writes to Supabase on network restore, receiving Realtime DB change events and writing them to the local SwiftData store, marking records with `sync_status: pending | synced | error`, and conflict resolution (last-write-wins on `updated_at`).

---

# 6. Data Model

All tables enforce ownership (`user_id = auth.uid()`) for INSERT, UPDATE, DELETE. Partner read access is governed by RLS policies described in Section 6.10.

## 6.1 users

| Column       | Type                      | Notes                                         |
| ------------ | ------------------------- | --------------------------------------------- |
| id           | uuid                      | Supabase Auth UID                             |
| created_at   | timestamptz               |                                               |
| role         | enum('tracker','partner') | Set at onboarding; immutable in beta          |
| display_name | text                      | Optional                                      |
| timezone     | text                      | IANA timezone string e.g. America/Toronto     |
| apns_token   | text                      | Registered on first launch; updated on change |

## 6.2 cycle_profiles

| Column                | Type            | Notes                                                   |
| --------------------- | --------------- | ------------------------------------------------------- |
| id                    | uuid            |                                                         |
| user_id               | uuid FK → users |                                                         |
| average_cycle_length  | int             | Default 28; recalculated from last 3–6 completed cycles |
| average_period_length | int             | Default 5; recalculated from last 3–6 completed cycles  |
| predictions_enabled   | bool            | Default true                                            |
| created_at            | timestamptz     |                                                         |
| updated_at            | timestamptz     |                                                         |

⚠️ `goal_mode` (track/conceive) removed from beta. Reintroduced in Phase 2 when behavioral differences are defined.

## 6.3 invite_codes

Separate from `partner_connections`. A row exists here only while the code is pending. On successful claim, this row is deleted and a `partner_connections` row is created.

| Column     | Type            | Notes                                |
| ---------- | --------------- | ------------------------------------ |
| id         | uuid            |                                      |
| tracker_id | uuid FK → users |                                      |
| code       | char(6)         | Uppercase alphanumeric; unique index |
| created_at | timestamptz     |                                      |
| expires_at | timestamptz     | created_at + 24 hours                |

RLS: only the owning Tracker can read or delete their invite code row. Partners may claim via a stored procedure that validates expiry before creating the connection.

## 6.4 partner_connections

A row exists only when a connection is live. This table represents the active relationship, not the invite state.

| Column               | Type            | Notes                                            |
| -------------------- | --------------- | ------------------------------------------------ |
| id                   | uuid            |                                                  |
| tracker_id           | uuid FK → users | Unique index — one active connection per Tracker |
| partner_id           | uuid FK → users |                                                  |
| connected_at         | timestamptz     | Timestamp when Tracker confirmed                 |
| is_paused            | bool            | Default false; Tracker-controlled                |
| share_predictions    | bool            | Default false                                    |
| share_phase          | bool            | Default false                                    |
| share_symptoms       | bool            | Default false                                    |
| share_mood           | bool            | Default false                                    |
| share_fertile_window | bool            | Default false                                    |
| share_notes          | bool            | Default false                                    |
| updated_at           | timestamptz     |                                                  |

## 6.5 period_logs

| Column     | Type                       | Notes                      |
| ---------- | -------------------------- | -------------------------- |
| id         | uuid                       |                            |
| user_id    | uuid FK → users            |                            |
| start_date | date                       |                            |
| end_date   | date                       | Nullable until period ends |
| source     | enum('manual','predicted') |                            |
| created_at | timestamptz                |                            |
| updated_at | timestamptz                |                            |

## 6.6 daily_logs

One row per user per date. Unique constraint on `(user_id, date)`.

| Column             | Type                                      | Notes                                               |
| ------------------ | ----------------------------------------- | --------------------------------------------------- |
| id                 | uuid                                      |                                                     |
| user_id            | uuid FK → users                           |                                                     |
| date               | date                                      | Unique with user_id                                 |
| flow_level         | enum('spotting','light','medium','heavy') | Nullable                                            |
| sleep_quality_poor | bool                                      | Default false; replaces numeric 1–5 field           |
| notes              | text                                      | Nullable                                            |
| is_private         | bool                                      | Default false; overrides all category-level sharing |
| created_at         | timestamptz                               |                                                     |
| updated_at         | timestamptz                               |                                                     |

⚠️ `mood` text column removed. Mood is the `mood_change` symptom chip in `symptom_logs`.

## 6.7 symptom_logs

| Column       | Type                 | Notes          |
| ------------ | -------------------- | -------------- |
| id           | uuid                 |                |
| daily_log_id | uuid FK → daily_logs |                |
| symptom_type | enum                 | See enum below |
| created_at   | timestamptz          |                |

**Symptom enum:** `cramps`, `headache`, `bloating`, `mood_change`, `fatigue`, `acne`, `discharge`, `exercise`, `poor_sleep`, `sex`

⚠️ `sex` is stored but excluded from all Partner-accessible queries at the RLS layer. Never surfaced to a Partner regardless of any permission flag.

## 6.8 prediction_snapshots

| Column                | Type                        | Notes                             |
| --------------------- | --------------------------- | --------------------------------- |
| id                    | uuid                        |                                   |
| user_id               | uuid FK → users             |                                   |
| date_generated        | timestamptz                 |                                   |
| predicted_next_period | date                        |                                   |
| predicted_ovulation   | date                        |                                   |
| fertile_window_start  | date                        |                                   |
| fertile_window_end    | date                        |                                   |
| confidence_level      | enum('high','medium','low') |                                   |
| cycles_used           | int                         | Cycles used to calculate averages |
| created_at            | timestamptz                 |                                   |

## 6.9 reminder_settings

| Column                    | Type            | Notes               |
| ------------------------- | --------------- | ------------------- |
| id                        | uuid            |                     |
| user_id                   | uuid FK → users |                     |
| remind_period             | bool            | Default true        |
| remind_period_days_before | int             | Default 2           |
| remind_ovulation          | bool            | Default false       |
| remind_daily_log          | bool            | Default false       |
| remind_daily_log_time     | time            | Default 20:00 local |
| notify_partner_period     | bool            | Default false       |
| notify_partner_symptoms   | bool            | Default false       |
| notify_partner_fertile    | bool            | Default false       |
| created_at                | timestamptz     |                     |
| updated_at                | timestamptz     |                     |

## 6.10 RLS Policy Summary

Write access (INSERT, UPDATE, DELETE): `user_id = auth.uid()` on all tables.

Read access on `daily_logs`, `period_logs`, and `prediction_snapshots` is additionally granted to a connected Partner when **ALL** of the following are true:

1. A `partner_connections` row exists where `tracker_id = data owner` AND `partner_id = auth.uid()`
2. `partner_connections.is_paused = false`
3. The relevant `share_*` flag for the requested data category is `true`
4. `daily_logs.is_private = false` (for daily log rows)
5. `symptom_type != 'sex'` (for symptom_logs rows; always excluded regardless of flags)

The Partner client never receives data that fails any of these conditions. This is enforced at the **database layer**, not the application layer.

---

# 7. Feature Specifications

## 7.1 Onboarding and Role Selection

**Tracker flow:** Auth → Role selection → Cycle setup (last period date, cycle length 21–45 default 28, period length 2–10 default 5) → prediction snapshot generated client-side → Tracker home dashboard.

**Partner flow:** Auth → Role selection → Code entry (6-character, auto-advance) → code validated via stored procedure → Tracker receives push notification to confirm and set permissions → `partner_connections` row created with all `share_*` flags false → Partner home dashboard.

**Error states:** Expired code: “This code has expired. Ask your partner to generate a new one.” | Invalid: “That code doesn’t look right.” | Already claimed: “This code has already been used.” | Network: “Couldn’t connect. Check your connection and try again.”

## 7.2 Predictions

| Prediction            | Rule                                            |
| --------------------- | ----------------------------------------------- |
| Next period start     | Last period start + average cycle length        |
| Ovulation             | Predicted next period start − 14 days           |
| Fertile window start  | Ovulation − 5 days                              |
| Fertile window end    | Ovulation day                                   |
| Average recalculation | Mean of last 3–6 completed cycle/period lengths |

**Confidence levels:** High — 4+ completed cycles, SD ≤ 2 days | Medium — 2–3 cycles, or 4+ with SD > 2 days | Low — 0–1 cycles.

**Recalculation trigger:** Client-side. `SyncCoordinator` calls the prediction function after any write to `period_logs`. New snapshot written to SwiftData immediately and queued for Supabase sync.

**Display requirement:** Every prediction surface must include “Based on your logged history — not medical advice.” visible without scrolling.

## 7.3 Cycle Phase Definitions

| Phase      | Day Range                                       | Tracker Label    | Partner Label              |
| ---------- | ----------------------------------------------- | ---------------- | -------------------------- |
| Menstrual  | Period start through period end                 | Menstrual phase  | Her period is here         |
| Follicular | Period end + 1 through fertile window start − 1 | Follicular phase | Post-period, pre-ovulation |
| Fertile    | Fertile window start through ovulation          | Fertile window   | Fertile window             |
| Luteal     | Ovulation + 1 through next period start − 1     | Luteal phase     | Second half of her cycle   |

If no predictions exist (0 cycles), phase label is replaced with “Cycle day [N]” based on days since last period start.

## 7.4 Period Logging

- Log period start / end (end triggers prediction recalculation)
- Log flow level: Spotting, Light, Medium, Heavy
- Edit / delete previously logged period dates
- At most one open period (start logged, no end) per Tracker at a time
- Predicted period rows (source = predicted) are display-only and disappear when the actual period is logged

## 7.5 Symptom Logging

**Symptom set:** Cramps, Headache, Bloating, Mood change, Fatigue, Acne, Discharge, Exercise, Poor sleep, Sex.

- Sex is always-private: stored in `symptom_logs` but excluded from all Partner-visible queries at the RLS layer
- Multi-select chip UI with optional notes field and private flag
- Entries can be edited or deleted at any time via Calendar view or day detail sheet
- Optimistic UI: saves update SwiftData and UI immediately; Supabase write queued

## 7.6 Reports

Tracker only. Requires ≥ 2 completed cycles. Cards: average cycle length (SD, sparkline, confidence), average period length, cycle consistency (Regular/Slightly irregular/Irregular), recent cycles timeline (last 6), symptom frequency by phase (≥ 3 cycles).

## 7.7 App Lock

iOS `LocalAuthentication`. Face ID with passcode fallback. Locks on background, requires auth on foreground. Available to both roles. Disabled by default.

## 7.8 Account Deletion

Required by Apple for App Store. Behaviour:

1. User taps "Delete my account" in Settings.
2. Confirmation dialog with irreversibility warning.
3. If Tracker has an active partner connection: additional warning that the Partner will be disconnected.
4. On confirmation: all `daily_logs`, `period_logs`, `symptom_logs`, `prediction_snapshots`, `cycle_profiles`, `partner_connections`, `invite_codes`, and `reminder_settings` rows owned by this user are deleted.
5. Supabase Auth account deleted.
6. App returns to auth screen.

Deletion is irreversible. No grace period in beta.

---

# 8. Screen Specifications

## 8.1 Auth Screen

**Components:** App wordmark “Cadence” (center, large) · tagline “Track your cycle. Share what matters.” · Sign in with Apple (system, full width) · Sign in with Google (Google brand guidelines, full width) · “or” divider · email field (keyboard type email) · password field (secure entry, show/hide toggle) · primary CTA “Continue” (creates account if new, signs in if existing) · secondary link toggles between create/sign-in · forgot password link (triggers Supabase password reset email).

**States:** Default · Loading (CTA spinner, inputs disabled) · Error (inline below affected field) · Success (transitions to role selection).

**Accessibility:** All interactive elements have VoiceOver labels. SIWA and Google buttons use system accessibility strings. Password show/hide toggle announces its state change to VoiceOver.

## 8.2 Role Selection Screen

**Components:** Screen title “How will you use Cadence?” · Role card A: icon + “I track my cycle” + descriptor · Role card B: icon + “My partner tracks their cycle” + descriptor · tapping selected card navigates forward immediately.

Role written to `users.role` on selection. Immutable in beta — no role change without account deletion.

## 8.3 Tracker Cycle Setup Screen

**Components:** Title “Let’s set up your cycle.” · last period start date picker (defaults to 28 days ago) · cycle length stepper (21–45, default 28, “days” label) · period length stepper (2–10, default 5, “days” label) · helper text “Not sure? These are common averages. You can update them later.” · primary CTA “Set up Cadence.”

**States:** Default (pre-filled with defaults) · Loading (CTA spinner) · Error (inline with retry).

## 8.4 Partner Code Entry Screen

**Components:** Title “Enter your partner’s code.” · descriptor with 24-hour expiry note · 6-character code input (monospaced, auto-capitalise, auto-advance, large tap targets) · CTA “Connect” disabled until 6 chars entered · waiting state toggle for users without a code yet.

**Waiting state copy:** “Waiting for your partner’s code. Once they generate one in their app, enter it here.”

**Error states:** Expired · Invalid · Already claimed · Network (see Section 7.1 for exact copy).

## 8.5 Tracker Home Dashboard

Tab 1 of 5.

**Components (top to bottom):**

- **Cycle status card** (custom): current cycle day · current phase label · confidence badge (High/Medium/Low) · prediction disclaimer
- **Countdown row** (custom): “Next period in X days” (large numeral) · “Ovulation in X days” (secondary) · if fertile window active: “Fertile window” badge replaces ovulation countdown
- **Today’s log summary** (custom): horizontal scroll of today’s symptom chips · “Nothing logged today” if empty · tap opens Log sheet
- **Quick log CTA**: “Log today” primary button — opens Log sheet
- **Contextual insight card** (custom): appears when ≥ 2 completed cycles · single rotating insight · dismissible; dismissed insights don’t reappear for 7 days
- **Partner sharing status strip** (custom): visible when partner connection exists · “Sharing with [name]” or “Sharing paused” · pause/resume toggle inline · tap navigates to Partner Sharing settings

**States:** Loading (skeleton) · No cycles logged (cycle day 1, insight hidden) · Offline (last synced data + “Last updated [time]”) · Period active (“Period active, day X”).

## 8.6 Log Sheet

Modal sheet over any tab. Entry points: Quick log CTA, Log tab, Calendar date tap.

**Components:**

- **Date header**: date being logged (today by default, or selected calendar date)
- **Period section**: “Log period start” button (if no period active) · “Log period end” button (if period active) · flow level chip row (Spotting / Light / Medium / Heavy)
- **Symptom chips**: “How are you feeling?” · multi-select grid of all 10 symptoms · 44pt minimum tap targets · Sex chip shows lock icon
- **Notes field**: optional multiline, placeholder “Anything else worth noting?”
- **Privacy toggle**: “Keep this day private” · helper: “Your partner won’t see anything from this day, even if sharing is on.”
- **Save button**: “Save log” primary, full width

**States:** Empty (Save enabled to allow clearing) · Saving (spinner) · Saved (sheet dismisses, optimistic update) · Error (non-blocking toast: “Couldn’t save — will retry when online.”)

## 8.7 Calendar View (Tracker only)

Tab 2 of 5.

**Components:**

- **Month header**: month + year · left/right chevrons · Today button
- **Calendar grid** (custom): logged period days (solid fill, brand color) · predicted period days (muted/dashed, same hue) · fertile window range highlight (distinct accent) · ovulation day indicator · today indicator · log dot for days with any entry · lock icon for private days
- **Day detail sheet** (on tap): date header · period/flow status · symptom chips (read view) · notes · private flag indicator · “Edit log” button (opens Log sheet pre-populated)

**States:** Loading (skeleton) · Empty month (today highlighted only) · Future months (predicted days and fertile windows shown).

## 8.8 Reports View (Tracker only)

Tab 4 of 5.

**Empty state** (< 2 completed cycles): “Your reports will appear here once you’ve logged 2 full cycles.”

**Components when data available:**

- **Cycle length card**: average, SD badge, sparkline (last 6 cycles), confidence label
- **Period length card**: average, sparkline
- **Cycle consistency card**: Regular / Slightly irregular / Irregular (SD ≤ 2 / 3–5 / > 5 days)
- **Recent cycles timeline**: horizontal scroll of last 6 cycles (start date, length, period length)
- **Symptom frequency card** (≥ 3 cycles): symptoms by cycle phase
- **Footer disclaimer**: “All information based on your logged history — not medical advice.”

## 8.9 Tracker Settings

Tab 5 of 5.

**Sections:**

- **Cycle defaults**: cycle length stepper · period length stepper · “Recalculate from history” button
- **Partner sharing**: connection status · Invite / code pending / connected states · permission category toggles (all default off) · pause sharing toggle · disconnect action (confirmation required)
- **Reminders**: period (on/off + days before) · ovulation · daily log (on/off + time) · partner notification toggles (period, symptoms, fertile window)
- **Privacy and security**: app lock toggle · Delete all my data (destructive, confirmation required)
- **Account**: display name · email (read-only) · sign out · app version

## 8.10 Partner Home Dashboard

Tab 1 of 3. Read-only. No write interactions.

**Components:**

- **Connection status header** (pause/disconnect states only): “[Name] has paused sharing” or “Your partner has ended the sharing connection.”
- **Phase card** (when `share_phase = true`): Partner-facing phase label · plain-language description · cycle day
- **Countdown card** (when `share_predictions = true`): “Her period is expected in X days” or “Her period is here.”
- **Today’s log card** (when `share_symptoms` or `share_mood = true`): permitted symptom chips · sex chip never shown · empty state: “She hasn’t logged today yet.”
- **Fertile window card** (when `share_fertile_window = true`): countdown or current status
- **Daily notes card** (when `share_notes = true`, notes exist today, entry not private)
- **All-categories-off empty state**: “She hasn’t turned on sharing yet. Check back soon.”

**States:** Loading (skeleton) · Sharing paused · Disconnected · All categories off · Offline (last synced + timestamp).

## 8.11 Partner Notifications Tab

Tab 2 of 3.

**Components:** Notification history list (last 30 days; icon + text + relative timestamp) · empty state: “No notifications yet.” · per-category mute toggles (Period, Symptoms, Fertile window) · helper: “Your partner controls which notifications are sent. You can mute categories here.”

## 8.12 Partner Settings

Tab 3 of 3.

**Sections:** Connection (partner name, connected since, End connection — destructive) · Notifications (same as tab preference section) · Privacy and security (app lock) · Account (display name, email read-only, sign out, delete account, app version).

## 8.13 Invite Partner Flow (Tracker)

Entry: Settings → Partner Sharing → Invite a Partner.

**Code generation screen:** 6-character code (large, monospaced, center) · expiry countdown · system share sheet · copy to clipboard · Cancel invite link.

**Waiting state:** “Waiting for your partner to connect…” · countdown continues · Generate new code option.

**Confirmation screen** (fires when Partner claims code): “[Name] wants to connect.” · checklist of what they will see (all off by default) · Review permissions CTA · Confirm connection primary CTA · Decline secondary (deletes claimed code without creating connection).

---

# 9. User Flows

## Flow 1: Tracker Onboarding

Open app → Auth → Create account → Role selection (Tracker) → Cycle setup → Prediction snapshot generated client-side → Tracker home dashboard.

## Flow 2: Partner Onboarding

Open app → Auth → Create account → Role selection (Partner) → Code entry → Code validated → Tracker receives push notification → Tracker confirms and sets permissions → Partner home dashboard.

## Flow 3: Invite a Partner (Tracker)

Settings → Partner Sharing → Invite a Partner → Code generated and displayed → Tracker shares code out-of-band → Partner enters code → confirmation push to Tracker → Tracker confirms → connection live.

## Flow 4: Manage Sharing Permissions (Tracker)

Settings → Partner Sharing → toggle category on/off → writes to `partner_connections` immediately → Realtime event propagates to Partner client.

## Flow 5: Pause and Resume Sharing

Dashboard sharing strip (or Settings) → pause toggle → `is_paused = true` → Partner dashboard immediately shows pause state via Realtime. Resume: same toggle.

## Flow 6: Log a Period

Dashboard → Log today → Log sheet (or Calendar → tap date) → Period started → optional flow level → Save → SwiftData updated optimistically → Supabase write queued → prediction recalculated client-side.

## Flow 7: Log Symptoms

Dashboard → Log today → Log sheet → select chips → optional notes and/or private flag → Save → optimistic update. If symptoms shared and entry not private: Partner dashboard updates via Realtime.

## Flow 8: Partner Views the App

Partner opens app → Partner home dashboard → Realtime subscription active → reads phase, countdown, symptoms, fertile window. Read-only.

## Flow 9: Disconnect a Partner (Tracker)

Settings → Partner Sharing → Disconnect partner → confirmation → `partner_connections` row deleted → Partner Realtime subscription fires deletion event → Partner dashboard shows disconnected state → Partner data access revoked at RLS layer immediately.

---

# 10. Navigation Architecture

## Tracker (5 tabs)

| Tab      | Icon        | Destination                        |
| -------- | ----------- | ---------------------------------- |
| Home     | House       | Tracker home dashboard             |
| Calendar | Calendar    | Calendar view                      |
| Log      | Plus circle | Log sheet (modal over current tab) |
| Reports  | Chart bar   | Reports view                       |
| Settings | Gear        | Tracker settings                   |

## Partner (3 tabs)

| Tab           | Icon  | Destination                          |
| ------------- | ----- | ------------------------------------ |
| Her Dashboard | House | Partner home dashboard               |
| Notifications | Bell  | Notification history and preferences |
| Settings      | Gear  | Partner settings                     |

SwiftUI `TabView` with programmatic tab selection. Each tab has its own `NavigationStack`. Sheets presented with `.sheet()`. The Log tab presents the Log sheet as a modal — the active tab does not change.

---

# 11. Partner Sharing System

## Design Principles

- The Tracker is always in control. Every sharing decision originates from her.
- All categories default to off. The Tracker explicitly opts each one in.
- The Partner experience is a consequence of the Tracker’s choices, never the other way.
- Pause sharing suspends all data access instantly without terminating the relationship.
- A private-flagged day is invisible to the Partner regardless of any category flag.

## Permission Categories

| Category                         | Schema Column        | What Partner Sees When Enabled             |
| -------------------------------- | -------------------- | ------------------------------------------ |
| Period predictions and countdown | share_predictions    | “Her period is expected in X days”         |
| Current cycle phase              | share_phase          | Phase label and plain-language description |
| Symptoms                         | share_symptoms       | Symptom chips (excluding Sex always)       |
| Mood change                      | share_mood           | Mood change chip if logged                 |
| Fertile window                   | share_fertile_window | Fertile window countdown and status        |
| Daily notes                      | share_notes          | Today’s notes text (if entry not private)  |

## Pause Sharing

`is_paused = true` blocks all data access at the RLS layer. Partner sees “Sharing paused” with no data and no explanation. Tracker’s toggle states are preserved — resuming restores them exactly. No notification sent on pause or resume.

## Private Log Flag

`daily_logs.is_private = true` makes that entire day’s data invisible to the Partner at the RLS layer, regardless of any category flag. Set via the privacy toggle in Log sheet. Private days show a lock icon on the Tracker’s calendar.

## Sex Symptom

`sex` is stored in `symptom_logs`. An RLS condition explicitly excludes `symptom_type = 'sex'` from all Partner-accessible queries. Cannot be overridden by any application-level flag. Sex chip shows lock icon in Log sheet.

## Connection State Machine

```
[No connection]
    ↓ Tracker generates code
[Invite pending]
    ↓ Partner claims code + Tracker confirms
[Connected]
    ↕ Tracker toggles pause
[Connected, paused]
    ↓ Tracker or Partner disconnects
[Disconnected]
```

| Transition                 | RLS Effect                                                                   |
| -------------------------- | ---------------------------------------------------------------------------- |
| Invite pending → Connected | Partner read access enabled (filtered by share flags)                        |
| Connected → Paused         | Partner read access suspended                                                |
| Paused → Connected         | Partner read access restored                                                 |
| Any → Disconnected         | `partner_connections` row deleted; Partner loses all read access immediately |

---

# 12. Offline and Sync Architecture

**Requirements:** Log success when offline · no data loss on app termination · dashboard shows last known data offline · pending writes flush on reconnect · prediction recalculation works offline.

**Local store:** SwiftData is the source of truth for the iOS client. Supabase is the authoritative remote store.

**Sync status:** Each SwiftData model has `syncStatus: pending | synced | error`. New and modified records start as `pending`.

**Write queue:** `SyncCoordinator` maintains an ordered queue of pending writes. On network availability (via `NWPathMonitor`), flushes in order to the appropriate Supabase table via the Swift SDK.

**Conflict resolution:** Last-write-wins on `updated_at`. Multi-device conflict resolution is post-beta.

**Read path:** Client reads from SwiftData. Realtime events are received by `SyncCoordinator`, written to SwiftData, UI refreshes via `@Observable`.

**Error handling:** If a write fails after 3 retries, `syncStatus = error` and a non-blocking indicator appears on the affected UI element.

**Partner data:** Separate read-only SwiftData store for Partner-visible Tracker data received via Realtime. Never written to by the Partner client.

---

# 13. Authentication

**Methods:** Email + password (Supabase Auth) · Sign in with Apple (required by Apple when any third-party auth present) · Sign in with Google (Google Sign-In SDK).

**APNS token registration:** Requested on first successful auth. Token written to `users.apns_token`. Refreshed on `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.

**Session management:** Supabase session token in iOS Keychain. SDK handles refresh automatically. On expiry, user shown auth screen.

**Google privacy note:** Google Sign-In SDK has its own data collection behaviour. Users authenticating via Google are subject to Google’s OAuth data handling. Must be disclosed in the minimal privacy notice.

---

# 14. Push Notifications

APNS via Supabase Edge Functions. Triggered by pg_cron daily job that evaluates reminder and partner notification conditions and dispatches APNS payloads.

## Tracker Reminders

| Notification       | Trigger Condition                                                    | Configurable      |
| ------------------ | -------------------------------------------------------------------- | ----------------- |
| Upcoming period    | predicted_next_period − remind_period_days_before = today            | Days before (1–7) |
| Upcoming ovulation | predicted_ovulation = tomorrow                                       | On/off            |
| Daily log reminder | Fires at remind_daily_log_time if no daily_logs row exists for today | On/off + time     |

## Partner Notifications (Tracker-controlled)

Fire only when `share_* = true` AND `notify_partner_* = true`. Partner can mute categories on their device.

| Notification       | Content                              | Condition                                                    |
| ------------------ | ------------------------------------ | ------------------------------------------------------------ |
| Period approaching | “Her period is expected in X days”   | share_predictions + notify_partner_period                    |
| Symptom logged     | “She logged [symptom] today”         | share_symptoms + notify_partner_symptoms + entry not private |
| Fertile window     | “Her fertile window starts tomorrow” | share_fertile_window + notify_partner_fertile                |

## Permission Request Timing

Permission requested after Tracker completes cycle setup (not at launch). For Partners, after successfully connecting to a Tracker.

## Deep Link on Tap

| Notification Type                    | Destination                |
| ------------------------------------ | -------------------------- |
| Tracker: upcoming period / ovulation | Tracker home dashboard     |
| Tracker: daily log reminder          | Log sheet (opens directly) |
| Partner: all notifications           | Partner home dashboard     |

---

# 15. Privacy and Security

Cadence handles sensitive reproductive health data. Post-Dobbs, this data carries real legal exposure in certain US states. This informs the privacy posture even for a private beta.

**Beta posture:** Supabase encrypts at rest and in transit (TLS 1.3) · RLS is the primary access control layer · no third-party analytics SDKs in beta · Google Sign-In SDK is the only third-party SDK included.

**Minimal privacy notice required before TestFlight invites:** What data is collected · where stored (Supabase, US/EU datacenters) · who can see it (user + connected Partner per permission model) · how to delete (in-app) · private beta caveat · lawful data request disclosure.

**Pre-App Store (out of beta scope):** Full privacy policy · Apple privacy nutrition labels · encrypted local storage beyond SwiftData defaults · anonymous mode.

---

# 16. Non-Functional Requirements

| Requirement                                 | Target              |
| ------------------------------------------- | ------------------- |
| Dashboard load from SwiftData               | < 100ms             |
| Dashboard load from Supabase (first launch) | < 1s on WiFi        |
| Symptom log save (optimistic)               | < 50ms to UI update |
| Calendar scroll                             | 60fps               |
| Prediction recalculation                    | < 200ms client-side |

**Reliability:** No data loss on app termination (SwiftData persists before any network write) · sync queue survives termination and resumes on next launch · Realtime reconnect handled automatically by Swift SDK.

**Accessibility:** Dynamic Type on all text (no truncation at accessibility sizes) · 44pt minimum tap targets · color never the sole signal · VoiceOver labels on all custom components · all entrance animations respect `@Environment(\.accessibilityReduceMotion)`.

**Privacy defaults:** All sharing categories off · app lock off · partner notifications off.

---

# 17. Design System

**Tone:** Calm. Warm. Personal. Not clinical. Not alarming. The app should feel like something a person made for someone they care about.

**Color constraints:** Palette works in Light and Dark mode · period-logged days and predicted period days use the same hue at different opacities, not different colors · fertile window highlight is a distinct accent that does not clash with the period color · confidence badges: High = neutral/positive, Medium = neutral, Low = muted/cautionary (never alarming red). Full system to be defined by designer in a separate design document.

**Typography:** All text uses Dynamic Type · large numerals for countdowns, standard body for descriptions, small for labels and disclaimers · prediction disclaimer always present but smaller and muted.

**Interaction patterns:** Symptom and period log: optimistic UI · permission toggles: immediate write to Supabase; if write fails, toggle reverts with toast · pause sharing: immediate · destructive actions: always require confirmation dialog.

---

# 18. Non-Goals (Beta)

- App Store submission and compliance
- HealthKit integration
- Multiple partner connections per Tracker
- Partner logging their own cycle
- Pregnancy mode or perimenopause mode
- Social or community features
- AI assistant or AI-generated insights
- Condition screening (PCOS, endometriosis)
- Wearable integrations
- Export (PDF, CSV)
- Anonymous or guest mode
- Advanced fertility tracking (BBT, ovulation tests)
- “Trying to conceive” goal mode (deferred until behavioral differences are defined)
- In-app messaging between Tracker and Partner
- Explicit multi-device support (sync architecture supports it but is not a tested scenario in beta)

---

# 19. Risks and Mitigations

| Risk                                             | Likelihood | Impact | Mitigation                                                                                      |
| ------------------------------------------------ | ---------- | ------ | ----------------------------------------------------------------------------------------------- |
| Offline sync conflicts corrupt data              | Low        | High   | Last-write-wins on updated_at; ordered sync queue; SwiftData is ground truth                    |
| Partner receives data despite RLS                | Very low   | High   | RLS policies must be integration-tested before any TestFlight build                             |
| APNS token stale; notifications silently fail    | Medium     | Low    | Refresh token on every launch; silent failure acceptable in beta                                |
| Beta user in US state with legal exposure        | Low        | High   | Minimal privacy notice before invites; deletion path tested end-to-end                          |
| SwiftData migration required after schema change | Medium     | Medium | Version SwiftData models from day one; define lightweight migrations for all schema changes     |
| iOS 26 Liquid Glass layout bugs                  | Medium     | Medium | Custom components for all data surfaces; fallback to system default if glass causes regressions |
| Invite code collision                            | Very low   | Low    | Unique constraint on code column; regenerate on collision                                       |

---

# 20. Open Questions Post-PRD

Out of scope for beta; must be resolved before App Store submission:

- Full privacy policy content and legal review
- Apple privacy nutrition label categories and data use justifications
- Encrypted local storage implementation beyond SwiftData defaults
- SwiftData model versioning and migration strategy
- APNS Edge Function scheduling: time zone handling for reminder delivery
- Multi-device sync conflict resolution
- Google Sign-In SDK version pinning and update cadence
- Supabase project region selection (EU vs US) and data residency implications

---

_Cadence MVP PRD — Version 1.0 — March 7, 2026_

_All decisions approved during structured pre-PRD discovery. Refer to Claude’s Space for the full decision ledger._
