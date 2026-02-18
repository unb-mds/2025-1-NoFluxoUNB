<script lang="ts">
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { X, BookOpen } from 'lucide-svelte';

	const store = fluxogramaStore;
</script>

{#if store.optativasAdicionadas.length > 0}
	<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
		<div class="mb-3 flex items-center gap-2">
			<BookOpen class="h-4 w-4 text-blue-400" />
			<h3 class="text-sm font-semibold uppercase tracking-wider text-white/70">
				Optativas Adicionadas
			</h3>
			<span class="rounded-full bg-blue-500/20 px-2 py-0.5 text-xs font-medium text-blue-300">
				{store.optativasAdicionadas.length}
			</span>
		</div>

		<div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
			{#each store.optativasAdicionadas as opt (opt.materia.codigoMateria)}
				<div class="group relative rounded-lg border border-blue-500/20 bg-gradient-to-br from-blue-500/10 to-blue-700/5 px-4 py-3 transition-colors hover:border-blue-500/30">
					<div class="flex items-start justify-between gap-2">
						<div class="flex-1">
							<p class="text-sm font-medium text-white/90">{opt.materia.nomeMateria}</p>
							<p class="text-xs text-white/50">{opt.materia.codigoMateria}</p>
							<div class="mt-1.5 flex items-center gap-2">
								<span class="rounded-full bg-white/10 px-2 py-0.5 text-[10px] text-white/60">
									{opt.materia.creditos} cr
								</span>
								<span class="rounded-full bg-purple-500/20 px-2 py-0.5 text-[10px] text-purple-300">
									{opt.semestre}º sem
								</span>
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
