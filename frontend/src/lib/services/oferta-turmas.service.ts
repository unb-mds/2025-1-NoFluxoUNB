/**
 * Oferta de turmas resolvida por equivalência — ponto único do app.
 *
 * Quando a matéria da matriz mudou de código, a oferta em `turmas` passa a ser publicada
 * sob o código novo (ex.: CIC0151 → CIC0197/FGA0158). Buscar turmas só por `id_materia`
 * faz a matéria parecer sem oferta nenhuma.
 *
 * Essa resolução vivia inline só no Montador de Grade; a aba Turmas do fluxograma
 * (SubjectDetailsModal) e o painel de /disciplinas (TurmasVagasPanel) consultavam direto
 * por id e exibiam "nenhuma turma ofertada" para matérias que na verdade tinham oferta.
 * Todo consumidor passa por aqui agora.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
 */
import { getMateriasByCodigos } from './materias.service';
import { getTurmasPorMaterias, type TurmaOferta } from './turmas.service';
import {
	construirSubstitutosPorCodigo,
	resolverTurmasComEquivalencia,
	type LinhaEquivalencia,
	type TurmaComOrigem
} from '$lib/utils/oferta-equivalencia';

/** O mínimo necessário para buscar a oferta de uma matéria. */
export interface MateriaOfertaInput {
	/** Código como está na matriz — é por ele que a equivalência é resolvida. */
	codigo: string;
	idMateria: number;
}

export type TurmaResolvida = TurmaComOrigem<TurmaOferta>;

function norm(codigo: string): string {
	return (codigo || '').trim().toUpperCase();
}

/**
 * Chave estável no mapa de retorno. Telas que só têm o `id_materia` (código opcional)
 * continuam funcionando — sem código não há equivalência a resolver, e o resultado
 * degrada para a busca simples por id.
 */
function chaveDe(codigo: string, idMateria: number): string {
	return norm(codigo) || `#${idMateria}`;
}

/**
 * Turmas de cada matéria no período, caindo nos substitutos por equivalência quando a
 * matéria não tem oferta no próprio código.
 *
 * `equivalencias` vazio degrada para a busca simples por id — é o caso de telas sem
 * matriz carregada (ex.: matéria global em /disciplinas).
 */
export async function getOfertaComEquivalencia(
	materias: MateriaOfertaInput[],
	equivalencias: LinhaEquivalencia[] = [],
	periodo?: string
): Promise<Map<string, TurmaResolvida[]>> {
	const out = new Map<string, TurmaResolvida[]>();
	if (materias.length === 0) return out;

	const idPorCodigo = new Map<string, number>();
	for (const m of materias) {
		const c = norm(m.codigo);
		if (c) idPorCodigo.set(c, m.idMateria);
	}

	const substitutosPorCodigo = construirSubstitutosPorCodigo(equivalencias, idPorCodigo.keys());

	// Os substitutos estão fora do que veio na entrada — precisam de lookup próprio.
	const codigosSubstitutos = [
		...new Set([...substitutosPorCodigo.values()].flat().filter((c) => !idPorCodigo.has(norm(c))))
	];
	if (codigosSubstitutos.length > 0) {
		try {
			for (const m of await getMateriasByCodigos(codigosSubstitutos)) {
				idPorCodigo.set(norm(m.codigo), m.idMateria);
			}
		} catch {
			// Degrada pro comportamento simples (só turmas do próprio código) em vez de
			// derrubar a tela inteira.
		}
	}

	const ids = [...new Set([...idPorCodigo.values(), ...materias.map((m) => m.idMateria)])];
	const turmas = await getTurmasPorMaterias(ids, periodo);

	const porMateria = new Map<number, TurmaOferta[]>();
	for (const t of turmas) {
		const l = porMateria.get(t.id_materia) ?? [];
		l.push(t);
		porMateria.set(t.id_materia, l);
	}

	for (const m of materias) {
		out.set(
			chaveDe(m.codigo, m.idMateria),
			resolverTurmasComEquivalencia(
				norm(m.codigo),
				m.idMateria,
				substitutosPorCodigo.get(norm(m.codigo)) ?? [],
				idPorCodigo,
				porMateria
			)
		);
	}

	return out;
}

/** Conveniência para as telas que mostram uma matéria só. */
export async function getOfertaDeMateria(
	codigo: string,
	idMateria: number,
	equivalencias: LinhaEquivalencia[] = [],
	periodo?: string
): Promise<TurmaResolvida[]> {
	const mapa = await getOfertaComEquivalencia([{ codigo, idMateria }], equivalencias, periodo);
	return mapa.get(chaveDe(codigo, idMateria)) ?? [];
}
