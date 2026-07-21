<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
	import ScheduleGrid from '$lib/components/planejamento/ScheduleGrid.svelte';
	import SubjectTurmaSelector from '$lib/components/planejamento/SubjectTurmaSelector.svelte';
	import MateriaSearchAdd from '$lib/components/planejamento/MateriaSearchAdd.svelte';
	import GradeResumo from '$lib/components/planejamento/GradeResumo.svelte';
	import CenarioSwitcher from '$lib/components/planejamento/CenarioSwitcher.svelte';
	import TrocarTurmaDialog from '$lib/components/planejamento/TrocarTurmaDialog.svelte';
	import AssistenteChatFab from '$lib/components/planejamento/AssistenteChatFab.svelte';
	import { authStore } from '$lib/stores/auth';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import {
		gradeStore,
		lerPoolSalvo,
		lerRemovidasSalvo,
		slotMaskFromHorario,
		type MateriaGrade
	} from '$lib/stores/grade.store.svelte';
	import type { Turno } from '$lib/utils/horario-slots';
	import { vagaAssinaturasStore } from '$lib/stores/vaga-assinaturas.store.svelte';
	import { getPeriodoAtivo, getTurmasPorMaterias, type TurmaOferta } from '$lib/services/turmas.service';
	import { getMateriasByCodigos } from '$lib/services/materias.service';
	import { satisfazPreRequisitos } from '$lib/types/curso';
	import { setHasCodeIgnoreCase } from '$lib/utils/subject-codes';
	import { ROUTES } from '$lib/config/routes';
	import type { SemestrePlano, ItemSemestre, MateriaPlano } from '$lib/types/plano-formatura';
	import { CalendarDays, Wand2, Trash2, Loader2, Info, Download, Star } from 'lucide-svelte';

	let status = $state<'loading' | 'ready' | 'error'>('loading');
	let erro = $state<string | null>(null);
	let periodo = $state<string | null>(null);
	let semestreLabel = $state<string | null>(null);
	let materiaDialog = $state<string | null>(null);
	let avisoAdd = $state<string | null>(null);

	function isMateriaPlano(item: ItemSemestre): item is MateriaPlano {
		return 'codigo' in item;
	}

	function extrairRecomendado(): SemestrePlano | null {
		const p = planoFormaturaStore.plano as { plano?: SemestrePlano[] } | null;
		const semestres = p?.plano ?? [];
		return (
			semestres.find((s) => s.tipo === 'recomendado') ??
			semestres.find((s) => s.tipo !== 'em_curso') ??
			semestres[0] ??
			null
		);
	}

	/**
	 * Requisitos da matéria a partir do courseData: aviso de pré-requisito pendente
	 * (não bloqueia) e lista de co-requisitos. Só resolve p/ matérias da matriz —
	 * optativas de fora não têm essas regras no courseData e passam sem aviso.
	 */
	function calcularRequisitos(idMateria: number): {
		avisoPreRequisito: string | null;
		coRequisitos: string[];
	} {
		const curso = fluxogramaStore.state.courseData;
		const completed = fluxogramaStore.completedCodes;
		const current = fluxogramaStore.currentCodes ?? new Set<string>();

		const prereqs = (curso?.preRequisitos ?? []).filter((pr) => pr.idMateria === idMateria);
		let avisoPreRequisito: string | null = null;
		if (prereqs.length > 0 && !satisfazPreRequisitos(prereqs, completed)) {
			const partes = new Set<string>();
			for (const pr of prereqs) {
				const code = pr.codigoMateriaRequisito?.trim();
				if (code) {
					if (!setHasCodeIgnoreCase(completed, code)) partes.add(code);
				} else if (pr.expressaoOriginal?.trim()) {
					partes.add(pr.expressaoOriginal.trim());
				}
			}
			avisoPreRequisito = partes.size > 0 ? [...partes].slice(0, 3).join(' · ') : 'requisitos não cumpridos';
		}

		const coRequisitos = [
			...new Set(
				(curso?.coRequisitos ?? [])
					.filter((cr) => cr.idMateria === idMateria)
					.map((cr) => cr.codigoMateriaCoRequisito?.trim())
					.filter((c): c is string => !!c && !setHasCodeIgnoreCase(completed, c) && !current.has(c))
			)
		];

		return { avisoPreRequisito, coRequisitos };
	}

	/** Resolve códigos → matéria + turmas (courseData primeiro; senão banco). */
	async function construirMaterias(codigos: string[], per: string): Promise<MateriaGrade[]> {
		const cods = [...new Set(codigos.map((c) => c.trim().toUpperCase()).filter(Boolean))];
		if (cods.length === 0) return [];

		const courseMap = new Map(
			(fluxogramaStore.state.courseData?.materias ?? []).map((m) => [
				m.codigoMateria.trim().toUpperCase(),
				m
			])
		);

		const resolved = new Map<string, { idMateria: number; nome: string; creditos: number }>();
		const faltantes: string[] = [];
		for (const c of cods) {
			const mm = courseMap.get(c);
			if (mm) resolved.set(c, { idMateria: mm.idMateria, nome: mm.nomeMateria, creditos: mm.creditos });
			else faltantes.push(c);
		}
		if (faltantes.length > 0) {
			const extra = await getMateriasByCodigos(faltantes);
			for (const e of extra) {
				resolved.set(e.codigo.trim().toUpperCase(), {
					idMateria: e.idMateria,
					nome: e.nome,
					creditos: e.creditos
				});
			}
		}

		const ids = [...resolved.values()].map((r) => r.idMateria);
		const turmas = await getTurmasPorMaterias(ids, per);
		const porMateria = new Map<number, TurmaOferta[]>();
		for (const t of turmas) {
			const l = porMateria.get(t.id_materia) ?? [];
			l.push(t);
			porMateria.set(t.id_materia, l);
		}

		const out: MateriaGrade[] = [];
		for (const [codigo, r] of resolved) {
			const { avisoPreRequisito, coRequisitos } = calcularRequisitos(r.idMateria);
			out.push({
				codigo,
				nome: r.nome,
				creditos: r.creditos,
				idMateria: r.idMateria,
				avisoPreRequisito,
				coRequisitos,
				turmas: (porMateria.get(r.idMateria) ?? []).map((t) => ({
					turma: t,
					mask: slotMaskFromHorario(t.horario)
				}))
			});
		}
		return out;
	}

	async function montar(): Promise<void> {
		status = 'loading';
		erro = null;
		try {
			if (!fluxogramaStore.state.courseData) {
				const matriz = authStore.getUser()?.dadosFluxograma?.matrizCurricular ?? null;
				if (!matriz) {
					goto(ROUTES.UPLOAD_HISTORICO);
					return;
				}
				await fluxogramaStore.loadCourseDataByCurriculoCompleto(matriz);
			}

			await planoFormaturaStore.loadPreferencias();
			if (!planoFormaturaStore.plano) await planoFormaturaStore.gerar();

			const recomendado = extrairRecomendado();
			semestreLabel = recomendado?.semestre ?? null;
			const recomendadoCodigos = recomendado
				? recomendado.materias.filter(isMateriaPlano).map((m) => m.codigo)
				: [];

			const idUser = authStore.getUser()?.idUser ?? null;
			periodo = await getPeriodoAtivo();
			const salvos = lerPoolSalvo(idUser, periodo);
			const removidas = new Set(lerRemovidasSalvo(idUser, periodo));
			// Salvos vêm primeiro (não re-adiciona removidas); recomendado só o que não foi removido.
			const todos = [...new Set([...salvos, ...recomendadoCodigos])].filter((c) => !removidas.has(c));

			const pool = await construirMaterias(todos, periodo);
			gradeStore.init(pool, { idUser, periodo });
			status = 'ready';
			// Carrega assinaturas de vaga em background (habilita "seguir turma lotada").
			void vagaAssinaturasStore.load();
		} catch (e) {
			erro = e instanceof Error ? e.message : 'Erro ao montar a grade.';
			status = 'error';
		}
	}

	onMount(montar);

	const limiteCreditos = $derived(planoFormaturaStore.preferencias?.limiteCreditos ?? 24);
	const creditosPct = $derived(
		limiteCreditos > 0 ? Math.min(100, (gradeStore.creditosSelecionados / limiteCreditos) * 100) : 0
	);
	const creditosAcima = $derived(gradeStore.creditosSelecionados > limiteCreditos);

	let exportando = $state(false);
	async function exportarGrade(): Promise<void> {
		if (exportando) return;
		const el = document.getElementById('grade-export');
		if (!el) return;
		exportando = true;
		try {
			const html2canvas = (await import('html2canvas-pro')).default;
			const canvas = await html2canvas(el, { backgroundColor: '#0a0a0a', scale: 2, logging: false });
			const link = document.createElement('a');
			link.download = `grade-${(periodo ?? '').replace('.', '-')}.png`;
			link.href = canvas.toDataURL('image/png');
			link.click();
		} catch {
			avisoAdd = 'Não foi possível exportar a imagem.';
		} finally {
			exportando = false;
		}
	}

	async function adicionarAoPool(codigo: string): Promise<void> {
		avisoAdd = null;
		const c = codigo.trim().toUpperCase();
		if (!periodo) return;
		if (gradeStore.hasMateria(c)) return;
		try {
			const [m] = await construirMaterias([c], periodo);
			if (m) {
				gradeStore.addMateriaAoPool(m);
			} else {
				avisoAdd = `Não encontrei a matéria ${c}.`;
			}
		} catch {
			avisoAdd = `Erro ao adicionar ${c}.`;
		}
	}

	/**
	 * Ação vinda do chat ([MONTAR_GRADE|...]): garante as matérias no pool, marca-as
	 * como prioritárias e rearranja — mantendo as demais que couberem sem conflito.
	 */
	async function montarGradeComPrioridade(codigos: string[], turnos?: string[]): Promise<void> {
		if (turnos && turnos.length > 0) gradeStore.setTurnos(turnos);
		for (const raw of codigos) {
			const c = raw.trim().toUpperCase();
			if (!c) continue;
			await adicionarAoPool(c);
			if (gradeStore.hasMateria(c) && !gradeStore.isPrioritaria(c)) {
				gradeStore.togglePrioridade(c);
			}
		}
		gradeStore.montarAutomatico();
	}

	const TURNO_OPCOES: ReadonlyArray<[Turno, string]> = [
		['M', 'Manhã'],
		['T', 'Tarde'],
		['N', 'Noite']
	];
</script>

<PageMeta
	title="Montador de Grade | NoFluxo UNB"
	description="Monte e simule sua grade horária do próximo semestre sem conflito de horário."
	noIndex={true}
/>

<PageBackground />

<div class="relative z-10 mx-auto w-full max-w-7xl px-3 py-4 sm:px-5">
	<!-- Cabeçalho -->
	<header class="mb-3 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between">
		<div class="flex items-center gap-2.5">
			<CalendarDays class="h-6 w-6 shrink-0 text-purple-300" />
			<div>
				<h1 class="text-lg font-bold text-white sm:text-xl">Montador de Grade</h1>
				<p class="text-xs text-white/50">
					Próximo semestre{#if semestreLabel} · <span class="font-semibold text-white/70">{semestreLabel}</span>{/if}
					{#if periodo} · turmas de <span class="font-mono">{periodo}</span>{/if}
				</p>
			</div>
		</div>

		{#if status === 'ready'}
			<div class="flex w-full flex-wrap items-center gap-2 sm:w-auto">
				<div
					class="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1"
					title="Créditos selecionados vs. seu limite por semestre"
				>
					<span class="text-xs {creditosAcima ? 'font-semibold text-red-300' : 'text-white/70'}">
						{gradeStore.creditosSelecionados}/{limiteCreditos} cr
					</span>
					<span class="h-1.5 w-16 overflow-hidden rounded-full bg-white/10">
						<span
							class="block h-full rounded-full transition-all {creditosAcima ? 'bg-red-400' : creditosPct > 85 ? 'bg-amber-400' : 'bg-emerald-400'}"
							style="width: {creditosPct}%"
						></span>
					</span>
				</div>
				<div
					class="flex items-center gap-0.5 rounded-full border border-white/10 bg-white/5 p-0.5"
					title="Turnos permitidos ao rearranjar"
				>
					{#each TURNO_OPCOES as [t, label] (t)}
						{@const ativo = gradeStore.turnosPermitidos.has(t)}
						<button
							type="button"
							onclick={() => gradeStore.toggleTurno(t)}
							aria-pressed={ativo}
							class="rounded-full px-2.5 py-1 text-[11px] font-medium transition-colors {ativo
								? 'bg-purple-500/25 text-purple-100'
								: 'text-white/40 hover:text-white/70'}"
						>
							{label}
						</button>
					{/each}
				</div>
				<button
					type="button"
					onclick={() => gradeStore.montarAutomatico()}
					title={gradeStore.temPrioritarias
						? 'Rearranja sem conflito priorizando as matérias com estrela'
						: 'Monta uma grade sem conflito. Marque matérias com estrela para priorizá-las.'}
					class="inline-flex items-center gap-1.5 rounded-full border border-purple-300/45 bg-purple-500/18 px-3 py-1.5 text-xs font-semibold text-purple-100 transition-colors hover:bg-purple-500/25"
				>
					<Wand2 class="h-3.5 w-3.5" /> Rearranjar
					{#if gradeStore.temPrioritarias}<Star class="h-3 w-3 fill-current text-amber-300" />{/if}
				</button>
				<button
					type="button"
					onclick={exportarGrade}
					disabled={exportando || gradeStore.selecao.size === 0}
					class="inline-flex items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/70 transition-colors hover:bg-white/10 disabled:opacity-40"
				>
					{#if exportando}<Loader2 class="h-3.5 w-3.5 animate-spin" />{:else}<Download class="h-3.5 w-3.5" />{/if} Exportar
				</button>
				<button
					type="button"
					onclick={() => gradeStore.limpar()}
					class="inline-flex items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/70 transition-colors hover:bg-white/10"
				>
					<Trash2 class="h-3.5 w-3.5" /> Limpar
				</button>
			</div>
		{/if}
	</header>

	{#if status === 'ready'}
		<div class="mb-3">
			<CenarioSwitcher />
		</div>
	{/if}

	{#if gradeStore.ultimaMontagem && gradeStore.ultimaMontagem.naoAlocadas.length > 0}
		<div class="mb-3 flex items-start gap-2 rounded-xl border border-amber-300/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-100">
			<Info class="mt-0.5 h-3.5 w-3.5 shrink-0" />
			<span>Não coube sem conflito: <strong>{gradeStore.ultimaMontagem.naoAlocadas.join(', ')}</strong>. Ajuste manualmente.</span>
		</div>
	{/if}

	{#if status === 'loading'}
		<div class="flex items-center justify-center gap-2 py-20 text-white/60">
			<Loader2 class="h-5 w-5 animate-spin" /> Carregando matérias e turmas...
		</div>
	{:else if status === 'error'}
		<div class="rounded-2xl border border-red-300/30 bg-red-500/10 px-4 py-6 text-center text-sm text-red-200">{erro}</div>
	{:else}
		<div class="grid gap-4 lg:grid-cols-[22rem_minmax(0,1fr)_18rem]">
			<!-- Coluna esquerda: matérias + busca -->
			<div class="order-2 space-y-3 lg:order-1 lg:sticky lg:top-24 lg:max-h-[calc(100dvh-9rem)] lg:overflow-y-auto lg:pr-0.5">
				<MateriaSearchAdd onAdd={adicionarAoPool} />
				{#if avisoAdd}
					<p class="rounded-lg border border-amber-300/30 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-100">{avisoAdd}</p>
				{/if}
				{#if gradeStore.pool.length === 0}
					<p class="rounded-2xl border border-white/10 bg-zinc-950/78 px-3 py-6 text-center text-xs text-white/50">
						Busque matérias acima ou peça recomendações ao assistente (botão flutuante).
					</p>
				{:else}
					<SubjectTurmaSelector />
				{/if}
			</div>

			<!-- Centro: calendário -->
			<div class="order-1 lg:order-2">
				<ScheduleGrid onBlocoClick={(codigo) => (materiaDialog = codigo)} />
			</div>

			<!-- Direita: resumo -->
			<div class="order-3">
				<GradeResumo />
			</div>
		</div>
	{/if}
</div>

<TrocarTurmaDialog codigo={materiaDialog} onClose={() => (materiaDialog = null)} />

<!-- Chatbot flutuante (Darcy) — recomenda optativas com turma e insere na grade -->
{#if status === 'ready'}
	<AssistenteChatFab onAddToGrade={adicionarAoPool} onMontarGrade={montarGradeComPrioridade} />
{/if}
