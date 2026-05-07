-- Migration: update handle_new_user trigger to include company_id from metadata
-- Fixes: RLS blocks company linkage on new user registration (CR-02)
-- Depends on: schema.sql (handle_new_user function and on_auth_user_created trigger)
--
-- Before this migration, handle_new_user only read full_name, email, and role
-- from raw_user_meta_data. A post-signup .update() in AuthService was used to set
-- company_id, but new RLS policies block that update for auditor-role users.
-- This migration makes the trigger read company_id directly from sign-up metadata,
-- eliminating the need for the follow-up update call.

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, email, role, company_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'auditor'),
    (NEW.raw_user_meta_data->>'company_id')::UUID
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
