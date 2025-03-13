<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { getUserStatus } from '$lib/auth/middleware';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/common/Button.svelte';
  
  // =========================================
  // IMPORTANT: Landing Page Behavior Rules
  // =========================================
  // 1. Always show landing page first
  // 2. No automatic redirects
  // 3. Let users manually navigate using buttons
  // 4. Show appropriate options based on role
  // =========================================
  
  // State variables for user status
  let isLoading = true;
  let isAuthenticated = false;
  let isSiteMaster = false;
  let isAdmin = false;
  let hasGroup = false;
  let userId = '';
  let groupId = '';
  let userChecked = false;
  
  onMount(async () => {
    try {
      // Check authentication status
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        isAuthenticated = true;
        userId = session.user.id;
        
        // Get user's role and group status
        const status = await getUserStatus(userId);
        isSiteMaster = status.isSiteMaster;
        isAdmin = status.isAdmin;
        hasGroup = !!status.groupId;
        groupId = status.groupId;
        
        // IMPORTANT: Do not add automatic redirects here
        // Let users see their options and choose where to go
        // This ensures the landing page is always shown first
      }
    } catch (error) {
      console.error('Error getting user status:', error);
    } finally {
      isLoading = false;
      userChecked = true;
    }
  });

  // Navigation functions - Only used when user explicitly clicks a button
  function goToSiteMaster() {
    goto('/sitemaster');
  }

  function goToAdmin() {
    goto('/admin');
  }

  function goToGroup() {
    goto(`/groups/${groupId}`);
  }
</script>

<svelte:head>
  <title>Sandoog - Savings Group Management</title>
</svelte:head>

<!-- Three main states: Loading, Not Authenticated, Authenticated -->
{#if isLoading}
  <!-- Loading state - shown while checking auth -->
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <svg class="animate-spin h-10 w-10 text-indigo-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <p class="mt-3 text-gray-600">Loading...</p>
    </div>
  </div>
{:else if !isAuthenticated}
  <!-- Landing page for non-authenticated users -->
  <div class="relative overflow-hidden">
    <div class="relative pt-6 pb-16 sm:pb-24">
      <div class="mt-16 mx-auto max-w-7xl px-4 sm:mt-24 sm:px-6">
        <div class="text-center">
          <div class="flex justify-center mb-8">
            <div class="p-4 bg-indigo-100 rounded-full">
              <svg class="h-16 w-16 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <h1 class="text-4xl tracking-tight font-extrabold text-gray-900 sm:text-5xl md:text-6xl">
            <span class="block">Manage your</span>
            <span class="block text-indigo-600">savings groups</span>
          </h1>
          <p class="mt-3 max-w-md mx-auto text-base text-gray-500 sm:text-lg md:mt-5 md:text-xl md:max-w-3xl">
            Sandoog makes it easy to organize and manage your savings groups, track contributions, and handle withdrawals.
          </p>
          <div class="mt-5 max-w-md mx-auto sm:flex sm:justify-center md:mt-8">
            <div class="rounded-md shadow">
              <a href="/auth/signup" class="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 md:py-4 md:text-lg md:px-10">
                Get started
              </a>
            </div>
            <div class="mt-3 rounded-md shadow sm:mt-0 sm:ml-3">
              <a href="/auth/login" class="w-full flex items-center justify-center px-8 py-3 border border-transparent text-base font-medium rounded-md text-indigo-600 bg-white hover:bg-gray-50 md:py-4 md:text-lg md:px-10">
                Sign in
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{:else}
  <!-- Options for authenticated users - Shows navigation based on role -->
  <div class="py-12">
    <div class="max-w-4xl mx-auto">
      <div class="text-center">
        <h1 class="text-3xl font-extrabold text-gray-900 sm:text-4xl">
          Welcome to Sandoog
        </h1>
        
        {#if hasGroup || isAdmin || isSiteMaster}
          <!-- Show role-specific navigation buttons -->
          <div class="mt-8 space-y-4">
            {#if isSiteMaster}
              <div class="text-center">
                <Button on:click={goToSiteMaster} fullWidth={false}>
                  Go to Site Master Dashboard
                </Button>
              </div>
            {/if}
            
            {#if isAdmin && hasGroup}
              <div class="text-center">
                <Button on:click={goToAdmin} fullWidth={false}>
                  Go to Admin Dashboard
                </Button>
              </div>
            {/if}
            
            {#if hasGroup && !isAdmin}
              <div class="text-center">
                <Button on:click={goToGroup} fullWidth={false}>
                  Go to Your Group
                </Button>
              </div>
            {/if}
          </div>
        {:else}
          <!-- Show options for users without roles -->
          <p class="mt-3 text-xl text-gray-500">
            Choose an option to get started
          </p>
          
          <div class="mt-12 grid gap-8 grid-cols-1 md:grid-cols-2">
            <!-- Join existing group option -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-indigo-100 rounded-md p-3">
                    <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                  <div class="ml-5">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      Join an Existing Group
                    </h3>
                    <p class="mt-2 text-base text-gray-500">
                      Enter the group ID provided by the group admin to join an existing savings group.
                    </p>
                  </div>
                </div>
                <div class="mt-6">
                  <a href="/groups/join">
                    <Button fullWidth={true}>Join a Group</Button>
                  </a>
                </div>
              </div>
            </div>
            
            <!-- Create new group option -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-indigo-100 rounded-md p-3">
                    <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                  </div>
                  <div class="ml-5">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      Create a New Group
                    </h3>
                    <p class="mt-2 text-base text-gray-500">
                      Request admin status to create and manage your own savings group.
                    </p>
                  </div>
                </div>
                <div class="mt-6">
                  <a href="/auth/admin-request">
                    <Button fullWidth={true}>Request Admin Status</Button>
                  </a>
                </div>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<!-- Add temporary test link -->
<div class="fixed bottom-4 right-4">
  <a href="/test" class="text-sm bg-blue-500 text-white px-3 py-1 rounded">Test Page</a>
</div>
