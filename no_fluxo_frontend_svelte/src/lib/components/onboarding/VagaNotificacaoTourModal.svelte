<script lang="ts">
	import { fade, fly } from 'svelte/transition';
	import { Bell, BellOff, Search, Loader2, X, ChevronRight } from 'lucide-svelte';
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { getTurmasPorMaterias, type TurmaOferta } from '$lib/services/turmas.service';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';

	interface Props {
		open: boolean;
		onClose: () => void;
	}

	let { open, onClose }: Props = $props();

	const supabase = createSupabaseBrowserClient();

	let step = $state(1);
	const TOTAL_STEPS = 2;

	type SearchResult = { idMateria: number; codigoMateria: string; nomeMateria: string };

	let query = $state('');
	let resultados = $state<SearchResult[]>([]);
	let buscando = $state(false);
	let erroBusca = $state<string | null>(null);

	let selecionada = $state<SearchResult | null>(null);
	let turmas = $state<TurmaOferta[]>([]);
	let turmasLoading = $state(false);
	let turmasError = $state<string | null>(null);

	let debounceHandle: ReturnType<typeof setTimeout> | undefined;

	$effect(() => {
		const termo = query.trim();
		clearTimeout(debounceHandle);
		if (termo.length < 2) {
			resultados = [];
			erroBusca = null;
			buscando = false;
			return;
		}
		buscando = true;
		debounceHandle = setTimeout(async () => {
			const safe = termo.replace(/[%,]/g, ' ').trim();
			try {
				const { data, error } = await supabase
					.from('materias')
					.select('id_materia, codigo_materia, nome_materia')
					.or(`codigo_materia.ilike.%${safe.toUpperCase()}%,nome_materia.ilike.%${safe}%`)
					.order('codigo_materia')
					.limit(8);
				if (error) {
					erroBusca = error.message;
					resultados = [];
					return;
				}
				erroBusca = null;
				resultados = (data ?? []).map((m) => ({
					idMateria: Number(m.id_materia),
					codigoMateria: String(m.codigo_materia),
					nomeMateria: String(m.nome_materia)
				}));
			} catch (e: unknown) {
				erroBusca = e instanceof Error ? e.message : 'Erro ao buscar matérias.';
				resultados = [];
			} finally {
				buscando = false;
			}
		}, 300);

		return () => clearTimeout(debounceHandle);
	});

	function selecionar(item: SearchResult) {
		selecionada = item;
		resultados = [];
		query = '';
		turmas = [];
		turmasLoading = true;
		turmasError = null;
		if (!vagaAssinaturasStore.carregado) void vagaAssinaturasStore.load();
		getTurmasPorMaterias([item.idMateria])
			.then((rows) => {
				turmas = rows;
			})
			.catch(() => {
				turmasError = 'Não foi possível carregar as turmas agora.';
			})
			.finally(() => {
				turmasLoading = false;
			});
	}

	function limparSelecao() {
		selecionada = null;
		turmas = [];
		turmasError = null;
	}

	function next() {
		if (step < TOTAL_STEPS) step++;
	}

	function fechar() {
		onClose();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') fechar();
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center p-4"
		transition:fade={{ duration: 180 }}
		role="dialog"
		aria-modal="true"
		aria-label="Novidade: avise-me quando abrir vaga"
	>
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="absolute inset-0 bg-black/70 backdrop-blur-sm"
			onclick={fechar}
			onkeydown={(e) => e.key === 'Enter' && fechar()}
		></div>

		<div
			class="relative z-10 w-full max-w-md overflow-hidden rounded-2xl border border-white/10 bg-[#0e1117] shadow-2xl"
			transition:fly={{ y: 24, duration: 250 }}
		>
			<!-- Header -->
			<div class="relative border-b border-white/8 px-6 py-5">
				<div class="flex items-center gap-3">
					<div class="flex h-9 w-9 items-center justify-center rounded-xl bg-purple-600/20">
						<Bell class="h-5 w-5 text-purple-300" />
					</div>
					<div>
						<p class="text-[11px] font-semibold uppercase tracking-widest text-purple-300">
							Novidade
						</p>
						<h2 class="text-base font-semibold leading-tight text-white">
							Avise-me quando abrir vaga
						</h2>
					</div>
				</div>
				<button
					type="button"
					onclick={fechar}
					class="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-lg text-white/40 transition-colors hover:bg-white/8 hover:text-white/80"
					aria-label="Fechar"
				>
					<X class="h-4 w-4" />
				</button>
			</div>

			<!-- Progress bar -->
			<div class="h-0.5 bg-white/6">
				<div
					class="h-full bg-purple-500 transition-all duration-400 ease-out"
					style="width: {(step / TOTAL_STEPS) * 100}%"
				></div>
			</div>

			<div class="px-6 py-7">
				{#if step === 1}
					<p class="mb-1 text-[11px] font-medium text-white/35">Passo 1 de {TOTAL_STEPS}</p>
					<h3 class="mb-4 text-lg font-semibold text-white">Turma lotada não precisa travar seu plano</h3>
					<p class="text-sm leading-relaxed text-white/65">
						Agora você pode <span class="font-medium text-white/90">seguir uma turma</span> mesmo
						que ela esteja sem vaga. Assim que surgir uma vaga, a gente te avisa direto no sino de
						notificações, no topo da tela.
					</p>
					<div class="mt-5 flex items-center gap-2 rounded-xl border border-white/10 bg-white/4 px-3 py-2.5">
						<Bell class="h-4 w-4 shrink-0 text-purple-300" />
						<p class="text-xs text-white/55">
							Você pode seguir/parar de seguir a qualquer momento em Disciplinas ou no seu
							Fluxograma.
						</p>
					</div>
				{:else if step === 2}
					<p class="mb-1 text-[11px] font-medium text-white/35">Passo 2 de {TOTAL_STEPS}</p>
					<h3 class="mb-4 text-lg font-semibold text-white">Já aproveita e segue uma matéria</h3>

					{#if !selecionada}
						<div class="relative">
							<Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/35" />
							<input
								type="text"
								bind:value={query}
								placeholder="Buscar por código ou nome (ex.: CIC0004)"
								class="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-white/35 focus:border-purple-400/50 focus:outline-none"
							/>
						</div>

						{#if buscando}
							<p class="mt-3 flex items-center gap-2 text-xs text-white/45">
								<Loader2 class="h-3.5 w-3.5 animate-spin" /> Buscando...
							</p>
						{:else if erroBusca}
							<p class="mt-3 text-xs text-red-300/85">{erroBusca}</p>
						{:else if resultados.length > 0}
							<div class="mt-3 max-h-52 space-y-1.5 overflow-y-auto">
								{#each resultados as item (item.idMateria)}
									<button
										type="button"
										onclick={() => selecionar(item)}
										class="flex w-full items-center justify-between gap-2 rounded-lg border border-white/10 bg-white/4 px-3 py-2 text-left transition-colors hover:border-white/20 hover:bg-white/8"
									>
										<span class="min-w-0">
											<span class="block font-mono text-xs font-semibold text-purple-200">
												{item.codigoMateria}
											</span>
											<span class="block truncate text-xs text-white/60">{item.nomeMateria}</span>
										</span>
										<ChevronRight class="h-4 w-4 shrink-0 text-white/30" />
									</button>
								{/each}
							</div>
						{:else if query.trim().length >= 2}
							<p class="mt-3 text-xs text-white/45">Nenhuma matéria encontrada.</p>
						{/if}
					{:else}
						<div class="mb-3 flex items-center justify-between gap-2 rounded-lg border border-white/10 bg-white/4 px-3 py-2">
							<span class="min-w-0">
								<span class="block font-mono text-xs font-semibold text-purple-200">
									{selecionada.codigoMateria}
								</span>
								<span class="block truncate text-xs text-white/60">{selecionada.nomeMateria}</span>
							</span>
							<button
								type="button"
								onclick={limparSelecao}
								class="shrink-0 text-xs font-medium text-white/40 transition-colors hover:text-white/70"
							>
								Trocar
							</button>
						</div>

						{#if turmasLoading}
							<p class="flex items-center gap-2 text-xs text-white/45">
								<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando turmas...
							</p>
						{:else if turmasError}
							<p class="text-xs text-red-300/85">{turmasError}</p>
						{:else if turmas.length === 0}
							<p class="text-xs text-white/45">Nenhuma turma ofertada no período atual.</p>
						{:else}
							<div class="max-h-52 space-y-1.5 overflow-y-auto">
								{#each turmas as t (t.id_turmas)}
									{@const seguindo = vagaAssinaturasStore.isSeguindo(t.id_materia, t.turma, t.ano_periodo)}
									{@const seguirBusy = vagaAssinaturasStore.isBusy(t.id_materia, t.turma, t.ano_periodo)}
									<div class="flex items-center justify-between gap-2 rounded-lg border border-white/10 bg-black/25 px-3 py-2">
										<div class="min-w-0">
											<span class="font-mono text-xs font-semibold text-purple-200">Turma {t.turma}</span>
											{#if t.vagas_sobrando != null}
												<span class="ml-1.5 text-[10px] text-white/45">
													{t.vagas_sobrando > 0 ? `${t.vagas_sobrando} vaga(s)` : 'Sem vagas'}
												</span>
											{/if}
										</div>
										<button
											type="button"
											disabled={seguirBusy}
											onclick={() => vagaAssinaturasStore.toggle(t.id_materia, t.turma, t.ano_periodo)}
											class="inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition-colors disabled:opacity-50 {seguindo
												? 'border-purple-300/45 bg-purple-500/18 text-purple-100 hover:bg-purple-500/25'
												: 'border-white/15 bg-white/5 text-white/70 hover:bg-white/10'}"
										>
											{#if seguirBusy}
												<Loader2 class="h-3 w-3 animate-spin" />
											{:else if seguindo}
												<Bell class="h-3 w-3" />
											{:else}
												<BellOff class="h-3 w-3" />
											{/if}
											{seguindo ? 'Seguindo' : 'Seguir'}
										</button>
									</div>
								{/each}
							</div>
						{/if}
					{/if}
				{/if}
			</div>

			<!-- Footer actions -->
			<div class="flex items-center justify-between border-t border-white/8 px-6 py-4">
				<button
					type="button"
					onclick={fechar}
					class="text-sm font-medium text-white/45 transition-colors hover:text-white/70"
				>
					{step === 1 ? 'Pular' : 'Concluir'}
				</button>

				{#if step === 1}
					<button
						type="button"
						onclick={next}
						class="flex items-center gap-1.5 rounded-lg bg-purple-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-purple-500 active:bg-purple-700"
					>
						Próximo
						<ChevronRight class="h-4 w-4" />
					</button>
				{:else}
					<button
						type="button"
						onclick={fechar}
						class="flex items-center gap-1.5 rounded-lg bg-purple-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-purple-500 active:bg-purple-700"
					>
						<Bell class="h-4 w-4" />
						Concluir
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}
