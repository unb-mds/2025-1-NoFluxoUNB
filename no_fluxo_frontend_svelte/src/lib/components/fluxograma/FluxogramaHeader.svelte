<script lang="ts">
	import { ArrowLeft, Camera, RefreshCw, Home, LayoutGrid } from 'lucide-svelte';
	import FluxogramViewMenu from './FluxogramViewMenu.svelte';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
	import { authStore } from '$lib/stores/auth';
	import { toast } from 'svelte-sonner';
	import { parseCurriculoCompleto } from '$lib/types/matriz';

	interface Props {
		courseName: string;
		matrizCurricular?: string;
		/** Ex.: Bacharelado, Licenciatura — vem da tabela cursos.tipo_curso */
		tipoCurso?: string | null;
		/** Lista de matrizes do mesmo curso para o seletor "Trocar matriz" */
		matrizes?: Array<{ curriculoCompleto: string }>;
		curriculoCompletoAtual?: string | null;
		onMatrizChange?: (curriculoCompleto: string) => void;
		containerRef?: HTMLElement | null;
		/** Mostra botão "Voltar ao meu fluxograma" quando está vendo outro curso (simulação) */
		showBackToMyFluxogram?: boolean;
		/** Menu ⚙ (Créditos/Horas + ajuda) — página do fluxograma */
		showFluxogramViewMenu?: boolean;
		onOpenFluxogramHelp?: () => void;
	}

	let {
		courseName,
		matrizCurricular = '',
		tipoCurso = null,
		matrizes = [],
		curriculoCompletoAtual = null,
		onMatrizChange,
		containerRef = null,
		showBackToMyFluxogram = false,
		showFluxogramViewMenu = false,
		onOpenFluxogramHelp
	}: Props = $props();

	const store = fluxogramaStore;
	let showConfirmDelete = $state(false);
	let isDeleting = $state(false);

	function formatMatrizLabel(cc: string) {
		const p = parseCurriculoCompleto(cc);
		return `${p.codigoCurso}/${p.versao}${p.ano ? ` - ${p.ano}` : ''}`;
	}

	function handleBack() {
		goto(ROUTES.FLUXOGRAMAS);
	}

	function handleScreenshot() {
		store.saveScreenshot(containerRef);
	}

	async function handleReupload() {
		const user = authStore.getUser();
		if (!user) return;

		isDeleting = true;
		try {
			await fluxogramaService.deleteFluxograma(user.idUser);
			toast.success('Fluxograma removido. Envie seu histórico novamente.');
			goto(ROUTES.UPLOAD_HISTORICO);
		} catch {
			toast.error('Erro ao remover fluxograma.');
		} finally {
			isDeleting = false;
			showConfirmDelete = false;
		}
	}

	function handleBackToMyFluxogram() {
		goto(ROUTES.MEU_FLUXOGRAMA);
	}
</script>

<!--
	Mobile: título em cima; ações em grade 2×2.
	Desktop (md+): uma única faixa — título à esquerda, matriz + reenviar + câmera alinhados à direita na mesma linha.
-->
<header class="min-w-0 overflow-visible pr-[max(0.25rem,env(safe-area-inset-right))]">
	<div
		class="flex w-full max-w-full min-w-0 flex-col gap-2 md:flex-row md:flex-wrap md:items-center md:justify-between md:gap-3"
	>
		<div class="flex min-w-0 flex-1 flex-col gap-0 md:min-w-0">
			<div class="flex min-w-0 items-center gap-1.5 sm:gap-2">
				<button
					onclick={handleBack}
					class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/70 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white sm:h-9 sm:w-9"
					aria-label="Voltar"
				>
					<ArrowLeft class="h-4 w-4 sm:h-[18px] sm:w-[18px]" />
				</button>
				<div class="min-w-0 flex-1 overflow-hidden">
					<h1 class="truncate text-sm font-bold leading-tight text-white sm:text-base md:text-lg lg:text-xl">{courseName}</h1>
					<div class="mt-0 flex flex-wrap items-center gap-1 sm:gap-1.5">
						{#if tipoCurso?.trim()}
							<span
								class="inline-flex shrink-0 items-center rounded-md bg-black/60 px-2 py-0.5 text-xs font-medium text-white/90 backdrop-blur-sm"
							>
								{tipoCurso.trim()}
							</span>
						{/if}
						{#if matrizCurricular}
							<p class="min-w-0 truncate text-xs text-white/50 sm:text-sm">{matrizCurricular}</p>
						{/if}
					</div>
				</div>
			</div>
		</div>

		<!--
			Mobile: coluna — matriz / voltar em largura total; Reenviar + câmera na mesma fileira (evita câmera “solta” na grade 2×2).
			md+: flex em linha (md:contents repassa filhos ao flex pai).
		-->
		<div
			class="flex w-full min-w-0 shrink-0 flex-col gap-2 md:flex-row md:flex-wrap md:items-center md:justify-end md:gap-2"
		>
			{#if matrizes.length > 1 && onMatrizChange}
				<div
					class="flex min-w-0 w-full max-w-full flex-row items-center gap-1 rounded-md border border-white/5 bg-black/20 px-1.5 py-1 md:w-auto md:gap-2 md:rounded-full md:px-3 md:py-1.5"
					title="Trocar matriz"
				>
					<LayoutGrid class="h-3 w-3 shrink-0 text-white/50 md:h-4 md:w-4" aria-hidden="true" />
					<select
						class="min-w-0 flex-1 rounded border-0 bg-white/5 py-0.5 pr-5 pl-1 text-[10px] leading-tight text-white/90 focus:bg-white/10 focus:ring-1 focus:ring-cyan-500/40 focus:outline-none md:max-w-[180px] md:flex-none md:py-1 md:pr-7 md:pl-2 md:text-xs [&>option]:bg-gray-900 [&>option]:text-white"
						aria-label="Trocar matriz"
						value={curriculoCompletoAtual ?? matrizCurricular ?? ''}
						onchange={(e) => onMatrizChange((e.target as HTMLSelectElement).value)}
					>
						{#each matrizes as m}
							<option value={m.curriculoCompleto}>{formatMatrizLabel(m.curriculoCompleto)}</option>
						{/each}
					</select>
					<span class="hidden shrink-0 text-xs text-white/60 md:inline">Trocar matriz</span>
				</div>
			{/if}
			{#if showBackToMyFluxogram}
				<button
					onclick={handleBackToMyFluxogram}
					class="inline-flex w-full items-center justify-center gap-1 rounded-md border border-cyan-500/40 bg-cyan-500/20 px-2 py-1.5 text-center text-[10px] font-medium leading-snug text-cyan-200 backdrop-blur-md transition-colors hover:bg-cyan-500/30 hover:text-cyan-100 md:w-auto md:rounded-full md:px-4 md:py-2 md:text-sm"
				>
					<Home class="h-3 w-3 shrink-0 md:h-4 md:w-4" />
					<span>Voltar ao meu fluxograma</span>
				</button>
			{/if}
			{#if !store.state.isAnonymous}
				{#if showConfirmDelete}
					<div
						class="flex w-full flex-wrap items-center justify-center gap-1.5 rounded-md border border-red-500/30 bg-red-500/10 px-2 py-1.5 backdrop-blur-md md:w-auto md:gap-2 md:rounded-full md:px-3 md:py-2"
					>
						<span class="text-[10px] text-red-300 md:text-xs">Tem certeza?</span>
						<button
							onclick={handleReupload}
							disabled={isDeleting}
							class="rounded-full bg-red-600 px-3 py-1 text-xs font-medium text-white transition-colors hover:bg-red-500 disabled:opacity-50"
						>
							{isDeleting ? 'Removendo...' : 'Sim'}
						</button>
						<button
							onclick={() => (showConfirmDelete = false)}
							class="rounded-full bg-white/10 px-3 py-1 text-xs font-medium text-white/70 transition-colors hover:bg-white/20"
						>
							Não
						</button>
					</div>
				{/if}
			{/if}
			{#if !store.state.isAnonymous && !showConfirmDelete}
				<div class="flex w-full min-w-0 flex-row items-center gap-2 md:contents">
					{#if showFluxogramViewMenu && onOpenFluxogramHelp}
						<FluxogramViewMenu onOpenHelp={onOpenFluxogramHelp} />
					{/if}
					<button
						onclick={() => (showConfirmDelete = true)}
						class="inline-flex min-h-9 min-w-0 flex-1 items-center justify-center gap-1 rounded-md border border-white/10 bg-black/40 px-2 py-1.5 text-[10px] font-medium text-white/60 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white md:h-10 md:w-auto md:flex-none md:rounded-full md:px-4 md:py-2 md:text-sm"
					>
						<RefreshCw class="h-3 w-3 md:h-4 md:w-4" />
						<span class="hidden md:inline">Enviar Novamente</span>
						<span class="md:hidden">Reenviar</span>
					</button>
					<button
						type="button"
						onclick={handleScreenshot}
						class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/80 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white md:h-10 md:w-10"
						aria-label="Capturar screenshot do fluxograma"
						title="Screenshot"
					>
						<Camera class="h-[18px] w-[18px] md:h-5 md:w-5" />
					</button>
				</div>
			{:else}
				<div class="flex w-full justify-end gap-2 md:contents">
					{#if showFluxogramViewMenu && onOpenFluxogramHelp}
						<FluxogramViewMenu onOpenHelp={onOpenFluxogramHelp} />
					{/if}
					<button
						type="button"
						onclick={handleScreenshot}
						class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/80 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white md:h-10 md:w-10"
						aria-label="Capturar screenshot do fluxograma"
						title="Screenshot"
					>
						<Camera class="h-[18px] w-[18px] md:h-5 md:w-5" />
					</button>
				</div>
			{/if}
		</div>
	</div>
</header>
