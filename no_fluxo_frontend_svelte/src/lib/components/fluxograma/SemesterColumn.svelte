<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import SubjectCard from './SubjectCard.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	interface Props {
		semester: number;
		subjects: MateriaModel[];
		onSubjectClick?: (materia: MateriaModel) => void;
		onSubjectLongPress?: (materia: MateriaModel) => void;
		headerOffsetY?: number;
	}

	let { semester, subjects, onSubjectClick, onSubjectLongPress, headerOffsetY = 0 }: Props = $props();

	const store = fluxogramaStore;

	const BASE_GAP_REM = 0.5;   // default gap when connections are off
	const MIN_GAP_REM = 1;      // minimum gap in 'all' mode
	const MAX_GAP_REM = 5;      // maximum gap in 'all' mode
	const GAP_PER_CONNECTION = 0.25; // extra rem per connection touching this column

	let verticalGap = $derived.by(() => {
		if (store.state.connectionMode !== 'all') return `${BASE_GAP_REM}rem`;

		const density = store.connectionDensityBySemester.get(semester) ?? 0;
		const gap = Math.min(MAX_GAP_REM, Math.max(MIN_GAP_REM, MIN_GAP_REM + density * GAP_PER_CONNECTION));
		return `${gap}rem`;
	});

	// Badge: horas/créditos do semestre (exigido e realizado)
	const stats = $derived.by(() => {
		const totalCredits = subjects.reduce((s, m) => s + (m.creditos ?? 0), 0);
		const totalHours = Math.round(totalCredits * 15);
		const completed = store.completedCodes;
		const completedCredits = subjects.reduce(
			(s, m) => (completed.has(m.codigoMateria?.trim().toUpperCase() ?? '') ? s + (m.creditos ?? 0) : s),
			0
		);
		const completedHours = Math.round(completedCredits * 15);
		return {
			totalCredits: Math.round(totalCredits * 10) / 10,
			totalHours,
			completedCredits: Math.round(completedCredits * 10) / 10,
			completedHours
		};
	});

	const displayUnit = $derived(store.state.displayUnit);
	const badgeLabel = $derived.by(() => {
		if (displayUnit === 'creditos') {
			const ex = stats.totalCredits;
			const re = stats.completedCredits;
			if (store.state.isAnonymous || !store.userFluxograma) return `${ex}cr`;
			return `${re} / ${ex}cr`;
		}
		const ex = stats.totalHours;
		const re = stats.completedHours;
		if (store.state.isAnonymous || !store.userFluxograma) return `${ex}h`;
		return `${re} / ${ex}h`;
	});
</script>

<div class="semester-column flex min-w-[130px] flex-col gap-2 sm:min-w-[160px]">
	<div
		class="z-10 rounded-lg border border-white/10 bg-black/60 px-3 py-2 text-center backdrop-blur-md"
		style="transform: translateY({headerOffsetY}px); position: relative;"
	>
		<span class="text-xs font-bold uppercase tracking-wider text-white/70">
			{semester === 0 ? 'Optativas' : `Semestre ${semester}`}
		</span>
	</div>

	<!-- Badge: horas/créditos no topo (menos transparência para fácil leitura) -->
	{#if subjects.length > 0}
		<div
			class="flex justify-center rounded-lg border border-cyan-400/50 bg-cyan-600/45 px-2 py-1.5 text-center shadow-sm"
			title={displayUnit === 'creditos'
				? `${stats.completedCredits} de ${stats.totalCredits} créditos do semestre`
				: `${stats.completedHours} de ${stats.totalHours}h do semestre`}
		>
			<span class="text-xs font-semibold text-cyan-100">{badgeLabel}</span>
		</div>
	{/if}

	<div class="flex flex-col" style="gap: {verticalGap}; transition: gap 0.3s ease;">
		{#each subjects as materia (materia.idMateria)}
			<SubjectCard
				{materia}
				onclick={() => onSubjectClick?.(materia)}
				onlongpress={() => onSubjectLongPress?.(materia)}
			/>
		{/each}
	</div>
</div>
