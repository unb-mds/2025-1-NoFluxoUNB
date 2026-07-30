import { slotMaskFromHorario, hasConflict, maskDosTurnos, maskLivre } from "../src/utils/horario_slots";

describe("horario_slots (backend) — porto de horario-slots.ts do frontend", () => {
    it("slotMaskFromHorario: mesmo horário SIGAA gera a mesma máscara duas vezes (determinístico)", () => {
        const a = slotMaskFromHorario("246M12 35T34");
        const b = slotMaskFromHorario("246M12 35T34");
        expect(a).toBe(b);
        expect(a).not.toBe(0n);
    });

    it("slotMaskFromHorario: horário vazio/EAD retorna máscara 0n", () => {
        expect(slotMaskFromHorario(null)).toBe(0n);
        expect(slotMaskFromHorario("")).toBe(0n);
        expect(slotMaskFromHorario("A DEFINIR")).toBe(0n);
    });

    it("hasConflict: duas turmas no mesmo dia/módulo conflitam", () => {
        const a = slotMaskFromHorario("2M12");
        const b = slotMaskFromHorario("2M23");
        expect(hasConflict(a, b)).toBe(true);
    });

    it("hasConflict: turmas em módulos totalmente distintos não conflitam", () => {
        const a = slotMaskFromHorario("2M12");
        const b = slotMaskFromHorario("3T12");
        expect(hasConflict(a, b)).toBe(false);
    });

    it("maskLivre: universo menos ocupado dá exatamente o complemento", () => {
        const ocupada = slotMaskFromHorario("2M12");
        const livre = maskLivre(ocupada, ["M", "T", "N"]);
        expect(hasConflict(livre, ocupada)).toBe(false);
        expect(livre | ocupada).toBe(maskDosTurnos(["M", "T", "N"]));
    });

    it("maskLivre: restrito a um turno não inclui slots de outro turno", () => {
        const livreSoManha = maskLivre(0n, ["M"]);
        const tardeQualquer = slotMaskFromHorario("2T1");
        expect(hasConflict(livreSoManha, tardeQualquer)).toBe(false);
    });
});
