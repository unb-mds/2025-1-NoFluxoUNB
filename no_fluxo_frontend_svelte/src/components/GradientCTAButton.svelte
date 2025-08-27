<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  export let text: string = '';
  export let fontSize: number = 19;
  export let textColor: string = 'var(--color-white)';
  export let fontWeight: string = 'bold';
  export let gradientColors: string[] = ['var(--color-purple)', 'var(--color-pink)'];
  export let animationDuration: number = 200;
  export let scaleOnHover: number = 1.05;
  export let borderRadius: number = 30;
  export let padding: string = '12px 16px';
  export let minWidth: string = '260px';
  export let minHeight: string = '40px';
  export let disabled: boolean = false;

  const dispatch = createEventDispatcher();

  function handleClick() {
    if (!disabled) {
      dispatch('click');
    }
  }

  let isHovered = false;
</script>

<style>
  .gradient-cta-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: none;
    border-radius: var(--border-radius);
    font-family: var(--font-display);
    font-weight: var(--font-weight);
    color: var(--text-color);
    cursor: pointer;
    transition: all var(--animation-duration)ms ease-in-out;
    min-width: var(--min-width);
    min-height: var(--min-height);
    padding: var(--padding);
    background: linear-gradient(135deg, var(--gradient-start), var(--gradient-end));
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    position: relative;
    overflow: hidden;
  }

  .gradient-cta-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.5s;
  }

  .gradient-cta-button:hover::before {
    left: 100%;
  }

  .gradient-cta-button:hover {
    transform: scale(var(--scale-on-hover));
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  }

  .gradient-cta-button:active {
    transform: scale(0.98);
  }

  .gradient-cta-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none;
  }

  .gradient-cta-button:disabled:hover {
    transform: none;
  }
</style>

<button
  class="gradient-cta-button"
  style="
    --border-radius: {borderRadius}px;
    --font-weight: {fontWeight};
    --text-color: {textColor};
    --gradient-start: {gradientColors[0]};
    --gradient-end: {gradientColors[1]};
    --animation-duration: {animationDuration};
    --scale-on-hover: {scaleOnHover};
    --padding: {padding};
    --min-width: {minWidth};
    --min-height: {minHeight};
    font-size: {fontSize}px;
  "
  {disabled}
  on:click={handleClick}
>
  {text}
</button>
