import { json } from '@sveltejs/kit';
import { supabase } from '$lib/auth/supabase';

/**
 * API endpoint to resend confirmation emails to users
 */
export async function POST({ request }) {
  try {
    console.log('[API] Resend confirmation email endpoint called');
    
    // Parse request body
    const body = await request.json();
    const { email } = body;
    
    if (!email) {
      console.error('[API] Missing email parameter');
      return json({ error: 'Email is required' }, { status: 400 });
    }
    
    console.log('[API] Resending confirmation email to:', email);
    
    // Use Supabase Auth API to resend confirmation instructions
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email,
      options: {
        emailRedirectTo: `${new URL(request.url).origin}/auth/confirm-email`
      }
    });
    
    if (error) {
      console.error('[API] Error resending confirmation email:', error);
      return json({ error: error.message }, { status: 500 });
    }
    
    return json({ 
      success: true, 
      message: 'Confirmation email sent successfully'
    });
    
  } catch (error) {
    console.error('[API] Unexpected error in resend-confirmation endpoint:', error);
    return json({ error: 'Server error' }, { status: 500 });
  }
} 