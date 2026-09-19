import { beforeEach, describe, expect, it } from 'vitest';
import {
	normalizeSearchQuery,
	stripDiacritics,
	materiaMatchesNormalizedQuery,
	CurriculumEngine,
	getCurriculumAnalysis,
	clearCurriculumAnalysisCache
} from './curriculum-utils';
import { SubjectStatusEnum } from '../types/materia';
import type { MateriaModel } from '../types/materia';
import type { CursoModel } from '../types/curso';

const materias: MateriaModel[] = [
	{
		idMateria: 1,
		codigoMateria: 'MAT101',
		nomeMateria: 'Cálculo Diferencial e Integral',
		nivel: 1,
		creditos: 4,
		status: SubjectStatusEnum.COMPLETED,
		tipoNatureza: 0
	},
	{
		idMateria: 2,
		codigoMateria: 'FIS201',
		nomeMateria: 'Física Experimental',
		nivel: 2,
		creditos: 4,
		status: SubjectStatusEnum.IN_PROGRESS,
		tipoNatureza: 0
	},
	{
		idMateria: 3,
		codigoMateria: 'EST301',
		nomeMateria: 'Estatística Aplicada',
		nivel: 3,
		creditos: 3,
		status: SubjectStatusEnum.AVAILABLE,
		tipoNatureza: 1
	}
] as MateriaModel[];

function createCurso(): CursoModel {
	const mat101 = { idMateria: 1, codigoMateria: 'MAT101', nomeMateria: 'Cálculo', nivel: 1, creditos: 4, ementa: '' };
	const mat201 = {
		idMateria: 2,
		codigoMateria: 'MAT201',
		nomeMateria: 'Álgebra Linear',
		nivel: 2,
		creditos: 4,
		ementa: '',
		preRequisitos: [mat101]
	};
	const mat301 = {
		idMateria: 3,
		codigoMateria: 'MAT301',
		nomeMateria: 'Probabilidade',
		nivel: 3,
		creditos: 4,
		ementa: '',
		preRequisitos: [mat201]
	};
	const fis201 = { idMateria: 4, codigoMateria: 'FIS201', nomeMateria: 'Física', nivel: 2, creditos: 4, ementa: '' };

	return {
		nomeCurso: 'Engenharia',
		matrizCurricular: '2024.1',
		idCurso: 77,
		totalCreditos: 160,
		classificacao: 'graduacao',
		tipoCurso: 'graduacao',
		materias: [mat101, mat201, mat301, fis201],
		semestres: 3,
		equivalencias: [
			{ idEquivalencia: 1, codigoMateriaOrigem: 'MAT201', nomeMateriaOrigem: 'Álgebra', codigoMateriaEquivalente: 'MAT999', nomeMateriaEquivalente: 'Álgebra 2', expressao: 'MAT201' },
			{ idEquivalencia: 2, codigoMateriaOrigem: 'MAT301', nomeMateriaOrigem: 'Probabilidade', codigoMateriaEquivalente: 'MAT998', nomeMateriaEquivalente: 'Estatística', expressaoLogica: { operador: 'OU', condicoes: ['MAT301', 'MAT999'] } }
		],
		preRequisitos: [],
		coRequisitos: [{ idCoRequisito: 1, idMateria: 2, idMateriaCoRequisito: 4, codigoMateriaCoRequisito: 'FIS201', nomeMateriaCoRequisito: 'Física', expressaoOriginal: null, expressaoLogica: null }],
		curriculoCompleto: '2024.1'
	} as CursoModel;
}

describe('curriculum utils search behavior', () => {
	beforeEach(() => {
		clearCurriculumAnalysisCache();
	});

	it('normaliza acentos e caixa para a busca', () => {
		expect(stripDiacritics('CÁLCULO')).toBe('CALCULO');
		expect(normalizeSearchQuery('CÁLCULO')).toBe('calculo');
	});

	it('acha matérias por código e nome com consulta válida', () => {
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('mat101'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('cálculo'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[1], normalizeSearchQuery('física'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('MAT101'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('CALCULO'))).toBe(true);
	});

	it('aceita consultas parciais e com diacríticos em nomes e códigos', () => {
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('calc'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[1], normalizeSearchQuery('fis'))).toBe(true);
		expect(materiaMatchesNormalizedQuery(materias[2], normalizeSearchQuery('estat'))).toBe(true);
	});

	it('usa a fachada do motor de currículo para normalizar e casar a busca', () => {
		expect(CurriculumEngine.normalizeSearchQuery('CÁLCULO DIFERENCIAL')).toBe('calculo diferencial');
		expect(CurriculumEngine.materiaMatchesNormalizedQuery(materias[0], 'mat101')).toBe(true);
		expect(CurriculumEngine.materiaMatchesNormalizedQuery(materias[0], 'inexistente')).toBe(false);
	});

	it('ignora consultas vazias, com só espaços e caracteres especiais', () => {
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery(''))).toBe(false);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('   '))).toBe(false);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('(( * [ 😄'))).toBe(false);
		expect(materiaMatchesNormalizedQuery(materias[0], normalizeSearchQuery('!@#'))).toBe(false);
	});

	it('não encontra resultados para consultas inexistentes, muito longas ou muito curtas', () => {
		const hugeQuery = 'x'.repeat(2000);
		expect(materiaMatchesNormalizedQuery(materias[2], normalizeSearchQuery(hugeQuery))).toBe(false);
		expect(materiaMatchesNormalizedQuery(materias[2], normalizeSearchQuery('inexistente'))).toBe(false);
		expect(materiaMatchesNormalizedQuery(materias[2], normalizeSearchQuery('a'))).toBe(false);
	});

	it('analisa um currículo com pré-requisitos, dependências, co-requisitos e equivalências', () => {
		const curso = createCurso();
		const first = getCurriculumAnalysis(curso, 'MAT201');
		const second = getCurriculumAnalysis(curso, 'MAT201');
		expect(first).toBe(second);
		expect(first?.focusCode).toBe('MAT201');
		expect(first?.focusMateria?.codigoMateria).toBe('MAT201');
		expect(first?.preRequisites.map((m) => m.codigoMateria)).toEqual(expect.arrayContaining(['MAT101', 'FIS201']));
		expect(first?.dependencies.map((m) => m.codigoMateria)).toEqual(expect.arrayContaining(['MAT301', 'FIS201']));
		expect(first?.corequisites.map((m) => m.codigoMateria)).toEqual([]);
		expect(first?.equivalencies).toHaveLength(1);
		clearCurriculumAnalysisCache();
		const afterClear = getCurriculumAnalysis(curso, 'MAT201');
		expect(afterClear).not.toBe(first);
	});
});
