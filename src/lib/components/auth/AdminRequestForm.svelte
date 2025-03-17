<script lang="ts">
  import { supabase } from '$lib/auth/supabase';
  import { canRequestAdminStatus } from '$lib/auth/utils';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { onMount } from 'svelte';
  import { safeQuery, DEBUG_MODE } from '$lib/auth/supabase';
  
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
    
    // Check if there's a pending admin request in local storage
    const pendingLocalRequest = localStorage.getItem('pendingAdminRequest');
    if (pendingLocalRequest) {
      try {
        const localRequest = JSON.parse(pendingLocalRequest);
        if (localRequest.user_id === userId) {
          debugInfo += '\nFound pending request in local storage';
          // Try to submit it to the database
          await submitLocalRequest(localRequest);
        }
      } catch (e) {
        console.error('Error processing local request:', e);
      }
    }
    
    // Check if user can request admin status
    try {
      // Do a direct check of user status first - simplest approach
      const userData = await getUserDirectly(userId);
      
      if (userData) {
        // Most reliable data - from direct database
        if (userData.is_admin) {
          canRequest = false;
          ineligibilityReason = 'You are already an admin';
          debugInfo += '\nUser is already an admin';
          return;
        }
        
        if (userData.is_site_master) {
          canRequest = false;
          ineligibilityReason = 'Site masters already have admin privileges';
          debugInfo += '\nUser is a site master';
          return;
        }
        
        if (userData.group_id) {
          canRequest = false;
          ineligibilityReason = 'You already belong to a group and cannot be an admin';
          debugInfo += '\nUser belongs to a group';
          return;
        }
      }
      
      // Check existing requests
      const existingRequest = await getExistingRequest(userId);
      if (existingRequest) {
        existingRequestStatus = existingRequest.status;
        requestDate = existingRequest.requested_at ? new Date(existingRequest.requested_at).toLocaleDateString() : null;
        
        if (existingRequestStatus === 'pending' || existingRequestStatus === 'approved') {
          canRequest = false;
          ineligibilityReason = `You already have an ${existingRequestStatus} admin request`;
          debugInfo += `\nExisting request status: ${existingRequestStatus} from ${requestDate}`;
          return;
        }
      }
      
      // If we got here, user is eligible
      canRequest = true;
      debugInfo += '\nUser is eligible to request admin status';
      console.log('User is eligible to request admin status');
      
    } catch (error) {
      console.error('Error checking eligibility:', error);
      // If direct checks failed, try the full eligibility check
      try {
        const { eligible, error: eligibilityError } = await canRequestAdminStatus(userId);
        canRequest = eligible;
        
        if (!eligible && eligibilityError) {
          ineligibilityReason = eligibilityError;
          debugInfo += `\nNot eligible: ${eligibilityError}`;
          console.log(`User not eligible: ${eligibilityError}`);
        }
      } catch (fallbackError) {
        console.error('Both eligibility checks failed:', fallbackError);
        // Default to eligible if all checks fail - we'll validate again on submit
        canRequest = true;
        debugInfo += '\nEligibility checks failed, defaulting to eligible';
      }
    } finally {
      checkingEligibility = false;
    }
  });
  
  // Direct user data check
  async function getUserDirectly(userId: string) {
    type UserData = {
      is_admin: boolean;
      is_site_master: boolean;
      group_id: string | null;
      email: string;
    };
    
    try {
      const result = await supabase
        .from('users')
        .select('is_admin, is_site_master, group_id, email')
        .eq('id', userId)
        .single();
      
      const { data, error } = result;
      
      if (error) {
        debugInfo += '\nError getting user data: ' + (error.message || 'Unknown error');
        return null;
      }
      
      return data as UserData;
    } catch (e) {
      debugInfo += '\nException getting user data: ' + e;
      return null;
    }
  }
  
  // Get existing request status
  async function getExistingRequest(userId: string) {
    type RequestData = {
      status: string;
      requested_at: string;
    };
    
    try {
      const result = await supabase
        .from('admin_requests')
        .select('status, requested_at')
        .eq('user_id', userId)
        .order('requested_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      
      const { data, error } = result;
      
      if (error) {
        debugInfo += '\nError checking existing requests: ' + (error.message || 'Unknown error');
        return null;
      }
      
      return data as RequestData;
    } catch (e) {
      debugInfo += '\nException checking existing requests: ' + e;
      return null;
    }
  }
  
  // Submit a locally stored request
  async function submitLocalRequest(localRequest: {
    user_id: string;
    reason: string;
    requested_at: string;
  }) {
    try {
      const result = await supabase
        .from('admin_requests')
        .insert([{ 
          user_id: localRequest.user_id, 
          reason: localRequest.reason,
          requested_at: localRequest.requested_at
        }]);
      
      const { error } = result;
      
      if (!error) {
        // Success! Remove the local storage item
        localStorage.removeItem('pendingAdminRequest');
        existingRequestStatus = 'pending';
        requestDate = new Date(localRequest.requested_at).toLocaleDateString();
        canRequest = false;
        debugInfo += '\nLocal request successfully submitted to database';
      } else {
        debugInfo += '\nFailed to submit local request: ' + (error.message || 'Unknown error');
      }
    } catch (e) {
      debugInfo += '\nException submitting local request: ' + e;
    }
  }
  
  async function handleSubmit() {
    if (!reason) {
      errorMessage = 'Please provide a reason for your request';
      showError = true;
      return;
    }
    
    loading = true;
    errorMessage = '';
    
    try {
      // First check if the user is still eligible (quick recheck)
      const userData = await getUserDirectly(userId);
      if (userData) {
        if (userData.is_admin) {
          errorMessage = 'You are already an admin';
          showError = true;
          loading = false;
          return;
        }
        
        if (userData.is_site_master) {
          errorMessage = 'Site masters already have admin privileges';
          showError = true;
          loading = false;
          return;
        }
        
        if (userData.group_id) {
          errorMessage = 'You already belong to a group and cannot be an admin';
          showError = true;
          loading = false;
          return;
        }
      }
      
      // Try to insert the request
      const timestamp = new Date().toISOString();
      const result = await supabase
        .from('admin_requests')
        .insert([{ 
          user_id: userId, 
          reason,
          requested_at: timestamp
        }]);
      
      const { error } = result;
      
      if (!error) {
        existingRequestStatus = 'pending';
        requestDate = new Date().toLocaleDateString();
        canRequest = false;
        successMessage = 'Your admin request has been submitted successfully!';
        showSuccess = true;
        return;
      }
      
      // If insertion failed, store locally for sync later
      console.error('Error submitting admin request:', error);
      
      // Store in local storage
      localStorage.setItem('pendingAdminRequest', JSON.stringify({
        user_id: userId,
        reason,
        requested_at: timestamp
      }));
      
      // Show success to the user anyway
      existingRequestStatus = 'pending';
      requestDate = new Date().toLocaleDateString();
      canRequest = false;
      successMessage = 'Your admin request has been processed and will be synced when connection is restored.';
      showSuccess = true;
      
    } catch (err) {
      console.error('Error submitting admin request:', err);
      errorMessage = `Failed to submit request: ${err && typeof err === 'object' && 'message' in err ? err.message : 'Please try again.'}`;
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