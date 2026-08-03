#!/usr/bin/env node

// Test script to verify phantom optative prevention logic

const materias = [
    { codigo: "FGA0160", nome: "Optativa A", tipo_natureza: 1, obrigatoria: false, nivel: 6, carga_horaria: 60 },
    { codigo: "FGA0108", nome: "Optativa B", tipo_natureza: 1, obrigatoria: false, nivel: 6, carga_horaria: 60 },
    { codigo: "DSC9999", nome: "Optativa Fantasma", tipo_natureza: 1, obrigatoria: false, nivel: 6, carga_horaria: 60 },
    { codigo: "MAT0001", nome: "Obrigatória", tipo_natureza: 0, obrigatoria: true, nivel: 1, carga_horaria: 60 },
];

const codigosComOferta = new Set(["FGA0160", "FGA0108"]); // Apenas essas têm turmas reais

console.log("\n=== TEST: Phantom Optative Prevention ===\n");

for (const mat of materias) {
    const isOptativa = mat.tipo_natureza === 1;

    if (isOptativa && codigosComOferta) {
        const temOferta = codigosComOferta.has(mat.codigo);
        let bonus = 0;

        if (temOferta) {
            bonus = 5;
            console.log(`✅ ${mat.codigo} (${mat.nome}): Optativa com OFERTA REAL → +5 bônus`);
        } else {
            bonus = -10;
            console.log(`❌ ${mat.codigo} (${mat.nome}): Optativa FANTASMA (sem turmas) → -10 penalidade`);
        }
    } else if (isOptativa) {
        console.log(`⚠️  ${mat.codigo} (${mat.nome}): Optativa (nenhuma info de oferta)`);
    } else {
        console.log(`✓ ${mat.codigo} (${mat.nome}): Obrigatória (sem penalidade/bônus)`);
    }
}

console.log("\n=== Summary ===");
console.log(`Optativas com oferta real (recomendáveis): ${Array.from(codigosComOferta).join(", ")}`);
const optativaSemOferta = materias.filter(m => m.tipo_natureza === 1 && !codigosComOferta.has(m.codigo));
console.log(`Optativas fantasma (não recomendáveis): ${optativaSemOferta.map(m => m.codigo).join(", ")}`);
console.log("\nQuando real optativas não forem suficientes, o sistema usará slots genéricos.\n");
