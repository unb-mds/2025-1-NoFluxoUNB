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
	import { getPeriodoAtivo } from '$lib/services/turmas.service';
	import { getMateriasByCodigos } from '$lib/services/materias.service';
	import { getOfertaComEquivalencia } from '$lib/services/oferta-turmas.service';
	import { satisfazPreRequisitos } from '$lib/types/curso';
	import { setHasCodeIgnoreCase, filtrarNaoCursados } from '$lib/utils/subject-codes';
	import { ROUTES } from '$lib/config/routes';
	import type { SemestrePlano, ItemSemestre, MateriaPlano } from '$lib/types/plano-formatura';
	import {
		CalendarDays,
		Wand2,
		Trash2,
		Loader2,
		Info,
		Download,
		Star,
		Search,
		Compass,
		Maximize2,
		Minimize2
	} from 'lucide-svelte';
	import OnboardingTour from '$lib/components/onboarding/OnboardingTour.svelte';
	import HelpTip from '$lib/components/onboarding/HelpTip.svelte';
	import { tourStore, type TourStep } from '$lib/components/onboarding/tour.store.svelte';

	// Feature em rollout gradual: só admins veem o Montador de Grade de verdade
	// por enquanto; usuários normais veem um aviso de "em breve" e nem chegam a
	// disparar o carregamento de curso/plano/turmas (evita trabalho à toa).
	const isAdmin = $derived(authStore.getUser()?.isAdmin ?? false);

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

		// Equivalência (matéria que mudou de código) resolvida no serviço compartilhado —
		// mesma regra que a aba Turmas do fluxograma e o painel de /disciplinas usam.
		const ofertaPorCodigo = await getOfertaComEquivalencia(
			[...resolved].map(([codigo, r]) => ({ codigo, idMateria: r.idMateria })),
			fluxogramaStore.state.courseData?.equivalencias ?? [],
			per
		);

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
				turmas: (ofertaPorCodigo.get(codigo) ?? []).map(({ turma, codigoOfertado }) => ({
					turma,
					mask: slotMaskFromHorario(turma.horario),
					codigoOfertado
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
			// O filtro de já-cursadas vale também para os `salvos`: matéria concluída depois de
			// ter entrado no pool some sozinha no próximo carregamento, sem o aluno ter que remover.
			const todos = filtrarNaoCursados(
				[...new Set([...salvos, ...recomendadoCodigos])].filter((c) => !removidas.has(c)),
				fluxogramaStore.completedCodes,
				fluxogramaStore.currentCodes ?? new Set<string>()
			);

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

	onMount(() => {
		if (isAdmin) void montar();
	});

	const limiteCreditos = $derived(planoFormaturaStore.preferencias?.limiteCreditos ?? 24);
	const creditosPct = $derived(
		limiteCreditos > 0 ? Math.min(100, (gradeStore.creditosSelecionados / limiteCreditos) * 100) : 0
	);
	const creditosAcima = $derived(gradeStore.creditosSelecionados > limiteCreditos);

	// Calendário em tela cheia (só faz diferença no desktop; no mobile já é 1 coluna).
	let calendarioExpandido = $state(false);

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
		// Avisa em vez de adicionar em silêncio: o aluno pode estar buscando pelo nome e
		// não perceber que é a mesma matéria que já cursou (ou que está cursando agora).
		if (setHasCodeIgnoreCase(fluxogramaStore.completedCodes, c)) {
			avisoAdd = `Você já foi aprovado em ${c}.`;
			return;
		}
		if (setHasCodeIgnoreCase(fluxogramaStore.currentCodes ?? new Set<string>(), c)) {
			avisoAdd = `Você já está cursando ${c} neste semestre.`;
			return;
		}
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

	// ---------------------------------------------------------------------------
	// Onboarding guiado
	// ---------------------------------------------------------------------------
	const TOUR_ID = 'montador-grade-v1';

	// 7 passos: só o caminho crítico (achar → turma → calendário → rearranjar →
	// exportar → IA). Turnos, créditos e modos de visualização são secundários e
	// já têm HelpTip permanente ao lado do próprio controle.
	const TOUR_STEPS: TourStep[] = [
		{
			title: 'Bem-vindo ao Montador de Grade 👋',
			description:
				'Em 1 minuto você monta a grade do próximo semestre sem conflito de horário. Já deixamos as matérias recomendadas pelo seu plano na lista — é só escolher as turmas.',
			hint: 'Dá pra navegar com as setas ← → do teclado e sair com Esc.'
		},
		{
			target: 'buscar-materia',
			side: 'right',
			title: '1. Ache a matéria',
			description:
				'Digite o código (ex.: CIC0004) ou parte do nome e clique no resultado para jogar a matéria na sua lista. Só aparecem matérias da sua matriz que você ainda não cursou.',
			hint: 'Quer algo fora da matriz? Use “Buscar turmas”, no topo da página.'
		},
		{
			target: 'escolher-turma',
			side: 'right',
			title: '2. Escolha a turma',
			description:
				'Cada matéria mostra as turmas ofertadas com professor, horário e vagas. Clique numa turma para colocá-la na grade — clicar de novo tira. A estrela marca a matéria como prioritária.',
			hint: 'Turma lotada? Dá pra seguir a turma e ser avisado quando abrir vaga.'
		},
		{
			target: 'calendario',
			side: 'left',
			title: '3. Veja sua semana',
			description:
				'As turmas escolhidas viram blocos coloridos aqui. Conflito de horário aparece destacado na hora, então não tem como se matricular em duas aulas no mesmo slot sem perceber.',
			hint: 'Clique num bloco para trocar a turma; os controles abaixo do calendário mudam a visualização.'
		},
		{
			target: 'rearranjar',
			side: 'bottom',
			title: 'Deixe o automático resolver',
			description:
				'“Rearranjar” testa as combinações e encaixa o máximo de matérias sem conflito, respeitando os turnos que você deixar ligados ali ao lado e priorizando as marcadas com estrela. Se algo não couber, a gente avisa.'
		},
		{
			target: 'resumo',
			side: 'left',
			title: '4. Confira e exporte',
			description:
				'O resumo lista tudo que está na grade com turma e horário. Quando estiver do jeito que você quer, use “Exportar” para baixar a grade em imagem e levar pro dia da matrícula.',
			hint: 'O contador de créditos no topo compara sua seleção com o limite do seu plano.'
		},
		{
			target: 'assistente-ia',
			side: 'left',
			padding: 12,
			title: '✨ E tem a Darcy, nossa IA',
			description:
				'Peça em português: “optativas de redes à tarde com turma aberta” ou “monta minha grade sem aula de manhã”. Ela sugere só matérias com turma neste semestre e joga direto na sua grade.',
			hint: 'Reveja este passo a passo em “Como funciona”, no topo — e os “?” explicam cada controle.'
		}
	];

	function abrirTour(): void {
		tourStore.start(TOUR_ID, TOUR_STEPS);
	}

	// Primeira visita: abre sozinho, mas só depois que a grade carregou (senão os
	// alvos do spotlight ainda nem existem na tela).
	// Propositalmente NÃO é $state: escrever numa flag reativa aqui invalidaria o
	// próprio efeito, cujo cleanup cancelaria o timer antes de ele disparar.
	let tourAutoDisparado = false;
	$effect(() => {
		if (status !== 'ready' || tourAutoDisparado) return;
		tourAutoDisparado = true;
		const t = setTimeout(() => tourStore.startSeNovo(TOUR_ID, TOUR_STEPS), 500);
		return () => clearTimeout(t);
	});

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

{#if !isAdmin}
	<div class="relative z-10 mx-auto flex w-full max-w-2xl flex-col items-center px-4 py-24 text-center">
		<div
			class="mb-4 flex h-16 w-16 items-center justify-center rounded-3xl border border-purple-500/40 bg-purple-500/10 shadow-[0_0_30px_rgba(168,85,247,0.15)] backdrop-blur-md"
		>
			<CalendarDays class="h-8 w-8 text-purple-300" />
		</div>
		<h1 class="text-xl font-bold text-white sm:text-2xl">Montador de Grade</h1>
		<p class="mt-2 max-w-md text-sm leading-relaxed text-white/60">
			Em breve! Estamos finalizando essa funcionalidade — monte sua grade horária do próximo semestre sem conflito de horário.
		</p>
	</div>
{:else}
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
				<HelpTip
					side="bottom"
					title="Créditos do semestre"
					text="Soma dos créditos das turmas já escolhidas contra o limite do seu plano. A barra fica amarela perto do limite e vermelha se passar."
				>
					<div
						class="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1"
						data-tour="creditos"
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
				</HelpTip>
				<div
					class="flex items-center gap-0.5 rounded-full border border-white/10 bg-white/5 p-0.5"
					data-tour="turnos"
					title="Turnos permitidos ao rearranjar"
				>
					{#each TURNO_OPCOES as [t, label] (t)}
						{@const ativo = gradeStore.turnosPermitidos.has(t)}
						<button
							type="button"
							onclick={() => gradeStore.toggleTurno(t)}
							aria-pressed={ativo}
							class="touch-manipulation rounded-full px-2.5 py-1.5 text-[11px] font-medium transition-colors sm:py-1 {ativo
								? 'bg-purple-500/25 text-purple-100'
								: 'text-white/40 hover:text-white/70'}"
						>
							{label}
						</button>
					{/each}
				</div>
				<HelpTip
					side="bottom"
					title="Rearranjar (montagem automática)"
					text={gradeStore.temPrioritarias
						? 'Rearranja tudo sem conflito de horário, começando pelas matérias com estrela.'
						: 'Encaixa suas matérias sem conflito de horário, respeitando os turnos escolhidos. Marque estrela numa matéria para ela entrar primeiro.'}
				>
					<button
						type="button"
						onclick={() => gradeStore.montarAutomatico()}
						data-tour="rearranjar"
						class="inline-flex touch-manipulation items-center gap-1.5 rounded-full border border-purple-300/45 bg-purple-500/18 px-3 py-2 text-xs font-semibold text-purple-100 transition-colors hover:bg-purple-500/25 sm:py-1.5"
					>
						<Wand2 class="h-3.5 w-3.5" /> Rearranjar
						{#if gradeStore.temPrioritarias}<Star class="h-3 w-3 fill-current text-amber-300" />{/if}
					</button>
				</HelpTip>
				<HelpTip
					side="bottom"
					title="Exportar"
					text="Baixa a grade como imagem PNG — boa pra mandar no grupo do curso ou conferir na hora da matrícula."
				>
					<button
						type="button"
						onclick={exportarGrade}
						disabled={exportando || gradeStore.selecao.size === 0}
						data-tour="exportar"
						class="inline-flex touch-manipulation items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-3 py-2 text-xs font-medium text-white/70 transition-colors hover:bg-white/10 sm:py-1.5 disabled:opacity-40"
					>
						{#if exportando}<Loader2 class="h-3.5 w-3.5 animate-spin" />{:else}<Download class="h-3.5 w-3.5" />{/if} Exportar
					</button>
				</HelpTip>
				<HelpTip
					side="bottom"
					title="Buscar turmas"
					text="Procura na oferta inteira do semestre por professor, horário ou sala — inclusive matérias que não estão na sua matriz."
				>
					<a
						href={ROUTES.BUSCAR_TURMAS}
						class="inline-flex touch-manipulation items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-3 py-2 text-xs font-medium text-white/70 transition-colors hover:bg-white/10 sm:py-1.5"
					>
						<Search class="h-3.5 w-3.5" /> Buscar turmas
					</a>
				</HelpTip>
				<button
					type="button"
					onclick={() => gradeStore.limpar()}
					class="inline-flex touch-manipulation items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-3 py-2 text-xs font-medium text-white/70 transition-colors hover:bg-white/10 sm:py-1.5"
				>
					<Trash2 class="h-3.5 w-3.5" /> Limpar
				</button>
				<HelpTip
					side="bottom"
					title="Tour guiado"
					text="Refaz o passo a passo do montador quando quiser."
				>
					<button
						type="button"
						onclick={abrirTour}
						class="inline-flex touch-manipulation items-center gap-1.5 rounded-full border border-purple-300/30 bg-purple-500/10 px-3 py-2 text-xs font-medium text-purple-100/90 transition-colors hover:bg-purple-500/20 sm:py-1.5"
					>
						<Compass class="h-3.5 w-3.5" /> Como funciona
					</button>
				</HelpTip>
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

	{#if gradeStore.ultimaMontagem && gradeStore.ultimaMontagem.preferenciasNaoAtendidas.length > 0}
		<div class="mb-3 flex items-start gap-2 rounded-xl border border-sky-300/30 bg-sky-500/10 px-3 py-2 text-xs text-sky-100">
			<Info class="mt-0.5 h-3.5 w-3.5 shrink-0" />
			<span>
				Preferência de horário/professor não coube em
				<strong>{gradeStore.ultimaMontagem.preferenciasNaoAtendidas.join(', ')}</strong> — a matéria
				entrou numa turma alternativa para não ficar de fora.
			</span>
		</div>
	{/if}

	{#if gradeStore.ultimaMontagem?.truncado}
		<div class="mb-3 flex items-start gap-2 rounded-xl border border-white/15 bg-white/5 px-3 py-2 text-xs text-white/70">
			<Info class="mt-0.5 h-3.5 w-3.5 shrink-0" />
			<span>
				São muitas combinações possíveis — paramos numa grade boa, sem conflito, mas talvez não
				a melhor. Marque estrela nas matérias essenciais e rearranje de novo.
			</span>
		</div>
	{/if}

	{#if status === 'loading'}
		<div class="flex items-center justify-center gap-2 py-20 text-white/60">
			<Loader2 class="h-5 w-5 animate-spin" /> Carregando matérias e turmas...
		</div>
	{:else if status === 'error'}
		<div class="rounded-2xl border border-red-300/30 bg-red-500/10 px-4 py-6 text-center text-sm text-red-200">{erro}</div>
	{:else}
		<!--
			As três áreas viram snippets para poderem ser rearranjadas sem duplicação:
			no modo normal o calendário fica ao centro com matérias à esquerda e resumo
			à direita (ordem 1→2→3→4 do tour); no modo ampliado ele ocupa a largura
			toda e os painéis descem para uma linha abaixo.
		-->
		{#snippet colunaMaterias()}
			<MateriaSearchAdd onAdd={adicionarAoPool} />
			{#if avisoAdd}
				<p class="rounded-lg border border-amber-300/30 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-100">{avisoAdd}</p>
			{/if}
			{#if gradeStore.pool.length === 0}
				<div class="rounded-2xl border border-white/10 bg-zinc-950/78 px-3 py-6 text-center">
					<p class="text-xs text-white/50">
						Busque matérias acima ou peça recomendações ao assistente (botão flutuante).
					</p>
					<button
						type="button"
						onclick={abrirTour}
						class="mt-3 inline-flex items-center gap-1.5 rounded-full border border-purple-300/35 bg-purple-500/12 px-3 py-1.5 text-[11px] font-medium text-purple-100 transition-colors hover:bg-purple-500/22"
					>
						<Compass class="h-3.5 w-3.5" /> Ver o passo a passo
					</button>
				</div>
			{:else}
				<div class="flex items-center justify-between gap-2 px-1 pt-1">
					<p class="text-[11px] font-semibold uppercase tracking-[0.12em] text-white/55">2 · Turmas</p>
					<HelpTip
						title="Escolha uma turma por matéria"
						text="Clique numa turma para colocá-la na grade; clicar de novo tira. A estrela marca a matéria como prioritária no Rearranjar."
					/>
				</div>
				<SubjectTurmaSelector />
			{/if}
		{/snippet}

		{#snippet calendario()}
			<div class="mb-1.5 flex items-center justify-between px-1">
				<p class="text-[11px] font-semibold uppercase tracking-[0.12em] text-white/55">
					3 · Sua semana
				</p>
				<HelpTip
					side="left"
					title={calendarioExpandido ? 'Voltar ao layout compacto' : 'Ampliar o calendário'}
					text={calendarioExpandido
						? 'Traz matérias e resumo de volta para o lado do calendário.'
						: 'O calendário ocupa a tela inteira e os painéis descem — melhor pra enxergar a semana toda.'}
				>
					<button
						type="button"
						onclick={() => (calendarioExpandido = !calendarioExpandido)}
						data-tour="ampliar"
						class="hidden touch-manipulation items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2 py-1 text-[10px] text-white/55 transition-colors hover:bg-white/10 lg:inline-flex"
					>
						{#if calendarioExpandido}
							<Minimize2 class="h-3 w-3" /> Reduzir
						{:else}
							<Maximize2 class="h-3 w-3" /> Ampliar
						{/if}
					</button>
				</HelpTip>
			</div>
			<ScheduleGrid onBlocoClick={(codigo) => (materiaDialog = codigo)} />
		{/snippet}

		{#if calendarioExpandido}
			<div class="space-y-4">
				<div>{@render calendario()}</div>
				<div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem]">
					<div class="space-y-3">{@render colunaMaterias()}</div>
					<div><GradeResumo /></div>
				</div>
			</div>
		{:else}
			<div class="grid gap-4 lg:grid-cols-[22rem_minmax(0,1fr)_18rem]">
				<!-- Coluna esquerda: matérias + busca -->
				<div class="order-2 space-y-3 lg:order-1 lg:sticky lg:top-24 lg:max-h-[calc(100dvh-9rem)] lg:overflow-y-auto lg:pr-0.5">
					{@render colunaMaterias()}
				</div>

				<!-- Centro: calendário -->
				<div class="order-1 lg:order-2">{@render calendario()}</div>

				<!-- Direita: resumo -->
				<div class="order-3">
					<GradeResumo />
				</div>
			</div>
		{/if}
	{/if}
</div>

<TrocarTurmaDialog codigo={materiaDialog} onClose={() => (materiaDialog = null)} />

<!-- Onboarding guiado (spotlight + coach marks) -->
<OnboardingTour />

<!-- Chatbot flutuante (Darcy) — recomenda optativas com turma e insere na grade -->
{#if status === 'ready'}
	<AssistenteChatFab onAddToGrade={adicionarAoPool} onMontarGrade={montarGradeComPrioridade} />
{/if}
{/if}
