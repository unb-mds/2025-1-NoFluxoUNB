/**
 * Status do histórico SIGAA que contam como componente curricular integralizado
 * (aprovado, cumprido por equivalência ou dispensado).
 */
export function isDisciplinaIntegralizada(status: string | undefined): boolean {
    const s = (status || '').toUpperCase();
    return s === 'APR' || s === 'CUMP' || s === 'DISP';
}
