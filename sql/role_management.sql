-- Role Management and Group Join Request SQL

-- Add columns to auth.users for role management
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS is_site_master BOOLEAN DEFAULT FALSE;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) NULL;

-- Create admin requests table
CREATE TABLE public.admin_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    reason TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    responded_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on admin_requests table
ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;

-- Admin requests policies
CREATE POLICY "Users can see their own admin requests" 
ON public.admin_requests 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create their own admin requests" 
ON public.admin_requests 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Site masters can view all admin requests" 
ON public.admin_requests 
FOR SELECT 
USING (EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid() AND is_site_master = TRUE
));

CREATE POLICY "Site masters can update admin requests" 
ON public.admin_requests 
FOR UPDATE 
USING (EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid() AND is_site_master = TRUE
));

-- Create group join requests table
CREATE TABLE public.group_join_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    group_id UUID NOT NULL REFERENCES public.groups(id),
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    responded_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on group_join_requests table
ALTER TABLE public.group_join_requests ENABLE ROW LEVEL SECURITY;

-- Group join requests policies
CREATE POLICY "Users can see their own join requests" 
ON public.group_join_requests 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create their own join requests" 
ON public.group_join_requests 
FOR INSERT 
WITH CHECK (
    user_id = auth.uid() AND
    NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = auth.uid() AND group_id IS NOT NULL
    )
);

CREATE POLICY "Group admins can view join requests for their group" 
ON public.group_join_requests 
FOR SELECT 
USING (EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_id AND created_by = auth.uid()
));

CREATE POLICY "Group admins can update join requests for their group" 
ON public.group_join_requests 
FOR UPDATE 
USING (EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = group_id AND created_by = auth.uid()
));

-- Function to process admin request approval
CREATE OR REPLACE FUNCTION approve_admin_request(request_id UUID, site_master_id UUID)
RETURNS VOID AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Check if the user processing is a site master
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = site_master_id AND is_site_master = TRUE
    ) THEN
        RAISE EXCEPTION 'Only site masters can approve admin requests';
    END IF;
    
    -- Get the user ID from the request
    SELECT user_id INTO user_id
    FROM public.admin_requests
    WHERE id = request_id AND status = 'pending';
    
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'Admin request not found or already processed';
    END IF;
    
    -- Update the admin request
    UPDATE public.admin_requests
    SET status = 'approved',
        responded_at = NOW(),
        responded_by = site_master_id,
        updated_at = NOW()
    WHERE id = request_id;
    
    -- Update the user's admin status
    UPDATE auth.users
    SET is_admin = TRUE
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject admin request
CREATE OR REPLACE FUNCTION reject_admin_request(request_id UUID, site_master_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Check if the user processing is a site master
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = site_master_id AND is_site_master = TRUE
    ) THEN
        RAISE EXCEPTION 'Only site masters can reject admin requests';
    END IF;
    
    -- Update the admin request
    UPDATE public.admin_requests
    SET status = 'rejected',
        responded_at = NOW(),
        responded_by = site_master_id,
        updated_at = NOW()
    WHERE id = request_id AND status = 'pending';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to approve group join request
CREATE OR REPLACE FUNCTION approve_join_request(request_id UUID, admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
    v_group_id UUID;
BEGIN
    -- Get the user and group IDs from the request
    SELECT user_id, group_id INTO v_user_id, v_group_id
    FROM public.group_join_requests
    WHERE id = request_id AND status = 'pending';
    
    IF v_user_id IS NULL OR v_group_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found or already processed';
    END IF;
    
    -- Check if the approver is the group admin
    IF NOT EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = v_group_id AND created_by = admin_id
    ) THEN
        RAISE EXCEPTION 'Only the group admin can approve join requests';
    END IF;
    
    -- Update the join request
    UPDATE public.group_join_requests
    SET status = 'approved',
        responded_at = NOW(),
        responded_by = admin_id,
        updated_at = NOW()
    WHERE id = request_id;
    
    -- Add the user to the group
    UPDATE auth.users
    SET group_id = v_group_id
    WHERE id = v_user_id;
    
    -- Add the user to the group's members array
    UPDATE public.groups
    SET members = array_append(members, v_user_id)
    WHERE id = v_group_id AND NOT (v_user_id = ANY(members));
    
    -- Add the user as a column in the matrix table
    PERFORM add_member_column(v_group_id, v_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject group join request
CREATE OR REPLACE FUNCTION reject_join_request(request_id UUID, admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_group_id UUID;
BEGIN
    -- Get the group ID from the request
    SELECT group_id INTO v_group_id
    FROM public.group_join_requests
    WHERE id = request_id AND status = 'pending';
    
    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found or already processed';
    END IF;
    
    -- Check if the rejecter is the group admin
    IF NOT EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = v_group_id AND created_by = admin_id
    ) THEN
        RAISE EXCEPTION 'Only the group admin can reject join requests';
    END IF;
    
    -- Update the join request
    UPDATE public.group_join_requests
    SET status = 'rejected',
        responded_at = NOW(),
        responded_by = admin_id,
        updated_at = NOW()
    WHERE id = request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create a group and update creator's status
CREATE OR REPLACE FUNCTION create_group_and_update_creator(
    name TEXT,
    description TEXT,
    type TEXT,
    monthly_contribution_amount DECIMAL,
    start_month_year DATE,
    creator_id UUID
)
RETURNS UUID AS $$
DECLARE
    new_group_id UUID;
BEGIN
    -- Check if creator is an admin
    IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = creator_id AND is_admin = TRUE
    ) THEN
        RAISE EXCEPTION 'Only admin users can create groups';
    END IF;
    
    -- Check if creator already has a group
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = creator_id AND group_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'User already belongs to a group';
    END IF;
    
    -- Create the group
    INSERT INTO public.groups (
        name,
        description,
        type,
        monthly_contribution_amount,
        start_month_year,
        created_by
    ) VALUES (
        name,
        description,
        type,
        monthly_contribution_amount,
        start_month_year,
        creator_id
    ) RETURNING id INTO new_group_id;
    
    -- Update the creator's group_id
    UPDATE auth.users
    SET group_id = new_group_id
    WHERE id = creator_id;
    
    -- Add creator to members array
    UPDATE public.groups
    SET members = array_append(members, creator_id)
    WHERE id = new_group_id;
    
    -- Add creator column to matrix
    PERFORM add_member_column(new_group_id, creator_id);
    
    RETURN new_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate admin request eligibility
CREATE OR REPLACE FUNCTION check_admin_request_eligibility(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_eligible BOOLEAN;
BEGIN
    -- Check if user already has admin status
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = user_id AND is_admin = TRUE
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if user already belongs to a group
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = user_id AND group_id IS NOT NULL
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if user already has a pending admin request
    IF EXISTS (
        SELECT 1 FROM public.admin_requests
        WHERE user_id = user_id AND status = 'pending'
    ) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Additional policy for admin requests to enforce eligibility
CREATE POLICY "Users can only create admin requests if eligible" 
ON public.admin_requests 
FOR INSERT 
WITH CHECK (
    user_id = auth.uid() AND 
    check_admin_request_eligibility(auth.uid())
); 