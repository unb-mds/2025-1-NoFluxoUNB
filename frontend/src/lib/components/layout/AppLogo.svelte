<script lang="ts">
	import { cn } from '$lib/utils';

	interface Props {
		text?: string;
		fontSize?: number;
		color?: string;
		showIcon?: boolean;
		showShadow?: boolean;
		class?: string;
	}

	let {
		text = 'NOFLUXO UNB',
		fontSize = 36,
		color = 'white',
		showIcon = true,
		showShadow = true,
		class: className = ''
	}: Props = $props();

	let shadowStyle = $derived(showShadow ? 'text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);' : '');
</script>

<div
	class={cn(
		'flex items-center gap-3',
		'select-none transition-transform duration-200',
		'hover:scale-105',
		className
	)}
	style="
		font-size: {fontSize}px;
		color: {color};
		{shadowStyle}
	"
>
	{#if showIcon}
		<div
			class="flex items-center justify-center bg-gradient-to-br from-purple-500 to-pink-500 rounded-full font-bold text-white"
			style="
				width: {fontSize * 0.8}px;
				height: {fontSize * 0.8}px;
				font-size: {fontSize * 0.4}px;
			"
		>
			N
		</div>
	{/if}

	<span class="leading-none font-sans font-extrabold tracking-tight">
		NO<span class="text-primary">FLUXO</span>
		{#if text.includes('UNB')}
			<span class="text-foreground"> UNB</span>
		{/if}
	</span>
</div>
