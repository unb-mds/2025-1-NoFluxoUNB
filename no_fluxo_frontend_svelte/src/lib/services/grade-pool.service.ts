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
import { hasConflict, turmaRespeitaTurnos } from '$lib/utils/horario-slots';

/**
 * Partes de pré-requisito ainda não cumpridas (código ou, quando o registro não
 * traz código, a expressão do SIGAA). `null` = nada pendente.
 *
 * Vive separado de `calcularRequisitos` porque o aviso inline corta em 3 partes
 * enquanto o pop-up de confirmação precisa da lista inteira — e a avaliação da
 * expressão lógica (AND/OR) não pode ficar duplicada nos dois lugares.
 */
function partesPreRequisitoPendentes(idMateria: number): string[] | null {
	const curso = fluxogramaStore.state.courseData;
	// O montador planeja o PRÓXIMO semestre, então o que está em curso agora já terá
	// sido cursado quando essas turmas começarem. É a mesma conta que o Motor 2 faz
	// para recomendar (`completedPlusMatr` em plano_formatura.service.ts): sem isso o
	// frontend carimbava "pré-requisito pendente" na própria recomendação que acabou
	// de receber do backend — ex.: FGA0240 exige FGA0238, que o aluno está cursando.
	const cumpridos = new Set([
		...fluxogramaStore.completedCodes,
		...(fluxogramaStore.currentCodes ?? [])
	]);

	const prereqs = (curso?.preRequisitos ?? []).filter((pr) => pr.idMateria === idMateria);
	if (prereqs.length === 0 || satisfazPreRequisitos(prereqs, cumpridos)) return null;

	const partes = new Set<string>();
	for (const pr of prereqs) {
		const code = pr.codigoMateriaRequisito?.trim();
		if (code) {
			if (!setHasCodeIgnoreCase(cumpridos, code)) partes.add(code);
		} else if (pr.expressaoOriginal?.trim()) {
			partes.add(pr.expressaoOriginal.trim());
		}
	}
	return [...partes];
}

/**
 * Requisitos da matéria a partir do courseData: aviso de pré-requisito pendente
 * (não bloqueia) e lista de co-requisitos. Só resolve p/ matérias da matriz —
 * optativas de fora não têm essas regras no courseData e passam sem aviso.
 */
export function calcularRequisitos(idMateria: number): {
	avisoPreRequisito: string | null;
	coRequisitos: string[];
} {
	const curso = fluxogramaStore.state.courseData;
	const completed = fluxogramaStore.completedCodes;
	const current = fluxogramaStore.currentCodes ?? new Set<string>();

	const pendentes = partesPreRequisitoPendentes(idMateria);
	const avisoPreRequisito =
		pendentes === null
			? null
			: pendentes.length > 0
				? pendentes.slice(0, 3).join(' · ')
				: 'requisitos não cumpridos';

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
		const { avisoPreRequisito, coRequisitos } = calcularRequisitos(r.idMateria);
		out.push({
			codigo,
			nome: r.nome,
			creditos: r.creditos,
			idMateria: r.idMateria,
			avisoPreRequisito,
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

/** O que a semeadura conseguiu trazer para a lista, por procedência. */
export interface SemeaduraResultado {
	/** Códigos vindos do semestre recomendado do plano de formatura. */
	doPlano: string[];
	/** Códigos puxados da matriz porque o plano não tinha matéria concreta a semear. */
	daMatriz: string[];
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
	const matriz = fluxogramaStore.state.courseData?.materias ?? [];
	if (matriz.length === 0) return [];

	const fora = new Set([...excluir].map((c) => c.trim().toUpperCase()));
	const codigos = filtrarNaoCursados(
		matriz.map((m) => m.codigoMateria).filter((c) => !fora.has(c.trim().toUpperCase())),
		fluxogramaStore.completedCodes,
		fluxogramaStore.currentCodes ?? new Set<string>()
	);
	if (codigos.length === 0) return [];

	const daMatriz = new Map(matriz.map((m) => [m.codigoMateria.trim().toUpperCase(), m]));

	return (await construirMateriasGrade(codigos, periodo))
		.filter((m) => m.turmas.length > 0)
		.map((m) => {
			const info = daMatriz.get(m.codigo);
			return {
				materia: m,
				requisitoPendente: m.avisoPreRequisito ? 1 : 0,
				optativa: info && isOptativa(info) ? 1 : 0,
				// Optativa tem nivel 0 na matriz; o critério anterior já a separou.
				nivel: info?.nivel ?? 99
			};
		})
		.sort(
			(a, b) =>
				a.requisitoPendente - b.requisitoPendente ||
				a.optativa - b.optativa ||
				a.nivel - b.nivel ||
				a.materia.codigo.localeCompare(b.materia.codigo)
		)
		.map((x) => x.materia);
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
	const escolhidas: MateriaGrade[] = [];
	let mask = gradeStore.combinedMask;
	let creditos = gradeStore.creditosSelecionados;

	for (const m of candidatos) {
		if (creditos + m.creditos > limiteCreditos) continue; // pode caber uma menor adiante
		const turma = m.turmas.find(
			(t) => turmaRespeitaTurnos(t.mask, gradeStore.turnosPermitidos) && !hasConflict(t.mask, mask)
		);
		if (!turma) continue;
		mask |= turma.mask;
		creditos += m.creditos;
		escolhidas.push(m);
	}

	return escolhidas;
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
