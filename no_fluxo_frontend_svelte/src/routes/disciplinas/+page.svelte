<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { getCodigosFromExpressaoLogica } from '$lib/utils/expressao-logica';

	const supabase = createSupabaseBrowserClient();

	type MateriaRow = {
		id_materia: number;
		codigo_materia: string;
		nome_materia: string;
	};

	type PreRequisitoRow = {
		id_pre_requisito: number;
		id_materia: number;
		codigo_materia: string;
		nome_materia: string;
		expressao_original: string | null;
		expressao_logica: unknown | null;
		codigo_requisito: string | null;
		nome_requisito: string | null;
	};

	type EquivalenciaRow = {
		id_equivalencia: number;
		id_materia: number;
		expressao_original: string | null;
		expressao_logica: unknown | null;
		codigo_materia_origem: string | null;
		nome_materia_origem: string | null;
		curriculo: string | null;
	};

let termoBusca = $state('');
let carregandoBusca = $state(false);
let resultados = $state<MateriaRow[]>([]);
let erroBusca = $state<string | null>(null);

let selecionada = $state<MateriaRow | null>(null);
let carregandoDetalhes = $state(false);
let prereqs = $state<PreRequisitoRow[]>([]);
let equivs = $state<EquivalenciaRow[]>([]);
let erroDetalhes = $state<string | null>(null);

let materiasExtras = $state(new Map<string, MateriaRow>());

	async function buscarMaterias() {
		const termo = termoBusca.trim();
		if (!termo || termo.length < 2) {
			resultados = [];
			selecionada = null;
			prereqs = [];
			equivs = [];
			erroBusca = null;
			return;
		}

		carregandoBusca = true;
		erroBusca = null;
		selecionada = null;
		prereqs = [];
		equivs = [];

		try {
			const { data, error } = await supabase
				.from('materias')
				.select('id_materia, codigo_materia, nome_materia')
				.or(
					`codigo_materia.ilike.${termo.toUpperCase()}%,nome_materia.ilike.%${termo}%`
				)
				.order('codigo_materia')
				.limit(25);

			if (error) {
				erroBusca = error.message;
				resultados = [];
			} else {
				resultados = data as MateriaRow[] || [];
			}
		} catch (e: any) {
			erroBusca = e?.message ?? 'Erro ao buscar disciplinas.';
			resultados = [];
		} finally {
			carregandoBusca = false;
		}
	}

	async function carregarDetalhes(m: MateriaRow) {
		selecionada = m;
		carregandoDetalhes = true;
		erroDetalhes = null;
		prereqs = [];
		equivs = [];

		try {
			const [pre, eq] = await Promise.all([
				supabase.rpc('get_pre_requisitos_materia', {
					p_codigo: m.codigo_materia,
					p_nome: null
				}),
				supabase.rpc('get_equivalencias_materia', {
					p_codigo: m.codigo_materia,
					p_nome: null
				})
			]);

			if (pre.error) {
				erroDetalhes = pre.error.message;
			} else {
				prereqs = (pre.data as unknown as PreRequisitoRow[]) || [];
			}

			if (eq.error) {
				erroDetalhes = (erroDetalhes ? erroDetalhes + ' / ' : '') + eq.error.message;
			} else {
				equivs = (eq.data as unknown as EquivalenciaRow[]) || [];
			}
			
			// Carregar nomes das matérias envolvidas nas expressões (pré-requisitos e equivalências)
			const codigosExtras = new Set<string>();
			for (const pr of prereqs) {
				for (const c of codigosDaExpressao(pr.expressao_logica)) {
					const key = c.trim().toUpperCase();
					if (key && !materiasExtras.has(key)) codigosExtras.add(key);
				}
			}
			for (const eqRow of equivs) {
				for (const c of codigosDaExpressao(eqRow.expressao_logica)) {
					const key = c.trim().toUpperCase();
					if (key && !materiasExtras.has(key)) codigosExtras.add(key);
				}
			}
			if (codigosExtras.size > 0) {
				const { data: mats, error: matsError } = await supabase
					.from('materias')
					.select('codigo_materia, nome_materia, id_materia')
					.in('codigo_materia', [...codigosExtras]);
				if (!matsError && mats) {
					for (const row of mats as any[]) {
						const key = String(row.codigo_materia).trim().toUpperCase();
						materiasExtras.set(key, {
							id_materia: row.id_materia,
							codigo_materia: row.codigo_materia,
							nome_materia: row.nome_materia
						});
					}
				}
			}
		} catch (e: any) {
			erroDetalhes = e?.message ?? 'Erro ao carregar detalhes.';
		} finally {
			carregandoDetalhes = false;
		}
	}

	function codigosDaExpressao(expressaoLogica: unknown): string[] {
		if (!expressaoLogica) return [];
		try {
			return getCodigosFromExpressaoLogica(expressaoLogica as any);
		} catch {
			return [];
		}
	}
</script>

<PageMeta
	title="Buscar Disciplinas"
	description="Busque disciplinas pelo código ou nome e visualize pré-requisitos e equivalências."
/>

<GraffitiBackground />

<div class="relative z-10 container mx-auto max-w-5xl px-3 py-4 sm:px-4 sm:py-6 space-y-4">
	<h1 class="text-xl sm:text-2xl font-bold text-white mb-1">Disciplinas</h1>
	<p class="text-xs sm:text-sm text-white/60 mb-3">
		Busque por <span class="font-semibold">código</span> (ex.: CIC0004) ou por parte do
		<span class="font-semibold">nome</span> da disciplina.
	</p>

	<!-- Busca -->
	<form
		class="flex flex-col sm:flex-row gap-2 sm:gap-3 items-stretch sm:items-center"
		onsubmit={async (e) => { e.preventDefault(); await buscarMaterias(); }}
	>
		<input
			type="text"
			bind:value={termoBusca}
			placeholder="Ex.: CIC0004 ou Inteligência Artificial"
			class="flex-1 rounded-full bg-black/40 border border-white/15 px-4 py-2.5 text-sm text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-pink-500/60"
		/>
		<button
			type="submit"
			class="shrink-0 rounded-full bg-gradient-to-r from-pink-500 to-purple-600 px-4 py-2.5 text-sm font-medium text-white shadow-md hover:opacity-90 transition-opacity disabled:opacity-40 disabled:cursor-not-allowed"
			disabled={carregandoBusca || termoBusca.trim().length < 2}
		>
			{carregandoBusca ? 'Buscando...' : 'Buscar'}
		</button>
	</form>

	{#if erroBusca}
		<p class="text-sm text-red-400">{erroBusca}</p>
	{/if}

	<div class="grid grid-cols-1 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1.8fr)] gap-4">
		<!-- Lista de resultados -->
		<div class="space-y-2">
			<h2 class="text-sm font-semibold text-white/80 mb-1">Resultados</h2>
			{#if resultados.length === 0 && !carregandoBusca && termoBusca.trim().length >= 2}
				<p class="text-xs text-white/50">Nenhuma disciplina encontrada para esse termo.</p>
			{/if}
			<div class="space-y-1.5 max-h-[320px] overflow-y-auto pr-1">
				{#each resultados as m}
					<button
						type="button"
						onclick={() => carregarDetalhes(m)}
						class="w-full rounded-lg border px-3 py-2 text-left text-xs sm:text-sm transition-colors {selecionada && selecionada.id_materia === m.id_materia
							? 'border-pink-400/60 bg-pink-500/10 text-white'
							: 'border-white/10 bg-black/30 text-white/80 hover:bg-black/50'}"
					>
						<p class="font-semibold text-white">{m.codigo_materia}</p>
						<p class="truncate">{m.nome_materia}</p>
					</button>
				{/each}
			</div>
		</div>

		<!-- Detalhes -->
		<div class="space-y-3">
			<h2 class="text-sm font-semibold text-white/80 mb-1">Detalhes</h2>
			{#if !selecionada}
				<p class="text-xs text-white/50">Selecione uma disciplina na lista para ver pré-requisitos e equivalências.</p>
			{:else}
				<div class="rounded-2xl border border-white/15 bg-gradient-to-br from-black/60 via-slate-950/80 to-slate-900/80 p-3 sm:p-4 space-y-3 shadow-[0_18px_45px_rgba(0,0,0,0.65)]">
					<div class="flex items-start justify-between gap-2">
						<div>
							<p class="text-[11px] uppercase tracking-[0.18em] text-pink-300/80 mb-0.5">
								Disciplina selecionada
							</p>
							<p class="text-sm sm:text-base font-semibold text-white">
								{selecionada.codigo_materia} · {selecionada.nome_materia}
							</p>
						</div>
					</div>

					{#if erroDetalhes}
						<p class="text-xs text-red-400">{erroDetalhes}</p>
					{/if}

					<!-- Pré-requisitos -->
					<div class="space-y-1.5">
						<h3 class="flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wide text-sky-200">
							<span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-sky-500/20 border border-sky-400/60 text-[9px] text-sky-100 shadow-sm">
								PR
							</span>
							Pré-requisitos
						</h3>
						{#if carregandoDetalhes}
							<p class="text-xs text-white/50">Carregando pré-requisitos...</p>
						{:else if prereqs.length === 0}
							<p class="text-xs text-white/50">Nenhum pré-requisito registrado.</p>
						{:else}
							{#each prereqs as pr}
								<div class="rounded-xl border border-sky-400/20 bg-sky-500/5 px-3 py-2.5 space-y-1.5">
									{#if pr.expressao_original}
										<div class="inline-flex items-center gap-1 rounded-full bg-sky-500/20 px-2 py-0.5 mb-1">
											<span class="h-1.5 w-1.5 rounded-full bg-sky-300"></span>
											<p class="text-[10px] font-semibold uppercase tracking-wide text-sky-100">
												Expressão de pré‑requisito
											</p>
										</div>
										<p class="text-xs text-sky-50/90 mb-1">{pr.expressao_original}</p>
									{/if}

									{#if codigosDaExpressao(pr.expressao_logica).length > 0}
										<p class="text-[11px] font-semibold text-sky-100 mt-1">Matérias na expressão</p>
										<div class="flex flex-wrap gap-1.5 mt-0.5">
											{#each codigosDaExpressao(pr.expressao_logica) as c}
												{@const key = c.trim().toUpperCase()}
												{@const mat = materiasExtras.get(key)}
												<span class="inline-flex items-center gap-1 rounded-full bg-sky-500/15 border border-sky-400/40 px-2.5 py-0.5 text-[10px] text-sky-50">
													<span class="h-1.5 w-1.5 rounded-full bg-sky-300"></span>
													{c}{mat ? ` · ${mat.nome_materia}` : ''}
												</span>
											{/each}
										</div>
									{:else if pr.codigo_requisito}
										<p class="text-[11px] font-semibold text-sky-100 mt-1">Matéria requerida</p>
										<p class="text-xs text-sky-50/90">
											{pr.codigo_requisito} · {pr.nome_requisito}
										</p>
									{/if}
								</div>
							{/each}
						{/if}
					</div>

					<!-- Equivalências -->
					<div class="space-y-1.5">
						<h3 class="flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wide text-emerald-200">
							<span class="inline-flex h-5 w-5 items-center justify-center rounded-full bg-emerald-500/20 border border-emerald-400/60 text-[9px] text-emerald-50 shadow-sm">
								EQ
							</span>
							Equivalências
						</h3>
						{#if carregandoDetalhes}
							<p class="text-xs text-white/50">Carregando equivalências...</p>
						{:else if equivs.length === 0}
							<p class="text-xs text-white/50">Nenhuma equivalência registrada.</p>
						{:else}
							{#each equivs as eq}
								<div class="rounded-xl border border-emerald-400/25 bg-emerald-500/5 px-3 py-2.5 space-y-1.5">
									<p class="text-xs text-emerald-50/95">
										Disciplina: {eq.codigo_materia_origem} · {eq.nome_materia_origem}
									</p>
									{#if eq.curriculo}
										<p class="inline-flex items-center gap-1.5 rounded-full bg-amber-500/15 border border-amber-300/60 px-2.5 py-0.5 text-[10px] text-amber-100 mt-0.5">
											<span class="h-1.5 w-1.5 rounded-full bg-amber-300"></span>
											Currículo específico: {eq.curriculo}
										</p>
									{/if}
									{#if eq.expressao_original}
										<div class="inline-flex items-center gap-1 rounded-full bg-emerald-500/20 px-2 py-0.5 mt-1">
											<span class="h-1.5 w-1.5 rounded-full bg-emerald-300"></span>
											<p class="text-[10px] font-semibold uppercase tracking-wide text-emerald-50">
												Expressão de equivalência
											</p>
										</div>
										<p class="text-xs text-emerald-50/90 mb-1">{eq.expressao_original}</p>
									{/if}

									{#if codigosDaExpressao(eq.expressao_logica).length > 0}
										<p class="text-[11px] font-semibold text-emerald-100 mt-1">Matérias na equivalência</p>
										<div class="flex flex-wrap gap-1.5 mt-0.5">
											{#each codigosDaExpressao(eq.expressao_logica) as c}
												{@const key = c.trim().toUpperCase()}
												{@const mat = materiasExtras.get(key)}
												<span class="inline-flex items-center gap-1 rounded-full bg-emerald-500/15 border border-emerald-400/40 px-2.5 py-0.5 text-[10px] text-emerald-50">
													<span class="h-1.5 w-1.5 rounded-full bg-emerald-300"></span>
													{c}{mat ? ` · ${mat.nome_materia}` : ''}
												</span>
											{/each}
										</div>
									{/if}
								</div>
							{/each}
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

