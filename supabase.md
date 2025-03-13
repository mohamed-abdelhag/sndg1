# Supabase Configuration

## Current Database Structure

### Tables

| Table Name | Description | Notes |
|------------|-------------|-------|
| admin_requests | Tracks admin role requests | Used for site master approval workflow |
| group_join_requests | Tracks group join requests | Used for admin approval of members |
| groups | Stores group information | Main groups table |
| users | Extended user profile data | Contains admin and site master flags |

### Functions

| Function Name | Parameters | Return Type | Description |
|---------------|------------|-------------|-------------|
| add_member_column | group_id uuid, user_id uuid | void | Adds a column for a new member in contribution matrix |
| add_new_month_to_matrix | group_id uuid | void | Adds a new month row to a group's contribution matrix |
| approve_admin_request | request_id uuid, site_master_id uuid | void | Site master approves admin request |
| approve_join_request | request_id uuid, admin_id uuid | void | Admin approves join request |
| approve_withdrawal | group_id uuid, withdrawal_id uuid, admin_id uuid | void | Admin approves withdrawal request |
| check_admin_request_eligibility | user_id uuid | boolean | Checks if user is eligible to request admin status |
| create_group_and_update_creator | name text, description text, type text, monthly_contribution_amount numeric, start_month_year date, creator_id uuid | uuid | Creates group and updates creator's status |
| create_group_contribution_matrix | group_id uuid | void | Creates contribution matrix table for group |
| create_group_tables | group_id uuid | void | Creates all required tables for a new group |
| create_group_withdrawal_table | group_id uuid | void | Creates withdrawal table for group |
| get_admin_request_ineligibility_reason | user_id uuid | text | Gets reason why user can't request admin status |
| initialize_monthly_row | group_id uuid, month_number integer | void | Initializes a new month row in matrix |
| record_contribution | parameters vary | void | Records contribution in matrix |
| record_payback | group_id uuid, user_id uuid, withdrawal_id uuid, month_number integer, payback_amount numeric | void | Records payback amount |
| reject_admin_request | request_id uuid, site_master_id uuid | void | Site master rejects admin request |
| reject_join_request | request_id uuid, admin_id uuid | void | Admin rejects join request |
| request_withdrawal | group_id uuid, user_id uuid, month_number integer, amount numeric, reason text, payback_months integer | uuid | Creates withdrawal request |
| select_lottery_winner | group_id uuid, month_number integer | uuid | Selects winner for lottery groups |
| update_modified_column | - | trigger | Updates timestamp on record modification |

### Triggers

| Trigger Name | Table | Function | Event | Level |
|--------------|-------|----------|-------|-------|
| after_group_created | groups | create_group_tables_trigger | AFTER INSERT | ROW |
| update_groups_timestamp | groups | update_modified_column | BEFORE UPDATE | ROW |
| update_users_timestamp | users | update_modified_column | BEFORE UPDATE | ROW |

### Row Level Security (RLS) Policies

#### admin_requests Table

| Policy | Description | Applied to Role |
|--------|-------------|-----------------|
| UPDATE | Site masters can update admin requests | `public` |
| SELECT | Site masters can view all admin requests | `public` |
| INSERT | Users can create their own admin requests | `public` |
| INSERT | Users can only create admin requests if eligible | `public` |
| SELECT | Users can see their own admin requests | `public` |

#### group_join_requests Table

| Policy | Description | Applied to Role |
|--------|-------------|-----------------|
| UPDATE | Group admins can update join requests for their group | `public` |
| SELECT | Group admins can view join requests for their group | `public` |
| INSERT | Users can create their own join requests | `public` |
| SELECT | Users can see their own join requests | `public` |

#### groups Table

| Policy | Description | Applied to Role |
|--------|-------------|-----------------|
| ALL | Group creators can do everything | `public` |
| SELECT | Group members can view | `public` |

#### users Table

Currently has RLS enabled but no policies defined.

## Missing Elements and Needed Updates

### 1. Missing Tables

The following dynamic tables need to be created per group:

```sql
-- Note: These are created dynamically by the create_group_tables function
-- {group_id}_matrix - For tracking contributions
-- {group_id}_withdrawals - For tracking withdrawals
```

### 2. Missing RLS Policies

RLS policies needed for the `users` table:

```sql
-- Allow users to view their own profile
CREATE POLICY "Users can view own profile"
ON users
FOR SELECT
USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile"
ON users
FOR UPDATE
USING (auth.uid() = id);

-- Allow site masters to view all users
CREATE POLICY "Site masters can view all users"
ON users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND is_site_master = true
  )
);

-- Allow site masters to update user admin status
CREATE POLICY "Site masters can update admin status"
ON users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND is_site_master = true
  )
);
```

### 3. Database Schema Updates

Ensure the tables have the correct structure:

```sql
-- Check/update admin_requests table structure
ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS reason text;
ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending'::text;
ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS requested_at timestamp with time zone DEFAULT now();
ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS responded_at timestamp with time zone;
ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS responded_by uuid REFERENCES auth.users(id);

-- Check/update users table structure
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_site_master boolean DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS group_id uuid REFERENCES groups(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name text;
```

### 4. Missing Functions for Site Master and Admin Management

```sql
-- Function to check if a user is a site master
CREATE OR REPLACE FUNCTION is_site_master(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  is_master boolean;
BEGIN
  SELECT is_site_master INTO is_master
  FROM users
  WHERE id = user_id;
  
  RETURN COALESCE(is_master, false);
END;
$$;

-- Function to check if a user is an admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  is_user_admin boolean;
BEGIN
  SELECT is_admin INTO is_user_admin
  FROM users
  WHERE id = user_id;
  
  RETURN COALESCE(is_user_admin, false);
END;
$$;

-- Function to get all pending admin requests for site master
CREATE OR REPLACE FUNCTION get_pending_admin_requests()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  reason text,
  status text,
  requested_at timestamp with time zone,
  user_email text,
  user_first_name text,
  user_last_name text
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ar.id,
    ar.user_id,
    ar.reason,
    ar.status,
    ar.requested_at,
    u.email as user_email,
    u.first_name as user_first_name,
    u.last_name as user_last_name
  FROM admin_requests ar
  JOIN users u ON ar.user_id = u.id
  WHERE ar.status = 'pending'
  ORDER BY ar.requested_at DESC;
END;
$$;
```

### 5. Function Improvements

```sql
-- Update the approve_admin_request function to ensure it works properly
CREATE OR REPLACE FUNCTION approve_admin_request(request_id uuid, site_master_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is site master
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = site_master_id AND is_site_master = true) THEN
    RAISE EXCEPTION 'User is not a site master';
  END IF;
  
  -- Update the request status
  UPDATE admin_requests
  SET 
    status = 'approved',
    responded_at = now(),
    responded_by = site_master_id
  WHERE id = request_id AND status = 'pending';
  
  -- Make the user an admin
  UPDATE users
  SET 
    is_admin = true
  FROM admin_requests
  WHERE users.id = admin_requests.user_id AND admin_requests.id = request_id;
END;
$$;

-- Update the reject_admin_request function to ensure it works properly
CREATE OR REPLACE FUNCTION reject_admin_request(request_id uuid, site_master_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is site master
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = site_master_id AND is_site_master = true) THEN
    RAISE EXCEPTION 'User is not a site master';
  END IF;
  
  -- Update the request status
  UPDATE admin_requests
  SET 
    status = 'rejected',
    responded_at = now(),
    responded_by = site_master_id
  WHERE id = request_id AND status = 'pending';
END;
$$;
```

### 6. Add Initial Site Master User

```sql
-- This should be run once on database setup to create an initial site master
-- Replace with actual email and password
INSERT INTO auth.users (email, password) 
VALUES ('sitemaster@sandoog.com', 'your-secure-password-hash') 
RETURNING id;

-- Get the created user ID and set it as site master
UPDATE users
SET is_site_master = true
WHERE email = 'sitemaster@sandoog.com';
```

## Implementation Status

- ✅ Basic table structure exists
- ✅ Most functions for group management exist
- ✅ RLS is enabled on all tables
- ✅ Basic triggers for maintenance are in place
- ❌ Users table needs RLS policies
- ❌ Helper functions for site master checks need improvement
- ❌ Initial site master creation script needed
- ❌ Some function improvements needed

## Next Steps

1. Apply the missing RLS policies for users table
2. Add the improved admin approval functions
3. Create site master helper functions
4. Ensure dynamic tables are created correctly for groups
5. Test the site master approval workflow end-to-end
6. Verify admin request eligibility checks work properly
7. Test user flow from login to redirection based on status

## Project Status

### Authentication
- [ ] Email authentication setup
- [ ] Password reset flow enabled

### Database Structure

#### Main Tables

##### groups
- [ ] Created
- Core group information
- Contains group settings and member lists
- Tracks total pool amount

Key fields:
- id (uuid, primary key)
- name (text)
- description (text)
- type (text) - 'standard' or 'lottery'
- monthly_contribution_amount (decimal)
- total_pool (decimal) - Updated monthly
- start_month_year (date) - Used for calculating month numbers
- created_by (uuid, references auth.users) - The admin/creator
- members (uuid[], references auth.users) - Array of member IDs
- created_at (timestamp)
- updated_at (timestamp)

#### Dynamic Per-Group Tables

Each group gets two dynamic tables automatically created:

##### 1. Contribution Matrix: `group_{group_id}_matrix`
- [ ] Dynamic creation
- Matrix structure with numbered months as rows and members as columns
- Tracks contributions and withdrawals in combined format
- Row numbering starts at 1 (first month of group)

Key structure:
- month_number (integer, primary key) - 1, 2, 3, etc. from group creation
- month_year (date) - Actual month/year date
- total_contributions (decimal) - Sum of all contributions that month
- total_withdrawals (decimal) - Sum of all withdrawals that month
- lottery_winner_id (uuid, nullable) - Only for lottery groups
- member_{user_id} (text) - One column per member with format:
  - Normal contribution: "+500"
  - Contribution with payback: "+500+200"
  - Contribution with withdrawal: "+500-1000"
  - Lottery winner: "+500-5000"

##### 2. Withdrawals: `group_{group_id}_withdrawals`
- [ ] Dynamic creation
- Tracks all withdrawal requests and payback plans
- Links to matrix for display

Key structure:
- id (uuid, primary key)
- user_id (uuid, references auth.users)
- month_number (integer) - When withdrawal was requested
- amount (decimal)
- reason (text)
- status (text) - 'requested', 'approved', 'withdrawn', 'paid'
- approved_by (uuid, references auth.users)
- approved_at (timestamp)
- payback_amount_monthly (decimal)
- payback_period_months (integer)
- due_by_date (date)
- remaining_amount (decimal)
- created_at (timestamp)
- updated_at (timestamp)

## Project Implementation

### Functions to Implement

- [ ] `create_group_tables(group_id)`
  - Creates both matrix and withdrawals tables for a new group
  - Sets initial structure based on group type

- [ ] `add_member_column(group_id, user_id)`
  - Adds new column for member in matrix table
  - Default value of '0' for all existing months

- [ ] `record_contribution(group_id, user_id, month_number, contribution_amount, payback_amount)`
  - Records contribution in matrix
  - Format: "+contribution_amount+payback_amount"
  - Updates total contributions for the month
  - Updates group total pool

- [ ] `request_withdrawal(group_id, user_id, month_number, amount, reason, payback_months)`
  - Creates withdrawal request record
  - Sets status to 'requested'
  - Calculates monthly payback amount and due date

- [ ] `approve_withdrawal(group_id, withdrawal_id)`
  - Updates withdrawal status to 'approved'
  - Updates matrix cell with withdrawal amount
  - Creates payback obligation
  - Updates total withdrawals
  - Updates group total pool

- [ ] `record_payback(group_id, user_id, withdrawal_id, month_number, amount)`
  - Updates remaining payback amount
  - Marks as 'paid' if fully paid back
  - Includes payback in monthly contribution cell

- [ ] `select_lottery_winner(group_id, month_number)`
  - For lottery groups only
  - Randomly selects eligible member
  - Creates and auto-approves withdrawal for full pool
  - Updates matrix cell and lottery_winner_id

- [ ] `initialize_monthly_row(group_id, month_number)`
  - Creates new row in matrix for the month
  - Called automatically at beginning of month

### Monthly Process Flow

1. System creates new month row in matrix table
2. Members submit contributions (app combines with any payback obligations)
3. System updates total contributions and pool amount
4. Members can request withdrawals
5. Admin approves/rejects withdrawals
6. For lottery groups, system selects winner at month end

### Example Data

#### Group Record Example
```
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Family Savings",
  "description": "Our family emergency fund",
  "type": "standard",
  "monthly_contribution_amount": 500.00,
  "total_pool": 4500.00,
  "start_month_year": "2024-01-01",
  "created_by": "auth-user-id-of-creator",
  "members": ["user-id-1", "user-id-2", "user-id-3"],
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-03-15T00:00:00Z"
}
```

#### Matrix Table Example (group_123_matrix)
```
╔══════════════╦══════════════╦══════════════════╦═══════════════════╦═══════════════╦═══════════════╦═══════════════╗
║ month_number ║ month_year   ║ total_contrib    ║ total_withdrawals ║ member_user1  ║ member_user2  ║ member_user3  ║
╠══════════════╬══════════════╬══════════════════╬═══════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ 1            ║ 2024-01-01   ║ 1500.00          ║ 0.00              ║ +500          ║ +500          ║ +500          ║
║ 2            ║ 2024-02-01   ║ 1700.00          ║ 0.00              ║ +500+200      ║ +500          ║ +500          ║
║ 3            ║ 2024-03-01   ║ 1700.00          ║ 1000.00           ║ +500+200      ║ +500-1000     ║ +500          ║
╚══════════════╩══════════════╩══════════════════╩═══════════════════╩═══════════════╩═══════════════╩═══════════════╝
```

#### Withdrawals Table Example (group_123_withdrawals)
```
╔════════════╦═══════════╦═════════════╦════════╦════════════╦═════════╦═════════════════╦═══════════════════╦══════════════════════╗
║ id         ║ user_id   ║ month_number║ amount ║ reason     ║ status  ║ payback_monthly ║ payback_period    ║ remaining_amount     ║
╠════════════╬═══════════╬═════════════╬════════╬════════════╬═════════╬═════════════════╬═══════════════════╬══════════════════════╣
║ wd-123     ║ user-id-2 ║ 3           ║ 1000.00║ Emergency  ║ approved║ 200.00          ║ 5                 ║ 600.00               ║
╚════════════╩═══════════╩═════════════╩════════╩════════════╩═════════╩═════════════════╩═══════════════════╩══════════════════════╝
```

### User Interface Requirements

#### Contribution Matrix Display
- Month numbers (1, 2, 3...) instead of actual dates
- Breakdown of contribution and payback in cells
- Color coding:
  - Normal contributions: Green
  - Contributions with payback: Blue
  - Withdrawals: Red
  - Lottery winners: Purple

#### Withdrawal Management
- Form for withdrawal request
- Payback plan calculator
- Admin approval interface
- Tracking of remaining balance

#### Payback Tracking
- Progress indicators for each withdrawal
- Monthly breakdown of payback obligations
- Due date reminders

## Key Application Flows

### Standard Group Flow
1. Group created with start_month_year
2. Members join group
3. Monthly contributions tracked in matrix
4. Withdrawals requested and approved
5. Paybacks tracked in matrix cells and withdrawal table
6. Total pool maintained in group table

### Lottery Group Flow
1. Group created with start_month_year
2. Members join group
3. Monthly contributions tracked in matrix
4. Monthly winner selected automatically
5. Winner receives full pool amount (shown in matrix)
6. Process repeats until all members have won once

## Environment Variables
```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

## Deployment History
- Initial setup: [Date]
- Database migrations: [Dates]
- Policy updates: [Dates]

## Backup Schedule
- Daily automated backups
- Weekly manual verification
- Monthly backup testing

