<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { checkIfSiteMaster } from '$lib/auth/middleware';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  
  // Define types
  interface AdminRequest {
    id: string;
    user_id: string;
    reason: string;
    status: 'pending' | 'approved' | 'rejected';
    requested_at: string;
    responded_at: string | null;
    users?: {
      email: string;
      first_name?: string;
      last_name?: string;
    } | null;
  }
  
  let loading = true;
  let adminRequests: AdminRequest[] = [];
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  let processingId: string | null = null;
  
  onMount(async () => {
    try {
      // Check if user is site master
      const isSiteMaster = await checkIfSiteMaster();
      if (!isSiteMaster) {
        goto('/');
        return;
      }
      
      await loadAdminRequests();
    } catch (error) {
      console.error('Error:', error);
      errorMessage = 'Failed to load admin requests. Please try again.';
      showError = true;
    } finally {
      loading = false;
    }
  });
  
  async function loadAdminRequests() {
    const { data, error } = await supabase
      .from('admin_requests')
      .select(`
        id,
        user_id,
        reason,
        status,
        requested_at,
        responded_at,
        users:user_id (
          email,
          first_name,
          last_name
        )
      `)
      .order('requested_at', { ascending: false });
      
    if (error) {
      console.error('Error loading requests:', error);
      errorMessage = 'Failed to load admin requests. Please try again.';
      showError = true;
      return;
    }
    
    adminRequests = (data || []) as AdminRequest[];
  }
  
  async function approveRequest(requestId: string) {
    processingId = requestId;
    try {
      // Get current user
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        errorMessage = 'You must be logged in to approve requests.';
        showError = true;
        return;
      }
      
      // Call the RPC function
      const { error } = await supabase.rpc('approve_admin_request', {
        request_id: requestId,
        site_master_id: session.user.id
      });
      
      if (error) {
        console.error('Error approving request:', error);
        errorMessage = 'Failed to approve request. Please try again.';
        showError = true;
        return;
      }
      
      // Update the local state
      adminRequests = adminRequests.map(request => {
        if (request.id === requestId) {
          return {
            ...request,
            status: 'approved',
            responded_at: new Date().toISOString()
          };
        }
        return request;
      });
      
      successMessage = 'Admin request approved successfully!';
      showSuccess = true;
    } catch (error) {
      console.error('Error:', error);
      errorMessage = 'Failed to approve request. Please try again.';
      showError = true;
    } finally {
      processingId = null;
    }
  }
  
  async function rejectRequest(requestId: string) {
    processingId = requestId;
    try {
      // Get current user
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        errorMessage = 'You must be logged in to reject requests.';
        showError = true;
        return;
      }
      
      // Call the RPC function
      const { error } = await supabase.rpc('reject_admin_request', {
        request_id: requestId,
        site_master_id: session.user.id
      });
      
      if (error) {
        console.error('Error rejecting request:', error);
        errorMessage = 'Failed to reject request. Please try again.';
        showError = true;
        return;
      }
      
      // Update the local state
      adminRequests = adminRequests.map(request => {
        if (request.id === requestId) {
          return {
            ...request,
            status: 'rejected',
            responded_at: new Date().toISOString()
          };
        }
        return request;
      });
      
      successMessage = 'Admin request rejected successfully!';
      showSuccess = true;
    } catch (error) {
      console.error('Error:', error);
      errorMessage = 'Failed to reject request. Please try again.';
      showError = true;
    } finally {
      processingId = null;
    }
  }
  
  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }
</script>

<svelte:head>
  <title>Admin Request Approvals | Sandoog</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
  <div class="mb-8 flex justify-between items-center">
    <div>
      <h1 class="text-3xl font-bold text-gray-900">Admin Request Approvals</h1>
      <p class="mt-2 text-sm text-gray-500">
        Review and manage admin role requests from users
      </p>
    </div>
    <div>
      <a href="/sitemaster" class="text-indigo-600 hover:text-indigo-500">
        ← Back to Dashboard
      </a>
    </div>
  </div>
  
  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-indigo-500"></div>
    </div>
  {:else if adminRequests.length === 0}
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <div class="px-4 py-5 sm:p-6 text-center">
        <p class="text-gray-500">No admin requests found.</p>
      </div>
    </div>
  {:else}
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul class="divide-y divide-gray-200">
        {#each adminRequests as request}
          <li>
            <div class="px-4 py-5 sm:px-6">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    {request.users?.email || 'Unknown User'}
                  </h3>
                  <p class="max-w-2xl text-sm text-gray-500 mt-1">
                    {request.users?.first_name} {request.users?.last_name}
                  </p>
                </div>
                <div>
                  <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full
                    {request.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 
                    request.status === 'approved' ? 'bg-green-100 text-green-800' : 
                    'bg-red-100 text-red-800'}">
                    {request.status.charAt(0).toUpperCase() + request.status.slice(1)}
                  </span>
                </div>
              </div>
              
              <div class="mt-4 max-w-2xl text-sm text-gray-500">
                <p class="font-medium">Request Reason:</p>
                <p class="mt-1">{request.reason || 'No reason provided'}</p>
              </div>
              
              <div class="mt-4 text-sm">
                <div class="flex space-x-4">
                  <p class="text-gray-500">
                    Requested: {formatDate(request.requested_at)}
                  </p>
                  {#if request.responded_at}
                    <p class="text-gray-500">
                      Responded: {formatDate(request.responded_at)}
                    </p>
                  {/if}
                </div>
                
                {#if request.status === 'pending'}
                  <div class="mt-4 flex space-x-3">
                    <Button 
                      type="button" 
                      variant="primary"
                      loading={processingId === request.id}
                      disabled={processingId !== null}
                      on:click={() => approveRequest(request.id)}>
                      Approve
                    </Button>
                    <Button 
                      type="button" 
                      variant="danger"
                      loading={processingId === request.id}
                      disabled={processingId !== null}
                      on:click={() => rejectRequest(request.id)}>
                      Reject
                    </Button>
                  </div>
                {/if}
              </div>
            </div>
          </li>
        {/each}
      </ul>
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