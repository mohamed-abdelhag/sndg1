<script lang="ts">
  import { loginUser } from '$lib/auth/utils';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { createEventDispatcher } from 'svelte';
  
  // Form state
  let email = '';
  let password = '';
  let loading = false;
  let errorMessage = '';
  let showError = false;
  
  const dispatch = createEventDispatcher();
  
  async function handleSubmit() {
    if (!email || !password) {
      errorMessage = 'Please enter both email and password';
      showError = true;
      return;
    }
    
    loading = true;
    const result = await loginUser(email, password);
    loading = false;
    
    if (!result.success) {
      errorMessage = result.error || 'Login failed. Please check your credentials.';
      showError = true;
    } else {
      dispatch('success');
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
        autocomplete="current-password"
        class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
      />
    </div>
  </div>
  
  <div class="flex items-center justify-between">
    <div class="flex items-center">
      <input
        id="remember-me"
        type="checkbox"
        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
      />
      <label for="remember-me" class="ml-2 block text-sm text-gray-900">Remember me</label>
    </div>
    
    <div class="text-sm">
      <a href="/auth/reset-password" class="font-medium text-indigo-600 hover:text-indigo-500">
        Forgot your password?
      </a>
    </div>
  </div>
  
  <div>
    <Button type="submit" fullWidth={true} loading={loading}>
      Sign in
    </Button>
  </div>
  
  <div class="text-center">
    <p class="text-sm text-gray-600">
      Don't have an account? <a href="/auth/signup" class="font-medium text-indigo-600 hover:text-indigo-500">Sign up</a>
    </p>
  </div>
</form>

<Notification
  type="error"
  message={errorMessage}
  bind:show={showError}
  on:close={() => (showError = false)}
/> 