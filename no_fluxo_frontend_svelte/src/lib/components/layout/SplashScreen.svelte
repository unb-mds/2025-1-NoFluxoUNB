<script lang="ts">
	import { onMount } from 'svelte';

	let visible = $state(true);

	onMount(() => {
		const timeout = setTimeout(() => {
			visible = false;
		}, 500);

		return () => clearTimeout(timeout);
	});
</script>

{#if visible}
	<div class="fixed inset-0 z-[200] flex items-center justify-center bg-background transition-opacity duration-300">
		<div class="text-center">
			<div class="mx-auto h-16 w-16 animate-pulse rounded-full bg-primary/20 flex items-center justify-center">
				<span class="text-2xl font-bold text-primary">NF</span>
			</div>
			<p class="mt-4 text-lg font-medium text-primary">NoFluxo</p>
			<p class="text-sm text-muted-foreground">Carregando...</p>
		</div>
	</div>
{/if}
