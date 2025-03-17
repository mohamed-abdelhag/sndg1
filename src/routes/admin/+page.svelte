<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { goto } from '$app/navigation';
  import { requireAdmin } from '$lib/auth/middleware';
  import Button from '$lib/components/common/Button.svelte';
  
  let isLoading = true;
  let hasGroup = false;
  let groupId = '';
  let adminName = '';
  let pendingRequests = 0;
  
  // Load admin dashboard data
  onMount(async () => {
    try {
      // Verify admin status
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        goto('/auth/login');
        return;
      }
      
      // Get user details
      const { data: userData } = await supabase
        .from('users')
        .select('first_name, last_name, is_admin, group_id')
        .eq('id', session.user.id)
        .single();
        
      if (!userData || !userData.is_admin) {
        goto('/');
        return;
      }
      
      adminName = userData.first_name || 'Admin';
      
      // Check if admin has created a group
      if (userData.group_id) {
        hasGroup = true;
        groupId = userData.group_id;
        
        // If admin has a group, fetch pending join requests
        const { data: requestsData, error: requestsError } = await supabase
          .from('group_join_requests')
          .select('id')
          .eq('group_id', groupId)
          .eq('status', 'pending');
          
        if (!requestsError) {
          pendingRequests = requestsData.length;
        }
      }
      
      isLoading = false;
    } catch (error) {
      console.error('[Admin] Dashboard error:', error);
      isLoading = false;
    }
  });
  
  function goToCreateGroup() {
    goto('/admin/create-group');
  }
  
  function goToGroup() {
    goto(`/groups/${groupId}`);
  }
  
  function goToMemberRequests() {
    goto(`/groups/${groupId}/members/requests`);
  }
  
  function goToWithdrawalApprovals() {
    goto(`/groups/${groupId}/withdrawals/approvals`);
  }
  
  function goToGroupSettings() {
    goto(`/groups/${groupId}/settings`);
  }
</script>

<div class="container mx-auto px-4 py-8">
  {#if isLoading}
    <div class="flex justify-center items-center h-64">
      <div class="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div>
    </div>
  {:else}
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-4">Admin Dashboard</h1>
      <p class="text-gray-600 mb-6">Welcome, {adminName}! This is your admin control center.</p>
      
      {#if !hasGroup}
        <div class="bg-indigo-50 p-4 rounded-lg mb-6">
          <h2 class="font-semibold text-indigo-800 mb-2">You haven't created a group yet</h2>
          <p class="text-indigo-600 mb-4">As an admin, you can create and manage one savings group.</p>
          <Button on:click={goToCreateGroup} variant="primary">Create a Group</Button>
        </div>
      {:else}
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div class="bg-indigo-50 p-4 rounded-lg flex flex-col items-center justify-center">
            <h3 class="font-semibold text-indigo-800 mb-2">Your Group</h3>
            <Button on:click={goToGroup} variant="outline">Manage Group</Button>
          </div>
          
          <div class="bg-amber-50 p-4 rounded-lg flex flex-col items-center justify-center">
            <h3 class="font-semibold text-amber-800 mb-2">Join Requests</h3>
            {#if pendingRequests > 0}
              <div class="text-amber-600 font-bold mb-2">{pendingRequests} pending</div>
            {:else}
              <div class="text-amber-600 mb-2">No pending requests</div>
            {/if}
            <Button on:click={goToMemberRequests} variant="outline">Review Requests</Button>
          </div>
          
          <div class="bg-emerald-50 p-4 rounded-lg flex flex-col items-center justify-center">
            <h3 class="font-semibold text-emerald-800 mb-2">Withdrawal Approvals</h3>
            <Button on:click={goToWithdrawalApprovals} variant="outline">Manage Withdrawals</Button>
          </div>
        </div>
        
        <div class="border-t border-gray-200 pt-4 mt-4">
          <h3 class="font-semibold text-gray-700 mb-2">Group Settings</h3>
          <Button on:click={goToGroupSettings} variant="secondary">Configure Group</Button>
        </div>
      {/if}
    </div>
    
    <div class="bg-white rounded-lg shadow-md p-6">
      <h2 class="text-xl font-semibold text-gray-800 mb-4">Admin Flows</h2>
      <div class="space-y-4">
        <div class="p-4 border border-gray-200 rounded-lg">
          <h3 class="font-medium text-gray-700">1. Group Creation Flow</h3>
          <p class="text-sm text-gray-500">Create a new group and configure its settings</p>
        </div>
        
        <div class="p-4 border border-gray-200 rounded-lg">
          <h3 class="font-medium text-gray-700">2. Member Approval Flow</h3>
          <p class="text-sm text-gray-500">Review and approve member join requests</p>
        </div>
        
        <div class="p-4 border border-gray-200 rounded-lg">
          <h3 class="font-medium text-gray-700">3. Withdrawal Approval Flow</h3>
          <p class="text-sm text-gray-500">Review and approve withdrawal requests</p>
        </div>
        
        <div class="p-4 border border-gray-200 rounded-lg">
          <h3 class="font-medium text-gray-700">4. Group Management Flow</h3>
          <p class="text-sm text-gray-500">Manage group settings and view contribution matrix</p>
        </div>
      </div>
    </div>
  {/if}
</div> 