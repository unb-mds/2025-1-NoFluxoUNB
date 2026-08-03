/**
 * Porto do núcleo algorítmico do Montador de Grade
 * (no_fluxo_frontend_svelte/src/lib/utils/horario-slots.ts). Duplicado de
 * propósito — os dois projetos não compartilham pacote — mas os dois lados
 * DEVEM mudar juntos se o formato de horário SIGAA mudar. Ver também o
 * comentário espelhado no arquivo do frontend.
 *
 * Horários da UnB: 16 módulos possíveis por dia (M1–M5, T1–T7, N1–N4), semana
 * útil de segunda (2) a sábado (7). Horário SIGAA (ex.: "246M12 35T34") vira
 * um bitmask BigInt de 96 bits (6 dias × 16 módulos) — conflito de horário
 * fica uma operação bit-a-bit O(1).
 */

const DIA_INDEX: Record<string, number> = { "2": 0, "3": 1, "4": 2, "5": 3, "6": 4, "7": 5 };

export type Turno = "M" | "T" | "N";
const TURNO_OFFSET: Record<Turno, number> = { M: 0, T: 5, N: 12 };
const TURNO_MAX_MODULO: Record<Turno, number> = { M: 5, T: 7, N: 4 };
const TODOS_TURNOS: readonly Turno[] = ["M", "T", "N"];

const HORARIO_REGEX = /([2-7]+)\s*([MTN])\s*([1-7]+)/g;

export function slotMaskFromHorario(rawHorario: string | null | undefined): bigint {
    const raw = String(rawHorario ?? "").trim().toUpperCase();
    if (!raw) return 0n;

    let mask = 0n;
    const regex = new RegExp(HORARIO_REGEX.source, "g");
    let match: RegExpExecArray | null = regex.exec(raw);

    while (match) {
        const diasCod = match[1] ?? "";
        const turno = (match[2] ?? "M") as Turno;
        const modulosCod = match[3] ?? "";
        const maxModulo = TURNO_MAX_MODULO[turno];

        for (const d of diasCod) {
            const diaIndex = DIA_INDEX[d];
            if (diaIndex === undefined) continue;
            for (const m of modulosCod) {
                const modulo = Number(m);
                if (modulo < 1 || modulo > maxModulo) continue;
                const bitIndex = diaIndex * 16 + TURNO_OFFSET[turno] + (modulo - 1);
                mask |= 1n << BigInt(bitIndex);
            }
        }
        match = regex.exec(raw);
    }

    return mask;
}

export function hasConflict(a: bigint, b: bigint): boolean {
    return (a & b) !== 0n;
}

export function maskDosTurnos(turnos: Iterable<Turno>): bigint {
    const set = new Set(turnos);
    if (set.size === 0) return 0n;
    let mask = 0n;
    for (let dia = 0; dia < 6; dia++) {
        for (const turno of TODOS_TURNOS) {
            if (!set.has(turno)) continue;
            for (let m = 0; m < TURNO_MAX_MODULO[turno]; m++) {
                mask |= 1n << BigInt(dia * 16 + TURNO_OFFSET[turno] + m);
            }
        }
    }
    return mask;
}

/** Máscara livre = universo dos turnos permitidos menos o que já está ocupado. */
export function maskLivre(ocupada: bigint, turnosPermitidos: Iterable<Turno>): bigint {
    const universo = maskDosTurnos(turnosPermitidos);
    return universo & ~ocupada;
}
