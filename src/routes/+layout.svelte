<script lang="ts">
	import '../app.postcss';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/auth/supabase';
	import { goto } from '$app/navigation';
	
	let isAuthenticated = false;
	let isLoading = true;
	
	onMount(async () => {
		const { data: { session } } = await supabase.auth.getSession();
		isAuthenticated = !!session;
		isLoading = false;
		
		// Subscribe to auth state changes
		supabase.auth.onAuthStateChange((_event, session) => {
			isAuthenticated = !!session;
		});
	});
	
	async function handleLogout() {
		await supabase.auth.signOut();
		goto('/auth/login');
	}
	
	function goToLogin() {
		goto('/auth/login');
	}
	
	function goToHome() {
		goto('/');
	}
	
	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter' || event.key === ' ') {
			goToHome();
		}
	}
	
	// Make sure Tailwind is properly loaded
	// Global styles applied here
</script>

<div class="app min-h-screen bg-gray-50 text-gray-900">
	{#if !isLoading}
	<header class="bg-white shadow-sm">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
			<div class="flex justify-between h-16 items-center">
				<div class="flex items-center">
					<div class="flex-shrink-0">
						<!-- Logo button with proper accessibility -->
						<button
							type="button"
							class="h-10 w-10 bg-indigo-600 text-white flex items-center justify-center rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
							on:click={goToHome}
							on:keydown={handleKeydown}
							aria-label="Go to home page"
						>
							<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
						</button>
					</div>
					<div class="ml-2">
						<button
							type="button"
							class="text-lg font-semibold text-indigo-600 hover:text-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 rounded-md px-2 py-1"
							on:click={goToHome}
							on:keydown={handleKeydown}
							aria-label="Go to home page"
						>
							Sandoog
						</button>
					</div>
				</div>
				<div class="flex items-center">
					{#if isAuthenticated}
						<button
							type="button"
							on:click={handleLogout}
							class="ml-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							Logout
						</button>
					{:else}
						<button
							type="button"
							on:click={goToLogin}
							class="ml-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
						>
							Sign In
						</button>
					{/if}
				</div>
			</div>
		</div>
	</header>
	<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
		<slot />
	</main>
	{/if}
</div>
