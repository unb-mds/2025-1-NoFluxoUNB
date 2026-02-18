<script lang="ts">
	import { cn } from '$lib/utils';

	interface Props {
		text: string;
		fontSize?: number;
		textColor?: string;
		fontWeight?: string;
		gradientColors?: [string, string];
		animationDuration?: number;
		underlineHeight?: number;
		class?: string;
		onclick?: () => void;
	}

	let {
		text,
		fontSize = 19,
		textColor = 'white',
		fontWeight = 'bold',
		gradientColors = ['#9C27B0', '#E91E63'],
		animationDuration = 300,
		underlineHeight = 2,
		class: className = '',
		onclick
	}: Props = $props();

	let isHovered = $state(false);
</script>

<button
	class={cn(
		'relative inline-flex items-center justify-center',
		'px-2 py-1 bg-transparent border-none cursor-pointer',
		'font-marker',
		className
	)}
	style="
		font-size: {fontSize}px;
		font-weight: {fontWeight};
		color: {textColor};
	"
	onmouseenter={() => (isHovered = true)}
	onmouseleave={() => (isHovered = false)}
	{onclick}
>
	<span>{text}</span>

	<span
		class="absolute bottom-0 left-0 transition-all"
		style="
			height: {underlineHeight}px;
			width: {isHovered ? '100%' : '0%'};
			background: linear-gradient(90deg, {gradientColors[0]}, {gradientColors[1]});
			transition-duration: {animationDuration}ms;
			transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
		"
	></span>
</button>

<style>
	button {
		transition: transform 0.2s ease;
	}
	button:hover {
		transform: translateY(-1px);
	}
	button:active {
		transform: translateY(0);
	}
</style>
