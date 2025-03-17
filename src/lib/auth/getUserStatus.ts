import { supabase } from './supabase';

/**
 * Enhanced user status checker that's more resilient to database issues
 */
export async function getUserStatus(userId: string) {
  try {
    console.log('[User] Getting status for user:', userId);
    
    // Try to get user from users table
    try {
      const { data, error } = await supabase
        .from('users')
        .select('is_admin, is_site_master, group_id, email')
        .eq('id', userId)
        .single();

      if (!error && data) {
        console.log('[User] Found user in users table:', data);
        
        // Special check for site master email regardless of database flags
        const isSiteMasterEmail = data.email && data.email.toLowerCase().endsWith('@sandoog.com');
        
        return {
          isAuthenticated: true,
          isSiteMaster: data.is_site_master || isSiteMasterEmail,
          isAdmin: data.is_admin || isSiteMasterEmail,
          groupId: data.group_id
        };
      }
      
      if (error) {
        console.log('[User] Error getting user from users table:', error);
      }
    } catch (err) {
      console.error('[User] Exception getting user from users table:', err);
    }
    
    // If that fails, try to get just the user email from auth
    try {
      const { data: authData } = await supabase.auth.getUser(userId);
      
      if (authData?.user?.email) {
        const email = authData.user.email;
        console.log('[User] Got user email from auth:', email);
        
        // Check if it's a site master email
        const isSiteMasterEmail = email.toLowerCase().endsWith('@sandoog.com');
        
        if (isSiteMasterEmail) {
          console.log('[User] User has site master email domain');
          return {
            isAuthenticated: true,
            isSiteMaster: true,
            isAdmin: true,
            groupId: null
          };
        }
      }
    } catch (err) {
      console.error('[User] Error getting user from auth:', err);
    }
    
    // Default to authenticated but with no special roles
    return {
      isAuthenticated: true,
      isSiteMaster: false,
      isAdmin: false,
      groupId: null
    };
  } catch (error) {
    console.error('[User] Failed to get user status:', error);
    return {
      isAuthenticated: false,
      isSiteMaster: false,
      isAdmin: false,
      groupId: null
    };
  }
}

/**
 * Check if the current user is a site master
 */
export async function checkIfSiteMaster(): Promise<boolean> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session) {
      return false;
    }
    
    // Email domain check for @sandoog.com
    if (session.user.email && session.user.email.toLowerCase().endsWith('@sandoog.com')) {
      console.log('[Auth] Site master detected via email domain:', session.user.email);
      return true;
    }
    
    // Special check for admin@sandoog.com
    if (session.user.email && session.user.email.toLowerCase() === 'admin@sandoog.com') {
      console.log('[Auth] Main admin account detected:', session.user.email);
      return true;
    }
    
    // Database flag check
    try {
      const { data, error } = await supabase
        .from('users')
        .select('is_site_master')
        .eq('id', session.user.id)
        .single();
      
      if (!error && data) {
        console.log('[Auth] Site master check from database:', data.is_site_master);
        return !!data.is_site_master;
      }
    } catch (err) {
      console.error('[Auth] Error checking site master in database:', err);
    }
    
    return false;
  } catch (error) {
    console.error('[Auth] Error checking site master status:', error);
    return false;
  }
} 