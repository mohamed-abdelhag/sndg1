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
        });
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
    
    // First check if user already has any admin requests (regardless of status)
    // Use a more direct approach instead of complex filters
    const { data: existingRequests, error: requestError } = await supabase
      .from('admin_requests')
      .select('status, requested_at')
      .eq('user_id', userId)
      .order('requested_at', { ascending: false });
      
    console.log('[AdminRequest] Request check result:', { data: existingRequests, error: requestError });
    
    if (requestError) {
      // If there's a database error (e.g., table doesn't exist), log it but allow the request
      console.error('[AdminRequest] Error checking for existing requests:', requestError);
      // Continue with other checks
    } else if (existingRequests && existingRequests.length > 0) {
      // If any requests exist, check the status of the most recent one
      const latestRequest = existingRequests[0];
      console.log('[AdminRequest] Found existing request with status:', latestRequest.status);
      
      if (latestRequest.status === 'pending' || latestRequest.status === 'approved') {
        return { 
          eligible: false, 
          error: `You already have an ${latestRequest.status} admin request (from ${new Date(latestRequest.requested_at).toLocaleDateString()})` 
        };
      }
      
      // If the latest request was rejected, they can apply again
      if (latestRequest.status === 'rejected') {
        console.log('[AdminRequest] User has a rejected request, can apply again');
        // Continue with other checks
      }
    }
      
    // Then check user attributes
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('is_admin, is_site_master, group_id')
      .eq('id', userId)
      .single();
      
    console.log('[AdminRequest] User data check result:', { data: userData, error: userError });
    
    if (userError) {
      console.error('[AdminRequest] Error checking user data:', userError);
      return { eligible: false, error: 'Unable to verify user status. Please try again later.' };
    }
    
    if (userData) {
      if (userData.is_admin) {
        return { eligible: false, error: 'You are already an admin' };
      }
      
      if (userData.is_site_master) {
        return { eligible: false, error: 'Site masters already have admin privileges' };
      }
      
      if (userData.group_id) {
        return { eligible: false, error: 'You already belong to a group and cannot be an admin' };
      }
    }
    
    // Finally check for pending join requests
    const { count: joinRequestCount, error: joinError } = await supabase
      .from('group_join_requests')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('status', 'pending');
      
    console.log('[AdminRequest] Join request check result:', { count: joinRequestCount, error: joinError });
    
    if (!joinError && joinRequestCount && joinRequestCount > 0) {
      return { eligible: false, error: 'You have pending group join requests' };
    }
    
    // If all checks pass, user is eligible
    console.log('[AdminRequest] User is eligible for admin request');
    return { eligible: true, error: null };
  } catch (error) {
    console.error('[AdminRequest] Admin eligibility check failed:', error);
    return { eligible: false, error: 'Unable to check eligibility' };
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