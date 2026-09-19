import { describe, it, expect } from 'vitest';
import {
	allocateTransitYs,
	assignLanesForGap,
	buildArcPath,
	buildGaps,
	buildRoutedPath,
	buildSameColumnPath,
	findColumnIndex,
	freeBands,
	mergeIntervals,
	pickBand,
	resolveEdgeGeometry,
	TRANSIT_Y_PADDING,
	type CardBox,
	type ColumnRect,
	type Interval
} from './prerequisite-routing';

/** Layout real do fluxograma: colunas de 240px separadas por vãos de 96px. */
const COL_WIDTH = 240;
const GAP = 96;

function columns(count: number, top = 0, bottom = 900): ColumnRect[] {
	return Array.from({ length: count }, (_, i) => ({
		index: i,
		left: i * (COL_WIDTH + GAP),
		right: i * (COL_WIDTH + GAP) + COL_WIDTH,
		top,
		bottom
	}));
}

function card(col: number, top: number, height = 130): CardBox {
	const left = col * (COL_WIDTH + GAP);
	return {
		left,
		right: left + COL_WIDTH,
		top,
		bottom: top + height,
		centerY: top + height / 2,
		column: col
	};
}

/** Pontos amostrados ao longo de uma cúbica `M ... C ...`. */
function sampleCubic(d: string, samples = 40): { x: number; y: number }[] {
	const nums = d.match(/-?\d+(\.\d+)?/g)!.map(Number);
	const [x0, y0, c1x, c1y, c2x, c2y, x1, y1] = nums;
	const out: { x: number; y: number }[] = [];
	for (let i = 0; i <= samples; i++) {
		const t = i / samples;
		const u = 1 - t;
		out.push({
			x: u * u * u * x0 + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * x1,
			y: u * u * u * y0 + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * y1
		});
	}
	return out;
}

/** Vértices de um traçado ortogonal (`M`/`L`/`Q`), suficientes para checar as faixas usadas. */
function pathPoints(d: string): { x: number; y: number }[] {
	const nums = d.match(/-?\d+(\.\d+)?/g)!.map(Number);
	const out: { x: number; y: number }[] = [];
	for (let i = 0; i + 1 < nums.length; i += 2) out.push({ x: nums[i], y: nums[i + 1] });
	return out;
}

describe('resolveEdgeGeometry', () => {
	it('mesma coluna ancora nas duas bordas direitas (não atravessa os cards)', () => {
		const g = resolveEdgeGeometry(card(4, 100), card(4, 400));
		expect(g.shape).toBe('same-column');
		expect(g.x1).toBe(g.x2);
		expect(g.x1).toBe(card(4, 100).right);
	});

	it('não classifica colunas vizinhas como mesma coluna', () => {
		expect(resolveEdgeGeometry(card(2, 100), card(3, 300)).shape).toBe('forward-adjacent');
	});

	it('marca como forward-far quando pula colunas', () => {
		expect(resolveEdgeGeometry(card(1, 100), card(5, 300)).shape).toBe('forward-far');
	});

	it('aresta que volta sai pela esquerda e entra pela borda direita do destino', () => {
		const from = card(5, 100);
		const to = card(2, 300);
		const g = resolveEdgeGeometry(from, to);
		expect(g.shape).toBe('backward');
		expect(g.x1).toBe(from.left);
		expect(g.x2).toBe(to.right);
	});
});

describe('buildSameColumnPath', () => {
	it('mantém a curva à direita da coluna, fora do corpo dos cards', () => {
		const g = resolveEdgeGeometry(card(4, 100), card(4, 400));
		const d = buildSameColumnPath(g);
		const colRight = card(4, 100).right;
		for (const p of sampleCubic(d)) {
			expect(p.x).toBeGreaterThanOrEqual(colRight - 0.01);
		}
	});

	it('termina apontando para a esquerda, entrando na borda direita do destino', () => {
		const g = resolveEdgeGeometry(card(4, 100), card(4, 400));
		const pts = sampleCubic(buildSameColumnPath(g));
		const last = pts[pts.length - 1];
		const before = pts[pts.length - 2];
		expect(last.x - before.x).toBeLessThan(0);
		expect(last.x).toBeCloseTo(g.x2, 5);
	});
});

describe('buildArcPath — colunas vizinhas', () => {
	it('fica dentro do vão entre as colunas', () => {
		const from = card(2, 100);
		const to = card(3, 300);
		const g = resolveEdgeGeometry(from, to);
		for (const p of sampleCubic(buildArcPath(g))) {
			expect(p.x).toBeGreaterThanOrEqual(from.right - 0.01);
			expect(p.x).toBeLessThanOrEqual(to.left + 0.01);
		}
	});
});

describe('freeBands / pickBand / spreadInBand', () => {
	it('une intervalos sobrepostos', () => {
		expect(mergeIntervals([[0, 10], [5, 20], [40, 50]])).toEqual([[0, 20], [40, 50]]);
	});

	it('devolve o complemento dentro dos limites', () => {
		expect(freeBands([[100, 200], [300, 400]], 0, 600)).toEqual([
			[0, 100],
			[200, 300],
			[400, 600]
		]);
	});

	it('descarta faixas estreitas demais e escolhe a mais próxima do Y desejado', () => {
		const bands: Interval[] = [
			[0, 5],
			[100, 160],
			[500, 560]
		];
		expect(pickBand(bands, 520, 40)).toEqual([500, 560]);
		expect(pickBand(bands, 0, 40)).toEqual([100, 160]);
		expect(pickBand(bands, 0, 400)).toBeNull();
	});
});

describe('allocateTransitYs', () => {
	const cardsByColumn = new Map<number, Interval[]>([
		[1, [[0, 130], [180, 310], [360, 490]]],
		[2, [[0, 130], [180, 310]]],
		[3, [[0, 130], [180, 310], [360, 490]]]
	]);

	it('escolhe uma faixa que não cruza nenhum card intermediário', () => {
		const ys = allocateTransitYs(
			[{ lineIndex: 0, sourceCol: 0, targetCol: 4, y1: 60, y2: 420 }],
			cardsByColumn,
			[0, 700]
		);
		const y = ys.get(0)!;
		for (const col of [1, 2, 3]) {
			for (const [top, bottom] of cardsByColumn.get(col)!) {
				expect(y < top || y > bottom).toBe(true);
			}
		}
	});

	it('separa travessias do mesmo corredor', () => {
		const ys = allocateTransitYs(
			[
				{ lineIndex: 0, sourceCol: 0, targetCol: 4, y1: 60, y2: 420 },
				{ lineIndex: 1, sourceCol: 0, targetCol: 4, y1: 70, y2: 430 },
				{ lineIndex: 2, sourceCol: 0, targetCol: 4, y1: 80, y2: 440 }
			],
			cardsByColumn,
			[0, 700]
		);
		const vals = [...ys.values()].sort((a, b) => a - b);
		expect(new Set(vals).size).toBe(3);
		expect(vals[1] - vals[0]).toBeGreaterThanOrEqual(TRANSIT_Y_PADDING - 0.001);
	});

	it('separa corredores que compartilham colunas', () => {
		const ys = allocateTransitYs(
			[
				{ lineIndex: 0, sourceCol: 0, targetCol: 4, y1: 60, y2: 420 },
				{ lineIndex: 1, sourceCol: 1, targetCol: 3, y1: 60, y2: 420 }
			],
			cardsByColumn,
			[0, 700]
		);
		expect(Math.abs(ys.get(0)! - ys.get(1)!)).toBeGreaterThanOrEqual(TRANSIT_Y_PADDING - 0.001);
	});

	it('desvia por baixo do diagrama quando não há faixa livre', () => {
		const lotado = new Map<number, Interval[]>([[1, [[0, 700]]]]);
		const ys = allocateTransitYs(
			[{ lineIndex: 0, sourceCol: 0, targetCol: 2, y1: 100, y2: 600 }],
			lotado,
			[0, 700]
		);
		expect(ys.get(0)!).toBeGreaterThan(700);
	});
});

describe('buildRoutedPath', () => {
	it('mantém os segmentos verticais dentro dos vãos e a travessia na faixa alocada', () => {
		const cols = columns(6);
		const gaps = buildGaps(cols);
		const from = card(1, 100);
		const to = card(5, 400);
		const g = resolveEdgeGeometry(from, to);
		const exitGap = gaps[1];
		const entryGap = gaps[4];
		const d = buildRoutedPath(g, {
			exitLaneX: exitGap.centerX,
			entryLaneX: entryGap.centerX,
			transitY: 340
		});

		const pts = pathPoints(d);
		const xs = pts.map((p) => p.x);
		// Todo X intermediário está numa das pontas (bordas dos cards) ou dentro de um vão.
		for (const x of xs) {
			const dentroDeVao = gaps.some((gp) => x >= gp.leftX - 9 && x <= gp.rightX + 9);
			const naPonta = Math.abs(x - g.x1) < 0.01 || Math.abs(x - g.x2) < 0.01;
			expect(dentroDeVao || naPonta).toBe(true);
		}
		expect(pts.some((p) => Math.abs(p.y - 340) < 0.01)).toBe(true);
		expect(pts[pts.length - 1].x).toBeCloseTo(g.x2, 5);
	});
});

describe('findColumnIndex', () => {
	it('encontra a coluna que contém o ponto', () => {
		const cols = columns(4);
		expect(findColumnIndex(cols, cols[2].left + 10)).toBe(2);
	});

	it('cai na coluna mais próxima quando o ponto está num vão', () => {
		const cols = columns(4);
		expect(findColumnIndex(cols, cols[1].right + 5)).toBe(1);
	});
});

describe('assignLanesForGap', () => {
	const gap = buildGaps(columns(3))[0];

	it('centraliza a única linha no vão', () => {
		const lanes = assignLanesForGap([{ lineIndex: 0, y1: 0, y2: 100 }], gap);
		expect(lanes.get(0)).toBeCloseTo(gap.centerX);
	});

	it('mantém todas as faixas dentro do vão mesmo lotado', () => {
		const linhas = Array.from({ length: 30 }, (_, i) => ({ lineIndex: i, y1: i * 10, y2: i * 12 }));
		const lanes = assignLanesForGap(linhas, gap);
		for (const x of lanes.values()) {
			expect(x).toBeGreaterThanOrEqual(gap.leftX);
			expect(x).toBeLessThanOrEqual(gap.rightX);
		}
	});

	it('ordena as faixas pelo Y médio', () => {
		const lanes = assignLanesForGap(
			[
				{ lineIndex: 0, y1: 900, y2: 900 },
				{ lineIndex: 1, y1: 100, y2: 100 }
			],
			gap
		);
		expect(lanes.get(1)!).toBeLessThan(lanes.get(0)!);
	});
});

describe('allocateTransitYs — corredores estreitos', () => {
	/** Coluna intermediária com dois vãos de 30px entre cards. */
	const estreito = new Map<number, Interval[]>([[1, [[0, 130], [160, 290], [320, 450]]]]);

	it('distribui linhas do mesmo corredor por vãos diferentes em vez de mandá-las para baixo', () => {
		const ys = allocateTransitYs(
			[
				{ lineIndex: 0, sourceCol: 0, targetCol: 2, y1: 60, y2: 200 },
				{ lineIndex: 1, sourceCol: 0, targetCol: 2, y1: 220, y2: 380 }
			],
			estreito,
			[0, 450],
			5
		);
		for (const y of ys.values()) {
			expect(y).toBeLessThanOrEqual(450);
			for (const [top, bottom] of estreito.get(1)!) {
				expect(y < top || y > bottom).toBe(true);
			}
		}
		expect(ys.get(0)).not.toBe(ys.get(1));
	});

	it('mantém a travessia perto do trajeto da própria linha', () => {
		const ys = allocateTransitYs(
			[{ lineIndex: 0, sourceCol: 0, targetCol: 2, y1: 300, y2: 340 }],
			estreito,
			[0, 450],
			5
		);
		// O vão 290–320 é o mais próximo do trajeto (~320); não pode saltar para o de cima.
		expect(ys.get(0)!).toBeGreaterThan(290);
		expect(ys.get(0)!).toBeLessThan(320);
	});
});
