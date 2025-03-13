-- Create admin_requests table with proper relationships
CREATE TABLE IF NOT EXISTS public.admin_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    responded_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS admin_requests_user_id_idx ON public.admin_requests(user_id);
CREATE INDEX IF NOT EXISTS admin_requests_status_idx ON public.admin_requests(status);

-- Set up Row Level Security
ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS admin_requests_site_master_select ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_user_select ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_user_insert ON public.admin_requests;
DROP POLICY IF EXISTS admin_requests_site_master_update ON public.admin_requests;

-- Create fresh policies
CREATE POLICY admin_requests_site_master_select
ON public.admin_requests
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() 
        AND (is_site_master OR email LIKE '%@sandoog.com')
    )
);

CREATE POLICY admin_requests_user_select
ON public.admin_requests
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY admin_requests_user_insert
ON public.admin_requests
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY admin_requests_site_master_update
ON public.admin_requests
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() 
        AND (is_site_master OR email LIKE '%@sandoog.com')
    )
);

-- Create helper view for joined data
CREATE OR REPLACE VIEW public.admin_requests_with_users AS
SELECT 
    ar.*,
    u.email,
    u.first_name,
    u.last_name
FROM public.admin_requests ar
JOIN public.users u ON ar.user_id = u.id;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON public.admin_requests TO authenticated;
GRANT SELECT ON public.admin_requests_with_users TO authenticated;

-- Create approval/rejection functions
CREATE OR REPLACE FUNCTION public.approve_admin_request(
    request_id UUID,
    site_master_id UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE public.admin_requests
    SET 
        status = 'approved',
        responded_at = NOW(),
        responded_by = site_master_id
    WHERE id = request_id;

    UPDATE public.users
    SET is_admin = TRUE
    WHERE id = (SELECT user_id FROM public.admin_requests WHERE id = request_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.reject_admin_request(
    request_id UUID,
    site_master_id UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE public.admin_requests
    SET 
        status = 'rejected',
        responded_at = NOW(),
        responded_by = site_master_id
    WHERE id = request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh Supabase schema cache
NOTIFY pgrst, 'reload schema'; 