<script lang="ts">
	import { ArrowLeft, Camera, RefreshCw, Home } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
	import { authStore } from '$lib/stores/auth';
	import { toast } from 'svelte-sonner';

	interface Props {
		courseName: string;
		matrizCurricular?: string;
		containerRef?: HTMLElement | null;
		/** Mostra botão "Voltar ao meu fluxograma" quando está vendo outro curso (simulação) */
		showBackToMyFluxogram?: boolean;
	}

	let { courseName, matrizCurricular = '', containerRef = null, showBackToMyFluxogram = false }: Props = $props();

	const store = fluxogramaStore;
	let showConfirmDelete = $state(false);
	let isDeleting = $state(false);

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

<header class="flex min-w-0 flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:gap-4">
	<div class="flex min-w-0 items-center gap-3">
		<button
			onclick={handleBack}
			class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/70 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white sm:h-10 sm:w-10"
			aria-label="Voltar"
		>
			<ArrowLeft class="h-4 w-4 sm:h-5 sm:w-5" />
		</button>
		<div class="min-w-0 flex-1">
			<h1 class="truncate text-lg font-bold text-white sm:text-xl md:text-2xl">{courseName}</h1>
			{#if matrizCurricular}
				<p class="truncate text-xs text-white/50 sm:text-sm">{matrizCurricular}</p>
			{/if}
		</div>
	</div>

	<div class="flex flex-wrap items-center gap-2">
		{#if showBackToMyFluxogram}
			<button
				onclick={handleBackToMyFluxogram}
				class="inline-flex items-center gap-1.5 rounded-full border border-cyan-500/40 bg-cyan-500/20 px-3 py-1.5 text-xs font-medium text-cyan-200 backdrop-blur-md transition-colors hover:bg-cyan-500/30 hover:text-cyan-100 sm:gap-2 sm:px-4 sm:py-2 sm:text-sm"
			>
				<Home class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
				Voltar ao meu fluxograma
			</button>
		{/if}
		{#if !store.state.isAnonymous}
			{#if showConfirmDelete}
				<div class="flex flex-wrap items-center gap-2 rounded-full border border-red-500/30 bg-red-500/10 px-2.5 py-1.5 backdrop-blur-md sm:px-3">
					<span class="text-[10px] text-red-300 sm:text-xs">Tem certeza?</span>
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
			{:else}
				<button
					onclick={() => (showConfirmDelete = true)}
					class="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-black/40 px-3 py-1.5 text-xs font-medium text-white/60 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white sm:gap-2 sm:px-4 sm:py-2 sm:text-sm"
				>
					<RefreshCw class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
					<span class="hidden sm:inline">Enviar Novamente</span>
					<span class="sm:hidden">Reenviar</span>
				</button>
			{/if}
		{/if}

		<button
			onclick={handleScreenshot}
			class="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-black/40 px-3 py-1.5 text-xs font-medium text-white/80 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white sm:gap-2 sm:px-4 sm:py-2 sm:text-sm"
		>
			<Camera class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
			Screenshot
		</button>
	</div>
</header>
