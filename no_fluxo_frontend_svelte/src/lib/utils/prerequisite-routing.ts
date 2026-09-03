/**
 * Geometria das setas de pré-requisito do fluxograma.
 *
 * O diagrama é uma ordenação por semestre (colunas) com arestas u→v “cursar u antes de v”.
 * O roteamento depende da relação entre as COLUNAS das duas pontas — nunca da distância
 * horizontal bruta entre as bordas dos cards, que confunde “mesma coluna” (≈ largura do
 * card) com “colunas vizinhas” (≈ largura do vão).
 *
 * Quatro formas:
 * - `same-column`   — pré-req/co-req no mesmo semestre: “U” pela direita, entrando na borda
 *                     direita do destino (não atravessa os cards da coluna).
 * - `backward`      — destino à esquerda da origem (optativa planejada antes do pré-req):
 *                     arco espelhado, saindo pela esquerda e entrando pela borda direita.
 * - `forward-adjacent` — arco simples dentro do vão entre as duas colunas.
 * - `forward-far`   — ortogonal: sobe/desce no vão de saída, cruza numa faixa horizontal
 *                     livre de cards e desce/sobe no vão de entrada.
 */

export interface ColumnRect {
	index: number;
	left: number;
	right: number;
	top: number;
	bottom: number;
}

export interface ColumnGap {
	index: number;
	leftX: number;
	rightX: number;
	centerX: number;
	width: number;
}

/** Card já convertido para coordenadas do SVG (px de layout, sem zoom). */
export interface CardBox {
	left: number;
	right: number;
	top: number;
	bottom: number;
	centerY: number;
	column: number;
}

export type EdgeShape = 'same-column' | 'backward' | 'forward-adjacent' | 'forward-far';

export interface EdgeGeometry {
	x1: number;
	y1: number;
	x2: number;
	y2: number;
	shape: EdgeShape;
	sourceCol: number;
	targetCol: number;
}

export type Interval = [number, number];

/** Vãos entre colunas consecutivas — onde os segmentos verticais podem correr sem tocar card. */
export function buildGaps(columns: ColumnRect[]): ColumnGap[] {
	const sorted = [...columns].sort((a, b) => a.left - b.left);
	const gaps: ColumnGap[] = [];
	for (let i = 0; i < sorted.length - 1; i++) {
		const leftX = sorted[i].right;
		const rightX = sorted[i + 1].left;
		gaps.push({
			index: i,
			leftX,
			rightX,
			centerX: (leftX + rightX) / 2,
			width: rightX - leftX
		});
	}
	return gaps;
}

/** Coluna que contém `x`; se nenhuma contém, a de centro mais próximo. */
export function findColumnIndex(columns: ColumnRect[], x: number): number {
	for (let i = 0; i < columns.length; i++) {
		if (x >= columns[i].left && x <= columns[i].right) return columns[i].index;
	}
	let best = columns[0]?.index ?? 0;
	let bestDist = Infinity;
	for (const col of columns) {
		const dist = Math.abs(x - (col.left + col.right) / 2);
		if (dist < bestDist) {
			bestDist = dist;
			best = col.index;
		}
	}
	return best;
}

/**
 * Âncoras e forma da aresta a partir das colunas das duas pontas.
 * Origem sai pela borda que aponta para o destino; destino recebe a seta na borda oposta.
 */
export function resolveEdgeGeometry(from: CardBox, to: CardBox): EdgeGeometry {
	const sourceCol = from.column;
	const targetCol = to.column;

	if (sourceCol === targetCol) {
		return {
			x1: from.right,
			y1: from.centerY,
			x2: to.right,
			y2: to.centerY,
			shape: 'same-column',
			sourceCol,
			targetCol
		};
	}

	if (targetCol < sourceCol) {
		return {
			x1: from.left,
			y1: from.centerY,
			x2: to.right,
			y2: to.centerY,
			shape: 'backward',
			sourceCol,
			targetCol
		};
	}

	return {
		x1: from.right,
		y1: from.centerY,
		x2: to.left,
		y2: to.centerY,
		shape: targetCol - sourceCol === 1 ? 'forward-adjacent' : 'forward-far',
		sourceCol,
		targetCol
	};
}

// ─── Faixas horizontais livres ────────────────────────────────────────

/** Une intervalos sobrepostos ou encostados, em ordem crescente. */
export function mergeIntervals(intervals: Interval[]): Interval[] {
	if (intervals.length === 0) return [];
	const sorted = [...intervals].sort((a, b) => a[0] - b[0]);
	const out: Interval[] = [[sorted[0][0], sorted[0][1]]];
	for (let i = 1; i < sorted.length; i++) {
		const last = out[out.length - 1];
		if (sorted[i][0] <= last[1]) {
			last[1] = Math.max(last[1], sorted[i][1]);
		} else {
			out.push([sorted[i][0], sorted[i][1]]);
		}
	}
	return out;
}

/**
 * Complemento de `occupied` dentro de [from, to] — as faixas onde uma linha horizontal
 * pode cruzar as colunas intermediárias sem passar por cima de nenhum card.
 */
export function freeBands(occupied: Interval[], from: number, to: number): Interval[] {
	const merged = mergeIntervals(occupied.filter(([a, b]) => b > from && a < to));
	const bands: Interval[] = [];
	let cursor = from;
	for (const [a, b] of merged) {
		if (a > cursor) bands.push([cursor, Math.min(a, to)]);
		cursor = Math.max(cursor, b);
		if (cursor >= to) break;
	}
	if (cursor < to) bands.push([cursor, to]);
	return bands.filter(([a, b]) => b > a);
}

/**
 * Faixa livre mais próxima de `preferredY` com largura ≥ `needed`.
 * `null` quando nenhuma serve — o chamador cai no desvio por fora do diagrama.
 *
 * A tolerância importa: uma faixa sobrando exatamente a largura pedida vem de subtrações
 * de floats e ficaria de fora por 1e-14, desperdiçando metade dos corredores.
 */
export function pickBand(bands: Interval[], preferredY: number, needed: number): Interval | null {
	const EPS = 1e-6;
	let best: Interval | null = null;
	let bestDist = Infinity;
	for (const band of bands) {
		if (band[1] - band[0] < needed - EPS) continue;
		const clamped = Math.min(Math.max(preferredY, band[0]), band[1]);
		const dist = Math.abs(clamped - preferredY);
		if (dist < bestDist) {
			bestDist = dist;
			best = band;
		}
	}
	return best;
}

// ─── Traçados ─────────────────────────────────────────────────────────

/** Espaçamento mínimo entre linhas paralelas dentro de um vão. */
export const LANE_PADDING = 6;
/** Espaçamento vertical entre linhas horizontais paralelas na mesma faixa. */
export const TRANSIT_Y_PADDING = 9;
/** Recuo horizontal antes de entrar no card, para a seta chegar reta. */
const HORIZ_ENTRY = 36;

/**
 * Faixas (X) para os segmentos verticais dentro de um vão, uma por linha,
 * ordenadas pelo Y médio para que linhas vizinhas fiquem em faixas vizinhas.
 */
export function assignLanesForGap(
	linesInGap: { lineIndex: number; y1: number; y2: number }[],
	gap: ColumnGap
): Map<number, number> {
	const result = new Map<number, number>();
	if (linesInGap.length === 0) return result;

	const sorted = [...linesInGap].sort((a, b) => (a.y1 + a.y2) / 2 - (b.y1 + b.y2) / 2);
	const count = sorted.length;

	if (count === 1) {
		result.set(sorted[0].lineIndex, gap.centerX);
		return result;
	}

	// Espaçamento cede quando o vão enche: linhas mais próximas é melhor que faixa
	// vazando para dentro da coluna, onde cruzaria os cards.
	const usableWidth = Math.max(gap.width - LANE_PADDING * 2, 0);
	const spacing = usableWidth / (count - 1);
	const startX = gap.leftX + LANE_PADDING;
	for (let i = 0; i < count; i++) {
		result.set(sorted[i].lineIndex, startX + spacing * i);
	}
	return result;
}

/**
 * Mesmo semestre: “U” pela direita da coluna. Sai da borda direita da origem e entra na
 * borda direita do destino — a seta nunca cruza o corpo dos cards.
 */
export function buildSameColumnPath(g: EdgeGeometry, bulge = 34): string {
	const cx = Math.max(g.x1, g.x2) + bulge;
	return `M ${g.x1} ${g.y1} C ${cx} ${g.y1}, ${cx} ${g.y2}, ${g.x2} ${g.y2}`;
}

/** Arco para frente entre colunas vizinhas: corre dentro do vão, entrando reto no destino. */
export function buildForwardArcPath(g: EdgeGeometry): string {
	const span = g.x2 - g.x1;
	const safeHoriz = Math.max(8, Math.min(HORIZ_ENTRY, span * 0.45));
	const bx2 = g.x2 - safeHoriz;
	const sgnY = g.y2 >= g.y1 ? 1 : -1;
	const midX = (g.x1 + bx2) / 2;
	const vertSwing = Math.abs(g.y2 - g.y1) * 0.35;
	return `M ${g.x1} ${g.y1} C ${midX} ${g.y1 + sgnY * vertSwing}, ${midX} ${g.y2}, ${bx2} ${g.y2} L ${g.x2} ${g.y2}`;
}

/** Espelho de `buildForwardArcPath` para arestas que voltam (destino à esquerda). */
export function buildBackwardArcPath(g: EdgeGeometry): string {
	const span = g.x1 - g.x2;
	const safeHoriz = Math.max(8, Math.min(HORIZ_ENTRY, span * 0.45));
	const bx2 = g.x2 + safeHoriz;
	const sgnY = g.y2 >= g.y1 ? 1 : -1;
	const midX = (g.x1 + bx2) / 2;
	const vertSwing = Math.abs(g.y2 - g.y1) * 0.35;
	return `M ${g.x1} ${g.y1} C ${midX} ${g.y1 + sgnY * vertSwing}, ${midX} ${g.y2}, ${bx2} ${g.y2} L ${g.x2} ${g.y2}`;
}

export interface FarRouting {
	exitLaneX: number;
	entryLaneX: number;
	transitY: number;
}

/**
 * Aresta que pula colunas: vertical no vão de saída, horizontal na faixa livre, vertical no
 * vão de entrada. Cantos arredondados quando há espaço.
 */
export function buildRoutedPath(g: EdgeGeometry, r: FarRouting): string {
	const { x1, y1, x2, y2 } = g;
	const { exitLaneX, entryLaneX, transitY } = r;
	const maxR = 8;
	const points: string[] = [`M ${x1} ${y1}`];

	const dir1Y = transitY < y1 ? -1 : 1;
	const r1 = Math.min(maxR, Math.abs(transitY - y1) / 2, Math.abs(exitLaneX - x1) / 2);
	if (r1 >= 2) {
		points.push(`L ${exitLaneX - r1} ${y1}`);
		points.push(`Q ${exitLaneX} ${y1}, ${exitLaneX} ${y1 + r1 * dir1Y}`);
	} else {
		points.push(`L ${exitLaneX} ${y1}`);
	}

	const dir2X = entryLaneX >= exitLaneX ? 1 : -1;
	const r2 = Math.min(maxR, Math.abs(transitY - y1) / 2, Math.abs(entryLaneX - exitLaneX) / 2);
	if (r2 >= 2) {
		points.push(`L ${exitLaneX} ${transitY - r2 * dir1Y}`);
		points.push(`Q ${exitLaneX} ${transitY}, ${exitLaneX + r2 * dir2X} ${transitY}`);
	} else {
		points.push(`L ${exitLaneX} ${transitY}`);
	}

	const dir3Y = y2 > transitY ? 1 : -1;
	const r3 = Math.min(maxR, Math.abs(entryLaneX - exitLaneX) / 2, Math.abs(y2 - transitY) / 2);
	if (r3 >= 2) {
		points.push(`L ${entryLaneX - r3 * dir2X} ${transitY}`);
		points.push(`Q ${entryLaneX} ${transitY}, ${entryLaneX} ${transitY + r3 * dir3Y}`);
	} else {
		points.push(`L ${entryLaneX} ${transitY}`);
	}

	const r4 = Math.min(maxR, Math.abs(y2 - transitY) / 2, Math.abs(x2 - entryLaneX) / 2);
	if (r4 >= 2) {
		points.push(`L ${entryLaneX} ${y2 - r4 * dir3Y}`);
		points.push(`Q ${entryLaneX} ${y2}, ${entryLaneX + r4} ${y2}`);
	} else {
		points.push(`L ${entryLaneX} ${y2}`);
	}

	points.push(`L ${x2} ${y2}`);
	return points.join(' ');
}

/** Traçado de uma aresta que não precisa de roteamento por vãos. */
export function buildArcPath(g: EdgeGeometry, bulge?: number): string {
	switch (g.shape) {
		case 'same-column':
			return buildSameColumnPath(g, bulge);
		case 'backward':
			return buildBackwardArcPath(g);
		default:
			return buildForwardArcPath(g);
	}
}

// ─── Alocação das faixas de travessia ─────────────────────────────────

export interface FarLineInput {
	lineIndex: number;
	sourceCol: number;
	targetCol: number;
	y1: number;
	y2: number;
}

interface AllocatedTransit {
	y: number;
	fromCol: number;
	toCol: number;
}

/**
 * Y de travessia para cada aresta que pula colunas.
 *
 * Cada linha escolhe sozinha a faixa livre mais próxima do seu próprio trajeto — arestas do
 * mesmo corredor se empilham naturalmente porque uma travessia já alocada passa a ocupar a
 * faixa. Alocar por linha (em vez de reservar uma faixa larga por corredor) é o que permite
 * usar os corredores estreitos entre cards, onde só cabe uma linha de cada vez.
 *
 * Corredores mais longos escolhem primeiro: atravessam mais colunas e têm menos opções.
 * Sem nenhuma faixa livre, a linha desvia por baixo do diagrama — sempre livre.
 */
export function allocateTransitYs(
	lines: FarLineInput[],
	cardIntervalsByColumn: Map<number, Interval[]>,
	bounds: Interval,
	margin = 10
): Map<number, number> {
	const result = new Map<number, number>();
	if (lines.length === 0) return result;

	const ordered = [...lines].sort((a, b) => {
		const spanDiff = b.targetCol - b.sourceCol - (a.targetCol - a.sourceCol);
		if (spanDiff !== 0) return spanDiff;
		return (a.y1 + a.y2) / 2 - (b.y1 + b.y2) / 2;
	});

	const allocated: AllocatedTransit[] = [];
	let desvios = 0;

	for (const line of ordered) {
		const preferred = (line.y1 + line.y2) / 2;

		const occupied: Interval[] = [];
		for (let col = line.sourceCol + 1; col <= line.targetCol - 1; col++) {
			for (const [top, bottom] of cardIntervalsByColumn.get(col) ?? []) {
				occupied.push([top - margin, bottom + margin]);
			}
		}
		for (const prev of allocated) {
			if (prev.fromCol < line.targetCol && prev.toCol > line.sourceCol) {
				occupied.push([prev.y - TRANSIT_Y_PADDING / 2, prev.y + TRANSIT_Y_PADDING / 2]);
			}
		}

		const band = pickBand(
			freeBands(occupied, bounds[0], bounds[1]),
			preferred,
			TRANSIT_Y_PADDING
		);

		const y = band
			? Math.min(
					Math.max(preferred, band[0] + TRANSIT_Y_PADDING / 2),
					band[1] - TRANSIT_Y_PADDING / 2
				)
			: bounds[1] + margin + desvios++ * TRANSIT_Y_PADDING;

		result.set(line.lineIndex, y);
		allocated.push({ y, fromCol: line.sourceCol, toCol: line.targetCol });
	}

	return result;
}
