-- this sql isnt meant to be ran in the editor here but in the web site supabase online sql editor thats for one always keep tis comment here
-- success no rows returned 
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create groups table
CREATE TABLE public.groups (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('standard', 'lottery')),
    monthly_contribution_amount DECIMAL NOT NULL,
    total_pool DECIMAL NOT NULL DEFAULT 0,
    start_month_year DATE NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    members UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id)
);

-- Enable RLS on groups table
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

-- Group access policies
CREATE POLICY "Group creators can do everything" 
ON public.groups 
FOR ALL 
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Group members can view" 
ON public.groups 
FOR SELECT 
USING (auth.uid() = ANY(members) OR created_by = auth.uid());

-- Create function to generate dynamic tables for a new group
CREATE OR REPLACE FUNCTION create_group_tables(group_id UUID)
RETURNS VOID AS $$
DECLARE
    matrix_table_name TEXT;
    withdrawals_table_name TEXT;
BEGIN
    -- Set table names
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    withdrawals_table_name := 'group_' || group_id::TEXT || '_withdrawals';
    
    -- Create matrix table
    EXECUTE format('
        CREATE TABLE public.%I (
            month_number INTEGER PRIMARY KEY,
            month_year DATE NOT NULL,
            total_contributions DECIMAL NOT NULL DEFAULT 0,
            total_withdrawals DECIMAL NOT NULL DEFAULT 0,
            lottery_winner_id UUID REFERENCES auth.users(id),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    ', matrix_table_name);
    
    -- Create withdrawals table
    EXECUTE format('
        CREATE TABLE public.%I (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            user_id UUID NOT NULL REFERENCES auth.users(id),
            month_number INTEGER NOT NULL,
            amount DECIMAL NOT NULL,
            reason TEXT,
            status TEXT NOT NULL CHECK (status IN (''requested'', ''approved'', ''withdrawn'', ''paid'')),
            approved_by UUID REFERENCES auth.users(id),
            approved_at TIMESTAMPTZ,
            payback_amount_monthly DECIMAL,
            payback_period_months INTEGER,
            due_by_date DATE,
            remaining_amount DECIMAL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    ', withdrawals_table_name);
    
    -- Enable RLS on both tables
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', matrix_table_name);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', withdrawals_table_name);
    
    -- Create policies for matrix table
    EXECUTE format('
        CREATE POLICY "Group members can view matrix"
        ON public.%I
        FOR SELECT
        USING (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND (auth.uid() = ANY(members) OR auth.uid() = created_by)
        ));
    ', matrix_table_name, group_id);
    
    EXECUTE format('
        CREATE POLICY "Group admin can update matrix"
        ON public.%I
        FOR ALL
        USING (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND auth.uid() = created_by
        ))
        WITH CHECK (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND auth.uid() = created_by
        ));
    ', matrix_table_name, group_id, group_id);
    
    -- Create policies for withdrawals table
    EXECUTE format('
        CREATE POLICY "Group members can view withdrawals"
        ON public.%I
        FOR SELECT
        USING (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND (auth.uid() = ANY(members) OR auth.uid() = created_by)
        ));
    ', withdrawals_table_name, group_id);
    
    EXECUTE format('
        CREATE POLICY "Group members can create withdrawal requests"
        ON public.%I
        FOR INSERT
        WITH CHECK (
            user_id = auth.uid() AND
            EXISTS (
                SELECT 1 FROM public.groups
                WHERE id = %L AND auth.uid() = ANY(members)
            )
        );
    ', withdrawals_table_name, group_id);
    
    EXECUTE format('
        CREATE POLICY "Group admin can update withdrawal status"
        ON public.%I
        FOR UPDATE
        USING (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND auth.uid() = created_by
        ))
        WITH CHECK (EXISTS (
            SELECT 1 FROM public.groups
            WHERE id = %L AND auth.uid() = created_by
        ));
    ', withdrawals_table_name, group_id, group_id);
    
    -- Initialize month 1 in matrix
    EXECUTE format('
        INSERT INTO public.%I (month_number, month_year, total_contributions, total_withdrawals)
        SELECT 1, start_month_year, 0, 0
        FROM public.groups
        WHERE id = %L;
    ', matrix_table_name, group_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add a member column to a matrix table
CREATE OR REPLACE FUNCTION add_member_column(group_id UUID, user_id UUID)
RETURNS VOID AS $$
DECLARE
    matrix_table_name TEXT;
    column_name TEXT;
    column_exists BOOLEAN;
BEGIN
    -- Set table name and column name
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    column_name := 'member_' || user_id::TEXT;
    
    -- Check if column exists
    EXECUTE format('
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = %L AND column_name = %L
        );
    ', matrix_table_name, column_name) INTO column_exists;
    
    -- Add the column if it doesn't exist
    IF NOT column_exists THEN
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN %I TEXT DEFAULT ''0'';', 
                      matrix_table_name, column_name);
    END IF;
    
    -- Update the members array in the groups table
    UPDATE public.groups
    SET members = array_append(members, user_id)
    WHERE id = group_id AND NOT (user_id = ANY(members));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record a contribution
CREATE OR REPLACE FUNCTION record_contribution(
    group_id UUID,
    user_id UUID,
    month_number INTEGER,
    contribution_amount DECIMAL,
    payback_amount DECIMAL DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
    matrix_table_name TEXT;
    column_name TEXT;
    contribution_text TEXT;
    current_total DECIMAL;
BEGIN
    -- Set table name and column name
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    column_name := 'member_' || user_id::TEXT;
    
    -- Format the contribution text
    IF payback_amount > 0 THEN
        contribution_text := '+' || contribution_amount::TEXT || '+' || payback_amount::TEXT;
    ELSE
        contribution_text := '+' || contribution_amount::TEXT;
    END IF;
    
    -- Update the matrix cell
    EXECUTE format('
        UPDATE public.%I
        SET %I = %L,
            total_contributions = total_contributions + %L,
            updated_at = NOW()
        WHERE month_number = %L;
    ', matrix_table_name, column_name, contribution_text, contribution_amount + payback_amount, month_number);
    
    -- Update total pool in groups table
    SELECT total_pool INTO current_total FROM public.groups WHERE id = group_id;
    
    UPDATE public.groups
    SET total_pool = current_total + contribution_amount + payback_amount,
        updated_at = NOW()
    WHERE id = group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to request a withdrawal
CREATE OR REPLACE FUNCTION request_withdrawal(
    group_id UUID,
    user_id UUID,
    month_number INTEGER,
    amount DECIMAL,
    reason TEXT,
    payback_months INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    withdrawals_table_name TEXT;
    new_withdrawal_id UUID;
    payback_monthly DECIMAL;
    due_date DATE;
    current_date DATE;
    current_total DECIMAL;
BEGIN
    -- Validate group exists and user is a member
    IF NOT EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = group_id AND user_id = ANY(members)
    ) THEN
        RAISE EXCEPTION 'User is not a member of this group';
    END IF;
    
    -- Get current total pool
    SELECT total_pool INTO current_total FROM public.groups WHERE id = group_id;
    
    -- Check if there's enough in the pool
    IF amount > current_total THEN
        RAISE EXCEPTION 'Insufficient funds in group pool';
    END IF;
    
    -- Set table name
    withdrawals_table_name := 'group_' || group_id::TEXT || '_withdrawals';
    
    -- Calculate payback details if this is a standard group
    SELECT start_month_year + ((month_number - 1) || ' months')::INTERVAL INTO current_date
    FROM public.groups WHERE id = group_id;
    
    IF payback_months IS NOT NULL THEN
        payback_monthly := amount / payback_months;
        due_date := current_date + (payback_months || ' months')::INTERVAL;
    END IF;
    
    -- Insert withdrawal request
    EXECUTE format('
        INSERT INTO public.%I (
            user_id, 
            month_number, 
            amount, 
            reason, 
            status, 
            payback_amount_monthly, 
            payback_period_months, 
            due_by_date,
            remaining_amount
        ) 
        VALUES (
            %L, 
            %L, 
            %L, 
            %L, 
            ''requested'', 
            %L, 
            %L, 
            %L,
            %L
        )
        RETURNING id
    ', withdrawals_table_name, user_id, month_number, amount, reason, 
       payback_monthly, payback_months, due_date, amount) INTO new_withdrawal_id;
    
    RETURN new_withdrawal_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to approve a withdrawal
CREATE OR REPLACE FUNCTION approve_withdrawal(
    group_id UUID,
    withdrawal_id UUID,
    admin_id UUID
)
RETURNS VOID AS $$
DECLARE
    withdrawals_table_name TEXT;
    matrix_table_name TEXT;
    withdrawal_record RECORD;
    column_name TEXT;
    current_cell TEXT;
    updated_cell TEXT;
    contribution_amount DECIMAL;
    new_total DECIMAL;
    group_type TEXT;
BEGIN
    -- Check if admin is the group creator
    IF NOT EXISTS (
        SELECT 1 FROM public.groups
        WHERE id = group_id AND created_by = admin_id
    ) THEN
        RAISE EXCEPTION 'Only the group creator can approve withdrawals';
    END IF;
    
    -- Set table names
    withdrawals_table_name := 'group_' || group_id::TEXT || '_withdrawals';
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    
    -- Get withdrawal record
    EXECUTE format('
        SELECT * FROM public.%I
        WHERE id = %L AND status = ''requested''
    ', withdrawals_table_name, withdrawal_id) INTO withdrawal_record;
    
    IF withdrawal_record IS NULL THEN
        RAISE EXCEPTION 'Withdrawal request not found or already processed';
    END IF;
    
    -- Get group type
    SELECT type INTO group_type FROM public.groups WHERE id = group_id;
    
    -- Set column name
    column_name := 'member_' || withdrawal_record.user_id::TEXT;
    
    -- Get current cell value
    EXECUTE format('
        SELECT %I FROM public.%I
        WHERE month_number = %L
    ', column_name, matrix_table_name, withdrawal_record.month_number) INTO current_cell;
    
    -- Extract contribution amount from cell
    IF current_cell ~ '^\+([0-9]+)' THEN
        contribution_amount := (regexp_matches(current_cell, '^\+([0-9]+)'))[1]::DECIMAL;
    ELSE
        contribution_amount := 0;
    END IF;
    
    -- Create updated cell value with withdrawal
    updated_cell := '+' || contribution_amount::TEXT || '-' || withdrawal_record.amount::TEXT;
    
    -- Update matrix cell
    EXECUTE format('
        UPDATE public.%I
        SET %I = %L,
            total_withdrawals = total_withdrawals + %L,
            updated_at = NOW()
        WHERE month_number = %L;
    ', matrix_table_name, column_name, updated_cell, withdrawal_record.amount, withdrawal_record.month_number);
    
    -- Update withdrawal status
    EXECUTE format('
        UPDATE public.%I
        SET status = ''approved'',
            approved_by = %L,
            approved_at = NOW(),
            updated_at = NOW()
        WHERE id = %L;
    ', withdrawals_table_name, admin_id, withdrawal_id);
    
    -- Update total pool in groups table
    SELECT total_pool INTO new_total FROM public.groups WHERE id = group_id;
    new_total := new_total - withdrawal_record.amount;
    
    UPDATE public.groups
    SET total_pool = new_total,
        updated_at = NOW()
    WHERE id = group_id;
    
    -- For lottery groups, update lottery_winner_id
    IF group_type = 'lottery' THEN
        EXECUTE format('
            UPDATE public.%I
            SET lottery_winner_id = %L
            WHERE month_number = %L;
        ', matrix_table_name, withdrawal_record.user_id, withdrawal_record.month_number);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record a payback
CREATE OR REPLACE FUNCTION record_payback(
    group_id UUID,
    user_id UUID,
    withdrawal_id UUID,
    month_number INTEGER,
    payback_amount DECIMAL
)
RETURNS VOID AS $$
DECLARE
    withdrawals_table_name TEXT;
    withdrawal_record RECORD;
    remaining DECIMAL;
BEGIN
    -- Set table name
    withdrawals_table_name := 'group_' || group_id::TEXT || '_withdrawals';
    
    -- Get withdrawal record
    EXECUTE format('
        SELECT * FROM public.%I
        WHERE id = %L AND status = ''approved''
    ', withdrawals_table_name, withdrawal_id) INTO withdrawal_record;
    
    IF withdrawal_record IS NULL THEN
        RAISE EXCEPTION 'Withdrawal not found or not approved';
    END IF;
    
    -- Calculate remaining amount
    remaining := withdrawal_record.remaining_amount - payback_amount;
    
    -- Update withdrawal record
    EXECUTE format('
        UPDATE public.%I
        SET remaining_amount = %L,
            status = CASE WHEN %L <= 0 THEN ''paid'' ELSE status END,
            updated_at = NOW()
        WHERE id = %L;
    ', withdrawals_table_name, 
       GREATEST(0, remaining), 
       remaining, 
       withdrawal_id);
    
    -- Include payback in contribution
    PERFORM record_contribution(
        group_id,
        user_id,
        month_number,
        0,  -- No new contribution, just payback
        payback_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to initialize a new monthly row
CREATE OR REPLACE FUNCTION initialize_monthly_row(
    group_id UUID,
    month_number INTEGER
)
RETURNS VOID AS $$
DECLARE
    matrix_table_name TEXT;
    start_date DATE;
    month_date DATE;
    row_exists BOOLEAN;
BEGIN
    -- Set table name
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    
    -- Calculate the date for this month
    SELECT start_month_year INTO start_date FROM public.groups WHERE id = group_id;
    month_date := start_date + ((month_number - 1) || ' months')::INTERVAL;
    
    -- Check if row already exists
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I WHERE month_number = %L)', 
                   matrix_table_name, month_number) INTO row_exists;
    
    IF row_exists THEN
        RETURN; -- Row already exists, nothing to do
    END IF;
    
    -- Create the new row
    EXECUTE format('
        INSERT INTO public.%I (
            month_number,
            month_year,
            total_contributions,
            total_withdrawals
        ) VALUES (
            %L,
            %L,
            0,
            0
        );
    ', matrix_table_name, month_number, month_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to select a lottery winner
CREATE OR REPLACE FUNCTION select_lottery_winner(
    group_id UUID,
    month_number INTEGER
)
RETURNS UUID AS $$
DECLARE
    matrix_table_name TEXT;
    group_record RECORD;
    eligible_members UUID[];
    winner_id UUID;
    pool_amount DECIMAL;
    withdrawal_id UUID;
BEGIN
    -- Check if this is a lottery group
    SELECT * INTO group_record 
    FROM public.groups 
    WHERE id = group_id AND type = 'lottery';
    
    IF group_record IS NULL THEN
        RAISE EXCEPTION 'Group not found or not a lottery group';
    END IF;
    
    -- Set table name
    matrix_table_name := 'group_' || group_id::TEXT || '_matrix';
    
    -- Check if winner already selected
    EXECUTE format('
        SELECT lottery_winner_id FROM public.%I
        WHERE month_number = %L;
    ', matrix_table_name, month_number) INTO winner_id;
    
    IF winner_id IS NOT NULL THEN
        RAISE EXCEPTION 'Winner already selected for this month';
    END IF;
    
    -- Get eligible members (those who have contributed this month)
    SELECT ARRAY(
        SELECT unnest(members)
        FROM public.groups
        WHERE id = group_id
    ) INTO eligible_members;
    
    -- Randomly select a winner
    SELECT eligible_members[floor(random() * array_length(eligible_members, 1)) + 1]
    INTO winner_id;
    
    -- Get current pool amount
    SELECT total_pool INTO pool_amount
    FROM public.groups
    WHERE id = group_id;
    
    -- Create withdrawal request
    SELECT request_withdrawal(
        group_id,
        winner_id,
        month_number,
        pool_amount,
        'Lottery win',
        NULL  -- No payback for lottery win
    ) INTO withdrawal_id;
    
    -- Auto-approve the withdrawal
    PERFORM approve_withdrawal(
        group_id,
        withdrawal_id,
        group_record.created_by
    );
    
    RETURN winner_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function to create tables when a group is created
CREATE OR REPLACE FUNCTION create_group_tables_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM create_group_tables(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER after_group_created
AFTER INSERT ON public.groups
FOR EACH ROW
EXECUTE FUNCTION create_group_tables_trigger();
