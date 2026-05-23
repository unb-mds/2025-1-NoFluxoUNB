<script lang="ts">
	import type { MateriaSemestreAtual } from '$lib/types/plano-formatura';
	import { CalendarDays, BookOpen } from 'lucide-svelte';

	interface Props {
		materias: MateriaSemestreAtual[];
		semestreAtual: number;
	}

	let { materias, semestreAtual }: Props = $props();

	// Calcula total de créditos
	const totalCreditos = $derived(materias.reduce((sum, m) => sum + (m.creditos ?? 4), 0));
	const totalHoras = $derived(Math.ceil(totalCreditos * 15));
</script>

<div class="flex h-full w-72 shrink-0 flex-col overflow-hidden rounded-2xl border border-purple-500/30 bg-purple-600/10 shadow-[0_0_0_1px_hsl(270_80%_50%/0.2),0_4px_24px_hsl(270_80%_40%/0.1)]">
	<!-- Header -->
	<div class="bg-purple-600/15 border-b border-purple-500/20 px-4 py-3.5">
		<div class="flex items-center justify-between gap-2">
			<div class="flex items-center gap-2">
				<CalendarDays class="h-4 w-4 text-purple-400" />
				<span class="text-sm font-semibold text-white">
					Semestre Atual - {semestreAtual}
				</span>
			</div>
		</div>

		<!-- Stats row -->
		<div class="mt-2.5 flex items-center gap-3">
			<div class="flex items-center gap-1.5">
				<span class="rounded-full px-2.5 py-0.5 text-[11px] font-semibold bg-purple-600/20 text-purple-200 ring-1 ring-purple-500/30">
					{totalCreditos} créditos
				</span>
			</div>
			<div class="flex items-center gap-1 text-[11px] text-white/35">
				<BookOpen class="h-3 w-3" />
				<span>{materias.length} disciplinas</span>
			</div>
		</div>
	</div>

	<!-- Matérias list — scrollable -->
	<div class="flex flex-1 flex-col gap-2 overflow-y-auto p-3">
		{#if materias.length === 0}
			<div class="flex flex-1 items-center justify-center py-8">
				<p class="text-center text-xs text-white/25 leading-relaxed">
					Nenhuma matéria<br/>em curso
				</p>
			</div>
		{:else}
			{#each materias as materia, idx (materia.codigo)}
				<div
					data-subject-code={materia.codigo}
					class="group flex flex-col gap-1.5 rounded-lg bg-[#161625] border border-l-4 border-l-purple-500 border-slate-600 p-2.5 transition-all hover:border-slate-500"
				>
					<div class="flex items-start justify-between gap-2">
						<span class="text-xs font-bold text-purple-300 uppercase tracking-wider">{materia.codigo}</span>
						<span class="text-xs font-semibold text-white/60">{materia.creditos ?? 4} cr</span>
					</div>
					<p class="text-xs text-white/70 line-clamp-2">{materia.nome || materia.codigo}</p>
					<div class="flex items-center gap-1 pt-0.5">
						<span class="text-[10px] font-medium text-purple-300 bg-purple-600/30 px-2 py-0.5 rounded">
							Em Curso
						</span>
					</div>
				</div>
			{/each}
		{/if}
	</div>
</div>
