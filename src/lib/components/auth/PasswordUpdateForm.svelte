<script lang="ts">
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { supabase } from '$lib/auth/supabase';
  
  let password = '';
  let confirmPassword = '';
  let loading = false;
  let errorMessage = '';
  let successMessage = '';
  let showError = false;
  let showSuccess = false;

  async function handleUpdate() {
    if (password !== confirmPassword) {
      errorMessage = 'Passwords do not match';
      showError = true;
      return;
    }

    loading = true;
    try {
      const { error } = await supabase.auth.updateUser({
        password
      });

      if (error) throw error;
      
      successMessage = 'Password updated successfully!';
      showSuccess = true;
      errorMessage = '';
    } catch (err) {
      errorMessage = err instanceof Error ? err.message : 'Failed to update password';
      showError = true;
    } finally {
      loading = false;
    }
  }
</script>

<form on:submit|preventDefault={handleUpdate} class="space-y-6">
  <div>
    <label for="password" class="block text-sm font-medium text-gray-700">New Password</label>
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
      Update Password
    </Button>
  </div>
</form>

<Notification type="error" message={errorMessage} bind:show={showError} on:close={() => showError = false} />
<Notification type="success" message={successMessage} bind:show={showSuccess} on:close={() => showSuccess = false} /> 