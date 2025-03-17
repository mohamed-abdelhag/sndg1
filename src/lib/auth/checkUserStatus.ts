import { supabase } from '$lib/auth/supabase';

/**
 * Check user authentication and roles
 * This function handles the complete user status check with fallbacks
 */
export async function checkUserStatus() {
  try {
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    
    if (sessionError) {
      console.error("Error getting session:", sessionError);
      return {
        isAuthenticated: false,
        isAdmin: false,
        isSiteMaster: false,
        groupId: null,
        userId: null,
        email: null,
        error: sessionError.message
      };
    }
    
    // If no session, user is not authenticated
    if (!session) {
      return {
        isAuthenticated: false,
        isAdmin: false,
        isSiteMaster: false,
        groupId: null,
        userId: null,
        email: null,
        error: null
      };
    }
    
    const userId = session.user.id;
    const email = session.user.email;
    
    // First check if it's a @sandoog.com email - these are always site masters
    const isSandoogEmail = email && email.toLowerCase().endsWith('@sandoog.com');
    
    // Check if user exists in users table
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single();
    
    // If user exists in the table, return their status
    if (userData) {
      console.log("User data found:", userData);
      
      // If email is @sandoog.com but they're not marked as site_master, fix it
      if (isSandoogEmail && (!userData.is_site_master || !userData.is_admin)) {
        console.log("Updating @sandoog.com user to site master:", email);
        await supabase
          .from('users')
          .update({
            is_site_master: true,
            is_admin: true,
            updated_at: new Date()
          })
          .eq('id', userId);
      }
      
      return {
        isAuthenticated: true,
        isAdmin: isSandoogEmail ? true : !!userData.is_admin,
        isSiteMaster: isSandoogEmail ? true : !!userData.is_site_master,
        groupId: userData.group_id,
        userId,
        email,
        firstName: userData.first_name,
        lastName: userData.last_name,
        error: null
      };
    }
    // User exists in auth but not in users table, create them
    else if (!userError || userError.code === 'PGRST116') {
      console.log("Creating user record for:", email);
      
      // Create user entry
      const { data: newUserData, error: createError } = await supabase
        .from('users')
        .insert({
          id: userId,
          email: email,
          is_admin: isSandoogEmail,
          is_site_master: isSandoogEmail,
          created_at: new Date(),
          updated_at: new Date()
        })
        .select()
        .single();
      
      if (createError) {
        console.error("Error creating user record:", createError);
        return {
          isAuthenticated: true,
          isAdmin: isSandoogEmail,
          isSiteMaster: isSandoogEmail,
          groupId: null,
          userId,
          email,
          error: createError.message
        };
      }
      
      return {
        isAuthenticated: true,
        isAdmin: isSandoogEmail,
        isSiteMaster: isSandoogEmail,
        groupId: null,
        userId,
        email,
        error: null
      };
    } 
    // Something else went wrong
    else {
      console.error("Error fetching user data:", userError);
      
      return {
        isAuthenticated: true,
        isAdmin: isSandoogEmail,
        isSiteMaster: isSandoogEmail,
        groupId: null,
        userId,
        email,
        error: userError.message
      };
    }
  } catch (error: any) {
    console.error("Unexpected error in checkUserStatus:", error);
    return {
      isAuthenticated: false,
      isAdmin: false,
      isSiteMaster: false,
      groupId: null,
      userId: null,
      email: null,
      error: error.message
    };
  }
} 