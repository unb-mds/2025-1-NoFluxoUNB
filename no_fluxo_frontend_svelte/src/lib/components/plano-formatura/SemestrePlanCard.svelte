<script lang="ts">
	import type { SemestrePlano } from '$lib/types/plano-formatura';
	import MateriaPlanCard from './MateriaPlanCard.svelte';
	import SlotCard from './SlotCard.svelte';
	import { CalendarDays, BookOpen } from 'lucide-svelte';

	interface Props {
		semestre: SemestrePlano;
		/** Índice 0-based para determinar se é o próximo semestre (index === 0). */
		index: number;
		/** Unidade de exibição: 'creditos' ou 'horas'. */
		displayUnit?: 'creditos' | 'horas';
	}

	let { semestre, index, displayUnit = 'creditos' }: Props = $props();

	const isFirst = $derived(index === 0);
	const isRecomendado = $derived(semestre.tipo === 'recomendado');

	/** Calcula a carga horária usando _horasInternas se disponível, senão converte créditos. */
	const totalHoras = $derived(
		semestre._horasInternas ?? Math.ceil(semestre.creditos * 15)
	);

	/** Exibição de carga — usa horas se selecionado, senão créditos. */
	const displayValue = $derived(
		displayUnit === 'horas' ? totalHoras : semestre.creditos
	);
	const displayLabel = $derived(displayUnit === 'horas' ? 'h' : 'créditos');

	const containerClass = $derived(
		isFirst
			? 'border-blue-500/50 bg-white/[0.03] shadow-[0_0_0_1px_hsl(220_80%_60%/0.15),0_4px_24px_hsl(220_80%_40%/0.15)]'
			: 'border-white/10 bg-white/[0.02]'
	);

	const headerBg = $derived(
		isFirst
			? 'bg-blue-600/10 border-b border-blue-500/20'
			: 'bg-white/[0.03] border-b border-white/8'
	);

	const tagClass = $derived(
		isRecomendado
			? 'bg-blue-600/20 text-blue-300 ring-1 ring-blue-500/30'
			: 'bg-white/8 text-white/45 ring-1 ring-white/10'
	);

	const creditBadgeClass = $derived(
		isFirst
			? 'bg-blue-600/20 text-blue-200 ring-1 ring-blue-500/30'
			: 'bg-white/8 text-white/60 ring-1 ring-white/10'
	);
</script>

<div
	class="flex h-full w-72 shrink-0 flex-col overflow-hidden rounded-2xl border {containerClass}"
>
	<!-- Header -->
	<div class="{headerBg} px-4 py-3.5">
		<div class="flex items-center justify-between gap-2">
			<div class="flex items-center gap-2">
				<CalendarDays class="h-4 w-4 {isFirst ? 'text-blue-400' : 'text-white/35'}" />
				<span class="text-sm font-semibold {isFirst ? 'text-white' : 'text-white/70'}">
					{semestre.semestre}
				</span>
			</div>
			<span class="rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider {tagClass}">
				{isRecomendado ? 'Próximo' : 'Estimado'}
			</span>
		</div>

		<!-- Stats row -->
		<div class="mt-2.5 flex items-center gap-3">
			<div class="flex items-center gap-1.5">
				<span class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold {creditBadgeClass}">
					{displayValue} {displayLabel}
				</span>
			</div>
			<div class="flex items-center gap-1 text-[11px] text-white/35">
				<BookOpen class="h-3 w-3" />
				<span>{semestre.materias.length} disciplinas</span>
			</div>
		</div>
	</div>

	<!-- Matérias list — scrollable -->
	<div class="flex flex-1 flex-col gap-2 overflow-y-auto p-3">
		{#if semestre.materias.length === 0}
			<div class="flex flex-1 items-center justify-center py-8">
				<p class="text-center text-xs text-white/25 leading-relaxed">
					Nenhuma matéria<br/>obrigatória pendente
				</p>
			</div>
		{:else}
			{#each semestre.materias as item, idx ('codigo' in item ? item.codigo : `slot-${item.tipo}-${idx}`)}
				{#if 'codigo' in item}
					<MateriaPlanCard materia={item} tipoSemestre={semestre.tipo} />
				{:else}
					<SlotCard slot={item} />
				{/if}
			{/each}
		{/if}
	</div>
</div>
