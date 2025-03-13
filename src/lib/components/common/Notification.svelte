<script lang="ts">
  import { fly } from 'svelte/transition';
  import { createEventDispatcher, onDestroy } from 'svelte';
  
  export let type: 'success' | 'error' | 'info' | 'warning' = 'info';
  export let message: string;
  export let duration: number = 5000; // Duration in ms
  export let show: boolean = false;
  
  const dispatch = createEventDispatcher();
  let timer: ReturnType<typeof setTimeout>;
  
  // Auto-close after duration
  $: if (show && duration > 0) {
    timer = setTimeout(() => {
      close();
    }, duration);
  }
  
  onDestroy(() => {
    if (timer) clearTimeout(timer);
  });
  
  // Icon and color based on type
  $: typeConfig = {
    success: {
      icon: '✓',
      bgColor: 'bg-emerald-500',
      textColor: 'text-white'
    },
    error: {
      icon: '✗',
      bgColor: 'bg-red-500',
      textColor: 'text-white'
    },
    info: {
      icon: 'ℹ',
      bgColor: 'bg-indigo-500',
      textColor: 'text-white'
    },
    warning: {
      icon: '⚠',
      bgColor: 'bg-amber-500',
      textColor: 'text-white'
    }
  };
  
  function close() {
    show = false;
    dispatch('close');
  }
</script>

{#if show}
  <div
    transition:fly={{ y: -20, duration: 300 }}
    class="fixed top-4 right-4 z-50 max-w-sm shadow-lg rounded-lg overflow-hidden"
    role="alert"
  >
    <div class="p-4 {typeConfig[type].bgColor} {typeConfig[type].textColor}">
      <div class="flex items-center">
        <div class="flex-shrink-0 mr-3">
          <span class="text-xl font-bold">{typeConfig[type].icon}</span>
        </div>
        <div class="flex-1 mr-2">
          <p class="text-sm">{message}</p>
        </div>
        <button 
          type="button"
          class="flex-shrink-0 text-white"
          on:click={close}
        >
          <span class="sr-only">Close</span>
          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      </div>
    </div>
  </div>
{/if} 