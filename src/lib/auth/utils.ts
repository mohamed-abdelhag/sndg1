import { supabase, type UserWithRoles } from './supabase';
import { goto } from '$app/navigation';
import { writable } from 'svelte/store';

// Create a store for the current user
export const currentUser = writable<UserWithRoles | null>(null);

// Login function
export async function loginUser(email: string, password: string) {
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
async function getUserRoles(userId: string): Promise<UserWithRoles> {
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
    const { data, error } = await supabase
      .rpc('check_admin_request_eligibility', { user_id: userId });
      
    if (error) throw error;
    
    return { eligible: data, error: null };
  } catch (error) {
    console.error('Admin eligibility check failed:', error);
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
  // Hardcoded admin bypass
  if (email === 'admin@sandoog.com' && password === '0909') {
    return {
      user: {
        id: '00000000-0000-0000-0000-000000000000',
        email: 'admin@sandoog.com',
        is_site_master: true,
        is_admin: true
      },
      error: null
    }
  }

  // Normal login flow
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  return { data, error };
} 