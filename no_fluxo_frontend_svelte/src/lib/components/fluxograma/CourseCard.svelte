<script lang="ts">
	import type { MinimalCursoModel } from '$lib/types/curso';
	import { GraduationCap, BookOpen } from 'lucide-svelte';

	interface Props {
		curso: MinimalCursoModel;
		onclick?: () => void;
	}

	let { curso, onclick }: Props = $props();
</script>

<button
	class="course-card group relative w-full overflow-hidden rounded-2xl border border-white/10 bg-black/40 p-5 text-left backdrop-blur-md transition-all duration-300 hover:scale-[1.03] hover:border-white/20 hover:bg-black/50 hover:shadow-xl hover:shadow-purple-500/10"
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

	{#if curso.matrizCurricular}
		<p class="mb-2 flex items-center gap-1 text-xs text-white/50">
			<BookOpen class="h-3 w-3" />
			{curso.matrizCurricular}
		</p>
	{/if}

	{#if curso.tipoCurso}
		<span
			class="mt-2 inline-block rounded-full bg-gradient-to-r from-blue-500/20 to-purple-500/20 px-2.5 py-0.5 text-xs font-medium text-blue-300"
		>
			{curso.tipoCurso}
		</span>
	{/if}
</button>
