<script lang="ts">
	import { cn } from '$lib/utils';
	import type { Snippet } from 'svelte';

	interface Props {
		padding?: string;
		borderRadius?: number;
		backgroundOpacity?: number;
		borderOpacity?: number;
		blurAmount?: number;
		class?: string;
		gradient?: string | null;
		shadow?: boolean;
		border?: boolean;
		children?: Snippet;
	}

	let {
		padding = 'p-4',
		borderRadius = 16,
		backgroundOpacity = 0.1,
		borderOpacity = 0.2,
		blurAmount = 10,
		class: className = '',
		gradient = null,
		shadow = false,
		border = true,
		children
	}: Props = $props();

	let computedStyle = $derived(`
		backdrop-filter: blur(${blurAmount}px);
		-webkit-backdrop-filter: blur(${blurAmount}px);
		background: ${gradient || `rgba(255, 255, 255, ${backgroundOpacity})`};
		border-radius: ${borderRadius}px;
		${border ? `border: 1px solid rgba(255, 255, 255, ${borderOpacity});` : ''}
		${shadow ? 'box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);' : ''}
	`);
</script>

<div
	class={cn('glass-container relative overflow-hidden', padding, className)}
	style={computedStyle}
>
	<div
		class="absolute inset-0 pointer-events-none bg-gradient-to-br from-white/10 via-white/5 to-transparent"
	></div>
	<div class="relative z-10">
		{@render children?.()}
	</div>
</div>

<style>
	.glass-container {
		will-change: backdrop-filter;
	}
</style>
