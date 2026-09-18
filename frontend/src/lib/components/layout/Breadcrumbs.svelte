<script lang="ts">
	import { page } from '$app/stores';
	import { getBreadcrumbs } from '$lib/stores/navigation';
	import { ChevronRight, Home } from 'lucide-svelte';

	let breadcrumbs = $derived(getBreadcrumbs($page.url.pathname));
</script>

{#if breadcrumbs.length > 1}
	<nav class="mb-4" aria-label="Breadcrumb">
		<ol class="flex items-center space-x-2 text-sm">
			{#each breadcrumbs as crumb, i}
				<li class="flex items-center">
					{#if i > 0}
						<ChevronRight class="mx-2 h-4 w-4 text-muted-foreground" />
					{/if}

					{#if i === breadcrumbs.length - 1}
						<span class="font-medium text-foreground">{crumb.label}</span>
					{:else}
						<a href={crumb.href} class="text-muted-foreground transition-colors hover:text-foreground">
							{#if i === 0}
								<Home class="h-4 w-4" />
								<span class="sr-only">{crumb.label}</span>
							{:else}
								{crumb.label}
							{/if}
						</a>
					{/if}
				</li>
			{/each}
		</ol>
	</nav>
{/if}
