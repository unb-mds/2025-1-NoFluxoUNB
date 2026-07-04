<script lang="ts">
	import type { MateriaPlano } from '$lib/types/plano-formatura';
	import { Flame, ArrowUpRight, BrainCircuit } from 'lucide-svelte';
	import * as Tooltip from '$lib/components/ui/tooltip';

	interface Props {
		materia: MateriaPlano;
		/** Tipo do semestre pai — para estilo de destaque do próximo semestre. */
		tipoSemestre?: 'recomendado' | 'estimado';
		/** Código da matéria sendo hovereada para destacar setas de pré-requisito. */
		hoveredCode?: string | null;
	}

	let { materia, tipoSemestre = 'estimado', hoveredCode = $bindable() }: Props = $props();

	const isRecomendado = $derived(tipoSemestre === 'recomendado');

	/** Border left color — azul para recomendado, cinza para estimado. */
	const borderClass = $derived(
		isRecomendado ? 'border-l-[#185FA5]' : 'border-l-slate-600'
	);

	function handleMouseEnter() {
		hoveredCode = materia.codigo;
	}

	function handleMouseLeave() {
		hoveredCode = null;
	}
</script>

<div
	role="group"
	data-subject-code={materia.codigo}
	class="group relative flex flex-col gap-2.5 rounded-lg border border-l-4 bg-[#161625] px-3.5 py-3 transition-all duration-150 hover:brightness-110 {borderClass}"
	onmouseenter={handleMouseEnter}
	onmouseleave={handleMouseLeave}
>
	<!-- Header: código + créditos -->
	<div class="flex items-center justify-between gap-2">
		<span class="font-mono text-[12px] font-black tracking-widest text-white">
			{materia.codigo}
		</span>
		<span class="rounded-full bg-white/10 px-2.5 py-0.5 text-[10px] font-bold text-white">
			{materia.creditos} cr
		</span>
	</div>

	<!-- Body: nome da matéria -->
	<p class="text-[14px] font-bold leading-tight text-white line-clamp-3">
		{materia.nome}
	</p>

	<!-- Footer: badges + motivo -->
	<div class="flex flex-wrap items-center justify-between gap-2 mt-1">
		<p class="text-[11px] leading-snug text-white/50 line-clamp-2 flex-1 font-medium">
			{materia.motivo}
		</p>

		<div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
			{#if materia.dificuldadeEstimada != null}
				{@const diff = materia.dificuldadeEstimada}
				{@const diffLabel = diff >= 8 ? 'Alta' : diff >= 5 ? 'Média' : 'Baixa'}
				{@const diffColor = diff >= 8 ? 'bg-red-500/10 text-red-400 border-red-500/20' : diff >= 5 ? 'bg-amber-500/10 text-amber-400 border-amber-500/20' : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'}
				
				<Tooltip.Provider>
					<Tooltip.Root>
						<Tooltip.Trigger>
							<div class="flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-[10px] font-semibold tracking-wide border {diffColor}">
								<BrainCircuit class="h-2.5 w-2.5" />
								Dif: {diffLabel}
							</div>
						</Tooltip.Trigger>
						<Tooltip.Content class="max-w-[250px] bg-[#161625] border-slate-700 text-white p-3 shadow-xl z-50">
							<p class="text-[12px] font-bold mb-1">Dificuldade: {diffLabel} ({diff}/10)</p>
							<p class="text-[11px] text-slate-300 leading-snug">{materia.motivoDificuldade || "Avaliação automática."}</p>
						</Tooltip.Content>
					</Tooltip.Root>
				</Tooltip.Provider>
			{/if}

			{#if materia.critica}
				<span class="flex items-center gap-0.5 rounded-full bg-[#993C1D] px-1.5 py-0.5 text-[10px] font-semibold tracking-wide text-white">
					<Flame class="h-2.5 w-2.5" />
					Crítica
				</span>
			{/if}

			{#if materia.desbloqueia_direto > 0}
				<span class="flex items-center gap-0.5 rounded-full bg-teal-600/20 px-1.5 py-0.5 text-[10px] font-semibold tracking-wide text-teal-300">
					<ArrowUpRight class="h-2.5 w-2.5" />
					{materia.desbloqueia_direto} mat.
				</span>
			{/if}
		</div>
	</div>
</div>
