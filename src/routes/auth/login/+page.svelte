<script lang="ts">
  import { enhance } from "$app/forms";
  import { goto } from "$app/navigation";
  import { signInWithPassword } from "$lib/auth/supabase";
  import { checkUserStatus } from "$lib/auth/checkUserStatus";
  import { onMount } from "svelte";

  let email = "";
  let password = "";
  let loading = false;
  let error = "";
  let success = "";
  let debugInfo = "";
  let showDebug = true; // For troubleshooting, set to true

  async function handleLogin() {
    loading = true;
    error = "";
    success = "";
    debugInfo = `Login attempt for: ${email}`;
    
    try {
      console.log("Login attempt for:", email);
      const { data, error: loginError } = await signInWithPassword({
        email,
        password,
      });
      
      if (loginError) {
        error = typeof loginError === 'object' && loginError !== null && 'message' in loginError 
          ? loginError.message as string 
          : 'Login failed';
        console.error("Login failed:", loginError);
        debugInfo += `\nLogin error: ${typeof loginError === 'object' && loginError !== null && 'message' in loginError 
          ? loginError.message 
          : 'Unknown error'}`;
        return;
      }
      
      success = "Login successful!";
      console.log("Login successful:", data);
      debugInfo += "\nLogin successful";
      
      // Check user status to determine where to redirect
      const userStatus = await checkUserStatus();
      console.log("User status:", userStatus);
      debugInfo += `\nUser status: ${JSON.stringify(userStatus)}`;
      
      // Check for sandoog.com emails first, which should always be site masters
      const isSandoogEmail = email.toLowerCase().endsWith('@sandoog.com');
      debugInfo += `\nIs sandoog.com email: ${isSandoogEmail}`;
      
      if (isSandoogEmail) {
        console.log("Detected sandoog.com email, redirecting to site master page");
        debugInfo += "\nRedirecting to /sitemaster (email rule)";
        
        // Ensure database is updated correctly for sandoog.com email users
        // This is a fallback in case the checkUserStatus didn't update it properly
        try {
          const userId = data && 'user' in data && data.user ? data.user.id : null;
          if (userId) {
            const { error: updateError } = await fetch('/api/update-site-master', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ userId })
            }).then(res => res.json());
            
            if (updateError) {
              console.warn("Could not update site master status:", updateError);
              debugInfo += `\nWarning: Could not update site master status: ${updateError}`;
            }
          }
        } catch (err) {
          console.warn("Error updating site master status:", err);
          debugInfo += `\nWarning: Error updating site master status: ${err}`;
        }
        
        goto("/sitemaster");
        return;
      }
      
      // Redirect based on user role - prioritize the strongest role
      if (userStatus.isSiteMaster) {
        console.log("Redirecting to site master page");
        debugInfo += "\nRedirecting to /sitemaster (role)";
        goto("/sitemaster");
      } else if (userStatus.isAdmin) {
        console.log("Redirecting to admin page");
        debugInfo += "\nRedirecting to /admin";
        goto("/admin");
      } else if (userStatus.groupId) {
        console.log("Redirecting to group page");
        debugInfo += `\nRedirecting to /groups/${userStatus.groupId}`;
        goto(`/groups/${userStatus.groupId}`);
      } else {
        console.log("Redirecting to join group page");
        debugInfo += "\nRedirecting to /groups/join";
        goto("/groups/join");
      }
    } catch (err) {
      console.error("Login exception:", err);
      error = "An unexpected error occurred. Please try again.";
      debugInfo += `\nError: ${JSON.stringify(err)}`;
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    // Check if user is already logged in
    const status = await checkUserStatus();
    if (status.isAuthenticated) {
      // For debug purposes, log the status
      console.log("Already logged in with status:", status);
      
      if (status.isSiteMaster) {
        goto("/sitemaster");
      } else if (status.isAdmin) {
        goto("/admin");
      } else if (status.groupId) {
        goto(`/groups/${status.groupId}`);
      } else {
        goto("/groups/join");
      }
    }
  });
</script>

<svelte:head>
  <title>Login - Sandoog</title>
</svelte:head>

<div class="flex min-h-screen flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="mt-6 text-center text-3xl font-bold tracking-tight text-gray-900">
      Sign in to your account
    </h2>
  </div>

  <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
    <div class="bg-white px-4 py-8 shadow sm:rounded-lg sm:px-10">
      <form class="space-y-6" on:submit|preventDefault={handleLogin}>
        <div>
          <label for="email" class="block text-sm font-medium leading-6 text-gray-900">
            Email address
          </label>
          <div class="mt-2">
            <input
              id="email"
              name="email"
              type="email"
              autocomplete="email"
              required
              bind:value={email}
              class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            />
          </div>
        </div>

        <div>
          <label for="password" class="block text-sm font-medium leading-6 text-gray-900">
            Password
          </label>
          <div class="mt-2">
            <input
              id="password"
              name="password"
              type="password"
              autocomplete="current-password"
              required
              bind:value={password}
              class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
            />
          </div>
        </div>

        {#if error}
          <div class="rounded-md bg-red-50 p-4">
            <div class="flex">
              <div class="text-sm text-red-700">
                {error}
              </div>
            </div>
          </div>
        {/if}

        {#if success}
          <div class="rounded-md bg-green-50 p-4">
            <div class="flex">
              <div class="text-sm text-green-700">
                {success}
              </div>
            </div>
          </div>
        {/if}
        
        {#if showDebug && debugInfo}
          <div class="rounded-md bg-gray-50 p-4">
            <div class="flex">
              <div class="text-xs text-gray-700">
                <strong>Debug:</strong>
                <pre class="mt-1 whitespace-pre-wrap">{debugInfo}</pre>
              </div>
            </div>
          </div>
        {/if}

        <div>
          <button
            type="submit"
            disabled={loading}
            class="flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            {#if loading}
              Signing in...
            {:else}
              Sign in
            {/if}
          </button>
        </div>
      </form>

      <div class="mt-6">
        <div class="relative">
          <div class="absolute inset-0 flex items-center">
            <div class="w-full border-t border-gray-300"></div>
          </div>
          <div class="relative flex justify-center text-sm">
            <span class="bg-white px-2 text-gray-500">
              Or
            </span>
          </div>
        </div>

        <div class="mt-6 grid grid-cols-1 gap-3">
          <div>
            <a
              href="/auth/signup"
              class="flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            >
              Create new account
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</div> 