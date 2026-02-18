<script lang="ts">
	import { ArrowLeft, Camera, RefreshCw } from 'lucide-svelte';
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
	}

	let { courseName, matrizCurricular = '', containerRef = null }: Props = $props();

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
</script>

<header class="flex flex-wrap items-center justify-between gap-4">
	<div class="flex items-center gap-3">
		<button
			onclick={handleBack}
			class="flex h-10 w-10 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/70 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white"
			aria-label="Voltar"
		>
			<ArrowLeft class="h-5 w-5" />
		</button>
		<div>
			<h1 class="text-xl font-bold text-white sm:text-2xl">{courseName}</h1>
			{#if matrizCurricular}
				<p class="text-sm text-white/50">{matrizCurricular}</p>
			{/if}
		</div>
	</div>

	<div class="flex items-center gap-2">
		{#if !store.state.isAnonymous}
			{#if showConfirmDelete}
				<div class="flex items-center gap-2 rounded-full border border-red-500/30 bg-red-500/10 px-3 py-1.5 backdrop-blur-md">
					<span class="text-xs text-red-300">Tem certeza?</span>
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
					class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 py-2 text-sm font-medium text-white/60 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white"
				>
					<RefreshCw class="h-4 w-4" />
					Enviar Novamente
				</button>
			{/if}
		{/if}

		<button
			onclick={handleScreenshot}
			class="inline-flex items-center gap-2 rounded-full border border-white/10 bg-black/40 px-4 py-2 text-sm font-medium text-white/80 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white"
		>
			<Camera class="h-4 w-4" />
			Screenshot
		</button>
	</div>
</header>
