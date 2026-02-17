<script lang="ts">
	import type { Component } from 'svelte';

	interface Props {
		icon: Component;
		title: string;
		description: string;
		gradientFrom: string;
		gradientTo: string;
	}

	let { icon: Icon, title, description, gradientFrom, gradientTo }: Props = $props();
	let isHovered = $state(false);
</script>

<div
	onmouseenter={() => (isHovered = true)}
	onmouseleave={() => (isHovered = false)}
	class="feature-card"
	style="transform: scale({isHovered ? 1.05 : 1});"
>
	<div
		class="feature-icon"
		style="background: linear-gradient(135deg, {gradientFrom}, {gradientTo});"
	>
		<Icon class="h-8 w-8 text-white" />
	</div>

	<h3 class="feature-card-title">{title}</h3>
	<p class="feature-card-desc">{description}</p>
</div>

<style>
	.feature-card {
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		padding: 1.5rem;
		text-align: center;
		transition: transform 0.2s ease;
	}

	.feature-icon {
		width: 64px;
		height: 64px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 1rem;
	}

	.feature-card-title {
		font-family: 'Permanent Marker', cursive;
		color: white;
		font-size: 1.25rem;
		margin-bottom: 0.5rem;
	}

	.feature-card-desc {
		color: #d1d5db;
		font-size: 0.95rem;
		line-height: 1.5;
	}
</style>
