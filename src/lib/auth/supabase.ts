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

export async function signInWithPassword({
  email,
  password,
}: {
  email: string;
  password: string;
}) {
  try {
    console.log("[Auth] Login attempt with email:", email);
    
    // Authenticate the user
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    
    if (error) {
      console.error("[Auth] Login error:", error);
      return { data: null, error };
    }
    
    console.log("[Auth] Login successful, verifying user record exists");
    
    // If login succeeded, ensure the user exists in the users table
    if (data?.user) {
      try {
        // Check if user exists in the users table
        const { data: existingUser, error: queryError } = await supabase
          .from('users')
          .select('*')
          .eq('id', data.user.id)
          .single();
          
        if (queryError || !existingUser) {
          console.log("[Auth] User not found in users table, creating new entry");
          
          // User doesn't exist in users table, create an entry
          const isSandoogEmail = email.endsWith('@sandoog.com');
          
          const { data: userData, error: userError } = await supabase
            .from('users')
            .upsert({
              id: data.user.id,
              email: data.user.email,
              is_admin: isSandoogEmail,
              is_site_master: isSandoogEmail,
              created_at: new Date(),
              updated_at: new Date(),
            }, {
              onConflict: 'id',
              ignoreDuplicates: false,
            });
            
          if (userError) {
            console.error("[Auth] Error creating user entry during login:", userError);
          } else {
            console.log("[Auth] User entry created successfully during login");
          }
        } else if (email.endsWith('@sandoog.com') && 
                  (!existingUser.is_site_master || !existingUser.is_admin)) {
          // Update sandoog.com users to be site masters and admins if they aren't already
          console.log("[Auth] Updating privileges for @sandoog.com user");
          
          const { error: updateError } = await supabase
            .from('users')
            .update({
              is_admin: true,
              is_site_master: true,
              updated_at: new Date(),
            })
            .eq('id', data.user.id);
            
          if (updateError) {
            console.error("[Auth] Error updating user privileges:", updateError);
          }
        }
      } catch (userCheckError) {
        console.error("[Auth] Exception checking user record:", userCheckError);
        // Continue despite error, the login is still successful
      }
    }
    
    return { data, error: null };
  } catch (err) {
    console.error("[Auth] Login exception:", err);
    return { 
      data: null, 
      error: { 
        message: 'An unexpected error occurred during login. Please try again.',
        name: 'LoginError'
      }
    };
  }
} 