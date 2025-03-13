<script lang="ts">
	import '../app.postcss';
	
	// Make sure Tailwind is properly loaded
	// Global styles applied here
</script>

<div class="app min-h-screen bg-gray-50 text-gray-900">
	<header class="bg-white shadow-sm">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
			<div class="flex justify-between h-16 items-center">
				<div class="flex items-center">
					<div class="flex-shrink-0">
						<!-- Dollar sign logo -->
						<div class="h-10 w-10 bg-indigo-600 text-white flex items-center justify-center rounded-md">
							<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
						</div>
					</div>
					<div class="ml-2">
						<span class="text-lg font-semibold text-indigo-600">Sandoog</span>
					</div>
				</div>
			</div>
		</div>
	</header>
	<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
		<slot />
	</main>
</div>
