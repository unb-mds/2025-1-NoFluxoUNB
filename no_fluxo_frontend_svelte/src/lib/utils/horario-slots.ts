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
	/** Horário de fim (ex.: "08:55"). */
	fim: string;
}

const HORA_INICIO: Record<'M' | 'T' | 'N', Record<number, string>> = {
	M: { 1: '08:00', 2: '08:55', 3: '10:00', 4: '10:55', 5: '12:00' },
	T: { 1: '12:55', 2: '14:00', 3: '14:55', 4: '16:00', 5: '16:55', 6: '18:00', 7: '18:55' },
	N: { 1: '19:00', 2: '19:50', 3: '20:50', 4: '21:40' }
};

const HORA_FIM: Record<'M' | 'T' | 'N', Record<number, string>> = {
	M: { 1: '08:55', 2: '09:50', 3: '10:55', 4: '11:50', 5: '12:55' },
	T: { 1: '13:50', 2: '14:55', 3: '15:50', 4: '16:55', 5: '17:50', 6: '18:55', 7: '19:50' },
	N: { 1: '19:50', 2: '20:40', 3: '21:40', 4: '22:30' }
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
			inicio: HORA_INICIO[turno][modulo],
			fim: HORA_FIM[turno][modulo]
		};
	})
);

/** Índice do bit para um dia (cód. SIGAA) e o offset do slot dentro do dia. */
export function bitIndex(diaCod: string, offsetNoDia: number): number {
	return (DIA_INDEX[diaCod] ?? 0) * 16 + offsetNoDia;
}

export type Turno = 'M' | 'T' | 'N';
const TODOS_TURNOS: readonly Turno[] = ['M', 'T', 'N'];

/** Máscara com todos os slots dos turnos indicados, em todos os dias da semana. */
export function maskDosTurnos(turnos: Iterable<Turno>): bigint {
	const set = new Set(turnos);
	if (set.size === 0) return 0n;
	let mask = 0n;
	for (let dia = 0; dia < DIAS_SEMANA.length; dia++) {
		for (const slot of SLOTS_DIA) {
			if (set.has(slot.turno)) mask |= 1n << BigInt(dia * 16 + slot.offset);
		}
	}
	return mask;
}

/**
 * A turma cabe apenas nos turnos permitidos? Sem filtro (retorna true) quando o
 * conjunto está vazio ou tem os 3 turnos. Turma sem horário (mask 0n) sempre cabe.
 */
export function turmaRespeitaTurnos(mask: bigint, turnosPermitidos: Set<Turno>): boolean {
	if (turnosPermitidos.size === 0 || turnosPermitidos.size === 3) return true;
	const proibidos = TODOS_TURNOS.filter((t) => !turnosPermitidos.has(t));
	return (mask & maskDosTurnos(proibidos)) === 0n;
}

export interface BlocoDia {
	/** Código da matéria que ocupa o bloco. */
	codigo: string;
	/** Índice do primeiro slot (posição em `SLOTS_DIA`). */
	offsetStart: number;
	/** Quantos slots consecutivos o bloco cobre. */
	span: number;
}

/**
 * Agrupa módulos consecutivos da mesma matéria num único bloco (para o calendário
 * estilo "Google Agenda"). Recebe, para um dia, o código que ocupa cada posição de
 * `SLOTS_DIA` (ou `null`/`undefined` se livre). Buracos e trocas de matéria quebram
 * o bloco.
 */
export function agruparBlocosDia(
	codigosPorOffset: ReadonlyArray<string | null | undefined>
): BlocoDia[] {
	const blocos: BlocoDia[] = [];
	const n = codigosPorOffset.length;
	let i = 0;
	while (i < n) {
		const codigo = codigosPorOffset[i];
		if (!codigo) {
			i++;
			continue;
		}
		let j = i + 1;
		while (j < n && codigosPorOffset[j] === codigo) j++;
		blocos.push({ codigo, offsetStart: i, span: j - i });
		i = j;
	}
	return blocos;
}

// ─── Montagem automática (interval scheduling / backtracking) ────────────────

export interface TurmaComMask<T> {
	mask: bigint;
	turma: T;
}

/** Turma candidata na montagem automática, com o bônus de preferência já calculado. */
export type TurmaCandidata<T> = TurmaComMask<T> & {
	/**
	 * O quanto esta turma atende às preferências do aluno (horário/professor).
	 * É só critério de **desempate**: quem calcula os bônus deve manter
	 * `peso` de matéria > soma máxima de bônus possível, para que encaixar mais uma
	 * matéria nunca perca para agradar uma preferência (ver grade.store).
	 */
	bonus?: number;
};

export interface MateriaTurmas<T> {
	/** Identificador da matéria (código ou id) usado como chave da seleção. */
	chave: string;
	/** Turmas ofertadas para a matéria, cada uma com sua máscara de horário. */
	turmas: Array<TurmaCandidata<T>>;
	/**
	 * Peso para priorização na montagem automática (default 1). Quanto maior, mais
	 * o montador prefere encaixá-la quando nem tudo cabe sem conflito.
	 */
	peso?: number;
}

/**
 * Teto de nós explorados na montagem automática. Com a poda sensível ao acumulado
 * um pool real resolve em centenas de nós; o teto existe só para garantir que
 * nenhuma entrada inesperada trave a aba do aluno.
 */
const MAX_NOS_MONTAGEM = 200_000;

export interface AutoMontarResult<T> {
	/** Turma escolhida por matéria (chave → turma selecionada). */
	selecao: Map<string, TurmaCandidata<T>>;
	/** Chaves das matérias que não couberam sem conflito. */
	naoAlocadas: string[];
	/**
	 * Chaves alocadas numa turma que não atinge o melhor bônus disponível para a
	 * matéria — ou seja, a preferência declarada teve de ceder para caber na grade.
	 */
	preferenciasNaoAtendidas: string[];
	/**
	 * A busca bateu no teto de nós e parou antes de esgotar as combinações. A grade
	 * devolvida é válida e sem conflito, mas pode não ser a melhor possível.
	 */
	truncado: boolean;
}

/**
 * Escolhe, via *branch and bound*, uma turma por matéria de modo que nenhuma
 * sobreponha horário com outra, **maximizando** o número de matérias alocadas.
 *
 * Preferências de horário/professor entram como `bonus` por turma e funcionam só
 * como desempate: desde que o chamador mantenha `peso` de matéria maior que a soma
 * máxima de bônus, encaixar mais uma matéria sempre ganha de agradar uma
 * preferência. Quem teve de ceder volta em `preferenciasNaoAtendidas`.
 *
 * A poda de `limiteSuperior` é o que mantém isso viável: sem ela, qualquer pool em
 * que o ótimo teórico seja inalcançável — uma matéria sem oferta no semestre, ou
 * turmas descartadas pelo filtro de turno — varre o espaço de busca inteiro
 * (~10 matérias × ~12 turmas passa de 10⁸ nós) e trava a thread principal por
 * minutos.
 *
 * Matérias sem turma disponível — ou que não couberam — voltam em `naoAlocadas`.
 *
 * `mascaraInicial` é horário já ocupado por fora de `materias` — matérias travadas
 * (ex.: o aluno já está cursando e escolheu a turma real) que o solver não pode
 * mexer nem sobrepor, mas conta pra poda de conflito como se fosse mais uma turma
 * escolhida desde o nó raiz (ver `gradeStore.montarAutomatico`).
 */
export function autoMontarGrade<T>(
	materias: Array<MateriaTurmas<T>>,
	mascaraInicial: bigint = 0n
): AutoMontarResult<T> {
	const pesoDe = (m: MateriaTurmas<T>) => m.peso ?? 1;
	const bonusDe = (t: TurmaCandidata<T>) => t.bonus ?? 0;
	const melhorBonusDe = (m: MateriaTurmas<T>) =>
		m.turmas.reduce((max, t) => Math.max(max, bonusDe(t)), 0);

	// Matérias de maior peso primeiro e, dentro de cada uma, as turmas que mais
	// atendem à preferência — assim o primeiro mergulho já encontra uma solução boa
	// e a poda descarta o resto cedo.
	//
	// Turmas com a mesma máscara são intercambiáveis para o encaixe (só o horário
	// importa), então basta manter a de maior bônus: corta um fator de ramificação
	// grande, já que é comum a matéria ter várias turmas no mesmo horário.
	const ordenadas = [...materias]
		.sort((a, b) => pesoDe(b) - pesoDe(a))
		.map((m) => {
			const porMask = new Map<bigint, TurmaCandidata<T>>();
			for (const t of [...m.turmas].sort((x, y) => bonusDe(y) - bonusDe(x))) {
				if (!porMask.has(t.mask)) porMask.set(t.mask, t);
			}
			return { ...m, turmas: [...porMask.values()] };
		});

	let melhorSelecao: Map<string, TurmaCandidata<T>> = new Map();
	let melhorPeso = -1;
	const atual = new Map<string, TurmaCandidata<T>>();
	let pesoAtual = 0;
	let nos = 0;
	let truncado = false;

	/**
	 * Limite superior do que ainda dá para somar do índice `i` em diante, dado o
	 * horário já ocupado (`accMask`).
	 *
	 * O ponto crucial é ele ser **sensível ao acumulado**: uma matéria cujas turmas
	 * já colidem todas com `accMask` não pode mais entrar (a máscara só cresce), e
	 * por isso não conta. Um limite estático — "toda matéria na sua melhor turma" —
	 * fica frouxo demais justo nos casos que interessam: basta uma matéria sem
	 * oferta para o ótimo teórico virar inalcançável, nenhuma poda disparar e a
	 * busca varrer o espaço inteiro.
	 *
	 * As turmas estão ordenadas por bônus decrescente, então a primeira compatível
	 * já é a de maior bônus da matéria.
	 */
	function limiteSuperior(i: number, accMask: bigint): number {
		let total = 0;
		for (let j = i; j < ordenadas.length; j++) {
			const m = ordenadas[j];
			for (const t of m.turmas) {
				if (hasConflict(t.mask, accMask)) continue;
				total += pesoDe(m) + bonusDe(t);
				break;
			}
		}
		return total;
	}

	function recurse(i: number, accMask: bigint): void {
		// Maximiza a soma dos pesos alocados (não só a contagem).
		if (pesoAtual > melhorPeso) {
			melhorPeso = pesoAtual;
			melhorSelecao = new Map(atual);
		}
		if (i >= ordenadas.length) return;
		// Rede de segurança: isto roda síncrono no clique do aluno. Num pool
		// patológico, para a busca e devolve a melhor grade encontrada até aqui —
		// que é sempre válida e sem conflito, só não comprovadamente ótima.
		if (nos >= MAX_NOS_MONTAGEM) {
			truncado = true;
			return;
		}
		nos++;
		// Poda: nem alocando tudo o que ainda cabe dá para superar o melhor achado.
		if (pesoAtual + limiteSuperior(i, accMask) <= melhorPeso) return;

		const m = ordenadas[i];

		// Opção A: tentar alocar uma turma que não conflite com o acumulado.
		for (const t of m.turmas) {
			if (hasConflict(t.mask, accMask)) continue;
			atual.set(m.chave, t);
			pesoAtual += pesoDe(m) + bonusDe(t);
			recurse(i + 1, accMask | t.mask);
			pesoAtual -= pesoDe(m) + bonusDe(t);
			atual.delete(m.chave);
		}

		// Opção B: deixar esta matéria de fora e seguir.
		recurse(i + 1, accMask);
	}

	recurse(0, mascaraInicial);

	const naoAlocadas: string[] = [];
	const preferenciasNaoAtendidas: string[] = [];
	for (const m of materias) {
		const escolhida = melhorSelecao.get(m.chave);
		if (!escolhida) {
			naoAlocadas.push(m.chave);
			continue;
		}
		const melhor = melhorBonusDe(m);
		// Só reporta quem declarou preferência (melhor > 0) e não conseguiu o melhor.
		if (melhor > 0 && bonusDe(escolhida) < melhor) preferenciasNaoAtendidas.push(m.chave);
	}

	return { selecao: melhorSelecao, naoAlocadas, preferenciasNaoAtendidas, truncado };
}
