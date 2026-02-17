<script lang="ts">
	import { navigating } from '$app/stores';
</script>

{#if $navigating}
	<div class="fixed left-0 right-0 top-0 z-[100]">
		<div class="h-1 w-full overflow-hidden bg-primary/20">
			<div class="loading-bar h-full bg-primary"></div>
		</div>
	</div>
{/if}

<style>
	.loading-bar {
		width: 100%;
		animation: loading 1s ease-in-out infinite;
		transform-origin: left;
	}

	@keyframes loading {
		0% {
			transform: translateX(-100%);
		}
		50% {
			transform: translateX(0%);
		}
		100% {
			transform: translateX(100%);
		}
	}
</style>
