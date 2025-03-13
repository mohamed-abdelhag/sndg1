<script lang="ts">
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { supabase } from '$lib/auth/supabase';
  
  let email = '';
  let loading = false;
  let errorMessage = '';
  let successMessage = '';
  let showError = false;
  let showSuccess = false;

  async function handleReset() {
    if (!email) {
      errorMessage = 'Please enter your email address';
      showError = true;
      return;
    }

    loading = true;
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${location.origin}/auth/update-password`
      });

      if (error) throw error;
      
      successMessage = 'Password reset email sent! Check your inbox.';
      showSuccess = true;
      errorMessage = '';
    } catch (err) {
      errorMessage = err.message || 'Failed to send reset email';
      showError = true;
    } finally {
      loading = false;
    }
  }
</script>

<form on:submit|preventDefault={handleReset} class="space-y-6">
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
    <Button type="submit" fullWidth={true} loading={loading}>
      Send Reset Link
    </Button>
  </div>
</form>

<Notification type="error" {message} bind:show={showError} on:close={() => showError = false} />
<Notification type="success" {message} bind:show={showSuccess} on:close={() => showSuccess = false} /> 