# Sandoog Project Plan

## Project Structure

### Root Directory
```
/
├── src/
├── static/
├── tests/
├── supabase.md
└── package.json
```

## Core Components

### Authentication (`/src/lib/auth/`)
- `supabase.ts` - Supabase client and auth configuration
- `utils.ts` - Authentication helper functions
- `middleware.ts` - Authentication middleware

### Database (`/src/lib/db/`)
- `supabase-types.ts` - Generated Supabase types
- `schema.ts` - Database schema type definitions
- `queries.ts` - Reusable database queries

### Components (`/src/lib/components/`)
- `auth/`
  - `LoginForm.svelte` - User login form
  - `SignupForm.svelte` - User registration form
  - `AdminRequestForm.svelte` - Form to request admin status
- `admin/`
  - `AdminDashboard.svelte` - Admin dashboard component
  - `GroupManagement.svelte` - Group administration interface
  - `MemberRequests.svelte` - Membership request management
  - `ShareGroup.svelte` - Group sharing interface component
- `sitemaster/`
  - `AdminApproval.svelte` - Site master's admin request approval interface
- `groups/`
  - `GroupCard.svelte` - Group display component
  - `CreateGroup.svelte` - Group creation form
  - `JoinGroup.svelte` - Group join request form
  - `MemberList.svelte` - Group members management
  - `ContributionMatrix.svelte` - Monthly contribution matrix
  - `WithdrawalForm.svelte` - Withdrawal request form
  - `WithdrawalApproval.svelte` - Admin approval interface
  - `PaybackTracker.svelte` - Payback tracking component
- `common/`
  - `Button.svelte` - Reusable button component
  - `Modal.svelte` - Modal dialog component
  - `Notification.svelte` - Toast notifications
  - `Loading.svelte` - Loading states

### Routes (`/src/routes/`)
- `+layout.svelte` - Main layout template
- `+page.svelte` - Landing page
- `/auth/`
  - `login/+page.svelte` - Login page
  - `signup/+page.svelte` - Signup page
  - `admin-request/+page.svelte` - Admin request page
- `/admin/`
  - `+page.svelte` - Admin dashboard
  - `[id]/members/+page.svelte` - Member management
  - `[id]/share/+page.svelte` - Group ID sharing
- `/sitemaster/`
  - `+page.svelte` - Site master dashboard
  - `admin-approvals/+page.svelte` - Admin approval interface
- `/groups/`
  - `+page.svelte` - Groups overview
  - `[id]/+page.svelte` - Individual group view
  - `new/+page.svelte` - Create new group
  - `join/+page.svelte` - Join existing group by ID
  - `[id]/contributions/+page.svelte` - Contribution tracking
  - `[id]/withdrawals/+page.svelte` - Withdrawal management
  - `[id]/paybacks/+page.svelte` - Payback management
  - `[id]/settings/+page.svelte` - Group settings (admin only)
- `/api/` - Backend API routes

## User Flow

### Three Main User Types and Flows

#### 1. Site Master
**Site Master Flow:**
1. Login → `/auth/login`
2. Redirect to → `/sitemaster`
3. View admin requests → `/sitemaster/admin-approvals`
4. Approve/reject admin requests
5. Manage site-wide settings

**Screens in Path:**
- Login Screen
- Site Master Dashboard (shows pending admin requests, user counts, group counts)
- Admin Approval Screen (lists all admin requests with ability to filter by status)

#### 2. Admin User
**Admin User Flow (New Admin):**
1. Login → `/auth/login`
2. If not admin yet: Request admin → `/auth/admin-request`
3. Wait for approval from site master
4. Once approved: Create group → `/groups/new`
5. Share group ID with potential members
6. Manage group → `/groups/[groupId]`
7. Approve membership requests → `/groups/[groupId]/members`
8. Track contributions → `/groups/[groupId]/contributions`
9. Approve withdrawals → `/groups/[groupId]/withdrawals`

**Admin User Flow (Existing Admin):**
1. Login → `/auth/login`
2. Redirect to → `/groups/[groupId]` (their group dashboard)
3. Manage group, members, contributions, withdrawals

**Screens in Path:**
- Login Screen
- Admin Request Screen (for new admins)
- Group Creation Screen
- Group Dashboard (shows overview, members, contribution matrix)
- Member Management Screen (approve/reject join requests, manage members)
- Contribution Matrix Screen (track all member contributions)
- Withdrawal Management Screen (approve/reject withdrawal requests)

#### 3. Regular User
**New User Flow (No Group):**
1. Signup → `/auth/signup`
2. Login → `/auth/login`
3. Choose between:
   - Join existing group with ID → `/groups/join`
   - Request admin status → `/auth/admin-request`
4. If joining group:
   - Submit join request with group ID
   - Wait for admin approval
   - Once approved: Access group → `/groups/[groupId]`

**Existing User Flow (In Group):**
1. Login → `/auth/login`
2. Redirect to → `/groups/[groupId]` (their group dashboard)
3. Make contributions → `/groups/[groupId]/contributions`
4. Request withdrawals → `/groups/[groupId]/withdrawals`
5. Track paybacks → `/groups/[groupId]/paybacks`

**Screens in Path:**
- Signup Screen
- Login Screen
- Group Join Screen (enter group ID)
- Group Dashboard (view-only for non-admin members)
- Contribution Screen (make monthly contributions)
- Withdrawal Request Screen (request money from the pool)
- Payback Tracking Screen (track outstanding obligations)

### Login Redirect Logic
Based on user type, the system will automatically redirect after login:

```
Login
↓
Check user status
↓
If site master → `/sitemaster`
↓
If admin with group → `/groups/[groupId]`
↓
If user with group → `/groups/[groupId]`
↓
If user without group → `/groups/join` with option to request admin
```

### User Status Matrix
| User Type | Has Group | Admin Status | Site Master | Initial Redirect |
|-----------|-----------|--------------|-------------|------------------|
| Site Master | N/A | Yes | Yes | `/sitemaster` |
| Admin | Yes | Yes | No | `/groups/[groupId]` |
| Regular (in group) | Yes | No | No | `/groups/[groupId]` |
| Regular (no group) | No | No | No | `/groups/join` |
| Admin (pending) | No | No (requested) | No | `/auth/admin-request` |

## Features Implementation

#### User Authentication and Role Management
- Uses Supabase Auth
- Email/password authentication
- Session management
- Password reset functionality
- Admin status request and approval flow
- One group per user limitation

#### Admin Management
- Site master interface for approving admin requests
- Admin dashboard for group management
- Group ID sharing functionality
- Membership request approval interface
- Group configuration options

#### Group Membership
- Group join request system
- Group ID-based group discovery
- Member status tracking
- Single group per user limitation

#### Group Management
1. Standard Savings Groups
   - Monthly contribution tracking in matrix format
   - Contribution and payback combined in cells (+contribution+payback)
   - Withdrawal requests with payback plan
   - Admin approval workflow

2. Lump Sum Lottery Groups
   - Monthly contribution tracking in matrix format
   - Monthly winner selection (visible as withdrawal in matrix)
   - Full pool withdrawal for winner
   - Winner history tracking

#### Financial Tracking
- Contribution matrix (users as columns, months as rows)
- Month numbering from group creation (1, 2, 3...)
- Total pool tracking in main group table
- Cell format: +contribution+payback or +contribution-withdrawal
- Separate withdrawal tracking with payback plans

## Database Integration

### Supabase Setup
- Authentication using Supabase Auth
- Database tables using Supabase PostgreSQL
- Table creation and management
- Security policies implementation

### Data Models

#### 1. Admin Requests Table
- Tracks admin role requests:
  - Request ID
  - User ID
  - Request reason
  - Status (pending, approved, rejected)
  - Request date
  - Approval date
  - Approved by (site master ID)
- Visibility:
  - User can see own requests
  - Site master can see all requests

#### 2. Auth Users Extensions
- Add additional fields to auth.users table:
  - is_admin (boolean)
  - group_id (UUID, nullable) - reference to the user's group
  - is_site_master (boolean)
- Visibility:
  - Users can see their own status
  - Site master can see all user statuses

#### 3. Group Join Requests Table
- Tracks requests to join groups:
  - Request ID
  - User ID
  - Group ID
  - Status (pending, approved, rejected)
  - Request date
  - Response date
  - Response by (admin ID)
- Visibility:
  - Users can see their own requests
  - Group admins can see requests for their group

#### 4. Groups (main table)
- Core group information:
  - Name and description
  - Type (standard/lottery)
  - Monthly contribution amount
  - Total pool amount (updated monthly)
  - Start month/year (for calculating month numbers)
  - Created by (group admin)
  - Members list (array of user IDs)
- Visibility:
  - Group details visible to all members
  - Only creator (admin) can edit group settings

#### 5. Group Contribution Matrix
- Dynamic creation (one table per group)
- Matrix structure:
  - Rows represent months (numbered 1, 2, 3... from start date)
  - Columns represent members
  - Each cell contains contribution and payback: "+x+z" or "+x-y"
- Example format:
  - Normal contribution: "+500"
  - Contribution with payback: "+500+200"
  - Contribution with withdrawal: "+500-1000"
  - Lottery winner: "+500-5000"
- Month tracked by row number rather than actual date
- Total contributions for group updated in main group table

#### 6. Group Withdrawal Table
- Dynamic creation (one table per group)
- Tracks all withdrawal requests:
  - Request ID
  - User ID
  - Amount
  - Reason
  - Status (requested, approved, withdrawn, paid)
  - Payback plan (monthly amount)
  - Payback period (number of months)
  - Due by date
  - Remaining amount
- Tracks payback progress
- Links to matrix cells for display

#### 7. Monthly Processes
- Beginning of month:
  - Create new row in contribution matrix
  - Initialize with zero values
- During month:
  - Members record their contributions
  - Contributions include payback amounts if applicable
- End of month:
  - For lottery groups: select winner
  - Update total pool amount in main group table
  - Check payback statuses and update

#### 8. Withdrawal and Payback Process
- Member submits withdrawal request with:
  - Amount
  - Reason
  - Proposed payback period (for standard groups)
- Admin (creator) approves/rejects request
- On approval:
  - Record withdrawal in matrix (-y in cell)
  - Calculate monthly payback amount
  - Set due date
  - Track payback in monthly cells (+z)
- Payback completion:
  - Mark withdrawal as "paid" when completed
  - Update user's history

## API Endpoints

### Authentication
- POST /api/auth/login
- POST /api/auth/signup
- POST /api/auth/logout
- POST /api/auth/reset-password
- POST /api/auth/admin-request

### Site Master
- GET /api/sitemaster/admin-requests
- PUT /api/sitemaster/admin-requests/[id]

### Admin Management
- GET /api/admin/status
- GET /api/admin/group

### Groups
- GET /api/groups
- POST /api/groups
- GET /api/groups/[id]
- PUT /api/groups/[id]
- GET /api/groups/join/[id]
- POST /api/groups/join-requests
- GET /api/groups/[id]/join-requests
- PUT /api/groups/[id]/join-requests/[requestId]
- GET /api/groups/[id]/members
- DELETE /api/groups/[id]/members/[userId]

### Contributions
- GET /api/groups/[id]/contributions
- POST /api/groups/[id]/contributions
- PUT /api/groups/[id]/contributions/[month]/[userId]

### Withdrawals
- GET /api/groups/[id]/withdrawals
- POST /api/groups/[id]/withdrawals
- PUT /api/groups/[id]/withdrawals/[id]
- POST /api/groups/[id]/withdrawals/[id]/approve
- POST /api/groups/[id]/withdrawals/[id]/reject

### Paybacks
- GET /api/groups/[id]/paybacks
- PUT /api/groups/[id]/paybacks/[withdrawalId]

## UI/UX Guidelines

### Color Scheme
- Primary: #4F46E5 (Indigo)
- Secondary: #10B981 (Emerald)
- Accent: #F59E0B (Amber)
- Background: #F9FAFB
- Text: #111827

### Typography
- Headings: Inter
- Body: Inter
- Monospace: JetBrains Mono

### Components Style
- Modern, clean interface
- Consistent padding and spacing
- Responsive design
- Accessible color contrast
- Clear visual hierarchy

## Development Workflow

1. Setup Development Environment
   - Install dependencies
   - Configure Supabase environment variables
   - Setup Supabase project
   - Generate types using Supabase CLI

2. Implementation Order
   - Authentication system and role management
   - Site master interface
   - Admin request workflow
   - Group creation and join request system
   - Member management
   - Basic UI components
   - Group management
   - Contribution matrix
   - Withdrawal system with payback tracking
   - Lottery selection
   - Reporting and statistics
   - Testing and optimization

3. Testing Strategy
   - Unit tests for utilities
   - Integration tests for API
   - E2E tests for critical flows
   - Performance testing

4. Deployment
   - CI/CD pipeline setup
   - Production environment config
   - Monitoring and logging
   - Backup strategy 

## Supabase Configuration
Database tables and server-side functions are defined in a separate `supabase.md` file containing:
- Table definitions
- RPC functions
- Triggers
- Row-level security policies
- Database indexes
- Foreign key relationships 