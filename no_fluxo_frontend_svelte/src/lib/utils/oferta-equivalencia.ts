/**
 * Oferta por equivalência — quando a matéria da matriz mudou de código.
 *
 * A matriz curricular continua com o código antigo, mas a oferta em `turmas` passa a
 * ser publicada sob o novo (ex.: CIC0151 → CIC0197/FGA0158). Sem consultar
 * equivalências, o Montador de Grade coloca a matéria no pool com zero turmas.
 *
 * Espelho da lógica do backend em
 * no_fluxo_backend/src/services/plano_formatura.service.ts
 * (construirSubstitutosPorCodigo) e .../chat/actuators/grade_actuator.ts.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
 */
import {
	getSubstitutosFromExpressaoLogica,
	type ExpressaoLogicaJson,
	type ExpressaoLogicaRecursiva
} from './expressao-logica';

/** Subconjunto de EquivalenciaModel de que esta lógica depende. */
export interface LinhaEquivalencia {
	codigoMateriaOrigem: string;
	expressaoLogica?: ExpressaoLogicaRecursiva | ExpressaoLogicaJson | null;
	expressao?: string;
}

export interface TurmaComOrigem<T> {
	turma: T;
	/**
	 * Código sob o qual a turma foi realmente ofertada, quando difere do código da
	 * matriz. É nele que o aluno se matricula. Indefinido = turma do próprio código.
	 */
	codigoOfertado?: string;
}

function norm(codigo: string): string {
	return (codigo || '').trim().toUpperCase();
}

/**
 * Mapeia cada código de interesse para os códigos que podem SUBSTITUÍ-LO na busca por
 * oferta.
 *
 * Direção DIRETA apenas: só as linhas de equivalência cuja origem é a própria matéria.
 * A leitura inversa é inferência, não fato registrado — medido em produção, só 46% dos
 * pares 1:1 têm o inverso cadastrado.
 *
 * Ramos `E` não geram substituto: ali os códigos só valem cursados juntos, então uma
 * turma isolada não cobre a matéria.
 */
export function construirSubstitutosPorCodigo(
	equivalencias: LinhaEquivalencia[],
	codigosDeInteresse: Iterable<string>
): Map<string, string[]> {
	const alvo = new Set([...codigosDeInteresse].map(norm));
	const mapa = new Map<string, string[]>();

	for (const eq of equivalencias) {
		const origem = norm(eq.codigoMateriaOrigem);
		if (!origem || !alvo.has(origem)) continue;

		const substitutos = new Set(mapa.get(origem) ?? []);
		for (const s of getSubstitutosFromExpressaoLogica(eq.expressaoLogica, eq.expressao)) {
			// Uma matéria não substitui a si mesma.
			if (s !== origem) substitutos.add(s);
		}

		if (substitutos.size > 0) mapa.set(origem, [...substitutos]);
	}

	return mapa;
}

/**
 * Turmas de uma matéria, caindo nos substitutos quando ela não tem oferta própria.
 *
 * Substituto é FALLBACK, não alternativa: se a matéria ainda é ofertada no próprio
 * código neste período, é nele que o aluno se matricula, e as turmas do substituto não
 * entram. Medido em produção: 1.396 pares têm oferta nos DOIS códigos — coexistem em
 * vez de terem sido renomeados.
 */
export function resolverTurmasComEquivalencia<T>(
	_codigoMatriz: string,
	idMateria: number,
	substitutos: string[],
	idPorCodigo: Map<string, number>,
	turmasPorId: Map<number, T[]>
): TurmaComOrigem<T>[] {
	const proprias = turmasPorId.get(idMateria) ?? [];
	if (proprias.length > 0) {
		return proprias.map((turma) => ({ turma, codigoOfertado: undefined }));
	}

	const out: TurmaComOrigem<T>[] = [];
	for (const codigo of substitutos) {
		const id = idPorCodigo.get(norm(codigo));
		if (id == null) continue;
		for (const turma of turmasPorId.get(id) ?? []) {
			out.push({ turma, codigoOfertado: norm(codigo) });
		}
	}
	return out;
}
