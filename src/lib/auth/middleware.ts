import { supabase, type UserWithRoles } from './supabase';
import { redirect } from '@sveltejs/kit';
import type { RequestEvent } from '@sveltejs/kit';

// Middleware to check if user is authenticated
export const requireAuth = async () => {
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session) {
    throw redirect(303, '/auth/login');
  }

  if (!session.user.email_confirmed_at) {
    throw redirect(303, '/auth/confirm-email');
  }

  return session;
};

// Middleware to check if user is site master
export async function requireSiteMaster(event: RequestEvent) {
  const session = await requireAuth();
  
  const { data, error } = await supabase
    .from('users')
    .select('is_site_master')
    .eq('id', session.user.id)
    .single();
  
  if (error || !data || !data.is_site_master) {
    throw redirect(303, '/');
  }
  
  return session;
}

// Middleware to check if user is admin
export async function requireAdmin(event: RequestEvent) {
  const session = await requireAuth();
  
  const { data, error } = await supabase
    .from('users')
    .select('is_admin')
    .eq('id', session.user.id)
    .single();
  
  if (error || !data || !data.is_admin) {
    throw redirect(303, '/');
  }
  
  return session;
}

// Middleware to check if user belongs to a specific group
export async function requireGroupMember(event: RequestEvent, groupId: string) {
  const session = await requireAuth();
  
  const { data, error } = await supabase
    .from('users')
    .select('group_id')
    .eq('id', session.user.id)
    .single();
  
  if (error || !data || data.group_id !== groupId) {
    throw redirect(303, '/');
  }
  
  return session;
}

// Middleware to check if user is group admin
export async function requireGroupAdmin(event: RequestEvent, groupId: string) {
  const session = await requireAuth();
  
  const { data, error } = await supabase
    .from('groups')
    .select('created_by')
    .eq('id', groupId)
    .single();
  
  if (error || !data || data.created_by !== session.user.id) {
    throw redirect(303, '/');
  }
  
  return session;
}

// Get user status for UI decisions
export async function getUserStatus(userId: string) {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('is_admin, is_site_master, group_id, email')
      .eq('id', userId)
      .single();

    if (error) throw error;

    // Check both the flag and email for site master status
    const isSiteMaster = data.is_site_master || data.email === 'admin@sandoog.com';
    
    return {
      isAuthenticated: true,
      isSiteMaster,
      isAdmin: data.is_admin,
      groupId: data.group_id
    };
  } catch (error) {
    console.error('Failed to get user status:', error);
    return {
      isAuthenticated: false,
      isSiteMaster: false,
      isAdmin: false,
      groupId: null
    };
  }
}

// Simple function to check if current user is a site master - doesn't use event parameter
export async function checkIfSiteMaster(): Promise<boolean> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session) {
      return false;
    }
    
    // First check: Email domain check for @sandoog.com
    if (session.user.email && session.user.email.toLowerCase().endsWith('@sandoog.com')) {
      console.log('[Auth] Site master detected via email domain:', session.user.email);
      
      // Ensure the database is updated to reflect site master status
      await supabase
        .from('users')
        .upsert({
          id: session.user.id,
          email: session.user.email,
          is_admin: true,
          is_site_master: true
        });
        
      return true;
    }
    
    // Second check: Database flag check
    const { data, error } = await supabase
      .from('users')
      .select('is_site_master')
      .eq('id', session.user.id)
      .single();
    
    if (error || !data) {
      console.log('[Auth] Site master check failed, no user data found');
      return false;
    }
    
    console.log('[Auth] Site master check from database:', data.is_site_master);
    return data.is_site_master || false;
  } catch (error) {
    console.error('[Auth] Error checking site master status:', error);
    return false;
  }
} 