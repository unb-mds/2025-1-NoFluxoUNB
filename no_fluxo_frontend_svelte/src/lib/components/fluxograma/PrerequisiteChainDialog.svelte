<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import type { CursoModel } from '$lib/types/curso';
	import { SubjectStatusEnum, getStatusLabel } from '$lib/types/materia';
	import { getDirectPrerequisites } from '$lib/types/curso';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, GitBranch, ChevronRight, Check, AlertTriangle, Lock } from 'lucide-svelte';

	interface Props {
		materia: MateriaModel;
		courseData: CursoModel;
		onclose?: () => void;
	}

	let { materia, courseData, onclose }: Props = $props();

	const store = fluxogramaStore;
	let status = $derived(store.getSubjectStatus(materia));

	// Can this subject be taken?
	let canTake = $derived(status === SubjectStatusEnum.AVAILABLE || status === SubjectStatusEnum.COMPLETED || status === SubjectStatusEnum.IN_PROGRESS);

	// Get prerequisite chain (recursive levels)
	function getPrereqLevels(code: string, visited = new Set<string>()): MateriaModel[][] {
		if (visited.has(code)) return [];
		visited.add(code);

		const directPrereqs = getDirectPrerequisites(courseData, code);
		if (directPrereqs.length === 0) return [];

		const levels: MateriaModel[][] = [directPrereqs];

		for (const prereq of directPrereqs) {
			const subLevels = getPrereqLevels(prereq.codigoMateria, visited);
			for (let i = 0; i < subLevels.length; i++) {
				if (levels.length <= i + 1) {
					levels.push([]);
				}
				// Add subjects that aren't already in this level
				for (const sub of subLevels[i]) {
					if (!levels[i + 1].some((m) => m.codigoMateria === sub.codigoMateria)) {
						levels[i + 1].push(sub);
					}
				}
			}
		}

		return levels;
	}

	// Get direct dependents (subjects that have this subject as a prerequisite)
	let dependents = $derived.by(() => {
		return courseData.materias.filter((m) =>
			m.preRequisitos?.some((p) => p.codigoMateria === materia.codigoMateria)
		);
	});

	let prereqLevels = $derived(getPrereqLevels(materia.codigoMateria));

	const statusIcons: Record<string, typeof Check> = {
		[SubjectStatusEnum.COMPLETED]: Check,
		[SubjectStatusEnum.IN_PROGRESS]: ChevronRight,
		[SubjectStatusEnum.AVAILABLE]: ChevronRight,
		[SubjectStatusEnum.FAILED]: AlertTriangle,
		[SubjectStatusEnum.LOCKED]: Lock,
		[SubjectStatusEnum.NOT_STARTED]: Lock
	};

	const statusColors: Record<string, string> = {
		[SubjectStatusEnum.COMPLETED]: 'text-green-400',
		[SubjectStatusEnum.IN_PROGRESS]: 'text-purple-400',
		[SubjectStatusEnum.AVAILABLE]: 'text-amber-400',
		[SubjectStatusEnum.FAILED]: 'text-red-400',
		[SubjectStatusEnum.LOCKED]: 'text-gray-400',
		[SubjectStatusEnum.NOT_STARTED]: 'text-gray-400'
	};

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose?.();
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) onclose?.();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-[60] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
	onclick={handleBackdropClick}
>
	<div
		class="relative max-h-[85vh] w-full max-w-md overflow-hidden rounded-2xl border border-white/10 bg-gray-900/95 shadow-2xl backdrop-blur-xl"
		role="dialog"
		aria-modal="true"
		aria-label="Cadeia de pré-requisitos"
	>
		<!-- Header -->
		<div class="border-b border-white/10 px-6 py-4">
			<div class="flex items-start justify-between gap-3">
				<div class="flex-1">
					<div class="mb-1 flex items-center gap-2">
						<GitBranch class="h-4 w-4 text-purple-400" />
						<span class="text-xs font-semibold uppercase tracking-wider text-white/60">
							Cadeia de Pré-requisitos
						</span>
					</div>
					<h2 class="text-lg font-bold text-white">{materia.nomeMateria}</h2>
					<p class="text-xs text-white/50">{materia.codigoMateria} · {materia.creditos} créditos</p>
				</div>
				<button
					onclick={onclose}
					class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/10 text-white/70 transition-colors hover:bg-white/20 hover:text-white"
					aria-label="Fechar"
				>
					<X class="h-4 w-4" />
				</button>
			</div>
		</div>

		<!-- Can-take status -->
		<div class="border-b border-white/10 px-6 py-3">
			<div class="flex items-center gap-2 rounded-lg px-3 py-2 {canTake ? 'bg-green-500/10' : 'bg-amber-500/10'}">
				{#if canTake}
					<Check class="h-4 w-4 text-green-400" />
					<span class="text-sm font-medium text-green-300">Pode cursar esta matéria</span>
				{:else}
					<AlertTriangle class="h-4 w-4 text-amber-400" />
					<span class="text-sm font-medium text-amber-300">Pré-requisitos pendentes</span>
				{/if}
			</div>
		</div>

		<!-- Content -->
		<div class="max-h-[50vh] overflow-y-auto px-6 py-4">
			<!-- Prerequisite levels -->
			{#if prereqLevels.length > 0}
				<div class="mb-4">
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/50">
						Pré-requisitos ({prereqLevels.reduce((sum, l) => sum + l.length, 0)})
					</h3>
					{#each prereqLevels as level, i}
						<div class="mb-2">
							<p class="mb-1 text-[10px] font-medium uppercase tracking-wider text-purple-300/60">
								Nível {i + 1}
							</p>
							<div class="space-y-1 pl-3 border-l-2 border-purple-500/20">
								{#each level as prereq}
									{@const prereqStatus = store.getSubjectStatus(prereq)}
									{@const StatusIcon = statusIcons[prereqStatus] ?? Lock}
									<div class="flex items-center gap-2 rounded-md bg-white/5 px-3 py-1.5">
										<StatusIcon class="h-3.5 w-3.5 shrink-0 {statusColors[prereqStatus]}" />
										<div class="flex-1 min-w-0">
											<p class="text-xs font-medium text-white/80 truncate">{prereq.nomeMateria}</p>
											<p class="text-[10px] text-white/40">{prereq.codigoMateria} · {getStatusLabel(prereqStatus)}</p>
										</div>
									</div>
								{/each}
							</div>
						</div>
					{/each}
				</div>
			{:else}
				<p class="mb-4 text-sm text-white/40">Nenhum pré-requisito.</p>
			{/if}

			<!-- Dependents -->
			<div>
				<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/50">
					Dependentes ({dependents.length})
				</h3>
				{#if dependents.length > 0}
					<div class="space-y-1 pl-3 border-l-2 border-teal-500/20">
						{#each dependents as dep}
							{@const depStatus = store.getSubjectStatus(dep)}
							{@const DepIcon = statusIcons[depStatus] ?? Lock}
							<div class="flex items-center gap-2 rounded-md bg-white/5 px-3 py-1.5">
								<DepIcon class="h-3.5 w-3.5 shrink-0 {statusColors[depStatus]}" />
								<div class="flex-1 min-w-0">
									<p class="text-xs font-medium text-white/80 truncate">{dep.nomeMateria}</p>
									<p class="text-[10px] text-white/40">{dep.codigoMateria} · Semestre {dep.nivel}</p>
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<p class="text-sm text-white/40">Nenhuma matéria depende desta.</p>
				{/if}
			</div>
		</div>
	</div>
</div>
