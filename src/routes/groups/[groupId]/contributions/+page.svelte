<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  
  // Define types
  interface ContributionEntry {
    month_number: number;
    user_id: string;
    contribution: string;
    contribution_date: string;
    updated_at: string;
  }
  
  interface GroupMember {
    id: string;
    email: string;
    first_name?: string;
    last_name?: string;
  }
  
  // Page state
  let loading = true;
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  
  // Group data
  let groupId = '';
  let groupName = '';
  let monthlyContributionAmount = 0;
  let groupStartDate = '';
  let currentMonth = 0;
  
  // User data
  let userId = '';
  let isAdmin = false;
  let userContributions: ContributionEntry[] = [];
  
  // Contribution matrix
  let contributionMatrix: ContributionEntry[] = [];
  let groupMembers: GroupMember[] = [];
  
  // New contribution
  let contributionAmount = 0;
  let paymentMethod = 'cash';
  let notes = '';
  let submitting = false;
  
  onMount(async () => {
    try {
      // Get the group ID from the URL
      groupId = $page.params.groupId;
      
      // Check user session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        goto('/auth/login');
        return;
      }
      
      userId = session.user.id;
      
      // Get user data
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('is_admin, group_id')
        .eq('id', userId)
        .single();
      
      if (userError) throw userError;
      
      // Verify user belongs to this group
      if (userData.group_id !== groupId) {
        errorMessage = 'You do not have access to this group';
        showError = true;
        goto('/');
        return;
      }
      
      isAdmin = userData.is_admin;
      
      // Get group data
      const { data: groupData, error: groupError } = await supabase
        .from('groups')
        .select('name, monthly_contribution, start_date')
        .eq('id', groupId)
        .single();
      
      if (groupError) throw groupError;
      
      groupName = groupData.name;
      monthlyContributionAmount = groupData.monthly_contribution;
      groupStartDate = groupData.start_date;
      
      // Calculate current month number based on start date
      const startDate = new Date(groupStartDate);
      const now = new Date();
      const diffMonths = (now.getFullYear() - startDate.getFullYear()) * 12 + (now.getMonth() - startDate.getMonth());
      currentMonth = Math.max(1, diffMonths + 1); // Month 1 is the first month
      
      // Get contribution matrix table name
      const { data: tableData, error: tableError } = await supabase
        .from('group_tables')
        .select('table_name')
        .eq('group_id', groupId)
        .eq('table_type', 'contribution_matrix')
        .single();
      
      if (tableError) {
        console.error('Error fetching matrix table:', tableError);
        throw new Error('Could not find contribution matrix for this group');
      }
      
      const matrixTableName = tableData.table_name;
      
      // Get group members
      const { data: members, error: membersError } = await supabase
        .from('users')
        .select('id, email, first_name, last_name')
        .eq('group_id', groupId);
      
      if (membersError) throw membersError;
      
      groupMembers = members as GroupMember[];
      
      // Get contribution matrix - this is a custom query to the dynamic table
      const { data: matrix, error: matrixError } = await supabase.rpc(
        'get_contribution_matrix',
        { p_group_id: groupId }
      );
      
      if (matrixError) {
        console.error('Error fetching matrix:', matrixError);
        // Fallback: Direct query to the table (might need admin rights)
        const { data: directMatrix, error: directError } = await supabase
          .from(matrixTableName)
          .select('*')
          .order('month_number');
          
        if (directError) {
          throw new Error('Could not load contribution matrix');
        }
        
        contributionMatrix = directMatrix as ContributionEntry[] || [];
      } else {
        contributionMatrix = matrix as ContributionEntry[] || [];
      }
      
      // Set default contribution amount
      contributionAmount = monthlyContributionAmount;
      
    } catch (error) {
      console.error('Error loading contributions:', error);
      errorMessage = 'Failed to load contribution data';
      showError = true;
    } finally {
      loading = false;
    }
  });
  
  // Function to handle contribution submission
  async function submitContribution() {
    if (contributionAmount <= 0) {
      errorMessage = 'Please enter a valid contribution amount';
      showError = true;
      return;
    }
    
    submitting = true;
    
    try {
      // Get any outstanding payback amount for this user
      const { data: paybackData, error: paybackError } = await supabase.rpc(
        'get_user_payback_amount',
        { p_user_id: userId, p_group_id: groupId }
      );
      
      let paybackAmount = 0;
      if (!paybackError && paybackData) {
        paybackAmount = paybackData;
      }
      
      // Record the contribution using the function
      const { error } = await supabase.rpc(
        'record_contribution',
        {
          p_group_id: groupId,
          p_user_id: userId,
          p_month_number: currentMonth,
          p_amount: contributionAmount,
          p_payback_amount: paybackAmount,
          p_is_withdrawal: false
        }
      );
      
      if (error) throw error;
      
      // Success!
      successMessage = 'Contribution recorded successfully!';
      showSuccess = true;
      
      // Refresh the data
      setTimeout(() => {
        window.location.reload();
      }, 2000);
      
    } catch (error) {
      console.error('Error submitting contribution:', error);
      errorMessage = 'Failed to record contribution. Please try again.';
      showError = true;
    } finally {
      submitting = false;
    }
  }
  
  // Helper function to get member name
  function getMemberName(memberId: string): string {
    const member = groupMembers.find(m => m.id === memberId);
    if (!member) return 'Unknown';
    
    if (member.first_name || member.last_name) {
      return `${member.first_name || ''} ${member.last_name || ''}`.trim();
    }
    
    return member.email.split('@')[0];
  }
  
  // Helper function to format contribution display
  function formatContribution(contribution: string): string {
    if (!contribution || contribution === '+0') return '-';
    
    // Parse the contribution string (e.g. "+500+200" or "+500-1000")
    const matches = contribution.match(/\+(\d+)(?:([+-])(\d+))?/);
    if (!matches) return contribution;
    
    const [_, base, operator, additional] = matches;
    
    if (!operator) {
      return `+${base}`;
    }
    
    if (operator === '+') {
      return `+${base} +${additional} (payback)`;
    }
    
    if (operator === '-') {
      return `+${base} -${additional} (withdrawal)`;
    }
    
    return contribution;
  }
  
  // Helper to check if user has contributed for current month
  function hasContributedThisMonth(): boolean {
    const currentMonthEntry = contributionMatrix.find(
      entry => entry.month_number === currentMonth && entry.user_id === userId
    );
    
    return !!currentMonthEntry && currentMonthEntry.contribution !== '+0';
  }
</script>

<svelte:head>
  <title>Contributions | {groupName}</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
  <div class="mb-8 flex justify-between items-center">
    <div>
      <h1 class="text-3xl font-bold text-gray-900">Contributions</h1>
      <p class="mt-2 text-sm text-gray-500">
        Track and manage your monthly contributions for {groupName}
      </p>
    </div>
    <div>
      <a href="/groups/{groupId}" class="text-indigo-600 hover:text-indigo-500">
        ← Back to Group
      </a>
    </div>
  </div>
  
  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-indigo-500"></div>
    </div>
  {:else}
    <!-- Current Month Contribution Panel -->
    <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
      <div class="px-4 py-5 sm:px-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900">
          Current Month (Month {currentMonth})
        </h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500">
          Monthly contribution amount: ${monthlyContributionAmount.toFixed(2)}
        </p>
      </div>
      
      {#if hasContributedThisMonth()}
        <div class="border-t border-gray-200 px-4 py-5 sm:px-6 bg-green-50">
          <p class="text-green-700 font-medium">
            You have already contributed for this month.
          </p>
        </div>
      {:else}
        <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
            <div class="sm:col-span-3">
              <label for="amount" class="block text-sm font-medium text-gray-700">
                Contribution Amount
              </label>
              <div class="mt-1 relative rounded-md shadow-sm">
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <span class="text-gray-500 sm:text-sm">$</span>
                </div>
                <input
                  type="number"
                  name="amount"
                  id="amount"
                  bind:value={contributionAmount}
                  class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-7 pr-12 sm:text-sm border-gray-300 rounded-md"
                  placeholder="0.00"
                  step="0.01"
                  min="0"
                />
              </div>
            </div>
            
            <div class="sm:col-span-3">
              <label for="payment-method" class="block text-sm font-medium text-gray-700">
                Payment Method
              </label>
              <select
                id="payment-method"
                name="payment-method"
                bind:value={paymentMethod}
                class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
              >
                <option value="cash">Cash</option>
                <option value="transfer">Bank Transfer</option>
                <option value="mobile">Mobile Money</option>
                <option value="other">Other</option>
              </select>
            </div>
            
            <div class="sm:col-span-6">
              <label for="notes" class="block text-sm font-medium text-gray-700">
                Notes (Optional)
              </label>
              <div class="mt-1">
                <textarea
                  id="notes"
                  name="notes"
                  rows="3"
                  bind:value={notes}
                  class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="Any additional information about your contribution"
                ></textarea>
              </div>
            </div>
          </div>
          
          <div class="mt-5">
            <Button
              on:click={submitContribution}
              loading={submitting}
              disabled={submitting || contributionAmount <= 0}
            >
              Submit Contribution
            </Button>
          </div>
        </div>
      {/if}
    </div>
    
    <!-- Contribution Matrix -->
    <div class="bg-white shadow overflow-hidden sm:rounded-lg">
      <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
        <h3 class="text-lg leading-6 font-medium text-gray-900">
          Contribution Matrix
        </h3>
        
        {#if isAdmin}
          <a
            href="/groups/{groupId}/contributions/export"
            class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Export as CSV
          </a>
        {/if}
      </div>
      
      <div class="border-t border-gray-200 px-4 py-5 sm:p-0">
        <div class="sm:overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Month
                </th>
                {#each groupMembers as member}
                  <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {getMemberName(member.id)}
                  </th>
                {/each}
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each Array.from({ length: currentMonth }, (_, i) => i + 1) as month}
                <tr class={month === currentMonth ? 'bg-yellow-50' : ''}>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    Month {month}
                  </td>
                  
                  {#each groupMembers as member}
                    {@const entry = contributionMatrix.find(
                      e => e.month_number === month && e.user_id === member.id
                    )}
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatContribution(entry?.contribution || '+0')}
                    </td>
                  {/each}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
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