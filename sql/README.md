# SQL Scripts for Sandoog

This directory contains SQL scripts for setting up and fixing the Sandoog database.

## Admin Requests Fix

If you're having issues with the admin requests functionality, run the `fix_admin_requests.sql` script.

### How to Run the SQL Script

1. **Open Supabase SQL Editor**:
   - Go to your Supabase project dashboard
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

2. **Paste the Script**:
   - Copy the entire contents of `fix_admin_requests.sql`
   - Paste it into the SQL Editor

3. **Run the Script**:
   - Click the "Run" button
   - Wait for the script to complete
   - You should see a success message at the bottom

4. **Refresh the App**:
   - Hard refresh your app (Ctrl+Shift+R or Cmd+Shift+R)
   - Wait about 30 seconds for Supabase to update its schema cache
   - Login again to test the site master dashboard

## Troubleshooting

If you're still having issues after running the script:

1. **Check for Errors**:
   - Look for any error messages in the SQL Editor
   - Check the browser console for errors

2. **Manual Verification**:
   - Run this SQL to check if the table exists:
     ```sql
     SELECT * FROM information_schema.tables 
     WHERE table_schema = 'public' 
     AND table_name = 'admin_requests';
     ```

3. **Test with a Sample Request**:
   - Run this SQL to insert a test request:
     ```sql
     INSERT INTO public.admin_requests (
       user_id, 
       reason, 
       status
     ) VALUES (
       (SELECT id FROM auth.users LIMIT 1),
       'Test request', 
       'pending'
     );
     ```
   
4. **Verify Permissions**:
   - Run this SQL to check RLS policies:
     ```sql
     SELECT * FROM pg_policies 
     WHERE tablename = 'admin_requests';
     ```

## Other Scripts

- `create.sql` - Initial database setup
- `role_management.sql` - User role management functions 