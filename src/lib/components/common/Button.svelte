<script lang="ts">
  export let type: 'button' | 'submit' | 'reset' = 'button';
  export let variant: 'primary' | 'secondary' | 'outline' | 'text' | 'danger' = 'primary';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let disabled = false;
  export let fullWidth = false;
  export let loading = false;
  
  // Class generation based on variant
  const variantClasses = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500',
    secondary: 'bg-emerald-600 text-white hover:bg-emerald-700 focus:ring-2 focus:ring-emerald-500',
    outline: 'bg-transparent border border-indigo-600 text-indigo-600 hover:bg-indigo-50',
    text: 'bg-transparent text-indigo-600 hover:bg-indigo-50',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-2 focus:ring-red-500'
  };
  
  // Size classes
  const sizeClasses = {
    sm: 'text-sm px-3 py-1.5',
    md: 'text-base px-4 py-2',
    lg: 'text-lg px-6 py-3'
  };
  
  // Generate classes based on props
  $: classes = `
    ${variantClasses[variant]}
    ${sizeClasses[size]}
    ${fullWidth ? 'w-full' : ''}
    rounded-lg font-semibold focus:outline-none focus:ring-offset-2
    ${disabled ? 'opacity-50 cursor-not-allowed' : 'transform transition-transform active:scale-95'}
  `;
</script>

<button 
  {type} 
  {disabled} 
  class={classes}
  on:click
>
  {#if loading}
    <span class="inline-block mr-2">
      <svg class="animate-spin -ml-1 h-4 w-4 text-current" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </span>
  {/if}
  <slot></slot>
</button> 