<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { DIAS_SEMANA, SLOTS_DIA, bitIndex, agruparBlocosDia } from '$lib/utils/horario-slots';
	import { CalendarClock, ChevronsUpDown } from 'lucide-svelte';

	// Clicar num bloco abre a troca de turma daquela matéria (na página).
	let { onBlocoClick }: { onBlocoClick: (codigo: string) => void } = $props();

	let mostrarTudo = $state(false);

	// Para cada dia, os blocos contínuos (módulos consecutivos da mesma matéria).
	const gridPorDia = $derived.by(() =>
		DIAS_SEMANA.map((dia) => {
			const codigos = SLOTS_DIA.map((slot) =>
				gradeStore.ocupacao.get(bitIndex(dia.cod, slot.offset))
			);
			return { dia, blocos: agruparBlocosDia(codigos) };
		})
	);

	const temAlgo = $derived(gradeStore.ocupacao.size > 0);

	// Turnos com pelo menos um bloco — os vazios são colapsados (a menos que expandido).
	const turnosUsados = $derived.by(() => {
		const usados = new Set<'M' | 'T' | 'N'>();
		for (const coluna of gridPorDia) {
			for (const bloco of coluna.blocos) {
				for (let i = bloco.offsetStart; i < bloco.offsetStart + bloco.span; i++) {
					usados.add(SLOTS_DIA[i].turno);
				}
			}
		}
		return usados;
	});

	/** Linhas visíveis: tudo quando expandido/vazio; senão só turnos usados. */
	const slotsVisiveis = $derived.by(() => {
		if (mostrarTudo || !temAlgo) return SLOTS_DIA.map((slot, i) => ({ slot, orig: i }));
		return SLOTS_DIA.map((slot, i) => ({ slot, orig: i })).filter(({ slot }) =>
			turnosUsados.has(slot.turno)
		);
	});

	/** offset global → linha visível (índice em slotsVisiveis). */
	const linhaVisivel = $derived.by(() => {
		const m = new Map<number, number>();
		slotsVisiveis.forEach(({ orig }, vis) => m.set(orig, vis));
		return m;
	});

	const haTurnoOculto = $derived(temAlgo && slotsVisiveis.length < SLOTS_DIA.length);

	// Legenda: matérias com turma selecionada, na ordem do pool.
	const legenda = $derived(
		gradeStore.pool.filter((m) => gradeStore.selecao.has(m.codigo))
	);

	function faixaHoraria(offsetStart: number, span: number): string {
		return `${SLOTS_DIA[offsetStart].inicio}–${SLOTS_DIA[offsetStart + span - 1].fim}`;
	}

	function hoverClasses(codigo: string): string {
		const h = gradeStore.hoverCodigo;
		if (!h) return '';
		return h === codigo ? 'ring-2 ring-white/50 brightness-110' : 'opacity-30';
	}
</script>

<div class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3 sm:p-4" id="grade-export">
	<div class="overflow-x-auto">
		<div
			class="relative grid min-w-[600px]"
			style="grid-template-columns: 3.25rem repeat(6, minmax(0, 1fr)); grid-template-rows: auto repeat({slotsVisiveis.length}, minmax(2.15rem, 1fr));"
		>
			<!-- Canto -->
			<div style="grid-column: 1; grid-row: 1;"></div>
			<!-- Cabeçalho de dias -->
			{#each DIAS_SEMANA as dia, di (dia.cod)}
				<div
					class="pb-1.5 text-center text-xs font-semibold uppercase tracking-wide text-white/70"
					style="grid-column: {di + 2}; grid-row: 1;"
				>
					{dia.label}
				</div>
			{/each}

			<!-- Eixo de horários -->
			{#each slotsVisiveis as { slot }, vi (slot.label)}
				<div
					class="flex flex-col items-end justify-center pr-1.5 text-right {slot.modulo === 1
						? 'border-t border-white/10'
						: ''}"
					style="grid-column: 1; grid-row: {vi + 2};"
				>
					<span class="font-mono text-[10px] font-semibold text-white/55">{slot.label}</span>
					<span class="text-[8px] tabular-nums text-white/30">{slot.inicio}</span>
				</div>
			{/each}

			<!-- Células de fundo -->
			{#each DIAS_SEMANA as dia, di (dia.cod)}
				{#each slotsVisiveis as { slot }, vi (slot.label)}
					<div
						class="border-l border-white/[0.05] {slot.modulo === 1 ? 'border-t border-white/10' : ''}"
						style="grid-column: {di + 2}; grid-row: {vi + 2};"
					></div>
				{/each}
			{/each}

			<!-- Blocos das matérias -->
			{#each gridPorDia as coluna, di (coluna.dia.cod)}
				{#each coluna.blocos as bloco (bloco.codigo + '-' + bloco.offsetStart)}
					{@const cor = gradeStore.corDaMateria(bloco.codigo)}
					{@const sel = gradeStore.turmaSelecionada(bloco.codigo)}
					{@const linha = linhaVisivel.get(bloco.offsetStart)}
					{#if linha !== undefined}
						<button
							type="button"
							onclick={() => onBlocoClick(bloco.codigo)}
							onmouseenter={() => gradeStore.setHover(bloco.codigo)}
							onmouseleave={() => gradeStore.setHover(null)}
							title="Trocar turma de {bloco.codigo}"
							class="m-0.5 flex flex-col items-start justify-center overflow-hidden rounded-md border px-1.5 py-1 text-left transition-all hover:scale-[1.02] {cor.cell} {cor.text} {hoverClasses(bloco.codigo)}"
							style="grid-column: {di + 2}; grid-row: {linha + 2} / span {bloco.span};"
						>
							<span class="truncate font-mono text-[11px] font-bold leading-tight">{bloco.codigo}</span>
							{#if sel}
								<span class="truncate text-[9px] opacity-80">T. {sel.turma.turma}</span>
							{/if}
							{#if bloco.span > 1}
								<span class="truncate text-[8px] tabular-nums opacity-70">
									{faixaHoraria(bloco.offsetStart, bloco.span)}
								</span>
							{/if}
						</button>
					{/if}
				{/each}
			{/each}
		</div>
	</div>

	<!-- Rodapé: legenda + expandir turnos -->
	{#if temAlgo}
		<div class="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-white/10 pt-2.5">
			<div class="flex flex-wrap items-center gap-1.5">
				{#each legenda as m (m.codigo)}
					{@const cor = gradeStore.corDaMateria(m.codigo)}
					<button
						type="button"
						onclick={() => onBlocoClick(m.codigo)}
						onmouseenter={() => gradeStore.setHover(m.codigo)}
						onmouseleave={() => gradeStore.setHover(null)}
						title={m.nome}
						class="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] font-medium text-white/75 transition-colors hover:bg-white/10"
					>
						<span class="h-2 w-2 rounded-full {cor.dot}"></span>
						<span class="font-mono">{m.codigo}</span>
					</button>
				{/each}
			</div>
			{#if haTurnoOculto || mostrarTudo}
				<button
					type="button"
					onclick={() => (mostrarTudo = !mostrarTudo)}
					class="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] text-white/55 transition-colors hover:bg-white/10"
				>
					<ChevronsUpDown class="h-3 w-3" />
					{mostrarTudo ? 'Ocultar turnos vazios' : 'Mostrar todos os horários'}
				</button>
			{/if}
		</div>
	{:else}
		<p class="mt-3 flex items-center justify-center gap-2 py-6 text-center text-xs text-white/40">
			<CalendarClock class="h-4 w-4" />
			Escolha turmas nas matérias (ou clique em "Montar automático") para ver sua grade.
		</p>
	{/if}
</div>
