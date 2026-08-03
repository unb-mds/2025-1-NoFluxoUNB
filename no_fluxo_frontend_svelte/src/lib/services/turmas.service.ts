/**
 * Acesso às ofertas de turmas (tabela `turmas`) para o Montador de Grade.
 * Extrai o padrão de consulta já usado em `TurmasVagasPanel.svelte` para um
 * serviço reusável, sempre filtrando pelo período letivo ativo (RPC
 * `periodo_letivo_atual`).
 */
import { createSupabaseBrowserClient } from '$lib/supabase/client';

export interface TurmaOferta {
	id_turmas: number;
	id_materia: number;
	turma: string;
	docente: string | null;
	horario: string | null;
	local: string | null;
	ano_periodo: string;
	vagas_ofertadas: number | null;
	vagas_ocupadas: number | null;
	vagas_sobrando: number | null;
}

const supabase = createSupabaseBrowserClient();

const TURMA_COLUNAS =
	'id_turmas, id_materia, turma, docente, horario, local, ano_periodo, vagas_ofertadas, vagas_ocupadas, vagas_sobrando';

/** Período letivo ativo no banco (ex.: "2026.1"). */
export async function getPeriodoAtivo(): Promise<string> {
	const { data, error } = await supabase.rpc('periodo_letivo_atual');
	if (error) throw new Error(error.message);
	return data as string;
}

/**
 * Busca as turmas ofertadas para um conjunto de matérias no período informado
 * (ou no período ativo, se omitido). Retorna lista achatada — o agrupamento por
 * matéria fica a cargo do chamador (via `id_materia`).
 */
export async function getTurmasPorMaterias(
	idMaterias: number[],
	periodo?: string
): Promise<TurmaOferta[]> {
	if (idMaterias.length === 0) return [];

	const periodoAtivo = periodo ?? (await getPeriodoAtivo());

	const { data, error } = await supabase
		.from('turmas')
		.select(TURMA_COLUNAS)
		.in('id_materia', idMaterias)
		.eq('ano_periodo', periodoAtivo)
		.order('turma');

	if (error) throw new Error(error.message);
	return (data as TurmaOferta[] | null) ?? [];
}
