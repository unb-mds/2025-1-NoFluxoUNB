<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import TurmaOption from './TurmaOption.svelte';
	import { TriangleAlert, Star, Trash2 } from 'lucide-svelte';

	// Alterna a turma de uma matéria: clicar na já selecionada remove; senão seleciona.
	function toggle(codigo: string, idTurma: number) {
		if (gradeStore.turmaSelecionada(codigo)?.turma.id_turmas === idTurma) {
			gradeStore.removerTurma(codigo);
		} else {
			gradeStore.selecionarTurma(codigo, idTurma);
		}
	}
</script>

<div class="space-y-3">
	{#each gradeStore.pool as materia (materia.codigo)}
		{@const cor = gradeStore.corDaMateria(materia.codigo)}
		{@const selecionada = gradeStore.turmaSelecionada(materia.codigo)}
		{@const prioritaria = gradeStore.isPrioritaria(materia.codigo)}
		<section
			class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3"
			role="group"
			onmouseenter={() => gradeStore.setHover(materia.codigo)}
			onmouseleave={() => gradeStore.setHover(null)}
		>
			<header class="mb-2.5 flex items-start gap-2.5 border-b border-white/10 pb-2.5">
				<span class="mt-1 h-2.5 w-2.5 shrink-0 rounded-full {cor.dot}"></span>
				<div class="min-w-0 flex-1">
					<p class="flex flex-wrap items-baseline gap-x-2">
						<span class="font-mono text-sm font-semibold text-white/90">{materia.codigo}</span>
						<span class="truncate text-xs text-white/60">{materia.nome}</span>
					</p>
					<p class="mt-0.5 text-[11px] text-white/40">
						{materia.creditos} créditos ·
						{#if selecionada}
							<span class="text-white/70">Turma {selecionada.turma.turma} selecionada</span>
						{:else if materia.turmas.length === 0}
							<span class="text-amber-300/80">Sem turma ofertada neste período</span>
						{:else}
							{materia.turmas.length} turma(s) disponível(is)
						{/if}
					</p>
					{#if materia.avisoPreRequisito}
						<p class="mt-1 flex items-start gap-1 text-[10px] font-medium text-amber-300/90">
							<TriangleAlert class="mt-px h-3 w-3 shrink-0" />
							<span>Pré-requisito pendente: {materia.avisoPreRequisito}</span>
						</p>
					{/if}
				</div>
				<div class="flex shrink-0 items-center gap-0.5">
					<button
						type="button"
						onclick={() => gradeStore.togglePrioridade(materia.codigo)}
						title={prioritaria ? 'Prioritária ao rearranjar — clique p/ remover' : 'Priorizar ao rearranjar'}
						aria-pressed={prioritaria}
						class="touch-manipulation rounded-lg p-1.5 transition-colors {prioritaria ? 'text-amber-300 hover:bg-amber-400/10' : 'text-white/30 hover:bg-white/10 hover:text-white/60'}"
					>
						<Star class="h-4 w-4 {prioritaria ? 'fill-current' : ''}" />
					</button>
					<button
						type="button"
						onclick={() => gradeStore.removerMateriaDoPool(materia.codigo)}
						title="Remover matéria da lista"
						aria-label="Remover {materia.codigo} da lista"
						class="touch-manipulation rounded-lg p-1.5 text-white/30 transition-colors hover:bg-red-500/15 hover:text-red-300"
					>
						<Trash2 class="h-4 w-4" />
					</button>
				</div>
			</header>

			{#if materia.turmas.length > 0}
				<div class="max-h-60 space-y-1.5 overflow-y-auto pr-0.5">
					{#each materia.turmas as tg (tg.turma.id_turmas)}
						<TurmaOption codigo={materia.codigo} {tg} onToggle={() => toggle(materia.codigo, tg.turma.id_turmas)} />
					{/each}
				</div>
			{/if}
		</section>
	{/each}
</div>
