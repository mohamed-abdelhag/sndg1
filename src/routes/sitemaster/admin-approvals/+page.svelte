<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { checkIfSiteMaster } from '$lib/auth/middleware';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/common/Button.svelte';
  import Notification from '$lib/components/common/Notification.svelte';
  import AdminApproval from '$lib/components/sitemaster/AdminApproval.svelte';
  
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
  
  let loading = true;
  let adminRequests: AdminRequest[] = [];
  let errorMessage = '';
  let showError = false;
  let successMessage = '';
  let showSuccess = false;
  let processingId: string | null = null;
  let isAuthorized = false;
  let tableNotFound = false;
  let filteredRequests: AdminRequest[] = [];
  
  onMount(async () => {
    try {
      console.log('[AdminApprovals] Checking authorization...');
      // Get current session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        console.error('[AdminApprovals] No session found');
        errorMessage = 'You must be logged in to access this page';
        showError = true;
        goto('/auth/login');
        return;
      }
      
      console.log('[AdminApprovals] User email:', session.user.email);
      
      // Check if user is site master
      const isSiteMaster = await checkIfSiteMaster();
      console.log('[AdminApprovals] Is site master check result:', isSiteMaster);
      
      if (!isSiteMaster) {
        // Check if the email domain is @sandoog.com as a fallback
        if (session.user.email && session.user.email.toLowerCase().endsWith('@sandoog.com')) {
          console.log('[AdminApprovals] Email domain check passed, granting access');
          // Ensure database is updated
          await supabase
            .from('users')
            .upsert({
              id: session.user.id,
              email: session.user.email,
              is_admin: true,
              is_site_master: true
            });
          
          isAuthorized = true;
        } else {
          console.error('[AdminApprovals] User not authorized');
          errorMessage = 'You are not authorized to access this page';
          showError = true;
          goto('/');
          return;
        }
      } else {
        isAuthorized = true;
      }
      
      await loadAdminRequests();
    } catch (error) {
      console.error('[AdminApprovals] Error:', error);
      errorMessage = 'Failed to load admin requests. Please try again.';
      showError = true;
    } finally {
      loading = false;
    }
  });
  
  async function loadAdminRequests() {
    console.log('[AdminApprovals] Loading admin requests...');
    
    try {
      // First check if table exists
      const { error: tableCheckError } = await supabase
        .from('admin_requests')
        .select('id')
        .limit(1);
        
      if (tableCheckError && tableCheckError.message?.includes('relation "admin_requests" does not exist')) {
        console.error('[AdminApprovals] Table does not exist:', tableCheckError.message);
        errorMessage = 'The admin_requests table has not been created yet. Please run the SQL script in sql/fix_admin_requests.sql to set up the table.';
        adminRequests = [];
        showError = true;
        tableNotFound = true;
        return;
      }
    
      // First get all admin requests directly without joins
      const { data, error } = await supabase
        .from('admin_requests')
        .select(`
          id,
          user_id,
          reason,
          status,
          requested_at,
          responded_at
        `)
        .order('requested_at', { ascending: false });
        
      if (error) {
        console.error('[AdminApprovals] Error loading requests:', error);
        
        // Special handling for common errors
        if (error.message?.includes('relation "admin_requests" does not exist')) {
          errorMessage = 'The admin_requests table has not been created yet. Please run the SQL script in sql/fix_admin_requests.sql to set up the table.';
          adminRequests = [];
          showError = true;
          tableNotFound = true;
          
          // Show error UI will be handled in the template below
          return;
        }
        
        errorMessage = 'Failed to load admin requests. Database error: ' + error.message;
        showError = true;
        adminRequests = [];
        return;
      }
      
      if (!data || data.length === 0) {
        // No requests found, just return empty array
        console.log('[AdminApprovals] No admin requests found');
        adminRequests = [];
        return;
      }
      
      console.log('[AdminApprovals] Requests loaded:', data.length);
      
      // For each request, get the user data separately (more reliable than joins)
      const adminRequestsWithUsers = await Promise.all(data.map(async (request) => {
        // Get user data for this request
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('email, first_name, last_name')
          .eq('id', request.user_id)
          .single();
          
        if (userError) {
          console.warn(`[AdminApprovals] Couldn't load user data for ${request.user_id}:`, userError);
          return {
            ...request,
            users: {
              email: 'unknown@email.com',
              first_name: 'Unknown',
              last_name: 'User'
            }
          };
        }
        
        return {
          ...request,
          users: userData
        };
      }));
      
      // Update state with combined data
      adminRequests = adminRequestsWithUsers as AdminRequest[];
    } catch (error) {
      console.error('[AdminApprovals] Unexpected error loading requests:', error);
      errorMessage = 'An unexpected error occurred loading admin requests.';
      showError = true;
      adminRequests = [];
    }
  }
  
  // Add the approve and reject functions back
  async function approveRequest(requestId: string) {
    processingId = requestId;
    
    try {
      // Get current user ID
      const currentUserId = (await supabase.auth.getSession()).data.session?.user.id;
      
      if (!currentUserId) {
        throw new Error('Not authenticated');
      }
      
      // Use the approve_admin_request RPC function as defined in supabase.md
      const { data: approved, error: approveError } = await supabase.rpc(
        'approve_admin_request',
        {
          request_id: requestId,
          approved_by: currentUserId
        }
      );
      
      if (approveError) {
        throw approveError;
      }
      
      if (!approved) {
        throw new Error('Approval failed');
      }
      
      // Success message
      successMessage = 'Request approved successfully';
      showSuccess = true;
      
      // Update the local state
      adminRequests = adminRequests.map(req => 
        req.id === requestId 
          ? { ...req, status: 'approved', responded_at: new Date().toISOString() } 
          : req
      );
    } catch (error) {
      console.error('[AdminApprovals] Error approving request:', error);
      errorMessage = 'Failed to approve request. Please try again.';
      showError = true;
    } finally {
      processingId = null;
    }
  }
  
  async function rejectRequest(requestId: string) {
    processingId = requestId;
    
    try {
      // Update the admin request
      const { error } = await supabase
        .from('admin_requests')
        .update({
          status: 'rejected',
          responded_at: new Date().toISOString(),
          responded_by: (await supabase.auth.getSession()).data.session?.user.id
        })
        .eq('id', requestId);
      
      if (error) throw error;
      
      // Success message and reload
      successMessage = 'Request rejected successfully';
      showSuccess = true;
      
      // Update the local state to avoid a reload
      adminRequests = adminRequests.map(req => 
        req.id === requestId 
          ? { ...req, status: 'rejected', responded_at: new Date().toISOString() } 
          : req
      );
    } catch (error) {
      console.error('[AdminApprovals] Error rejecting request:', error);
      errorMessage = 'Failed to reject request. Please try again.';
      showError = true;
    } finally {
      processingId = null;
    }
  }
  
  // Filter requests by status
  let activeFilter: 'all' | 'pending' | 'approved' | 'rejected' = 'all';
  
  $: {
    if (!adminRequests) filteredRequests = [];
    else if (activeFilter === 'all') filteredRequests = adminRequests;
    else filteredRequests = adminRequests.filter(req => req.status === activeFilter);
  }
</script>

<svelte:head>
  <title>Admin Request Approvals | Sandoog</title>
</svelte:head>

{#if isAuthorized}
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
    {:else}
      <!-- Filter tabs -->
      <div class="mb-6 border-b border-gray-200">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
          <button
            class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              {activeFilter === 'all' 
                ? 'border-indigo-500 text-indigo-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
            on:click={() => activeFilter = 'all'}
          >
            All Requests
          </button>
          <button
            class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              {activeFilter === 'pending' 
                ? 'border-yellow-500 text-yellow-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
            on:click={() => activeFilter = 'pending'}
          >
            Pending
          </button>
          <button
            class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              {activeFilter === 'approved' 
                ? 'border-green-500 text-green-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
            on:click={() => activeFilter = 'approved'}
          >
            Approved
          </button>
          <button
            class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm
              {activeFilter === 'rejected' 
                ? 'border-red-500 text-red-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
            on:click={() => activeFilter = 'rejected'}
          >
            Rejected
          </button>
        </nav>
      </div>
      
      {#if filteredRequests.length === 0}
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:p-6 text-center">
            <p class="text-gray-500">No admin requests found with the selected filter.</p>
          </div>
        </div>
      {:else}
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <ul class="divide-y divide-gray-200">
            {#each filteredRequests as request}
              <AdminApproval 
                {request} 
                loading={processingId === request.id}
                on:approve={({ detail }) => approveRequest(detail.id)}
                on:reject={({ detail }) => rejectRequest(detail.id)}
              />
            {/each}
          </ul>
        </div>
      {/if}
    {/if}
  </div>
{:else if loading}
  <div class="flex items-center justify-center h-screen">
    <div class="animate-spin rounded-full h-12 w-12 border-t-4 border-b-4 border-indigo-500"></div>
  </div>
{:else}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 text-center">
    {#if tableNotFound}
      <div class="bg-red-50 border border-red-200 text-red-800 rounded-md p-4 mt-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3 text-left">
            <h3 class="text-sm font-medium text-red-800">Database Table Missing</h3>
            <div class="mt-2 text-sm text-red-700">
              <p>The admin_requests table does not exist in your database. Please follow these steps:</p>
              <ol class="list-decimal pl-5 mt-1 space-y-1">
                <li>Go to the SQL directory in your project</li>
                <li>Find the file named fix_admin_requests.sql</li>
                <li>Run this SQL script in the Supabase SQL Editor</li>
                <li>Refresh this page after running the script</li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    {:else}
      <div class="bg-red-50 shadow overflow-hidden sm:rounded-lg p-6">
        <h2 class="text-2xl font-bold text-red-800">Access Denied</h2>
        <p class="mt-4 text-red-600">
          You are not authorized to access the admin approvals page.
        </p>
        <div class="mt-6">
          <a href="/" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            Return to Home
          </a>
        </div>
      </div>
    {/if}
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