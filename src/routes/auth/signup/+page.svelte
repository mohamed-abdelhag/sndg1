<script lang="ts">
  import SignupForm from '$lib/components/auth/SignupForm.svelte';
  import { goto } from '$app/navigation';
  
  // Define variables used in the page
  let errorMessage = '';
  let successMessage = '';
  
  function resendConfirmation() {
    // This will be handled by the SignupForm component
    console.log('Resend confirmation requested');
  }
</script>

<svelte:head>
  <title>Signup - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
      Create your account
    </h2>
    <p class="mt-2 text-center text-sm text-gray-600">
      Or
      <a href="/auth/login" class="font-medium text-indigo-600 hover:text-indigo-500">
        sign in to your existing account
      </a>
    </p>
  </div>

  <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
      <SignupForm on:success={() => goto('/auth/confirm-email')} />

      {#if errorMessage}
        <div class="mb-4 p-3 bg-red-50 text-red-700 rounded-md">
          <p class="text-sm">Error: {errorMessage}</p>
          {#if errorMessage.includes('already registered')}
            <p class="mt-1 text-sm">
              Already have an account? <a href="/auth/login" class="font-medium text-red-700 hover:text-red-600">Login here</a>
            </p>
          {/if}
        </div>
      {/if}

      {#if successMessage}
        <div class="mb-4 p-3 bg-green-50 text-green-700 rounded-md">
          <p class="text-sm">{successMessage}</p>
          <p class="mt-2 text-sm">
            Didn't receive the email? <button on:click|preventDefault={resendConfirmation} class="font-medium text-green-700 hover:text-green-600">Resend confirmation</button>
          </p>
        </div>
      {/if}
    </div>
  </div>
</div> 