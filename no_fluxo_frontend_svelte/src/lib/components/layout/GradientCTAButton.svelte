<script lang="ts">
	import { cn } from '$lib/utils';

	interface Props {
		text: string;
		fontSize?: number;
		textColor?: string;
		fontWeight?: string;
		gradientColors?: [string, string];
		animationDuration?: number;
		scaleOnHover?: number;
		borderRadius?: number;
		padding?: string;
		minWidth?: string;
		minHeight?: string;
		disabled?: boolean;
		class?: string;
		onclick?: () => void;
	}

	let {
		text,
		fontSize = 19,
		textColor = 'white',
		fontWeight = 'bold',
		gradientColors = ['#9C27B0', '#E91E63'],
		animationDuration = 200,
		scaleOnHover = 1.05,
		borderRadius = 30,
		padding = 'px-4 py-3',
		minWidth = '260px',
		minHeight = '40px',
		disabled = false,
		class: className = '',
		onclick
	}: Props = $props();

	let isHovered = $state(false);
</script>

<button
	class={cn(
		'inline-flex items-center justify-center',
		'font-marker border-none cursor-pointer',
		'relative overflow-hidden',
		'shadow-lg hover:shadow-xl',
		'active:scale-[0.98]',
		'disabled:opacity-60 disabled:cursor-not-allowed',
		'transition-all',
		padding,
		className
	)}
	style="
		font-size: {fontSize}px;
		font-weight: {fontWeight};
		color: {textColor};
		border-radius: {borderRadius}px;
		min-width: {minWidth};
		min-height: {minHeight};
		background: linear-gradient(135deg, {gradientColors[0]}, {gradientColors[1]});
		transition-duration: {animationDuration}ms;
		transform: scale({isHovered && !disabled ? scaleOnHover : 1});
	"
	{disabled}
	onmouseenter={() => (isHovered = true)}
	onmouseleave={() => (isHovered = false)}
	{onclick}
>
	<span class="shine-effect"></span>
	<span class="relative z-10">{text}</span>
</button>

<style>
	.shine-effect {
		position: absolute;
		top: 0;
		left: -100%;
		width: 100%;
		height: 100%;
		background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
		transition: left 0.5s ease;
	}

	button:hover:not(:disabled) .shine-effect {
		left: 100%;
	}

	button:disabled .shine-effect {
		display: none;
	}
</style>
