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
	let selectedTurno = $state('');
	let currentPage = $state(1);
	const perPage = 6;

	// Tipos de curso para o filtro (valores únicos)
	let courseTypes = $derived.by(() => {
		const types = new Set(courses.map((c) => c.tipoCurso).filter(Boolean));
		return Array.from(types).sort();
	});

	const turnoOptions = [
		{ value: '', label: 'Todos os turnos' },
		{ value: 'DIURNO', label: 'Diurno' },
		{ value: 'NOTURNO', label: 'Noturno' }
	];

	// Filtered courses: busca por nome (sempre); opcional por tipo e turno
	let filtered = $derived.by(() => {
		let result = courses;
		// Busca por texto: nome do curso; se tiver tipo/turno, também busca neles
		if (searchQuery.trim()) {
			const q = searchQuery.toLowerCase().trim();
			result = result.filter((c) => {
				const nome = (c.nomeCurso ?? '').toLowerCase();
				if (nome.includes(q)) return true;
				const tipo = (c.tipoCurso ?? '').toString().toLowerCase();
				if (tipo && tipo.includes(q)) return true;
				const turno = (c.turno ?? '').toString().toLowerCase();
				if (turno && turno.includes(q)) return true;
				return false;
			});
		}
		if (selectedType) {
			result = result.filter((c) => (c.tipoCurso ?? '') === selectedType);
		}
		if (selectedTurno) {
			result = result.filter((c) => (c.turno ?? '').toString().toUpperCase() === selectedTurno);
		}
		return result;
	});

	// Pagination
	let totalPages = $derived(Math.max(1, Math.ceil(filtered.length / perPage)));
	let paginated = $derived(filtered.slice((currentPage - 1) * perPage, currentPage * perPage));

	function onSearchOrFilterChange() {
		currentPage = 1;
	}

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
		const url = ROUTES.meuFluxograma(curso.nomeCurso);
		const params = curso.matrizCurricular
			? `?matriz=${encodeURIComponent(curso.matrizCurricular)}`
			: '';
		goto(url + params);
	}

	// Generate page numbers with ellipsis
	// Returns array of page numbers or 'ellipsis' strings
	let paginationItems = $derived.by(() => {
		const total = totalPages;
		const current = currentPage;
		const items: (number | 'ellipsis')[] = [];

		if (total <= 7) {
			// Show all pages if 7 or fewer
			for (let i = 1; i <= total; i++) items.push(i);
			return items;
		}

		// Always show first page
		items.push(1);

		if (current <= 3) {
			// Near start: 1 2 3 4 ... N-1 N
			items.push(2, 3, 4);
			items.push('ellipsis');
			items.push(total - 1, total);
		} else if (current >= total - 2) {
			// Near end: 1 2 ... N-3 N-2 N-1 N
			items.push(2);
			items.push('ellipsis');
			items.push(total - 3, total - 2, total - 1, total);
		} else {
			// Middle: 1 ... N-1 N N+1 ... X
			items.push('ellipsis');
			items.push(current - 1, current, current + 1);
			items.push('ellipsis');
			items.push(total);
		}

		return items;
	});
</script>

<PageMeta
	title="Fluxogramas"
	description="Explore os fluxogramas de cursos disponíveis na UnB"
/>

<GraffitiBackground />

<div class="relative z-10 container mx-auto min-w-0 max-w-6xl overflow-x-hidden px-3 py-6 sm:px-4 sm:py-8">
	<!-- Header -->
	<div class="mb-4 sm:mb-6">
		<h1 class="text-xl font-bold text-white sm:text-2xl">Fluxogramas</h1>
		<p class="text-sm text-gray-300 sm:text-base">Explore e selecione o fluxograma do seu curso.</p>
	</div>

	<!-- Search and Filter -->
	<div class="mb-6 flex flex-col gap-3 sm:flex-row">
		<div class="relative flex-1">
			<Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
			<input
				type="text"
				bind:value={searchQuery}
				oninput={onSearchOrFilterChange}
				placeholder="Buscar por nome, tipo (ex.: Bacharelado) ou turno (Diurno/Noturno)..."
				class="w-full rounded-xl border border-white/10 bg-black/40 py-2.5 pl-10 pr-4 text-sm text-white placeholder-white/40 backdrop-blur-md outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30"
			/>
		</div>

		{#if courseTypes.length > 0 || turnoOptions.length > 1}
			<div class="flex flex-wrap gap-3">
				{#if courseTypes.length > 0}
					<div class="relative w-full sm:w-auto">
						<Filter class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
						<select
							bind:value={selectedType}
							onchange={onSearchOrFilterChange}
							class="w-full appearance-none rounded-xl border border-white/10 bg-black/40 py-2.5 pl-10 pr-8 text-sm text-white backdrop-blur-md outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30 sm:w-auto"
						>
							<option value="">Todos os tipos</option>
							{#each courseTypes as type}
								<option value={type}>{type}</option>
							{/each}
						</select>
					</div>
				{/if}
				<select
					bind:value={selectedTurno}
					onchange={onSearchOrFilterChange}
					class="w-full appearance-none rounded-xl border border-white/10 bg-black/40 py-2.5 pl-4 pr-8 text-sm text-white backdrop-blur-md outline-none focus:border-purple-500/50 focus:ring-1 focus:ring-purple-500/30 sm:w-auto"
				>
					{#each turnoOptions as opt}
						<option value={opt.value}>{opt.label}</option>
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
			{#each paginated as curso, i (curso.idCurso != null && !Number.isNaN(Number(curso.idCurso)) ? curso.idCurso : `curso-${i}-${curso.nomeCurso}`)}
				<CourseCard {curso} onclick={() => navigateToCourse(curso)} />
			{/each}
		</div>

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="mt-6 flex items-center justify-center gap-1 sm:gap-2">
				<button
					onclick={() => (currentPage = Math.max(1, currentPage - 1))}
					disabled={currentPage <= 1}
					class="flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-black/40 text-white/70 transition-colors hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:cursor-not-allowed"
				>
					<ChevronLeft class="h-4 w-4" />
				</button>

				{#each paginationItems as item, idx}
					{#if item === 'ellipsis'}
						<span class="flex h-9 w-6 items-center justify-center text-white/40">…</span>
					{:else}
						<button
							onclick={() => (currentPage = item)}
							class="flex h-9 w-9 items-center justify-center rounded-lg border text-sm font-medium transition-colors {currentPage === item ? 'border-purple-500/50 bg-purple-500/20 text-purple-300' : 'border-white/10 bg-black/40 text-white/50 hover:bg-white/10 hover:text-white'}"
						>
							{item}
						</button>
					{/if}
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
