# Sandoog Project Implementation Summary

## Overview of Changes

Based on the requirements, I've updated the project plan and created SQL schema additions to implement the new user flow and role management system. The core changes revolve around:

1. Creating a three-tiered user system:
   - Site Master (supreme admin - just you)
   - Group Admins (can create/manage groups)
   - Regular Users (can join one group only)

2. Implementing group management workflow:
   - Users request admin status, approved by Site Master
   - Admins create groups and get group IDs
   - Admins share group IDs via external means (WhatsApp, etc.)
   - Other users use group IDs to find and request to join groups
   - Group admins approve member requests

3. Enforcing one-group-per-user limitation:
   - Users can only be in one group at a time
   - Once in a group, users can't request to join another
   - Admin requests are only possible for users not in a group

## Plan Changes Summary

1. **Added New User Flows**:
   - Admin User Flow
   - Group Member User Flow
   - New User Flow

2. **Added New Components**:
   - Admin request form and management components
   - Group join request components
   - Site master administration components
   - Group ID sharing functionality

3. **Added New Routes**:
   - Admin request page
   - Admin dashboard routes
   - Site master dashboard routes
   - Group join routes

4. **Added New Database Models**:
   - Admin Requests Table
   - Auth Users Extensions
   - Group Join Requests Table

5. **Added New API Endpoints**:
   - Admin request endpoints
   - Site master approval endpoints
   - Group join request endpoints

## Database Schema Additions

### 1. Auth User Extensions

Added columns to the `auth.users` table:
- `is_admin` (BOOLEAN) - Indicates if user has admin privileges
- `is_site_master` (BOOLEAN) - Indicates if user is the site master
- `group_id` (UUID) - Reference to user's group (enforces one group per user)

### 2. Admin Requests Table

Created a table to track admin role requests:
```sql
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
```

### 3. Group Join Requests Table

Created a table to track requests to join groups:
```sql
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
```

### 4. Key Functions Added

1. **Admin Request Functions**:
   - `check_admin_request_eligibility` - Ensures users can only request admin if eligible
   - `approve_admin_request` - For site master to approve admin requests
   - `reject_admin_request` - For site master to reject admin requests

2. **Group Management Functions**:
   - `create_group_and_update_creator` - Creates group and updates admin's status
   - `approve_join_request` - For admins to approve group join requests
   - `reject_join_request` - For admins to reject group join requests

### 5. Row-Level Security Policies

Added policies to ensure:
- Users can only see their own requests
- Site master can see and manage all admin requests
- Group admins can only see and manage requests for their own groups
- Users can only create requests if eligible (not in a group already)

## Next Steps for Implementation

1. **Frontend Development**:
   - Create the three main screen flows (admin, user-in-group, user-with-no-group)
   - Implement admin request form and approval process
   - Build group ID sharing functionality
   - Create group join request workflow

2. **Backend Implementation**:
   - Execute the SQL scripts to create the new tables and functions
   - Implement the API endpoints for the new functionality
   - Create server-side validation for all request types

3. **Testing Scenarios**:
   - Test admin request and approval flow
   - Test group creation by admins
   - Test group joining by regular users
   - Verify one-group-per-user restriction
   - Test site master functionality

4. **Security Considerations**:
   - Ensure proper RLS policies are in place
   - Add client-side validation to prevent unauthorized actions
   - Implement proper error handling for all workflows 