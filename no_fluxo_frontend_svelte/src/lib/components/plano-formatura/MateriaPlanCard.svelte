<script lang="ts">
	import type { MateriaPlano } from '$lib/types/plano-formatura';
	import { Flame, ArrowUpRight } from 'lucide-svelte';

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
		<span class="font-mono text-[11px] font-bold tracking-wide text-white/85">
			{materia.codigo}
		</span>
		<span class="rounded-full bg-white/8 px-2 py-0.5 text-[10px] font-semibold text-white/70">
			{materia.creditos} cr
		</span>
	</div>

	<!-- Body: nome da matéria -->
	<p class="text-[13px] font-medium leading-snug text-white/85">
		{materia.nome}
	</p>

	<!-- Footer: badges + motivo -->
	<div class="flex flex-wrap items-center justify-between gap-2">
		<p class="text-[11px] leading-snug text-white/35 line-clamp-2 flex-1">
			{materia.motivo}
		</p>

		<div class="flex items-center gap-1.5">
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
