<script lang="ts">
  import { supabase } from '$lib/auth/supabase';
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
  let canRequest = true;
  let existingRequestStatus: string | null = null;
  let requestDate: string | null = null;
  
  onMount(async () => {
    // Get current user
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      userId = session.user.id;
      
      try {
        // Check for existing request first
        const { data: requestData } = await supabase
          .from('admin_requests')
          .select('status, requested_at')
          .eq('user_id', userId)
          .order('requested_at', { ascending: false })
          .limit(1)
          .single();
        
        if (requestData) {
          existingRequestStatus = requestData.status;
          requestDate = new Date(requestData.requested_at).toLocaleDateString();
          canRequest = false;
          return;
        }
        
        // Only check eligibility if there's no existing request
        const { data: isEligible } = await supabase
          .rpc('check_admin_request_eligibility', { user_id: userId });
        
        canRequest = !!isEligible;
        
        if (!canRequest) {
          // Check if user is already an admin or has a group
          const { data: userData } = await supabase
            .from('users')
            .select('is_admin, is_site_master, group_id')
            .eq('id', userId)
            .single();
          
          if (userData?.is_admin || userData?.is_site_master) {
            errorMessage = 'You are already an admin';
          } else if (userData?.group_id) {
            errorMessage = 'You already belong to a group';
          }
          showError = true;
        }
      } catch (error) {
        console.error('Error checking admin request status:', error);
        errorMessage = 'Failed to check eligibility';
        showError = true;
      }
    }
  });
  
  async function handleSubmit() {
    if (!reason) {
      errorMessage = 'Please provide a reason for your request';
      showError = true;
      return;
    }
    
    if (!canRequest) {
      errorMessage = 'You are not eligible to request admin status';
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
    } catch (error) {
      console.error('Error submitting admin request:', error);
      errorMessage = 'Failed to submit request. Please try again.';
      showError = true;
    } finally {
      loading = false;
    }
  }
</script>

<div class="space-y-6">
  {#if existingRequestStatus}
    <div class="bg-gray-50 p-4 rounded-md border border-gray-200">
      <h3 class="text-lg font-medium text-gray-900">Your Admin Request</h3>
      <div class="mt-2">
        <p class="text-sm text-gray-500">
          Status: <span class="font-medium 
          {existingRequestStatus === 'pending' ? 'text-amber-600' : 
          existingRequestStatus === 'approved' ? 'text-emerald-600' : 
          'text-red-600'}">
            {existingRequestStatus.charAt(0).toUpperCase() + existingRequestStatus.slice(1)}
          </span>
        </p>
        {#if requestDate}
          <p class="text-sm text-gray-500">Submitted on: {requestDate}</p>
        {/if}
      </div>
      
      {#if existingRequestStatus === 'pending'}
        <div class="mt-3">
          <p class="text-sm text-gray-700">
            Your request is currently being reviewed. You'll be notified once a decision has been made.
          </p>
        </div>
      {:else if existingRequestStatus === 'approved'}
        <div class="mt-3">
          <p class="text-sm text-emerald-700">
            Congratulations! Your admin request has been approved. You can now create a group.
          </p>
          <div class="mt-2">
            <a href="/groups/new" class="text-indigo-600 hover:text-indigo-500 font-medium text-sm">
              Create a group →
            </a>
          </div>
        </div>
      {:else if existingRequestStatus === 'rejected'}
        <div class="mt-3">
          <p class="text-sm text-red-700">
            We're sorry, but your admin request has been rejected. You may join an existing group instead.
          </p>
          <div class="mt-2">
            <a href="/groups/join" class="text-indigo-600 hover:text-indigo-500 font-medium text-sm">
              Join a group →
            </a>
          </div>
        </div>
      {/if}
    </div>
  {:else if canRequest}
    <form on:submit|preventDefault={handleSubmit}>
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
          As an admin, you'll be able to create and manage a group.
        </p>
      </div>
      
      <div class="mt-4">
        <Button type="submit" loading={loading}>
          Submit Request
        </Button>
      </div>
    </form>
  {:else}
    <div class="bg-red-50 p-4 rounded-md border border-red-200">
      <h3 class="text-lg font-medium text-red-800">Not Eligible</h3>
      <div class="mt-2">
        <p class="text-sm text-red-700">
          You are not eligible to request admin status at this time. This could be because:
        </p>
        <ul class="list-disc pl-5 mt-1 text-sm text-red-700">
          <li>You are already an admin</li>
          <li>You already belong to a group</li>
          <li>You have a pending admin request</li>
        </ul>
      </div>
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