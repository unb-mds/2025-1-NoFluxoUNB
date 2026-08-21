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
import { classificarNatureza } from '$lib/types/materia';
import { setHasCodeIgnoreCase } from '$lib/utils/subject-codes';

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
		avisoPreRequisito =
			partes.size > 0 ? [...partes].slice(0, 3).join(' · ') : 'requisitos não cumpridos';
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
