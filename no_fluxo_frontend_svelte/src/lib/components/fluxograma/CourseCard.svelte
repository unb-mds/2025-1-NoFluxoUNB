<script lang="ts">
	import type { MinimalCursoModel } from '$lib/types/curso';
	import { GraduationCap, BookOpen } from 'lucide-svelte';

	interface Props {
		curso: MinimalCursoModel;
		onclick?: () => void;
	}

	let { curso, onclick }: Props = $props();

	function formatTurno(turno: string | null | undefined): string {
		if (!turno) return '';
		const t = turno.toUpperCase();
		if (t === 'NOTURNO') return 'Noturno';
		if (t === 'DIURNO') return 'Diurno';
		return turno;
	}
</script>

<button
	class="course-card group relative w-full min-w-0 overflow-hidden rounded-xl border border-white/10 bg-black/40 p-4 text-left backdrop-blur-md transition-all duration-300 hover:scale-[1.02] hover:border-white/20 hover:bg-black/50 hover:shadow-xl hover:shadow-purple-500/10 sm:rounded-2xl sm:p-5 sm:hover:scale-[1.03]"
	{onclick}
>
	<!-- Gradient accent top bar -->
	<div
		class="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-purple-500 via-pink-500 to-orange-500 opacity-60 transition-opacity group-hover:opacity-100"
	></div>

	<div class="mb-3 flex items-start justify-between gap-2">
		<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-purple-500/20">
			<GraduationCap class="h-5 w-5 text-purple-400" />
		</div>
		{#if curso.creditos}
			<span class="rounded-full bg-white/10 px-2.5 py-0.5 text-xs font-medium text-white/70">
				{curso.creditos} créditos
			</span>
		{/if}
	</div>

	<h3 class="mb-1 line-clamp-2 text-sm font-semibold leading-tight text-white">
		{curso.nomeCurso}
	</h3>

	<!-- Tipo do curso e turno em destaque (quando existir) -->
	{#if curso.tipoCurso || curso.turno}
		<p class="mb-2 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-white/80">
			{#if curso.tipoCurso}
				<span class="font-medium text-cyan-300">{curso.tipoCurso}</span>
			{/if}
			{#if curso.tipoCurso && curso.turno}
				<span class="text-white/40">·</span>
			{/if}
			{#if curso.turno}
				<span class="font-medium text-amber-300/90">{formatTurno(curso.turno)}</span>
			{/if}
		</p>
	{/if}

	{#if curso.matrizCurricular}
		<p class="mb-2 flex items-center gap-1 text-xs text-white/50">
			<BookOpen class="h-3 w-3 shrink-0" />
			<span class="line-clamp-1">{curso.matrizCurricular}</span>
		</p>
	{/if}
</button>
