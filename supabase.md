# Supabase Configuration

## Database Structure

### Core Tables

#### 1. users (extends auth.users)
- Extended user profile data
- Contains admin and site master flags
- Key fields:
  - id (UUID, from auth.users)
  - email (from auth.users)
  - is_admin (boolean)
  - is_site_master (boolean)
  - group_id (UUID, nullable) - Links to group if user is a member
  - first_name (text)
  - last_name (text)
  - created_at (timestamp)
  - updated_at (timestamp)

#### 2. admin_requests
- Tracks admin role requests
- Used for site master approval workflow
- Key fields:
  - id (UUID)
  - user_id (UUID, references users.id)
  - reason (text)
  - status (text) - 'pending', 'approved', 'rejected'
  - requested_at (timestamp)
  - responded_at (timestamp)
  - responded_by (UUID, references users.id)

#### 3. groups
- Stores group information
- Main groups table
- Key fields:
  - id (UUID)
  - name (text)
  - description (text)
  - type (text) - 'standard' or 'lottery'
  - monthly_contribution_amount (numeric)
  - total_pool (numeric) - Updated monthly
  - start_month_year (date) - Used for calculating month numbers
  - created_by (UUID, references users.id) - The admin/creator
  - created_at (timestamp)
  - updated_at (timestamp)

#### 4. group_join_requests
- Tracks group join requests
- Used for admin approval of members
- Key fields:
  - id (UUID)
  - user_id (UUID, references users.id)
  - group_id (UUID, references groups.id)
  - status (text) - 'pending', 'approved', 'rejected'
  - requested_at (timestamp)
  - responded_at (timestamp)
  - responded_by (UUID, references users.id)

### Dynamic Tables (Per Group)

When a group is created, three tables are automatically created for that group:

#### 1. group_{id}_matrix
- Contribution matrix
- Structure with months as rows and members as columns
- Key fields:
  - month_number (integer) - 1, 2, 3, etc. from group creation
  - month_year (date) - Actual month/year date
  - total_contributions (numeric) - Sum of all contributions that month
  - total_withdrawals (numeric) - Sum of all withdrawals that month
  - lottery_winner_id (UUID, nullable) - Only for lottery groups
  - member_{user_id} (text) - One column per member with format:
    - Normal contribution: "+500"
    - Contribution with payback: "+500+200"
    - Contribution with withdrawal: "+500-1000" 

#### 2. group_{id}_metadata
- Additional information about the group
- Key fields:
  - current_month_number (integer)
  - active_members_count (integer)
  - last_updated (timestamp)
  - settings (JSONB) - Configurable group settings

#### 3. group_{id}_withdrawals
- Tracks all withdrawal requests and payback plans
- Key fields:
  - id (UUID)
  - user_id (UUID, references users.id)
  - month_number (integer) - When withdrawal was requested
  - amount (numeric)
  - reason (text)
  - status (text) - 'requested', 'approved', 'rejected', 'paid'
  - approved_by (UUID, references users.id)
  - approved_at (timestamp)
  - payback_amount_monthly (numeric)
  - payback_period_months (integer)
  - due_by_date (date)
  - remaining_amount (numeric)
  - created_at (timestamp)
  - updated_at (timestamp)

## Database Functions

### Group Management Functions
- **create_group_tables()** - Trigger function that creates the three dynamic tables when a new group is created
- **add_member_to_matrix()** - Adds a column for a new member to the matrix when they join a group
- **add_next_month_to_matrix()** - Adds the next month to the matrix table for all groups

### User and Request Management Functions
- **approve_admin_request()** - Sets a user as admin when their admin request is approved
- **approve_join_request()** - Adds a user to a group when their join request is approved
- **initialize_first_site_master(email)** - Sets up the first site master by email address

### Financial Functions
- **record_contribution(user_id, amount, withdrawal_amount, payback_amount)** - Records a user's contribution with optional withdrawal and payback amounts
- **select_lottery_winner(group_id)** - Randomly selects a winner for a lottery group

### Utility Functions
- **trigger_set_timestamp()** - Updates the updated_at timestamp when records are modified

## Row Level Security (RLS) Policies

### users Table
- Users can view their own profile
- Users can update their own profile
- Site masters can view all users
- Site masters can update admin status

### admin_requests Table
- Site masters can update and view all admin requests
- Users can create their own admin requests
- Users can see their own admin requests

### groups Table
- Group creators (admins) have full access
- Group members can view the group

### group_join_requests Table
- Group admins can update and view join requests for their group
- Users can create their own join requests
- Users can see their own join requests

### Dynamic Tables
- Each dynamic table will have appropriate RLS policies:
  - Group admins have full access
  - Group members have read access
  - For withdrawals, users can create their own requests

## User Roles and Flow

### 1. Site Master
- Can approve/reject admin requests
- Manages site-wide settings
- Has visibility into all users and groups

### 2. Admin
- Can create one group (becomes the admin of that group)
- Approves/rejects group join requests
- Manages contributions and withdrawals for their group
- Can view all members in their group

### 3. Regular User
- Can join one group
- Makes contributions
- Can request withdrawals
- Tracks paybacks

## Core Workflows

### Admin Approval Process
1. User requests admin status
2. Site master approves/rejects request
3. On approval, user becomes admin and can create a group

### Group Creation Process
1. Admin creates a group
2. System automatically creates three dynamic tables for the group
3. Group is ready to accept members

### Group Join Process
1. User requests to join a group
2. Group admin approves/rejects request
3. On approval, user's group_id is updated and a column is added to the matrix

### Contribution Process
1. User makes monthly contribution
2. Contribution is recorded in matrix
3. Group total pool is updated

### Withdrawal Process
1. User requests withdrawal
2. Admin approves/rejects request
3. On approval, withdrawal is recorded in matrix
4. Payback plan is established and tracked

### Lottery Process (for lottery groups)
1. Monthly contributions recorded
2. At month end, system selects winner
3. Winner receives full pool amount
4. New month begins 