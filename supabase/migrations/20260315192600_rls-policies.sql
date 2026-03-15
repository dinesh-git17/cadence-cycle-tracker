-- Cadence RLS policies: ownership-write on all tables, partner-read with 4-condition model
-- Source: cadence-supabase skill section 3, MVP Spec section 2

-- ============================================================
-- users: own-row read and update only (no insert/delete via RLS)
-- ============================================================
CREATE POLICY user_read ON users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY user_update ON users
  FOR UPDATE USING (id = auth.uid());

-- ============================================================
-- cycle_profiles: ownership CRUD
-- ============================================================
CREATE POLICY owner_read ON cycle_profiles
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY owner_insert ON cycle_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY owner_update ON cycle_profiles
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY owner_delete ON cycle_profiles
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- period_logs: ownership CRUD + partner read
-- ============================================================
CREATE POLICY owner_read ON period_logs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY owner_insert ON period_logs
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY owner_update ON period_logs
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY owner_delete ON period_logs
  FOR DELETE USING (user_id = auth.uid());

CREATE POLICY partner_read_period_logs ON period_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM partner_connections pc
      WHERE pc.tracker_id = period_logs.user_id
        AND pc.partner_id = auth.uid()
        AND pc.is_paused = false
        AND pc.share_predictions = true
    )
  );

-- ============================================================
-- daily_logs: ownership CRUD + partner read (4-condition)
-- ============================================================
CREATE POLICY owner_read ON daily_logs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY owner_insert ON daily_logs
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY owner_update ON daily_logs
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY owner_delete ON daily_logs
  FOR DELETE USING (user_id = auth.uid());

CREATE POLICY partner_read_daily_logs ON daily_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM partner_connections pc
      WHERE pc.tracker_id = daily_logs.user_id
        AND pc.partner_id = auth.uid()
        AND pc.is_paused = false
        AND (pc.share_symptoms = true OR pc.share_mood = true OR pc.share_notes = true)
        AND daily_logs.is_private = false
    )
  );

-- ============================================================
-- symptom_logs: ownership CRUD only (no partner read)
-- Ownership resolved via daily_log_id subquery
-- ============================================================
CREATE POLICY owner_read ON symptom_logs
  FOR SELECT USING (
    daily_log_id IN (SELECT id FROM daily_logs WHERE user_id = auth.uid())
  );

CREATE POLICY owner_insert ON symptom_logs
  FOR INSERT WITH CHECK (
    daily_log_id IN (SELECT id FROM daily_logs WHERE user_id = auth.uid())
  );

CREATE POLICY owner_update ON symptom_logs
  FOR UPDATE USING (
    daily_log_id IN (SELECT id FROM daily_logs WHERE user_id = auth.uid())
  );

CREATE POLICY owner_delete ON symptom_logs
  FOR DELETE USING (
    daily_log_id IN (SELECT id FROM daily_logs WHERE user_id = auth.uid())
  );

-- ============================================================
-- prediction_snapshots: ownership CRUD + partner read
-- ============================================================
CREATE POLICY owner_read ON prediction_snapshots
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY owner_insert ON prediction_snapshots
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY owner_update ON prediction_snapshots
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY owner_delete ON prediction_snapshots
  FOR DELETE USING (user_id = auth.uid());

CREATE POLICY partner_read_prediction_snapshots ON prediction_snapshots
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM partner_connections pc
      WHERE pc.tracker_id = prediction_snapshots.user_id
        AND pc.partner_id = auth.uid()
        AND pc.is_paused = false
        AND (pc.share_predictions = true OR pc.share_phase = true)
    )
  );

-- ============================================================
-- reminder_settings: ownership CRUD
-- ============================================================
CREATE POLICY owner_read ON reminder_settings
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY owner_insert ON reminder_settings
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY owner_update ON reminder_settings
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY owner_delete ON reminder_settings
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- partner_connections: tracker CRUD + partner read-only
-- ============================================================
CREATE POLICY tracker_read_connection ON partner_connections
  FOR SELECT USING (tracker_id = auth.uid());

CREATE POLICY partner_read_connection ON partner_connections
  FOR SELECT USING (partner_id = auth.uid());

CREATE POLICY tracker_insert_connection ON partner_connections
  FOR INSERT WITH CHECK (tracker_id = auth.uid());

CREATE POLICY tracker_update_connection ON partner_connections
  FOR UPDATE USING (tracker_id = auth.uid());

CREATE POLICY tracker_delete_connection ON partner_connections
  FOR DELETE USING (tracker_id = auth.uid());
