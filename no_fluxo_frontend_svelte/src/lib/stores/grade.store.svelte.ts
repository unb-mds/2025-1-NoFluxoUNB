/**
 * Grade Store — Montador de Grade.
 * Store baseado em runes (Svelte 5) que gerencia a seleção de turmas do próximo
 * semestre recomendado, bloqueia conflitos de horário, oferece montagem
 * automática e persiste a seleção em localStorage por usuário + período.
 */
import {
	hasConflict,
	autoMontarGrade,
	slotMaskFromHorario,
	type TurmaComMask
} from '$lib/utils/horario-slots';
import type { TurmaOferta } from '$lib/services/turmas.service';

export interface MateriaGrade {
	codigo: string;
	nome: string;
	creditos: number;
	idMateria: number;
	/** Turmas ofertadas para a matéria, já com máscara de horário. */
	turmas: Array<TurmaComMask<TurmaOferta>>;
}

/** Paleta dark-mode, uma cor estável por matéria (por ordem de exibição). */
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

export interface MontagemResultado {
	naoAlocadas: string[];
}

function createGradeStore() {
	let materias = $state<MateriaGrade[]>([]);
	let selecao = $state<Map<string, TurmaComMask<TurmaOferta>>>(new Map());
	let idUser = $state<number | null>(null);
	let periodo = $state<string | null>(null);
	let ultimaMontagem = $state<MontagemResultado | null>(null);

	// Índice estável de cor por código de matéria.
	const indicePorCodigo = $derived.by(() => {
		const m = new Map<string, number>();
		materias.forEach((mat, i) => m.set(mat.codigo, i));
		return m;
	});

	/** Máscara combinada de todas as turmas selecionadas. */
	const combinedMask = $derived.by(() => {
		let mask = 0n;
		for (const t of selecao.values()) mask |= t.mask;
		return mask;
	});

	/** Mapa bitIndex → código da matéria que ocupa o slot (conflitos são impedidos). */
	const ocupacao = $derived.by(() => {
		const map = new Map<number, string>();
		for (const [codigo, t] of selecao) {
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

	function storageKey(): string | null {
		return idUser != null && periodo ? `nofluxo:grade:${idUser}:${periodo}` : null;
	}

	function persist(): void {
		const key = storageKey();
		if (!key || typeof localStorage === 'undefined') return;
		const obj: Record<string, number> = {};
		for (const [codigo, t] of selecao) obj[codigo] = t.turma.id_turmas;
		localStorage.setItem(key, JSON.stringify(obj));
	}

	function restore(): void {
		const key = storageKey();
		if (!key || typeof localStorage === 'undefined') return;
		const raw = localStorage.getItem(key);
		if (!raw) return;
		try {
			const obj = JSON.parse(raw) as Record<string, number>;
			const next = new Map<string, TurmaComMask<TurmaOferta>>();
			let acc = 0n;
			for (const mat of materias) {
				const idTurma = obj[mat.codigo];
				if (idTurma == null) continue;
				const tg = mat.turmas.find((t) => t.turma.id_turmas === idTurma);
				// Ignora seleções persistidas que passaram a conflitar (ex.: oferta mudou).
				if (tg && !hasConflict(tg.mask, acc)) {
					next.set(mat.codigo, tg);
					acc |= tg.mask;
				}
			}
			selecao = next;
		} catch {
			// localStorage corrompido — começa vazio.
		}
	}

	/** Máscara das turmas selecionadas, exceto a da matéria informada. */
	function maskExcluindo(codigo: string): bigint {
		let mask = 0n;
		for (const [c, t] of selecao) if (c !== codigo) mask |= t.mask;
		return mask;
	}

	return {
		get materias() {
			return materias;
		},
		get selecao() {
			return selecao;
		},
		get combinedMask() {
			return combinedMask;
		},
		get ocupacao() {
			return ocupacao;
		},
		get ultimaMontagem() {
			return ultimaMontagem;
		},

		/** Carrega as matérias do semestre e restaura a seleção salva. */
		init(materiasGrade: MateriaGrade[], ctx: { idUser: number | null; periodo: string }): void {
			materias = materiasGrade;
			idUser = ctx.idUser;
			periodo = ctx.periodo;
			ultimaMontagem = null;
			selecao = new Map();
			restore();
		},

		turmaSelecionada(codigo: string): TurmaComMask<TurmaOferta> | undefined {
			return selecao.get(codigo);
		},

		/** Cor estável da matéria (por ordem de exibição). */
		corDaMateria(codigo: string) {
			const i = indicePorCodigo.get(codigo) ?? 0;
			return MATERIA_CORES[i % MATERIA_CORES.length];
		},

		/** true se a turma pode ser selecionada sem conflitar com as demais. */
		podeSelecionar(codigo: string, tg: TurmaComMask<TurmaOferta>): boolean {
			return !hasConflict(tg.mask, maskExcluindo(codigo));
		},

		/** Código da matéria já selecionada que conflita com esta turma, ou null. */
		conflitaCom(codigo: string, tg: TurmaComMask<TurmaOferta>): string | null {
			for (const [c, t] of selecao) {
				if (c === codigo) continue;
				if (hasConflict(tg.mask, t.mask)) return c;
			}
			return null;
		},

		/** Seleciona (ou troca) a turma de uma matéria; ignora se conflitar. */
		selecionarTurma(codigo: string, idTurma: number): void {
			const mat = materias.find((m) => m.codigo === codigo);
			const tg = mat?.turmas.find((t) => t.turma.id_turmas === idTurma);
			if (!tg) return;
			if (hasConflict(tg.mask, maskExcluindo(codigo))) return; // proibir adicionar
			const next = new Map(selecao);
			next.set(codigo, tg);
			selecao = next;
			ultimaMontagem = null;
			persist();
		},

		removerTurma(codigo: string): void {
			if (!selecao.has(codigo)) return;
			const next = new Map(selecao);
			next.delete(codigo);
			selecao = next;
			ultimaMontagem = null;
			persist();
		},

		/** Backtracking: escolhe turmas sem conflito para o máximo de matérias. */
		montarAutomatico(): MontagemResultado {
			const r = autoMontarGrade(
				materias.map((m) => ({ chave: m.codigo, turmas: m.turmas }))
			);
			selecao = new Map(r.selecao);
			ultimaMontagem = { naoAlocadas: r.naoAlocadas };
			persist();
			return ultimaMontagem;
		},

		limpar(): void {
			selecao = new Map();
			ultimaMontagem = null;
			persist();
		}
	};
}

export const gradeStore = createGradeStore();

/** Reexport utilitário para os componentes construírem máscaras a partir do horário. */
export { slotMaskFromHorario };
