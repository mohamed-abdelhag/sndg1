# Sandoog

Sandoog is a group savings management application built with SvelteKit. It allows users to create groups, manage members, set savings goals, track contributions, and handle withdrawal requests. The application supports two types of savings groups to accommodate different saving styles.

## Features

### User Authentication
* User Login
* User Sign Up

### Group Management
* Create groups with an administrator
* Two types of groups:
    * **Standard Savings Groups:** Members contribute monthly towards a goal with withdrawal options
    * **Lump Sum Lottery Groups:** Members contribute monthly, and one randomly selected member receives the entire pool each month until all members have won once
* Add and remove group members
* Set monthly savings goals (for Standard Savings Groups)

### Savings Tracking
* Users can mark their monthly contributions
* Track overall group savings progress
* Monitor contribution deficits (shows how much each user is behind, e.g., "X dirhams behind")
* Monthly contribution status tracking

### Standard Savings Groups Features
* Track progress towards group savings goal
* Members can request withdrawals from the pool
* Administrators can approve/reject withdrawal requests
* Set payback rates (interest-free) for withdrawals
* Payback amounts are added to monthly dues

### Lump Sum Lottery Groups Features
* Equal monthly contributions from all members
* Automated random selection of winner at month-end
* Fair distribution system (each member wins exactly once)
* Tracking of previous winners and remaining eligible members
* Contribution deficit tracking affects eligibility

## Technologies Used

* SvelteKit
* Prisma (Database ORM)
* PostgreSQL (Database)
* TypeScript
* Lucia (Authentication)
* TailwindCSS (Styling)

## Getting Started

```bash
# Clone the repository
git clone [repository-url]

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env

# Start development server
npm run dev
```

## Environment Setup

Create a `.env` file with the following variables:

```env
DATABASE_URL="postgresql://..."
AUTH_SECRET="your-secret-key"
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Email Confirmation and Magic Link Setup

To enable email confirmation and magic link functionality in the Supabase project, follow these steps:

### 1. Configure Supabase Auth Settings

1. Go to your Supabase project dashboard.
2. Navigate to **Authentication** > **Providers** > **Email**.
3. Enable the following options:
   - **Confirm email**: Enable to require email confirmation.
   - **Secure email change**: Enable to require confirmation for email changes.
   - **Enable magic link login**: Enable to allow login through a one-time link sent via email.

### 2. Configure Supabase Auth Redirect URLs

1. Go to your Supabase project dashboard.
2. Navigate to **Authentication** > **URL Configuration**.
3. Add the following URLs to the **Redirect URLs** list:
   - `http://localhost:5000/auth/confirm-email` (for local development)
   - `https://yourdomain.com/auth/confirm-email` (for production)

### 3. Configure Email Templates

1. Go to your Supabase project dashboard.
2. Navigate to **Authentication** > **Email Templates**.
3. Edit the following templates:
   - **Confirm signup**: This is the email sent for account confirmation.
   - **Magic link**: This is the email sent for passwordless login.

### 4. Customize the Confirmation Email Template

Here's a sample template for the confirmation email:

**Subject:**
```
Confirm your Sandoog account
```

**Content:**
```html
<h2>Confirm Your Sandoog Account</h2>
<p>Follow this link to confirm your account:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm Account</a></p>
<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
<p>If you didn't create this account, you can safely ignore this email.</p>
```

### 5. Customize the Magic Link Email Template

Here's a sample template for the magic link email:

**Subject:**
```
Your Sandoog Magic Link
```

**Content:**
```html
<h2>Login to Sandoog</h2>
<p>Follow this link to log in to your Sandoog account:</p>
<p><a href="{{ .SiteURL }}/auth/callback?token={{ .Token }}&type=magiclink">Login to Sandoog</a></p>
<p>Or copy and paste this URL into your browser:</p>
<p>{{ .SiteURL }}/auth/callback?token={{ .Token }}&type=magiclink</p>
<p>This link will expire in 1 hour and can only be used once.</p>
<p>If you didn't request this email, you can safely ignore it.</p>
```

### Important Notes

1. Make sure your application's domain is properly configured in the Supabase project.
2. For local development, you may need to use a service like ngrok to test email flows.
3. Email templates support HTML and basic CSS for styling.
4. The `{{ .ConfirmationURL }}` and `{{ .SiteURL }}` variables are automatically populated by Supabase.

## Database Setup for User Profiles

The application requires a `users` table with the following structure:

```sql
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    is_admin BOOLEAN DEFAULT false,
    is_site_master BOOLEAN DEFAULT false,
    group_id UUID REFERENCES public.groups(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Set up RLS policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy for users to read their own data
CREATE POLICY "Users can read their own data" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- Policy for users to update their own data
CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Site masters can read and update all user data
CREATE POLICY "Site masters can read all users" ON public.users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_site_master = true
        )
    );

CREATE POLICY "Site masters can update all users" ON public.users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_site_master = true
        )
    );
```

## Add RPC Function to Count Users

For the site master dashboard to show the correct user count:

```sql
CREATE OR REPLACE FUNCTION get_total_users_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER -- Run with function owner's privileges
AS $$
DECLARE
  users_count integer;
BEGIN
  -- Count users in the auth.users table
  SELECT COUNT(*) INTO users_count FROM auth.users;
  RETURN users_count;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_total_users_count() TO authenticated;
```

## Add RPC Function for Handling Admin Requests with Table Creation

Create this RPC function in Supabase SQL Editor to handle admin requests even if the table doesn't exist yet:

```sql
-- Function to ensure admin_requests table exists and insert a request
CREATE OR REPLACE FUNCTION ensure_admin_request(p_user_id UUID, p_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Run with function owner's privileges
AS $$
BEGIN
  -- Create the admin_requests table if it doesn't exist
  BEGIN
    CREATE TABLE IF NOT EXISTS public.admin_requests (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES auth.users(id),
      reason TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      responded_at TIMESTAMP WITH TIME ZONE,
      responded_by UUID REFERENCES auth.users(id),
      updated_at TIMESTAMP WITH TIME ZONE
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error creating table: %', SQLERRM;
  END;
  
  -- Add RLS if it's a new table
  BEGIN
    -- Check if RLS is enabled
    IF NOT EXISTS (
      SELECT 1 FROM pg_tables 
      WHERE tablename = 'admin_requests' 
      AND rowsecurity = true
    ) THEN
      -- Enable RLS
      ALTER TABLE public.admin_requests ENABLE ROW LEVEL SECURITY;
      
      -- Policy for site masters to read all requests
      CREATE POLICY "Site masters can view all admin requests" ON public.admin_requests
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_site_master = true
          )
        );
      
      -- Policy for site masters to update requests
      CREATE POLICY "Site masters can update admin requests" ON public.admin_requests
        FOR UPDATE USING (
          EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_site_master = true
          )
        );
      
      -- Policy for users to insert their own requests
      CREATE POLICY "Users can create their own admin requests" ON public.admin_requests
        FOR INSERT WITH CHECK (
          auth.uid() = user_id
        );
      
      -- Policy for users to view their own requests
      CREATE POLICY "Users can view their own admin requests" ON public.admin_requests
        FOR SELECT USING (
          auth.uid() = user_id
        );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error setting up RLS: %', SQLERRM;
  END;
  
  -- Insert the admin request
  BEGIN
    INSERT INTO public.admin_requests (user_id, reason)
    VALUES (p_user_id, p_reason);
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to insert admin request: %', SQLERRM;
  END;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION ensure_admin_request(UUID, TEXT) TO authenticated;
```

This function:
1. Creates the admin_requests table if it doesn't exist
2. Sets up appropriate Row Level Security policies
3. Inserts the new admin request
4. Can be called by any authenticated user

## Troubleshooting 500 Errors with Supabase Tables

If you encounter 500 errors when trying to access tables:

1. Check if the table exists in Supabase:
   - Go to the Supabase Dashboard
   - Navigate to the Table Editor
   - Look for the table in the list

2. If the table doesn't exist, you can:
   - Run the SQL scripts provided in this README
   - Use the `ensure_admin_request` RPC function which handles this automatically

3. Check RLS (Row Level Security) policies:
   - Ensure users have appropriate permissions to read/write to the tables
   - The provided SQL scripts include RLS policies
