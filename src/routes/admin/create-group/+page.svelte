<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { goto } from '$app/navigation';
  import { requireAdmin } from '$lib/auth/middleware';
  import Button from '$lib/components/common/Button.svelte';
  import { page } from '$app/stores';
  
  let isLoading = true;
  let isSubmitting = false;
  let errorMessage = '';
  let successMessage = '';
  
  // Form data
  let name = '';
  let description = '';
  let type: 'standard' | 'lottery' = 'standard';
  let monthlyContributionAmount = 500;
  let startDate = new Date().toISOString().slice(0, 7); // YYYY-MM format
  
  onMount(async () => {
    try {
      // Check if user is admin
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        goto('/auth/login');
        return;
      }
      
      // Check if admin already has a group
      const { data: userData } = await supabase
        .from('users')
        .select('is_admin, group_id')
        .eq('id', session.user.id)
        .single();
        
      if (!userData || !userData.is_admin) {
        goto('/');
        return;
      }
      
      // If admin already has a group, redirect to group page
      if (userData.group_id) {
        goto(`/groups/${userData.group_id}`);
        return;
      }
      
      isLoading = false;
    } catch (error) {
      console.error('[Admin] Create group error:', error);
      errorMessage = 'Failed to load page';
      isLoading = false;
    }
  });
  
  async function createGroup() {
    try {
      isSubmitting = true;
      errorMessage = '';
      
      // Validate form
      if (!name || !description || !startDate) {
        errorMessage = 'Please fill all required fields';
        isSubmitting = false;
        return;
      }
      
      if (monthlyContributionAmount <= 0) {
        errorMessage = 'Monthly contribution must be greater than 0';
        isSubmitting = false;
        return;
      }
      
      // Get current user
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        goto('/auth/login');
        return;
      }
      
      // Create group
      const { data: groupData, error: groupError } = await supabase
        .from('groups')
        .insert({
          name,
          description,
          type,
          created_by: session.user.id,
          monthly_contribution_amount: monthlyContributionAmount,
          total_pool: 0,
          start_month_year: `${startDate}-01` // Add day to make a complete date
        })
        .select('id')
        .single();
        
      if (groupError) {
        console.error('[Admin] Group creation error:', groupError);
        errorMessage = 'Failed to create group: ' + groupError.message;
        isSubmitting = false;
        return;
      }
      
      // Call the create_group_tables function 
      const { error: tablesError } = await supabase.rpc('create_group_tables', {
        group_id: groupData.id
      });
      
      if (tablesError) {
        console.error('[Admin] Create tables error:', tablesError);
        errorMessage = 'Failed to create group tables: ' + tablesError.message;
        
        // Clean up the group if tables couldn't be created
        await supabase.from('groups').delete().eq('id', groupData.id);
        
        isSubmitting = false;
        return;
      }
      
      // Update user's group_id
      const { error: userError } = await supabase
        .from('users')
        .update({ group_id: groupData.id })
        .eq('id', session.user.id);
        
      if (userError) {
        console.error('[Admin] User update error:', userError);
        errorMessage = 'Failed to update user: ' + userError.message;
        isSubmitting = false;
        return;
      }
      
      // Success! Redirect to group page
      successMessage = 'Group created successfully!';
      setTimeout(() => {
        goto(`/groups/${groupData.id}`);
      }, 1500);
      
    } catch (error) {
      console.error('[Admin] Create group error:', error);
      errorMessage = 'An unexpected error occurred';
      isSubmitting = false;
    }
  }
</script>

<div class="container mx-auto px-4 py-8">
  {#if isLoading}
    <div class="flex justify-center items-center h-64">
      <div class="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-indigo-500"></div>
    </div>
  {:else}
    <div class="max-w-2xl mx-auto bg-white rounded-lg shadow-md p-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-6">Create a Savings Group</h1>
      
      {#if errorMessage}
        <div class="bg-red-50 text-red-600 p-4 rounded-lg mb-6">
          {errorMessage}
        </div>
      {/if}
      
      {#if successMessage}
        <div class="bg-green-50 text-green-600 p-4 rounded-lg mb-6">
          {successMessage}
        </div>
      {/if}
      
      <form on:submit|preventDefault={createGroup} class="space-y-6">
        <div>
          <label for="name" class="block text-sm font-medium text-gray-700 mb-1">Group Name *</label>
          <input
            type="text"
            id="name"
            bind:value={name}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            required
          />
        </div>
        
        <div>
          <label for="description" class="block text-sm font-medium text-gray-700 mb-1">Description *</label>
          <textarea
            id="description"
            bind:value={description}
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            required
          ></textarea>
        </div>
        
        <div>
          <fieldset>
            <legend class="block text-sm font-medium text-gray-700 mb-1">Group Type *</legend>
            <div class="flex space-x-4">
              <label class="inline-flex items-center">
                <input 
                  type="radio" 
                  name="type" 
                  value="standard" 
                  bind:group={type} 
                  class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                />
                <span class="ml-2">Standard Savings Group</span>
              </label>
              <label class="inline-flex items-center">
                <input 
                  type="radio" 
                  name="type" 
                  value="lottery" 
                  bind:group={type}
                  class="h-4 w-4 text-indigo-600 border-gray-300 focus:ring-indigo-500"
                />
                <span class="ml-2">Lottery Group</span>
              </label>
            </div>
          </fieldset>
        </div>
        
        <div>
          <label for="contribution" class="block text-sm font-medium text-gray-700 mb-1">
            Monthly Contribution Amount *
          </label>
          <div class="relative rounded-md shadow-sm">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <span class="text-gray-500 sm:text-sm">$</span>
            </div>
            <input
              type="number"
              id="contribution"
              bind:value={monthlyContributionAmount}
              min="1"
              step="1"
              class="w-full pl-7 pr-12 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              required
            />
          </div>
        </div>
        
        <div>
          <label for="startDate" class="block text-sm font-medium text-gray-700 mb-1">
            Start Month/Year *
          </label>
          <input
            type="month"
            id="startDate"
            bind:value={startDate}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            required
          />
        </div>
        
        <div class="flex items-center justify-between pt-4">
          <button
            type="button"
            on:click={() => goto('/admin')}
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Back to Dashboard
          </button>
          
          <button
            type="submit"
            disabled={isSubmitting}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {#if isSubmitting}
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Creating...
            {:else}
              Create Group
            {/if}
          </button>
        </div>
      </form>
    </div>
  {/if}
</div> 