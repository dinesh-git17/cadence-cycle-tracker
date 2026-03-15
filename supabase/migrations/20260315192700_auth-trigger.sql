-- Auth trigger: create public.users row on every auth.users insert
-- Bridges Supabase Auth identity to application schema
-- SECURITY DEFINER required to bypass RLS on public.users

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, created_at, role, timezone)
  VALUES (NEW.id, NEW.created_at, 'tracker', 'UTC')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
