<script lang="ts">
	import { browser } from '$app/environment';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import {
		Bot,
		Send,
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
	import { AssistenteService, type StreamEvent } from '$lib/services/assistente.service';
	import { assistenteUIService } from '$lib/services/assistente-ui.service';
	import { authStore } from '$lib/stores/auth';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { fly } from 'svelte/transition';
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
		erroDetalhes?: string | null;
		expanded?: boolean;
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
	let turmasModalDisciplina: DisciplinaUI | null = null;

	const assistente = new AssistenteService();
	const detailsCache = new Map<string, Promise<void>>();

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

	function toggleExpand(msgIndex: number, codigo: string) {
		updateDisciplina(msgIndex, codigo, (disc) => ({
			...disc,
			expanded: !disc.expanded
		}));
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
			nivel: Number(disc.nivel ?? 0),
			tipoNatureza: disc.tipoNatureza ?? null,
			creditos: Number(disc.creditos ?? 0),
			preRequisitos: []
		};
	}

	function abrirModalAdicionar(disc: DisciplinaUI) {
		if (!disc.idMateria) return;
		materiaModal = toMateriaModel(disc);
	}

	function abrirModalTurmas(disc: DisciplinaUI) {
		turmasModalDisciplina = disc;
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
					erroDetalhes: null
				}));
			} catch (error) {
				const msg = error instanceof Error ? error.message : 'Erro ao buscar detalhes';
				updateDisciplina(msgIndex, codigo, (disc) => ({
					...disc,
					carregandoDetalhes: false,
					erroDetalhes: msg
				}));
			}
		})();

		detailsCache.set(key, job);
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
										carregandoDetalhes: true,
										erroDetalhes: null,
										expanded: false
									} satisfies DisciplinaUI
								];

								historico[assistenteIndex] = { ...current, disciplinas };
								historico = [...historico];
								void enriquecerDisciplina(assistenteIndex, event.data.codigo, matrizCurricular);
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
/>

<AnimatedBackground />

<div class="relative z-10 mx-auto w-full max-w-none px-3 py-4 sm:px-4 sm:py-8 lg:px-8 h-[calc(100vh-88px)] sm:h-[calc(100vh-100px)] flex flex-col">
	<!-- Header -->
	<div class="mb-6">
		<div class="flex items-center gap-3">
			<div class="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-pink-500 to-purple-600">
				<Sparkles class="h-6 w-6 text-white" />
			</div>
			<div>
				<h1 class="text-2xl font-bold text-white">Darcy AI</h1>
				<p class="text-gray-300 text-sm">Powered by Maritaca AI</p>
			</div>
		</div>
	</div>

	<!-- Banner de orientações -->
	<div class="mb-3 sm:mb-4 rounded-xl border border-white/10 bg-black/40 px-3 py-2.5 sm:px-4 sm:py-3 text-xs sm:text-sm text-gray-200">
		<p class="font-semibold text-gray-100 mb-0.5 sm:mb-1">Como usar o Darcy AI</p>
		<p class="text-gray-300">
			Envie só <span class="font-semibold">tópicos de interesse</span> (ex.: "IA e visão computacional"). Evite papo paralelo:
			perguntas diretas geram <span class="font-semibold">melhores sugestões de disciplinas</span>.
		</p>
		<button
			type="button"
			class="mt-2.5 w-full text-left rounded-lg border border-fuchsia-400/35 bg-fuchsia-500/10 hover:bg-fuchsia-500/20 px-3 py-2 transition-colors"
			on:click={pedirOptativasDoCurso}
		>
			<p class="text-fuchsia-100 font-semibold text-xs sm:text-sm">
				✨ Recomende matérias optativas baseado no meu curso
			</p>
			<p class="text-fuchsia-100/80 text-[11px] sm:text-xs mt-0.5">
				Usa sua matriz curricular para sugerir optativas alinhadas ao seu curso.
			</p>
		</button>
	</div>

	<!-- Chat Container -->
	<div class="flex-1 chat-shell rounded-2xl overflow-hidden flex flex-col">
		<!-- Mensagens -->
		<div class="flex-1 overflow-y-auto p-6 space-y-4">
			{#if historico.length === 0}
				<div class="h-full flex flex-col items-center justify-center text-center">
					<Bot class="h-16 w-16 text-pink-400 mb-4 opacity-50" />
					<h2 class="text-xl font-semibold text-white mb-2">Como posso ajudar?</h2>
					<div class="mt-6 grid grid-cols-2 sm:grid-cols-3 gap-2 sm:gap-3 max-w-2xl">
					<button
						on:click={() => { mensagem = 'Direito Constitucional e Teoria da Constituição'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">⚖️ Direito Constitucional</p>
					</button>

					<button
						on:click={() => { mensagem = 'História da África: Sociedades Pré-Coloniais e Processos de Independência'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🌍 História da África</p>
					</button>

					<button
						on:click={() => { mensagem = 'Inteligência Artificial: Aprendizado de Máquina e Redes Neurais'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🤖 Inteligência Artificial</p>
					</button>

					<button
						on:click={() => { mensagem = 'Bioética e Saúde Coletiva no Sistema Único de Saúde'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">🦠 Microbiologia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Macroeconomia: Modelos de Crescimento e Políticas Monetárias'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">📈 Macroeconomia</p>
					</button>

					<button
						on:click={() => { mensagem = 'Cálculo Diferencial e Integral para Engenharia'; enviarMensagem(); }}
							class="chat-suggestion px-3 py-2 sm:p-3 rounded-lg transition-colors text-left text-xs sm:text-sm"
					>
						<p class="text-white">⚛️ Física Quântica</p>
					</button>
				</div>
				</div>
			{:else}
				{#each historico as msg, msgIndex}
					<div class="flex {msg.tipo === 'usuario' ? 'justify-end' : 'justify-start'}">
						<div class={msg.tipo === 'usuario' ? 'max-w-[80%]' : 'w-full lg:max-w-[980px]'}>
							{#if msg.tipo === 'usuario'}
								<div class="bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-2xl px-4 py-3">
									<p class="whitespace-pre-wrap">{msg.texto}</p>
								</div>
							{:else}
								<div
									class={msg.disciplinas && msg.disciplinas.length > 0
										? 'assistant-list-shell'
										: 'assistant-bubble rounded-2xl px-4 py-3'}
								>
									<!-- Só mostra o texto se NÃO houver disciplinas -->
									{#if !msg.disciplinas || msg.disciplinas.length === 0}
										<p class="text-white whitespace-pre-wrap">{msg.texto}</p>
									{/if}
									
									{#if msg.disciplinas && msg.disciplinas.length > 0}
										<!-- Título apenas para disciplinas -->
										<p class="text-white font-semibold mb-3">
											🎓 {msg.disciplinas.length} {msg.disciplinas.length === 1 ? 'disciplina encontrada' : 'disciplinas encontradas'}
										</p>
										<div class="mt-4 space-y-3">
											{#each msg.disciplinas as disc, discIndex (`${msgIndex}-${disc.codigo}-${discIndex}`)}
												<div class="assistant-card rounded-xl p-3 sm:p-4" transition:fly={{ y: 20, duration: 300 }}>
													<div class="flex items-start justify-between gap-2">
														<div>
															<p class="text-amber-300 font-semibold text-xs tracking-wide">{disc.codigo}</p>
															<p class="text-white font-semibold text-base leading-tight">{disc.nome}</p>
														</div>
														<button
															type="button"
															class="text-white/60 hover:text-white transition-colors"
															on:click={() => toggleExpand(msgIndex, disc.codigo)}
															aria-label={disc.expanded ? 'Recolher card' : 'Expandir card'}
														>
															<ChevronDown
																class={disc.expanded
																	? 'h-4 w-4 transition-transform rotate-180'
																	: 'h-4 w-4 transition-transform'}
															/>
														</button>
													</div>

													<div class="mt-2 flex items-center justify-between gap-3">
														<div class="flex flex-wrap gap-2 text-[11px]">
															{#if disc.creditos != null && disc.creditos > 0}
																<span class="tag-chip">{disc.creditos} créditos</span>
															{/if}
															{#if disc.departamento}
																<span class="tag-chip">{disc.departamento}</span>
															{/if}
															{#if disc.tipoNatureza === 1}
																<span class="tag-chip text-amber-200 border-amber-300/30">optativa</span>
															{/if}
														</div>
														<div class="flex items-baseline gap-1 text-emerald-300">
															<span class="text-xl font-bold leading-none">{disc.nota}</span>
															<span class="text-xs text-emerald-200/80">/10</span>
														</div>
													</div>

													{#if disc.justificativa}
														<div class="mt-3 rounded-md border border-emerald-400/30 bg-emerald-500/10 px-3 py-2">
															<p class="text-[11px] font-semibold text-emerald-200/90 mb-0.5">Por que recomenda:</p>
															<p class="text-sm text-emerald-50/90">{disc.justificativa}</p>
														</div>
													{/if}

													{#if disc.expanded}
														<div class="mt-3 space-y-2">
															{#if disc.carregandoDetalhes}
																<div class="flex items-center gap-2 text-xs text-white/65">
																	<Loader2 class="h-3.5 w-3.5 animate-spin" />
																	Carregando pré-requisitos e turmas...
																</div>
															{:else if disc.erroDetalhes}
																<p class="text-xs text-red-300/90">{disc.erroDetalhes}</p>
															{/if}

															{#if disc.prerequisitos && disc.prerequisitos.length > 0}
																<div>
																	<p class="text-xs text-white/60 mb-1">Pré-requisitos:</p>
																	<div class="flex flex-wrap gap-1.5">
																		{#each disc.prerequisitos as req}
																			<span class="req-chip">{req}</span>
																		{/each}
																	</div>
																</div>
															{/if}

															{#if disc.prerequisitosExpressoes && disc.prerequisitosExpressoes.length > 0}
																<div class="space-y-2">
																	<p class="text-xs text-white/60 mb-1">Expressão de pré-requisito:</p>
																	{#each disc.prerequisitosExpressoes as expr}
																		<div class="rounded-lg border border-purple-300/25 bg-purple-500/10 px-2.5 py-2">
																			{#each expr.grupos as group, gi}
																				<div class="flex flex-wrap items-center gap-1.5">
																					{#each group as item, ii}
																						<span class="req-chip">{item}</span>
																						{#if ii < group.length - 1}
																							<span class="text-[10px] font-bold uppercase tracking-wide text-purple-200/85">E</span>
																						{/if}
																					{/each}
																				</div>
																				{#if gi < expr.grupos.length - 1}
																					<div class="my-1 text-[10px] font-extrabold uppercase tracking-[0.12em] text-purple-200/80">OU</div>
																				{/if}
																			{/each}
																			{#if expr.expressaoOriginal}
																				<p class="mt-1 text-[11px] text-purple-100/75">{expr.expressaoOriginal}</p>
																			{/if}
																		</div>
																	{/each}
																</div>
															{/if}
														</div>
													{/if}

													<div class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2">
														<button
															type="button"
															class="assistant-action-btn"
															on:click={() => abrirModalAdicionar(disc)}
															disabled={!disc.idMateria}
														>
															<Plus class="h-4 w-4" />
															Adicionar
														</button>
														<button
															type="button"
															class="assistant-action-btn secondary"
															on:click={() => abrirModalTurmas(disc)}
															disabled={!disc.idMateria || disc.carregandoDetalhes}
														>
															<BookOpen class="h-4 w-4" />
															Ver Turmas
														</button>
													</div>
												</div>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
						</div>
					</div>
				{/each}
			{/if}
			
			{#if carregando}
				<div class="flex justify-start">
					<div class="assistant-bubble rounded-2xl px-4 py-3">
						<div class="flex items-center gap-2 text-gray-400">
							<Loader2 class="h-4 w-4 animate-spin" />
							<span>{etapaAtual || 'Pensando...'}</span>
						</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Input -->
		<div class="border-t border-white/10 p-2.5 sm:p-3">
			<form on:submit|preventDefault={enviarMensagem} class="flex gap-1.5 items-center">
				<input
					type="text"
					bind:value={mensagem}
					on:keypress={handleKeyPress}
					placeholder="Só tópicos de interesse (ex: IA aplicada a saúde)..."
					disabled={carregando}
					class="flex-1 bg-black/50 border border-white/20 rounded-full px-3 py-2.5 text-sm text-white placeholder-gray-300 focus:outline-none focus:ring-2 focus:ring-pink-500/50 disabled:opacity-50"
				/>
				<button
					type="submit"
					disabled={!mensagem.trim() || carregando}
					class="shrink-0 bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-full px-3 sm:px-4 py-2 text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5 shadow-md shadow-pink-500/30"
				>
					{#if carregando}
						<Loader2 class="h-5 w-5 animate-spin" />
					{:else}
						<Send class="h-5 w-5" />
					{/if}
					<span class="hidden sm:inline">Enviar</span>
				</button>
			</form>
		</div>
	</div>
</div>

{#if materiaModal}
	<OptativaTipoModal
		materia={materiaModal}
		defaultSemestre={Math.max(1, Number(authStore.getUser()?.dadosFluxograma?.semestreAtual ?? 1))}
		ondecidir={(tipo, semestreFuturo) => {
			if (!materiaModal) return;
			if (tipo === 'futura') {
				fluxogramaStore.addOptativa(materiaModal, semestreFuturo ?? 1);
			} else {
				fluxogramaStore.registrarOptativaConcluida(materiaModal);
			}
			materiaModal = null;
		}}
		onpular={() => {
			materiaModal = null;
		}}
	/>
{/if}

{#if turmasModalDisciplina}
	<div class="fixed inset-0 z-[500] flex items-center justify-center bg-black/60 p-3 backdrop-blur-sm">
		<div class="w-full max-w-3xl rounded-2xl border border-white/15 bg-slate-950/95 shadow-2xl">
			<div class="flex items-start justify-between border-b border-white/10 px-5 py-4">
				<div>
					<h3 class="text-white font-semibold text-lg">Turmas Disponíveis</h3>
					<p class="text-white/70 text-sm">
						{turmasModalDisciplina.codigo} - {turmasModalDisciplina.nome}
					</p>
					<p class="text-xs text-white/55 mt-1">
						Última atualização: {formatDate(turmasModalDisciplina.ultimaAtualizacaoTurmas)}
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
				{#if !turmasModalDisciplina.turmas || turmasModalDisciplina.turmas.length === 0}
					<p class="text-sm text-white/60">Nenhuma turma encontrada para esta disciplina.</p>
				{:else}
					{#each turmasModalDisciplina.turmas as turma}
						<div class="rounded-xl border border-white/10 bg-white/[0.06] p-5">
							<div class="flex flex-wrap items-start justify-between gap-4">
								<p class="text-[1.08rem] font-bold text-blue-300">
									Turma {turma.turma || '-'} - {turma.anoPeriodo || '-'}
								</p>
								<p class="text-sm">
									<span class="text-white/80">Vagas sobrando:</span>
									<span class="ml-1 text-white font-black text-lg">
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
													<p class="text-white/90 font-semibold">
														{linha.dia}
														<span class="text-white/70">({linha.faixas.join(' | ')})</span>
													</p>
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
	}

	.assistant-list-shell {
		width: 100%;
	}

	.tag-chip {
		background: rgba(148, 163, 184, 0.15);
		border: 1px solid rgba(148, 163, 184, 0.24);
		color: rgba(226, 232, 240, 0.92);
		padding: 2px 8px;
		border-radius: 9999px;
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
		gap: 6px;
		border-radius: 10px;
		background: linear-gradient(135deg, rgba(236, 72, 153, 0.85), rgba(168, 85, 247, 0.85));
		color: #fff;
		padding: 8px 12px;
		font-size: 0.875rem;
		font-weight: 600;
		border: 1px solid rgba(255, 255, 255, 0.18);
	}

	.assistant-action-btn.secondary {
		background: rgba(15, 23, 42, 0.8);
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
