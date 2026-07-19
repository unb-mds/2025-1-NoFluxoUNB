/**
 * Núcleo algorítmico do Montador de Grade.
 *
 * Os horários da UnB são discretos: por dia há 16 módulos possíveis
 * (M1–M5, T1–T7, N1–N4) e a semana útil vai de segunda (2) a sábado (7).
 * Cada horário SIGAA (ex.: "246M12 35T34") é convertido num **bitmask BigInt**
 * de 96 bits (6 dias × 16 módulos), o que torna a detecção de conflito uma
 * simples operação bit-a-bit — exata e O(1), sem edge cases de intervalo.
 *
 * Layout do bit: `diaIndex(0..5) * 16 + offsetTurno + (modulo - 1)`,
 * com offsetTurno M=0, T=5, N=12. Reaproveita o mesmo padrão de código do
 * parser de exibição em `sigaa.ts` (formatHorarioSigaa).
 */

/** '2'(Seg)..'7'(Sáb) → 0..5. */
const DIA_INDEX: Record<string, number> = { '2': 0, '3': 1, '4': 2, '5': 3, '6': 4, '7': 5 };

/** Deslocamento do turno dentro do dia (16 slots/dia). */
const TURNO_OFFSET: Record<'M' | 'T' | 'N', number> = { M: 0, T: 5, N: 12 };

/** Módulo máximo válido por turno (evita colisão entre turnos). */
const TURNO_MAX_MODULO: Record<'M' | 'T' | 'N', number> = { M: 5, T: 7, N: 4 };

// Mesmo padrão usado em sigaa.ts: dias + turno + módulos (ex.: 24M12, 6N1234).
const HORARIO_REGEX = /([2-7]+)\s*([MTN])\s*([1-7]+)/g;

/**
 * Converte um horário SIGAA num bitmask de slots da semana.
 * Retorna `0n` para entradas vazias, nulas ou sem padrão reconhecível
 * (ex.: EAD / "A DEFINIR") — máscara vazia nunca conflita.
 */
export function slotMaskFromHorario(rawHorario: string | null | undefined): bigint {
	const raw = String(rawHorario ?? '')
		.trim()
		.toUpperCase();
	if (!raw) return 0n;

	let mask = 0n;
	// Regex global é stateful; instância local evita problemas de reentrância.
	const regex = new RegExp(HORARIO_REGEX.source, 'g');
	let match: RegExpExecArray | null = regex.exec(raw);

	while (match) {
		const diasCod = match[1] ?? '';
		const turno = (match[2] ?? 'M') as 'M' | 'T' | 'N';
		const modulosCod = match[3] ?? '';
		const maxModulo = TURNO_MAX_MODULO[turno];

		for (const d of diasCod) {
			const diaIndex = DIA_INDEX[d];
			if (diaIndex === undefined) continue;
			for (const m of modulosCod) {
				const modulo = Number(m);
				if (modulo < 1 || modulo > maxModulo) continue; // fora da faixa do turno
				const bitIndex = diaIndex * 16 + TURNO_OFFSET[turno] + (modulo - 1);
				mask |= 1n << BigInt(bitIndex);
			}
		}
		match = regex.exec(raw);
	}

	return mask;
}

/** Duas máscaras conflitam se compartilham ao menos um slot. */
export function hasConflict(a: bigint, b: bigint): boolean {
	return (a & b) !== 0n;
}

// ─── Metadados para renderização da grade ────────────────────────────────────

/** Colunas da grade: segunda a sábado. */
export const DIAS_SEMANA: ReadonlyArray<{ cod: string; label: string }> = [
	{ cod: '2', label: 'Seg' },
	{ cod: '3', label: 'Ter' },
	{ cod: '4', label: 'Qua' },
	{ cod: '5', label: 'Qui' },
	{ cod: '6', label: 'Sex' },
	{ cod: '7', label: 'Sáb' }
];

export interface SlotMeta {
	turno: 'M' | 'T' | 'N';
	modulo: number;
	/** Deslocamento dentro do dia (0..15) — TURNO_OFFSET + (modulo-1). */
	offset: number;
	/** Rótulo compacto (ex.: "M1"). */
	label: string;
	/** Horário de início (ex.: "08:00"). Espelha o SLOT_MAP de sigaa.ts. */
	inicio: string;
}

const HORA_INICIO: Record<'M' | 'T' | 'N', Record<number, string>> = {
	M: { 1: '08:00', 2: '08:55', 3: '10:00', 4: '10:55', 5: '12:00' },
	T: { 1: '12:55', 2: '14:00', 3: '14:55', 4: '16:00', 5: '16:55', 6: '18:00', 7: '18:55' },
	N: { 1: '19:00', 2: '19:50', 3: '20:50', 4: '21:40' }
};

/** Linhas da grade, em ordem: M1–M5, T1–T7, N1–N4. */
export const SLOTS_DIA: readonly SlotMeta[] = (['M', 'T', 'N'] as const).flatMap((turno) =>
	Array.from({ length: TURNO_MAX_MODULO[turno] }, (_, i): SlotMeta => {
		const modulo = i + 1;
		return {
			turno,
			modulo,
			offset: TURNO_OFFSET[turno] + i,
			label: `${turno}${modulo}`,
			inicio: HORA_INICIO[turno][modulo]
		};
	})
);

/** Índice do bit para um dia (cód. SIGAA) e o offset do slot dentro do dia. */
export function bitIndex(diaCod: string, offsetNoDia: number): number {
	return (DIA_INDEX[diaCod] ?? 0) * 16 + offsetNoDia;
}

// ─── Montagem automática (interval scheduling / backtracking) ────────────────

export interface TurmaComMask<T> {
	mask: bigint;
	turma: T;
}

export interface MateriaTurmas<T> {
	/** Identificador da matéria (código ou id) usado como chave da seleção. */
	chave: string;
	/** Turmas ofertadas para a matéria, cada uma com sua máscara de horário. */
	turmas: Array<TurmaComMask<T>>;
}

export interface AutoMontarResult<T> {
	/** Turma escolhida por matéria (chave → turma selecionada). */
	selecao: Map<string, TurmaComMask<T>>;
	/** Chaves das matérias que não couberam sem conflito. */
	naoAlocadas: string[];
}

/**
 * Escolhe, via backtracking, uma turma por matéria de modo que nenhuma
 * sobreponha horário com outra, **maximizando** o número de matérias alocadas.
 *
 * Para um semestre típico (~5–7 matérias × poucas turmas) o espaço de busca é
 * minúsculo e a resposta é instantânea. Matérias sem turma disponível — ou que
 * não couberam — voltam em `naoAlocadas`.
 */
export function autoMontarGrade<T>(materias: Array<MateriaTurmas<T>>): AutoMontarResult<T> {
	let melhorSelecao: Map<string, TurmaComMask<T>> = new Map();

	const atual = new Map<string, TurmaComMask<T>>();

	function recurse(i: number, accMask: bigint): void {
		if (atual.size > melhorSelecao.size) {
			melhorSelecao = new Map(atual);
		}
		if (melhorSelecao.size === materias.length) return; // ótimo já atingido
		if (i >= materias.length) return;

		const m = materias[i];

		// Opção A: tentar alocar uma turma que não conflite com o acumulado.
		for (const t of m.turmas) {
			if (hasConflict(t.mask, accMask)) continue;
			atual.set(m.chave, t);
			recurse(i + 1, accMask | t.mask);
			atual.delete(m.chave);
			if (melhorSelecao.size === materias.length) return;
		}

		// Opção B: deixar esta matéria de fora e seguir.
		recurse(i + 1, accMask);
	}

	recurse(0, 0n);

	const naoAlocadas = materias.map((m) => m.chave).filter((chave) => !melhorSelecao.has(chave));

	return { selecao: melhorSelecao, naoAlocadas };
}
