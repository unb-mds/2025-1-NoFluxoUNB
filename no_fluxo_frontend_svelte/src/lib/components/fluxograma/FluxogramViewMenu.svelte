<script lang="ts">
	import { Settings2, HelpCircle } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	interface Props {
		onOpenHelp?: () => void;
	}

	let { onOpenHelp }: Props = $props();

	const store = fluxogramaStore;
	let open = $state(false);

	function close() {
		open = false;
	}

	function handleDocClick(e: MouseEvent) {
		const t = e.target as HTMLElement;
		if (!t.closest('[data-fluxo-view-menu]')) open = false;
	}
</script>

<svelte:window onmousedown={handleDocClick} />

<!--
	Menu compacto no header: totais (CH) + atalho Ajuda — reduz barra inferior.
-->
<div class="relative shrink-0" data-fluxo-view-menu>
	<button
		type="button"
		onclick={() => (open = !open)}
		class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/10 bg-black/40 text-white/75 backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white md:h-10 md:w-10"
		aria-expanded={open}
		aria-haspopup="menu"
		aria-label="Exibição e ajuda do fluxograma"
		title="Exibição e ajuda"
	>
		<Settings2 class="h-[18px] w-[18px] md:h-5 md:w-5" />
	</button>

	{#if open}
		<div
			class="absolute right-0 top-full z-[60] mt-1.5 min-w-[13rem] overflow-hidden rounded-xl border border-white/15 bg-gray-950/95 py-1 shadow-xl backdrop-blur-xl"
			role="menu"
			tabindex="-1"
			onmousedown={(e) => e.stopPropagation()}
		>
			<div class="border-b border-white/10 px-3 py-2">
				<p class="text-[10px] font-semibold uppercase tracking-wide text-white/45">Totais por semestre</p>
				<div class="mt-2 flex gap-0 overflow-hidden rounded-lg border border-white/10 bg-white/5">
					<button
						type="button"
						role="menuitem"
						onclick={() => {
							store.setDisplayUnit('creditos');
							close();
						}}
						class="flex-1 px-3 py-2 text-left text-xs font-medium transition-colors {store.state.displayUnit === 'creditos'
							? 'bg-cyan-500/25 text-cyan-200'
							: 'text-white/75 hover:bg-white/10'}"
					>
						Créditos
					</button>
					<button
						type="button"
						role="menuitem"
						onclick={() => {
							store.setDisplayUnit('horas');
							close();
						}}
						class="flex-1 border-l border-white/10 px-3 py-2 text-left text-xs font-medium transition-colors {store.state.displayUnit === 'horas'
							? 'bg-cyan-500/25 text-cyan-200'
							: 'text-white/75 hover:bg-white/10'}"
					>
						Horas
					</button>
				</div>
			</div>
			<button
				type="button"
				role="menuitem"
				onclick={() => {
					onOpenHelp?.();
					close();
				}}
				class="flex w-full items-center gap-2 px-3 py-2.5 text-left text-sm text-cyan-200/95 transition-colors hover:bg-white/10"
			>
				<HelpCircle class="h-4 w-4 shrink-0" />
				Legenda e regras de uso
			</button>
		</div>
	{/if}
</div>
