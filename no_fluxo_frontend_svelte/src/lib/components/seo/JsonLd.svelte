<script lang="ts">
	interface Props {
		data: Record<string, unknown>;
	}

	let { data }: Props = $props();
</script>

<svelte:head>
	{@html `<script type="application/ld+json">${JSON.stringify(data)}</script>`}
</svelte:head>
