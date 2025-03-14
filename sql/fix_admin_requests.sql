-- This SQL script fixes the admin_requests table issues

-- 1. First, create the admin_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.admin_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    responded_at TIMESTAMP WITH TIME ZONE,
    responded_by UUID
);

-- 2. Add the foreign key if it's missing (skip error if it exists)
DO $$
BEGIN
    BEGIN
        ALTER TABLE public.admin_requests 
        ADD CONSTRAINT admin_requests_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    EXCEPTION
        WHEN duplicate_object THEN 
            RAISE NOTICE 'Foreign key constraint already exists';
    END;
END $$;

-- 3. Give proper permissions (more permissive)
GRANT ALL ON public.admin_requests TO authenticated, anon, service_role;
GRANT USAGE ON SEQUENCE admin_requests_id_seq TO authenticated, anon, service_role;

-- 4. Enable Row Level Security
ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;

-- 5. Create basic policies (first dropping any existing ones)
DROP POLICY IF EXISTS admin_requests_user_select ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_user_insert ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_site_master_select ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_site_master_update ON public.admin_requests;

-- 6. Create more permissive policies
-- Policy for users to view their own requests
CREATE POLICY admin_requests_user_select
ON public.admin_requests
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy for users to insert their own requests
CREATE POLICY admin_requests_user_insert
ON public.admin_requests
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- IMPORTANT: More permissive policy for site masters to view all requests
CREATE POLICY admin_requests_site_master_select
ON public.admin_requests
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid() 
        AND (
            auth.users.email LIKE '%@sandoog.com'
            OR EXISTS (
                SELECT 1 FROM public.users 
                WHERE public.users.id = auth.uid() 
                AND public.users.is_site_master = TRUE
            )
        )
    )
);

-- Policy for site masters to update any request
CREATE POLICY admin_requests_site_master_update
ON public.admin_requests
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth.users
        WHERE auth.users.id = auth.uid() 
        AND (
            auth.users.email LIKE '%@sandoog.com'
            OR EXISTS (
                SELECT 1 FROM public.users 
                WHERE public.users.id = auth.uid() 
                AND public.users.is_site_master = TRUE
            )
        )
    )
);

-- Add site master data if not exists
INSERT INTO public.users (id, email, is_admin, is_site_master)
SELECT 
    auth.id,
    auth.email,
    TRUE,
    TRUE
FROM 
    auth.users
WHERE 
    auth.users.email LIKE '%@sandoog.com'
    AND NOT EXISTS (
        SELECT 1 FROM public.users WHERE public.users.id = auth.users.id
    );

-- Update existing site master emails
UPDATE public.users
SET is_admin = TRUE, is_site_master = TRUE
WHERE email LIKE '%@sandoog.com'
AND (is_admin = FALSE OR is_site_master = FALSE);

-- Insert a test admin request (only if none exist)
INSERT INTO public.admin_requests (user_id, reason, status)
SELECT 
    (SELECT id FROM auth.users LIMIT 1),
    'Test admin request - please approve',
    'pending'
WHERE NOT EXISTS (SELECT 1 FROM public.admin_requests LIMIT 1);

-- Complete with success message
SELECT 'Admin requests table has been fixed successfully' as result; 