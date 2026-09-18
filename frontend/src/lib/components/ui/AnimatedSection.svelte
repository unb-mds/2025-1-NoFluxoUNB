<script lang="ts">
	import { inview } from '$lib/actions/inview';
	import { fly, fade } from 'svelte/transition';
	import type { Snippet } from 'svelte';

	interface Props {
		animation?: 'fade' | 'slide-up' | 'slide-left' | 'slide-right';
		delay?: number;
		duration?: number;
		class?: string;
		children: Snippet;
	}

	let {
		animation = 'slide-up',
		delay = 0,
		duration = 600,
		class: className = '',
		children
	}: Props = $props();

	let isVisible = $state(false);

	function handleInView() {
		isVisible = true;
	}

	const flyConfigs = {
		fade: { y: 0, x: 0 },
		'slide-up': { y: 50, x: 0 },
		'slide-left': { x: -50, y: 0 },
		'slide-right': { x: 50, y: 0 }
	};

	const config = flyConfigs[animation] || flyConfigs['slide-up'];
</script>

<div use:inview={{ onInView: handleInView }} class={className}>
	{#if isVisible}
		<div in:fly={{ ...config, duration, delay, opacity: 0 }}>
			{@render children()}
		</div>
	{:else}
		<div class="opacity-0">
			{@render children()}
		</div>
	{/if}
</div>
