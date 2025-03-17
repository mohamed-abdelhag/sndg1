import { createClient, type User, type Session } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import type { Database } from '$lib/db/supabase-types';

// Add a debug flag
export const DEBUG_MODE = true;

// Create a more robust client with error handling
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
  {
    auth: {
      persistSession: false, // Don't persist session by default - we'll handle this manually
      storageKey: 'sandoog-auth-token',
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);

// Helper to safely execute database operations with proper error handling
export async function safeQuery<T>(operation: () => any): Promise<{data: T | null; error: any}> {
  try {
    return await operation();
  } catch (error) {
    if (DEBUG_MODE) {
      console.error('[Supabase] Error executing query:', error);
    }
    return { data: null, error };
  }
}

// Define user types based on our extended auth.users table
export type UserWithRoles = {
  id: string;
  email: string;
  first_name: string | null;
  last_name: string | null;
  is_admin: boolean;
  is_site_master: boolean;
  group_id: string | null;
};

// Get current user with role information
export async function getCurrentUserWithRoles(): Promise<UserWithRoles | null> {
  const { data: { session }, error: sessionError } = await supabase.auth.getSession();
  
  if (sessionError || !session) {
    return null;
  }
  
  // Get the extended user data from auth.users
  const { data, error } = await supabase
    .from('users')
    .select('id, email, first_name, last_name, is_admin, is_site_master, group_id')
    .eq('id', session.user.id)
    .single();
  
  if (error || !data) {
    return null;
  }
  
  return data as UserWithRoles;
}

export async function signupUser({
  email,
  password,
  firstName,
  lastName,
}: {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
}) {
  try {
    console.log("[Auth] Signup attempt with email:", email);
    
    // Check if user already exists first
    const { data: existingUsers } = await supabase
      .from('users')
      .select('email')
      .eq('email', email)
      .limit(1);
      
    if (existingUsers && existingUsers.length > 0) {
      console.error("[Auth] Email already in use:", email);
      return { 
        data: null, 
        error: { 
          message: 'Email address is already in use. Please use a different email or try logging in.',
          name: 'EmailExistsError'
        } 
      };
    }
    
    // Create the user with Supabase auth
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: window.location.origin + '/auth/login',
        // Ensure no auto-login after signup
        data: {
          first_name: firstName,
          last_name: lastName
        }
      },
    });
    
    if (error) {
      console.error("[Auth] Signup error:", error);
      return { data: null, error };
    }

    console.log("[Auth] Signup successful, creating user entry in users table");
    
    // If signup succeeded, add the user to the users table
    if (data?.user) {
      try {
        const { data: userData, error: userError } = await supabase
          .from('users')
          .upsert({
            id: data.user.id,
            email: data.user.email || email,
            first_name: firstName || null,
            last_name: lastName || null,
            is_admin: email.endsWith('@sandoog.com'),
            is_site_master: email.endsWith('@sandoog.com'),
            created_at: new Date(),
            updated_at: new Date(),
          }, {
            onConflict: 'id',
            ignoreDuplicates: false,
          });
          
        if (userError) {
          console.error("[Auth] Error creating user entry:", userError);
          // We don't return the error here since we still want the signup to succeed
        } else {
          console.log("[Auth] User entry created successfully");
        }
      } catch (userCreateError) {
        console.error("[Auth] Exception creating user entry:", userCreateError);
        // Continue despite error, the user is still created in auth
      }
    }
    
    // Sign out the user to prevent auto-login
    await supabase.auth.signOut();
    
    return { data, error: null };
  } catch (err) {
    console.error("[Auth] Signup exception:", err);
    return { 
      data: null, 
      error: { 
        message: 'An unexpected error occurred during signup. Please try again.',
        name: 'SignupError'
      } 
    };
  }
}

// Modified auth functions with better logging
export async function signInWithPassword({ email, password }: { email: string; password: string }) {
  if (DEBUG_MODE) {
    console.log('[Auth] Login attempt with email:', email);
  }
  
  try {
    const authResult = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (authResult.error) {
      console.error('[Auth] Login failed:', authResult.error);
      return authResult;
    }
    
    // Successful login
    if (DEBUG_MODE) {
      console.log('[Auth] Login successful, verifying user record exists');
    }
    
    // Check if user exists in users table and create if not
    const userId = authResult.data.user?.id;
    if (userId) {
      try {
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();
        
        if (userError || !userData) {
          if (DEBUG_MODE) {
            console.log('[Auth] User not found in users table, creating new entry');
          }
          
          const isSandoogEmail = email.toLowerCase().endsWith('@sandoog.com');
          
          try {
            await supabase
              .from('users')
              .upsert({
                id: userId,
                email: email.toLowerCase(),
                is_admin: isSandoogEmail,
                is_site_master: isSandoogEmail,
                created_at: new Date(),
                updated_at: new Date()
              }, { onConflict: 'id' });
          } catch (insertError) {
            // Log error but don't block login
            console.error('[Auth] Error creating user entry during login:', insertError);
          }
        }
      } catch (error) {
        // Log error but don't block login process
        console.error('[Auth] Error checking/creating user record:', error);
      }
    }
    
    return authResult;
  } catch (error) {
    console.error('[Auth] Unexpected error during login:', error);
    return { data: {}, error };
  }
}

// Force logout and clear all session data
export async function forceLogout() {
  try {
    await supabase.auth.signOut({ scope: 'global' });
    localStorage.removeItem('sandoog-auth-token');
    sessionStorage.clear();
    
    // Attempt to clear any cookies
    document.cookie.split(';').forEach(cookie => {
      const [name] = cookie.trim().split('=');
      document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
    });
    
    if (DEBUG_MODE) {
      console.log('[Auth] User completely logged out');
    }
    
    return { success: true };
  } catch (error) {
    console.error('[Auth] Error during logout:', error);
    return { success: false, error };
  }
} 