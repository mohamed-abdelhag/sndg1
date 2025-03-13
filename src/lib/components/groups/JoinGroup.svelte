<script lang="ts">
  import { supabase } from '$lib/auth/supabase';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import { onMount } from 'svelte';
  
  // Form state
  let groupId = '';
  let loading = false;
  let loadingGroupInfo = false;
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  
  // User state
  let userId = '';
  let canJoin = true;
  
  // Group info type
  type GroupInfo = {
    name: string;
    admin_name: string;
    type: string;
    monthly_contribution: number;
  };
  
  // Group info
  let groupInfo: GroupInfo | null = null;
  
  onMount(async () => {
    // Get current user
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      userId = session.user.id;
      
      // Check if user already belongs to a group
      const { data, error } = await supabase
        .from('users')
        .select('group_id')
        .eq('id', userId)
        .single();
      
      if (data && data.group_id) {
        canJoin = false;
      }
    }
  });
  
  async function lookupGroup() {
    if (!groupId) {
      errorMessage = 'Please enter a group ID';
      showError = true;
      return;
    }
    
    loadingGroupInfo = true;
    
    // Check if group exists and get basic info
    const { data, error } = await supabase
      .from('groups')
      .select(`
        name,
        type,
        monthly_contribution_amount,
        admin:created_by(email)
      `)
      .eq('id', groupId)
      .single();
    
    loadingGroupInfo = false;
    
    if (error || !data) {
      errorMessage = 'Group not found. Please check the ID and try again.';
      showError = true;
      groupInfo = null;
      return;
    }
    
    // Format group info for display
    groupInfo = {
      name: data.name,
      admin_name: typeof data.admin === 'object' && data.admin !== null ? (data.admin as any).email || 'Unknown' : 'Unknown',
      type: data.type === 'standard' ? 'Standard Savings' : 'Lottery',
      monthly_contribution: data.monthly_contribution_amount
    };
  }
  
  async function requestToJoin() {
    if (!groupId || !userId) {
      errorMessage = 'Unable to process request. Missing information.';
      showError = true;
      return;
    }
    
    if (!canJoin) {
      errorMessage = 'You already belong to a group and cannot join another.';
      showError = true;
      return;
    }
    
    // Check if user already has a pending request for this group
    const { data: existingRequest, error: requestError } = await supabase
      .from('group_join_requests')
      .select('status')
      .eq('user_id', userId)
      .eq('group_id', groupId)
      .eq('status', 'pending')
      .limit(1);
    
    if (existingRequest && existingRequest.length > 0) {
      errorMessage = 'You already have a pending request to join this group.';
      showError = true;
      return;
    }
    
    loading = true;
    
    // Create join request
    const { data, error } = await supabase
      .from('group_join_requests')
      .insert([
        { user_id: userId, group_id: groupId }
      ]);
    
    loading = false;
    
    if (error) {
      errorMessage = error.message || 'Failed to submit join request. Please try again.';
      showError = true;
    } else {
      successMessage = 'Your request to join the group has been submitted! The admin will review your request.';
      showSuccess = true;
    }
  }
</script>

<div class="space-y-6">
  <div>
    <label for="group-id" class="block text-sm font-medium text-gray-700">
      Group ID
    </label>
    <div class="mt-1 flex">
      <input
        id="group-id"
        type="text"
        bind:value={groupId}
        placeholder="Enter the group ID provided by the admin"
        class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
      />
      <Button 
        variant="secondary" 
        size="md" 
        on:click={lookupGroup} 
        loading={loadingGroupInfo}
      >
        Look up
      </Button>
    </div>
    <p class="mt-2 text-sm text-gray-500">
      You should receive this ID from the group admin, usually shared via WhatsApp or other means.
    </p>
  </div>
  
  {#if groupInfo}
    <div class="bg-gray-50 p-4 rounded-md border border-gray-200">
      <h3 class="text-lg font-medium text-gray-900">Group Information</h3>
      <dl class="mt-2 text-sm">
        <div class="grid grid-cols-3 gap-4 py-2">
          <dt class="text-gray-500">Name:</dt>
          <dd class="text-gray-900 col-span-2">{groupInfo.name}</dd>
        </div>
        <div class="grid grid-cols-3 gap-4 py-2">
          <dt class="text-gray-500">Admin:</dt>
          <dd class="text-gray-900 col-span-2">{groupInfo.admin_name}</dd>
        </div>
        <div class="grid grid-cols-3 gap-4 py-2">
          <dt class="text-gray-500">Type:</dt>
          <dd class="text-gray-900 col-span-2">{groupInfo.type}</dd>
        </div>
        <div class="grid grid-cols-3 gap-4 py-2">
          <dt class="text-gray-500">Monthly Contribution:</dt>
          <dd class="text-gray-900 col-span-2">${groupInfo.monthly_contribution}</dd>
        </div>
      </dl>
      
      <div class="mt-4">
        {#if canJoin}
          <Button 
            on:click={requestToJoin} 
            loading={loading}
          >
            Request to Join
          </Button>
        {:else}
          <div class="bg-amber-50 p-3 rounded-md border border-amber-200">
            <p class="text-sm text-amber-700">
              You already belong to a group and cannot join another one at this time.
            </p>
          </div>
        {/if}
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