# Sandoog User Flows

This document outlines the key user flows for each user type in the Sandoog platform.

## Authentication Flows

### Files: `src/routes/auth/*`

1. **Login Flow**
   - `src/routes/auth/login/+page.svelte`
   - User enters email and password
   - Authentication with Supabase
   - Redirect based on user role

2. **Signup Flow**
   - `src/routes/auth/signup/+page.svelte`
   - User enters email, password, and name
   - Account creation with Supabase
   - Email verification

3. **Admin Request Flow**
   - `src/routes/auth/admin-request/+page.svelte`
   - Regular user requests admin status
   - Request stored in `admin_requests` table
   - Site master approval required

4. **Password Reset Flow**
   - `src/routes/auth/forgot-password/+page.svelte`
   - `src/routes/auth/update-password/+page.svelte`
   - Email-based password reset

## Site Master Flows

### Files: `src/routes/sitemaster/*`

1. **Admin Approval Flow**
   - `src/routes/sitemaster/admin-approvals/+page.svelte`
   - View pending admin requests
   - Approve/reject admin requests
   - Set user as admin in database

2. **Platform Monitoring Flow**
   - `src/routes/sitemaster/+page.svelte`
   - View platform statistics
   - Monitor all groups
   - Access user management

## Admin Flows

### Files: `src/routes/admin/*` and `src/routes/groups/*`

1. **Group Creation Flow**
   - `src/routes/admin/create-group/+page.svelte`
   - Set group name, description, type
   - Configure monthly contribution amount
   - Create dynamic tables for the group

2. **Member Approval Flow**
   - `src/routes/groups/[groupId]/members/requests/+page.svelte`
   - View pending member join requests
   - Approve/reject member requests
   - Add members to group matrix

3. **Withdrawal Approval Flow**
   - `src/routes/groups/[groupId]/withdrawals/approvals/+page.svelte`
   - View pending withdrawal requests
   - Approve/reject withdrawals
   - Set payback plans

4. **Group Management Flow**
   - `src/routes/groups/[groupId]/settings/+page.svelte`
   - Configure group settings
   - View member list
   - Monitor contribution matrix

## Regular User Flows

### Files: `src/routes/groups/*`

1. **Group Join Flow**
   - `src/routes/groups/join/+page.svelte`
   - Browse available groups
   - Request to join group
   - Wait for admin approval

2. **Contribution Flow**
   - `src/routes/groups/[groupId]/contribute/+page.svelte`
   - Make monthly contributions
   - View contribution history
   - See group total pool

3. **Withdrawal Request Flow**
   - `src/routes/groups/[groupId]/withdrawals/request/+page.svelte`
   - Request withdrawal amount
   - Provide reason for withdrawal
   - View status of request

4. **Payback Tracking Flow**
   - `src/routes/groups/[groupId]/paybacks/+page.svelte`
   - View payback obligations
   - Track remaining amount
   - Make payback contributions

## Routing and Navigation

The application uses role-based navigation to direct users to appropriate screens:

1. Landing page (`src/routes/+page.svelte`) redirects based on user role:
   - Site Master → `/sitemaster`
   - Admin → `/admin` or `/groups/{groupId}` if group exists
   - Regular User → `/groups/{groupId}` if member of a group

2. Authentication middleware (`src/lib/auth/middleware.ts`) enforces access control:
   - `requireAuth()` - Ensures user is authenticated
   - `requireSiteMaster()` - Ensures user is a site master
   - `requireAdmin()` - Ensures user is an admin
   - `requireGroupMember()` - Ensures user belongs to specific group

## Database Interactions

Each flow interacts with specific database tables:

1. Authentication flows → `users` and `admin_requests` tables
2. Site Master flows → `admin_requests` and user role management
3. Admin flows → `groups`, `group_join_requests`, and dynamic tables
4. Regular User flows → Group membership and financial transactions

The application ensures appropriate database permissions through Supabase Row Level Security policies as defined in `supabase.md`. 