<script lang="ts">
	import { X, Search, Loader2 } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
	import { supabaseDataService } from '$lib/services/supabase-data.service';
	import type { MinimalCursoModel } from '$lib/types/curso';

	interface Props {
		open: boolean;
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const store = fluxogramaStore;

	let searchQuery = $state('');
	let cursos = $state<MinimalCursoModel[]>([]);
	let loadingCursos = $state(false);
	let navigating = $state(false);

	const cursosFiltrados = $derived(
		searchQuery.trim()
			? cursos.filter((c) =>
					c.nomeCurso.toLowerCase().includes(searchQuery.toLowerCase().trim())
				)
			: cursos
	);

	$effect(() => {
		if (open) {
			loadCursos();
			const prev = document.body.style.overflow;
			document.body.style.overflow = 'hidden';
			return () => {
				document.body.style.overflow = prev;
				searchQuery = '';
			};
		}
	});

	async function loadCursos() {
		loadingCursos = true;
		try {
			cursos = await fluxogramaService.getAllCursos();
		} catch (e) {
			console.error('Erro ao carregar cursos:', e);
			cursos = [];
		} finally {
			loadingCursos = false;
		}
	}

	async function handleSelectCurso(curso: MinimalCursoModel) {
		if (!store.userFluxograma) return;

		navigating = true;
		onclose();

		try {
			let curriculoCompleto = curso.matrizCurricular?.trim();
			if (!curriculoCompleto) {
				const matrizes = await supabaseDataService.getMatrizesByCurso(curso.idCurso);
				curriculoCompleto = matrizes[0]?.curriculoCompleto ?? '';
			}

			// Navega para a tela do fluxograma do curso selecionado.
			// A página carrega o curso e calcula integralização usando os dados do usuário (casar matérias).
			const url = curriculoCompleto
				? `${ROUTES.meuFluxograma(curso.nomeCurso)}?matriz=${encodeURIComponent(curriculoCompleto)}`
				: ROUTES.meuFluxograma(curso.nomeCurso);
			await goto(url);
		} catch (e) {
			console.error('Erro ao navegar:', e);
		} finally {
			navigating = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onclose();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="mudanca-modal-overlay"
		onclick={(e) => e.target === e.currentTarget && onclose()}
	>
		<div class="mudanca-modal-box" role="dialog" aria-modal="true" aria-label="Mudança de curso">
			<div class="mudanca-modal-header">
				<h2 class="text-base font-bold text-white sm:text-lg">Mudança de Curso</h2>
				<button
					type="button"
					onclick={onclose}
					class="rounded-lg p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
					aria-label="Fechar"
				>
					<X class="h-5 w-5" />
				</button>
			</div>

			<div class="mudanca-modal-body">
				<p class="mb-4 text-xs text-white/50">
					Selecione um curso para ver seu progresso como se estivesse nele. Suas matérias concluídas serão casadas com o currículo do curso.
				</p>

				<div class="relative mb-4">
					<Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
					<input
						type="search"
						placeholder="Pesquisar curso..."
						bind:value={searchQuery}
						class="w-full rounded-lg border border-white/10 bg-white/5 py-2.5 pl-10 pr-4 text-sm text-white placeholder-white/40 focus:border-amber-500/50 focus:outline-none"
					/>
				</div>

				{#if loadingCursos}
					<div class="flex flex-col items-center justify-center gap-3 py-12">
						<Loader2 class="h-8 w-8 animate-spin text-amber-400" />
						<p class="text-sm text-white/60">Carregando cursos...</p>
					</div>
				{:else}
					<div class="max-h-[50vh] space-y-1 overflow-y-auto overscroll-behavior-contain">
						{#each cursosFiltrados as curso}
							<button
								type="button"
								onclick={() => handleSelectCurso(curso)}
								disabled={navigating}
								class="flex w-full items-center justify-between rounded-lg border border-white/10 bg-white/5 px-4 py-3 text-left transition-colors hover:bg-white/10 hover:border-amber-500/30 disabled:opacity-50"
							>
								<span class="font-medium text-white/90">{curso.nomeCurso}</span>
								<span class="text-xs text-amber-400">Ver fluxograma →</span>
							</button>
						{/each}
						{#if cursosFiltrados.length === 0}
							<p class="py-8 text-center text-sm text-white/50">
								{searchQuery.trim() ? 'Nenhum curso encontrado.' : 'Nenhum curso disponível.'}
							</p>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.mudanca-modal-overlay {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
		padding: 1rem;
	}
	.mudanca-modal-box {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		max-height: 90vh;
		width: 100%;
		max-width: 28rem;
		overflow: hidden;
		border-radius: 1rem;
		border: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(24px);
	}
	.mudanca-modal-header {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		padding: 0.75rem 1rem;
	}
	.mudanca-modal-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
		padding: 1rem;
	}
</style>
