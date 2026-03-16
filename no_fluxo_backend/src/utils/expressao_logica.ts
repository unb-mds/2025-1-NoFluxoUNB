/**
 * Utilitário para expressao_logica (JSONB) recursivo.
 * Formato: string | { operador: "OU"|"E", condicoes: ExpressaoLogicaRecursiva[] }
 * Alinhado ao output do script coleta_dados/dados/expressao_logica/parse-expressao.ts
 */

export type ExpressaoLogicaRecursiva =
    | string
    | { operador: "OU" | "E"; condicoes: ExpressaoLogicaRecursiva[] };

function norm(code: string): string {
    return (code || "").trim().toUpperCase();
}

function setHasCode(codes: Set<string>, code: string): boolean {
    const c = norm(code);
    return [...codes].some((x) => norm(x) === c);
}

/**
 * Extrai todos os códigos de matérias de uma expressão lógica recursiva.
 */
export function getCodigosFromExpressaoLogica(
    expr: ExpressaoLogicaRecursiva | null | undefined
): string[] {
    if (!expr) return [];
    if (typeof expr === "string") {
        const c = norm(expr);
        return c ? [c] : [];
    }
    if (expr && typeof expr === "object" && Array.isArray(expr.condicoes)) {
        return expr.condicoes.flatMap((c) => getCodigosFromExpressaoLogica(c));
    }
    return [];
}

/**
 * Verifica se um código está contido na expressão.
 */
export function codigoContidoEmExpressaoLogica(
    expr: ExpressaoLogicaRecursiva | null | undefined,
    codigo: string
): boolean {
    const codigos = getCodigosFromExpressaoLogica(expr);
    const codigoNorm = norm(codigo);
    return codigos.some((c) => c === codigoNorm);
}

/**
 * Avalia se a expressão lógica é satisfeita pelo conjunto de códigos concluídos.
 * OU: qualquer condição satisfeita
 * E: todas as condições satisfeitas
 */
export function satisfazExpressaoLogica(
    expr: ExpressaoLogicaRecursiva | null | undefined,
    completedCodes: Set<string>
): boolean {
    if (!expr) return false;

    if (typeof expr === "string") {
        return setHasCode(completedCodes, expr);
    }

    if (expr && typeof expr === "object" && Array.isArray(expr.condicoes)) {
        if (expr.condicoes.length === 0) return false;
        const op = (expr.operador || "OU").toUpperCase();
        const resultados = expr.condicoes.map((c) =>
            satisfazExpressaoLogica(c, completedCodes)
        );
        if (op === "E") {
            return resultados.every(Boolean);
        }
        return resultados.some(Boolean);
    }

    return false;
}

/**
 * Avalia com array de códigos (converte para Set internamente).
 */
export function satisfazExpressaoLogicaComArray(
    expr: ExpressaoLogicaRecursiva | null | undefined,
    completedCodes: string[]
): boolean {
    const set = new Set(completedCodes.map(norm));
    return satisfazExpressaoLogica(expr, set);
}

/** Regex para código de matéria (ex: MAT0026) */
const CODIGO_MATERIA_REGEX = /^[A-Za-z]{2,}\d{3,}$/;

/**
 * Normaliza expressao_logica vinda do banco (JSONB).
 * Pode vir como: string simples "MAT0026"; string com aspas "\"MAT0026\""; ou objeto {"operador","condicoes"}.
 */
export function parseExpressaoLogicaFromDb(
    value: unknown
): ExpressaoLogicaRecursiva | null {
    if (value == null) return null;
    if (typeof value === "string") {
        let s = value.trim();
        if (!s) return null;
        // Remove camadas de aspas: "MAT0026" ou \"MAT0026\"
        while (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
            s = s.slice(1, -1).trim();
        }
        if (s.length >= 4 && s.startsWith('\\"') && s.endsWith('\\"')) {
            s = s.slice(2, -2).trim();
        }
        if (!s) return null;
        // String que parece um único código de matéria (ex: MAT0026)
        if (CODIGO_MATERIA_REGEX.test(s)) return s.toUpperCase();
        // String que parece JSON (ex: retorno serializado)
        if (s.startsWith("{") || s.startsWith("[")) {
            try {
                const parsed = JSON.parse(value.trim()) as ExpressaoLogicaRecursiva;
                return parsed;
            } catch {
                return null;
            }
        }
        return s.toUpperCase();
    }
    if (typeof value === "object" && value !== null && "condicoes" in (value as object)) {
        return value as ExpressaoLogicaRecursiva;
    }
    return null;
}
