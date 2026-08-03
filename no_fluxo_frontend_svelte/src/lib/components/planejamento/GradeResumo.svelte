<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias } from '$lib/utils/sigaa';
	import { X, ListChecks, TriangleAlert } from 'lucide-svelte';

	function nomeMateria(codigo: string): string {
		return gradeStore.pool.find((m) => m.codigo === codigo)?.nome ?? codigo;
	}
	function creditosMateria(codigo: string): number {
		return gradeStore.pool.find((m) => m.codigo === codigo)?.creditos ?? 0;
	}
	function horarioLegivel(horario: string | null): string {
		const linhas = formatHorarioSigaa(horario ?? '');
		if (linhas.length === 0) return 'Horário a definir';
		return linhas.map((l) => `${l.dia} ${compactarFaixasHorarias(l.faixas)}`).join(' · ');
	}
</script>

<section class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3">
	<header class="mb-2.5 flex items-center justify-between border-b border-white/10 pb-2">
		<p class="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-[0.12em] text-white/80">
			<ListChecks class="h-3.5 w-3.5" /> Resumo
		</p>
		<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] text-white/60">
			{gradeStore.creditosSelecionados} créditos
		</span>
	</header>

	{#if gradeStore.selecao.size === 0}
		<p class="py-6 text-center text-xs text-white/40">Nenhuma matéria na grade ainda.</p>
	{:else}
		<ul class="space-y-2">
			{#each [...gradeStore.selecao] as [codigo, tg] (codigo)}
				{@const cor = gradeStore.corDaMateria(codigo)}
				{@const coReqsFaltando = gradeStore.coReqsFaltando(codigo)}
				<li
					class="flex items-start gap-2 rounded-xl border border-white/10 bg-black/25 px-2.5 py-2"
					onmouseenter={() => gradeStore.setHover(codigo)}
					onmouseleave={() => gradeStore.setHover(null)}
				>
					<span class="mt-1 h-2.5 w-2.5 shrink-0 rounded-full {cor.dot}"></span>
					<div class="min-w-0 flex-1">
						<p class="flex items-baseline gap-1.5">
							<span class="font-mono text-xs font-semibold text-white/90">{codigo}</span>
							<span class="text-[10px] text-white/45">T. {tg.turma.turma} · {creditosMateria(codigo)}cr</span>
						</p>
						<p class="truncate text-[11px] text-white/60">{nomeMateria(codigo)}</p>
						<p class="truncate text-[10px] text-white/40">{horarioLegivel(tg.turma.horario)}</p>
						{#if coReqsFaltando.length > 0}
							<p class="mt-0.5 flex items-start gap-1 text-[10px] font-medium text-amber-300/90">
								<TriangleAlert class="mt-px h-3 w-3 shrink-0" />
								<span>Co-requisito fora da grade: {coReqsFaltando.join(', ')}</span>
							</p>
						{/if}
					</div>
					<button
						type="button"
						onclick={() => gradeStore.removerTurma(codigo)}
						class="touch-manipulation rounded-lg p-1.5 text-white/40 transition-colors hover:bg-white/10 hover:text-white/80"
						aria-label="Tirar {codigo} da grade"
					>
						<X class="h-4 w-4" />
					</button>
				</li>
			{/each}
		</ul>
	{/if}
</section>
