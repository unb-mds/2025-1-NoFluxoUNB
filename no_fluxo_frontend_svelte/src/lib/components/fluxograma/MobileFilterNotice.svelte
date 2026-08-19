<script lang="ts">
	import { onMount } from 'svelte';
	import { Settings2, X } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

	/**
	 * Aviso (só mobile) de que optativas/módulos livres começam ocultos para
	 * uma visualização melhor — o fluxograma completo fica a um toque no ⚙.
	 * Some ao dispensar (persistido em localStorage) ou quando o usuário
	 * ativa os dois filtros.
	 */

	const DISMISS_KEY = 'nf-fluxo-aviso-filtros-mobile';

	const store = fluxogramaStore;
	let dismissed = $state(true);

	onMount(() => {
		dismissed = localStorage.getItem(DISMISS_KEY) === '1';
	});

	function dismiss() {
		dismissed = true;
		localStorage.setItem(DISMISS_KEY, '1');
	}

	let filtrosAtivos = $derived(store.state.showOptativas && store.state.showModulosLivres);
</script>

{#if !dismissed && !filtrosAtivos}
	<div
		class="mb-2 flex items-start gap-2.5 rounded-xl border border-primary/30 bg-primary/[0.12] px-3 py-2.5 text-xs leading-relaxed text-white/85 backdrop-blur-md md:hidden"
		role="note"
	>
		<Settings2 class="mt-0.5 h-4 w-4 shrink-0 text-purple-300" aria-hidden="true" />
		<p class="min-w-0 flex-1">
			Para uma melhor experiência e visualização no celular, mostramos só as
			<strong class="text-white">obrigatórias e optatórias</strong>. Ative
			<strong class="text-white">Optativas</strong> e
			<strong class="text-white">Módulos livres</strong> no menu de exibição (⚙) para ver o
			fluxograma completo.
		</p>
		<button
			type="button"
			onclick={dismiss}
			class="shrink-0 rounded-lg p-1 text-white/55 transition-colors hover:bg-white/10 hover:text-white"
			aria-label="Dispensar aviso"
		>
			<X class="h-4 w-4" />
		</button>
	</div>
{/if}
