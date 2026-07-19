<script lang="ts">
	import { gradeStore } from '$lib/stores/grade.store.svelte';
	import { DIAS_SEMANA, SLOTS_DIA, bitIndex } from '$lib/utils/horario-slots';

	// Rótulo só aparece na primeira célula de uma sequência vertical da mesma
	// matéria (reduz repetição visual quando ocupa módulos consecutivos).
	function slotInfo(diaCod: string, si: number) {
		const bi = bitIndex(diaCod, SLOTS_DIA[si].offset);
		const codigo = gradeStore.ocupacao.get(bi);
		const acima =
			si > 0 ? gradeStore.ocupacao.get(bitIndex(diaCod, SLOTS_DIA[si - 1].offset)) : undefined;
		return { codigo, showLabel: !!codigo && codigo !== acima };
	}

	function tooltip(codigo: string): string {
		const sel = gradeStore.turmaSelecionada(codigo);
		if (!sel) return codigo;
		const t = sel.turma;
		return `${codigo} · Turma ${t.turma}${t.docente ? ` · ${t.docente}` : ''}`;
	}
</script>

<div class="overflow-x-auto rounded-2xl border border-white/10 bg-zinc-950/78 p-3 sm:p-4">
	<div
		class="grid min-w-[620px] gap-px"
		style="grid-template-columns: 3.25rem repeat(6, minmax(0, 1fr));"
	>
		<!-- Canto + cabeçalho de dias -->
		<div class="sticky left-0 z-10 bg-zinc-950/78"></div>
		{#each DIAS_SEMANA as dia (dia.cod)}
			<div class="pb-1 text-center text-xs font-semibold uppercase tracking-wide text-white/70">
				{dia.label}
			</div>
		{/each}

		<!-- Linhas de módulos -->
		{#each SLOTS_DIA as slot, si (slot.label)}
			<div
				class="sticky left-0 z-10 flex flex-col items-end justify-center bg-zinc-950/78 pr-1.5 text-right {slot.modulo ===
				1
					? 'mt-1'
					: ''}"
			>
				<span class="font-mono text-[11px] font-semibold text-white/60">{slot.label}</span>
				<span class="text-[9px] tabular-nums text-white/35">{slot.inicio}</span>
			</div>

			{#each DIAS_SEMANA as dia (dia.cod)}
				{@const info = slotInfo(dia.cod, si)}
				{#if info.codigo}
					{@const cor = gradeStore.corDaMateria(info.codigo)}
					<div
						title={tooltip(info.codigo)}
						class="flex min-h-[1.9rem] items-center justify-center border px-0.5 text-center {cor.cell} {cor.text} {slot.modulo ===
						1
							? 'mt-1'
							: ''}"
					>
						{#if info.showLabel}
							<span class="truncate font-mono text-[10px] font-bold leading-tight">{info.codigo}</span>
						{/if}
					</div>
				{:else}
					<div
						class="min-h-[1.9rem] rounded-[3px] border border-white/[0.04] bg-white/[0.015] {slot.modulo ===
						1
							? 'mt-1'
							: ''}"
					></div>
				{/if}
			{/each}
		{/each}
	</div>
</div>
