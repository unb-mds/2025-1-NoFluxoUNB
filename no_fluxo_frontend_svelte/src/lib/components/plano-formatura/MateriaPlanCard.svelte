<script lang="ts">
	import type { MateriaPlano } from '$lib/types/plano-formatura';
	import { Flame, Link2 } from 'lucide-svelte';

	interface Props {
		materia: MateriaPlano;
		/** Tipo do semestre pai — para estilo de destaque do próximo semestre. */
		tipoSemestre?: 'recomendado' | 'estimado';
	}

	let { materia, tipoSemestre = 'estimado' }: Props = $props();

	const isRecomendado = $derived(tipoSemestre === 'recomendado');

	/**
	 * Card color coding:
	 * - crítica  → orange tones
	 * - recomendado (semestre seguinte, não crítica) → blue tones
	 * - estimado → slate tones
	 */
	const cardClass = $derived(
		materia.critica
			? 'bg-orange-950/30 border-orange-800/50 border-l-orange-400'
			: isRecomendado
				? 'bg-blue-950/30 border-blue-800/40 border-l-blue-400'
				: 'bg-slate-900/60 border-slate-700/40 border-l-slate-600'
	);

	const badgeClass = $derived(
		materia.critica
			? 'bg-orange-500/15 text-orange-300 ring-orange-500/25'
			: isRecomendado
				? 'bg-blue-500/15 text-blue-300 ring-blue-500/25'
				: 'bg-slate-700/40 text-slate-400 ring-slate-600/30'
	);

	const codeClass = $derived(
		materia.critica
			? 'text-orange-300'
			: isRecomendado
				? 'text-blue-300'
				: 'text-slate-400'
	);

	const totalDesbloqueia = $derived(
		materia.desbloqueia_direto + materia.desbloqueia_indireto
	);
</script>

<div
	data-planner-code={materia.codigo}
	class="group relative flex flex-col gap-2 rounded-lg border border-l-2 px-3.5 py-3 transition-all duration-150 hover:brightness-110 {cardClass}"
>
	<!-- Top row: code + credits badge -->
	<div class="flex items-center justify-between gap-2">
		<span class="font-mono text-[11px] font-bold tracking-wide {codeClass}">
			{materia.codigo}
		</span>
		<div class="flex items-center gap-1.5">
			{#if materia.critica}
				<span class="flex items-center gap-0.5 rounded-full bg-orange-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-orange-300 ring-1 ring-orange-500/25">
					<Flame class="h-2.5 w-2.5" />
					crítica
				</span>
			{/if}
			<span class="rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1 {badgeClass}">
				{materia.creditos} cr
			</span>
		</div>
	</div>

	<!-- Subject name -->
	<p class="text-[13px] font-medium leading-snug text-white/85">
		{materia.nome}
	</p>

	<!-- Bottom row: motivo + desbloqueia -->
	<div class="flex items-end justify-between gap-2">
		{#if materia.motivo}
			<p class="text-[11px] leading-snug text-white/35 line-clamp-2">
				{materia.motivo}
			</p>
		{/if}

		{#if totalDesbloqueia > 0}
			<div class="ml-auto flex shrink-0 items-center gap-1 text-[11px] text-white/35">
				<Link2 class="h-3 w-3" />
				<span>+{totalDesbloqueia}</span>
			</div>
		{/if}
	</div>
</div>
