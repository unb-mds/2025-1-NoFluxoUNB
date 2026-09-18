<script lang="ts">
	import { X, Camera, Link2 } from 'lucide-svelte';
	import { portal } from '$lib/actions/portal';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	interface Props {
		open: boolean;
		onclose: () => void;
		containerRef: HTMLElement | null;
	}

	let { open, onclose, containerRef }: Props = $props();

	function choose(mode: 'off' | 'all') {
		onclose();
		void fluxogramaStore.saveScreenshot(containerRef, { connectionMode: mode });
	}

	function handleWindowKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && open) onclose();
	}

	$effect(() => {
		if (!open || typeof document === 'undefined') return;
		const prev = document.body.style.overflow;
		document.body.style.overflow = 'hidden';
		return () => {
			document.body.style.overflow = prev;
		};
	});
</script>

<svelte:window onkeydown={handleWindowKeydown} />

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		use:portal
		data-screenshot-choice-modal
		class="fixed inset-0 z-[5600] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
		role="presentation"
		onclick={onclose}
	>
		<div
			role="dialog"
			aria-modal="true"
			aria-labelledby="screenshot-modal-title"
			tabindex="-1"
			class="w-full max-w-md rounded-2xl border border-white/15 bg-gray-950/98 shadow-2xl backdrop-blur-xl"
			onmousedown={(e) => e.stopPropagation()}
			onclick={(e) => e.stopPropagation()}
		>
			<div class="flex items-center justify-between border-b border-white/10 px-4 py-3">
				<h2 id="screenshot-modal-title" class="text-base font-bold text-white">Screenshot do fluxograma</h2>
				<button
					type="button"
					onclick={onclose}
					class="rounded-lg p-2 text-white/60 hover:bg-white/10"
					aria-label="Fechar"
				>
					<X class="h-5 w-5" />
				</button>
			</div>
			<div class="space-y-3 px-4 py-4">
				<p class="text-sm text-white/60">Como você quer exportar a imagem?</p>
				<button
					type="button"
					onclick={() => choose('off')}
					class="flex w-full items-center gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-left transition-colors hover:border-white/20 hover:bg-white/10"
				>
					<span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-white/10 text-white/90">
						<Camera class="h-5 w-5" />
					</span>
					<span class="min-w-0 flex-1">
						<span class="block font-medium text-white">Normal</span>
						<span class="mt-0.5 block text-xs text-white/50">Apenas as disciplinas, sem linhas de conexão</span>
					</span>
				</button>
				<button
					type="button"
					onclick={() => choose('all')}
					class="flex w-full items-center gap-3 rounded-xl border border-purple-500/30 bg-purple-500/10 px-4 py-3 text-left transition-colors hover:border-purple-400/40 hover:bg-purple-500/15"
				>
					<span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-purple-500/25 text-purple-200">
						<Link2 class="h-5 w-5" />
					</span>
					<span class="min-w-0 flex-1">
						<span class="block font-medium text-purple-100">Com todas as conexões</span>
						<span class="mt-0.5 block text-xs text-purple-200/60">
							Pré-requisitos, dependentes e co-requisitos (modo “Todas”)
						</span>
					</span>
				</button>
				<button
					type="button"
					onclick={onclose}
					class="w-full rounded-xl border border-white/10 py-2.5 text-sm font-medium text-white/70 transition-colors hover:bg-white/5"
				>
					Cancelar
				</button>
			</div>
		</div>
	</div>
{/if}
