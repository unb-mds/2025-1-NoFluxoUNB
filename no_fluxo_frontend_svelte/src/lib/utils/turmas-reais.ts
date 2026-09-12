/**
 * Casamento entre a matrícula real do histórico SIGAA e a oferta de turmas do
 * montador — extraído da página do montador para ser testável e reusável.
 *
 * O histórico traz, para cada matéria com status MATR, a turma em que o aluno
 * de fato se matriculou (`DadosMateria.turma`). Quando essa matrícula é do
 * mesmo período da oferta carregada, dá para pré-selecionar a turma real no
 * calendário em vez de deixar a matéria solta.
 */
import { isMateriaCurrent, type DadosFluxogramaUser } from '$lib/types/user';

/**
 * Visão mínima de uma matéria do pool que o casamento precisa — estruturalmente
 * compatível com `MateriaGrade` sem acoplar este módulo ao store.
 */
export interface MateriaComTurmas {
	codigo: string;
	turmas: Array<{ turma: { id_turmas: number; turma: string }; codigoOfertado?: string }>;
}

/** "01" e "1" são a mesma turma — o SIGAA ora zera à esquerda, ora não. */
export function mesmaTurma(a: string, b: string): boolean {
	const norm = (s: string) =>
		s
			.trim()
			.toUpperCase()
			.replace(/^0+(?=\d)/, '');
	return norm(a) === norm(b);
}

/**
 * Turma real (do histórico SIGAA) por código de matéria matriculada agora.
 * Só vale quando o período da matrícula é o mesmo da oferta carregada — a
 * turma "01" de outro semestre pode ter horário completamente diferente.
 */
export function turmasReaisDoHistorico(
	dados: DadosFluxogramaUser | null | undefined,
	periodoAtivo: string
): Map<string, string> {
	const mapa = new Map<string, string>();
	for (const semestre of dados?.dadosFluxograma ?? []) {
		for (const dm of semestre) {
			const turma = dm.turma?.trim();
			if (!turma || !isMateriaCurrent(dm)) continue;
			if ((dm.anoPeriodo ?? '').trim() !== periodoAtivo) continue;
			mapa.set(dm.codigoMateria.trim().toUpperCase(), turma);
		}
	}
	return mapa;
}

/**
 * Turma da oferta que corresponde à matrícula real da matéria, ou `null` se o
 * histórico não tem essa matrícula (ou a turma dele não existe na oferta). A
 * matrícula em equivalente casa pelo `codigoOfertado` da turma — o histórico
 * registra o código em que o aluno de fato se matriculou.
 */
export function encontrarTurmaReal(
	materia: MateriaComTurmas,
	reais: ReadonlyMap<string, string>
): number | null {
	const alvo = materia.turmas.find((t) => {
		const real = reais.get((t.codigoOfertado ?? materia.codigo).trim().toUpperCase());
		return !!real && mesmaTurma(t.turma.turma, real);
	});
	return alvo?.turma.id_turmas ?? null;
}
