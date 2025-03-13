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

### Three Main User Flows

1. **Admin User Flow**
   - User requests admin status
   - Site master approves admin request
   - Admin creates a group
   - Admin shares group ID with potential members
   - Admin reviews and approves membership requests
   - Admin manages group settings and approves withdrawals

2. **Group Member User Flow**
   - User logs in
   - User requests to join a group using group ID
   - Once approved, user accesses group dashboard
   - User makes contributions and withdrawal requests
   - User tracks their payback obligations

3. **New User Flow**
   - User signs up and logs in
   - User has two options:
     - Request to join an existing group (with group ID)
     - Request admin status to create a new group

### Features Implementation

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

### Key Screens

#### Login Redirect Logic
- After login, route user based on status:
  - If site master: route to site master dashboard
  - If admin with group: route to admin dashboard
  - If user with group: route to group dashboard
  - If user without group: route to group join/admin request page

#### Site Master Dashboard
- List of pending admin requests
- User management interface
- System statistics and overview
- Limited to authorized site master only

#### Admin Request Screen
- Form to request admin status
- Request status tracking
- Only available to users not already in a group

#### Admin Dashboard
- Group management interface
- Member request approval section
- Group ID sharing with copy functionality
- Group settings management
- Financial overview and statistics

#### Group Join Screen
- Input for group ID
- Submit join request
- Request status tracking
- Only available to users not already in a group

#### Group Dashboard
- Group summary information
- Contribution matrix view (members vs months)
- Pool total and monthly contribution amount
- Withdrawal history
- Member list with contribution status
- Month numbering (1, 2, 3...) rather than calendar dates
- Color coding for different cell states

#### Contribution Screen
- Current month highlighted
- Simple form to submit contribution
- Shows payback obligations
- Combines contribution and payback in one submission
- Shows history of previous months

#### Withdrawal Screen
- Withdrawal request form
- Payback plan selection
  - Monthly amount
  - Duration
  - Due date calculator
- Terms acceptance
- Status tracking

#### Withdrawal Approval (Admin)
- List of pending withdrawal requests
- Request details with amounts
- Payback plan review
- Approve/reject buttons
- History of past requests

#### Payback Tracking
- Outstanding payback amounts
- Progress bars for each withdrawal
- Monthly breakdown
- Payment history
- Due dates and remaining amounts

#### Lottery Winner Screen
- For lottery groups only
- Winner announcement
- Distribution amount
- History of previous winners
- Next drawing countdown

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