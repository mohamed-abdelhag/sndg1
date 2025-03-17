<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { checkIfSiteMaster } from '$lib/auth/getUserStatus';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import Notification from '$lib/components/common/Notification.svelte';
  
  let loading = true;
  let pendingAdminRequests = 0;
  let totalUsers = 0;
  let totalGroups = 0;
  let isAuthorized = false;
  let errorMessage = '';
  let showError = false;
  let debugInfo = '';
  let showDebug = false;
  
  onMount(async () => {
    try {
      console.log('[SiteMaster] Checking authorization...');
      // Get current session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        console.error('[SiteMaster] No session found');
        errorMessage = 'You must be logged in to access this page';
        showError = true;
        goto('/auth/login');
        return;
      }
      
      // Debug information
      debugInfo = `User email: ${session.user.email}, User ID: ${session.user.id}`;
      showDebug = true;
      console.log('[SiteMaster] ' + debugInfo);
      
      // Check if user is site master
      const isSiteMaster = await checkIfSiteMaster();
      console.log('[SiteMaster] Is site master check result:', isSiteMaster);
      debugInfo += `\nSiteMaster check: ${isSiteMaster}`;
      
      // Check directly if it's a sandoog.com email
      const isSandoogEmail = session.user.email && session.user.email.toLowerCase().endsWith('@sandoog.com');
      debugInfo += `\nEmail domain check: ${isSandoogEmail}`;
      
      if (!isSiteMaster && !isSandoogEmail) {
        console.error('[SiteMaster] User not authorized');
        errorMessage = 'You are not authorized to access the site master dashboard';
        showError = true;
        goto('/');
        return;
      }
      
      // At this point, user is authorized
      isAuthorized = true;
      
      // If it's a sandoog.com email but not marked as site master in database, update the record
      if (isSandoogEmail) {
        debugInfo += `\nUpdating user record for sandoog.com email`;
        
        // Get user data first to check current status
        const { data: userData } = await supabase
          .from('users')
          .select('is_site_master, is_admin')
          .eq('id', session.user.id)
          .single();
          
        if (userData && (!userData.is_site_master || !userData.is_admin)) {
          console.log('[SiteMaster] Updating user record to set site master flags');
          await supabase
            .from('users')
            .update({
              is_site_master: true,
              is_admin: true,
              updated_at: new Date()
            })
            .eq('id', session.user.id);
        }
      }
      
      // Try to get data with error handling for each request
      await loadDashboardData();
    } catch (error) {
      console.error('[SiteMaster] Unexpected error:', error);
      errorMessage = 'An unexpected error occurred. Please try again.';
      showError = true;
      debugInfo += `\nError: ${JSON.stringify(error)}`;
    } finally {
      loading = false;
    }
  });
  
  // Function to load all dashboard data with proper error handling
  async function loadDashboardData() {
    // Get pending admin requests count - handle permission errors gracefully
    try {
      // First check if table exists
      const { error: tableCheckError } = await supabase
        .from('admin_requests')
        .select('id', { count: 'exact', head: true })
        .limit(1);
        
      if (tableCheckError && tableCheckError.message?.includes('relation "admin_requests" does not exist')) {
        console.warn('[SiteMaster] admin_requests table does not exist');
        pendingAdminRequests = 0;
        return;
      }
      
      // If table exists, get the count of pending requests
      const { count: requestCount, error: requestError } = await supabase
        .from('admin_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending');
        
      if (!requestError) {
        pendingAdminRequests = requestCount || 0;
      } else {
        console.error('[SiteMaster] Error fetching admin requests:', requestError);
        pendingAdminRequests = 0; // Default to 0 on error
      }
    } catch (error) {
      console.error('[SiteMaster] Admin requests count error:', error);
      pendingAdminRequests = 0;
    }
    
    // Get total users count - handle errors gracefully
    try {
      // Change the query to use auth.users instead, which should always have users
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('id');
        
      if (!userError && userData) {
        totalUsers = userData.length;
        console.log('[SiteMaster] Users count:', totalUsers);
      } else {
        console.error('[SiteMaster] Error fetching users count:', userError);
        // Try alternative method using auth.users
        try {
          const { count, error: authUserError } = await supabase.rpc('get_total_users_count');
          if (!authUserError) {
            totalUsers = count || 0;
            console.log('[SiteMaster] Users count from RPC:', totalUsers);
          } else {
            totalUsers = 0;
          }
        } catch (fallbackError) {
          console.error('[SiteMaster] Fallback user count error:', fallbackError);
          totalUsers = 0;
        }
      }
    } catch (error) {
      console.error('[SiteMaster] User count error:', error);
      totalUsers = 0;
    }
    
    // Get total groups count - handle errors gracefully
    try {
      const { count: groupCount, error: groupError } = await supabase
        .from('groups')
        .select('id', { count: 'exact', head: true });
        
      if (!groupError) {
        totalGroups = groupCount || 0;
      } else {
        console.error('[SiteMaster] Error fetching groups count:', groupError);
        totalGroups = 0;
      }
    } catch (error) {
      console.error('[SiteMaster] Group count error:', error);
      totalGroups = 0;
    }
  }
</script>

<svelte:head>
  <title>Site Master Dashboard | Sandoog</title>
</svelte:head>

{#if loading}
  <div class="flex justify-center">
    <div class="animate-pulse text-center">
      <p class="text-gray-600">Loading dashboard...</p>
    </div>
  </div>
{:else if !isAuthorized}
  {#if showError}
    <Notification type="error" message={errorMessage} />
  {/if}
{:else}
  {#if showError}
    <Notification type="error" message={errorMessage} />
  {/if}
  
  {#if showDebug}
    <div class="bg-yellow-100 border-l-4 border-yellow-500 p-4 mb-6 rounded">
      <h3 class="text-yellow-800 font-medium">Debug Information</h3>
      <pre class="mt-2 text-xs text-yellow-700 whitespace-pre-wrap">{debugInfo}</pre>
    </div>
  {/if}
  
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900">Site Master Dashboard</h1>
      <p class="mt-2 text-sm text-gray-500">
        Manage your Sandoog application site-wide settings and user requests
      </p>
    </div>
    
    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-indigo-500"></div>
      </div>
    {:else}
      <!-- Stats Cards -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 mb-8">
        <!-- Pending Admin Requests -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Pending Admin Requests
                  </dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {pendingAdminRequests}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-4 py-4 sm:px-6">
            <div class="text-sm">
              <a href="/sitemaster/admin-approvals" class="font-medium text-indigo-600 hover:text-indigo-500">
                View all requests <span aria-hidden="true">&rarr;</span>
              </a>
            </div>
          </div>
        </div>
        
        <!-- Total Users -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-emerald-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Total Users
                  </dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {totalUsers}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Total Groups -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-amber-500 rounded-md p-3">
                <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Total Groups
                  </dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {totalGroups}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Admin Request Actions -->
      <div class="bg-white shadow sm:rounded-lg mb-8">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            Admin Requests Management
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500">
            <p>
              Review and approve requests from users who want to become admins and create their own groups.
            </p>
          </div>
          <div class="mt-5">
            <a href="/sitemaster/admin-approvals" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Manage Admin Requests
            </a>
          </div>
        </div>
      </div>
    {/if}
  </div>
{/if} 