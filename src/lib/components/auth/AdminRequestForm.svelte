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
  let canRequest = true;
  let existingRequestStatus: string | null = null;
  let requestDate: string | null = null;
  let ineligibilityReason: string | null = null;
  let checkingEligibility = true;
  
  onMount(async () => {
    // Get current user
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      userId = session.user.id;
      userEmail = session.user.email || '';
      
      try {
        // Use our improved eligibility check function to check for existing requests
        const { eligible, error: eligibilityError } = await canRequestAdminStatus(userId);
        
        if (!eligible) {
          canRequest = false;
          ineligibilityReason = eligibilityError || 'You are not eligible to request admin status';
          
          // Check if there's an existing request to show the status
          const { data: requestData, error: requestError } = await supabase
            .from('admin_requests')
            .select('status, requested_at')
            .eq('user_id', userId)
            .order('requested_at', { ascending: false })
            .limit(1);
            
          if (!requestError && requestData && requestData.length > 0) {
            existingRequestStatus = requestData[0].status;
            requestDate = new Date(requestData[0].requested_at).toLocaleDateString();
          }
          
          checkingEligibility = false;
          return;
        }
        
        // If we get here, user is eligible
        canRequest = true;
        checkingEligibility = false;
        
      } catch (error) {
        console.error('Error checking admin request status:', error);
        errorMessage = 'Failed to check eligibility. Please try again.';
        showError = true;
        canRequest = false;
        checkingEligibility = false;
      }
    } else {
      // User is not logged in
      canRequest = false;
      ineligibilityReason = 'You must be logged in to request admin status.';
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

<div class="space-y-6">
  {#if checkingEligibility}
    <div class="flex items-center justify-center py-6">
      <div class="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-indigo-500"></div>
      <span class="ml-3 text-sm text-gray-500">Checking eligibility...</span>
    </div>
  {:else if existingRequestStatus}
    <div class="bg-gray-50 p-6 rounded-md border border-gray-200">
      <h3 class="text-lg font-medium text-gray-900">Your Admin Request</h3>
      <div class="mt-3">
        <div class="flex items-center">
          <span class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full
            {existingRequestStatus === 'pending' ? 'bg-yellow-100 text-yellow-800' : 
            existingRequestStatus === 'approved' ? 'bg-green-100 text-green-800' : 
            'bg-red-100 text-red-800'}">
            {existingRequestStatus.charAt(0).toUpperCase() + existingRequestStatus.slice(1)}
          </span>
          {#if requestDate}
            <span class="ml-2 text-sm text-gray-500">Submitted on: {requestDate}</span>
          {/if}
        </div>
      </div>
      
      {#if existingRequestStatus === 'pending'}
        <div class="mt-4 p-4 bg-yellow-50 border border-yellow-100 rounded-md">
          <p class="text-sm text-yellow-800">
            <svg class="inline-block w-5 h-5 mr-2 -mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            Your request is currently being reviewed by a site master. You'll be notified once a decision has been made.
          </p>
        </div>
      {:else if existingRequestStatus === 'approved'}
        <div class="mt-4 p-4 bg-green-50 border border-green-100 rounded-md">
          <p class="text-sm text-green-800">
            <svg class="inline-block w-5 h-5 mr-2 -mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
            Congratulations! Your admin request has been approved. You can now create a group.
          </p>
          <div class="mt-4">
            <a href="/groups/new" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Create a group
            </a>
          </div>
        </div>
      {:else if existingRequestStatus === 'rejected'}
        <div class="mt-4 p-4 bg-red-50 border border-red-100 rounded-md">
          <p class="text-sm text-red-800">
            <svg class="inline-block w-5 h-5 mr-2 -mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
            We're sorry, but your admin request has been rejected. You may join an existing group instead.
          </p>
          <div class="mt-4">
            <a href="/groups/join" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Join a group
            </a>
          </div>
        </div>
      {/if}
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
    <div class="bg-red-50 p-6 rounded-md border border-red-200">
      <h3 class="text-lg font-medium text-red-800">Cannot Request Admin Status</h3>
      
      <div class="mt-4 p-4 bg-white rounded-md border border-red-100">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">Reason:</h3>
            <div class="mt-2 text-sm text-red-700">
              <p>{ineligibilityReason || 'You are not eligible to request admin status at this time.'}</p>
            </div>
          </div>
        </div>
      </div>
      
      {#if !ineligibilityReason?.includes('already an admin') && !ineligibilityReason?.includes('site master')}
        <div class="mt-4">
          <a href="/groups/join" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Join an existing group instead
          </a>
        </div>
      {:else if ineligibilityReason?.includes('already an admin')}
        <div class="mt-4">
          <a href="/groups/new" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Create a group
          </a>
        </div>
      {/if}
    </div>
  {/if}
</div>

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