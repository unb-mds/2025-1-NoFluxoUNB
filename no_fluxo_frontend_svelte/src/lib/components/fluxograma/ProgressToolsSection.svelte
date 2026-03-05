<script lang="ts">
	import { ArrowRightLeft } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import MudancaCursoModal from './MudancaCursoModal.svelte';

	const store = fluxogramaStore;

	let showMudancaModal = $state(false);

	function handleMudancaClick() {
		if (store.state.isAnonymous) return;
		showMudancaModal = true;
	}
</script>

<div class="min-w-0 rounded-xl border border-white/10 bg-black/40 p-3 backdrop-blur-md sm:p-4">
	<h3 class="mb-3 text-xs font-semibold uppercase tracking-wider text-white/50">
		Ferramentas
	</h3>
	<button
		onclick={handleMudancaClick}
		disabled={store.state.isAnonymous}
		class="group flex w-full items-center gap-4 rounded-xl border border-white/10 bg-gradient-to-br from-amber-500/10 to-amber-700/5 p-4 text-left transition-all hover:border-amber-500/30 hover:shadow-lg disabled:cursor-not-allowed disabled:opacity-50"
	>
		<div class="rounded-full bg-amber-500/20 p-3 {store.state.isAnonymous ? 'opacity-50' : ''}">
			<ArrowRightLeft class="h-6 w-6 text-amber-400" />
		</div>
		<div>
			<h4 class="text-sm font-semibold text-white/90">Mudança de Curso</h4>
			<p class="mt-0.5 text-xs text-white/50">
				Simule como seria sua integralização em outro curso
			</p>
		</div>
	</button>
</div>

<MudancaCursoModal open={showMudancaModal} onclose={() => (showMudancaModal = false)} />
