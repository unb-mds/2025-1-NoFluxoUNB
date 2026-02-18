<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		onclick?: () => void;
		href?: string;
		variant?: 'primary' | 'secondary' | 'cta';
		class?: string;
		children: Snippet;
	}

	let {
		onclick,
		href,
		variant = 'primary',
		class: className = '',
		children
	}: Props = $props();

	let isHovered = $state(false);

	const variants: Record<string, string> = {
		primary: 'bg-gradient-to-r from-blue-400 to-blue-700',
		secondary: 'bg-gradient-to-r from-purple-500 to-pink-500',
		cta: 'bg-gradient-to-r from-sky-500 to-blue-700'
	};
</script>

{#if href}
	<a
		{href}
		onmouseenter={() => (isHovered = true)}
		onmouseleave={() => (isHovered = false)}
		class="inline-block px-6 py-3 rounded-full text-white font-bold shadow-lg
			   transition-all duration-200 ease-in-out
			   {variants[variant]}
			   {isHovered ? 'scale-105' : 'scale-100'}
			   {className}"
	>
		{@render children()}
	</a>
{:else}
	<button
		{onclick}
		onmouseenter={() => (isHovered = true)}
		onmouseleave={() => (isHovered = false)}
		class="inline-block px-6 py-3 rounded-full text-white font-bold shadow-lg
			   transition-all duration-200 ease-in-out
			   {variants[variant]}
			   {isHovered ? 'scale-105' : 'scale-100'}
			   {className}"
	>
		{@render children()}
	</button>
{/if}
