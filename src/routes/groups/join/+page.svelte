<script lang="ts">
  import JoinGroup from '$lib/components/groups/JoinGroup.svelte';
  import { supabase } from '$lib/auth/supabase';
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
  <title>Join a Group - Sandoog</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-lg mx-auto">
    <div class="text-center">
      <h2 class="text-3xl font-extrabold text-gray-900">
        Join a Group
      </h2>
      <p class="mt-2 text-md text-gray-600">
        Enter the group ID shared by the group admin to join
      </p>
    </div>
    
    <div class="mt-8 bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
      {#if isAuthenticated}
        <JoinGroup />
      {:else}
        <div class="text-center">
          <p class="text-gray-600">Loading...</p>
        </div>
      {/if}
      
      <div class="mt-6 text-center">
        <p class="text-sm text-gray-600">
          Want to create your own group? <a href="/auth/admin-request" class="font-medium text-indigo-600 hover:text-indigo-500">Request admin status</a>
        </p>
      </div>
    </div>
  </div>
</div> 