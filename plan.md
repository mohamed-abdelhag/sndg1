# Sandoog Project Plan

## Project Overview

Sandoog is a platform for managing group savings, featuring two types of groups:
1. **Standard Savings Groups**: Members contribute monthly and can request withdrawals with payback plans
2. **Lottery Groups**: Members contribute monthly and one winner gets the full pot each month

## User Hierarchy

### 1. Site Master
- **Role**: Platform administrator
- **Permissions**:
  - Approve/reject admin requests
  - View all users and groups
  - Manage site settings

### 2. Admin
- **Role**: Group creator/manager
- **Permissions**:
  - Create and manage one group
  - Approve/reject group join requests
  - Approve/reject withdrawal requests
  - View all contributions and withdrawals

### 3. Regular User
- **Role**: Group member
- **Permissions**:
  - Join one group
  - Make monthly contributions
  - Request withdrawals
  - Track personal payback obligations

## Database Structure

### Core Tables
1. **users** - Extended auth.users with roles and profile info
2. **admin_requests** - Tracks admin role requests
3. **groups** - Main group information
4. **group_join_requests** - Tracks group join requests

### Dynamic Tables (Per Group)
Each group gets three automatically created tables:
1. **group_{id}_matrix** - Contribution tracking with members as columns, months as rows
2. **group_{id}_metadata** - Group settings and status information
3. **group_{id}_withdrawals** - Detailed withdrawal and payback tracking

## Core User Flows

### Site Master Flow
1. Login → Site Master Dashboard
2. View and manage admin requests
3. Monitor platform usage statistics

### Admin Flow
1. Regular user requests admin status
2. Site master approves request
3. New admin creates a group
4. Admin approves/rejects member join requests
5. Admin manages group contributions and withdrawals

### Regular User Flow
1. Signup/Login
2. Join existing group (requires admin approval)
3. Make monthly contributions
4. Request withdrawals when needed
5. Track and make paybacks for withdrawals

## Technical Implementation

### Frontend Components

#### Authentication Components
- LoginForm
- SignupForm
- AdminRequestForm

#### Site Master Components
- AdminRequestsList
- AdminApprovalInterface

#### Admin Components
- GroupCreationForm
- MemberRequestsList
- WithdrawalApprovalInterface
- GroupSettingsForm

#### User Components
- GroupJoinForm
- ContributionForm
- WithdrawalRequestForm
- PaybackTracker

#### Shared Components
- ContributionMatrix - Shows monthly contributions and withdrawals
- GroupDashboard - Group overview and statistics

### Route Structure
- `/` - Landing page
- `/auth` - Authentication routes (login, signup)
- `/dashboard` - User dashboard (redirects based on role)
- `/sitemaster` - Site master dashboard
- `/admin` - Admin dashboard
- `/groups/{id}` - Group details
- `/groups/{id}/contributions` - Contribution management
- `/groups/{id}/withdrawals` - Withdrawal management
- `/groups/{id}/members` - Member management

### Database Operations
- User authentication (Supabase Auth)
- Role-based access control via RLS
- Dynamic table creation for new groups
- Monthly contribution recording
- Withdrawal request and approval workflow
- Payback tracking and calculation

## Project Phases

### Phase 1: Core Structure
- Setup Supabase project
- Implement authentication system
- Create core database tables
- Build basic UI components

### Phase 2: Role Management
- Implement site master dashboard
- Create admin request workflow
- Build admin approval interface
- Setup role-based redirects

### Phase 3: Group Management
- Implement group creation for admins
- Create dynamic table generation
- Build group join workflow
- Develop member management interface

### Phase 4: Financial Features
- Build contribution matrix
- Implement withdrawal request system
- Create payback tracking
- Develop lottery selection for lottery groups

### Phase 5: Polish and Launch
- Implement reporting and statistics
- Performance optimization
- Thorough testing and bug fixes

## Development Guidelines

### UI/UX Standards
- Clean, modern interface
- Responsive design for all devices
- Clear visualization of financial data
- Intuitive navigation between related screens

### Security Measures
- Row-level security for all tables
- Role-based access control
- Secure authentication via Supabase
- Data validation on both client and server

### Testing Strategy
- Unit tests for core functions
- Integration tests for workflows
- End-to-end tests for user journeys
- Security testing for access controls

## Setup Instructions

### Environment Setup
```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
```

### Database Initialization
1. Create a new Supabase project
2. Set up authentication providers
3. Create the core tables
4. Configure RLS policies
5. Create initial site master user 