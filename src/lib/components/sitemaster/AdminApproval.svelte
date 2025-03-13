<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from '$lib/components/common/Button.svelte';
  
  // Define types
  interface AdminRequest {
    id: string;
    user_id: string;
    reason: string;
    status: 'pending' | 'approved' | 'rejected';
    requested_at: string;
    responded_at: string | null;
    users: {
      email: string;
      first_name?: string;
      last_name?: string;
    };
  }
  
  // Props
  export let request: AdminRequest;
  export let loading = false;
  
  // Event dispatcher
  const dispatch = createEventDispatcher<{
    approve: { id: string };
    reject: { id: string };
  }>();
  
  // Action handlers
  function handleApprove() {
    dispatch('approve', { id: request.id });
  }
  
  function handleReject() {
    dispatch('reject', { id: request.id });
  }
  
  // Format date
  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }
</script>

<li class="border-b border-gray-200 last:border-b-0">
  <div class="px-4 py-5 sm:px-6">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-lg leading-6 font-medium text-gray-900">
          {request.users?.email || 'Unknown User'}
        </h3>
        <p class="max-w-2xl text-sm text-gray-500 mt-1">
          {#if request.users?.first_name || request.users?.last_name}
            {request.users?.first_name || ''} {request.users?.last_name || ''}
          {:else}
            User ID: {request.user_id}
          {/if}
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
      <p class="mt-1 p-3 bg-gray-50 rounded-md">{request.reason || 'No reason provided'}</p>
    </div>
    
    <div class="mt-4 text-sm">
      <div class="flex space-x-4">
        <p class="text-gray-500">
          <span class="font-medium">Requested:</span> {formatDate(request.requested_at)}
        </p>
        {#if request.responded_at}
          <p class="text-gray-500">
            <span class="font-medium">Responded:</span> {formatDate(request.responded_at)}
          </p>
        {/if}
      </div>
    </div>
    
    {#if request.status === 'pending'}
      <div class="mt-4 flex space-x-3">
        <Button 
          on:click={handleApprove} 
          loading={loading} 
          disabled={loading}
          variant="primary"
          size="sm"
        >
          Approve
        </Button>
        <Button 
          on:click={handleReject} 
          loading={loading} 
          disabled={loading}
          variant="danger"
          size="sm"
        >
          Reject
        </Button>
      </div>
    {/if}
  </div>
</li> 