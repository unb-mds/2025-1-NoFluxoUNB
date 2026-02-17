<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import type { CursoModel } from '$lib/types/curso';
	import type { EquivalenciaModel } from '$lib/types/equivalencia';
	import { getDirectPrerequisites, getCorequisites } from '$lib/types/curso';
	import { getStatusLabel, type SubjectStatusValue, SubjectStatusEnum } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, BookOpen, GitBranch, Repeat2 } from 'lucide-svelte';

	interface Props {
		materia: MateriaModel;
		courseData: CursoModel;
		onclose?: () => void;
	}

	let { materia, courseData, onclose }: Props = $props();

	const store = fluxogramaStore;
	let activeTab = $state<'info' | 'prereqs' | 'equivalencias'>('info');

	let status = $derived(store.getSubjectStatus(materia));
	let userData = $derived(store.getSubjectUserData(materia.codigoMateria));
	let prereqs = $derived(getDirectPrerequisites(courseData, materia.codigoMateria));
	let coreqs = $derived(getCorequisites(courseData, materia.codigoMateria));

	let equivalencias = $derived.by(() => {
		return courseData.equivalencias.filter(
			(eq) => eq.codigoMateriaOrigem === materia.codigoMateria
		);
	});

	const statusGradientMap: Record<SubjectStatusValue, string> = {
		[SubjectStatusEnum.COMPLETED]: 'from-green-500/20 to-green-700/10',
		[SubjectStatusEnum.IN_PROGRESS]: 'from-purple-500/20 to-purple-700/10',
		[SubjectStatusEnum.AVAILABLE]: 'from-amber-500/20 to-amber-700/10',
		[SubjectStatusEnum.FAILED]: 'from-red-500/20 to-red-700/10',
		[SubjectStatusEnum.LOCKED]: 'from-gray-500/20 to-gray-700/10',
		[SubjectStatusEnum.NOT_STARTED]: 'from-gray-500/20 to-gray-700/10'
	};

	const statusDotColor: Record<SubjectStatusValue, string> = {
		[SubjectStatusEnum.COMPLETED]: 'bg-green-500',
		[SubjectStatusEnum.IN_PROGRESS]: 'bg-purple-500',
		[SubjectStatusEnum.AVAILABLE]: 'bg-amber-500',
		[SubjectStatusEnum.FAILED]: 'bg-red-500',
		[SubjectStatusEnum.LOCKED]: 'bg-gray-500',
		[SubjectStatusEnum.NOT_STARTED]: 'bg-gray-500'
	};

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose?.();
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) onclose?.();
	}

	const tabs = [
		{ id: 'info' as const, label: 'Info', icon: BookOpen },
		{ id: 'prereqs' as const, label: 'Pré-requisitos', icon: GitBranch },
		{ id: 'equivalencias' as const, label: 'Equivalências', icon: Repeat2 }
	];
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
	onclick={handleBackdropClick}
>
	<div
		class="relative max-h-[85vh] w-full max-w-lg overflow-hidden rounded-2xl border border-white/10 bg-gray-900/95 shadow-2xl backdrop-blur-xl"
		role="dialog"
		aria-modal="true"
		aria-label="Detalhes da matéria"
	>
		<!-- Header -->
		<div class="bg-gradient-to-r {statusGradientMap[status]} border-b border-white/10 px-6 py-4">
			<div class="flex items-start justify-between gap-3">
				<div class="flex-1">
					<div class="mb-1 flex items-center gap-2">
						<span class="text-xs font-semibold uppercase tracking-wider text-white/60">
							{materia.codigoMateria}
						</span>
						<div class="flex items-center gap-1.5">
							<div class="h-2 w-2 rounded-full {statusDotColor[status]}"></div>
							<span class="text-xs text-white/60">{getStatusLabel(status)}</span>
						</div>
					</div>
					<h2 class="text-lg font-bold text-white">{materia.nomeMateria}</h2>
					<p class="mt-1 text-sm text-white/50">{materia.creditos} créditos</p>
				</div>
				<button
					onclick={onclose}
					class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/10 text-white/70 transition-colors hover:bg-white/20 hover:text-white"
					aria-label="Fechar"
				>
					<X class="h-4 w-4" />
				</button>
			</div>

			{#if userData}
				<div class="mt-3 flex flex-wrap gap-2">
					{#if userData.mencao && userData.mencao !== '-'}
						<span class="rounded-full bg-white/10 px-2.5 py-0.5 text-xs font-medium text-white/80">
							Menção: {userData.mencao}
						</span>
					{/if}
					{#if userData.professor}
						<span class="rounded-full bg-white/10 px-2.5 py-0.5 text-xs font-medium text-white/80">
							Prof: {userData.professor}
						</span>
					{/if}
				</div>
			{/if}
		</div>

		<!-- Tabs -->
		<div class="flex border-b border-white/10">
			{#each tabs as tab}
				<button
					onclick={() => (activeTab = tab.id)}
					class="flex flex-1 items-center justify-center gap-1.5 px-3 py-2.5 text-xs font-medium transition-colors {activeTab === tab.id ? 'border-b-2 border-purple-400 text-purple-300' : 'text-white/50 hover:text-white/80'}"
				>
					<tab.icon class="h-3.5 w-3.5" />
					{tab.label}
				</button>
			{/each}
		</div>

		<!-- Tab content -->
		<div class="max-h-[50vh] overflow-y-auto px-6 py-4">
			{#if activeTab === 'info'}
				<div class="space-y-4">
					{#if materia.ementa}
						<div>
							<h3 class="mb-1.5 text-xs font-semibold uppercase tracking-wider text-white/50">
								Ementa
							</h3>
							<p class="text-sm leading-relaxed text-white/80">{materia.ementa}</p>
						</div>
					{/if}

					<div class="grid grid-cols-2 gap-3">
						<div class="rounded-lg bg-white/5 p-3">
							<span class="text-xs text-white/50">Semestre</span>
							<p class="text-sm font-semibold text-white">
								{materia.nivel === 0 ? 'Optativa' : `${materia.nivel}º`}
							</p>
						</div>
						<div class="rounded-lg bg-white/5 p-3">
							<span class="text-xs text-white/50">Créditos</span>
							<p class="text-sm font-semibold text-white">{materia.creditos}</p>
						</div>
					</div>

					{#if coreqs.length > 0}
						<div>
							<h3 class="mb-1.5 text-xs font-semibold uppercase tracking-wider text-white/50">
								Co-requisitos
							</h3>
							<div class="space-y-1">
								{#each coreqs as coreq}
									<div class="rounded-lg bg-white/5 px-3 py-2 text-sm text-white/80">
										<span class="text-white/50">{coreq.codigoMateria}</span> — {coreq.nomeMateria}
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{:else if activeTab === 'prereqs'}
				<div class="space-y-2">
					{#if prereqs.length === 0}
						<p class="py-4 text-center text-sm text-white/50">
							Esta matéria não possui pré-requisitos.
						</p>
					{:else}
						{#each prereqs as prereq}
							{@const prereqStatus = store.getSubjectStatus(prereq)}
							<div class="flex items-center gap-3 rounded-lg bg-white/5 px-3 py-2.5">
								<div class="h-2.5 w-2.5 shrink-0 rounded-full {statusDotColor[prereqStatus]}"></div>
								<div class="flex-1">
									<p class="text-sm font-medium text-white/90">{prereq.nomeMateria}</p>
									<p class="text-xs text-white/50">
										{prereq.codigoMateria} · {prereq.creditos} créditos · {getStatusLabel(prereqStatus)}
									</p>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			{:else if activeTab === 'equivalencias'}
				<div class="space-y-2">
					{#if equivalencias.length === 0}
						<p class="py-4 text-center text-sm text-white/50">
							Nenhuma equivalência registrada.
						</p>
					{:else}
						{#each equivalencias as eq}
							<div class="rounded-lg bg-white/5 px-3 py-2.5">
								<p class="text-sm font-medium text-white/90">{eq.nomeMateriaEquivalente}</p>
								<p class="text-xs text-white/50">{eq.codigoMateriaEquivalente}</p>
								{#if eq.expressao}
									<p class="mt-1 text-xs text-purple-300/70">Expressão: {eq.expressao}</p>
								{/if}
							</div>
						{/each}
					{/if}
				</div>
			{/if}
		</div>

			<!-- Add to semester footer -->
			{#if !store.state.isAnonymous && (status === SubjectStatusEnum.AVAILABLE || status === SubjectStatusEnum.NOT_STARTED || status === SubjectStatusEnum.LOCKED)}
				<div class="border-t border-white/10 px-6 py-3">
					<button
						onclick={() => {
							const nextSem = materia.nivel > 0 ? materia.nivel : 1;
							store.addOptativa(materia, nextSem);
							onclose?.();
						}}
						class="w-full rounded-lg bg-gradient-to-r from-purple-600 to-purple-700 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:from-purple-500 hover:to-purple-600"
					>
						Adicionar ao {materia.nivel > 0 ? `${materia.nivel}º` : 'próximo'} semestre
					</button>
				</div>
			{/if}
	</div>
</div>
