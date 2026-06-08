<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';

	let dotX = $state(-100);
	let dotY = $state(-100);
	let ringX = $state(-100);
	let ringY = $state(-100);
	let isHovering = $state(false);
	let isVisible = $state(false);
	let isClicking = $state(false);
	let isTouch = $state(false);

	onMount(() => {
		if (!browser) return;
		if (window.matchMedia('(hover: none)').matches) {
			isTouch = true;
			return;
		}

		let targetX = -100;
		let targetY = -100;
		let rafId: number;

		function lerp(a: number, b: number, t: number) {
			return a + (b - a) * t;
		}

		function tick() {
			ringX = lerp(ringX, targetX, 0.1);
			ringY = lerp(ringY, targetY, 0.1);
			rafId = requestAnimationFrame(tick);
		}

		function onMove(e: MouseEvent) {
			targetX = e.clientX;
			targetY = e.clientY;
			dotX = e.clientX;
			dotY = e.clientY;
			if (!isVisible) isVisible = true;
		}

		function onOver(e: MouseEvent) {
			const t = e.target as HTMLElement;
			isHovering = !!t.closest(
				'a, button, [role="button"], [tabindex="0"], input, select, textarea, label, .tab-btn'
			);
		}

		function onDown() {
			isClicking = true;
		}
		function onUp() {
			isClicking = false;
		}

		document.documentElement.classList.add('custom-cursor');
		document.addEventListener('mousemove', onMove);
		document.addEventListener('mouseover', onOver);
		document.addEventListener('mousedown', onDown);
		document.addEventListener('mouseup', onUp);
		rafId = requestAnimationFrame(tick);

		return () => {
			document.documentElement.classList.remove('custom-cursor');
			document.removeEventListener('mousemove', onMove);
			document.removeEventListener('mouseover', onOver);
			document.removeEventListener('mousedown', onDown);
			document.removeEventListener('mouseup', onUp);
			cancelAnimationFrame(rafId);
		};
	});
</script>

{#if !isTouch && isVisible}
	<div
		class="cur-dot"
		class:cur-dot--hover={isHovering}
		class:cur-dot--click={isClicking}
		style="transform: translate({dotX - 4}px, {dotY - 4}px)"
		aria-hidden="true"
	></div>
	<div
		class="cur-ring"
		class:cur-ring--hover={isHovering}
		class:cur-ring--click={isClicking}
		style="transform: translate({ringX - 22}px, {ringY - 22}px)"
		aria-hidden="true"
	></div>
{/if}

<style>
	:global(html.custom-cursor),
	:global(html.custom-cursor *) {
		cursor: none !important;
	}

	.cur-dot,
	.cur-ring {
		position: fixed;
		top: 0;
		left: 0;
		pointer-events: none;
		z-index: 99999;
		border-radius: 50%;
		will-change: transform;
	}

	.cur-dot {
		width: 8px;
		height: 8px;
		background: hsl(var(--primary));
		box-shadow: 0 0 8px hsl(var(--primary) / 0.8);
		transition:
			width 0.15s ease,
			height 0.15s ease,
			opacity 0.15s ease;
	}

	.cur-dot--hover {
		width: 5px;
		height: 5px;
		background: #fff;
		box-shadow: 0 0 6px hsl(0 0% 100% / 0.9);
	}

	.cur-dot--click {
		width: 3px;
		height: 3px;
		opacity: 0.6;
	}

	.cur-ring {
		width: 44px;
		height: 44px;
		border: 1.5px solid hsl(var(--primary) / 0.55);
		background: transparent;
		transition:
			width 0.3s cubic-bezier(0.16, 1, 0.3, 1),
			height 0.3s cubic-bezier(0.16, 1, 0.3, 1),
			border-color 0.3s ease,
			border-width 0.3s ease,
			background 0.3s ease;
	}

	.cur-ring--hover {
		width: 60px;
		height: 60px;
		border-color: hsl(var(--primary) / 0.9);
		border-width: 2px;
		background: hsl(var(--primary) / 0.06);
	}

	.cur-ring--click {
		width: 34px;
		height: 34px;
		border-color: hsl(var(--primary));
		background: hsl(var(--primary) / 0.1);
	}
</style>
