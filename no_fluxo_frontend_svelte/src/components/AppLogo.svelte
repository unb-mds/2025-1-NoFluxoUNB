<script lang="ts">
  export let fontSize: number = 36;
  export let color: string = 'var(--color-white)';
  export let showIcon: boolean = true;
</script>

<style>
  .app-logo {
    display: flex;
    align-items: center;
    gap: 12px;
    font-family: var(--font-display);
    font-weight: 400;
    color: var(--color);
    font-size: var(--font-size);
    text-decoration: none;
    transition: color 0.2s ease;
  }

  .app-logo:hover {
    color: var(--color-primary);
  }

  .logo-icon {
    width: calc(var(--font-size) * 0.8);
    height: calc(var(--font-size) * 0.8);
    background: linear-gradient(135deg, var(--color-primary), var(--color-purple));
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-weight: bold;
    font-size: calc(var(--font-size) * 0.4);
  }

  .logo-text {
    font-size: var(--font-size);
    line-height: 1;
  }

  .logo-text .highlight {
    color: var(--color-pink);
  }
</style>

<div class="app-logo" style="--color: {color}; --font-size: {fontSize}px;">
  {#if showIcon}
    <div class="logo-icon">N</div>
  {/if}
  <span class="logo-text">
    NO<span class="highlight">FLUXO</span>
  </span>
</div>
