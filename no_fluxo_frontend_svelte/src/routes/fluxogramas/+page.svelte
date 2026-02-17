<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import CourseCard from '$lib/components/fluxograma/CourseCard.svelte';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
	import { ROUTES } from '$lib/config/routes';
	import { goto } from '$app/navigation';
	import type { MinimalCursoModel } from '$lib/types/curso';
	import { Search, Filter, ChevronLeft, ChevronRight, Loader2, AlertTriangle, GraduationCap } from 'lucide-svelte';
	import { onMount } from 'svelte';

	let courses = $state<MinimalCursoModel[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	let searchQuery = $state('');
	let selectedType = $state('');
	let currentPage = $state(1);
	const perPage = 6;

	// Get unique course types for filter dropdown
	let courseTypes = $derived.by(() => {
		const types = new Set(courses.map((c) => c.tipoCurso).filter(Boolean));
		return Array.from(types).sort();
	});

	// Filtered courses
	let filtered = $derived.by(() => {
		let result = courses;
		if (searchQuery.trim()) {
			const q = searchQuery.toLowerCase();
			result = result.filter((c) => c.nomeCurso.toLowerCase().includes(q));
		}
		if (selectedType) {
			result = result.filter((c) => c.tipoCurso === selectedType);
		}
		return result;
	});

	// Pagination
	let totalPages = $derived(Math.max(1, Math.ceil(filtered.length / perPage)));
	let paginated = $derived(filtered.slice((currentPage - 1) * perPage, currentPage * perPage));

	// Reset page when filters change
	$effect(() => {
		// Access dependencies
		searchQuery;
		selectedType;
		currentPage = 1;
	});

	onMount(async () => {
		try {
			courses = await fluxogramaService.getAllCursos();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Erro ao carregar cursos';
		} finally {
			loading = false;
		}
	});

	function navigateToCourse(curso: MinimalCursoModel) {
		goto(ROUTES.meuFluxograma(curso.nomeCurso));
	}
</script>

<PageMeta
	title="Fluxogramas"
	description="Explore os fluxogramas de cursos disponíveis na UnB"
/>

<GraffitiBackground />

<div class="relative z-10 container mx-auto max-w-6xl px-4 py-8">
	<!-- Header -->
	<div class="mb-6">
		<h1 class="text-2xl font-bold text-white">Fluxogramas</h1>
		<p class="text-gray-300">Explore e selecione o fluxograma do seu curso.</p>
	</div>

	<!-- Search and Filter -->
	<div class="mb-6 flex flex-col gap-3 sm:flex-row">
		<div class="relative flex-1">
			<Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
			<input
				type="text"
				bind:value={searchQuery}
				placeholder="Buscar curso por nome..."
				class="w-full rounded-xl border border-white/10 bg-black/40 py-2.5 pl-10 pr-4 text-sm text-white placeholder-white/40 backdrop-blur-md outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30"
			/>
		</div>

		{#if courseTypes.length > 0}
			<div class="relative">
				<Filter class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
				<select
					bind:value={selectedType}
					class="appearance-none rounded-xl border border-white/10 bg-black/40 py-2.5 pl-10 pr-8 text-sm text-white backdrop-blur-md outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30"
				>
					<option value="">Todos os tipos</option>
					{#each courseTypes as type}
						<option value={type}>{type}</option>
					{/each}
				</select>
			</div>
		{/if}
	</div>

	<!-- Content -->
	{#if loading}
		<!-- Loading skeleton -->
		<div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
			{#each Array(6) as _}
				<div class="animate-pulse rounded-2xl border border-white/10 bg-black/40 p-5 backdrop-blur-md">
					<div class="mb-3 flex items-start justify-between">
						<div class="h-10 w-10 rounded-xl bg-white/10"></div>
						<div class="h-5 w-16 rounded-full bg-white/10"></div>
					</div>
					<div class="mb-2 h-4 w-3/4 rounded bg-white/10"></div>
					<div class="h-3 w-1/2 rounded bg-white/10"></div>
				</div>
			{/each}
		</div>
	{:else if error}
		<div class="rounded-2xl border border-red-500/20 bg-red-500/10 p-8 text-center backdrop-blur-md">
			<AlertTriangle class="mx-auto mb-3 h-8 w-8 text-red-400" />
			<h2 class="mb-2 text-lg font-semibold text-white">Erro ao carregar cursos</h2>
			<p class="text-sm text-red-300/80">{error}</p>
		</div>
	{:else if filtered.length === 0}
		<div class="rounded-2xl border border-white/10 bg-black/40 p-8 text-center backdrop-blur-md">
			<GraduationCap class="mx-auto mb-3 h-8 w-8 text-white/40" />
			<h2 class="mb-2 text-lg font-semibold text-white">Nenhum curso encontrado</h2>
			<p class="text-sm text-white/50">Tente alterar os filtros de busca.</p>
		</div>
	{:else}
		<!-- Course grid -->
		<div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
			{#each paginated as curso (curso.idCurso)}
				<CourseCard {curso} onclick={() => navigateToCourse(curso)} />
			{/each}
		</div>

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="mt-6 flex items-center justify-center gap-2">
				<button
					onclick={() => (currentPage = Math.max(1, currentPage - 1))}
					disabled={currentPage <= 1}
					class="flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-black/40 text-white/70 transition-colors hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed"
				>
					<ChevronLeft class="h-4 w-4" />
				</button>

				{#each Array(totalPages) as _, i}
					<button
						onclick={() => (currentPage = i + 1)}
						class="flex h-9 w-9 items-center justify-center rounded-lg border text-sm font-medium transition-colors {currentPage === i + 1 ? 'border-purple-500/50 bg-purple-500/20 text-purple-300' : 'border-white/10 bg-black/40 text-white/50 hover:bg-white/10 hover:text-white'}"
					>
						{i + 1}
					</button>
				{/each}

				<button
					onclick={() => (currentPage = Math.min(totalPages, currentPage + 1))}
					disabled={currentPage >= totalPages}
					class="flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-black/40 text-white/70 transition-colors hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed"
				>
					<ChevronRight class="h-4 w-4" />
				</button>
			</div>
		{/if}

		<p class="mt-3 text-center text-xs text-white/40">
			Mostrando {(currentPage - 1) * perPage + 1}–{Math.min(currentPage * perPage, filtered.length)} de {filtered.length} curso{filtered.length !== 1 ? 's' : ''}
		</p>
	{/if}
</div>
