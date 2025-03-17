import { json } from '@sveltejs/kit';
import { supabase } from '$lib/auth/supabase';

/**
 * Endpoint to update site master status for users
 * This is used as a fallback for ensuring sandoog.com email users have site master privileges
 */
export async function POST({ request }) {
  try {
    console.log('[API] update-site-master endpoint called');
    
    // Parse request body
    const body = await request.json();
    const { userId } = body;
    
    if (!userId) {
      console.error('[API] Missing userId in request');
      return json({ error: 'Missing userId parameter' }, { status: 400 });
    }
    
    console.log('[API] Updating site master status for user:', userId);
    
    // First get the user's email
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('email, is_site_master, is_admin')
      .eq('id', userId)
      .single();
      
    if (userError) {
      console.error('[API] Error fetching user data:', userError);
      return json({ error: userError.message }, { status: 500 });
    }
    
    if (!userData) {
      console.error('[API] User not found');
      return json({ error: 'User not found' }, { status: 404 });
    }
    
    const email = userData.email;
    const isSandoogEmail = email && email.toLowerCase().endsWith('@sandoog.com');
    
    // Only update if it's a sandoog.com email and not already a site master
    if (isSandoogEmail && (!userData.is_site_master || !userData.is_admin)) {
      console.log('[API] Updating sandoog.com user to site master:', email);
      
      const { error: updateError } = await supabase
        .from('users')
        .update({
          is_site_master: true,
          is_admin: true,
          updated_at: new Date()
        })
        .eq('id', userId);
        
      if (updateError) {
        console.error('[API] Error updating user:', updateError);
        return json({ error: updateError.message }, { status: 500 });
      }
      
      return json({ success: true, message: 'User updated to site master' });
    }
    
    // User is already a site master or not a sandoog.com email
    return json({ 
      success: true, 
      message: 'No update needed', 
      details: {
        email,
        isSandoogEmail,
        is_site_master: userData.is_site_master,
        is_admin: userData.is_admin
      }
    });
  } catch (error) {
    console.error('[API] Unexpected error in update-site-master endpoint:', error);
    return json({ error: 'Server error' }, { status: 500 });
  }
} 