<script lang="ts">
  import LoginForm from '$lib/components/auth/LoginForm.svelte';
  import { goto } from '$app/navigation';
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
      <LoginForm on:success={() => goto('/')} />
      <div class="text-sm text-center mt-4">
        <a href="/auth/forgot-password" class="font-medium text-indigo-600 hover:text-indigo-500">
          Forgot your password?
        </a>
      </div>
    </div>
  </div>
</div> 