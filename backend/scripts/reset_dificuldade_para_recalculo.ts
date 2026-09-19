/**
 * Reset pontual de dificuldade_estimada para matérias com dado real.
 *
 * Uso: depois de uma mudança na fórmula de cálculo em DificuldadeAgenteService
 * (ex.: troca do corte binário n>=3 por shrinkage contínuo), matérias que já
 * tinham dificuldade_estimada calculada com a fórmula ANTIGA precisam ser
 * resetadas para NULL, senão o lazy-loading do PlanejamentoController nunca as
 * recalcula (só recalcula quando dificuldade_estimada é NULL).
 *
 * Diferente do reset feito no fim de import_avaliacoes_disciplinas.ts (que só
 * pega quem ainda não é 'real'): este aqui reseta TODAS as matérias com dado
 * real de qualquer uma das duas fontes (avaliações de alunos OU taxa de
 * reprovação real do histórico acadêmico), incluindo as já marcadas
 * 'real'/'hibrido' — porque desta vez é a fórmula em si que mudou, não só a
 * chegada de dado novo.
 *
 * Uso: npx tsx scripts/reset_dificuldade_para_recalculo.ts
 */

import { createClient } from "@supabase/supabase-js";
import * as path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

for (const envPath of [path.join(__dirname, "..", ".env"), ".env"]) {
    const result = dotenv.config({ path: envPath });
    if (!result.error) break;
}

const SUPABASE_URL = process.env.SUPABASE_URL || "";
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

async function main() {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
        console.error("❌ Faltam credenciais do Supabase (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
        process.exit(1);
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    console.log("🔍 Buscando matérias com pelo menos 1 avaliação real ou 1 tentativa real no histórico...");
    const ids = new Set<number>();

    // Fonte 1: avaliações de alunos (view já tem id_materia, veio de join com materias)
    {
        let from = 0;
        const pageSize = 1000;
        while (true) {
            const { data, error } = await supabase
                .from("materias_estatisticas_avaliacoes")
                .select("id_materia")
                .gte("n_avaliacoes", 1)
                .range(from, from + pageSize - 1);
            if (error) throw error;
            if (!data || data.length === 0) break;
            for (const row of data as { id_materia: number }[]) ids.add(row.id_materia);
            from += pageSize;
            if (data.length < pageSize) break;
        }
    }

    // Fonte 2: histórico acadêmico real (view só tem codigo_materia — não passou por
    // join com materias, já que vem de historicos_usuarios — resolve id_materia à parte).
    {
        const codigos: string[] = [];
        let from = 0;
        const pageSize = 1000;
        while (true) {
            const { data, error } = await supabase
                .from("materias_estatisticas_historico")
                .select("codigo_materia")
                .gte("n_tentativas", 1)
                .range(from, from + pageSize - 1);
            if (error) throw error;
            if (!data || data.length === 0) break;
            for (const row of data as { codigo_materia: string }[]) codigos.push(row.codigo_materia);
            from += pageSize;
            if (data.length < pageSize) break;
        }
        for (let i = 0; i < codigos.length; i += 500) {
            const batch = codigos.slice(i, i + 500);
            const { data, error } = await supabase.from("materias").select("id_materia").in("codigo_materia", batch);
            if (error) throw error;
            for (const row of (data as { id_materia: number }[]) || []) ids.add(row.id_materia);
        }
    }

    if (ids.size === 0) {
        console.log("Nenhuma matéria com dado real (avaliação ou histórico) encontrada. Nada a fazer.");
        return;
    }

    const idsArray = [...ids];
    console.log(`   ${idsArray.length} matéria(s) com dado real. Resetando dificuldade_estimada/fonte para recálculo...`);

    const BATCH = 200;
    let resetadas = 0;
    for (let i = 0; i < idsArray.length; i += BATCH) {
        const batch = idsArray.slice(i, i + BATCH);
        const { error } = await supabase
            .from("materias")
            .update({
                dificuldade_estimada: null,
                motivo_dificuldade: null,
                dificuldade_calculada_em: null,
                dificuldade_fonte: null,
            })
            .in("id_materia", batch);
        if (error) throw error;
        resetadas += batch.length;
        process.stdout.write(`\r   ${resetadas}/${idsArray.length}`);
    }
    console.log("");
    console.log("✅ Reset concluído. Próxima geração de plano recalcula essas matérias com a fórmula nova.");
}

main().catch((err) => {
    console.error("❌ Falha no reset:", err);
    process.exit(1);
});
