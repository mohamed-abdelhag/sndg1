<script lang="ts">
  import { enhance } from "$app/forms";
  import { goto } from "$app/navigation";
  import { page } from '$app/stores';
  import { supabase } from "$lib/auth/supabase";
  import { onMount } from "svelte";

  let email = "";
  let password = "";
  let confirmPassword = "";
  let firstName = "";
  let lastName = "";
  let loading = false;
  let error = "";
  let success = false;
  let confirmationSent = false;
  let resendRequested = false;
  
  // Already logged in check
  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
      // User is already logged in, redirect to home
      goto('/');
    }
  });

  async function handleSignup() {
    if (loading) return;
    
    error = "";
    
    // Form validation
    if (!email || !password || !confirmPassword || !firstName || !lastName) {
      error = "All fields are required";
      return;
    }
    
    if (password !== confirmPassword) {
      error = "Passwords don't match";
      return;
    }
    
    if (password.length < 6) {
      error = "Password must be at least 6 characters";
      return;
    }
    
    loading = true;
    
    try {
      console.log('[Signup] Attempting signup for:', email);
      
      // First check if the user already exists but isn't confirmed
      const { data: { user: existingUser }, error: getUserError } = await supabase.auth.getUser();
      
      if (existingUser && existingUser.email === email && !existingUser.confirmed_at) {
        console.log('[Signup] User exists but is not confirmed, sending new confirmation email');
        
        // Resend confirmation email
        const { error: resendError } = await supabase.auth.resend({
          type: 'signup',
          email,
          options: {
            emailRedirectTo: `${window.location.origin}/auth/confirm-email`
          }
        });
        
        if (resendError) {
          console.error('[Signup] Error resending confirmation:', resendError);
          error = resendError.message;
          loading = false;
          return;
        }
        
        // Show confirmation sent message
        confirmationSent = true;
        loading = false;
        return;
      }
      
      // Standard signup flow
      const { data, error: signupError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            first_name: firstName,
            last_name: lastName,
          },
          emailRedirectTo: `${window.location.origin}/auth/confirm-email`
        }
      });
      
      if (signupError) {
        console.error('[Signup] Error during signup:', signupError);
        error = signupError.message;
        return;
      }
      
      // Create user record in users table
      const { error: insertError } = await supabase
        .from('users')
        .insert({
          id: data.user?.id,
          email: email.toLowerCase(),
          first_name: firstName,
          last_name: lastName,
          created_at: new Date(),
          updated_at: new Date()
        });
      
      if (insertError) {
        console.warn('[Signup] Error creating user record:', insertError);
        // Don't show error to user, as auth signup was successful
      }
      
      console.log('[Signup] Signup successful, confirmation email sent');
      success = true;
      confirmationSent = true;
      
    } catch (err) {
      console.error('[Signup] Unexpected error:', err);
      error = "An unexpected error occurred. Please try again.";
    } finally {
      loading = false;
    }
  }
  
  async function resendConfirmation() {
    if (resendRequested) return;
    
    resendRequested = true;
    error = "";
    
    try {
      console.log('[Signup] Resending confirmation email to:', email);
      
      const { error: resendError } = await supabase.auth.resend({
        type: 'signup',
        email,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/confirm-email`
        }
      });
      
      if (resendError) {
        console.error('[Signup] Error resending confirmation:', resendError);
        error = `Could not resend confirmation: ${resendError.message}`;
        resendRequested = false;
        return;
      }
      
      confirmationSent = true;
      
    } catch (err) {
      console.error('[Signup] Unexpected error in resend:', err);
      error = "Could not resend confirmation. Please try again.";
      resendRequested = false;
    }
  }
</script>

<svelte:head>
  <title>Sign up - Sandoog</title>
</svelte:head>

<div class="flex min-h-screen flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-bold tracking-tight text-gray-900">
      {confirmationSent ? 'Check your email' : 'Create a new account'}
    </h2>
    {#if !confirmationSent}
      <p class="mt-2 text-center text-sm text-gray-600">
        Or <a href="/auth/login" class="font-medium text-indigo-600 hover:text-indigo-500">sign in to your existing account</a>
      </p>
    {/if}
  </div>

  <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white px-4 py-8 shadow sm:rounded-lg sm:px-10">
      {#if confirmationSent}
        <div class="text-center">
          <div class="mb-4 flex justify-center">
            <div class="h-12 w-12 rounded-full bg-green-100 flex items-center justify-center">
              <svg class="h-6 w-6 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
              </svg>
            </div>
          </div>
          <h3 class="text-base font-semibold text-gray-900">Confirmation email sent</h3>
          <p class="mt-2 text-sm text-gray-500">
            We've sent an email to <span class="font-medium">{email}</span> with a confirmation link.
            Please check your inbox and click the link to activate your account.
          </p>
          <div class="mt-6">
            <button
              on:click={resendConfirmation}
              disabled={resendRequested}
              class="text-sm font-medium text-indigo-600 hover:text-indigo-500 disabled:opacity-50"
            >
              {resendRequested ? 'Email sent again!' : 'Resend confirmation email'}
            </button>
          </div>
          <div class="mt-6">
            <a
              href="/auth/login"
              class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              Return to login
            </a>
          </div>
        </div>
      {:else}
        <form class="space-y-6" on:submit|preventDefault={handleSignup}>
          {#if error}
            <div class="rounded-md bg-red-50 p-4">
              <div class="flex">
                <div class="text-sm text-red-700">
                  {error}
                </div>
              </div>
            </div>
          {/if}
          
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-2">
            <div>
              <label for="firstName" class="block text-sm font-medium text-gray-700">
                First name
              </label>
              <div class="mt-1">
                <input
                  id="firstName"
                  name="firstName"
                  type="text"
                  autocomplete="given-name"
                  required
                  bind:value={firstName}
                  class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
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
                  autocomplete="family-name"
                  required
                  bind:value={lastName}
                  class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
                />
              </div>
            </div>
          </div>

          <div>
            <label for="email" class="block text-sm font-medium text-gray-700">
              Email address
            </label>
            <div class="mt-1">
              <input
                id="email"
                name="email"
                type="email"
                autocomplete="email"
                required
                bind:value={email}
                class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
              />
            </div>
          </div>

          <div>
            <label for="password" class="block text-sm font-medium text-gray-700">
              Password
            </label>
            <div class="mt-1">
              <input
                id="password"
                name="password"
                type="password"
                autocomplete="new-password"
                required
                bind:value={password}
                class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
              />
            </div>
          </div>

          <div>
            <label for="confirmPassword" class="block text-sm font-medium text-gray-700">
              Confirm password
            </label>
            <div class="mt-1">
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                autocomplete="new-password"
                required
                bind:value={confirmPassword}
                class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              class="flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50"
            >
              {loading ? 'Creating account...' : 'Create account'}
            </button>
          </div>
        </form>
      {/if}
    </div>
  </div>
</div> 