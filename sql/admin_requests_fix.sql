-- Fix admin_requests table foreign key relationships and permissions
-- This script addresses foreign key relationships between admin_requests and users tables
-- It also adds necessary permissions for site master access

-- 1. Check if the admin_requests table exists, create it if it doesn't
CREATE TABLE IF NOT EXISTS public.admin_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'pending',
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  responded_at TIMESTAMP WITH TIME ZONE,
  responded_by UUID
);

-- 2. Make sure the foreign key relationship is correctly set up
-- First drop the constraint if it already exists (to avoid errors)
ALTER TABLE public.admin_requests 
  DROP CONSTRAINT IF EXISTS admin_requests_user_id_fkey;

-- Add the foreign key constraint properly
ALTER TABLE public.admin_requests 
  ADD CONSTRAINT admin_requests_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES public.users(id) 
  ON DELETE CASCADE;

-- Also add foreign key for responded_by if it doesn't exist
ALTER TABLE public.admin_requests 
  DROP CONSTRAINT IF EXISTS admin_requests_responded_by_fkey;

ALTER TABLE public.admin_requests 
  ADD CONSTRAINT admin_requests_responded_by_fkey 
  FOREIGN KEY (responded_by) 
  REFERENCES public.users(id) 
  ON DELETE SET NULL;

-- 3. Add index to improve query performance
CREATE INDEX IF NOT EXISTS admin_requests_user_id_idx ON public.admin_requests(user_id);
CREATE INDEX IF NOT EXISTS admin_requests_status_idx ON public.admin_requests(status);

-- 4. Fix permissions for site masters
-- Grant permissions to the authenticated role (all logged-in users)
GRANT SELECT, INSERT ON public.admin_requests TO authenticated;

-- 5. Create or replace the approve_admin_request function
CREATE OR REPLACE FUNCTION public.approve_admin_request(
  request_id UUID,
  site_master_id UUID
) RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the user ID from the request
  SELECT user_id INTO v_user_id FROM admin_requests WHERE id = request_id;
  
  -- Update the admin request status
  UPDATE admin_requests 
  SET 
    status = 'approved',
    responded_at = NOW(),
    responded_by = site_master_id
  WHERE id = request_id;
  
  -- Grant admin privileges to the user
  UPDATE users
  SET 
    is_admin = TRUE
  WHERE id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create or replace the reject_admin_request function
CREATE OR REPLACE FUNCTION public.reject_admin_request(
  request_id UUID,
  site_master_id UUID
) RETURNS VOID AS $$
BEGIN
  UPDATE admin_requests 
  SET 
    status = 'rejected',
    responded_at = NOW(),
    responded_by = site_master_id
  WHERE id = request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.approve_admin_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_admin_request TO authenticated;

-- 7. Enable RLS on the admin_requests table
ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;

-- 8. Create policies for admin_requests
-- Policy for site masters to view all requests
CREATE POLICY admin_requests_site_master_select
  ON public.admin_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND (users.is_site_master = TRUE OR users.email LIKE '%@sandoog.com')
    )
  );

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

-- Site masters can update any request
CREATE POLICY admin_requests_site_master_update
  ON public.admin_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND (users.is_site_master = TRUE OR users.email LIKE '%@sandoog.com')
    )
  ); 