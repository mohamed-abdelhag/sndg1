<script lang="ts">
  import { signupUser } from '$lib/auth/supabase';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  
  // Form state
  let email = '';
  let password = '';
  let confirmPassword = '';
  let loading = false;
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  
  const dispatch = createEventDispatcher();
  
  // Add debug console logs
  function logDebug(message: string, data?: any) {
    console.log('[Signup]', message, data);
  }
  
  async function handleSubmit() {
    logDebug('Form submission started', { email, password });
    
    // Form validation
    if (!email || !password || !confirmPassword) {
      errorMessage = 'Please fill in all fields';
      showError = true;
      return;
    }
    
    if (password !== confirmPassword) {
      errorMessage = 'Passwords do not match';
      showError = true;
      return;
    }
    
    if (password.length < 6) {
      errorMessage = 'Password must be at least 6 characters long';
      showError = true;
      return;
    }
    
    // Submit form
    loading = true;
    try {
      logDebug('Attempting signup with', { email });
      const { user, session, error } = await signupUser(email, password);
      
      logDebug('Signup result', { user, session, error });
      
      if (error) {
        logDebug('Signup error', error);
        errorMessage = typeof error === 'string' ? error : error.message;
        successMessage = '';
      } else if (user) {
        logDebug('Signup success', user);
        successMessage = 'Account created successfully! Please check your email to confirm.';
        errorMessage = '';
        window.location.href = '/auth/confirm-email';
      } else {
        errorMessage = 'Signup completed but no user data returned';
      }
    } catch (err) {
      logDebug('Unexpected error', err);
      errorMessage = 'An unexpected error occurred. Please try again.';
      successMessage = '';
    }
  }
</script>

<form on:submit|preventDefault={handleSubmit} class="space-y-6">
  <div>
    <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
    <div class="mt-1">
      <input
        id="email"
        type="email"
        bind:value={email}
        required
        autocomplete="email"
        class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
      />
    </div>
  </div>
  
  <div>
    <label for="password" class="block text-sm font-medium text-gray-700">Password</label>
    <div class="mt-1">
      <input
        id="password"
        type="password"
        bind:value={password}
        required
        autocomplete="new-password"
        class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
      />
    </div>
  </div>
  
  <div>
    <label for="confirm-password" class="block text-sm font-medium text-gray-700">Confirm Password</label>
    <div class="mt-1">
      <input
        id="confirm-password"
        type="password"
        bind:value={confirmPassword}
        required
        autocomplete="new-password"
        class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
      />
    </div>
  </div>
  
  <div>
    <Button type="submit" fullWidth={true} loading={loading}>
      Create Account
    </Button>
  </div>
  
  <div class="text-center">
    <p class="text-sm text-gray-600">
      Already have an account? <a href="/auth/login" class="font-medium text-indigo-600 hover:text-indigo-500">Sign in</a>
    </p>
  </div>
</form>

<Notification
  type="error"
  message={errorMessage}
  bind:show={showError}
  on:close={() => (showError = false)}
/>

<Notification
  type="success"
  message={successMessage}
  bind:show={showSuccess}
  on:close={() => (showSuccess = false)}
/> 