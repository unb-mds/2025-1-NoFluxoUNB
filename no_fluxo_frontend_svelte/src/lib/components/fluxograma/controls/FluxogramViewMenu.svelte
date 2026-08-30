<script lang="ts">
	import { Settings2, X } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { portal } from '$lib/actions/portal';

	const store = fluxogramaStore;
	let open = $state(false);

	function close() {
		open = false;
	}

	function handleDocClick(e: MouseEvent) {
		const t = e.target as HTMLElement;
		if (!t.closest('[data-fluxo-view-menu]')) open = false;
	}

	function handleWindowKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && open) close();
	}
</script>

<svelte:window onmousedown={handleDocClick} onkeydown={handleWindowKeydown} />

<!--
	Créditos/Horas: modal em portal (body) — ancestrais com backdrop-blur/transform prendiam o fixed e o fluxograma passava por cima.
-->
<div class="relative shrink-0" data-fluxo-view-menu>
	<button
		type="button"
		onclick={() => (open = !open)}
		class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/75 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white md:h-10 md:w-10"
		aria-expanded={open}
		aria-haspopup="dialog"
		aria-label="Opções de exibição do fluxograma"
		title="Opções de exibição"
	>
		<Settings2 class="h-[18px] w-[18px] md:h-5 md:w-5" />
	</button>

	{#if open}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			use:portal
			data-fluxo-view-menu
			class="fixed inset-0 z-[5500] flex items-center justify-center bg-black/55 p-4 backdrop-blur-sm"
			role="presentation"
			onclick={close}
		>
			<div
				role="dialog"
				aria-modal="true"
				aria-labelledby="fluxo-unit-modal-title"
				tabindex="-1"
				class="w-full max-w-sm rounded-2xl border border-white/15 bg-gray-950/98 shadow-2xl backdrop-blur-xl"
				onmousedown={(e) => e.stopPropagation()}
				onclick={(e) => e.stopPropagation()}
			>
				<div class="flex items-center justify-between border-b border-white/10 px-4 py-3">
					<h2 id="fluxo-unit-modal-title" class="text-sm font-semibold text-white">Exibição do fluxograma</h2>
					<button
						type="button"
						onclick={close}
						class="rounded-lg p-2 text-white/60 hover:bg-white/10"
						aria-label="Fechar"
					>
						<X class="h-5 w-5" />
					</button>
				</div>
				<div class="px-4 py-4">
					<p class="mb-3 text-xs text-white/55">Como exibir os totais nas colunas do fluxograma:</p>
					<div class="flex gap-0 overflow-hidden rounded-xl border border-white/10 bg-white/5">
						<button
							type="button"
							onclick={() => {
								store.setDisplayUnit('creditos');
								close();
							}}
							class="flex-1 px-4 py-3 text-sm font-medium transition-colors {store.state.displayUnit === 'creditos'
								? 'bg-cyan-500/25 text-cyan-200'
								: 'text-white/75 hover:bg-white/10'}"
						>
							Créditos
						</button>
						<button
							type="button"
							onclick={() => {
								store.setDisplayUnit('horas');
								close();
							}}
							class="flex-1 border-l border-white/10 px-4 py-3 text-sm font-medium transition-colors {store.state.displayUnit === 'horas'
								? 'bg-cyan-500/25 text-cyan-200'
								: 'text-white/75 hover:bg-white/10'}"
						>
							Horas
						</button>
					</div>

					<!-- Filtros: optativas e módulos livres (no mobile começam ocultos) -->
					<p class="mb-2 mt-5 text-xs text-white/55">Mostrar no fluxograma:</p>
					<div class="flex flex-col gap-2">
						<button
							type="button"
							role="switch"
							aria-checked={store.state.showOptativas}
							onclick={() => store.toggleShowOptativas()}
							class="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium transition-colors hover:bg-white/10"
						>
							<span class="flex items-center gap-2 text-white/85">
								Optativas
								<span class="rounded bg-blue-500/80 px-1.5 py-0.5 text-[9px] font-medium text-white">opt.</span>
							</span>
							<span
								class="relative h-5 w-9 shrink-0 rounded-full transition-colors {store.state.showOptativas
									? 'bg-cyan-500/70'
									: 'bg-white/15'}"
								aria-hidden="true"
							>
								<span
									class="absolute top-0.5 h-4 w-4 rounded-full bg-white transition-[left] {store.state.showOptativas
										? 'left-[18px]'
										: 'left-0.5'}"
								></span>
							</span>
						</button>
						<button
							type="button"
							role="switch"
							aria-checked={store.state.showModulosLivres}
							onclick={() => store.toggleShowModulosLivres()}
							class="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium transition-colors hover:bg-white/10"
						>
							<span class="flex items-center gap-2 text-white/85">
								Módulos livres
								<span class="rounded bg-teal-400/90 px-1.5 py-0.5 text-[9px] font-medium text-black">mód. livre</span>
							</span>
							<span
								class="relative h-5 w-9 shrink-0 rounded-full transition-colors {store.state.showModulosLivres
									? 'bg-cyan-500/70'
									: 'bg-white/15'}"
								aria-hidden="true"
							>
								<span
									class="absolute top-0.5 h-4 w-4 rounded-full bg-white transition-[left] {store.state.showModulosLivres
										? 'left-[18px]'
										: 'left-0.5'}"
								></span>
							</span>
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>
