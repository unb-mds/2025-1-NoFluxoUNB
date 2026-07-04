<script lang="ts">
	import { browser } from '$app/environment';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import {
		Bot,
		SendHorizontal,
		Loader2,
		Sparkles,
		ChevronDown,
		Plus,
		BookOpen,
		User,
		Clock3,
		MapPin,
		Users,
		CalendarClock
	} from 'lucide-svelte';
	import ChatWrapper from '$lib/components/chat/ChatWrapper.svelte';
	import ChatBubble from '$lib/components/chat/ChatBubble.svelte';
	import ChatLoader from '$lib/components/chat/ChatLoader.svelte';
	import { AssistenteService, type StreamEvent } from '$lib/services/assistente.service';
	import { assistenteUIService } from '$lib/services/assistente-ui.service';
	import { authStore } from '$lib/stores/auth';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { fade, fly } from 'svelte/transition';
	import type { MateriaModel } from '$lib/types/materia';
	import OptativaTipoModal from '$lib/components/fluxograma/OptativaTipoModal.svelte';

	type DisciplinaStream = NonNullable<StreamEvent['data']>;
	type DisciplinaUI = DisciplinaStream & {
		idMateria?: number;
		departamento?: string;
		ementa?: string;
		creditos?: number;
		nivel?: number | null;
		tipoNatureza?: number | null;
		prerequisitos?: string[];
		prerequisitosExpressoes?: Array<{
			expressaoOriginal: string | null;
			grupos: string[][];
		}>;
		turmas?: Array<{
			turma: string;
			anoPeriodo: string;
			docente: string;
			horario: string;
			local: string;
			vagasOfertadas: number | null;
			vagasOcupadas: number | null;
			vagasSobrando: number | null;
			lastUpdatedAt: string | null;
		}>;
		ultimaAtualizacaoTurmas?: string | null;
		carregandoDetalhes?: boolean;
		detalhesCarregados?: boolean;
		erroDetalhes?: string | null;
		aberto: boolean;
	};

	type ChatMessage = {
		tipo: 'usuario' | 'assistente';
		texto: string;
		disciplinas?: DisciplinaUI[];
	};

	let mensagem = '';
	let carregando = false;
	let etapaAtual = '';
	let historico: ChatMessage[] = [];
	let materiaModal: MateriaModel | null = null;
	let permitirConcluidaNoModal = false;
	let salvandoOptativas = false;
	let turmasModalDisciplina: DisciplinaUI | null = null;

	const assistente = new AssistenteService();
	const detailsCache = new Map<string, Promise<void>>();
	const previewCache = new Map<string, Promise<void>>();

	function getMatrizCurricularUsuario(): string {
		const user = authStore.getUser();
		const fromStore = String(user?.dadosFluxograma?.matrizCurricular ?? '').trim();
		if (fromStore) return fromStore;

		if (!browser) return '';
		try {
			const raw = localStorage.getItem('nofluxo_user');
			if (!raw) return '';
			const parsed = JSON.parse(raw) as {
				dadosFluxograma?: { matrizCurricular?: string };
				dados_fluxograma?: { matriz_curricular?: string };
			};
			return String(
				parsed?.dadosFluxograma?.matrizCurricular ??
					parsed?.dados_fluxograma?.matriz_curricular ??
					''
			).trim();
		} catch {
			return '';
		}
	}

	function toggleExpand(msgIndex: number, discIndex: number) {
		const nextHistorico = [...historico];
		const current = nextHistorico[msgIndex];
		if (!current?.disciplinas) return;
		const alvo = current.disciplinas[discIndex];
		if (!alvo) return;
		const abrindoAgora = !alvo.aberto;

		nextHistorico[msgIndex] = {
			...current,
			disciplinas: current.disciplinas.map((disc, idx) =>
				idx === discIndex ? { ...disc, aberto: !disc.aberto } : disc
			)
		};
		historico = nextHistorico;

		// Evita travar a UI carregando detalhes de todas as matérias de uma vez.
		// Carrega só quando o aluno abre o card.
		if (abrindoAgora && !alvo.detalhesCarregados && !alvo.carregandoDetalhes) {
			void enriquecerDisciplina(msgIndex, alvo.codigo, getMatrizCurricularUsuario());
		}
	}

	function updateDisciplina(
		msgIndex: number,
		codigo: string,
		updater: (disc: DisciplinaUI) => DisciplinaUI
	) {
		const nextHistorico = [...historico];
		const current = nextHistorico[msgIndex];
		if (!current?.disciplinas) return;

		nextHistorico[msgIndex] = {
			...current,
			disciplinas: current.disciplinas.map((disc) =>
				disc.codigo === codigo ? updater(disc) : disc
			)
		};
		historico = nextHistorico;
	}

	function formatDate(value?: string | null): string {
		if (!value) return 'Sem informação';
		const dt = new Date(value);
		if (Number.isNaN(dt.getTime())) return 'Sem informação';
		return dt.toLocaleString('pt-BR', {
			dateStyle: 'short',
			timeStyle: 'short'
		});
	}

	function formatVagas(
		vagasSobrando: number | null,
		vagasOfertadas: number | null,
		vagasOcupadas: number | null
	): string {
		if (vagasSobrando != null) return String(Math.max(0, vagasSobrando));
		if (vagasOfertadas != null && vagasOcupadas != null)
			return String(Math.max(0, vagasOfertadas - vagasOcupadas));
		return '-';
	}

	function getVagasSobrandoNumero(
		vagasSobrando: number | null,
		vagasOfertadas: number | null,
		vagasOcupadas: number | null
	): number | null {
		if (vagasSobrando != null) return Math.max(0, vagasSobrando);
		if (vagasOfertadas != null && vagasOcupadas != null)
			return Math.max(0, vagasOfertadas - vagasOcupadas);
		return null;
	}

	const DIA_MAP: Record<string, string> = {
		'2': 'Seg',
		'3': 'Ter',
		'4': 'Qua',
		'5': 'Qui',
		'6': 'Sex',
		'7': 'Sab'
	};

	const SLOT_MAP: Record<'M' | 'T' | 'N', Record<string, string>> = {
		M: {
			'1': '08:00-08:55',
			'2': '08:55-09:50',
			'3': '10:00-10:55',
			'4': '10:55-11:50',
			'5': '12:00-12:55'
		},
		T: {
			'1': '12:55-13:50',
			'2': '14:00-14:55',
			'3': '14:55-15:50',
			'4': '16:00-16:55',
			'5': '16:55-17:50',
			'6': '18:00-18:55',
			'7': '18:55-19:50'
		},
		N: {
			'1': '19:00-19:50',
			'2': '19:50-20:40',
			'3': '20:50-21:40',
			'4': '21:40-22:30'
		}
	};

	function turnoLabel(turno: 'M' | 'T' | 'N'): string {
		if (turno === 'M') return 'Manha';
		if (turno === 'T') return 'Tarde';
		return 'Noite';
	}

	type HorarioLinha = {
		dia: string;
		faixas: string[];
	};

	function formatHorarioSigaa(rawHorario: string): HorarioLinha[] {
		const raw = String(rawHorario ?? '').trim();
		if (!raw) return [];

		// Ex.: 24M12, 35T34, 6N1234, múltiplos blocos no mesmo texto.
		const regex = /([2-7]+)\s*([MTN])\s*([1-7]+)/g;
		const out: HorarioLinha[] = [];
		let match: RegExpExecArray | null = regex.exec(raw);

		while (match) {
			const diasCod = match[1] ?? '';
			const turno = (match[2] ?? 'M') as 'M' | 'T' | 'N';
			const slotsCod = match[3] ?? '';
			const faixas = [...slotsCod].map((s) => SLOT_MAP[turno]?.[s] ?? `${turno}${s}`);

			for (const d of [...diasCod]) {
				const dia = DIA_MAP[d] ?? d;
				out.push({
					dia,
					faixas
				});
			}
			match = regex.exec(raw);
		}

		return out;
	}

	function formatHoraCompacta(raw: string): string {
		const [h, m] = raw.split(':');
		if (!h) return raw;
		const hora = String(Number(h));
		if (!m || m === '00') return `${hora}h`;
		return `${hora}h${m}`;
	}

	function compactarFaixasHorarias(faixas: string[]): string {
		if (!faixas || faixas.length === 0) return '-';
		const primeira = faixas[0];
		const ultima = faixas[faixas.length - 1];
		const inicio = primeira.split('-')[0] ?? primeira;
		const fim = ultima.split('-')[1] ?? ultima;
		return `${formatHoraCompacta(inicio)} - ${formatHoraCompacta(fim)}`;
	}

	function formatLocalSigaa(rawLocal: string): string[] {
		const raw = String(rawLocal ?? '').trim();
		if (!raw) return [];

		// Ex.: "2N12(ICC ANF.12) 35N34(ICC ANF.15)"
		const regex = /([2-7]+[MTN][1-7]+)\(([^)]+)\)/g;
		const out: string[] = [];
		let match: RegExpExecArray | null = regex.exec(raw);

		while (match) {
			const codigo = String(match[1] ?? '').trim().toUpperCase();
			const local = String(match[2] ?? '').trim();
			const horarios = formatHorarioSigaa(codigo);
			if (horarios.length === 0) {
				out.push(`${local} (${codigo})`);
			} else {
				for (const h of horarios) {
					out.push(`${h.dia} (${compactarFaixasHorarias(h.faixas)}) - ${local}`);
				}
			}
			match = regex.exec(raw);
		}

		if (out.length > 0) return out;
		return [raw];
	}

	function toMateriaModel(disc: DisciplinaUI): MateriaModel {
		return {
			ementa: disc.ementa ?? '',
			idMateria: Number(disc.idMateria ?? -1),
			nomeMateria: disc.nome,
			codigoMateria: disc.codigo,
			// Na IA, qualquer item adicionado por este fluxo deve entrar como optativa planejada.
			nivel: 0,
			tipoNatureza: 1,
			creditos: Number(disc.creditos ?? 0),
			preRequisitos: []
		};
	}

	function abrirModalAdicionar(disc: DisciplinaUI) {
		materiaModal = toMateriaModel(disc);
		permitirConcluidaNoModal = Number(disc.idMateria ?? -1) > 0;
	}

	function abrirModalTurmas(disc: DisciplinaUI) {
		turmasModalDisciplina = disc;
	}

	function getTurmasSeguras(disc?: DisciplinaUI | null): NonNullable<DisciplinaUI['turmas']> {
		if (!disc?.turmas || !Array.isArray(disc.turmas)) return [];
		return disc.turmas.filter((turma) => !!turma && typeof turma === 'object');
	}

	async function garantirDetalhesDisciplina(
		msgIndex: number,
		discIndex: number
	): Promise<DisciplinaUI | null> {
		const msg = historico[msgIndex];
		const disc = msg?.disciplinas?.[discIndex];
		if (!disc) return null;
		if (disc.detalhesCarregados) return disc;
		if (!disc.carregandoDetalhes) {
			await enriquecerDisciplina(msgIndex, disc.codigo, getMatrizCurricularUsuario());
		}
		return historico[msgIndex]?.disciplinas?.[discIndex] ?? null;
	}

	async function abrirModalAdicionarComDetalhes(msgIndex: number, discIndex: number) {
		const disc = await garantirDetalhesDisciplina(msgIndex, discIndex);
		if (!disc) return;
		abrirModalAdicionar(disc);
	}

	async function abrirModalTurmasComDetalhes(msgIndex: number, discIndex: number) {
		const disc = await garantirDetalhesDisciplina(msgIndex, discIndex);
		if (!disc) return;
		abrirModalTurmas(disc);
	}

	async function salvarOptativasNaIA() {
		if (salvandoOptativas) return;
		salvandoOptativas = true;
		try {
			await fluxogramaStore.saveOptativasPlanejadas();
		} finally {
			salvandoOptativas = false;
		}
	}

	async function enriquecerDisciplina(msgIndex: number, codigo: string, matrizCurricular: string) {
		const key = `${codigo.toUpperCase()}|${matrizCurricular}`;
		if (detailsCache.has(key)) {
			await detailsCache.get(key);
			return;
		}

		const job = (async () => {
			updateDisciplina(msgIndex, codigo, (disc) => ({
				...disc,
				carregandoDetalhes: true,
				erroDetalhes: null
			}));

			try {
				const context = await assistenteUIService.getMateriaContext(codigo, matrizCurricular);
				if (!context) {
					updateDisciplina(msgIndex, codigo, (disc) => ({
						...disc,
						carregandoDetalhes: false,
						erroDetalhes: 'Disciplina não encontrada na base.'
					}));
					return;
				}

				updateDisciplina(msgIndex, codigo, (disc) => ({
					...disc,
					idMateria: context.idMateria,
					departamento: context.departamento,
					ementa: context.ementa,
					creditos: context.creditos,
					nivel: context.nivel,
					tipoNatureza: context.tipoNatureza,
					prerequisitos: context.prerequisitos,
					prerequisitosExpressoes: context.prerequisitosExpressoes,
					turmas: context.turmas,
					ultimaAtualizacaoTurmas: context.ultimaAtualizacaoTurmas,
					carregandoDetalhes: false,
					detalhesCarregados: true,
					erroDetalhes: null
				}));
			} catch (error) {
				const msg = error instanceof Error ? error.message : 'Erro ao buscar detalhes';
				updateDisciplina(msgIndex, codigo, (disc) => ({
					...disc,
					carregandoDetalhes: false,
					detalhesCarregados: false,
					erroDetalhes: msg
				}));
			}
		})();

		detailsCache.set(key, job);
		await job;
	}

	async function enriquecerDisciplinaPreview(
		msgIndex: number,
		codigo: string,
		matrizCurricular: string
	) {
		const key = `${codigo.toUpperCase()}|${matrizCurricular}`;
		if (previewCache.has(key)) {
			await previewCache.get(key);
			return;
		}

		const job = (async () => {
			try {
				const preview = await assistenteUIService.getMateriaPreview(codigo, matrizCurricular);
				if (!preview) return;

				updateDisciplina(msgIndex, codigo, (disc) => ({
					...disc,
					idMateria: preview.idMateria,
					departamento: preview.departamento,
					creditos: preview.creditos,
					nivel: preview.nivel,
					tipoNatureza: preview.tipoNatureza
				}));
			} catch {
				// Não bloqueia o fluxo principal do chat se falhar metadado de card.
			}
		})();

		previewCache.set(key, job);
		await job;
	}

	async function enviarMensagem() {
		if (!mensagem.trim() || carregando) return;

		const mensagemUsuario = mensagem.trim();
		mensagem = '';
		historico = [...historico, { tipo: 'usuario', texto: mensagemUsuario }];

		carregando = true;
		etapaAtual = 'Conectando...';

		const assistenteIndex = historico.length;
		historico = [...historico, { tipo: 'assistente', texto: '', disciplinas: [] }];

		const matrizCurricular = getMatrizCurricularUsuario();

		try {
			await assistente.streamMessageFromSabia(
				mensagemUsuario,
				matrizCurricular,
				(event: StreamEvent) => {
					switch (event.stage) {
						case 'thinking':
							etapaAtual = event.message || 'Analisando...';
							break;
						case 'searching':
							etapaAtual = event.message || 'Buscando disciplinas...';
							break;
						case 'generating':
							etapaAtual = event.message || 'Gerando recomendações...';
							break;
						case 'disciplina':
							if (event.data) {
								const current = historico[assistenteIndex];
								if (!current) return;
								const existing = (current.disciplinas ?? []).some(
									(disc) => disc.codigo === event.data?.codigo
								);
								if (existing) return;

								const disciplinas = [
									...(current.disciplinas || []),
									{
										...event.data,
										carregandoDetalhes: false,
										detalhesCarregados: false,
										erroDetalhes: null,
										aberto: false
									} satisfies DisciplinaUI
								];

								historico[assistenteIndex] = { ...current, disciplinas };
								historico = [...historico];
								void enriquecerDisciplinaPreview(
									assistenteIndex,
									event.data.codigo,
									matrizCurricular
								);
							}
							break;
						case 'done':
							historico[assistenteIndex] = {
								...historico[assistenteIndex],
								texto: event.resultado || 'Resposta recebida'
							};
							historico = [...historico];
							break;
						case 'error':
							historico[assistenteIndex] = {
								tipo: 'assistente',
								texto: `❌ Erro: ${event.message}`,
								disciplinas: undefined
							};
							historico = [...historico];
							break;
					}
				}
			);
		} catch (erro: unknown) {
			const message = erro instanceof Error ? erro.message : 'Erro desconhecido';
			historico[assistenteIndex] = {
				tipo: 'assistente',
				texto: `❌ Erro ao conectar: ${message}`,
				disciplinas: undefined
			};
			historico = [...historico];
		} finally {
			carregando = false;
			etapaAtual = '';
		}
	}

	function handleKeyPress(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			enviarMensagem();
		}
	}

	function pedirOptativasDoCurso() {
		mensagem = 'Recomende matérias optativas baseado no meu curso';
		void enviarMensagem();
	}
</script>

<PageMeta
	title="Darcy AI"
	description="Converse com o assistente inteligente do NoFluxo para descobrir disciplinas"
	noIndex={true}
/>



<div class="relative z-10 mx-auto flex h-[calc(100dvh-5.75rem)] min-h-0 w-full max-w-none flex-col px-2 pb-2 sm:h-[calc(100dvh-6.5rem)] sm:px-3 sm:pb-3 lg:px-6">
	<div class="relative flex min-h-0 flex-1 flex-col overflow-hidden rounded-xl bg-[#09090b] shadow-2xl border border-white/5">
		<ChatWrapper>
			<!-- Header inside ChatWrapper for assistente standalone -->
			<div class="relative z-10 px-5 py-3 border-b border-white/5 flex items-center justify-center shrink-0 bg-black/20 backdrop-blur-xl">
				<div class="flex items-center gap-2 rounded-full border border-white/10 bg-black/25 px-3 py-1 backdrop-blur-md shadow-inner">
					<Sparkles class="h-3.5 w-3.5 text-pink-400" />
					<div class="flex items-baseline gap-1.5">
						<span class="text-[11px] font-bold uppercase tracking-widest text-white/50 sm:text-xs">Darcy AI</span>
						<span class="text-[9px] font-semibold tracking-wider text-white/30 sm:text-[10px]">Powered by Maritaca AI</span>
					</div>
				</div>
			</div>

			<!-- Mensagens -->
			<div class="flex-1 overflow-y-auto space-y-2.5 p-4 sm:p-5 relative z-10">
				{#if historico.length === 0}
					<div class="h-full flex flex-col items-center justify-center text-center">
						<div class="w-16 h-16 rounded-3xl bg-white/5 border border-white/10 flex items-center justify-center mb-6 shadow-2xl backdrop-blur-md">
							<Bot class="h-8 w-8 text-pink-400 opacity-80" />
						</div>
						<h2 class="mb-2 text-lg font-bold tracking-tight text-white/95">Como posso ajudar?</h2>
						
						<div class="mt-4 grid max-w-2xl grid-cols-2 gap-2 sm:grid-cols-3 sm:auto-rows-fr sm:gap-3">
							<button
								on:click={() => { mensagem = 'Direito Constitucional e Teoria da Constituição'; enviarMensagem(); }}
								class="chat-suggestion h-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[12px] font-medium text-white/80 transition-all hover:bg-white/10 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								⚖️ Direito Constitucional
							</button>

							<button
								on:click={() => { mensagem = 'História da África: Sociedades Pré-Coloniais e Processos de Independência'; enviarMensagem(); }}
								class="chat-suggestion h-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[12px] font-medium text-white/80 transition-all hover:bg-white/10 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								🌍 História da África
							</button>

							<button
								on:click={() => { mensagem = 'Inteligência Artificial: Aprendizado de Máquina e Redes Neurais'; enviarMensagem(); }}
								class="chat-suggestion h-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[12px] font-medium text-white/80 transition-all hover:bg-white/10 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								🤖 Inteligência Artificial
							</button>

							<button
								on:click={() => { mensagem = 'Bioética e Saúde Coletiva no Sistema Único de Saúde'; enviarMensagem(); }}
								class="chat-suggestion h-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[12px] font-medium text-white/80 transition-all hover:bg-white/10 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								🦠 Microbiologia
							</button>

							<button
								on:click={() => { mensagem = 'Macroeconomia: Modelos de Crescimento e Políticas Monetárias'; enviarMensagem(); }}
								class="chat-suggestion h-full rounded-2xl border border-white/10 bg-white/5 px-3 py-2.5 text-left text-[12px] font-medium text-white/80 transition-all hover:bg-white/10 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								📈 Macroeconomia
							</button>

							<button
								on:click={pedirOptativasDoCurso}
								class="chat-suggestion h-full rounded-2xl border border-fuchsia-500/30 bg-fuchsia-500/10 px-3 py-2.5 text-left text-[12px] font-medium text-fuchsia-100 transition-all hover:bg-fuchsia-500/20 hover:shadow-md hover:text-white sm:text-xs backdrop-blur-md"
							>
								✨ Recomendar optativas
							</button>
						</div>
					</div>
				{:else}
					{#each historico as msg, msgIndex}
						<ChatBubble role={msg.tipo} name={msg.tipo === 'usuario' ? 'Você' : 'Darcy AI'}>
							{#if !msg.disciplinas || msg.disciplinas.length === 0}
								<p class="whitespace-pre-wrap text-sm leading-relaxed text-white">{msg.texto}</p>
							{/if}
							
							{#if msg.disciplinas && msg.disciplinas.length > 0}
								<!-- Título apenas para disciplinas -->
								<p class="mb-3 text-sm font-semibold text-white/90">
									🎓 {msg.disciplinas.length} {msg.disciplinas.length === 1 ? 'disciplina encontrada' : 'disciplinas encontradas'}
								</p>
								
								<div class="flex flex-col gap-3 w-full sm:w-[480px] lg:w-[600px] mt-2">
									{#each msg.disciplinas as disc, discIndex}
										<div
											class="overflow-hidden rounded-xl border border-white/10 bg-white/5 backdrop-blur-md shadow-lg transition-all"
										>
											<div class="flex items-center justify-between gap-3 p-3.5 sm:p-4">
												<div class="flex-1">
													<div class="flex flex-wrap items-center gap-1.5 sm:gap-2">
														<span class="text-[12px] font-black tracking-widest text-white/90 font-mono">
															{disc.codigo}
														</span>
														<h3 class="text-[14.5px] font-bold leading-tight text-white">
															{disc.nome}
														</h3>
													</div>
												</div>
												<button
													type="button"
													class="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white/70 hover:bg-white/20 hover:text-white transition-all border border-white/5"
													on:click={() => toggleExpand(msgIndex, discIndex)}
													aria-label={disc.aberto ? 'Recolher card' : 'Expandir card'}
												>
													<ChevronDown
														class={disc.aberto
															? 'h-4 w-4 transition-transform rotate-180'
															: 'h-4 w-4 transition-transform'}
													/>
												</button>
											</div>

											<div class="px-3.5 pb-3 sm:px-4 flex items-center justify-between gap-2">
												<div class="flex flex-wrap gap-1.5 text-[10px]">
													{#if disc.creditos != null && disc.creditos > 0}
														<span class="rounded-full bg-white/10 px-2.5 py-0.5 font-bold text-white shadow-sm border border-white/10">{disc.creditos} créditos</span>
													{/if}
													{#if disc.departamento}
														<span class="rounded-full bg-white/10 px-2.5 py-0.5 font-bold text-white shadow-sm border border-white/10">{disc.departamento}</span>
													{/if}
													{#if disc.tipoNatureza === 1}
														<span class="rounded-full bg-amber-500/20 px-2.5 py-0.5 font-bold text-amber-200 border border-amber-500/30">optativa</span>
													{:else if disc.tipoNatureza === 0}
														<span class="rounded-full bg-sky-500/20 px-2.5 py-0.5 font-bold text-sky-200 border border-sky-500/30">obrigatória</span>
													{/if}
												</div>
												<div class="flex items-baseline gap-1 text-emerald-400 font-mono">
													<span class="text-xl font-black leading-none drop-shadow-sm">{disc.nota}</span>
													<span class="text-[11px] text-emerald-300/80 font-bold">/10</span>
												</div>
											</div>

											{#if disc.justificativa}
												<div class="mx-3.5 mb-3 rounded-lg border border-emerald-400/20 bg-emerald-500/10 px-3 py-2 shadow-inner">
													<p class="mb-1 text-[10px] font-bold uppercase tracking-widest text-emerald-300">Por que recomenda:</p>
													<p class="text-[13px] text-emerald-100/90 leading-snug">{disc.justificativa}</p>
												</div>
											{/if}

											{#if disc.aberto}
												<div class="px-3.5 pb-3.5 sm:px-4 space-y-2 border-t border-white/5 pt-3" in:fly={{ y: -6, duration: 180 }} out:fly={{ y: -4, duration: 140 }}>
													{#if disc.carregandoDetalhes}
														<div class="flex items-center gap-2 text-xs text-white/50 font-medium">
															<Loader2 class="h-3.5 w-3.5 animate-spin" />
															Carregando pré-requisitos e turmas...
														</div>
													{:else if disc.erroDetalhes}
														<p class="text-xs text-red-400 font-medium">{disc.erroDetalhes}</p>
													{/if}

													<div>
														<p class="text-[10px] font-bold uppercase tracking-widest text-white/50 mb-1.5">Pré-requisitos</p>
														{#if disc.prerequisitos && disc.prerequisitos.length > 0}
															<div class="flex flex-wrap gap-1.5">
																{#each disc.prerequisitos as req}
																	<span class="rounded-md bg-white/10 px-2 py-1 text-[11px] font-bold text-white border border-white/20">{req}</span>
																{/each}
															</div>
														{:else}
															<p class="text-xs text-white/60 font-medium">Esta matéria não possui pré-requisito.</p>
														{/if}
													</div>

													{#if disc.prerequisitosExpressoes && disc.prerequisitosExpressoes.length > 0}
														<div class="space-y-2 mt-3">
															<p class="text-[10px] font-bold uppercase tracking-widest text-white/50 mb-1.5">Expressão de pré-requisito</p>
															{#each disc.prerequisitosExpressoes as expr}
																<div class="rounded-xl border border-purple-500/20 bg-purple-500/10 px-3 py-2.5">
																	{#each expr.grupos as group, gi}
																		<div class="flex flex-wrap items-center gap-1.5">
																			{#each group as item, ii}
																				<span class="rounded-md bg-white/10 px-1.5 py-0.5 text-[11px] font-bold text-white border border-white/20">{item}</span>
																				{#if ii < group.length - 1}
																					<span class="text-[10px] font-bold uppercase tracking-wide text-purple-300">E</span>
																				{/if}
																			{/each}
																		</div>
																		{#if gi < expr.grupos.length - 1}
																			<div class="my-1.5 text-[10px] font-black uppercase tracking-[0.15em] text-purple-400">OU</div>
																		{/if}
																	{/each}
																	{#if expr.expressaoOriginal}
																		<p class="mt-2 text-[11px] text-purple-200/70">{expr.expressaoOriginal}</p>
																	{/if}
																</div>
															{/each}
														</div>
													{/if}
												</div>
											{/if}

											<div class="grid grid-cols-1 gap-1.5 sm:grid-cols-2 p-3.5 pt-0">
												<button
													type="button"
													class="flex items-center justify-center gap-2 rounded-xl bg-blue-500/20 hover:bg-blue-500/30 border border-blue-500/30 px-3 py-2 text-[13px] font-bold text-blue-200 transition-all disabled:opacity-50"
													on:click={() => void abrirModalAdicionarComDetalhes(msgIndex, discIndex)}
													disabled={!!disc.carregandoDetalhes}
												>
													{#if disc.carregandoDetalhes}
														<Loader2 class="h-4 w-4 animate-spin" />
														Carregando...
													{:else}
														<Plus class="h-4 w-4" />
														Adicionar
													{/if}
												</button>
												<button
													type="button"
													class="flex items-center justify-center gap-2 rounded-xl bg-white/10 hover:bg-white/20 border border-white/10 px-3 py-2 text-[13px] font-bold text-white transition-all disabled:opacity-50"
													on:click={() => void abrirModalTurmasComDetalhes(msgIndex, discIndex)}
													disabled={!!disc.carregandoDetalhes}
												>
													{#if disc.carregandoDetalhes}
														<Loader2 class="h-4 w-4 animate-spin" />
														Carregando...
													{:else}
														<BookOpen class="h-4 w-4" />
														Ver Turmas
													{/if}
												</button>
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</ChatBubble>
					{/each}
				{/if}
				
				{#if carregando}
					<ChatLoader text={etapaAtual || 'Pensando...'} />
				{/if}
			</div>

			<!-- Input -->
			<div class="border-t border-white/10 p-3 sm:p-4 bg-transparent relative z-10">
				{#if fluxogramaStore.precisaSalvarPerfil}
					<div class="mb-3 flex items-center justify-between gap-3 rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-2.5 backdrop-blur-md shadow-lg">
						<p class="text-[12px] font-medium text-emerald-100/95">Você tem alterações pendentes no perfil do fluxograma.</p>
						<button
							type="button"
							class="inline-flex shrink-0 items-center justify-center gap-2 rounded-lg border border-emerald-400/40 bg-emerald-500/20 px-3 py-1.5 text-[12px] font-bold text-emerald-100 transition-all hover:bg-emerald-500/30 shadow-inner disabled:cursor-not-allowed disabled:opacity-50"
							on:click={() => void salvarOptativasNaIA()}
							disabled={salvandoOptativas}
						>
							{#if salvandoOptativas}
								<Loader2 class="h-3.5 w-3.5 animate-spin" />
								Salvando...
							{:else}
								Salvar
							{/if}
						</button>
					</div>
				{/if}
				<form on:submit|preventDefault={enviarMensagem} class="flex items-center w-full shadow-2xl relative">
					<input
						type="text"
						bind:value={mensagem}
						on:keypress={handleKeyPress}
						placeholder="Só tópicos de interesse (ex: IA aplicada a saúde)..."
						disabled={carregando}
						class="w-full bg-white/10 backdrop-blur-2xl border border-white/20 rounded-full pl-5 pr-[110px] py-4 text-[14.5px] text-white placeholder:text-white/40 focus:outline-none focus:border-white/30 focus:bg-white/15 transition-all shadow-inner disabled:opacity-50"
					/>
					<button
						type="submit"
						disabled={!mensagem.trim() || carregando}
						class="absolute right-2 flex shrink-0 items-center justify-center gap-1.5 rounded-full bg-white/15 hover:bg-white/25 border border-white/20 px-4 py-2 text-[13px] font-bold text-white shadow-md transition-all disabled:cursor-not-allowed disabled:opacity-40 sm:px-4"
					>
						{#if carregando}
							<Loader2 class="h-4 w-4 animate-spin" />
						{:else}
							<SendHorizontal class="h-4 w-4" />
						{/if}
						<span class="hidden sm:inline">Enviar</span>
					</button>
				</form>
			</div>
		</ChatWrapper>
	</div>
</div>

{#if materiaModal}
	<OptativaTipoModal
		materia={materiaModal}
		allowConcluida={permitirConcluidaNoModal}
		defaultSemestre={Math.max(1, Number(authStore.getUser()?.dadosFluxograma?.semestreAtual ?? 1))}
		ondecidir={(tipo, semestreFuturo) => {
			if (!materiaModal) return;
			if (tipo === 'futura') {
				fluxogramaStore.addOptativa(materiaModal, semestreFuturo ?? 1);
			} else {
				fluxogramaStore.registrarOptativaConcluida(materiaModal, semestreFuturo ?? 1);
			}
			materiaModal = null;
			permitirConcluidaNoModal = false;
		}}
		onpular={() => {
			materiaModal = null;
			permitirConcluidaNoModal = false;
		}}
	/>
{/if}

{#if turmasModalDisciplina}
	{@const turmasModalLista = getTurmasSeguras(turmasModalDisciplina)}
	<div class="fixed inset-0 z-[500] flex items-center justify-center bg-black/60 p-3 backdrop-blur-sm" in:fade={{ duration: 160 }} out:fade={{ duration: 130 }}>
		<div class="w-full max-w-3xl rounded-2xl border border-white/15 bg-slate-950/95 shadow-2xl" in:fly={{ y: 10, duration: 180 }} out:fly={{ y: 8, duration: 140 }}>
			<div class="flex items-start justify-between border-b border-white/10 px-5 py-4">
				<div>
					<h3 class="text-white font-semibold text-lg">Turmas Disponíveis</h3>
					<p class="text-white/70 text-sm">
						{turmasModalDisciplina?.codigo ?? '-'} - {turmasModalDisciplina?.nome ?? '-'}
					</p>
					<p class="text-xs text-white/55 mt-1">
						Última atualização: {formatDate(turmasModalDisciplina?.ultimaAtualizacaoTurmas)}
					</p>
				</div>
				<button
					type="button"
					class="text-white/60 hover:text-white"
					on:click={() => {
						turmasModalDisciplina = null;
					}}
					aria-label="Fechar modal de turmas"
				>
					✕
				</button>
			</div>

			<div class="max-h-[64vh] overflow-y-auto p-5 space-y-4">
				{#if turmasModalLista.length === 0}
					<p class="text-sm text-white/60">Nenhuma turma encontrada para esta disciplina.</p>
				{:else}
					{#each turmasModalLista as turma}
						<div class="rounded-xl border border-white/10 bg-white/[0.06] p-5">
							<div class="flex flex-wrap items-start justify-between gap-4">
								<p class="text-[1.08rem] font-bold text-blue-300">
									Turma {turma.turma || '-'} - {turma.anoPeriodo || '-'}
								</p>
								<p class="text-sm">
									<span class="text-white/80">Vagas sobrando:</span>
									<span
										class="ml-1 font-black text-lg"
										class:text-green-400={getVagasSobrandoNumero(turma.vagasSobrando, turma.vagasOfertadas, turma.vagasOcupadas) !== null && getVagasSobrandoNumero(turma.vagasSobrando, turma.vagasOfertadas, turma.vagasOcupadas)! > 0}
										class:text-red-400={getVagasSobrandoNumero(turma.vagasSobrando, turma.vagasOfertadas, turma.vagasOcupadas) === 0}
										class:text-white={getVagasSobrandoNumero(turma.vagasSobrando, turma.vagasOfertadas, turma.vagasOcupadas) === null}
									>
										{formatVagas(turma.vagasSobrando, turma.vagasOfertadas, turma.vagasOcupadas)}
									</span>
								</p>
							</div>

							<div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-3 text-sm">
								<div class="rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2.5">
									<p class="text-sky-300/90 text-xs mb-1 inline-flex items-center gap-1.5 font-semibold">
										<User class="h-3.5 w-3.5" />
										Docente
									</p>
									<p class="text-white font-semibold leading-snug">{turma.docente || '-'}</p>
								</div>
								<div class="rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2.5">
									<p class="text-sky-300/90 text-xs mb-1 inline-flex items-center gap-1.5 font-semibold">
										<Clock3 class="h-3.5 w-3.5" />
										Horário
									</p>
									{#if formatHorarioSigaa(turma.horario).length > 0}
										<div class="space-y-1.5">
											{#each formatHorarioSigaa(turma.horario) as linha}
												<div class="grid grid-cols-[108px_minmax(0,1fr)] gap-2 text-[13px] leading-snug rounded-md bg-black/20 px-2 py-1">
													<p class="text-white/90 font-semibold">{linha.dia}</p>
													<p class="text-white font-medium">{compactarFaixasHorarias(linha.faixas)}</p>
												</div>
											{/each}
											<p class="text-[11px] text-white/45">Código SIGAA: {turma.horario}</p>
										</div>
									{:else}
										<p class="text-white/90 leading-snug">{turma.horario || '-'}</p>
									{/if}
								</div>
								<div class="rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2.5">
									<p class="text-sky-300/90 text-xs mb-1 inline-flex items-center gap-1.5 font-semibold">
										<MapPin class="h-3.5 w-3.5" />
										Local
									</p>
									{#if formatLocalSigaa(turma.local).length > 0}
										<div class="space-y-1">
											{#each formatLocalSigaa(turma.local) as localLinha}
												<p class="text-white font-semibold leading-snug">{localLinha}</p>
											{/each}
											<p class="text-[11px] text-white/45">Origem SIGAA: {turma.local || '-'}</p>
										</div>
									{:else}
										<p class="text-white font-semibold leading-snug">{turma.local || '-'}</p>
									{/if}
								</div>
								<div class="rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2.5">
									<p class="text-sky-300/90 text-xs mb-1 inline-flex items-center gap-1.5 font-semibold">
										<Users class="h-3.5 w-3.5" />
										Vagas (ocupadas / ofertadas)
									</p>
									<p class="leading-snug">
										<span class="text-white font-bold">{turma.vagasOcupadas ?? '-'}</span>
										<span class="text-white/70"> / </span>
										<span class="text-white font-bold">{turma.vagasOfertadas ?? '-'}</span>
									</p>
								</div>
							</div>
							<p class="mt-4 text-[11px] text-white/50 inline-flex items-center gap-1.5">
								<CalendarClock class="h-3.5 w-3.5" />
								Atualizado em: {formatDate(turma.lastUpdatedAt)}
							</p>
						</div>
					{/each}
				{/if}
			</div>

			<div class="border-t border-white/10 p-4">
				<button
					type="button"
					class="w-full rounded-lg bg-fuchsia-600/80 hover:bg-fuchsia-500 text-white py-2 text-sm font-medium"
					on:click={() => {
						turmasModalDisciplina = null;
					}}
				>
					Fechar
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.chat-shell {
		background: rgba(15, 23, 42, 0.72);
		border: 1px solid rgba(255, 255, 255, 0.14);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
	}

	.chat-suggestion {
		background: rgba(15, 23, 42, 0.58);
		border: 1px solid rgba(255, 255, 255, 0.14);
		color: rgba(255, 255, 255, 0.96);
	}

	.chat-suggestion:hover {
		background: rgba(30, 41, 59, 0.78);
		border-color: rgba(255, 255, 255, 0.24);
	}

	.assistant-bubble {
		background: rgba(15, 23, 42, 0.82);
		border: 1px solid rgba(255, 255, 255, 0.18);
		color: rgba(255, 255, 255, 0.98);
	}

	.assistant-card {
		background: rgba(2, 6, 23, 0.8);
		border: 1px solid rgba(255, 255, 255, 0.18);
		min-height: 148px;
	}

	.assistant-list-shell {
		width: 100%;
	}

	.tag-chip {
		background: rgba(148, 163, 184, 0.15);
		border: 1px solid rgba(148, 163, 184, 0.24);
		color: rgba(226, 232, 240, 0.92);
		padding: 1px 7px;
		border-radius: 9999px;
		font-size: 10px;
	}

	.req-chip {
		background: rgba(59, 130, 246, 0.15);
		border: 1px solid rgba(96, 165, 250, 0.35);
		color: rgba(219, 234, 254, 0.95);
		padding: 2px 8px;
		border-radius: 6px;
		font-size: 11px;
	}

	.assistant-action-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 5px;
		border-radius: 9px;
		background: linear-gradient(135deg, rgba(236, 72, 153, 0.85), rgba(168, 85, 247, 0.85));
		color: #fff;
		padding: 6px 10px;
		font-size: 0.78rem;
		font-weight: 600;
		border: 1px solid rgba(255, 255, 255, 0.18);
		transition:
			transform 160ms ease,
			box-shadow 160ms ease,
			opacity 160ms ease,
			background 160ms ease;
		will-change: transform;
	}

	.assistant-action-btn.secondary {
		background: rgba(15, 23, 42, 0.8);
	}

	.assistant-action-btn:hover:not(:disabled) {
		transform: translateY(-1px) scale(1.01);
		box-shadow: 0 8px 20px rgba(236, 72, 153, 0.25);
	}

	.assistant-action-btn.secondary:hover:not(:disabled) {
		box-shadow: 0 8px 20px rgba(59, 130, 246, 0.2);
		background: rgba(30, 41, 59, 0.9);
	}

	.assistant-action-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	/* Scrollbar personalizada */
	:global(.overflow-y-auto::-webkit-scrollbar) {
		width: 8px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-track) {
		background: rgba(255, 255, 255, 0.05);
		border-radius: 4px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-thumb) {
		background: rgba(255, 255, 255, 0.2);
		border-radius: 4px;
	}
	
	:global(.overflow-y-auto::-webkit-scrollbar-thumb:hover) {
		background: rgba(255, 255, 255, 0.3);
	}
</style>
