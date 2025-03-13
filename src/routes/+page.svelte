<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/auth/supabase';
  import { getUserStatus } from '$lib/auth/middleware';
  import { goto } from '$app/navigation';
  import Button from '$lib/components/common/Button.svelte';
  
  let isLoading = true;
  let isAuthenticated = false;
  let isSiteMaster = false;
  let isAdmin = false;
  let hasGroup = false;
  let userId = '';
  
  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      isAuthenticated = true;
      userId = session.user.id;
      
      const status = await getUserStatus(userId);
      isSiteMaster = status.isSiteMaster;
      isAdmin = status.isAdmin;
      hasGroup = !!status.groupId;
      
      console.log('User status:', status);
      
      if (isSiteMaster) {
        console.log('Redirecting to sitemaster dashboard');
        goto('/sitemaster');
        return;
      }
      
      // Redirect based on user role
      if (isAdmin && hasGroup) {
        goto('/admin');
      } else if (hasGroup) {
        goto(`/groups/${status.groupId}`);
      }
    }
    
    isLoading = false;
  });
</script>

<svelte:head>
  <title>Sandoog - Savings Group Management</title>
</svelte:head>

{#if isLoading}
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
  <div>
    <div class="relative overflow-hidden">
      <div class="relative pt-6 pb-16 sm:pb-24">
        <!-- Hero section with dollar sign icon -->
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
    
    <!-- Features section -->
    <div class="py-12 bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="lg:text-center">
          <h2 class="text-base text-indigo-600 font-semibold tracking-wide uppercase">Features</h2>
          <p class="mt-2 text-3xl leading-8 font-extrabold tracking-tight text-gray-900 sm:text-4xl">
            A better way to manage savings
          </p>
          <p class="mt-4 max-w-2xl text-xl text-gray-500 lg:mx-auto">
            Everything you need to manage your savings groups in one place.
          </p>
        </div>

        <div class="mt-10">
          <div class="space-y-10 md:space-y-0 md:grid md:grid-cols-2 md:gap-x-8 md:gap-y-10">
            <div class="flex">
              <div class="flex-shrink-0">
                <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
                  <!-- Icon size fixed -->
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Standard Savings Groups</h3>
                <p class="mt-2 text-base text-gray-500">
                  Track contributions, manage withdrawals, and set payback plans with flexible terms.
                </p>
              </div>
            </div>

            <div class="flex">
              <div class="flex-shrink-0">
                <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
                  <!-- Icon size fixed -->
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Lottery Groups</h3>
                <p class="mt-2 text-base text-gray-500">
                  Run a lottery-style savings group with random selection of monthly winners.
                </p>
              </div>
            </div>

            <div class="flex">
              <div class="flex-shrink-0">
                <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
                  <!-- Icon size fixed -->
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Contribution Tracking</h3>
                <p class="mt-2 text-base text-gray-500">
                  Clear matrix view of all contributions, withdrawals, and paybacks by month.
                </p>
              </div>
            </div>

            <div class="flex">
              <div class="flex-shrink-0">
                <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
                  <!-- Icon size fixed -->
                  <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Group Management</h3>
                <p class="mt-2 text-base text-gray-500">
                  Invite members, approve withdrawal requests, and manage group settings.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{:else if !hasGroup}
  <!-- Option selection for authenticated users without a group -->
  <div class="py-12">
    <div class="max-w-4xl mx-auto">
      <div class="text-center">
        <h1 class="text-3xl font-extrabold text-gray-900 sm:text-4xl">
          Welcome to Sandoog
        </h1>
        <p class="mt-3 text-xl text-gray-500">
          Choose an option to get started
        </p>
      </div>
      
      <div class="mt-12 grid gap-8 grid-cols-1 md:grid-cols-2">
        <!-- Join a group option -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-indigo-100 rounded-md p-3">
                <!-- Icon size fixed -->
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
        
        <!-- Create a group option -->
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-emerald-100 rounded-md p-3">
                <!-- Icon size fixed -->
                <svg class="h-6 w-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
              </div>
              <div class="ml-5">
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  Request to Create a Group
                </h3>
                <p class="mt-2 text-base text-gray-500">
                  Request admin status to create and manage your own savings group.
                </p>
              </div>
            </div>
            <div class="mt-6">
              <a href="/auth/admin-request">
                <Button variant="secondary" fullWidth={true}>Request Admin Status</Button>
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Add temporary test link -->
<div class="fixed bottom-4 right-4">
  <a href="/test" class="text-sm bg-blue-500 text-white px-3 py-1 rounded">Test Page</a>
</div>
