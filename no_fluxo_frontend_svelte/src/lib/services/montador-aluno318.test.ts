/**
 * Reprodução do chamado do aluno 318 (ENGENHARIA DE SOFTWARE, matriz 6360/1).
 *
 * Relato: "não considerou as MATR, não trouxe as obrigatórias do meu curso, não
 * procurou por equivalência, botou matéria que nem o pré-requisito eu tenho".
 *
 * Aqui roda o caminho REAL da rota `/planejamento/grade`: plano de formatura do
 * Motor 2 (gerado de verdade e congelado no fixture) → `semear()` → montagem.
 * Só as duas funções de rede são mockadas, como na suíte de dados reais.
 *
 * Gere o fixture com:  node <scratchpad>/extrair-318.cjs
 * e aponte:            MONTADOR_FIXTURE_318=<caminho>/fixture-318.json
 */
import { describe, it, expect, beforeAll, beforeEach, vi } from 'vitest';
import fs from 'node:fs';

const CAMINHO =
	process.env.MONTADOR_FIXTURE_318 ??
	'C:/Users/FELIPE~1/AppData/Local/Temp/claude/C--Users-Felipe-Pedroza-Documents-UnB-nofluxo-2025-1-NoFluxoUNB/b9ea3c94-f2b4-4264-8e97-2f43a0a91c1c/scratchpad/fixture-318.json';

const TEM = fs.existsSync(CAMINHO);

const dados = vi.hoisted(() => ({
	periodo: '',
	turmas: [] as Record<string, unknown>[],
	materias: [] as Record<string, unknown>[]
}));

vi.mock('$lib/services/turmas.service', () => ({
	getPeriodoAtivo: async () => dados.periodo,
	getTurmasPorMaterias: async (ids: number[]) => {
		const set = new Set(ids.map(Number));
		return dados.turmas.filter((t) => set.has(Number(t.id_materia)));
	},
	searchTurmas: async () => []
}));

vi.mock('$lib/services/materias.service', () => ({
	getMateriasByCodigos: async (codigos: string[]) => {
		const alvo = new Set(codigos.map((c) => String(c).trim().toUpperCase()));
		return dados.materias
			.filter((m) => alvo.has(String(m.codigo_materia).trim().toUpperCase()))
			.map((m) => ({
				idMateria: Number(m.id_materia),
				codigo: String(m.codigo_materia),
				nome: String(m.nome_materia),
				creditos: Number(m.carga_horaria ?? 0) > 0 ? Math.round(Number(m.carga_horaria) / 15) : 0
			}));
	},
	searchMaterias: async () => []
}));

import { authStore } from '$lib/stores/auth';
import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
import { gradeStore, type MateriaGrade } from '$lib/stores/grade.store.svelte';
import {
	construirMateriasGrade,
	candidatosDaMatriz,
	escolherAteOLimite
} from '$lib/services/grade-pool.service';
import { filtrarNaoCursados } from '$lib/utils/subject-codes';
import {
	createDadosFluxogramaUserFromJson,
	createMateriaModelFromJson,
	createPreRequisitoModelFromJson,
	createCoRequisitoModelFromJson,
	createEquivalenciaModelFromJson
} from '$lib/factories';
import type { CursoModel } from '$lib/types/curso';
import type { UserModel } from '$lib/types/user';

interface Fixture {
	periodo: string;
	alunos: Array<{
		id_user: number;
		semestre_atual: number;
		matriz: string;
		nome_curso: string;
		dados_fluxograma: Record<string, unknown>[][];
	}>;
	courseDataPorMatriz: Record<string, Record<string, unknown>>;
	materiasPorCodigo: Record<string, unknown>[];
	turmas: Record<string, unknown>[];
	planoPorAluno: Record<
		string,
		{ plano: Array<{ semestre: string; tipo: string; materias: Array<{ codigo?: string }> }> }
	>;
}

let fx: Fixture;

function montarCursoModel(raw: Record<string, unknown>): CursoModel {
	const materias = ((raw.materias as Record<string, unknown>[]) ?? []).map(
		createMateriaModelFromJson
	);
	const preRequisitos = ((raw.preRequisitos as Record<string, unknown>[]) ?? []).map(
		createPreRequisitoModelFromJson
	);
	const coRequisitos = ((raw.coRequisitos as Record<string, unknown>[]) ?? []).map(
		createCoRequisitoModelFromJson
	);
	const equivalencias = ((raw.equivalenciasRaw as Record<string, unknown>[]) ?? [])
		.map((eq) => {
			const mat = eq.materias as { codigo_materia?: string; nome_materia?: string } | null;
			return {
				...eq,
				codigo_materia_origem: mat?.codigo_materia ?? '',
				nome_materia_origem: mat?.nome_materia ?? '',
				expressao: eq.expressao_original ?? '',
				expressao_logica: eq.expressao_logica ?? null
			};
		})
		.map(createEquivalenciaModelFromJson);

	const norm = (c: string) => (c || '').trim().toUpperCase();
	const codes = new Set(materias.map((m) => norm(m.codigoMateria)));
	const ids = new Set(materias.map((m) => m.idMateria));
	const curso = (raw.curso as Record<string, unknown>) ?? {};

	return {
		idCurso: Number(curso.id_curso ?? 0),
		nomeCurso: String(curso.nome_curso ?? ''),
		matrizCurricular: String(curso.matriz_curricular ?? ''),
		materias,
		preRequisitos: preRequisitos.filter((pr) => ids.has(pr.idMateria)),
		coRequisitos: coRequisitos.filter((cr) => codes.has(norm(cr.codigoMateriaCoRequisito || ''))),
		equivalencias
	} as unknown as CursoModel;
}

function carregarAluno(): void {
	const aluno = fx.alunos[0];
	fluxogramaStore.state.courseData = montarCursoModel(fx.courseDataPorMatriz[aluno.matriz]);
	authStore.setUser({
		idUser: aluno.id_user,
		email: 'fixture@local',
		nomeCompleto: 'Fixture',
		dadosFluxograma: createDadosFluxogramaUserFromJson({
			nome_curso: aluno.nome_curso,
			ira: 0,
			matricula: '',
			horas_integralizadas: 0,
			suspensoes: [],
			ano_atual: '',
			matriz_curricular: aluno.matriz,
			semestre_atual: aluno.semestre_atual,
			dados_fluxograma: aluno.dados_fluxograma
		})
	} as unknown as UserModel);
}

/** Réplica de `codigosRecomendados()` da rota (grade/+page.svelte). */
function codigosRecomendados(): string[] {
	const p = fx.planoPorAluno[String(fx.alunos[0].id_user)];
	const semestres = p?.plano ?? [];
	const rec =
		semestres.find((s) => s.tipo === 'recomendado') ??
		semestres.find((s) => s.tipo !== 'em_curso') ??
		semestres[0];
	return (rec?.materias ?? []).filter((m) => m.codigo).map((m) => m.codigo!);
}

/** Réplica de `semear()` da rota, passo a passo e instrumentada. */
async function semear(limiteCreditos: number) {
	const periodo = fx.periodo;
	const recomendados = codigosRecomendados();

	const aposRemovidasEPool = recomendados.filter(
		(c) => !gradeStore.removidas.has(c) && !gradeStore.hasMateria(c)
	);
	const aposNaoCursados = filtrarNaoCursados(
		aposRemovidasEPool,
		fluxogramaStore.completedCodes,
		fluxogramaStore.currentCodes ?? new Set<string>()
	);
	const doPlano =
		aposNaoCursados.length > 0 ? await construirMateriasGrade(aposNaoCursados, periodo) : [];
	for (const m of doPlano) gradeStore.addMateriaAoPool(m);

	let daMatriz: MateriaGrade[] = [];
	let caiuNoFallback = false;
	if (!gradeStore.pool.some((m) => m.turmas.length > 0)) {
		caiuNoFallback = true;
		daMatriz = escolherAteOLimite(
			await candidatosDaMatriz(
				periodo,
				gradeStore.pool.map((m) => m.codigo)
			),
			limiteCreditos
		);
		for (const m of daMatriz) gradeStore.addMateriaAoPool(m);
	}

	return { recomendados, aposRemovidasEPool, aposNaoCursados, doPlano, daMatriz, caiuNoFallback };
}

describe.skipIf(!TEM)('Montador — chamado do aluno 318', () => {
	beforeAll(() => {
		fx = JSON.parse(fs.readFileSync(CAMINHO, 'utf8')) as Fixture;
		dados.periodo = fx.periodo;
		dados.turmas = fx.turmas;
		dados.materias = fx.materiasPorCodigo;
	});

	beforeEach(() => {
		gradeStore.definirCursandoAtual([]);
		gradeStore.init([], { idUser: null, periodo: 'reset' });
		carregarAluno();
	});

	it('diagnóstico: onde cada recomendada do plano se perde', async () => {
		gradeStore.init([], { idUser: null, periodo: fx.periodo });
		const r = await semear(24);

		const linhas = r.recomendados.map((c) => {
			const construida = r.doPlano.find((m) => m.codigo === c);
			return {
				codigo: c,
				noPlano: true,
				passouRemovidas: r.aposRemovidasEPool.includes(c),
				passouNaoCursados: r.aposNaoCursados.includes(c),
				construida: !!construida,
				turmas: construida?.turmas.length ?? 0,
				natureza: construida?.natureza ?? '-'
			};
		});
		console.log('\n=== ALUNO 318 · CADA RECOMENDADA DO PLANO ===');
		console.table(linhas);
		console.log('caiu no fallback da matriz?', r.caiuNoFallback);
		console.log(
			'pool final:',
			gradeStore.pool.map((m) => `${m.codigo}(${m.turmas.length}t)`).join(', ')
		);

		expect(r.recomendados.length).toBeGreaterThan(0);
	}, 60_000);

	it('as obrigatórias pendentes COM oferta entram na grade', async () => {
		gradeStore.init([], { idUser: null, periodo: fx.periodo });
		gradeStore.definirCursandoAtual([...(fluxogramaStore.currentCodes ?? [])]);
		await semear(24);
		gradeStore.montarAutomatico({ limiteCreditos: 24 });

		// Verificadas no banco: têm turma em 2026.2 e o aluno não cursou nem cursa.
		const ESPERADAS = ['IFD0171', 'FGA0060', 'FGA0211'];
		const naGrade = new Set(gradeStore.selecao.keys());
		const faltando = ESPERADAS.filter((c) => !naGrade.has(c));

		console.log('\n=== GRADE MONTADA (aluno 318) ===');
		console.log([...naGrade].join(', '));

		expect(
			faltando,
			`obrigatórias pendentes com oferta que ficaram de fora: ${faltando.join(', ')}`
		).toEqual([]);
	}, 60_000);

	it('nenhuma matéria da grade tem pré-requisito não cumprido', async () => {
		gradeStore.init([], { idUser: null, periodo: fx.periodo });
		gradeStore.definirCursandoAtual([...(fluxogramaStore.currentCodes ?? [])]);
		await semear(24);
		gradeStore.montarAutomatico({ limiteCreditos: 24 });

		const comPendencia = [...gradeStore.selecao.keys()].filter((c) => {
			const m = gradeStore.pool.find((x) => x.codigo === c);
			return !!m?.avisoPreRequisito;
		});

		expect(
			comPendencia,
			`entraram na grade com pré-requisito pendente: ${comPendencia.join(', ')}`
		).toEqual([]);
	}, 60_000);

	it('a MATR sem oferta no próprio código acha turma pela equivalente', async () => {
		// FGA0238 (TESTES DE SOFTWARE) tem 0 turmas em 2026.2, mas equivale a
		// FGA0237/FGA0314 — e é em FGA0314 que o aluno está matriculado.
		const construidas = await construirMateriasGrade(['FGA0238'], fx.periodo);
		const fga238 = construidas.find((m) => m.codigo === 'FGA0238');

		console.log('\n=== EQUIVALÊNCIA FGA0238 ===');
		console.log(
			'turmas:',
			fga238?.turmas.map((t) => `${t.codigoOfertado ?? 'FGA0238'}·${t.turma.horario}`).join(', ') ||
				'(nenhuma)'
		);

		expect(fga238, 'FGA0238 não foi sequer construída').toBeTruthy();
		expect(
			fga238!.turmas.length,
			'FGA0238 não tem oferta própria; a equivalência com FGA0314 deveria trazer turma'
		).toBeGreaterThan(0);
	}, 60_000);
});

/**
 * O defeito isolado, com os dados do aluno 318.
 *
 * FGA0240 (GERÊNCIA DE CONFIGURAÇÃO) exige FGA0238, que ele está CURSANDO agora.
 * O Motor 2 recomenda FGA0240 para 2027.1 justamente porque monta o conjunto
 * `completedPlusMatr` — para o próximo semestre, o que está em curso já terá sido
 * cursado. O frontend avalia a mesma regra só contra as concluídas e carimba
 * "pré-requisito pendente" na própria recomendação que acabou de receber.
 *
 * É o "botou matéria que nem o pré-requisito eu tenho ainda": os dois lados do app
 * respondem diferente à mesma pergunta.
 */
describe.skipIf(!TEM)('Montador — pré-requisito em curso conta para o próximo semestre', () => {
	beforeAll(() => {
		fx = JSON.parse(fs.readFileSync(CAMINHO, 'utf8')) as Fixture;
		dados.periodo = fx.periodo;
		dados.turmas = fx.turmas;
		dados.materias = fx.materiasPorCodigo;
	});

	beforeEach(() => {
		gradeStore.definirCursandoAtual([]);
		gradeStore.init([], { idUser: null, periodo: 'reset' });
		carregarAluno();
	});

	it('FGA0240 não é marcada como pendente: FGA0238 está em curso', async () => {
		const construidas = await construirMateriasGrade(['FGA0240'], fx.periodo);
		const fga240 = construidas.find((m) => m.codigo === 'FGA0240');

		expect(fluxogramaStore.currentCodes?.has('FGA0238'), 'FGA0238 deveria estar em curso').toBe(
			true
		);
		expect(
			fga240?.avisoPreRequisito,
			'FGA0238 está em curso — para 2027.1 o pré-requisito está encaminhado'
		).toBeNull();
	}, 60_000);

	it('pré-requisito que ele NÃO cursou nem está cursando continua avisando', async () => {
		// FGA0211 exige FGA0170, que não está no histórico dele de forma nenhuma.
		const construidas = await construirMateriasGrade(['FGA0211'], fx.periodo);
		const fga211 = construidas.find((m) => m.codigo === 'FGA0211');

		const temFGA0170 =
			fluxogramaStore.completedCodes.has('FGA0170') ||
			(fluxogramaStore.currentCodes?.has('FGA0170') ?? false);
		if (!temFGA0170) {
			expect(
				fga211?.avisoPreRequisito,
				'FGA0170 não cursado: o aviso tem de aparecer'
			).toBeTruthy();
		}
	}, 60_000);
});
