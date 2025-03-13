<script lang="ts">
  import PasswordResetForm from '$lib/components/auth/PasswordResetForm.svelte';
  import { goto } from '$app/navigation';
</script>

<svelte:head>
  <title>Reset Password - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
      Reset your password
    </h2>
    <p class="mt-2 text-center text-sm text-gray-600">
      Enter your email to receive a password reset link
    </p>
  </div>

  <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
      <PasswordResetForm on:success={() => goto('/auth/login')} />
    </div>
  </div>
</div> 