/**
 * Grade Store — Montador de Grade v2.
 * Store baseado em runes (Svelte 5) que gerencia:
 *  - um **pool** de matérias candidatas (recomendadas ∪ buscadas ∪ vindas do chat);
 *  - **cenários** nomeados (simular grades diferentes), cada um com sua seleção;
 *  - bloqueio de conflito de horário, montagem automática e persistência em
 *    localStorage por usuário + período.
 */
import {
	hasConflict,
	autoMontarGrade,
	slotMaskFromHorario,
	turmaRespeitaTurnos,
	maskDosTurnos,
	type TurmaComMask,
	type Turno
} from '$lib/utils/horario-slots';
import type { TurmaOferta } from '$lib/services/turmas.service';

export interface MateriaGrade {
	codigo: string;
	nome: string;
	creditos: number;
	idMateria: number;
	/**
	 * Turmas ofertadas para a matéria, já com máscara de horário. `codigoOfertado` vem
	 * preenchido quando a matéria mudou de código e a turma está publicada sob outro —
	 * é nesse código que o aluno se matricula.
	 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
	 */
	turmas: Array<TurmaComMask<TurmaOferta> & { codigoOfertado?: string }>;
	/** Aviso quando o aluno ainda não satisfaz os pré-requisitos (não bloqueia). */
	avisoPreRequisito?: string | null;
	/** Códigos de co-requisitos (matérias que precisam ser cursadas juntas). */
	coRequisitos?: string[];
	/**
	 * Natureza na matriz do aluno — é o que faz `montarAutomatico` preferir
	 * obrigatória a optativa quando as duas disputam o mesmo horário. Ausente
	 * (`undefined`) quando quem montou a matéria não resolveu a matriz; nesse caso
	 * a montagem trata como optativa, que é o comportamento antigo.
	 */
	natureza?: 'obrigatoria' | 'optativa' | 'modulo_livre';
}

interface Cenario {
	id: string;
	nome: string;
	/** código da matéria → id_turmas selecionado. */
	selecao: Record<string, number>;
}

export interface SelecaoResultado {
	ok: boolean;
	/** Código da matéria já selecionada que impediu a troca, se houve conflito. */
	conflitaCom: string | null;
}

export interface MontagemResultado {
	naoAlocadas: string[];
	/** A busca parou no teto de nós: grade válida, mas talvez não a melhor possível. */
	truncado: boolean;
}

/**
 * Escada de prioridade da montagem automática.
 *
 * `autoMontarGrade` maximiza a SOMA dos pesos, então a razão entre dois degraus é
 * o que decide quantas matérias do degrau de baixo valem uma do degrau de cima.
 * Com fator 1000 entre eles a ordem é, na prática, lexicográfica: nenhum pool real
 * (dezenas de matérias) chega perto de somar mil optativas para roubar o lugar de
 * uma obrigatória. Encaixar optativa no buraco que sobra continua valendo — ela
 * sempre soma, só nunca desloca quem está acima.
 *
 * Por que nesta ordem:
 * - `CURSANDO`: a matrícula já aconteceu. Tirá-la da grade não desmatricula
 *   ninguém, só esconde a matéria do aluno.
 * - `PRIORITARIA`: o aluno marcou a estrela. Escolha explícita ganha de heurística
 *   nossa — senão a estrela numa optativa não serviria para nada.
 * - `OBRIGATORIA`: é o que atrasa formatura quando fica de fora. Era justamente o
 *   degrau que não existia: obrigatória e optativa saíam ambas com peso 1 e a
 *   montagem virava um maximizador de contagem.
 */
const PESO_CURSANDO = 1_000_000_000;
const PESO_PRIORITARIA = 1_000_000;
const PESO_OBRIGATORIA = 1_000;
const PESO_PADRAO = 1;

/** Docentes comparáveis: sem espaços redundantes, caixa alta. */
function normDocente(nome: string | null | undefined): string {
	return (nome ?? '').trim().replace(/\s+/g, ' ').toUpperCase();
}

/** Paleta dark-mode, uma cor estável por matéria (por ordem no pool). */
export const MATERIA_CORES: ReadonlyArray<{ cell: string; dot: string; text: string }> = [
	{ cell: 'bg-purple-500/25 border-purple-400/50', dot: 'bg-purple-400', text: 'text-purple-100' },
	{ cell: 'bg-sky-500/25 border-sky-400/50', dot: 'bg-sky-400', text: 'text-sky-100' },
	{
		cell: 'bg-emerald-500/25 border-emerald-400/50',
		dot: 'bg-emerald-400',
		text: 'text-emerald-100'
	},
	{ cell: 'bg-amber-500/25 border-amber-400/50', dot: 'bg-amber-400', text: 'text-amber-100' },
	{ cell: 'bg-pink-500/25 border-pink-400/50', dot: 'bg-pink-400', text: 'text-pink-100' },
	{ cell: 'bg-cyan-500/25 border-cyan-400/50', dot: 'bg-cyan-400', text: 'text-cyan-100' },
	{ cell: 'bg-orange-500/25 border-orange-400/50', dot: 'bg-orange-400', text: 'text-orange-100' },
	{ cell: 'bg-teal-500/25 border-teal-400/50', dot: 'bg-teal-400', text: 'text-teal-100' }
];

function novoId(): string {
	if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
	return `g-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

function poolKey(idUser: number | null, periodo: string | null): string | null {
	return idUser != null && periodo ? `nofluxo:grade:${idUser}:${periodo}:pool` : null;
}
function cenariosKey(idUser: number | null, periodo: string | null): string | null {
	return idUser != null && periodo ? `nofluxo:grade:${idUser}:${periodo}:cenarios` : null;
}

/** Lê (fora do store) os códigos do pool salvo — a página usa p/ rehidratar turmas. */
export function lerPoolSalvo(idUser: number | null, periodo: string): string[] {
	const key = poolKey(idUser, periodo);
	if (!key || typeof localStorage === 'undefined') return [];
	try {
		const arr = JSON.parse(localStorage.getItem(key) ?? '[]');
		return Array.isArray(arr) ? arr.filter((x): x is string => typeof x === 'string') : [];
	} catch {
		return [];
	}
}

/** Códigos removidos pelo aluno — a página exclui do re-semeio do recomendado. */
export function lerRemovidasSalvo(idUser: number | null, periodo: string): string[] {
	const key = cenariosKey(idUser, periodo);
	if (!key || typeof localStorage === 'undefined') return [];
	try {
		const obj = JSON.parse(localStorage.getItem(key) ?? '{}');
		return Array.isArray(obj?.removidas)
			? obj.removidas.filter((x: unknown): x is string => typeof x === 'string')
			: [];
	} catch {
		return [];
	}
}

function createGradeStore() {
	let pool = $state<MateriaGrade[]>([]);
	let grades = $state<Cenario[]>([]);
	let activeId = $state<string>('');
	let idUser = $state<number | null>(null);
	let periodo = $state<string | null>(null);
	let ultimaMontagem = $state<MontagemResultado | null>(null);
	/** Matéria sob o mouse (lista/resumo) — o calendário destaca os blocos dela. */
	let hoverCodigo = $state<string | null>(null);
	/** Códigos priorizados: a montagem automática tenta encaixá-los primeiro. */
	let prioritarias = $state<Set<string>>(new Set());
	/** Turnos permitidos ao montar a grade (M/T/N). Os 3 = sem filtro. */
	let turnosPermitidos = $state<Set<Turno>>(new Set<Turno>(['M', 'T', 'N']));
	/** Códigos que o aluno removeu — não voltam ao re-semear o recomendado. */
	let removidas = $state<Set<string>>(new Set());
	/**
	 * Professor obrigatório por matéria, confirmado numa sessão anterior (vem do
	 * banco — tabela `preferencias_grade`) e reaplicado em toda montagem automática,
	 * não só na que veio do chat. Quem carrega é a rota (`definirDocentesPersistidos`);
	 * o store só guarda e usa como filtro rígido.
	 */
	let docentesPersistidos = $state<Record<string, string>>({});
	/**
	 * Códigos que o aluno já está cursando agora (fora do pool "próximo semestre" —
	 * vem do fluxograma atual). Entram na lista sozinhos pra não conflitar com o que
	 * o aluno for adicionar, mas sem turma pré-escolhida — o app não sabe qual é a
	 * turma real. Quem define é a rota (`definirCursandoAtual`), logo depois do init.
	 */
	let cursandoAtual = $state<Set<string>>(new Set());
	/**
	 * Códigos travados: `montarAutomatico` nunca reatribui a turma deles, só ocupa o
	 * horário pras outras matérias otimizarem em volta. Uma matéria de `cursandoAtual`
	 * trava sozinha assim que o aluno escolhe a turma real dela (`selecionarTurma`) —
	 * sem isso, "Montar grade" poderia trocar a turma de uma matéria que ele já está
	 * cursando de verdade, o que não faz sentido (a matrícula real já aconteceu).
	 */
	let travadas = $state<Set<string>>(new Set());

	const indicePorCodigo = $derived.by(() => {
		const m = new Map<string, number>();
		pool.forEach((mat, i) => m.set(mat.codigo, i));
		return m;
	});

	const cenarioAtivo = $derived(grades.find((g) => g.id === activeId) ?? null);

	/** Seleção do cenário ativo, resolvida contra o pool (código → turma). */
	const selecaoAtiva = $derived.by(() => {
		const map = new Map<string, TurmaComMask<TurmaOferta>>();
		if (!cenarioAtivo) return map;
		for (const [codigo, idTurma] of Object.entries(cenarioAtivo.selecao)) {
			const mat = pool.find((m) => m.codigo === codigo);
			const tg = mat?.turmas.find((t) => t.turma.id_turmas === idTurma);
			if (tg) map.set(codigo, tg);
		}
		return map;
	});

	const combinedMask = $derived.by(() => {
		let mask = 0n;
		for (const t of selecaoAtiva.values()) mask |= t.mask;
		return mask;
	});

	const ocupacao = $derived.by(() => {
		const map = new Map<number, string>();
		for (const [codigo, t] of selecaoAtiva) {
			let mask = t.mask;
			let i = 0;
			while (mask > 0n) {
				if (mask & 1n) map.set(i, codigo);
				mask >>= 1n;
				i++;
			}
		}
		return map;
	});

	const creditosSelecionados = $derived.by(() => {
		let total = 0;
		for (const codigo of selecaoAtiva.keys()) {
			total += pool.find((m) => m.codigo === codigo)?.creditos ?? 0;
		}
		return total;
	});

	function persistPool(): void {
		const key = poolKey(idUser, periodo);
		if (!key || typeof localStorage === 'undefined') return;
		localStorage.setItem(key, JSON.stringify(pool.map((m) => m.codigo)));
	}
	function persistCenarios(): void {
		const key = cenariosKey(idUser, periodo);
		if (!key || typeof localStorage === 'undefined') return;
		localStorage.setItem(
			key,
			JSON.stringify({
				grades,
				activeId,
				prioritarias: [...prioritarias],
				turnos: [...turnosPermitidos],
				removidas: [...removidas]
			})
		);
	}

	/** Remove seleções cuja turma sumiu do pool ou que passaram a conflitar. */
	function reconciliar(sel: Record<string, number>): Record<string, number> {
		const out: Record<string, number> = {};
		let acc = 0n;
		for (const [codigo, idTurma] of Object.entries(sel)) {
			const tg = pool
				.find((m) => m.codigo === codigo)
				?.turmas.find((t) => t.turma.id_turmas === idTurma);
			if (tg && !hasConflict(tg.mask, acc)) {
				out[codigo] = idTurma;
				acc |= tg.mask;
			}
		}
		return out;
	}

	/** Atualiza a seleção do cenário ativo de forma imutável (dispara reatividade). */
	function updateAtivo(fn: (sel: Record<string, number>) => Record<string, number>): void {
		grades = grades.map((g) => (g.id === activeId ? { ...g, selecao: fn(g.selecao) } : g));
		ultimaMontagem = null;
		persistCenarios();
	}

	/** Máscara das turmas do cenário ativo, exceto a da matéria informada. */
	function maskExcluindo(codigo: string): bigint {
		let mask = 0n;
		for (const [c, t] of selecaoAtiva) if (c !== codigo) mask |= t.mask;
		return mask;
	}

	return {
		get pool() {
			return pool;
		},
		get grades() {
			return grades;
		},
		get activeId() {
			return activeId;
		},
		get cenarioAtivo() {
			return cenarioAtivo;
		},
		get selecao() {
			return selecaoAtiva;
		},
		get combinedMask() {
			return combinedMask;
		},
		/** Slots livres = universo dos turnos permitidos menos o que já está selecionado. */
		get freeMask(): bigint {
			return maskDosTurnos(turnosPermitidos) & ~combinedMask;
		},
		get ocupacao() {
			return ocupacao;
		},
		get creditosSelecionados() {
			return creditosSelecionados;
		},
		get ultimaMontagem() {
			return ultimaMontagem;
		},
		get hoverCodigo() {
			return hoverCodigo;
		},

		setHover(codigo: string | null): void {
			hoverCodigo = codigo;
		},

		isPrioritaria(codigo: string): boolean {
			return prioritarias.has(codigo);
		},

		/** Marca/desmarca a matéria como prioritária na montagem automática. */
		togglePrioridade(codigo: string): void {
			const next = new Set(prioritarias);
			if (next.has(codigo)) next.delete(codigo);
			else next.add(codigo);
			prioritarias = next;
			persistCenarios();
		},

		get temPrioritarias() {
			return prioritarias.size > 0;
		},

		/**
		 * Docentes distintos que oferecem a matéria, em ordem alfabética — usado pelo
		 * botão "Perguntar pra Darcy" pra o aluno escolher um nome real em vez de
		 * digitar de cabeça.
		 */
		docentesDe(codigo: string): string[] {
			const mat = pool.find((m) => m.codigo === codigo);
			if (!mat) return [];
			const vistos = new Map<string, string>();
			for (const t of mat.turmas) {
				const nome = (t.turma.docente ?? '').trim();
				if (nome) vistos.set(nome.toUpperCase(), nome);
			}
			return [...vistos.values()].sort((a, b) => a.localeCompare(b, 'pt-BR'));
		},

		get docentesPersistidos() {
			return docentesPersistidos;
		},

		/** Carrega as preferências de professor confirmadas antes (vêm do banco). */
		definirDocentesPersistidos(mapa: Record<string, string>): void {
			docentesPersistidos = mapa;
		},

		/** Foto da seleção atual — pra poder voltar se o aluno recusar um rearranjo. */
		snapshotSelecao(): Record<string, number> {
			return { ...(cenarioAtivo?.selecao ?? {}) };
		},

		/** Restaura uma seleção tirada por `snapshotSelecao`. */
		restaurarSelecao(snapshot: Record<string, number>): void {
			updateAtivo(() => ({ ...snapshot }));
		},

		get turnosPermitidos() {
			return turnosPermitidos;
		},

		/**
		 * Códigos que o aluno tirou da lista na mão. Exposto porque quem re-semeia o
		 * pool (a rota, ao montar a grade automaticamente) precisa respeitar essa
		 * escolha — `addMateriaAoPool` limpa a marca, então filtrar é com o chamador.
		 */
		get removidas() {
			return removidas;
		},

		/** Filtro de turno ativo (1 ou 2 turnos selecionados; 0 ou 3 = sem filtro). */
		get temFiltroTurno() {
			return turnosPermitidos.size > 0 && turnosPermitidos.size < 3;
		},

		/** Liga/desliga um turno; nunca deixa os 3 desligados. */
		toggleTurno(t: Turno): void {
			const next = new Set(turnosPermitidos);
			if (next.has(t)) {
				if (next.size > 1) next.delete(t);
			} else {
				next.add(t);
			}
			turnosPermitidos = next;
			persistCenarios();
		},

		/** Define diretamente os turnos permitidos (usado pelo chat). Vazio = todos. */
		setTurnos(turnos: string[]): void {
			const validos = turnos
				.map((t) => t.trim().toUpperCase())
				.filter((t): t is Turno => t === 'M' || t === 'T' || t === 'N');
			turnosPermitidos = new Set<Turno>(validos.length > 0 ? validos : ['M', 'T', 'N']);
			persistCenarios();
		},

		/** Co-requisitos da matéria que NÃO estão na grade atual (só p/ selecionadas). */
		coReqsFaltando(codigo: string): string[] {
			const mat = pool.find((m) => m.codigo === codigo);
			if (!mat?.coRequisitos?.length || !selecaoAtiva.has(codigo)) return [];
			const naGrade = new Set([...selecaoAtiva.keys()].map((c) => c.toUpperCase()));
			return mat.coRequisitos.filter((c) => !naGrade.has(c.trim().toUpperCase()));
		},

		/** Carrega o pool e restaura cenários salvos (ou cria "Grade 1"). */
		init(poolInicial: MateriaGrade[], ctx: { idUser: number | null; periodo: string }): void {
			pool = poolInicial;
			idUser = ctx.idUser;
			periodo = ctx.periodo;
			ultimaMontagem = null;

			const key = cenariosKey(idUser, periodo);
			let restaurado: {
				grades: Cenario[];
				activeId: string;
				prioritarias?: string[];
				turnos?: Turno[];
				removidas?: string[];
			} | null = null;
			if (key && typeof localStorage !== 'undefined') {
				try {
					const raw = localStorage.getItem(key);
					if (raw) restaurado = JSON.parse(raw);
				} catch {
					restaurado = null;
				}
			}

			prioritarias = new Set(
				Array.isArray(restaurado?.prioritarias) ? restaurado!.prioritarias : []
			);
			turnosPermitidos = new Set<Turno>(
				Array.isArray(restaurado?.turnos) && restaurado!.turnos.length > 0
					? restaurado!.turnos
					: ['M', 'T', 'N']
			);
			removidas = new Set(Array.isArray(restaurado?.removidas) ? restaurado!.removidas : []);

			if (restaurado && Array.isArray(restaurado.grades) && restaurado.grades.length > 0) {
				grades = restaurado.grades.map((g) => ({
					id: g.id,
					nome: g.nome,
					selecao: reconciliar(g.selecao ?? {})
				}));
				activeId = grades.some((g) => g.id === restaurado!.activeId)
					? restaurado.activeId
					: grades[0].id;
			} else {
				const id = novoId();
				grades = [{ id, nome: 'Grade 1', selecao: {} }];
				activeId = id;
			}

			persistPool();
			persistCenarios();
		},

		hasMateria(codigo: string): boolean {
			return pool.some((m) => m.codigo === codigo);
		},

		/** Adiciona uma matéria (com turmas) ao pool, se ainda não estiver lá. */
		addMateriaAoPool(materia: MateriaGrade): void {
			if (pool.some((m) => m.codigo === materia.codigo)) return;
			pool = [...pool, materia];
			if (removidas.has(materia.codigo)) {
				const nr = new Set(removidas);
				nr.delete(materia.codigo);
				removidas = nr;
			}
			persistPool();
			persistCenarios();
		},

		/** Remove a matéria do pool: tira das seleções, prioridade e não volta no reload. */
		removerMateriaDoPool(codigo: string): void {
			pool = pool.filter((m) => m.codigo !== codigo);
			grades = grades.map((g) => {
				if (!(codigo in g.selecao)) return g;
				const { [codigo]: _omit, ...rest } = g.selecao;
				return { ...g, selecao: rest };
			});
			if (prioritarias.has(codigo)) {
				const np = new Set(prioritarias);
				np.delete(codigo);
				prioritarias = np;
			}
			if (cursandoAtual.has(codigo)) {
				const nc = new Set(cursandoAtual);
				nc.delete(codigo);
				cursandoAtual = nc;
			}
			if (travadas.has(codigo)) {
				const nt = new Set(travadas);
				nt.delete(codigo);
				travadas = nt;
			}
			const nr = new Set(removidas);
			nr.add(codigo);
			removidas = nr;
			ultimaMontagem = null;
			persistPool();
			persistCenarios();
		},

		corDaMateria(codigo: string) {
			const i = indicePorCodigo.get(codigo) ?? 0;
			return MATERIA_CORES[i % MATERIA_CORES.length];
		},

		turmaSelecionada(codigo: string): TurmaComMask<TurmaOferta> | undefined {
			return selecaoAtiva.get(codigo);
		},

		podeSelecionar(codigo: string, tg: TurmaComMask<TurmaOferta>): boolean {
			return !hasConflict(tg.mask, maskExcluindo(codigo));
		},

		conflitaCom(codigo: string, tg: TurmaComMask<TurmaOferta>): string | null {
			for (const [c, t] of selecaoAtiva) {
				if (c === codigo) continue;
				if (hasConflict(tg.mask, t.mask)) return c;
			}
			return null;
		},

		/**
		 * Seleciona/troca a turma; retorna feedback de conflito p/ o "tenta inserir".
		 * Matéria de `cursandoAtual` trava sozinha aqui: assim que o aluno escolhe a
		 * turma real dele, "Montar grade" para de poder reatribuir essa matéria.
		 */
		selecionarTurma(codigo: string, idTurma: number): SelecaoResultado {
			const tg = pool
				.find((m) => m.codigo === codigo)
				?.turmas.find((t) => t.turma.id_turmas === idTurma);
			if (!tg) return { ok: false, conflitaCom: null };
			const conflito = this.conflitaCom(codigo, tg);
			if (conflito) return { ok: false, conflitaCom: conflito };
			updateAtivo((sel) => ({ ...sel, [codigo]: idTurma }));
			if (cursandoAtual.has(codigo) && !travadas.has(codigo)) {
				travadas = new Set([...travadas, codigo]);
			}
			return { ok: true, conflitaCom: null };
		},

		/** Tira a turma escolhida — e destrava, se era uma matéria travada. */
		removerTurma(codigo: string): void {
			updateAtivo((sel) => {
				const { [codigo]: _omit, ...rest } = sel;
				return rest;
			});
			if (travadas.has(codigo)) {
				const nt = new Set(travadas);
				nt.delete(codigo);
				travadas = nt;
			}
		},

		isCursandoAtual(codigo: string): boolean {
			return cursandoAtual.has(codigo);
		},

		isTravada(codigo: string): boolean {
			return travadas.has(codigo);
		},

		/**
		 * Marca quais códigos do pool já são matérias que o aluno está cursando agora
		 * — a rota chama isso logo depois do `init`. Se a turma já estava escolhida
		 * (restaurada do localStorage), trava de novo — sem isso a trava se perderia
		 * a cada reload mesmo com a seleção intacta.
		 */
		definirCursandoAtual(codigos: Iterable<string>): void {
			cursandoAtual = new Set([...codigos].map((c) => c.trim().toUpperCase()));
			const jaEscolhidas = [...cursandoAtual].filter((c) => selecaoAtiva.has(c));
			if (jaEscolhidas.length > 0) travadas = new Set([...travadas, ...jaEscolhidas]);
		},

		/** Destrava manualmente — o aluno quer que "Montar grade" mexa nessa também. */
		destravar(codigo: string): void {
			if (!travadas.has(codigo)) return;
			const nt = new Set(travadas);
			nt.delete(codigo);
			travadas = nt;
		},

		/**
		 * `docentesObrigatorios` (código → nome) é um filtro RÍGIDO, não bônus: a
		 * matéria só considera turmas daquele professor e pode ficar de fora se
		 * nenhuma bater — diferente do antigo bônus de desempate, que nunca deixava
		 * uma matéria fora por causa de preferência. Mescla com `docentesPersistidos`
		 * (confirmados numa sessão anterior); o argumento vence em caso de conflito.
		 *
		 * Matérias travadas (`travadas` — cursando agora, turma real já escolhida)
		 * ficam de fora do solver: a turma delas é fixa, só o horário conta como já
		 * ocupado pras outras otimizarem em volta (`mascaraInicial` do `autoMontarGrade`).
		 *
		 * `limiteCreditos` é o teto de créditos do semestre (o slider da tela). Sem
		 * ele a montagem enche a grade como sempre fez. Com ele, as matérias que o
		 * aluno já está cursando (`cursandoAtual`) entram primeiro e comem o
		 * orçamento — se elas sozinhas já estouram o teto, ninguém mais entra, mas
		 * nenhuma delas sai: a matrícula já aconteceu de verdade.
		 */
		montarAutomatico(opts?: {
			docentesObrigatorios?: Record<string, string>;
			limiteCreditos?: number;
		}): MontagemResultado {
			const docentesEfetivos = { ...docentesPersistidos, ...(opts?.docentesObrigatorios ?? {}) };

			const mascaraTravada = [...travadas].reduce((acc, codigo) => {
				const tg = selecaoAtiva.get(codigo);
				return tg ? acc | tg.mask : acc;
			}, 0n);

			// As travadas continuam na grade final, então o crédito delas já está gasto
			// antes do solver começar — o orçamento que sobra é o do resto.
			const creditosTravados = [...travadas].reduce((acc, codigo) => {
				if (!selecaoAtiva.has(codigo)) return acc;
				return acc + (pool.find((m) => m.codigo === codigo)?.creditos ?? 0);
			}, 0);
			const orcamento =
				opts?.limiteCreditos === undefined ? undefined : opts.limiteCreditos - creditosTravados;

			const r = autoMontarGrade(
				pool
					.filter((m) => !travadas.has(m.codigo))
					.map((m) => {
						const docenteAlvo = docentesEfetivos[m.codigo];
						// Só considera turmas dentro dos turnos permitidos e, se houver
						// professor obrigatório pra essa matéria, só as turmas dele.
						let turmas = m.turmas.filter((t) => turmaRespeitaTurnos(t.mask, turnosPermitidos));
						if (docenteAlvo) {
							const alvoNorm = normDocente(docenteAlvo);
							turmas = turmas.filter((t) => normDocente(t.turma.docente).includes(alvoNorm));
						}
						// CUIDADO com o nome: o campo `obrigatoria` de `MateriaTurmas` NÃO é
						// "obrigatória da matriz" — é "não pode ser barrada pelo teto de
						// créditos", e isso só vale para a matrícula que já aconteceu. A
						// natureza da matriz entra pelo `peso`, logo abaixo.
						const matriculaReal = cursandoAtual.has(m.codigo);
						return {
							chave: m.codigo,
							turmas,
							creditos: m.creditos,
							obrigatoria: matriculaReal,
							peso: matriculaReal
								? PESO_CURSANDO
								: prioritarias.has(m.codigo)
									? PESO_PRIORITARIA
									: m.natureza === 'obrigatoria'
										? PESO_OBRIGATORIA
										: PESO_PADRAO
						};
					}),
				mascaraTravada,
				orcamento
			);
			const novaSel: Record<string, number> = {};
			for (const codigo of travadas) {
				const tg = selecaoAtiva.get(codigo);
				if (tg) novaSel[codigo] = tg.turma.id_turmas;
			}
			for (const [codigo, t] of r.selecao) novaSel[codigo] = t.turma.id_turmas;
			grades = grades.map((g) => (g.id === activeId ? { ...g, selecao: novaSel } : g));
			ultimaMontagem = {
				naoAlocadas: r.naoAlocadas,
				truncado: r.truncado
			};
			persistCenarios();
			return ultimaMontagem;
		},

		limpar(): void {
			updateAtivo(() => ({}));
		},

		/**
		 * Tira matérias da seleção até caber em `limite` créditos — usado pelo slider
		 * de créditos: puramente aditivo em relação ao que já está selecionado, nunca
		 * roda o solver de novo (arrastar o slider não deveria trocar turmas que o
		 * aluno já escolheu, só encolher a lista).
		 *
		 * A ordem de corte é a MESMA escada de prioridade da montagem (`PESO_*`),
		 * invertida: sai primeiro a optativa, depois a obrigatória da matriz, e a
		 * prioritária só quando não sobra mais nada. Dentro de cada degrau, a de mais
		 * crédito primeiro — sai menos matéria para abrir o mesmo espaço.
		 *
		 * A natureza precisa entrar aqui também, e não só no solver: ordenar apenas por
		 * crédito cortava a obrigatória de 4 créditos e preservava duas optativas de 2,
		 * desfazendo pelo slider exatamente a priorização que a montagem tinha acabado
		 * de fazer.
		 *
		 * Matéria que o aluno já está cursando (`cursandoAtual`) nunca é candidata — o
		 * slider não desmatricula ninguém de uma matéria de matrícula já efetivada.
		 * Repare que a trava não basta pra isso: ela só nasce quando o aluno escolhe a
		 * turma real na mão, então logo depois de "Montar grade" o conjunto `travadas`
		 * está vazio e era justamente aí que o slider jogava MATR fora.
		 */
		ajustarParaLimite(limite: number): void {
			if (creditosSelecionados <= limite) return;
			/** Quanto vale manter: 0 sai primeiro, 2 sai por último. */
			const valorDe = (codigo: string): number => {
				if (prioritarias.has(codigo)) return 2;
				return pool.find((m) => m.codigo === codigo)?.natureza === 'obrigatoria' ? 1 : 0;
			};
			const candidatos = [...selecaoAtiva.keys()]
				.filter((codigo) => !travadas.has(codigo) && !cursandoAtual.has(codigo))
				.map((codigo) => ({
					codigo,
					valor: valorDe(codigo),
					creditos: pool.find((m) => m.codigo === codigo)?.creditos ?? 0
				}))
				.sort(
					(a, b) => a.valor - b.valor || b.creditos - a.creditos || a.codigo.localeCompare(b.codigo)
				);

			let atual = creditosSelecionados;
			const remover = new Set<string>();
			for (const c of candidatos) {
				if (atual <= limite) break;
				remover.add(c.codigo);
				atual -= c.creditos;
			}
			if (remover.size === 0) return;
			updateAtivo((sel) => {
				const out = { ...sel };
				for (const codigo of remover) delete out[codigo];
				return out;
			});
			ultimaMontagem = null;
		},

		// ─── Cenários ────────────────────────────────────────────────────────────
		criarCenario(nome?: string): void {
			const id = novoId();
			grades = [...grades, { id, nome: nome?.trim() || `Grade ${grades.length + 1}`, selecao: {} }];
			activeId = id;
			ultimaMontagem = null;
			persistCenarios();
		},

		renomearCenario(id: string, nome: string): void {
			grades = grades.map((g) => (g.id === id ? { ...g, nome: nome.trim() || g.nome } : g));
			persistCenarios();
		},

		removerCenario(id: string): void {
			if (grades.length <= 1) {
				// Nunca fica sem cenário: limpa o único que existe.
				grades = grades.map((g) => ({ ...g, selecao: {} }));
				ultimaMontagem = null;
				persistCenarios();
				return;
			}
			const idx = grades.findIndex((g) => g.id === id);
			grades = grades.filter((g) => g.id !== id);
			if (activeId === id) activeId = grades[Math.max(0, idx - 1)]?.id ?? grades[0].id;
			ultimaMontagem = null;
			persistCenarios();
		},

		selecionarCenario(id: string): void {
			if (grades.some((g) => g.id === id)) {
				activeId = id;
				ultimaMontagem = null;
				persistCenarios();
			}
		}
	};
}

export const gradeStore = createGradeStore();

/** Reexport utilitário para a página construir máscaras a partir do horário. */
export { slotMaskFromHorario };
