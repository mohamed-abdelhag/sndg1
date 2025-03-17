<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/auth/supabase';
  
  let status = 'loading';
  let message = 'Verifying your email...';
  let email = '';
  let firstName = '';
  let lastName = '';
  let showProfileForm = false;
  let formSubmitted = false;
  
  onMount(async () => {
    try {
      // Check query params for token
      const hash = window.location.hash;
      const query = $page.url.searchParams;
      
      // Log debugging info
      console.log('Confirm email page loaded', { hash, query: Object.fromEntries(query) });
      
      // If there's a hash, we're coming from email confirmation
      if (hash && hash.includes('access_token')) {
        // Email has been confirmed
        status = 'confirmed';
        message = 'Your email has been confirmed! Updating your profile...';
        
        // Get current session
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) {
          console.error('Session error:', sessionError);
          status = 'error';
          message = 'There was an error retrieving your session. Please try logging in again.';
          return;
        }
        
        if (session) {
          email = session.user.email || '';
          
          // Check if user has first/last name
          const { data: userData, error: userError } = await supabase
            .from('users')
            .select('first_name, last_name')
            .eq('id', session.user.id)
            .single();
          
          if (!userError && userData && userData.first_name && userData.last_name) {
            // User already has profile data, redirect to home
            console.log('User already has profile data, redirecting to home');
            message = 'Your profile is already complete. Redirecting...';
            
            // Redirect after a short delay
            setTimeout(() => {
              goto('/');
            }, 2000);
          } else {
            // Show form to complete profile
            console.log('Showing profile form');
            showProfileForm = true;
          }
        } else {
          // No session found
          status = 'error';
          message = 'No active session found. Please try logging in.';
        }
      } else {
        // No confirmation token found
        status = 'error';
        message = 'No confirmation token found. This page should be accessed from the confirmation email link.';
      }
    } catch (error) {
      console.error('Error in confirm-email page:', error);
      status = 'error';
      message = 'An unexpected error occurred. Please try logging in again.';
    }
  });
  
  async function handleProfileSubmit() {
    if (!firstName || !lastName) {
      message = 'Please provide both first and last name';
      return;
    }
    
    try {
      formSubmitted = true;
      
      // Get current session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        status = 'error';
        message = 'No active session found. Please try logging in again.';
        formSubmitted = false;
        return;
      }
      
      // Update user profile in users table
      const { error: updateError } = await supabase
        .from('users')
        .update({
          first_name: firstName,
          last_name: lastName,
          updated_at: new Date()
        })
        .eq('id', session.user.id);
      
      if (updateError) {
        console.error('Error updating profile:', updateError);
        status = 'error';
        message = 'There was an error updating your profile. Please try again.';
        formSubmitted = false;
        return;
      }
      
      // Profile updated successfully
      status = 'success';
      message = 'Your profile has been updated successfully! Redirecting...';
      
      // Redirect to home after a short delay
      setTimeout(() => {
        goto('/');
      }, 2000);
      
    } catch (error) {
      console.error('Error in profile update:', error);
      status = 'error';
      message = 'An unexpected error occurred. Please try again.';
      formSubmitted = false;
    }
  }
</script>

<svelte:head>
  <title>Confirm Email - Sandoog</title>
</svelte:head>

<div class="min-h-screen flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-bold tracking-tight text-gray-900">
      {status === 'confirmed' ? 'Email Confirmed' : status === 'error' ? 'Error' : 'Confirming Email'}
    </h2>
    <p class="mt-2 text-center text-sm text-gray-600">
      {message}
    </p>
  </div>

  {#if showProfileForm}
    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
      <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
        <form class="space-y-6" on:submit|preventDefault={handleProfileSubmit}>
          <div>
            <label for="email" class="block text-sm font-medium text-gray-700">
              Email address
            </label>
            <div class="mt-1">
              <input
                id="email"
                name="email"
                type="email"
                disabled
                value={email}
                class="block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm bg-gray-50"
              />
            </div>
          </div>

          <div>
            <label for="firstName" class="block text-sm font-medium text-gray-700">
              First name
            </label>
            <div class="mt-1">
              <input
                id="firstName"
                name="firstName"
                type="text"
                required
                bind:value={firstName}
                class="block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                placeholder="Enter your first name"
              />
            </div>
          </div>

          <div>
            <label for="lastName" class="block text-sm font-medium text-gray-700">
              Last name
            </label>
            <div class="mt-1">
              <input
                id="lastName"
                name="lastName"
                type="text"
                required
                bind:value={lastName}
                class="block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 placeholder-gray-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                placeholder="Enter your last name"
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={formSubmitted}
              class="flex w-full justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50"
            >
              {formSubmitted ? 'Updating...' : 'Complete Profile'}
            </button>
          </div>
        </form>
      </div>
    </div>
  {:else if status === 'loading'}
    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md flex justify-center">
      <svg class="animate-spin -ml-1 mr-3 h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </div>
  {/if}
  
  {#if status === 'error'}
    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
      <div class="flex justify-center">
        <a
          href="/auth/login"
          class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
        >
          Go to Login
        </a>
      </div>
    </div>
  {/if}
</div> 