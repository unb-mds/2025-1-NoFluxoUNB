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
	type TurmaComMask,
	type Turno
} from '$lib/utils/horario-slots';
import type { TurmaOferta } from '$lib/services/turmas.service';

export interface MateriaGrade {
	codigo: string;
	nome: string;
	creditos: number;
	idMateria: number;
	/** Turmas ofertadas para a matéria, já com máscara de horário. */
	turmas: Array<TurmaComMask<TurmaOferta>>;
	/** Aviso quando o aluno ainda não satisfaz os pré-requisitos (não bloqueia). */
	avisoPreRequisito?: string | null;
	/** Códigos de co-requisitos (matérias que precisam ser cursadas juntas). */
	coRequisitos?: string[];
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
}

/** Paleta dark-mode, uma cor estável por matéria (por ordem no pool). */
export const MATERIA_CORES: ReadonlyArray<{ cell: string; dot: string; text: string }> = [
	{ cell: 'bg-purple-500/25 border-purple-400/50', dot: 'bg-purple-400', text: 'text-purple-100' },
	{ cell: 'bg-sky-500/25 border-sky-400/50', dot: 'bg-sky-400', text: 'text-sky-100' },
	{ cell: 'bg-emerald-500/25 border-emerald-400/50', dot: 'bg-emerald-400', text: 'text-emerald-100' },
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
	/** Códigos priorizados: o "Montar automático" tenta encaixá-los primeiro. */
	let prioritarias = $state<Set<string>>(new Set());
	/** Turnos permitidos ao rearranjar (M/T/N). Os 3 = sem filtro. */
	let turnosPermitidos = $state<Set<Turno>>(new Set<Turno>(['M', 'T', 'N']));
	/** Códigos que o aluno removeu — não voltam ao re-semear o recomendado. */
	let removidas = $state<Set<string>>(new Set());

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
			const tg = pool.find((m) => m.codigo === codigo)?.turmas.find((t) => t.turma.id_turmas === idTurma);
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

		get turnosPermitidos() {
			return turnosPermitidos;
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
			let restaurado:
				| {
						grades: Cenario[];
						activeId: string;
						prioritarias?: string[];
						turnos?: Turno[];
						removidas?: string[];
				  }
				| null = null;
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

		/** Seleciona/troca a turma; retorna feedback de conflito p/ o "tenta inserir". */
		selecionarTurma(codigo: string, idTurma: number): SelecaoResultado {
			const tg = pool
				.find((m) => m.codigo === codigo)
				?.turmas.find((t) => t.turma.id_turmas === idTurma);
			if (!tg) return { ok: false, conflitaCom: null };
			const conflito = this.conflitaCom(codigo, tg);
			if (conflito) return { ok: false, conflitaCom: conflito };
			updateAtivo((sel) => ({ ...sel, [codigo]: idTurma }));
			return { ok: true, conflitaCom: null };
		},

		removerTurma(codigo: string): void {
			updateAtivo((sel) => {
				const { [codigo]: _omit, ...rest } = sel;
				return rest;
			});
		},

		montarAutomatico(): MontagemResultado {
			const r = autoMontarGrade(
				pool.map((m) => ({
					chave: m.codigo,
					// Só considera turmas dentro dos turnos permitidos.
					turmas: m.turmas.filter((t) => turmaRespeitaTurnos(t.mask, turnosPermitidos)),
					peso: prioritarias.has(m.codigo) ? 1000 : 1
				}))
			);
			const novaSel: Record<string, number> = {};
			for (const [codigo, t] of r.selecao) novaSel[codigo] = t.turma.id_turmas;
			grades = grades.map((g) => (g.id === activeId ? { ...g, selecao: novaSel } : g));
			ultimaMontagem = { naoAlocadas: r.naoAlocadas };
			persistCenarios();
			return ultimaMontagem;
		},

		limpar(): void {
			updateAtivo(() => ({}));
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
