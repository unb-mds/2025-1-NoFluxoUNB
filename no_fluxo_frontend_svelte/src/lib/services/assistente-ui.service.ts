import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { getCodigosFromExpressaoLogica, getLogicalCodeGroups } from '$lib/utils/expressao-logica';
import { config } from '$lib/config';

export interface TurmaInfo {
	turma: string;
	anoPeriodo: string;
	docente: string;
	horario: string;
	local: string;
	vagasOfertadas: number | null;
	vagasOcupadas: number | null;
	vagasSobrando: number | null;
	lastUpdatedAt: string | null;
}

export interface AssistenteMateriaContext {
	idMateria: number;
	codigoMateria: string;
	nomeMateria: string;
	departamento: string;
	ementa: string;
	creditos: number;
	nivel: number | null;
	tipoNatureza: number | null;
	prerequisitos: string[];
	prerequisitosExpressoes: Array<{
		expressaoOriginal: string | null;
		grupos: string[][];
	}>;
	turmas: TurmaInfo[];
	ultimaAtualizacaoTurmas: string | null;
}

type MateriaRow = {
	id_materia: number;
	codigo_materia: string;
	nome_materia: string;
	departamento?: string | null;
	ementa?: string | null;
	carga_horaria?: number | null;
};

type MateriaCursoRow = {
	nivel?: number | null;
	tipo_natureza?: number | null;
	id_matriz?: number | null;
};

type PrereqRow = {
	id_materia_requisito?: number | null;
	expressao_original?: string | null;
	expressao_logica?: unknown | null;
	materias?: { codigo_materia?: string | null; nome_materia?: string | null } | null;
};

type TurmaRow = {
	turma?: string | null;
	ano_periodo?: string | null;
	docente?: string | null;
	horario?: string | null;
	local?: string | null;
	vagas_ofertadas?: number | null;
	vagas_ocupadas?: number | null;
	vagas_sobrando?: number | null;
	last_updated_at?: string | null;
	updated_at?: string | null;
};

class AssistenteUIService {
	private readonly supabase = createSupabaseBrowserClient();

	private async fetchTurmasViaBackend(codigoMateria: string): Promise<{
		turmas: TurmaInfo[];
		ultimaAtualizacaoTurmas: string | null;
	}> {
		const url = `${config.apiUrl}/assistente/turmas-by-codigo?codigo=${encodeURIComponent(
			codigoMateria
		)}`;
		const response = await fetch(url);
		if (!response.ok) return { turmas: [], ultimaAtualizacaoTurmas: null };
		const data = (await response.json()) as {
			turmas?: TurmaInfo[];
			ultimaAtualizacaoTurmas?: string | null;
		};
		return {
			turmas: Array.isArray(data.turmas) ? data.turmas : [],
			ultimaAtualizacaoTurmas: data.ultimaAtualizacaoTurmas ?? null
		};
	}

	private async fetchPrerequisitosViaBackend(codigoMateria: string): Promise<PrereqRow[]> {
		const url = `${config.apiUrl}/assistente/prerequisitos-by-codigo?codigo=${encodeURIComponent(
			codigoMateria
		)}`;
		const response = await fetch(url);
		if (!response.ok) return [];
		const data = (await response.json()) as { prerequisitos?: PrereqRow[] };
		return Array.isArray(data.prerequisitos) ? data.prerequisitos : [];
	}

	private extractSubjectCodesFromExpression(expression: string | null | undefined): string[] {
		if (!expression) return [];
		const normalized = String(expression)
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '')
			.toUpperCase();
		const matches = normalized.match(/[A-Z]{3}\d{4}/g) ?? [];
		return [...new Set(matches.map((c) => c.trim().toUpperCase()))];
	}

	private async resolveMatrizId(matrizCurricular: string): Promise<number | null> {
		const raw = (matrizCurricular ?? '').trim();
		if (!raw) return null;

		const matrizLimpa = raw.replace(/\s*-\s*\d{4}\.\d+$/u, '').trim();
		const query = matrizLimpa || raw;

		const { data, error } = await this.supabase
			.from('matrizes')
			.select('id_matriz, curriculo_completo')
			.ilike('curriculo_completo', `%${query}%`)
			.limit(1);

		if (error || !data || data.length === 0) return null;
		return Number(data[0].id_matriz);
	}

	async getMateriaContext(
		codigoMateria: string,
		matrizCurricular: string
	): Promise<AssistenteMateriaContext | null> {
		const codigo = (codigoMateria ?? '').trim().toUpperCase();
		if (!codigo) return null;

		const { data: materiaData, error: materiaError } = await this.supabase
			.from('materias')
			.select('id_materia, codigo_materia, nome_materia, departamento, ementa, carga_horaria')
			.eq('codigo_materia', codigo)
			.limit(1);

		if (materiaError || !materiaData || materiaData.length === 0) return null;
		const materia = materiaData[0] as MateriaRow;

		const matrizId = await this.resolveMatrizId(matrizCurricular);

		const materiaCursoQuery = this.supabase
			.from('materias_por_curso')
			.select('nivel, tipo_natureza, id_matriz')
			.eq('id_materia', materia.id_materia)
			.limit(20);

		const materiaCursoResult = matrizId
			? await materiaCursoQuery.eq('id_matriz', matrizId)
			: await materiaCursoQuery;

		const prereqResult = await this.supabase
			.from('pre_requisitos')
			.select(
				'id_materia_requisito, expressao_original, expressao_logica, materias:id_materia_requisito(codigo_materia, nome_materia)'
			)
			.eq('id_materia', materia.id_materia);

		const turmasResult = await this.supabase
			.from('turmas')
			.select('*')
			.eq('id_materia', materia.id_materia)
			.order('ano_periodo', { ascending: false })
			.limit(30);

		const materiaCursoRows = (materiaCursoResult.data ?? []) as MateriaCursoRow[];
		const preferencial = matrizId
			? materiaCursoRows.find((row) => Number(row.id_matriz) === matrizId) ?? materiaCursoRows[0]
			: materiaCursoRows[0];

		let prereqRows = (prereqResult.data ?? []) as PrereqRow[];
		if (prereqRows.length === 0 || prereqResult.error) {
			try {
				const fallbackPrereqs = await this.fetchPrerequisitosViaBackend(codigo);
				if (fallbackPrereqs.length > 0) prereqRows = fallbackPrereqs;
			} catch {
				// mantém vazio caso fallback também falhe
			}
		}
		const prereqCodes = new Set<string>();
		const prereqExpressionRows: Array<{
			expressaoOriginal: string | null;
			gruposCodigos: string[][];
		}> = [];

		for (const row of prereqRows) {
			const codigoDireto = String(row.materias?.codigo_materia ?? '')
				.trim()
				.toUpperCase();
			if (codigoDireto) prereqCodes.add(codigoDireto);

			if (row.expressao_logica) {
				try {
					const fromLogic = getCodigosFromExpressaoLogica(row.expressao_logica as never);
					for (const code of fromLogic) {
						const c = String(code).trim().toUpperCase();
						if (c) prereqCodes.add(c);
					}
				} catch {
					// ignore malformed JSONB and keep fallback from textual expression
				}
			}

			const fromOriginal = this.extractSubjectCodesFromExpression(row.expressao_original);
			for (const code of fromOriginal) prereqCodes.add(code);

			const grupos = getLogicalCodeGroups(
				(row.expressao_logica as never) ?? null,
				row.expressao_original ?? null
			)
				.map((group) =>
					[...new Set(group.map((c) => String(c).trim().toUpperCase()).filter(Boolean))]
				)
				.filter((group) => group.length > 0);

			if (grupos.length > 0) {
				prereqExpressionRows.push({
					expressaoOriginal: row.expressao_original ? String(row.expressao_original).trim() : null,
					gruposCodigos: grupos
				});
			}
		}

		const prereqCodesList = [...prereqCodes];
		const prereqNameByCode = new Map<string, string>();
		if (prereqCodesList.length > 0) {
			const { data: prereqMaterias } = await this.supabase
				.from('materias')
				.select('codigo_materia, nome_materia')
				.in('codigo_materia', prereqCodesList);

			for (const row of prereqMaterias ?? []) {
				const code = String((row as { codigo_materia?: string }).codigo_materia ?? '')
					.trim()
					.toUpperCase();
				const name = String((row as { nome_materia?: string }).nome_materia ?? '').trim();
				if (code) prereqNameByCode.set(code, name);
			}
		}

		const prerequisitos = [
			...new Set(
				prereqCodesList
					.map((codigoReq) => {
						const nomeReq = prereqNameByCode.get(codigoReq) ?? '';
						if (nomeReq) return `${codigoReq} - ${nomeReq}`;
						return codigoReq;
					})
					.filter(Boolean)
			)
		];

		const prerequisitosExpressoes = prereqExpressionRows.map((row) => ({
			expressaoOriginal: row.expressaoOriginal,
			grupos: row.gruposCodigos.map((group) =>
				group.map((code) => {
					const name = prereqNameByCode.get(code) ?? '';
					return name ? `${code} - ${name}` : code;
				})
			)
		}));

		const turmaRows = (turmasResult.data ?? []) as TurmaRow[];
		let turmas: TurmaInfo[] = turmaRows.map((row) => {
			const vagasOfertadas =
				row.vagas_ofertadas != null ? Number(row.vagas_ofertadas) : null;
			const vagasOcupadas = row.vagas_ocupadas != null ? Number(row.vagas_ocupadas) : null;
			const vagasSobrandoInformada =
				row.vagas_sobrando != null ? Number(row.vagas_sobrando) : null;
			const vagasSobrando =
				vagasSobrandoInformada != null
					? vagasSobrandoInformada
					: vagasOfertadas != null && vagasOcupadas != null
						? vagasOfertadas - vagasOcupadas
						: null;

			return {
				turma: String(row.turma ?? '').trim(),
				anoPeriodo: String(row.ano_periodo ?? '').trim(),
				docente: String(row.docente ?? '').trim(),
				horario: String(row.horario ?? '').trim(),
				local: String(row.local ?? '').trim(),
				vagasOfertadas,
				vagasOcupadas,
				vagasSobrando,
				lastUpdatedAt:
					typeof row.last_updated_at === 'string'
						? row.last_updated_at
						: typeof row.updated_at === 'string'
							? row.updated_at
							: null
			};
		});

		let ultimaAtualizacaoTurmas: string | null = turmas
			.map((t) => t.lastUpdatedAt)
			.filter((v): v is string => !!v)
			.sort()
			.reverse()[0] ?? null;

		// Fallback: quando o frontend não consegue ler "turmas" (RLS/policies),
		// tenta via backend Node (service role).
		if (turmas.length === 0 || turmasResult.error) {
			try {
				const fallback = await this.fetchTurmasViaBackend(codigo);
				if (fallback.turmas.length > 0) {
					turmas = fallback.turmas;
					ultimaAtualizacaoTurmas = fallback.ultimaAtualizacaoTurmas ?? null;
				}
			} catch {
				// ignora erro de fallback e mantém lista vazia
			}
		}

		return {
			idMateria: Number(materia.id_materia),
			codigoMateria: String(materia.codigo_materia ?? codigo),
			nomeMateria: String(materia.nome_materia ?? ''),
			departamento: String(materia.departamento ?? '').trim(),
			ementa: String(materia.ementa ?? ''),
			creditos:
				materia.carga_horaria != null && Number.isFinite(Number(materia.carga_horaria))
					? Number(materia.carga_horaria) / 15
					: 0,
			nivel: preferencial?.nivel != null ? Number(preferencial.nivel) : null,
			tipoNatureza:
				preferencial?.tipo_natureza != null ? Number(preferencial.tipo_natureza) : null,
			prerequisitos,
			prerequisitosExpressoes,
			turmas,
			ultimaAtualizacaoTurmas
		};
	}
}

export const assistenteUIService = new AssistenteUIService();
