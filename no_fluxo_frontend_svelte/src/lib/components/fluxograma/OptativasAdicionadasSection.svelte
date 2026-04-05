<script lang="ts">
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, BookOpen, Save, Loader2 } from 'lucide-svelte';

	const store = fluxogramaStore;

	let saving = $state(false);

	async function salvarPlanejamento() {
		saving = true;
		try {
			await store.saveOptativasPlanejadas();
		} finally {
			saving = false;
		}
	}
</script>

{#if store.optativasAdicionadas.length > 0}
	<div class="min-w-0 rounded-xl border border-white/10 bg-black/40 p-3 backdrop-blur-md sm:p-4">
		<div class="mb-3 flex flex-wrap items-center justify-between gap-2">
			<div class="flex items-center gap-2">
				<BookOpen class="h-4 w-4 text-blue-400" />
				<h3 class="text-sm font-semibold uppercase tracking-wider text-white/70">
					Optativas no fluxograma
				</h3>
				<span class="rounded-full bg-blue-500/20 px-2 py-0.5 text-xs font-medium text-blue-300">
					{store.optativasAdicionadas.length}
				</span>
			</div>
			{#if !store.state.isAnonymous}
				<button
					type="button"
					disabled={store.optativasPlanejamentoSalvo || saving}
					onclick={salvarPlanejamento}
					class="inline-flex items-center gap-1.5 rounded-lg border border-purple-500/40 bg-purple-600/30 px-3 py-1.5 text-xs font-semibold text-purple-100 transition-colors hover:bg-purple-600/45 disabled:cursor-not-allowed disabled:opacity-40"
				>
					{#if saving}
						<Loader2 class="h-3.5 w-3.5 animate-spin" />
						Salvando…
					{:else}
						<Save class="h-3.5 w-3.5" />
						{store.optativasPlanejamentoSalvo ? 'Salvo' : 'Salvar no perfil'}
					{/if}
				</button>
			{/if}
		</div>

		{#if !store.state.isAnonymous && !store.optativasPlanejamentoSalvo}
			<p class="mb-3 text-[11px] text-amber-200/80">
				Alterações ainda não salvas — use &quot;Salvar no perfil&quot; para gravar em seus dados.
			</p>
		{:else if store.state.isAnonymous}
			<p class="mb-3 text-[11px] text-white/45">
				Entre na conta para salvar o planejamento de optativas.
			</p>
		{/if}

		<div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
			{#each store.optativasAdicionadas as opt (`${opt.materia.codigoMateria}-${opt.semestre}`)}
				<div
					class="group relative rounded-lg border border-blue-500/20 bg-gradient-to-br from-blue-500/10 to-blue-700/5 px-4 py-3 transition-colors hover:border-blue-500/30"
				>
					<div class="flex items-start justify-between gap-2">
						<div class="flex-1">
							<p class="text-sm font-medium text-white/90">{opt.materia.nomeMateria}</p>
							<p class="text-xs text-white/50">{opt.materia.codigoMateria}</p>
							<div class="mt-1.5 flex flex-wrap items-center gap-2">
								<span class="rounded-full bg-white/10 px-2 py-0.5 text-[10px] text-white/60">
									{opt.materia.creditos} cr
								</span>
								<span class="rounded-full bg-purple-500/20 px-2 py-0.5 text-[10px] text-purple-300">
									{opt.semestre}º sem
								</span>
								<span
									class="rounded-full bg-purple-500/35 px-2 py-0.5 text-[9px] font-semibold text-purple-100"
								>(opt)</span>
							</div>
						</div>
						<button
							onclick={() => store.removeOptativa(opt.materia.codigoMateria)}
							class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-white/30 opacity-0 transition-all hover:bg-red-500/20 hover:text-red-400 group-hover:opacity-100"
							aria-label="Remover optativa"
						>
							<X class="h-3.5 w-3.5" />
						</button>
					</div>
				</div>
			{/each}
		</div>
	</div>
{/if}
