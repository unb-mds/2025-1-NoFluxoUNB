<script lang="ts">
	import { Skeleton } from '$lib/components/ui/skeleton';

	interface Props {
		title?: string;
	}

	let { title = 'Carregando...' }: Props = $props();
</script>

<div class="space-y-6 animate-in fade-in duration-300">
	<!-- Header skeleton -->
	<div class="space-y-2">
		<Skeleton class="h-8 w-48" />
		<Skeleton class="h-4 w-72" />
	</div>

	<!-- Content skeleton -->
	<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
		{#each Array(6) as _}
			<div class="rounded-lg border p-4 space-y-3">
				<Skeleton class="h-4 w-3/4" />
				<Skeleton class="h-4 w-1/2" />
				<Skeleton class="h-20 w-full" />
			</div>
		{/each}
	</div>
</div>

<span class="sr-only">{title}</span>
