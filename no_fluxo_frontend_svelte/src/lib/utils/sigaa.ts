export type HorarioLinha = {
	dia: string;
	faixas: string[];
};

const DIA_MAP: Record<string, string> = {
	'2': 'Seg',
	'3': 'Ter',
	'4': 'Qua',
	'5': 'Qui',
	'6': 'Sex',
	'7': 'Sab'
};

const SLOT_MAP: Record<'M' | 'T' | 'N', Record<string, string>> = {
	M: {
		'1': '08:00-08:55',
		'2': '08:55-09:50',
		'3': '10:00-10:55',
		'4': '10:55-11:50',
		'5': '12:00-12:55'
	},
	T: {
		'1': '12:55-13:50',
		'2': '14:00-14:55',
		'3': '14:55-15:50',
		'4': '16:00-16:55',
		'5': '16:55-17:50',
		'6': '18:00-18:55',
		'7': '18:55-19:50'
	},
	N: {
		'1': '19:00-19:50',
		'2': '19:50-20:40',
		'3': '20:50-21:40',
		'4': '21:40-22:30'
	}
};

export function formatHorarioSigaa(rawHorario: string): HorarioLinha[] {
	const raw = String(rawHorario ?? '').trim();
	if (!raw) return [];

	// Ex.: 24M12, 35T34, 6N1234, múltiplos blocos no mesmo texto.
	const regex = /([2-7]+)\s*([MTN])\s*([1-7]+)/g;
	const out: HorarioLinha[] = [];
	let match: RegExpExecArray | null = regex.exec(raw);

	while (match) {
		const diasCod = match[1] ?? '';
		const turno = (match[2] ?? 'M') as 'M' | 'T' | 'N';
		const slotsCod = match[3] ?? '';
		const faixas = [...slotsCod].map((s) => SLOT_MAP[turno]?.[s] ?? `${turno}${s}`);

		for (const d of [...diasCod]) {
			const dia = DIA_MAP[d] ?? d;
			out.push({
				dia,
				faixas
			});
		}
		match = regex.exec(raw);
	}

	return out;
}

export function formatHoraCompacta(raw: string): string {
	const [h, m] = raw.split(':');
	if (!h) return raw;
	const hora = String(Number(h));
	if (!m || m === '00') return `${hora}h`;
	return `${hora}h${m}`;
}

export function compactarFaixasHorarias(faixas: string[]): string {
	if (!faixas || faixas.length === 0) return '-';
	const primeira = faixas[0];
	const ultima = faixas[faixas.length - 1];
	const inicio = primeira.split('-')[0] ?? primeira;
	const fim = ultima.split('-')[1] ?? ultima;
	return `${formatHoraCompacta(inicio)} - ${formatHoraCompacta(fim)}`;
}

export function formatLocalSigaa(rawLocal: string): string[] {
	const raw = String(rawLocal ?? '').trim();
	if (!raw) return [];

	// Ex.: "2N12(ICC ANF.12) 35N34(ICC ANF.15)"
	const regex = /([2-7]+[MTN][1-7]+)\(([^)]+)\)/g;
	const out: string[] = [];
	let match: RegExpExecArray | null = regex.exec(raw);

	while (match) {
		const codigo = String(match[1] ?? '').trim().toUpperCase();
		const local = String(match[2] ?? '').trim();
		const horarios = formatHorarioSigaa(codigo);
		if (horarios.length === 0) {
			out.push(`${local} (${codigo})`);
		} else {
			for (const h of horarios) {
				out.push(`${h.dia} (${compactarFaixasHorarias(h.faixas)}) - ${local}`);
			}
		}
		match = regex.exec(raw);
	}

	if (out.length > 0) return out;
	return [raw];
}

export function formatVagas(
	vagasSobrando: number | null,
	vagasOfertadas: number | null,
	vagasOcupadas: number | null
): string {
	if (vagasSobrando != null) return String(Math.max(0, vagasSobrando));
	if (vagasOfertadas != null && vagasOcupadas != null)
		return String(Math.max(0, vagasOfertadas - vagasOcupadas));
	return '-';
}

export function getVagasSobrandoNumero(
	vagasSobrando: number | null,
	vagasOfertadas: number | null,
	vagasOcupadas: number | null
): number | null {
	if (vagasSobrando != null) return Math.max(0, vagasSobrando);
	if (vagasOfertadas != null && vagasOcupadas != null)
		return Math.max(0, vagasOfertadas - vagasOcupadas);
	return null;
}
