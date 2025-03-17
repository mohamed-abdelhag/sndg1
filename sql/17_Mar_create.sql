-- I'll copy past it

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables with appropriate RLS policies

-- 1. Extend the users table (assumes auth.users exists from Supabase)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  is_admin BOOLEAN DEFAULT FALSE,
  is_site_master BOOLEAN DEFAULT FALSE,
  group_id UUID,
  first_name TEXT,
  last_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 2. Admin requests table
CREATE TABLE public.admin_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  responded_at TIMESTAMP WITH TIME ZONE,
  responded_by UUID REFERENCES public.users(id),
  CONSTRAINT valid_response CHECK (
    (status = 'pending' AND responded_at IS NULL AND responded_by IS NULL) OR
    ((status = 'approved' OR status = 'rejected') AND responded_at IS NOT NULL AND responded_by IS NOT NULL)
  )
);

-- 3. Groups table
CREATE TABLE public.groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL CHECK (type IN ('standard', 'lottery')),
  monthly_contribution_amount NUMERIC NOT NULL,
  total_pool NUMERIC DEFAULT 0,
  start_month_year DATE NOT NULL,
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. Group join requests table
CREATE TABLE public.group_join_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  responded_at TIMESTAMP WITH TIME ZONE,
  responded_by UUID REFERENCES public.users(id),
  CONSTRAINT valid_response CHECK (
    (status = 'pending' AND responded_at IS NULL AND responded_by IS NULL) OR
    ((status = 'approved' OR status = 'rejected') AND responded_at IS NOT NULL AND responded_by IS NOT NULL)
  )
);

-- Function to create dynamic tables for a new group
CREATE OR REPLACE FUNCTION create_group_tables()
RETURNS TRIGGER AS $$
DECLARE
  matrix_table TEXT;
  metadata_table TEXT;
  withdrawals_table TEXT;
BEGIN
  -- Define table names
  matrix_table := 'group_' || NEW.id || '_matrix';
  metadata_table := 'group_' || NEW.id || '_metadata';
  withdrawals_table := 'group_' || NEW.id || '_withdrawals';
  
  -- Create matrix table
  EXECUTE format('
    CREATE TABLE public.%I (
      month_number INTEGER PRIMARY KEY,
      month_year DATE NOT NULL,
      total_contributions NUMERIC DEFAULT 0,
      total_withdrawals NUMERIC DEFAULT 0,
      lottery_winner_id UUID
    )', matrix_table);
  
  -- Create metadata table
  EXECUTE format('
    CREATE TABLE public.%I (
      current_month_number INTEGER DEFAULT 1,
      active_members_count INTEGER DEFAULT 1,
      last_updated TIMESTAMP WITH TIME ZONE DEFAULT now(),
      settings JSONB DEFAULT ''{}''
    )', metadata_table);
  
  -- Create withdrawals table
  EXECUTE format('
    CREATE TABLE public.%I (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES public.users(id),
      month_number INTEGER NOT NULL,
      amount NUMERIC NOT NULL,
      reason TEXT,
      status TEXT NOT NULL DEFAULT ''requested'' CHECK (status IN (''requested'', ''approved'', ''rejected'', ''paid'')),
      approved_by UUID REFERENCES public.users(id),
      approved_at TIMESTAMP WITH TIME ZONE,
      payback_amount_monthly NUMERIC,
      payback_period_months INTEGER,
      due_by_date DATE,
      remaining_amount NUMERIC,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
    )', withdrawals_table);
  
  -- Initialize metadata
  EXECUTE format('
    INSERT INTO public.%I (current_month_number, active_members_count)
    VALUES (1, 1)', metadata_table);
  
  -- Initialize first month in matrix
  EXECUTE format('
    INSERT INTO public.%I (month_number, month_year)
    VALUES (1, %L)', matrix_table, NEW.start_month_year);
  
  -- Set RLS policies for matrix table
  EXECUTE format('
    ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY group_admin_matrix_access
    ON public.%I
    USING (EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = %L AND g.created_by = auth.uid()
    ));
    
    CREATE POLICY group_member_matrix_access
    ON public.%I
    FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.group_id = %L
    ));
  ', matrix_table, matrix_table, NEW.id, matrix_table, NEW.id);
  
  -- Set RLS policies for metadata table
  EXECUTE format('
    ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY group_admin_metadata_access
    ON public.%I
    USING (EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = %L AND g.created_by = auth.uid()
    ));
    
    CREATE POLICY group_member_metadata_access
    ON public.%I
    FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.group_id = %L
    ));
  ', metadata_table, metadata_table, NEW.id, metadata_table, NEW.id);
  
  -- Set RLS policies for withdrawals table
  EXECUTE format('
    ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY group_admin_withdrawals_access
    ON public.%I
    USING (EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = %L AND g.created_by = auth.uid()
    ));
    
    CREATE POLICY group_member_withdrawals_select
    ON public.%I
    FOR SELECT
    USING (EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.group_id = %L
    ));
    
    CREATE POLICY group_member_withdrawals_insert
    ON public.%I
    FOR INSERT
    WITH CHECK (
      auth.uid() = user_id AND
      EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.group_id = %L
      )
    );
    
    CREATE POLICY group_member_withdrawals_update
    ON public.%I
    FOR UPDATE
    USING (
      auth.uid() = user_id AND
      EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.group_id = %L
      )
    )
    WITH CHECK (
      auth.uid() = user_id AND
      EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.group_id = %L
      )
    );
  ', withdrawals_table, withdrawals_table, NEW.id, withdrawals_table, NEW.id, withdrawals_table, NEW.id, withdrawals_table, NEW.id, NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create dynamic tables when a new group is created
CREATE TRIGGER create_group_tables_trigger
AFTER INSERT ON public.groups
FOR EACH ROW
EXECUTE FUNCTION create_group_tables();

-- Function to add a member column to the matrix when a user joins a group
CREATE OR REPLACE FUNCTION add_member_to_matrix()
RETURNS TRIGGER AS $$
DECLARE
  matrix_table TEXT;
  metadata_table TEXT;
  old_group_id UUID;
BEGIN
  -- Only proceed if group_id is changing
  IF OLD.group_id IS DISTINCT FROM NEW.group_id THEN
    -- Handle case where user is leaving a group
    IF OLD.group_id IS NOT NULL THEN
      old_group_id := OLD.group_id;
      matrix_table := 'group_' || old_group_id || '_matrix';
      metadata_table := 'group_' || old_group_id || '_metadata';
      
      -- Drop member column from old matrix
      EXECUTE format('
        ALTER TABLE public.%I DROP COLUMN IF EXISTS member_%s;
      ', matrix_table, OLD.id);
      
      -- Update member count in old group metadata
      EXECUTE format('
        UPDATE public.%I
        SET active_members_count = active_members_count - 1,
            last_updated = now();
      ', metadata_table);
    END IF;
    
    -- Handle case where user is joining a group
    IF NEW.group_id IS NOT NULL THEN
      matrix_table := 'group_' || NEW.group_id || '_matrix';
      metadata_table := 'group_' || NEW.group_id || '_metadata';
      
      -- Add member column to matrix
      EXECUTE format('
        ALTER TABLE public.%I 
        ADD COLUMN member_%s TEXT DEFAULT NULL;
      ', matrix_table, NEW.id);
      
      -- Update member count in metadata
      EXECUTE format('
        UPDATE public.%I
        SET active_members_count = active_members_count + 1,
            last_updated = now();
      ', metadata_table);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update matrix when a user joins or leaves a group
CREATE TRIGGER update_matrix_on_group_join
AFTER UPDATE OF group_id ON public.users
FOR EACH ROW
EXECUTE FUNCTION add_member_to_matrix();

-- Function to approve admin request
CREATE OR REPLACE FUNCTION approve_admin_request()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    UPDATE public.users
    SET is_admin = TRUE,
        updated_at = now()
    WHERE id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to handle admin approval
CREATE TRIGGER handle_admin_approval
AFTER UPDATE OF status ON public.admin_requests
FOR EACH ROW
WHEN (NEW.status = 'approved' AND OLD.status = 'pending')
EXECUTE FUNCTION approve_admin_request();

-- Function to approve group join request
CREATE OR REPLACE FUNCTION approve_join_request()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    UPDATE public.users
    SET group_id = NEW.group_id,
        updated_at = now()
    WHERE id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to handle group join approval
CREATE TRIGGER handle_join_approval
AFTER UPDATE OF status ON public.group_join_requests
FOR EACH ROW
WHEN (NEW.status = 'approved' AND OLD.status = 'pending')
EXECUTE FUNCTION approve_join_request();

-- Function to add a new month to the matrix automatically
CREATE OR REPLACE FUNCTION add_next_month_to_matrix()
RETURNS void AS $$
DECLARE
  group_record RECORD;
  matrix_table TEXT;
  metadata_table TEXT;
  current_month INTEGER;
  next_month_date DATE;
BEGIN
  FOR group_record IN SELECT * FROM public.groups LOOP
    matrix_table := 'group_' || group_record.id || '_matrix';
    metadata_table := 'group_' || group_record.id || '_metadata';
    
    -- Get current month number
    EXECUTE format('
      SELECT current_month_number FROM public.%I LIMIT 1;
    ', metadata_table) INTO current_month;
    
    -- Calculate next month date
    next_month_date := group_record.start_month_year + (current_month * interval '1 month');
    
    -- Add next month to matrix
    EXECUTE format('
      INSERT INTO public.%I (month_number, month_year)
      VALUES (%L, %L);
      
      UPDATE public.%I
      SET current_month_number = %L,
          last_updated = now();
    ', matrix_table, current_month + 1, next_month_date, metadata_table, current_month + 1);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Setup RLS policies

-- RLS for users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_self_view
ON public.users
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY users_self_update
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY users_site_master_view
ON public.users
FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND u.is_site_master = TRUE
));

CREATE POLICY users_site_master_update
ON public.users
FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND u.is_site_master = TRUE
));

-- RLS for admin_requests table
ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_requests_create
ON public.admin_requests
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY admin_requests_self_view
ON public.admin_requests
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY admin_requests_site_master
ON public.admin_requests
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND u.is_site_master = TRUE
));

-- RLS for groups table
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY groups_admin_full_access
ON public.groups
USING (created_by = auth.uid());

CREATE POLICY groups_member_view
ON public.groups
FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND u.group_id = id
));

CREATE POLICY groups_site_master_view
ON public.groups
FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id = auth.uid() AND u.is_site_master = TRUE
));

-- RLS for group_join_requests table
ALTER TABLE public.group_join_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY join_requests_create
ON public.group_join_requests
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY join_requests_self_view
ON public.group_join_requests
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY join_requests_admin_view
ON public.group_join_requests
USING (EXISTS (
  SELECT 1 FROM public.groups g
  WHERE g.id = group_id AND g.created_by = auth.uid()
));

CREATE POLICY join_requests_admin_update
ON public.group_join_requests
FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM public.groups g
  WHERE g.id = group_id AND g.created_by = auth.uid()
));

-- Function to record a contribution
CREATE OR REPLACE FUNCTION record_contribution(
  p_user_id UUID,
  p_amount NUMERIC,
  p_withdrawal_amount NUMERIC DEFAULT 0,
  p_payback_amount NUMERIC DEFAULT 0
)
RETURNS void AS $$
DECLARE
  v_group_id UUID;
  v_matrix_table TEXT;
  v_metadata_table TEXT;
  v_current_month INTEGER;
  v_contribution_string TEXT;
BEGIN
  -- Get the user's group
  SELECT group_id INTO v_group_id
  FROM public.users
  WHERE id = p_user_id;
  
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'User is not a member of any group';
  END IF;
  
  -- Set table names
  v_matrix_table := 'group_' || v_group_id || '_matrix';
  v_metadata_table := 'group_' || v_group_id || '_metadata';
  
  -- Get current month
  EXECUTE format('
    SELECT current_month_number FROM public.%I LIMIT 1;
  ', v_metadata_table) INTO v_current_month;
  
  -- Format contribution string
  v_contribution_string := '+' || p_amount;
  
  IF p_payback_amount > 0 THEN
    v_contribution_string := v_contribution_string || '+' || p_payback_amount;
  END IF;
  
  IF p_withdrawal_amount > 0 THEN
    v_contribution_string := v_contribution_string || '-' || p_withdrawal_amount;
  END IF;
  
  -- Record contribution in matrix
  EXECUTE format('
    UPDATE public.%I
    SET member_%s = %L,
        total_contributions = total_contributions + %L
    WHERE month_number = %L;
  ', v_matrix_table, p_user_id, v_contribution_string, p_amount + p_payback_amount, v_current_month);
  
  -- Update group total pool
  UPDATE public.groups
  SET total_pool = total_pool + p_amount + p_payback_amount - p_withdrawal_amount,
      updated_at = now()
  WHERE id = v_group_id;
  
  -- If there was a withdrawal amount, record it in withdrawals
  IF p_withdrawal_amount > 0 THEN
    EXECUTE format('
      INSERT INTO public.%I_withdrawals (
        user_id,
        month_number,
        amount,
        status,
        remaining_amount
      ) VALUES (
        %L,
        %L,
        %L,
        ''approved'',
        %L
      );
    ', 'group_' || v_group_id, p_user_id, v_current_month, p_withdrawal_amount, p_withdrawal_amount);
    
    -- Update total withdrawals in matrix
    EXECUTE format('
      UPDATE public.%I
      SET total_withdrawals = total_withdrawals + %L
      WHERE month_number = %L;
    ', v_matrix_table, p_withdrawal_amount, v_current_month);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to select lottery winner
CREATE OR REPLACE FUNCTION select_lottery_winner(p_group_id UUID)
RETURNS UUID AS $$
DECLARE
  v_matrix_table TEXT;
  v_metadata_table TEXT;
  v_current_month INTEGER;
  v_member_columns TEXT[];
  v_winner_id UUID;
BEGIN
  -- Only proceed if group is a lottery type
  IF NOT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = p_group_id AND type = 'lottery'
  ) THEN
    RAISE EXCEPTION 'Group is not a lottery type';
  END IF;
  
  -- Set table names
  v_matrix_table := 'group_' || p_group_id || '_matrix';
  v_metadata_table := 'group_' || p_group_id || '_metadata';
  
  -- Get current month
  EXECUTE format('
    SELECT current_month_number FROM public.%I LIMIT 1;
  ', v_metadata_table) INTO v_current_month;
  
  -- Get all member columns
  EXECUTE format('
    SELECT array_agg(column_name)
    FROM information_schema.columns
    WHERE table_name = %L
    AND column_name LIKE ''member_%%'';
  ', v_matrix_table) INTO v_member_columns;
  
  -- Randomly select a winner from contributing members
  EXECUTE format('
    WITH contributing_members AS (
      SELECT unnest(%L::text[]) AS column_name
      FROM public.%I
      WHERE month_number = %L
      AND (
        %s
      )
    )
    SELECT substr(column_name, 8)::uuid
    FROM contributing_members
    ORDER BY random()
    LIMIT 1;
  ', 
    v_member_columns,
    v_matrix_table,
    v_current_month,
    array_to_string(
      array(
        SELECT format('%I IS NOT NULL', col)
        FROM unnest(v_member_columns) col
      ),
      ' OR '
    )
  ) INTO v_winner_id;
  
  -- Record the winner in the matrix
  IF v_winner_id IS NOT NULL THEN
    EXECUTE format('
      UPDATE public.%I
      SET lottery_winner_id = %L
      WHERE month_number = %L;
    ', v_matrix_table, v_winner_id, v_current_month);
  END IF;
  
  RETURN v_winner_id;
END;
$$ LANGUAGE plpgsql;

-- Create a function to initialize the first site master
CREATE OR REPLACE FUNCTION initialize_first_site_master(p_email TEXT)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET is_site_master = TRUE,
      is_admin = TRUE,
      updated_at = now()
  WHERE email = p_email;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at timestamp
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_users
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_groups
BEFORE UPDATE ON public.groups
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp(); 