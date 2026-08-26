/**
 * Montador de Grade — suíte contra HISTÓRICOS REAIS.
 *
 * Roda o motor de verdade (grade-pool.service + gradeStore + resolução de
 * equivalência) sobre uma amostra de históricos extraída do banco, em vez dos
 * pools sintéticos dos outros testes. Serve para achar o que só aparece com
 * matriz grande, oferta real e histórico bagunçado.
 *
 * ── Como rodar ──────────────────────────────────────────────────────────────
 * O fixture NÃO é versionado (é derivado de dado de aluno). Gere com:
 *   node <scratchpad>/extrair-fixtures.cjs
 * e aponte o caminho:
 *   MONTADOR_FIXTURES=<caminho>/fixtures-montador.json npm run test:unit
 * Sem o arquivo, a suíte inteira é pulada — não quebra o CI.
 *
 * ── O que é mockado ─────────────────────────────────────────────────────────
 * Só as DUAS funções que fazem rede (`getTurmasPorMaterias`, `getMateriasByCodigos`),
 * alimentadas pelo fixture. Tudo acima disso — `construirMateriasGrade`,
 * `getOfertaComEquivalencia`, `construirSubstitutosPorCodigo`,
 * `candidatosDaMatriz`, `escolherAteOLimite`, `montarAutomatico` — é o código
 * de produção rodando de verdade.
 */
import { describe, it, expect, beforeAll, beforeEach, vi } from 'vitest';
import fs from 'node:fs';

const CAMINHO_FIXTURES =
	process.env.MONTADOR_FIXTURES ??
	'C:/Users/FELIPE~1/AppData/Local/Temp/claude/C--Users-Felipe-Pedroza-Documents-UnB-nofluxo-2025-1-NoFluxoUNB/31d0c2f9-8804-4a52-aa53-01a0de8c9ac4/scratchpad/fixtures-montador.json';

const TEM_FIXTURES = fs.existsSync(CAMINHO_FIXTURES);

/** Preenchido no beforeAll; os mocks (hoisted) leem daqui. */
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
	escolherAteOLimite,
	motivoParaNaoAdicionar
} from '$lib/services/grade-pool.service';
import { filtrarNaoCursados } from '$lib/utils/subject-codes';
import { hasConflict, turmaRespeitaTurnos } from '$lib/utils/horario-slots';
import { satisfazPreRequisitos } from '$lib/types/curso';
import {
	createDadosFluxogramaUserFromJson,
	createMateriaModelFromJson,
	createPreRequisitoModelFromJson,
	createCoRequisitoModelFromJson,
	createEquivalenciaModelFromJson
} from '$lib/factories';
import type { CursoModel } from '$lib/types/curso';
import type { UserModel } from '$lib/types/user';

interface AlunoFixture {
	id_user: number;
	semestre_atual: number;
	matriz: string;
	nome_curso: string;
	statuses: Record<string, number>;
	dados_fluxograma: Record<string, unknown>[][];
}

interface Fixtures {
	periodo: string;
	alunos: AlunoFixture[];
	courseDataPorMatriz: Record<string, Record<string, unknown>>;
	materiasPorCodigo: Record<string, unknown>[];
	turmas: Record<string, unknown>[];
}

let fx: Fixtures;

/** Espelha o buildCursoModelFromRaw privado de fluxograma.service.ts:230. */
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
	// O extrator já aplicou o filtro de contexto (curso/currículo) da produção;
	// aqui só falta o mapeamento que o serviço faz antes da factory.
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

/** Coloca o aluno + a matriz dele nos stores globais, como a rota faz. */
function carregarAluno(aluno: AlunoFixture): void {
	const curso = montarCursoModel(fx.courseDataPorMatriz[aluno.matriz]);
	fluxogramaStore.state.courseData = curso;

	const dadosFluxograma = createDadosFluxogramaUserFromJson({
		nome_curso: aluno.nome_curso,
		ira: 0,
		matricula: '',
		horas_integralizadas: 0,
		suspensoes: [],
		ano_atual: '',
		matriz_curricular: aluno.matriz,
		semestre_atual: aluno.semestre_atual,
		dados_fluxograma: aluno.dados_fluxograma
	});

	authStore.setUser({
		idUser: aluno.id_user,
		email: 'fixture@local',
		nomeCompleto: 'Fixture',
		dadosFluxograma
	} as unknown as UserModel);
}

/** Turmas realmente escolhidas na grade ativa. */
function selecionadas(): { codigo: string; mask: bigint }[] {
	return [...gradeStore.selecao].map(([codigo, tg]) => ({ codigo, mask: tg.mask }));
}

/**
 * Reproduz o fluxo da rota `/planejamento/grade`: pool inicial (só as MATR,
 * porque não há plano de formatura no fixture) → semeadura pela matriz →
 * montagem automática.
 */
async function montarGradeDoAluno(
	limiteCreditos: number,
	/**
	 * Semeia da matriz mesmo quando as MATR já enchem o pool.
	 *
	 * Sem isso o pool do fixture é 100% MATR — ou seja, tudo obrigatório — e o teto
	 * de créditos nunca chega a morder. Na rota real o plano de formatura contribui
	 * matérias opcionais; como o fixture não tem plano, forçar a semeadura é o que
	 * reproduz aquele cenário.
	 */
	forcarSemeadura = false
): Promise<{
	cursando: string[];
	poolInicial: MateriaGrade[];
	semeadas: MateriaGrade[];
	msSolver: number;
}> {
	const periodo = fx.periodo;
	const cursando = [...(fluxogramaStore.currentCodes ?? new Set<string>())];

	const todos = filtrarNaoCursados(
		[],
		fluxogramaStore.completedCodes,
		fluxogramaStore.currentCodes ?? new Set<string>()
	);
	const pool = await construirMateriasGrade([...new Set([...todos, ...cursando])], periodo);
	gradeStore.init(pool, { idUser: null, periodo });
	gradeStore.definirCursandoAtual(cursando);

	// Semeadura: sem plano, a rota cai na matriz (grade/+page.svelte:97).
	let semeadas: MateriaGrade[] = [];
	if (forcarSemeadura || !gradeStore.pool.some((m) => m.turmas.length > 0)) {
		semeadas = escolherAteOLimite(
			await candidatosDaMatriz(periodo, gradeStore.pool.map((m) => m.codigo)),
			limiteCreditos
		);
		for (const m of semeadas) gradeStore.addMateriaAoPool(m);
	}

	// Só o solver — é ele que roda na thread principal a cada "Montar grade".
	// A semeadura acima custa bem mais, mas é I/O + construção de pool, não busca.
	const t0 = performance.now();
	gradeStore.montarAutomatico({ limiteCreditos });
	const msSolver = Math.round(performance.now() - t0);
	return { cursando, poolInicial: pool, semeadas, msSolver };
}

interface Linha {
	aluno: number;
	curso: string;
	sem: number;
	matrMateria: number;
	matrNoPool: number;
	matrSemOferta: number;
	matrNaGrade: number;
	poolTotal: number;
	naGrade: number;
	creditos: number;
	semHorario: number;
	viaEquivalencia: number;
	preReqPendente: number;
	coReqFaltando: number;
}

const relatorio: Linha[] = [];

/** Códigos MATR que não chegaram ao pool — o sintoma "nem aparece na lista". */
const sumidas: Record<string, unknown>[] = [];

describe.skipIf(!TEM_FIXTURES)('Montador de Grade — históricos reais', () => {
	beforeAll(() => {
		fx = JSON.parse(fs.readFileSync(CAMINHO_FIXTURES, 'utf8')) as Fixtures;
		dados.periodo = fx.periodo;
		dados.turmas = fx.turmas;
		dados.materias = fx.materiasPorCodigo;
	});

	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: 'reset' });
	});

	it('o fixture tem alunos e oferta', () => {
		expect(fx.alunos.length).toBeGreaterThan(0);
		expect(fx.turmas.length).toBeGreaterThan(0);
		console.log(
			`\n[fixture] período=${fx.periodo} alunos=${fx.alunos.length} matrizes=${
				Object.keys(fx.courseDataPorMatriz).length
			} turmas=${fx.turmas.length}`
		);
	});

	describe('por aluno', () => {
		it('monta a grade de cada aluno e mede os 5 eixos', async () => {
			for (const aluno of fx.alunos) {
				carregarAluno(aluno);
				const limite = 24;
				const { cursando } = await montarGradeDoAluno(limite);

				const curso = fluxogramaStore.state.courseData!;
				const sel = selecionadas();
				const naGradeSet = new Set(sel.map((s) => s.codigo));

				// ── MATR ────────────────────────────────────────────────────────────
				const matrNoHistorico = new Set(
					aluno.dados_fluxograma
						.flat()
						.filter((m) => String(m.status ?? '').toUpperCase() === 'MATR')
						.map((m) => String(m.codigo ?? '').trim().toUpperCase())
						.filter(Boolean)
				);
				const noPool = gradeStore.pool.filter((m) => matrNoHistorico.has(m.codigo));
				const matrSemOferta = noPool.filter((m) => m.turmas.length === 0).length;
				const matrNaGrade = [...matrNoHistorico].filter((c) => naGradeSet.has(c)).length;

				// Diagnóstico do sintoma "MATR nem aparece na lista": quais códigos
				// sumiram, e em que etapa.
				const poolSet = new Set(gradeStore.pool.map((m) => m.codigo));
				const naMatriz = new Set(
					curso.materias.map((m) => m.codigoMateria.trim().toUpperCase())
				);
				for (const c of matrNoHistorico) {
					if (poolSet.has(c)) continue;
					sumidas.push({
						aluno: aluno.id_user,
						codigo: c,
						estaNaMatriz: naMatriz.has(c),
						estaEmCurrentCodes: (fluxogramaStore.currentCodes ?? new Set()).has(c),
						contadaComoConcluida: fluxogramaStore.completedCodes.has(c),
						temMateriaNoBanco: fx.materiasPorCodigo.some(
							(m) => String(m.codigo_materia).trim().toUpperCase() === c
						)
					});
				}

				// ── Equivalência: matéria cuja oferta veio de OUTRO código ───────────
				const viaEquivalencia = gradeStore.pool.filter((m) =>
					m.turmas.some((t) => t.codigoOfertado)
				).length;

				// ── Pré/co-requisito das matérias que entraram na grade ─────────────
				const porCodigo = new Map(
					curso.materias.map((m) => [m.codigoMateria.trim().toUpperCase(), m])
				);
				let preReqPendente = 0;
				for (const c of naGradeSet) {
					const info = porCodigo.get(c);
					if (!info) continue;
					const prs = (curso.preRequisitos ?? []).filter((p) => p.idMateria === info.idMateria);
					if (prs.length > 0 && !satisfazPreRequisitos(prs, fluxogramaStore.completedCodes)) {
						preReqPendente++;
					}
				}
				let coReqFaltando = 0;
				for (const c of naGradeSet) coReqFaltando += gradeStore.coReqsFaltando(c).length;

				relatorio.push({
					aluno: aluno.id_user,
					curso: aluno.nome_curso.slice(0, 22),
					sem: aluno.semestre_atual,
					matrMateria: matrNoHistorico.size,
					matrNoPool: noPool.length,
					matrSemOferta,
					matrNaGrade,
					poolTotal: gradeStore.pool.length,
					naGrade: sel.length,
					creditos: gradeStore.creditosSelecionados,
					semHorario: sel.filter((s) => s.mask === 0n).length,
					viaEquivalencia,
					preReqPendente,
					coReqFaltando
				});

				// ── INVARIANTE 1: nenhuma sobreposição de horário ───────────────────
				for (let i = 0; i < sel.length; i++) {
					for (let j = i + 1; j < sel.length; j++) {
						expect(
							hasConflict(sel[i].mask, sel[j].mask),
							`aluno ${aluno.id_user}: ${sel[i].codigo} conflita com ${sel[j].codigo}`
						).toBe(false);
					}
				}

				// ── INVARIANTE 2: só matéria do pool entra na grade ─────────────────
				const poolCodes = new Set(gradeStore.pool.map((m) => m.codigo));
				for (const s of sel) {
					expect(poolCodes.has(s.codigo), `aluno ${aluno.id_user}: ${s.codigo} fora do pool`).toBe(
						true
					);
				}

				// ── INVARIANTE 3: nada já aprovado entra no pool ────────────────────
				for (const m of gradeStore.pool) {
					const jaAprovada =
						fluxogramaStore.completedCodes.has(m.codigo) &&
						!matrNoHistorico.has(m.codigo);
					expect(jaAprovada, `aluno ${aluno.id_user}: ${m.codigo} já concluída no pool`).toBe(
						false
					);
				}

				void cursando;
			}

			// Relatório legível — é o que você vai conferir.
			console.log('\n=== RESULTADO POR ALUNO ===');
			console.table(relatorio);

			console.log('\n=== MATR QUE NAO CHEGARAM AO POOL ===');
			if (sumidas.length === 0) console.log('(nenhuma)');
			else console.table(sumidas);
		});
	});

	describe('eixo: turnos', () => {
		it('a montagem respeita os turnos permitidos', async () => {
			const aluno = fx.alunos.find((a) => (a.statuses.MATR ?? 0) > 0) ?? fx.alunos[0];
			carregarAluno(aluno);
			gradeStore.setTurnos(['M']);
			await montarGradeDoAluno(24);

			const turnos = gradeStore.turnosPermitidos;
			for (const { codigo, mask } of selecionadas()) {
				// Travadas/cursando podem ficar fora do filtro por design; as demais não.
				if (gradeStore.isTravada(codigo)) continue;
				expect(turmaRespeitaTurnos(mask, turnos), `${codigo} fora do turno M`).toBe(true);
			}
			gradeStore.setTurnos(['M', 'T', 'N']);
		});
	});

	describe('eixo: limite de créditos', () => {
		it('ajustarParaLimite desce até o limite sem derrubar travada', async () => {
			const linhas: Record<string, unknown>[] = [];
			for (const aluno of fx.alunos.slice(0, 6)) {
				carregarAluno(aluno);
				await montarGradeDoAluno(24);
				const antes = gradeStore.creditosSelecionados;
				const travadas = [...gradeStore.selecao.keys()].filter((c) => gradeStore.isTravada(c));

				gradeStore.ajustarParaLimite(12);
				const depois = gradeStore.creditosSelecionados;

				for (const c of travadas) {
					expect(gradeStore.selecao.has(c), `travada ${c} foi derrubada pelo slider`).toBe(true);
				}
				linhas.push({ aluno: aluno.id_user, antes, depois, limite: 12, travadas: travadas.length });
			}
			console.log('\n=== LIMITE DE CRÉDITOS (alvo 12) ===');
			console.table(linhas);
		});
	});

	describe('eixo: limite de créditos com matérias opcionais no pool', () => {
		/**
		 * Aceitação do defeito 2. Critério: ou a grade cabe no limite, ou o que
		 * estourou é só matrícula real (obrigatória) — nunca opcional empilhada
		 * por cima do teto.
		 */
		it('a montagem nunca passa do limite por causa de matéria opcional', async () => {
			const linhas: Record<string, unknown>[] = [];
			for (const aluno of fx.alunos) {
				carregarAluno(aluno);
				const limite = 20;
				const { msSolver } = await montarGradeDoAluno(limite, true);

				const cursando = fluxogramaStore.currentCodes ?? new Set<string>();
				let creditosObrigatorios = 0;
				let opcionaisNaGrade = 0;
				for (const codigo of gradeStore.selecao.keys()) {
					const m = gradeStore.pool.find((x) => x.codigo === codigo);
					if (!m) continue;
					if (cursando.has(codigo)) creditosObrigatorios += m.creditos;
					else opcionaisNaGrade++;
				}
				const total = gradeStore.creditosSelecionados;

				linhas.push({
					aluno: aluno.id_user,
					limite,
					total,
					obrigatorios: creditosObrigatorios,
					opcionaisNaGrade,
					poolTotal: gradeStore.pool.length,
					saturado: creditosObrigatorios >= limite,
					msSolver
				});

				expect(
					total <= limite || total === creditosObrigatorios,
					`aluno ${aluno.id_user}: ${total}cr > limite ${limite} e só ${creditosObrigatorios}cr são obrigatórios — sobrou opcional acima do teto`
				).toBe(true);
			}
			console.log('\n=== LIMITE COM OPCIONAIS NO POOL (alvo 20) ===');
			console.table(linhas);
		}, 60_000);
	});

	describe('eixo: equivalências ao adicionar matéria', () => {
		it('não deixa adicionar matéria já concluída por equivalência', async () => {
			const linhas: Record<string, unknown>[] = [];
			for (const aluno of fx.alunos) {
				carregarAluno(aluno);
				const curso = fluxogramaStore.state.courseData!;

				// Códigos que só são "concluídos" via equivalência (não estão crus no histórico).
				const crus = new Set(
					aluno.dados_fluxograma
						.flat()
						.map((m) => String(m.codigo ?? '').trim().toUpperCase())
						.filter(Boolean)
				);
				const porEquiv = [...fluxogramaStore.completedCodes].filter((c) => !crus.has(c));

				let bloqueados = 0;
				for (const c of porEquiv) {
					if (motivoParaNaoAdicionar(c)) bloqueados++;
				}
				expect(
					bloqueados,
					`aluno ${aluno.id_user}: ${porEquiv.length - bloqueados} matérias concluídas por equivalência ainda podem ser adicionadas`
				).toBe(porEquiv.length);

				linhas.push({
					aluno: aluno.id_user,
					concluidasPorEquiv: porEquiv.length,
					bloqueadas: bloqueados,
					equivalenciasNaMatriz: curso.equivalencias?.length ?? 0
				});
			}
			console.log('\n=== EQUIVALÊNCIAS ===');
			console.table(linhas);
		});
	});
});
