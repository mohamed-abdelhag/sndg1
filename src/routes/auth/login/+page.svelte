<script lang="ts">
  import LoginForm from '$lib/components/auth/LoginForm.svelte';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { getUserRoles, redirectBasedOnRole } from '$lib/auth/utils';
  
  // Check if user is already logged in on mount
  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      // User is already logged in, get roles and redirect
      const userData = await getUserRoles(session.user.id);
      
      if (userData) {
        // Check if email is a site master email
        if (userData.email.toLowerCase().endsWith('@sandoog.com')) {
          console.log('[Login] Detected site master email, redirecting to sitemaster page');
          goto('/sitemaster');
          return;
        }
        
        // Otherwise redirect based on standard role logic
        redirectBasedOnRole(userData);
      }
    }
  });
  
  // Handle successful login
  function handleLoginSuccess() {
    // Note: Redirection is handled within the loginUser function
    console.log('[Login] Login successful');
  }
</script>

<svelte:head>
  <title>Login - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
      Sign in to your account
    </h2>
    <p class="mt-2 text-center text-sm text-gray-600">
      Welcome back to Sandoog - your savings group management platform
    </p>
  </div>

  <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
      <LoginForm on:success={handleLoginSuccess} />
      <div class="text-sm text-center mt-4">
        <a href="/auth/forgot-password" class="font-medium text-indigo-600 hover:text-indigo-500">
          Forgot your password?
        </a>
      </div>
    </div>
  </div>
</div> 