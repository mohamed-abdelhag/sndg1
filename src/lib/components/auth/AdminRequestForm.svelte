<script lang="ts">
  import { supabase } from '$lib/auth/supabase';
  import { canRequestAdminStatus } from '$lib/auth/utils';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { onMount } from 'svelte';
  
  // Form state
  let reason = '';
  let loading = false;
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  
  // User state
  let userId = '';
  let userEmail = '';
  let canRequest = false;  // Default to false until we check
  let existingRequestStatus: string | null = null;
  let requestDate: string | null = null;
  let ineligibilityReason: string | null = null;
  let checkingEligibility = true;
  let debugInfo = '';
  
  onMount(async () => {
    // Get current user
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session) {
      errorMessage = 'You must be logged in to request admin status';
      showError = true;
      return;
    }
    
    userId = session.user.id;
    userEmail = session.user.email || '';
    
    debugInfo = `Checking eligibility for user: ${userEmail} (${userId})`;
    console.log(debugInfo);
    
    // Check if user can request admin status
    try {
      const { eligible, error } = await canRequestAdminStatus(userId);
      canRequest = eligible;
      
      if (!eligible && error) {
        ineligibilityReason = error;
        debugInfo += `\nNot eligible: ${error}`;
        console.log(`User not eligible: ${error}`);
      } else if (eligible) {
        debugInfo += `\nUser is eligible to request admin status`;
        console.log('User is eligible to request admin status');
      }
      
      // Check if user already has a pending or approved request
      const { data, error: requestError } = await supabase
        .from('admin_requests')
        .select('status, requested_at')
        .eq('user_id', userId)
        .order('requested_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      
      if (data) {
        existingRequestStatus = data.status;
        requestDate = data.requested_at ? new Date(data.requested_at).toLocaleDateString() : null;
        
        if (existingRequestStatus === 'pending' || existingRequestStatus === 'approved') {
          canRequest = false;
          ineligibilityReason = `You already have an ${existingRequestStatus} admin request`;
          debugInfo += `\nExisting request status: ${existingRequestStatus} from ${requestDate}`;
        }
      }
    } catch (error) {
      console.error('Error checking eligibility:', error);
      errorMessage = 'Failed to check eligibility. Please try again later.';
      showError = true;
      debugInfo += `\nError: ${JSON.stringify(error)}`;
    } finally {
      checkingEligibility = false;
    }
  });
  
  async function handleSubmit() {
    if (!reason) {
      errorMessage = 'Please provide a reason for your request';
      showError = true;
      return;
    }
    
    if (!canRequest) {
      errorMessage = ineligibilityReason || 'You are not eligible to request admin status';
      showError = true;
      return;
    }
    
    loading = true;
    try {
      const { error } = await supabase
        .from('admin_requests')
        .insert([{ user_id: userId, reason }]);
      
      if (error) throw error;
      
      existingRequestStatus = 'pending';
      requestDate = new Date().toLocaleDateString();
      canRequest = false;
      successMessage = 'Your admin request has been submitted successfully!';
      showSuccess = true;
    } catch (error: any) {
      console.error('Error submitting admin request:', error);
      errorMessage = `Failed to submit request: ${error.message || 'Please try again.'}`;
      showError = true;
    } finally {
      loading = false;
    }
  }
</script>

{#if checkingEligibility}
  <div class="flex justify-center py-6">
    <div class="animate-pulse">
      <p class="text-gray-600">Checking eligibility...</p>
    </div>
  </div>
{:else if showError}
  <div class="bg-red-50 border-l-4 border-red-500 p-4 mb-4">
    <div class="flex">
      <div class="ml-3">
        <p class="text-sm text-red-700">{errorMessage}</p>
      </div>
    </div>
  </div>
  
  <!-- Debug information in development -->
  <div class="bg-gray-100 rounded p-3 text-xs mb-4">
    <strong>Debug Info:</strong>
    <pre>{debugInfo}</pre>
  </div>
  
  <div class="flex justify-center">
    <a href="/" class="text-indigo-600 hover:text-indigo-900">Return to Home</a>
  </div>
{:else if showSuccess}
  <div class="bg-green-50 border-l-4 border-green-500 p-4 mb-4">
    <div class="flex">
      <div class="ml-3">
        <p class="text-sm text-green-700">{successMessage}</p>
        <p class="text-sm text-green-700 mt-2">
          Your request status: <span class="font-semibold">{existingRequestStatus}</span>
          {#if requestDate} (submitted on {requestDate}){/if}
        </p>
      </div>
    </div>
  </div>
  
  <div class="flex justify-center">
    <a href="/" class="text-indigo-600 hover:text-indigo-900">Return to Home</a>
  </div>
{:else if existingRequestStatus}
  <div class="bg-yellow-50 p-4 rounded-md">
    <h3 class="text-lg font-medium text-yellow-800">Existing Admin Request</h3>
    <div class="mt-2">
      <p class="text-yellow-700">
        You already have an admin request with status: <span class="font-semibold">{existingRequestStatus}</span>
        {#if requestDate} (from {requestDate}){/if}
      </p>
      
      {#if existingRequestStatus === 'pending'}
        <p class="mt-2 text-yellow-700">Your request is being reviewed by site administrators.</p>
      {:else if existingRequestStatus === 'approved'}
        <p class="mt-2 text-yellow-700">Your request has been approved! You now have admin privileges.</p>
      {:else if existingRequestStatus === 'rejected'}
        <p class="mt-2 text-yellow-700">Your previous request was rejected. You may submit a new request.</p>
      {/if}
    </div>
  </div>
{:else if canRequest}
  <form on:submit|preventDefault={handleSubmit} class="space-y-6">
    <div class="bg-yellow-50 p-4 rounded-md border border-yellow-100">
      <h3 class="text-sm font-medium text-yellow-800">Important Information</h3>
      <div class="mt-2 text-sm text-yellow-700">
        <p>As an admin:</p>
        <ul class="list-disc pl-5 space-y-1 mt-2">
          <li>You will be able to create and manage a savings group</li>
          <li>You will be responsible for approving member requests and withdrawals</li>
          <li>You cannot join other groups once you become an admin</li>
        </ul>
      </div>
    </div>
    
    <div>
      <label for="reason" class="block text-sm font-medium text-gray-700">
        Why do you want to become an admin?
      </label>
      <div class="mt-1">
        <textarea
          id="reason"
          bind:value={reason}
          rows="4"
          class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
          placeholder="Please explain why you want to become an admin and create a group..."
        ></textarea>
      </div>
      <p class="mt-2 text-sm text-gray-500">
        Please provide a detailed explanation. Site masters will review your request.
      </p>
    </div>
    
    <div>
      <Button type="submit" loading={loading} variant="primary" fullWidth={true}>
        Submit Request
      </Button>
    </div>
  </form>
{:else}
  <div class="bg-red-50 p-4 rounded-md">
    <h3 class="text-lg font-medium text-red-800">Not Eligible</h3>
    <div class="mt-2">
      <p class="text-red-700">
        {ineligibilityReason || "You are not eligible to request admin status."}
      </p>
    </div>
    
    <!-- Debug information in development -->
    <div class="mt-4 bg-gray-100 rounded p-3 text-xs">
      <strong>Debug Info:</strong>
      <pre>{debugInfo}</pre>
    </div>
  </div>
{/if}

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