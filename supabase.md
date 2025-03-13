# Supabase Configuration and Changes

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

