-- Cadence initial schema: 8 tables, constraints, indexes, triggers
-- Source: MVP Spec Data Model + cadence-supabase skill section 2

-- Reusable trigger function for automatic updated_at maintenance
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 1. users
CREATE TABLE users (
  id uuid PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  role text NOT NULL CHECK (role IN ('tracker', 'partner')),
  timezone text NOT NULL DEFAULT 'UTC'
);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. cycle_profiles
CREATE TABLE cycle_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  average_cycle_length int NOT NULL DEFAULT 28,
  average_period_length int NOT NULL DEFAULT 5,
  goal_mode text NOT NULL DEFAULT 'track' CHECK (goal_mode IN ('track', 'conceive')),
  predictions_enabled bool NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE cycle_profiles ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_cycle_profiles
  BEFORE UPDATE ON cycle_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3. partner_connections
CREATE TABLE partner_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tracker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  partner_id uuid REFERENCES users(id) ON DELETE SET NULL,
  invite_code text,
  invited_at timestamptz NOT NULL DEFAULT now(),
  connected_at timestamptz,
  is_paused bool NOT NULL DEFAULT false,
  share_predictions bool NOT NULL DEFAULT false,
  share_phase bool NOT NULL DEFAULT false,
  share_symptoms bool NOT NULL DEFAULT false,
  share_mood bool NOT NULL DEFAULT false,
  share_fertile_window bool NOT NULL DEFAULT false,
  share_notes bool NOT NULL DEFAULT false
);
ALTER TABLE partner_connections ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX idx_one_connection_per_tracker ON partner_connections(tracker_id);

-- 4. period_logs
CREATE TABLE period_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_date date NOT NULL,
  end_date date,
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'predicted')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, start_date)
);
ALTER TABLE period_logs ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_period_logs
  BEFORE UPDATE ON period_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5. daily_logs
CREATE TABLE daily_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date date NOT NULL,
  flow_level text CHECK (flow_level IN ('spotting', 'light', 'medium', 'heavy')),
  mood text,
  sleep_quality int CHECK (sleep_quality BETWEEN 1 AND 5),
  notes text,
  is_private bool NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_daily_logs
  BEFORE UPDATE ON daily_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 6. symptom_logs
CREATE TABLE symptom_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_log_id uuid NOT NULL REFERENCES daily_logs(id) ON DELETE CASCADE,
  symptom_type text NOT NULL CHECK (symptom_type IN (
    'cramps', 'headache', 'bloating', 'mood_changes', 'fatigue',
    'acne', 'discharge', 'sex', 'exercise', 'sleep_quality'
  )),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE symptom_logs ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_symptom_logs
  BEFORE UPDATE ON symptom_logs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 7. prediction_snapshots
CREATE TABLE prediction_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date_generated timestamptz NOT NULL DEFAULT now(),
  predicted_next_period date NOT NULL,
  predicted_ovulation date,
  fertile_window_start date,
  fertile_window_end date,
  confidence_level text NOT NULL CHECK (confidence_level IN ('high', 'medium', 'low')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE prediction_snapshots ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_prediction_snapshots
  BEFORE UPDATE ON prediction_snapshots
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 8. reminder_settings
CREATE TABLE reminder_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  remind_period bool NOT NULL DEFAULT false,
  remind_ovulation bool NOT NULL DEFAULT false,
  remind_daily_log bool NOT NULL DEFAULT false,
  notify_partner_period bool NOT NULL DEFAULT false,
  notify_partner_symptoms bool NOT NULL DEFAULT false,
  notify_partner_fertile bool NOT NULL DEFAULT false,
  reminder_time time NOT NULL DEFAULT '08:00:00',
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reminder_settings ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_updated_at_reminder_settings
  BEFORE UPDATE ON reminder_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Performance indexes
CREATE INDEX idx_daily_logs_user_date ON daily_logs(user_id, date);
CREATE INDEX idx_daily_logs_user_private ON daily_logs(user_id, is_private);
CREATE INDEX idx_period_logs_user ON period_logs(user_id);
CREATE INDEX idx_partner_connections_tracker ON partner_connections(tracker_id);
CREATE INDEX idx_partner_connections_partner ON partner_connections(partner_id);
CREATE INDEX idx_prediction_snapshots_user_date ON prediction_snapshots(user_id, date_generated DESC);
CREATE INDEX idx_symptom_logs_daily_log ON symptom_logs(daily_log_id);
