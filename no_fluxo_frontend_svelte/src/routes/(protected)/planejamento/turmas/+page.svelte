<script lang="ts">
	import { onMount } from 'svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import { searchTurmas, getPeriodoAtivo, type TurmaComMateria } from '$lib/services/turmas.service';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';
	import { formatHorarioSigaa, compactarFaixasHorarias, formatLocalCompacto } from '$lib/utils/sigaa';
	import { Search, Loader2, CalendarClock, MapPin, Users, Bell, BellOff, X } from 'lucide-svelte';

	let termo = $state('');
	let resultados = $state<TurmaComMateria[]>([]);
	let buscando = $state(false);
	let erro = $state<string | null>(null);
	let periodo = $state<string | null>(null);
	/** Termo que gerou os resultados atuais — evita mostrar "nada encontrado" antes da 1ª busca. */
	let termoBuscado = $state('');

	onMount(() => {
		void getPeriodoAtivo()
			.then((p) => (periodo = p))
			.catch(() => (periodo = null));
		if (!vagaAssinaturasStore.carregado) void vagaAssinaturasStore.load();
	});

	// Debounce: a busca dispara sozinha enquanto o aluno digita, mas só depois da pausa.
	let debounce: ReturnType<typeof setTimeout> | null = null;
	let buscaEmVoo = 0;

	function aoDigitar(valor: string): void {
		termo = valor;
		if (debounce) clearTimeout(debounce);
		if (valor.trim().length < 2) {
			resultados = [];
			termoBuscado = '';
			erro = null;
			buscando = false;
			return;
		}
		buscando = true;
		debounce = setTimeout(() => void buscar(valor), 350);
	}

	async function buscar(valor: string): Promise<void> {
		// Respostas fora de ordem não podem sobrescrever uma busca mais nova.
		const chamada = ++buscaEmVoo;
		erro = null;
		try {
			const achados = await searchTurmas(valor);
			if (chamada !== buscaEmVoo) return;
			resultados = achados;
			termoBuscado = valor.trim();
		} catch (e) {
			if (chamada !== buscaEmVoo) return;
			erro = e instanceof Error ? e.message : 'Erro ao buscar turmas.';
			resultados = [];
		} finally {
			if (chamada === buscaEmVoo) buscando = false;
		}
	}

	function limpar(): void {
		if (debounce) clearTimeout(debounce);
		termo = '';
		termoBuscado = '';
		resultados = [];
		erro = null;
		buscando = false;
	}

	/** Resultados agrupados por matéria, preservando a ordem já vinda do serviço. */
	const porMateria = $derived.by(() => {
		const grupos = new Map<string, { codigo: string; nome: string; turmas: TurmaComMateria[] }>();
		for (const t of resultados) {
			const g = grupos.get(t.codigoMateria) ?? {
				codigo: t.codigoMateria,
				nome: t.nomeMateria,
				turmas: []
			};
			g.turmas.push(t);
			grupos.set(t.codigoMateria, g);
		}
		return [...grupos.values()];
	});

	function horarioLegivel(horario: string | null): string {
		const linhas = formatHorarioSigaa(horario ?? '');
		if (linhas.length === 0) return 'Horário a definir';
		return linhas.map((l) => `${l.dia} ${compactarFaixasHorarias(l.faixas)}`).join(' · ');
	}
</script>

<PageMeta
	title="Buscar turmas | NoFluxo UNB"
	description="Busque na oferta do semestre por professor, horário, sala ou matéria."
	noIndex={true}
/>

<PageBackground />

<div class="relative z-10 mx-auto w-full max-w-4xl px-3 py-5 sm:px-5 sm:py-6">
	<header class="mb-4">
		<div class="flex items-center gap-2.5">
			<Search class="h-6 w-6 shrink-0 text-purple-300" />
			<div>
				<h1 class="text-lg font-bold text-white sm:text-xl">Buscar turmas</h1>
				<p class="text-xs text-white/50">
					Procure na oferta inteira{#if periodo} de <span class="font-mono">{periodo}</span>{/if} por
					professor, horário, sala ou matéria.
				</p>
			</div>
		</div>
	</header>

	<div class="relative mb-4">
		<Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/30" />
		<input
			type="search"
			value={termo}
			oninput={(e) => aoDigitar((e.currentTarget as HTMLInputElement).value)}
			placeholder="Ex.: nome do professor, 2M34, CIC0004, ICC ANF"
			aria-label="Buscar turmas por professor, horário, sala ou matéria"
			class="w-full rounded-2xl border border-white/12 bg-zinc-950/78 py-3 pl-10 pr-10 text-sm text-white placeholder:text-white/25 focus:border-purple-300/45 focus:outline-none focus:ring-1 focus:ring-purple-400/30"
		/>
		{#if termo}
			<button
				type="button"
				onclick={limpar}
				aria-label="Limpar busca"
				class="absolute right-2.5 top-1/2 -translate-y-1/2 touch-manipulation rounded-lg p-1.5 text-white/35 transition-colors hover:bg-white/10 hover:text-white/70"
			>
				<X class="h-4 w-4" />
			</button>
		{/if}
	</div>

	{#if buscando}
		<p class="flex items-center justify-center gap-2 py-10 text-sm text-white/55">
			<Loader2 class="h-4 w-4 animate-spin" /> Procurando na oferta...
		</p>
	{:else if erro}
		<p class="rounded-2xl border border-red-300/30 bg-red-500/10 px-4 py-5 text-center text-sm text-red-200">
			{erro}
		</p>
	{:else if termo.trim().length > 0 && termo.trim().length < 2}
		<p class="py-10 text-center text-xs text-white/35">Digite pelo menos 2 caracteres.</p>
	{:else if termoBuscado && resultados.length === 0}
		<p class="py-10 text-center text-sm text-white/45">
			Nada encontrado para <strong class="text-white/70">{termoBuscado}</strong> na oferta atual.
		</p>
	{:else if resultados.length > 0}
		<p class="mb-2 text-[11px] text-white/35">
			{resultados.length} turma(s) em {porMateria.length} matéria(s)
		</p>
		<div class="space-y-3">
			{#each porMateria as grupo (grupo.codigo)}
				<section class="rounded-2xl border border-white/10 bg-zinc-950/78 p-3 sm:p-4">
					<header class="mb-2.5 border-b border-white/10 pb-2">
						<p class="flex flex-wrap items-baseline gap-x-2">
							<span class="font-mono text-sm font-semibold text-purple-200">{grupo.codigo}</span>
							<span class="text-xs text-white/60">{grupo.nome}</span>
						</p>
					</header>
					<div class="space-y-2">
						{#each grupo.turmas as t (t.id_turmas)}
							{@const local = formatLocalCompacto(t.local)}
							{@const lotada = t.vagas_sobrando != null && t.vagas_sobrando <= 0}
							{@const seguindo = vagaAssinaturasStore.isSeguindo(t.id_materia, t.turma, t.ano_periodo)}
							{@const seguirBusy = vagaAssinaturasStore.isBusy(t.id_materia, t.turma, t.ano_periodo)}
							<div class="rounded-xl border border-white/10 bg-black/25 px-3 py-2.5">
								<div class="flex flex-wrap items-center justify-between gap-2">
									<span class="font-mono text-xs font-semibold text-white/90">Turma {t.turma}</span>
									{#if t.vagas_sobrando != null}
										<span
											class="inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-semibold {lotada
												? 'border-red-300/40 bg-red-500/15 text-red-200'
												: 'border-emerald-300/45 bg-emerald-500/18 text-emerald-100'}"
										>
											<Users class="h-2.5 w-2.5" />
											{lotada ? 'Sem vagas' : `${t.vagas_sobrando} vaga(s)`}
										</span>
									{/if}
								</div>
								<p class="mt-1 truncate text-[11px] text-white/65">
									{t.docente ?? 'Docente não informado'}
								</p>
								<p class="mt-0.5 flex flex-wrap items-center gap-x-2.5 gap-y-0.5 text-[11px] text-white/45">
									<span class="inline-flex items-center gap-1">
										<CalendarClock class="h-3 w-3 shrink-0" />{horarioLegivel(t.horario)}
									</span>
									{#if local}
										<span class="inline-flex items-center gap-1">
											<MapPin class="h-3 w-3 shrink-0" />{local}
										</span>
									{/if}
								</p>
								{#if lotada && vagaAssinaturasStore.carregado}
									<button
										type="button"
										disabled={seguirBusy}
										onclick={() => vagaAssinaturasStore.toggle(t.id_materia, t.turma, t.ano_periodo)}
										class="mt-2 inline-flex touch-manipulation items-center gap-1.5 rounded-full border px-2.5 py-1 text-[10px] font-medium transition-colors disabled:opacity-50 {seguindo
											? 'border-purple-300/45 bg-purple-500/18 text-purple-100 hover:bg-purple-500/25'
											: 'border-white/15 bg-white/5 text-white/60 hover:bg-white/10'}"
									>
										{#if seguirBusy}
											<Loader2 class="h-3 w-3 animate-spin" />
										{:else if seguindo}
											<Bell class="h-3 w-3" />
										{:else}
											<BellOff class="h-3 w-3" />
										{/if}
										{seguindo ? 'Seguindo — aviso quando abrir vaga' : 'Avisar quando abrir vaga'}
									</button>
								{/if}
							</div>
						{/each}
					</div>
				</section>
			{/each}
		</div>
	{:else}
		<div class="rounded-2xl border border-white/10 bg-zinc-950/78 px-4 py-8 text-center">
			<p class="text-sm text-white/50">Busque na oferta do semestre.</p>
			<p class="mx-auto mt-2 max-w-md text-xs leading-relaxed text-white/35">
				Dá para procurar pelo nome de um professor e ver tudo que ele dá, por um horário SIGAA
				(<span class="font-mono">2M34</span>), pela sala, ou pelo código/nome da matéria.
			</p>
		</div>
	{/if}
</div>
