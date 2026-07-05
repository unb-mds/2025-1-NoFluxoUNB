import { describe, expect, it } from 'vitest';
import {
	getAncestorAndDescendantCodes,
	getSubjectChain,
	getTopologicalPrerequisiteChain,
	classifyChainPrereqStroke,
	CHAIN_VISUAL
} from './curriculum-graph';
import type { CursoModel } from '../types/curso';
import type { MateriaModel } from '../types/materia';

function makeMateria(id: number, code: string, level: number, prereqs: string[] = []): MateriaModel {
	return {
		idMateria: id,
		codigoMateria: code,
		nomeMateria: code,
		nivel: level,
		creditos: 4,
		ementa: '',
		preRequisitos: prereqs.map((c) => ({ idMateria: 0, codigoMateria: c, nomeMateria: c, nivel: 0, creditos: 0, ementa: '' }))
	};
}

function buildCurso(): CursoModel {
	const mat101 = makeMateria(1, 'MAT101', 1);
	const mat201 = makeMateria(2, 'MAT201', 2, ['MAT101']);
	const mat301 = makeMateria(3, 'MAT301', 3, ['MAT201']);
	const fis201 = makeMateria(4, 'FIS201', 2);
	return {
		nomeCurso: 'Engenharia',
		matrizCurricular: '2024.1',
		idCurso: 7,
		totalCreditos: 160,
		classificacao: 'graduacao',
		tipoCurso: 'graduacao',
		materias: [mat101, mat201, mat301, fis201],
		semestres: 3,
		equivalencias: [],
		preRequisitos: [],
		coRequisitos: [{ idCoRequisito: 1, idMateria: 2, idMateriaCoRequisito: 4, codigoMateriaCoRequisito: 'FIS201', nomeMateriaCoRequisito: 'Física', expressaoOriginal: null, expressaoLogica: null }],
		curriculoCompleto: '2024.1'
	} as CursoModel;
}

describe('curriculum graph helpers', () => {
	it('calcula antecessores, descendentes e cadeia contextual', () => {
		const curso = buildCurso();
		const { ancestors, descendants } = getAncestorAndDescendantCodes(curso, 'MAT301');
		expect([...ancestors].sort()).toEqual(['FIS201', 'MAT101', 'MAT201']);
		expect([...descendants]).toEqual([]);

		const chain = getSubjectChain(curso, 'MAT301');
		expect(chain?.focusCode).toBe('MAT301');
		expect([...chain?.precursors ?? []].sort()).toEqual(['FIS201', 'MAT101', 'MAT201']);
		expect([...chain?.descendants ?? []]).toEqual([]);
		expect([...chain?.corequisites ?? []]).toEqual([]);
		expect(chain?.chainNodeSet.has('FIS201')).toBe(true);
	});

	it('monta camadas topológicas e classifica arestas da cadeia', () => {
		const curso = buildCurso();
		const topo = getTopologicalPrerequisiteChain(curso, 'MAT301');
		expect(topo.totalSccCount).toBeGreaterThan(0);
		expect(topo.layers[0]?.codes).toContain('MAT101');
		expect(topo.layers.at(-1)?.codes).toContain('MAT301');

		expect(classifyChainPrereqStroke('MAT101', 'MAT201', 'MAT301', new Set(['MAT101']), new Set(['MAT201']))).toBe('pre');
		expect(classifyChainPrereqStroke('MAT201', 'MAT301', 'MAT301', new Set(['MAT101']), new Set(['MAT201', 'MAT301']))).toBe('desc');
		expect(CHAIN_VISUAL.precursor).toBeTruthy();
	});

	it('retorna vazio para foco inválido', () => {
		const curso = buildCurso();
		expect(getAncestorAndDescendantCodes(curso, '   ')).toEqual({ ancestors: new Set(), descendants: new Set() });
		expect(getSubjectChain(curso, null)).toBeNull();
		expect(getTopologicalPrerequisiteChain(curso, 'MAT999')).toEqual({
			layers: [],
			sccIdByCode: new Map(),
			totalSccCount: 0
		});
	});
});
