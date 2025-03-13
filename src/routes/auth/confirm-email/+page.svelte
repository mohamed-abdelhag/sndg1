<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { goto } from '$app/navigation';

  let email = '';
  let resent = false;

  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    email = session?.user?.email || '';
  });

  async function resendConfirmation() {
    await supabase.auth.resend({
      type: 'signup',
      email,
      options: {
        emailRedirectTo: `${location.origin}/auth/callback`
      }
    });
    resent = true;
  }
</script>

<svelte:head>
  <title>Confirm Email - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10 text-center">
      <h2 class="text-2xl font-bold text-gray-900 mb-4">Confirm Your Email</h2>
      <p class="text-gray-600 mb-4">
        We've sent a confirmation email to <span class="font-medium">{email}</span>.
        Please check your inbox and click the verification link.
      </p>
      
      <button
        on:click={resendConfirmation}
        class="text-indigo-600 hover:text-indigo-500 font-medium"
      >
        {resent ? 'Email Resent!' : 'Resend Confirmation Email'}
      </button>
      
      <p class="mt-6 text-sm text-gray-600">
        Already confirmed? <a href="/auth/login" class="text-indigo-600 hover:text-indigo-500">Try logging in again</a>
      </p>
    </div>
  </div>
</div> 