# Cadence — MVP Product Spec

## Product Summary

Cadence is a mobile-first cycle tracking application built in SwiftUI with a Supabase backend. The defining feature is partner sharing — a first-class, privacy-first system that lets a Tracker share selected cycle data with a Partner in real time.

The MVP targets a private beta delivered via TestFlight. App Store submission is a post-beta milestone once the core loop is validated with real users.

The product should feel calm, personal, and trustworthy — the opposite of clinical.

---

## Product Goal

Help users understand where they are in their cycle, predict what is likely to happen next, and log what they are experiencing — with the option to share that information with one trusted partner on their terms.

---

## Target Users

### Tracker
The person logging their cycle. Controls all data and all sharing permissions. Initiates every partner connection.

### Partner
The person receiving shared data. Read-only access to what the Tracker has explicitly permitted. No logging of their own cycle data in the beta.

### Beta Cohort
Known users only. Carolina, Dinesh's sister, close friends and their partners. TestFlight distribution. No public App Store release in this phase.

---

## Core Jobs To Be Done

1. When I go about my month, I want to know when my next period is likely so I can prepare.
2. When I notice symptoms, I want to log them quickly so I can find patterns over time.
3. When I want my partner to be more aware of where I am in my cycle, I want to share exactly what I choose and nothing more.
4. When my partner checks the app, I want them to see something useful and respectful — not a copy of my full data.
5. When I use this app, I want to trust that my health data is private and under my control.

---

## Tech Stack

| Layer | Choice |
|---|---|
| iOS | SwiftUI |
| Backend | Supabase (Postgres + Auth + Realtime + RLS) |
| Notifications | Apple Push Notification Service via Supabase Edge Functions |
| Distribution (beta) | TestFlight |
| HealthKit | Excluded from MVP |

---

## MVP Scope

### 1. Onboarding and Role Selection

The first screen after signup asks the user to identify their role.

**Role options:**
- I track my cycle (Tracker)
- My partner tracks their cycle (Partner)

A Tracker completes cycle setup immediately. A Partner enters a connection code issued by their Tracker to connect. A Partner without a connection code cannot proceed past onboarding.

**Tracker setup inputs:**
- Last period start date
- Average cycle length (default: 28 days)
- Average period length (default: 5 days)
- Goal mode: Track cycle / Trying to conceive

**Why it matters:**
Role selection at onboarding is the foundation of the entire experience split. Getting this right on day one prevents confusion about what the app is for.

---

### 2. Partner Sharing — First-Class Feature

Partner sharing is the primary differentiator of Cadence. It is built into the data model and enforced at the database level via Supabase Row Level Security.

#### Connection Flow

1. Tracker opens Settings and taps "Invite a Partner"
2. App generates a unique 6-digit invite code (expires after 24 hours)
3. Tracker shares the code with their partner out of band (text, etc.)
4. Partner opens the app, creates an account, and enters the code
5. Before connection finalises, Tracker sees a confirmation screen: "Dinesh will be able to see: [list of permitted categories]. He will not see: [restricted categories]."
6. Tracker confirms. Connection is live.

Only one active partner connection is permitted per Tracker in the beta.

The Tracker can disconnect the partner at any time from Settings. Disconnection immediately revokes all data access.

#### Permission Model

The Tracker controls sharing at category level. All categories are off by default. The Tracker explicitly opts each one in.

| Category | Default | Notes |
|---|---|---|
| Period predictions and countdown | Off | Most commonly enabled |
| Current cycle phase | Off | Non-clinical phase label |
| Symptoms (cramps, fatigue, headache etc.) | Off | Shared as chips, not clinical detail |
| Mood | Off | Separate from symptoms — more intimate |
| Fertile window | Off | Especially relevant for conception tracking |
| Daily notes | Off | Highest intimacy, always opt-in |

**Pause sharing:** A single toggle that suspends all data sharing without disconnecting the relationship. The Partner sees a "Sharing paused" state. No explanation required from the Tracker.

**Private log flag:** Any individual daily entry can be marked private by the Tracker. Even if symptoms are broadly shared, a flagged day is invisible to the Partner.

#### Supabase RLS Design

A `partner_connections` table links `tracker_id` to `partner_id` and stores a boolean column per permission category plus a `is_paused` flag. RLS policies on `daily_logs`, `period_logs`, and `prediction_snapshots` grant read access to a connected partner only when:

- A live connection exists between the two users
- `is_paused` is false
- The relevant permission category flag is true
- The individual log entry is not marked private

This enforcement lives at the database level. The Partner client cannot receive data the Tracker has not explicitly permitted, regardless of app code.

---

### 3. Home Dashboard — Tracker View

The primary surface for the Tracker. Communicates the most important cycle information at a glance.

**Components:**
- Current cycle day and phase label
- Next period countdown (days)
- Ovulation estimate
- Fertile window status
- Today's log summary (chips of what was logged today)
- Quick log CTA
- Contextual insight card (appears once enough cycles are logged)

**Insight examples:**
- "You usually experience cramps on days 1 and 2"
- "Your last 3 cycles were within 2 days of each other"
- "Fertile window starts tomorrow"

---

### 4. Home Dashboard — Partner View

A fundamentally different surface. Read-only. Simplified. Respectful.

**Components:**
- Tracker's current cycle phase with a plain-language description
- Days until next period (if shared)
- What she shared today — symptom chips and mood indicator
- "She hasn't logged today yet" empty state
- Fertile window indicator (if shared)
- Pause state — shown when the Tracker has paused sharing

**Tab structure for Partner:**
- Her Dashboard
- Notifications
- Settings

The Partner does not have Log, Calendar, or Reports tabs in the beta.

---

### 5. Calendar View (Tracker only)

Visual model of the cycle. Builds trust through visible history and editable records.

**Components:**
- Month-based calendar grid
- Logged period days (solid fill)
- Predicted period days (dashed or muted fill)
- Fertile window range highlight
- Ovulation day indicator
- Tap a date to view logs or edit entries

---

### 6. Period Logging

The foundation of all predictions.

**Actions:**
- Log period start
- Log period end
- Edit previously logged period dates
- Log flow level per day

**Flow levels:**
- Light
- Medium
- Heavy
- Spotting

---

### 7. Symptom Logging

Fast daily logging without friction.

**Symptom set:**
- Cramps
- Headache
- Bloating
- Mood changes
- Fatigue
- Acne
- Discharge
- Sex
- Exercise
- Sleep quality

**Requirements:**
- Multi-select chip UI
- Optional notes field
- Edit or delete a log after saving
- Private flag on any individual entry

---

### 8. Fertility and Cycle Predictions

Simple, transparent, rule-based predictions.

**Predictions:**
- Next period start date
- Estimated ovulation day
- Fertile window start and end

**Rules:**
- Next period = last period start + average cycle length
- Ovulation = predicted next period − 14 days
- Fertile window = ovulation − 5 days through ovulation day
- Averages recalculated from last 3–6 completed cycles

**Confidence levels:**
- High: 4+ cycles logged with low variance
- Medium: 2–3 cycles logged
- Low: 0–1 cycles or high irregularity

Every prediction must be labelled as an estimate based on logged history. No medical framing.

---

### 9. Reminders and Notifications

**Tracker reminders:**
- Upcoming period (configurable days in advance)
- Upcoming ovulation
- Daily logging reminder

**Partner notifications (Tracker controls which fire):**
- "Her period is expected in X days"
- "She logged [symptom] today" (only if symptoms are shared)
- "Her fertile window starts tomorrow" (only if fertile window is shared)

**Controls:**
- Tracker enables or disables each reminder type
- Tracker separately controls which Partner notifications are sent
- Partner can mute notification categories on their end

---

### 10. History and Reports (Tracker only)

**Report cards:**
- Average cycle length
- Average period length
- Recent cycles overview
- Cycle consistency (regular vs. irregular)
- Symptom frequency by cycle phase

Reports require at least 2 completed cycles before surfacing. Empty state explains what will appear once more data is logged.

---

### 11. Privacy and Settings

**Tracker settings:**
- Cycle defaults (update average length, period length, goal mode)
- Partner sharing controls (invite, manage permissions, pause, disconnect)
- Reminder preferences
- App lock (Face ID / passcode)
- Delete all data

**Partner settings:**
- Notification preferences
- Connection status (view or disconnect)
- Account settings

**Beta-appropriate privacy posture:**
Supabase encrypts data at rest and in transit. For a known private beta cohort this is sufficient. Full privacy policy, encrypted local storage, and anonymous mode are pre-App Store requirements, not beta blockers.

---

## Out of Scope for Beta

- App Store submission and compliance
- HealthKit integration
- Multiple partner connections
- Partner's own cycle tracking
- Pregnancy mode
- Perimenopause mode
- Social or community features
- AI assistant
- Condition screening (PCOS, endometriosis)
- Wearable integrations
- Export (PDF, CSV)
- Anonymous or guest mode
- Advanced fertility tracking (BBT, ovulation tests)

---

## User Flows

### Flow 1: Tracker Onboarding
1. User opens app, selects "I track my cycle"
2. Enters last period date, cycle length, period length, goal mode
3. App generates initial predictions
4. Lands on Tracker home dashboard

### Flow 2: Partner Onboarding
1. User opens app, selects "My partner tracks their cycle"
2. Creates account
3. Enters 6-digit invite code
4. Sees confirmation of what they'll have access to
5. Lands on Partner home dashboard

### Flow 3: Invite a Partner (Tracker)
1. Tracker opens Settings → Partner Sharing
2. Taps "Invite a Partner"
3. App generates invite code
4. Tracker shares code out of band
5. Once Partner connects, Tracker sees confirmation and sets permissions

### Flow 4: Manage Sharing Permissions (Tracker)
1. Tracker opens Settings → Partner Sharing
2. Toggles permission categories on or off
3. Changes apply immediately via Supabase RLS
4. Pause sharing available as one-tap override

### Flow 5: Log a Period
1. Tracker taps Log or a calendar date
2. Selects "Period started" or "Period ended"
3. Optionally adds flow level
4. App updates history and recalculates predictions

### Flow 6: Log Symptoms
1. Tracker taps Log
2. Selects symptoms from chip grid
3. Optionally adds notes
4. Optionally marks entry private
5. App saves log and (if permitted) surfaces to Partner

### Flow 7: Partner Checks the App
1. Partner opens app
2. Sees her current phase, what she shared today, days until next period
3. Read-only — no interactions except notification settings

---

## Information Architecture

### Tracker (5 tabs)
1. Home — cycle status and quick actions
2. Calendar — logged and predicted cycle events
3. Log — fast symptom and period logging surface
4. Reports — cycle averages and trends
5. Settings — cycle defaults, partner sharing, reminders, privacy

### Partner (3 tabs)
1. Her Dashboard — read-only shared view
2. Notifications — notification history and preferences
3. Settings — connection status and account

---

## Data Model

### users
| Column | Type | Notes |
|---|---|---|
| id | uuid | Supabase Auth UID |
| created_at | timestamptz | |
| role | enum | tracker / partner |
| timezone | text | |

### cycle_profiles
| Column | Type |
|---|---|
| user_id | uuid (FK → users) |
| average_cycle_length | int |
| average_period_length | int |
| goal_mode | enum (track / conceive) |
| predictions_enabled | bool |

### partner_connections
| Column | Type | Notes |
|---|---|---|
| id | uuid | |
| tracker_id | uuid (FK → users) | |
| partner_id | uuid (FK → users) | |
| invite_code | text | Expires 24h after generation |
| connected_at | timestamptz | |
| is_paused | bool | Tracker-controlled pause |
| share_predictions | bool | |
| share_phase | bool | |
| share_symptoms | bool | |
| share_mood | bool | |
| share_fertile_window | bool | |
| share_notes | bool | |

### period_logs
| Column | Type |
|---|---|
| id | uuid |
| user_id | uuid (FK → users) |
| start_date | date |
| end_date | date |
| source | enum (manual / predicted) |

### daily_logs
| Column | Type | Notes |
|---|---|---|
| id | uuid | |
| user_id | uuid (FK → users) | |
| date | date | |
| flow_level | enum (spotting / light / medium / heavy) | |
| mood | text | |
| sleep_quality | int | 1–5 |
| notes | text | |
| is_private | bool | Hides entry from partner |

### symptom_logs
| Column | Type |
|---|---|
| id | uuid |
| daily_log_id | uuid (FK → daily_logs) |
| symptom_type | enum |

### prediction_snapshots
| Column | Type |
|---|---|
| id | uuid |
| user_id | uuid (FK → users) |
| date_generated | timestamptz |
| predicted_next_period | date |
| predicted_ovulation | date |
| fertile_window_start | date |
| fertile_window_end | date |
| confidence_level | enum (high / medium / low) |

### reminder_settings
| Column | Type |
|---|---|
| id | uuid |
| user_id | uuid (FK → users) |
| remind_period | bool |
| remind_ovulation | bool |
| remind_daily_log | bool |
| notify_partner_period | bool |
| notify_partner_symptoms | bool |
| notify_partner_fertile | bool |
| reminder_time | time |

---

## RLS Policy Summary

All tables enforce ownership (`user_id = auth.uid()`) for write access.

Read access on `daily_logs`, `period_logs`, and `prediction_snapshots` is additionally granted to a connected Partner when:
- A `partner_connections` row exists linking `tracker_id = owner` and `partner_id = auth.uid()`
- `is_paused = false`
- The relevant `share_*` flag for that data category is true
- `daily_logs.is_private = false` (for daily log entries)

---

## Prediction Logic

| Prediction | Rule |
|---|---|
| Next period | Last period start + average cycle length |
| Ovulation | Predicted next period − 14 days |
| Fertile window start | Ovulation − 5 days |
| Fertile window end | Ovulation day |
| Average recalculation | Last 3–6 completed cycles |

Predictions recalculate automatically when period history is updated.

Every prediction surface must include a label: *"Based on your logged history — not medical advice."*

---

## Design Principles

1. **Tracker is always in control.** Every sharing decision flows from her. The Partner experience is a consequence of her choices, never the other way around.
2. **Calm over clinical.** The app should feel like something a person made for someone they care about — not a medical dashboard.
3. **Fast logging wins.** Logging a symptom should take under 5 seconds. Friction is the enemy of daily retention.
4. **Predictions must be transparent.** Estimates, not facts. Always labelled as such.
5. **Partner view is respectful, not clinical.** The Partner sees what helps them be present and aware. They do not see a surveillance dashboard.

---

## Non-Functional Requirements

### Privacy
- Supabase encrypted at rest and in transit (sufficient for beta)
- RLS as primary access control layer
- No third-party analytics SDKs in the beta build

### Accessibility
- Dynamic Type support
- Minimum 44pt tap targets
- Color is never the only signal (always paired with text or icon)
- VoiceOver labels on all interactive elements

### Performance
- Dashboard loads in under 1 second on WiFi
- Logging a symptom feels immediate (optimistic UI updates)
- Calendar scrolling at 60fps

### Reliability
- Offline logging supported with local cache
- Sync on reconnect
- No data loss on app termination mid-log

---

## Beta Success Metrics

### Activation
- % of invited users who complete onboarding
- % of Trackers who log their first period in session one
- % of Tracker-Partner pairs who successfully connect

### Engagement
- Logs per Tracker per month
- % of Trackers who return within 7 days
- % of connected Partners who open the app at least weekly

### Partner Sharing
- % of Trackers who invite a Partner
- Most commonly enabled permission categories
- Pause sharing usage rate (proxy for friction or discomfort)

### Qualitative
- Carolina, Dinesh's sister, and friends: does the partner view feel useful or intrusive?
- Which permission categories do Trackers actually enable?
- What's missing from the Partner view that they expected?

---

## Future Roadmap

### Post-Beta / Pre-App Store
- App Store privacy nutrition labels and full privacy policy
- Anonymous or guest mode
- Encrypted local storage
- Face ID / passcode lock
- Richer symptom taxonomy

### Phase 2
- Partner can also be a Tracker (dual tracking in the same relationship)
- Multiple partner connection types (partner, close friend, family)
- Export (PDF, CSV)
- Improved cycle charts

### Phase 3
- Pregnancy mode
- Irregular cycle insights
- Wearable integrations
- AI-assisted pattern summaries
- Payments — premium tier (Carolina gets premium by default, always free)

---

## Final Beta Definition

The beta is successful if:

- A Tracker can set up their cycle profile in under 3 minutes
- A Tracker can invite a Partner and control exactly what they see
- A Partner can open the app and immediately understand where their partner is in her cycle
- Both users feel the sharing experience is respectful and not clinical
- The core logging loop — period, symptoms, predictions — works reliably across real cycles
- The feedback from Carolina, Dinesh's sister, and close friends shapes what gets built next
