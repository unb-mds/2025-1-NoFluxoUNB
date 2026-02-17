<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import SubjectCard from './SubjectCard.svelte';

	interface Props {
		semester: number;
		subjects: MateriaModel[];
		onSubjectClick?: (materia: MateriaModel) => void;
		onSubjectLongPress?: (materia: MateriaModel) => void;
	}

	let { semester, subjects, onSubjectClick, onSubjectLongPress }: Props = $props();
</script>

<div class="semester-column flex min-w-[160px] flex-col gap-2">
	<div class="sticky top-0 z-10 rounded-lg border border-white/10 bg-black/60 px-3 py-2 text-center backdrop-blur-md">
		<span class="text-xs font-bold uppercase tracking-wider text-white/70">
			{semester === 0 ? 'Optativas' : `Semestre ${semester}`}
		</span>
	</div>

	<div class="flex flex-col gap-2">
		{#each subjects as materia (materia.idMateria)}
			<SubjectCard
				{materia}
				onclick={() => onSubjectClick?.(materia)}
				onlongpress={() => onSubjectLongPress?.(materia)}
			/>
		{/each}
	</div>
</div>
