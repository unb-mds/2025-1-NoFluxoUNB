<script lang="ts">
  import { onMount } from 'svelte';

  export let padding: string = '16px';
  export let borderRadius: number = 16;
  export let backgroundOpacity: number = 0.1;
  export let borderOpacity: number = 0.2;
  export let blurAmount: number = 10;

  let containerElement: HTMLElement;

  onMount(() => {
    // Apply glass effect styles
    if (containerElement) {
      containerElement.style.backdropFilter = `blur(${blurAmount}px)`;
      containerElement.style.background = `rgba(255, 255, 255, ${backgroundOpacity})`;
      containerElement.style.border = `1px solid rgba(255, 255, 255, ${borderOpacity})`;
    }
  });
</script>

<style>
  .glass-container {
    border-radius: var(--border-radius);
    position: relative;
    overflow: hidden;
  }

  .glass-container::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg,
      rgba(255, 255, 255, 0.1) 0%,
      rgba(255, 255, 255, 0.05) 100%);
    pointer-events: none;
  }
</style>

<div
  class="glass-container"
  bind:this={containerElement}
  style="
    --border-radius: {borderRadius}px;
    padding: {padding};
  "
>
  <slot />
</div>
