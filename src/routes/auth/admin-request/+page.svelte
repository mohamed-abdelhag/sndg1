<script lang="ts">
  import AdminRequestForm from '$lib/components/auth/AdminRequestForm.svelte';
  import { supabase } from '$lib/auth/supabase';
  import { requireAuth } from '$lib/auth/middleware';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  
  let isAuthenticated = false;
  
  onMount(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    isAuthenticated = !!session;
    
    if (!isAuthenticated) {
      goto('/auth/login');
    }
  });
</script>

<svelte:head>
  <title>Request Admin Status - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-lg mx-auto">
    <div class="text-center">
      <h2 class="text-3xl font-extrabold text-gray-900">
        Request Admin Status
      </h2>
      <p class="mt-2 text-md text-gray-600">
        As an admin, you'll be able to create and manage a savings group
      </p>
    </div>
    
    <div class="mt-8 bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
      {#if isAuthenticated}
        <AdminRequestForm />
      {:else}
        <div class="text-center">
          <p class="text-gray-600">Loading...</p>
        </div>
      {/if}
      
      <div class="mt-6 text-center">
        <p class="text-sm text-gray-600">
          Want to join an existing group instead? <a href="/groups/join" class="font-medium text-indigo-600 hover:text-indigo-500">Join a group</a>
        </p>
      </div>
    </div>
  </div>
</div> 