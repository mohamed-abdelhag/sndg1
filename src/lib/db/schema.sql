-- Admin requests table
CREATE TABLE IF NOT EXISTS admin_requests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id)
);

-- Function to check if a user is eligible to request admin status
CREATE OR REPLACE FUNCTION check_admin_request_eligibility(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_eligible BOOLEAN;
BEGIN
  SELECT 
    NOT EXISTS (
      SELECT 1 FROM users WHERE id = user_id AND (is_admin = true OR is_site_master = true)
    ) 
    AND NOT EXISTS (
      SELECT 1 FROM users WHERE id = user_id AND group_id IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM admin_requests 
      WHERE user_id = user_id 
      AND status = 'pending'
    )
  INTO is_eligible;
  
  RETURN is_eligible;
END;
$$; 