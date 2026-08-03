<script lang="ts">
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { Search, Plus } from 'lucide-svelte';

	// Adiciona uma matéria da matriz do curso ao pool. A página resolve turmas.
	let { onAdd }: { onAdd: (codigo: string) => void } = $props();

	let query = $state('');

	const resultados = $derived.by(() => {
		const q = query.trim().toLowerCase();
		if (q.length < 2) return [];
		const mats = fluxogramaStore.state.courseData?.materias ?? [];
		return mats
			.filter(
				(m) =>
					!gradeStore.hasMateria(m.codigoMateria) &&
					(m.codigoMateria.toLowerCase().includes(q) || m.nomeMateria.toLowerCase().includes(q))
			)
			.slice(0, 8);
	});

	function adicionar(codigo: string) {
		onAdd(codigo);
		query = '';
	}
</script>

<div class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3">
	<div class="relative">
		<Search class="pointer-events-none absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-white/40" />
		<input
			type="text"
			bind:value={query}
			placeholder="Adicionar matéria (código ou nome)..."
			class="w-full rounded-full border border-white/15 bg-white/5 py-2 pl-9 pr-3 text-xs text-white placeholder:text-white/40 focus:border-white/30 focus:outline-none"
		/>
	</div>

	{#if resultados.length > 0}
		<div class="mt-2 space-y-1">
			{#each resultados as m (m.idMateria)}
				<button
					type="button"
					onclick={() => adicionar(m.codigoMateria)}
					class="flex w-full items-center gap-2 rounded-lg border border-white/10 bg-black/25 px-2.5 py-1.5 text-left transition-colors hover:bg-white/5"
				>
					<Plus class="h-3.5 w-3.5 shrink-0 text-purple-300" />
					<span class="font-mono text-[11px] font-semibold text-white/85">{m.codigoMateria}</span>
					<span class="truncate text-[11px] text-white/55">{m.nomeMateria}</span>
				</button>
			{/each}
		</div>
	{:else if query.trim().length >= 2}
		<p class="mt-2 px-1 text-[11px] text-white/40">Nenhuma matéria nova encontrada na sua matriz.</p>
	{/if}
</div>
