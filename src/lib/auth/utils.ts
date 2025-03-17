import { supabase, type UserWithRoles } from './supabase';
import { goto } from '$app/navigation';
import { writable } from 'svelte/store';

// Create a store for the current user
export const currentUser = writable<UserWithRoles | null>(null);

// Login function
export async function loginUser(email: string, password: string) {
  // Special handling for site master - any email with @sandoog.com domain
  if (email.toLowerCase().endsWith('@sandoog.com')) {
    console.log('[Auth] Site master login detected:', email);
    // Try normal login flow first
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    // If login fails using hardcoded admin, fallback for local testing
    if (error && email === 'admin@sandoog.com') {
      currentUser.set({
        id: '00000000-0000-0000-0000-000000000000',
        email: 'admin@sandoog.com',
        first_name: null,
        last_name: null,
        is_admin: true,
        is_site_master: true,
        group_id: null
      });
      
      console.log('[Auth] Using hardcoded site master account');
      // Explicit redirect to site master dashboard
      goto('/sitemaster');
      return { success: true };
    }
    
    if (error) {
      return { success: false, error: error.message };
    }
    
    // Get extended user data and ensure site_master flag is set
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', data.user.id)
      .single();
      
    if (userError || !userData) {
      // Create or update the user data to ensure site_master is true
      await supabase
        .from('users')
        .upsert({
          id: data.user.id,
          email: email,
          is_admin: true,
          is_site_master: true
        }, { onConflict: 'id' });
    } else if (!userData.is_site_master) {
      // Update the user to be a site master
      await supabase
        .from('users')
        .update({ is_site_master: true, is_admin: true })
        .eq('id', data.user.id);
    }
    
    // Set current user as site master
    currentUser.set({
      id: data.user.id,
      email: email,
      first_name: userData?.first_name || null,
      last_name: userData?.last_name || null,
      is_admin: true,
      is_site_master: true,
      group_id: userData?.group_id || null
    });
    
    console.log('[Auth] Site master authenticated, redirecting');
    // Explicit redirect to site master dashboard
    goto('/sitemaster');
    return { success: true };
  }

  // Normal login flow for non-site-master users
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  
  if (error) {
    return { success: false, error: error.message };
  }
  
  // Get extended user data with roles
  const userData = await getUserRoles(data.user.id);
  currentUser.set(userData);
  
  // Redirect based on user role
  redirectBasedOnRole(userData);
  
  return { success: true };
}

// Signup function
export async function signupUser(email: string, password: string) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
  });
  
  if (error) {
    return { success: false, error: error.message };
  }
  
  // New users have no roles by default
  currentUser.set({
    id: data.user!.id,
    email: email,
    first_name: null,
    last_name: null,
    is_admin: false,
    is_site_master: false,
    group_id: null
  });
  
  // Redirect to the landing page
  goto('/');
  
  return { success: true };
}

// Logout function
export async function logoutUser() {
  await supabase.auth.signOut();
  currentUser.set(null);
  goto('/auth/login');
}

// Get user roles from extended auth table
export async function getUserRoles(userId: string): Promise<UserWithRoles> {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, is_admin, is_site_master, group_id')
    .eq('id', userId)
    .single();
  
  if (error || !data) {
    return {
      id: userId,
      email: '',
      first_name: null,
      last_name: null,
      is_admin: false,
      is_site_master: false,
      group_id: null
    };
  }
  
  return data as UserWithRoles;
}

// Redirect user based on role
export function redirectBasedOnRole(user: UserWithRoles | null) {
  if (!user) {
    goto('/auth/login');
    return;
  }
  
  if (user.is_site_master) {
    goto('/sitemaster');
    return;
  }
  
  if (user.is_admin && user.group_id) {
    goto('/admin');
    return;
  }
  
  if (user.group_id) {
    goto(`/groups/${user.group_id}`);
    return;
  }
  
  // User has no role or group - show landing page with options
  goto('/');
}

// Check if user can request admin status
export async function canRequestAdminStatus(userId: string) {
  try {
    console.log('[AdminRequest] Checking eligibility for user ID:', userId);
    
    if (!userId) {
      return { eligible: false, error: 'User ID is required' };
    }
    
    let is500Error = false;
    
    // First check if user already has any admin requests
    let existingRequests = [];
    
    try {
      const { data: requestData, error: requestError } = await supabase
        .from('admin_requests')
        .select('status, requested_at')
        .eq('user_id', userId)
        .order('requested_at', { ascending: false });
      
      if (requestError) {
        if (requestError.code === '500' || requestError.message?.includes('500')) {
          console.log('[AdminRequest] 500 error detected, table might not exist');
          is500Error = true;
          // Continue with other checks if table doesn't exist
        } else if (!requestError.message?.includes('does not exist')) {
          console.error('[AdminRequest] Error checking existing requests:', requestError);
        }
      } else if (requestData) {
        existingRequests = requestData;
        
        // If any active requests exist, the user is not eligible
        if (existingRequests.length > 0) {
          const latestRequest = existingRequests[0];
          
          if (latestRequest.status === 'pending') {
            return { 
              eligible: false, 
              error: `You already have a pending admin request from ${new Date(latestRequest.requested_at).toLocaleDateString()}` 
            };
          }
          
          if (latestRequest.status === 'approved') {
            return { 
              eligible: false, 
              error: 'You already have an approved admin request' 
            };
          }
          
          // If rejected, they can apply again, continue with checks
        }
      }
    } catch (err) {
      console.warn('[AdminRequest] Error checking admin requests, continuing:', err);
      // Continue with user checks
    }
    
    // Check user attributes in the users table
    try {
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('is_admin, is_site_master, group_id, email')
        .eq('id', userId)
        .single();
      
      if (userError) {
        if (userError.code === '500' || userError.message?.includes('500')) {
          is500Error = true;
          console.log('[AdminRequest] 500 error on users table, will use fallback');
        } else if (userError.code === 'PGRST116') {
          console.log('[AdminRequest] User not found in users table, eligible as new user');
          return { eligible: true, error: null };
        } else {
          console.error('[AdminRequest] Error checking user data:', userError);
        }
        
        // If we got a 500 error and no conclusive result yet, continue to fallback
        if (is500Error) {
          // Last attempt - check directly with auth
          try {
            const { data: authData } = await supabase.auth.getUser(userId);
            if (authData?.user) {
              console.log('[AdminRequest] User found in auth, assuming eligible');
              return { eligible: true, error: null };
            }
          } catch (authErr) {
            console.error('[AdminRequest] Error checking auth:', authErr);
          }
        }
      } else if (userData) {
        // Check if email is from sandoog.com domain
        if (userData.email && userData.email.toLowerCase().endsWith('@sandoog.com')) {
          return { eligible: false, error: 'Users with sandoog.com emails are automatically site masters' };
        }
        
        // Check specific conditions that would make user ineligible
        if (userData.is_admin) {
          return { eligible: false, error: 'You are already an admin' };
        }
        
        if (userData.is_site_master) {
          return { eligible: false, error: 'Site masters already have admin privileges' };
        }
        
        if (userData.group_id) {
          return { eligible: false, error: 'You already belong to a group and cannot be an admin' };
        }
        
        // If we got here, user is eligible
        return { eligible: true, error: null };
      }
    } catch (err) {
      console.error('[AdminRequest] Unexpected error checking user attributes:', err);
      // Continue to fallback
    }
    
    // Fallback - give benefit of doubt if all checks pass without conclusive result
    console.log('[AdminRequest] Using fallback eligibility check result: eligible');
    return { eligible: true, error: null };
  } catch (error) {
    console.error('[AdminRequest] Unexpected error in eligibility check:', error);
    return { eligible: false, error: 'Unable to verify eligibility. Please try again later.' };
  }
}

// Submit admin request
export async function requestAdminStatus(userId: string, reason: string) {
  const { data, error } = await supabase
    .from('admin_requests')
    .insert([
      { user_id: userId, reason }
    ]);
  
  if (error) {
    return { success: false, error: error.message };
  }
  
  return { success: true };
}

// Check admin request status
export async function getAdminRequestStatus(userId: string) {
  try {
    const { data, error } = await supabase
      .from('admin_requests')
      .select('status, requested_at')
      .eq('user_id', userId)
      .order('requested_at', { ascending: false })
      .limit(1)
      .maybeSingle();
      
    if (error) throw error;
    
    return data;
  } catch (error) {
    console.error('Failed to fetch admin request status:', error);
    return null;
  }
}

export async function signInWithPassword(email: string, password: string) {
  // Hardcoded admin bypass for testing
  if (email === 'admin@sandoog.com' && password === '0909') {
    console.log('[Auth] Using hardcoded site master credentials');
    return {
      user: {
        id: '00000000-0000-0000-0000-000000000000',
        email: 'admin@sandoog.com',
        is_site_master: true,
        is_admin: true
      },
      error: null
    };
  }

  // Check for @sandoog.com domain for site master
  if (email.toLowerCase().endsWith('@sandoog.com')) {
    console.log('[Auth] Site master domain detected:', email);
    // Normal login flow
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (error) {
      return { data: null, error };
    }
    
    // Ensure we set site master status
    return { 
      data: { 
        user: { ...data?.user, is_site_master: true, is_admin: true }, 
        session: data?.session 
      }, 
      error: null 
    };
  }

  // Regular user login
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  return { data, error };
} 