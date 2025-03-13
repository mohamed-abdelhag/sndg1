import { createClient, type User, type Session } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import type { Database } from '$lib/db/supabase-types';

export const supabase = createClient<Database>(
  PUBLIC_SUPABASE_URL,
  PUBLIC_SUPABASE_ANON_KEY
);

// Define user types based on our extended auth.users table
export type UserWithRoles = {
  id: string;
  email: string;
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
    .select('id, email, is_admin, is_site_master, group_id')
    .eq('id', session.user.id)
    .single();
  
  if (error || !data) {
    return null;
  }
  
  return data as UserWithRoles;
}

export async function signupUser(email: string, password: string): Promise<{
  user: User | null;
  session: Session | null;
  error: { message: string; code?: string } | null;
}> {
  console.log('[Auth] Signup attempt for:', email);
  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${location.origin}/auth/callback`
      }
    });

    console.log('[Auth] Signup response:', { data, error });
    
    return {
      user: data?.user || null,
      session: data?.session || null,
      error: error ? { message: error.message, code: error.code } : null
    };
  } catch (err) {
    console.error('[Auth] Signup error:', err);
    return {
      user: null,
      session: null,
      error: {
        message: 'Failed to create account',
        code: 'UNKNOWN_ERROR'
      }
    };
  }
}

export async function signInWithPassword(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  
  if (email === 'admin@sandoog.com') {
    // Explicitly check for site master status
    const { data: userData } = await supabase
      .from('users')
      .select('is_site_master')
      .eq('email', email)
      .single();

    if (userData?.is_site_master) {
      return { 
        data: { 
          user: { ...data?.user, is_site_master: true }, 
          session: data?.session 
        }, 
        error: null 
      };
    }
  }
  
  return { data, error };
} 