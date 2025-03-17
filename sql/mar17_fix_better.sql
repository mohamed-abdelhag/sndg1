-- Simplified SQL fix for Sandoog application
-- Assumes 17_Mar_create.sql has already been run successfully

-- Add any missing columns to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS first_name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Make sure all @sandoog.com users have site master privileges
UPDATE public.users
SET is_site_master = TRUE, is_admin = TRUE
WHERE email LIKE '%@sandoog.com';

-- Make sure start_month_year column exists in groups table
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS start_month_year DATE DEFAULT CURRENT_DATE;

-- Improve the trigger function for handling new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (
    id, 
    email, 
    first_name,
    last_name,
    is_admin, 
    is_site_master, 
    created_at, 
    updated_at
  )
  VALUES (
    NEW.id, 
    NEW.email,
    NULL,
    NULL,
    NEW.email LIKE '%@sandoog.com', 
    NEW.email LIKE '%@sandoog.com',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      is_admin = CASE WHEN EXCLUDED.email LIKE '%@sandoog.com' THEN TRUE ELSE public.users.is_admin END,
      is_site_master = CASE WHEN EXCLUDED.email LIKE '%@sandoog.com' THEN TRUE ELSE public.users.is_site_master END,
      updated_at = NOW();
      
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Make sure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Fix users that exist in auth but not in public.users table
INSERT INTO public.users (id, email, is_admin, is_site_master, created_at, updated_at)
SELECT 
  au.id, 
  au.email,
  au.email LIKE '%@sandoog.com',
  au.email LIKE '%@sandoog.com',
  NOW(),
  NOW()
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM public.users pu WHERE pu.id = au.id
); 