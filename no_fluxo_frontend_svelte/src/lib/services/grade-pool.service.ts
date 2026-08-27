/**
 * Construção do pool do Montador de Grade — compartilhado entre a página do
 * montador e a busca de turmas.
 *
 * Existe porque as duas telas precisam da mesma coisa: transformar códigos de
 * matéria em `MateriaGrade` (matéria + oferta do período + máscaras de horário +
 * avisos de requisito). A busca de turmas ainda depende de `garantirContexto`
 * para funcionar em carregamento direto, sem passar antes pelo montador.
 */
import { authStore } from '$lib/stores/auth';
import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
import {
	gradeStore,
	lerPoolSalvo,
	slotMaskFromHorario,
	type MateriaGrade
} from '$lib/stores/grade.store.svelte';
import { getPeriodoAtivo } from '$lib/services/turmas.service';
import { getMateriasByCodigos } from '$lib/services/materias.service';
import { getOfertaComEquivalencia } from '$lib/services/oferta-turmas.service';
import { satisfazPreRequisitos } from '$lib/types/curso';
import { classificarNatureza, isOptativa } from '$lib/types/materia';
import { setHasCodeIgnoreCase, filtrarNaoCursados } from '$lib/utils/subject-codes';
import { hasConflict, turmaRespeitaTurnos, type Turno } from '$lib/utils/horario-slots';

/**
 * Partes de pré-requisito ainda não cumpridas (código ou, quando o registro não
 * traz código, a expressão do SIGAA). `null` = nada pendente.
 *
 * Vive separado de `calcularRequisitos` porque o aviso inline corta em 3 partes
 * enquanto o pop-up de confirmação precisa da lista inteira — e a avaliação da
 * expressão lógica (AND/OR) não pode ficar duplicada nos dois lugares.
 */
export type NivelPreRequisito = 'em-curso' | 'pendente';

/**
 * Estado do pré-requisito em três níveis, com as partes que faltam.
 *
 * `docs/unb-domain.md:26` diz que MATR não desbloqueia pré-requisito; o Motor 2
 * monta `completedPlusMatr` e recomenda com base nisso. Os dois estão certos no
 * próprio quadro, e escolher um em silêncio foi o erro anterior: ora o app dizia
 * "pendente" numa recomendação legítima do backend, ora não dizia nada sobre uma
 * dependência que ainda pode falhar.
 *
 * O padrão é não decidir escondido:
 * - `null`  → cumprido só com aprovadas (inclui equivalência)
 * - `em-curso` → só fecha contando o que ele cursa agora; depende de passar
 * - `pendente` → não fecha nem assim
 *
 * Nenhum bloqueia: quem chama decide o que fazer com o aviso.
 */
function estadoPreRequisito(
	idMateria: number
): { nivel: NivelPreRequisito; partes: string[] } | null {
	const curso = fluxogramaStore.state.courseData;
	const concluidas = fluxogramaStore.completedCodes;
	const emCurso = fluxogramaStore.currentCodes ?? new Set<string>();
	const comEmCurso = new Set([...concluidas, ...emCurso]);

	const prereqs = (curso?.preRequisitos ?? []).filter((pr) => pr.idMateria === idMateria);
	if (prereqs.length === 0 || satisfazPreRequisitos(prereqs, concluidas)) return null;

	// Fecha quando entram as em curso? Então é dependência encaminhada, não pendência.
	const nivel: NivelPreRequisito = satisfazPreRequisitos(prereqs, comEmCurso)
		? 'em-curso'
		: 'pendente';
	// No nível "em curso" o que interessa mostrar é a matéria de que ele depende;
	// no "pendente", o que ainda falta por completo.
	const base = nivel === 'em-curso' ? concluidas : comEmCurso;

	const partes = new Set<string>();
	for (const pr of prereqs) {
		const code = pr.codigoMateriaRequisito?.trim();
		if (code) {
			if (!setHasCodeIgnoreCase(base, code)) partes.add(code);
		} else if (pr.expressaoOriginal?.trim()) {
			partes.add(pr.expressaoOriginal.trim());
		}
	}
	return { nivel, partes: [...partes] };
}

/**
 * Partes ainda não cumpridas, contando o que ele cursa agora — é a lista que o
 * pop-up de confirmação mostra. `null` = nada a avisar.
 */
function partesPreRequisitoPendentes(idMateria: number): string[] | null {
	const estado = estadoPreRequisito(idMateria);
	return estado === null || estado.nivel === 'em-curso' ? null : estado.partes;
}

/**
 * Requisitos da matéria a partir do courseData: aviso de pré-requisito pendente
 * (não bloqueia) e lista de co-requisitos. Só resolve p/ matérias da matriz —
 * optativas de fora não têm essas regras no courseData e passam sem aviso.
 */
export function calcularRequisitos(idMateria: number): {
	avisoPreRequisito: string | null;
	nivelPreRequisito: NivelPreRequisito | null;
	coRequisitos: string[];
} {
	const curso = fluxogramaStore.state.courseData;
	const completed = fluxogramaStore.completedCodes;
	const current = fluxogramaStore.currentCodes ?? new Set<string>();

	const estado = estadoPreRequisito(idMateria);
	const avisoPreRequisito =
		estado === null
			? null
			: estado.partes.length > 0
				? estado.partes.slice(0, 3).join(' · ')
				: 'requisitos não cumpridos';

	const coRequisitos = [
		...new Set(
			(curso?.coRequisitos ?? [])
				.filter((cr) => cr.idMateria === idMateria)
				.map((cr) => cr.codigoMateriaCoRequisito?.trim())
				.filter((c): c is string => !!c && !setHasCodeIgnoreCase(completed, c) && !current.has(c))
		)
	];

	return { avisoPreRequisito, nivelPreRequisito: estado?.nivel ?? null, coRequisitos };
}

/**
 * Natureza da matéria (obrigatória / optativa / módulo livre) pelo código, na
 * mesma regra do fluxograma: o que não está na matriz é módulo livre.
 */
export function naturezaDoCodigo(codigo: string): 'obrigatoria' | 'optativa' | 'modulo_livre' {
	const alvo = codigo.trim().toUpperCase();
	const m = (fluxogramaStore.state.courseData?.materias ?? []).find(
		(x) => x.codigoMateria.trim().toUpperCase() === alvo
	);
	return classificarNatureza(m);
}

/** Resolve códigos → matéria + turmas (courseData primeiro; senão banco). */
export async function construirMateriasGrade(
	codigos: string[],
	periodo: string
): Promise<MateriaGrade[]> {
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
		if (mm)
			resolved.set(c, { idMateria: mm.idMateria, nome: mm.nomeMateria, creditos: mm.creditos });
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
	// Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
	const ofertaPorCodigo = await getOfertaComEquivalencia(
		[...resolved].map(([codigo, r]) => ({ codigo, idMateria: r.idMateria })),
		fluxogramaStore.state.courseData?.equivalencias ?? [],
		periodo
	);

	const out: MateriaGrade[] = [];
	for (const [codigo, r] of resolved) {
		const { avisoPreRequisito, nivelPreRequisito, coRequisitos } = calcularRequisitos(r.idMateria);
		out.push({
			codigo,
			nome: r.nome,
			creditos: r.creditos,
			idMateria: r.idMateria,
			avisoPreRequisito,
			nivelPreRequisito,
			coRequisitos,
			// Sem isto a montagem automática não distingue obrigatória de optativa e
			// vira um maximizador de contagem — ver a escada de pesos em grade.store.
			natureza: naturezaDoCodigo(codigo),
			turmas: (ofertaPorCodigo.get(codigo) ?? []).map(({ turma, codigoOfertado }) => ({
				turma,
				mask: slotMaskFromHorario(turma.horario),
				codigoOfertado
			}))
		});
	}
	return out;
}

/**
 * O que a semeadura trouxe para a lista — e o que não pôde trazer.
 *
 * Já não separa "do plano" de "da matriz": a fonte agora é sempre a matriz do
 * aluno, e o plano de formatura só desempata a ordem.
 */
export interface SemeaduraResultado {
	/** Códigos que entraram na lista agora. */
	adicionadas: string[];
	/** Obrigatórias que faltam ao aluno e não têm turma neste período. */
	obrigatoriasSemOferta: string[];
}

/**
 * Candidatas da matriz, para quando o plano não tem matéria concreta a semear.
 *
 * Acontece mais do que parece: o semestre recomendado pode vir só com
 * `optativa_slot`/`complementar_slot` (que não têm código), o `gerar()` do plano
 * pode ter falhado, ou tudo que ele recomendou já foi cursado. Sem uma segunda
 * fonte, "Montar grade" não tem o que montar e o aluno leva um aviso no lugar de
 * uma grade.
 *
 * Só volta matéria **com turma no período** — sem oferta ela não entra na grade de
 * jeito nenhum. A ordem é a de utilidade para quem quer se formar: requisito
 * cumprido antes de pendente, obrigatória antes de optativa e, dentro disso, o
 * nível mais baixo primeiro (a matéria mais atrasada).
 */
export async function candidatosDaMatriz(
	periodo: string,
	excluir: Iterable<string> = []
): Promise<MateriaGrade[]> {
	const { obrigatorias, optativas } = await candidatosClassificados(periodo, excluir);
	return [...obrigatorias, ...optativas].map((c) => c.materia);
}

/**
 * Posição de quem o plano não citou. Um número grande e FINITO de propósito:
 * `Infinity - Infinity` é `NaN`, e um `NaN` no comparador só não estraga a ordem
 * por acidente (é falsy, então o `||` cai no critério seguinte).
 */
const SEM_PLANO = Number.MAX_SAFE_INTEGER;

/** Uma candidata da matriz com tudo que a ordenação precisa saber sobre ela. */
interface CandidatoMatriz {
	materia: MateriaGrade;
	/** Pendente de verdade vai para o fim; dependência em curso fica no meio. */
	requisitoPendente: 0 | 1 | 2;
	/** Optativa que é pré-requisito de obrigatória — na prática, obrigatória disfarçada. */
	optatoria: boolean;
	/** Semestre esperado na matriz; a mais atrasada primeiro. */
	nivel: number;
	/** Posição no semestre recomendado do plano, ou `SEM_PLANO` se ele não citou. */
	ordemPlano: number;
}

/**
 * As matérias da matriz que ainda faltam, separadas por natureza e já ordenadas
 * por utilidade para quem quer se formar.
 *
 * Só volta matéria **com turma no período** — sem oferta ela não vira bloco no
 * calendário. As obrigatórias que caem por esse filtro saem em
 * `obrigatoriasSemOferta` em vez de sumirem caladas: "a obrigatória que te falta
 * não é ofertada neste semestre" é informação que muda o planejamento do aluno.
 *
 * `ordemDoPlano` é o semestre recomendado do plano de formatura. Ele NÃO decide
 * quem entra — só desempata entre matérias do mesmo grupo. Foi de lá que saíam as
 * "matérias nada a ver": o plano pode recomendar código que não está na matriz do
 * aluno, e isso entrava na lista como módulo livre.
 */
async function candidatosClassificados(
	periodo: string,
	excluir: Iterable<string> = [],
	ordemDoPlano: string[] = []
): Promise<{
	obrigatorias: CandidatoMatriz[];
	optativas: CandidatoMatriz[];
	obrigatoriasSemOferta: string[];
}> {
	const vazio = () => ({ obrigatorias: [], optativas: [], obrigatoriasSemOferta: [] });
	const matriz = fluxogramaStore.state.courseData?.materias ?? [];
	if (matriz.length === 0) return vazio();

	const fora = new Set([...excluir].map((c) => c.trim().toUpperCase()));
	const codigos = filtrarNaoCursados(
		matriz.map((m) => m.codigoMateria).filter((c) => !fora.has(c.trim().toUpperCase())),
		fluxogramaStore.completedCodes,
		fluxogramaStore.currentCodes ?? new Set<string>()
	);
	if (codigos.length === 0) return vazio();

	const daMatriz = new Map(matriz.map((m) => [m.codigoMateria.trim().toUpperCase(), m]));
	// Nem todo consumidor do store expõe `optatorias` (os testes antigos, por
	// exemplo) — sem ela a regra degrada para "toda optativa vale o mesmo".
	const destravam = fluxogramaStore.optatorias ?? new Map<string, string[]>();
	const posicaoNoPlano = new Map(
		ordemDoPlano.map((c, i) => [c.trim().toUpperCase(), i] as const)
	);

	const obrigatorias: CandidatoMatriz[] = [];
	const optativas: CandidatoMatriz[] = [];
	const obrigatoriasSemOferta: string[] = [];

	for (const m of await construirMateriasGrade(codigos, periodo)) {
		const info = daMatriz.get(m.codigo);
		const optativa = !!info && isOptativa(info);
		if (m.turmas.length === 0) {
			// Optativa sem oferta é rotina e não vale aviso; obrigatória é notícia.
			if (!optativa) obrigatoriasSemOferta.push(m.codigo);
			continue;
		}
		(optativa ? optativas : obrigatorias).push({
			materia: m,
			requisitoPendente:
				m.nivelPreRequisito === 'pendente' ? 2 : m.nivelPreRequisito === 'em-curso' ? 1 : 0,
			optatoria: optativa && destravam.has(m.codigo),
			// Optativa tem nivel 0 na matriz; a separação por natureza já cuidou disso.
			nivel: info?.nivel ?? 99,
			ordemPlano: posicaoNoPlano.get(m.codigo) ?? SEM_PLANO
		});
	}

	const porUtilidade = (a: CandidatoMatriz, b: CandidatoMatriz): number =>
		a.requisitoPendente - b.requisitoPendente ||
		Number(b.optatoria) - Number(a.optatoria) ||
		a.ordemPlano - b.ordemPlano ||
		a.nivel - b.nivel ||
		a.materia.codigo.localeCompare(b.materia.codigo);

	obrigatorias.sort(porUtilidade);
	optativas.sort(porUtilidade);

	return { obrigatorias, optativas, obrigatoriasSemOferta };
}

/**
 * Escolhe, na ordem recebida, o maior prefixo viável: matérias que cabem na grade
 * atual sem conflito de horário e sem estourar o limite de créditos do aluno.
 *
 * Existe para a semeadura não jogar a matriz inteira na lista. `montarAutomatico`
 * maximiza matérias e **não** conhece limite de créditos — semear 70 matérias faria
 * ele empacotar a semana toda e devolver o dobro do limite. Escolhendo aqui um
 * conjunto que já é comprovadamente compatível (mesma máscara, mesmos turnos), a
 * montagem seguinte consegue alocar todas: o ótimo dela é, no mínimo, este conjunto.
 *
 * Parte do que já está selecionado — assim a semeadura complementa a grade em vez
 * de ignorá-la.
 */
export function escolherAteOLimite(
	candidatos: MateriaGrade[],
	limiteCreditos: number
): MateriaGrade[] {
	return escolherComOrcamento(candidatos, limiteCreditos, {
		mask: gradeStore.combinedMask,
		creditos: gradeStore.creditosSelecionados,
		turnos: gradeStore.turnosPermitidos
	});
}

/** Ponto de partida da escolha: o que a grade já ocupa e o filtro de turno. */
export interface OrcamentoInicial {
	/** Horários já tomados. */
	mask: bigint;
	/** Créditos já gastos. */
	creditos: number;
	/** Turnos que o aluno aceita. */
	turnos: Set<Turno>;
}

const TODOS_OS_TURNOS = new Set<Turno>(['M', 'T', 'N']);

/**
 * O mesmo prefixo viável de `escolherAteOLimite`, mas partindo de um orçamento
 * explícito em vez do estado do `gradeStore`.
 *
 * A semeadura precisa disso porque roda ANTES do `init` do store, na primeira
 * carga da página: ali não existe seleção nem filtro de turno de onde partir, e
 * ler o store devolveria o estado da visita anterior.
 */
function escolherComOrcamento(
	candidatos: MateriaGrade[],
	limiteCreditos: number,
	base: OrcamentoInicial
): MateriaGrade[] {
	const escolhidas: MateriaGrade[] = [];
	let mask = base.mask;
	let creditos = base.creditos;

	for (const m of candidatos) {
		if (creditos + m.creditos > limiteCreditos) continue; // pode caber uma menor adiante
		const turma = m.turmas.find(
			(t) => turmaRespeitaTurnos(t.mask, base.turnos) && !hasConflict(t.mask, mask)
		);
		if (!turma) continue;
		mask |= turma.mask;
		creditos += m.creditos;
		escolhidas.push(m);
	}

	return escolhidas;
}

/** O que a semeadura devolve: a lista pronta e o que ficou de fora, com o motivo. */
export interface PoolRecomendado {
	/** Em curso primeiro, depois obrigatórias, depois optativas — na ordem de entrada. */
	materias: MateriaGrade[];
	/** Obrigatórias pendentes da matriz que não têm turma no período. */
	obrigatoriasSemOferta: string[];
}

/**
 * Monta a lista que o Montador recomenda — direto da **matriz do aluno**.
 *
 * A ordem não é arbitrária, é a de quem quer se formar:
 *
 * 1. **Matérias em curso (MATR).** Entram sempre, antes de tudo e sem passar por
 *    filtro nenhum: matrícula é fato consumado, não recomendação. O crédito delas
 *    é debitado do orçamento antes de o app sugerir qualquer coisa — recomendar 24
 *    créditos por cima de 12 já cursados dá uma grade impossível de se matricular.
 * 2. **Obrigatórias pendentes** com turma no período, requisito cumprido antes de
 *    pendente e a mais atrasada (menor `nivel`) primeiro.
 * 3. **Optativas**, só com o crédito que sobrar — e entre elas, primeiro as que
 *    destravam alguma obrigatória (as "optatórias").
 *
 * O plano de formatura entra apenas como desempate (`ordemDoPlano`). Ele era a
 * fonte da semeadura e é de lá que vinham as "matérias nada a ver": o plano pode
 * recomendar código fora da matriz, que entrava na lista como módulo livre. Agora
 * matéria de fora só entra se o aluno adicionar na mão.
 */
export async function montarPoolRecomendado(
	periodo: string,
	opts: {
		limiteCreditos: number;
		/** Semestre recomendado do plano de formatura — só desempata a ordem. */
		ordemDoPlano?: string[];
		/** Códigos que não devem voltar (lixeira do aluno) ou que já estão na lista. */
		excluir?: Iterable<string>;
		/** O que a grade já ocupa. Ausente = lista partindo do zero. */
		base?: OrcamentoInicial;
	}
): Promise<PoolRecomendado> {
	const base = opts.base ?? { mask: 0n, creditos: 0, turnos: TODOS_OS_TURNOS };
	const fora = new Set([...(opts.excluir ?? [])].map((c) => c.trim().toUpperCase()));

	// Em curso: entram inteiras, mesmo sem oferta no período. Uma MATR sem turma
	// publicada continua sendo uma matéria que o aluno cursa — escondê-la da lista
	// é justamente o bug que este caminho existe para não repetir.
	const emCurso = [...(fluxogramaStore.currentCodes ?? new Set<string>())].filter(
		(c) => !fora.has(c.trim().toUpperCase())
	);
	const materiasEmCurso = await construirMateriasGrade(emCurso, periodo);

	// Só o crédito é debitado, não o horário: a turma real da matrícula é escolhida
	// depois (`preencherTurmasReais`), então travar a máscara numa turma qualquer
	// bloquearia horários que a matéria talvez nem ocupe.
	const creditosEmCurso = materiasEmCurso.reduce((acc, m) => acc + m.creditos, 0);

	const { obrigatorias, optativas, obrigatoriasSemOferta } = await candidatosClassificados(
		periodo,
		[...fora, ...emCurso],
		opts.ordemDoPlano ?? []
	);

	const recomendadas = escolherComOrcamento(
		[...obrigatorias, ...optativas].map((c) => c.materia),
		opts.limiteCreditos,
		{ ...base, creditos: base.creditos + creditosEmCurso }
	);

	return {
		materias: [...materiasEmCurso, ...recomendadas],
		obrigatoriasSemOferta
	};
}

/**
 * Motivo pelo qual a matéria não deve entrar no pool, ou `null` se pode entrar.
 *
 * Avisa em vez de adicionar em silêncio: o aluno pode estar buscando pelo nome e
 * não perceber que é a mesma matéria que já cursou (ou que está cursando agora).
 */
export function motivoParaNaoAdicionar(codigo: string): string | null {
	const c = codigo.trim().toUpperCase();
	if (setHasCodeIgnoreCase(fluxogramaStore.completedCodes, c)) {
		return `Você já foi aprovado em ${c}.`;
	}
	if (setHasCodeIgnoreCase(fluxogramaStore.currentCodes ?? new Set<string>(), c)) {
		return `Você já está cursando ${c} neste semestre.`;
	}
	return null;
}

/** Pré-requisitos que o aluno ainda não cumpriu para uma matéria. */
export interface PendenciaPreRequisito {
	/** Código normalizado da matéria que ele quer adicionar. */
	codigo: string;
	/** Nome da matéria, quando conhecido (vem do courseData). */
	nome: string;
	/** Códigos — ou expressões, quando o registro não tem código — ainda não cumpridos. */
	faltantes: string[];
	/** Regra como o SIGAA escreve, ex.: "CIC0004 E MAT0025". */
	expressaoOriginal: string | null;
}

/**
 * Nome da matéria pelo código, para exibição.
 *
 * Consulta a matriz primeiro e, se o código não estiver nela, cai no
 * `nomeMateriaRequisito` dos pré-requisitos — pré-requisito de outro
 * departamento costuma não fazer parte da matriz do aluno.
 */
export function nomeDoCodigo(codigo: string): string | null {
	const alvo = codigo.trim().toUpperCase();
	if (!alvo) return null;

	const curso = fluxogramaStore.state.courseData;
	const materia = (curso?.materias ?? []).find(
		(m) => m.codigoMateria.trim().toUpperCase() === alvo
	);
	if (materia?.nomeMateria?.trim()) return materia.nomeMateria.trim();

	const pr = (curso?.preRequisitos ?? []).find(
		(p) => p.codigoMateriaRequisito?.trim().toUpperCase() === alvo
	);
	return pr?.nomeMateriaRequisito?.trim() || null;
}

/**
 * Pendência de pré-requisito da matéria, ou `null` quando não há o que avisar.
 *
 * Serve a todos os caminhos de adição (busca do montador, chat da Darcy, busca de
 * turmas): o aviso é advisory de propósito — quem está cursando o pré-requisito
 * agora tem motivo legítimo para seguir —, então quem chama decide o que fazer
 * com o resultado em vez de receber um bloqueio.
 *
 * Devolve `null` para matéria fora da matriz (módulo livre): o courseData não tem
 * as regras dela e afirmar "faltam pré-requisitos" ali seria mentira.
 */
export function pendenciaPreRequisito(codigo: string): PendenciaPreRequisito | null {
	const alvo = codigo.trim().toUpperCase();
	if (!alvo) return null;

	const curso = fluxogramaStore.state.courseData;
	const materia = (curso?.materias ?? []).find(
		(m) => m.codigoMateria.trim().toUpperCase() === alvo
	);
	if (!materia) return null;

	const faltantes = partesPreRequisitoPendentes(materia.idMateria);
	if (faltantes === null) return null;

	// Um mesmo idMateria pode ter vários registros repetindo a mesma expressão
	// (o backend devolve a regra expandida) — daí o dedupe.
	const expressoes = [
		...new Set(
			(curso?.preRequisitos ?? [])
				.filter((pr) => pr.idMateria === materia.idMateria)
				.map((pr) => pr.expressaoOriginal?.trim())
				.filter((e): e is string => !!e)
		)
	];

	return {
		codigo: alvo,
		nome: materia.nomeMateria?.trim() || alvo,
		faltantes,
		expressaoOriginal: expressoes.length > 0 ? expressoes.join(' · ') : null
	};
}

/**
 * Versão em lote, para quem adiciona várias matérias de uma vez (ação
 * `[MONTAR_GRADE|...]` do chat, semeadura).
 *
 * Um diálogo por matéria seria uma fila de pop-ups; devolvendo tudo junto o aluno
 * vê de uma vez o que está pendente. Preserva a ordem de entrada, ignora código
 * repetido e já descarta quem não tem pendência.
 */
export function pendenciasPreRequisito(codigos: string[]): PendenciaPreRequisito[] {
	const vistos = new Set<string>();
	const out: PendenciaPreRequisito[] = [];

	for (const codigo of codigos) {
		const alvo = codigo?.trim().toUpperCase();
		if (!alvo || vistos.has(alvo)) continue;
		vistos.add(alvo);

		const pendencia = pendenciaPreRequisito(alvo);
		if (pendencia) out.push(pendencia);
	}

	return out;
}

/** Estado do contexto compartilhado do montador. */
export type ContextoGrade = { periodo: string } | null;

let contextoEmVoo: Promise<ContextoGrade> | null = null;

/**
 * Garante que o `gradeStore` está utilizável fora da página do montador.
 *
 * O store só era inicializado ao montar `/planejamento/grade`; num carregamento
 * direto de `/planejamento/turmas` o `idUser`/`periodo` ficam nulos, `persistPool`
 * vira no-op e qualquer adição sumiria em silêncio. Aqui carregamos courseData,
 * período e o pool salvo, e chamamos `init`.
 *
 * Idempotente e à prova de chamadas concorrentes: se já há um carregamento em
 * curso, devolve a mesma promessa.
 */
export function garantirContextoGrade(): Promise<ContextoGrade> {
	if (contextoEmVoo) return contextoEmVoo;

	contextoEmVoo = (async (): Promise<ContextoGrade> => {
		try {
			if (!fluxogramaStore.state.courseData) {
				const matriz = authStore.getUser()?.dadosFluxograma?.matrizCurricular ?? null;
				if (!matriz) return null;
				await fluxogramaStore.loadCourseDataByCurriculoCompleto(matriz);
			}
			const idUser = authStore.getUser()?.idUser ?? null;
			const periodo = await getPeriodoAtivo();
			const pool = await construirMateriasGrade(lerPoolSalvo(idUser, periodo), periodo);
			gradeStore.init(pool, { idUser, periodo });
			return { periodo };
		} catch {
			contextoEmVoo = null; // deixa tentar de novo numa próxima navegação
			return null;
		}
	})();

	return contextoEmVoo;
}

/** Descarta o contexto memoizado — a página do montador reinicializa o store. */
export function invalidarContextoGrade(): void {
	contextoEmVoo = null;
}
