/**
 * Import: avaliações reais de disciplinas (formulário público)
 *
 * Lê o CSV de respostas (Google Forms), normaliza campos categóricos, resolve
 * cada linha para um id_materia (via codigo_materia exato ou fuzzy match de
 * nome_materia + departamento), redige nome de professor do texto livre, e
 * importa para public.avaliacoes_disciplinas (idempotente via raw_row_hash).
 *
 * Escopo é só disciplina — nenhum dado de professor é armazenado.
 *
 * Uso:
 *   npx tsx scripts/import_avaliacoes_disciplinas.ts <caminho-csv> [--write] [--out <dir>]
 *
 * Sem --write: dry-run. Só imprime estatísticas e grava relatórios (não-matches,
 * matches ambíguos, amostra de redação) na pasta --out (default: scripts/_import_reports).
 * Com --write: além do dry-run, insere as linhas resolvidas em avaliacoes_disciplinas
 * (upsert por raw_row_hash, seguro rodar mais de uma vez).
 *
 * IMPORTANTE sobre a redação de nomes: é defesa em profundidade, não a garantia
 * principal. Ela só apaga o nome do professor daquela própria linha (extraído da
 * coluna "Professor (a)", que é descartada); não pega nomes de OUTROS professores
 * mencionados incidentalmente no texto, nem sobrenomes que não vieram naquela
 * coluna. A garantia real é de contrato de aplicação: feedback_texto/metodo_avaliacao
 * nunca devem ser expostos verbatim (nem via API pública, nem authenticated, nem
 * repassados a um LLM voltado ao usuário) — só agregados (ver materias_estatisticas_avaliacoes).
 */

import { createClient } from "@supabase/supabase-js";
import * as fs from "fs";
import * as path from "path";
import * as crypto from "crypto";
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

// =============================================================================
// CLI args
// =============================================================================

function parseArgs(argv: string[]) {
    const positional = argv.filter((a) => !a.startsWith("--"));
    const write = argv.includes("--write");
    const outIdx = argv.indexOf("--out");
    const outDir = outIdx >= 0 ? argv[outIdx + 1] : path.join(__dirname, "_import_reports");
    return { csvPath: positional[0], write, outDir };
}

// =============================================================================
// CSV parsing (RFC4180: aspas, vírgulas e quebras de linha dentro de campos)
// =============================================================================

function parseCsv(content: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let field = "";
    let inQuotes = false;
    let i = 0;
    const n = content.length;

    const pushField = () => {
        row.push(field);
        field = "";
    };
    const pushRow = () => {
        pushField();
        rows.push(row);
        row = [];
    };

    while (i < n) {
        const c = content[i];

        if (inQuotes) {
            if (c === '"') {
                if (content[i + 1] === '"') {
                    field += '"';
                    i += 2;
                    continue;
                }
                inQuotes = false;
                i++;
                continue;
            }
            field += c;
            i++;
            continue;
        }

        if (c === '"') {
            inQuotes = true;
            i++;
            continue;
        }
        if (c === ",") {
            pushField();
            i++;
            continue;
        }
        if (c === "\r") {
            i++;
            continue;
        }
        if (c === "\n") {
            pushRow();
            i++;
            continue;
        }
        field += c;
        i++;
    }
    // última linha (sem \n final)
    if (field.length > 0 || row.length > 0) pushRow();

    return rows.filter((r) => !(r.length === 1 && r[0] === ""));
}

// =============================================================================
// Normalização de texto
// =============================================================================

function stripAccents(s: string): string {
    return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

// Cursos sequenciais em português quase sempre terminam em algarismo arábico no
// banco ("CÁLCULO 1"), mas alunos frequentemente escrevem numeral romano
// ("Cálculo I") — sem isso, "Cálculo I" fica ambíguo entre Cálculo 1/2/3 porque a
// similaridade de bigramas não pesa o último caractere o suficiente.
const ROMAN_TRAILING: Record<string, string> = { IV: "4", III: "3", II: "2", I: "1", V: "5" };
const ROMAN_TRAILING_REGEX = /\b(IV|III|II|I|V)$/;

function normalizeTrailingRoman(s: string): string {
    return s.replace(ROMAN_TRAILING_REGEX, (m) => ROMAN_TRAILING[m]);
}

function normText(s: string): string {
    const base = stripAccents(s.trim().toUpperCase()).replace(/\s+/g, " ");
    return normalizeTrailingRoman(base);
}

const CODIGO_MATERIA_REGEX = /^[A-Za-z]{2,}\d{3,}$/;

// =============================================================================
// Canonicalização de campos categóricos (o formulário mudou de texto ao longo
// do tempo; cada categoria tem várias variantes que só diferem no texto depois
// do emoji, então detectamos pelo emoji/prefixo).
// =============================================================================

function canonDificuldade(raw: string): number | null {
    const s = raw.trim();
    if (s.startsWith("🟢")) return 1; // muito fácil
    if (s.startsWith("🟡")) return 2; // fácil
    if (s.startsWith("🟠")) return 3; // médio
    if (s.startsWith("🔴")) return 4; // difícil
    if (s.startsWith("🔥")) return 5; // muito difícil
    if (s.startsWith("💀")) return 6; // nível god
    return null;
}

function canonCarga(raw: string): number | null {
    const s = raw.trim();
    const lower = stripAccents(s.toLowerCase());
    if (s.startsWith("🟢")) return lower.includes("muito leve") ? 1 : 2; // leve
    if (s.startsWith("🟡")) return 3; // moderada
    if (s.startsWith("🟠")) return 4; // intensa
    if (s.startsWith("🔴")) return 5; // exagerada
    return null;
}

function canonMaterial(raw: string): string | null {
    const s = raw.trim();
    if (s.startsWith("✅")) return "suficiente";
    if (s.startsWith("⚠️") || s.startsWith("⚠")) return "insuficiente";
    if (s.startsWith("📜")) return "desatualizado";
    if (s.startsWith("❌")) return "inexistente";
    return null;
}

function canonRecomendaria(raw: string): string | null {
    const s = raw.trim();
    if (s.startsWith("✅")) return "sim";
    if (s.startsWith("❌")) return "nao";
    if (s.startsWith("🔄")) return "depende";
    return null;
}

/** Normaliza strings de semestre (2024/2, 2024.2, 24/2, 26.1, 2025/02, ...) para 'YYYY.S' */
function normalizeSemestre(raw: string): string | null {
    const s = raw.trim();
    const m = s.match(/^(\d{2,4})[./](\d{1,2})\s*$/);
    if (!m) return null;
    let [, yearStr, semStr] = m;
    let year = parseInt(yearStr, 10);
    let sem = parseInt(semStr, 10);
    if (yearStr.length === 2) year += 2000;
    if (sem >= 10) sem = sem % 10; // ex: '02' -> 2, '01' -> 1
    if (year < 2015 || year > 2035) return null;
    if (sem !== 1 && sem !== 2) return null;
    return `${year}.${sem}`;
}

// =============================================================================
// Similaridade de string (Dice coefficient sobre bigramas de caracteres) —
// mesma ideia do pg_trgm/similarity() já usado no banco, calculado em memória
// para não depender de uma função SQL nova só para este import único.
// =============================================================================

function bigrams(s: string): Map<string, number> {
    const map = new Map<string, number>();
    const padded = ` ${s} `;
    for (let i = 0; i < padded.length - 1; i++) {
        const bg = padded.slice(i, i + 2);
        map.set(bg, (map.get(bg) || 0) + 1);
    }
    return map;
}

function bigramTotal(bg: Map<string, number>): number {
    let total = 0;
    for (const v of bg.values()) total += v;
    return total;
}

/** Dice coefficient a partir de bigramas já pré-computados (evita reconstruir o mapa do lado "b" a cada comparação). */
function diceCoefficientPrecomputed(bgA: Map<string, number>, totalA: number, bgB: Map<string, number>, totalB: number): number {
    if (totalA + totalB === 0) return 0;
    let intersection = 0;
    // itera sobre o menor mapa
    const [small, big] = bgA.size <= bgB.size ? [bgA, bgB] : [bgB, bgA];
    for (const [bg, count] of small) {
        const other = big.get(bg);
        if (other) intersection += Math.min(count, other);
    }
    return (2 * intersection) / (totalA + totalB);
}

// Prefixos institucionais que não carregam sinal — removidos antes de comparar
// o campo livre "departamento" do CSV com materias.departamento.
const DEPT_PREFIXES = [
    "DEPARTAMENTO DE",
    "DEPTO",
    "INSTITUTO DE",
    "FACULDADE DE",
    "FACULDADE",
    "CENTRO DE",
    "CENTRO",
    "DECANATO DE",
    "DECANATO",
    "CAMPUS UNB",
    "CURSO DE",
];

function normalizeDepartamento(raw: string): string {
    let s = normText(raw);
    for (const prefix of DEPT_PREFIXES) {
        if (s.startsWith(prefix)) {
            s = s.slice(prefix.length).trim();
            break;
        }
    }
    return s.replace(/[():,]/g, " ").replace(/\s+/g, " ").trim();
}

// =============================================================================
// Redação de nomes de professor no texto livre
// =============================================================================

const STOPWORDS_NOME = new Set(["DE", "DA", "DO", "DOS", "DAS", "E", "A", "O", "SR", "SRA", "DR", "DRA", "PROF", "PROFESSOR", "PROFESSORA"]);

function extrairTokensNome(rawProfessor: string): string[] {
    const partes = rawProfessor
        .split(/[,/&]| e | E |\n/)
        .flatMap((p) => p.trim().split(/\s+/))
        .map((t) => t.replace(/[^\p{L}]/gu, ""))
        .filter((t) => t.length >= 3)
        .filter((t) => !STOPWORDS_NOME.has(stripAccents(t.toUpperCase())));
    return [...new Set(partes)];
}

// Grafias variam no texto livre (ex.: professor cadastrado como "César" mas o
// aluno escreve "Cezar"), então cada vogal do token vira uma classe de caracteres
// cobrindo as variantes acentuadas, em vez de exigir acento idêntico.
const VOWEL_CLASSES: Record<string, string> = {
    a: "[aàáâãä]",
    e: "[eèéêë]",
    i: "[iìíîï]",
    o: "[oòóôõö]",
    u: "[uùúûü]",
    c: "[cç]",
};

function tokenParaRegexAccentInsensitive(token: string): string {
    return token
        .split("")
        .map((ch) => {
            const base = stripAccents(ch).toLowerCase();
            const escaped = ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
            return VOWEL_CLASSES[base] || escaped;
        })
        .join("");
}

function redigirTexto(texto: string, tokensNome: string[]): string {
    let out = texto;
    for (const token of tokensNome) {
        const re = new RegExp(`\\b${tokenParaRegexAccentInsensitive(token)}\\b`, "giu");
        out = out.replace(re, "[professor]");
    }
    return out;
}

// =============================================================================
// Matching disciplina -> materias
// =============================================================================

interface MateriaRow {
    id_materia: number;
    codigo_materia: string;
    nome_materia: string;
    departamento: string | null;
}

interface MatchResult {
    id_materia: number | null;
    method: "codigo_exato" | "nome_fuzzy" | "sem_match";
    confidence: number;
    alternativas?: { id_materia: number; nome_materia: string; score: number }[];
}

function buildMatcher(materias: MateriaRow[]) {
    const byCodigo = new Map<string, MateriaRow>();
    const normalizedNomes = materias.map((m) => normText(m.nome_materia));
    const normalizedDepts = materias.map((m) => (m.departamento ? normalizeDepartamento(m.departamento) : ""));
    const nomeBigrams = normalizedNomes.map((n) => bigrams(n));
    const nomeBigramTotals = nomeBigrams.map((bg) => bigramTotal(bg));
    for (const m of materias) byCodigo.set(normText(m.codigo_materia), m);

    return function match(disciplinaRaw: string, departamentoRaw: string): MatchResult {
        const disciplina = disciplinaRaw.trim();
        const asCodigo = normText(disciplina).replace(/\s+/g, "");
        if (CODIGO_MATERIA_REGEX.test(asCodigo)) {
            const hit = byCodigo.get(asCodigo);
            if (hit) return { id_materia: hit.id_materia, method: "codigo_exato", confidence: 1 };
        }

        // Muitas linhas trazem o código embutido no meio do texto livre, ex.:
        // "Engenharia de Software (CIC0105)" ou "Comportamento Organizacional - ADM0231".
        const embeddedCodeMatches = normText(disciplina).match(/[A-Z]{2,4}\d{3,4}/g);
        if (embeddedCodeMatches) {
            for (const candidate of embeddedCodeMatches) {
                const hit = byCodigo.get(candidate);
                if (hit) return { id_materia: hit.id_materia, method: "codigo_exato", confidence: 1 };
            }
        }

        const nomeNorm = normText(disciplina);
        const nomeBg = bigrams(nomeNorm);
        const nomeBgTotal = bigramTotal(nomeBg);
        const deptNorm = departamentoRaw ? normalizeDepartamento(departamentoRaw) : "";
        const deptTokens = deptNorm.split(" ").filter((t) => t.length >= 4);

        const scored = materias.map((m, idx) => {
            let score = diceCoefficientPrecomputed(nomeBg, nomeBgTotal, nomeBigrams[idx], nomeBigramTotals[idx]);
            if (deptTokens.length > 0 && normalizedDepts[idx]) {
                const overlap = deptTokens.some((t) => normalizedDepts[idx].includes(t));
                if (overlap) score += 0.15;
            }
            return { m, score };
        });
        scored.sort((a, b) => b.score - a.score);

        const top = scored[0];
        // Materias tem várias linhas por matriz/curriculo — o "segundo colocado"
        // só indica ambiguidade real se for uma disciplina DIFERENTE do topo.
        // Duplicatas com o mesmo nome_materia não contam contra a confiança do match.
        const topNomeNorm = normText(top.m.nome_materia);
        const distinctRunnerUp = scored.find((s) => normText(s.m.nome_materia) !== topNomeNorm);
        const margin = distinctRunnerUp ? top.score - distinctRunnerUp.score : 1;

        const alternativas = scored.slice(0, 5).map((s) => ({
            id_materia: s.m.id_materia,
            nome_materia: s.m.nome_materia,
            score: Math.round(s.score * 1000) / 1000,
        }));

        // Nome normalizado idêntico (score ~1, sem o bônus de departamento) é uma
        // correspondência exata de texto — aceitar sempre, mesmo se outra disciplina
        // parecida (ex.: "X" vs "X 2") também tiver score alto por pura semelhança
        // de bigrama. Margem só importa quando o próprio top não é uma igualdade exata.
        const exactTextMatch = topNomeNorm === nomeNorm;

        if (top.score >= 0.55 && (exactTextMatch || margin >= 0.06)) {
            return { id_materia: top.m.id_materia, method: "nome_fuzzy", confidence: top.score, alternativas };
        }

        return { id_materia: null, method: "sem_match", confidence: top?.score || 0, alternativas };
    };
}

// =============================================================================
// Main
// =============================================================================

interface Header {
    carimbo: number;
    campus: number;
    disciplina: number;
    modalidade: number;
    semestre: number;
    departamento: number;
    professor: number;
    didatica: number;
    dificuldade: number;
    carga: number;
    material: number;
    recomendaria: number;
    feedback: number;
    metodoAvaliacao: number;
    comoFoi: number;
}

function findHeaderIndex(header: string[], needle: string): number {
    const idx = header.findIndex((h) => stripAccents(h.toLowerCase()).includes(stripAccents(needle.toLowerCase())));
    if (idx === -1) throw new Error(`Coluna não encontrada no CSV: "${needle}"`);
    return idx;
}

async function main() {
    const { csvPath, write, outDir } = parseArgs(process.argv.slice(2));
    if (!csvPath) {
        console.error("Uso: npx tsx scripts/import_avaliacoes_disciplinas.ts <caminho-csv> [--write] [--out <dir>]");
        process.exit(1);
    }
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

    console.log(`📄 Lendo CSV: ${csvPath}`);
    const content = fs.readFileSync(csvPath, "utf8");
    const rows = parseCsv(content);
    const header = rows[0];
    const data = rows.slice(1);
    console.log(`   ${data.length} linhas de dados, ${header.length} colunas`);

    const h: Header = {
        carimbo: findHeaderIndex(header, "carimbo"),
        campus: findHeaderIndex(header, "campus"),
        disciplina: findHeaderIndex(header, "ou codigo"),
        modalidade: findHeaderIndex(header, "modalidade"),
        semestre: findHeaderIndex(header, "semestre"),
        departamento: findHeaderIndex(header, "departamento"),
        professor: findHeaderIndex(header, "professor"),
        didatica: findHeaderIndex(header, "didatica"),
        dificuldade: findHeaderIndex(header, "dificuldade"),
        carga: findHeaderIndex(header, "carga de atividades"),
        material: findHeaderIndex(header, "material dispon"),
        recomendaria: findHeaderIndex(header, "recomendaria"),
        feedback: findHeaderIndex(header, "feedback sincero"),
        metodoAvaliacao: findHeaderIndex(header, "metodo de avaliacao"),
        comoFoi: findHeaderIndex(header, "como foi"),
    };

    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
        console.error("❌ Faltam credenciais do Supabase (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
        process.exit(1);
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    console.log("🔌 Carregando materias (id_materia, codigo_materia, nome_materia, departamento)...");
    const materias: MateriaRow[] = [];
    {
        let from = 0;
        const pageSize = 1000;
        while (true) {
            const { data: page, error } = await supabase
                .from("materias")
                .select("id_materia,codigo_materia,nome_materia,departamento")
                .range(from, from + pageSize - 1);
            if (error) throw error;
            if (!page || page.length === 0) break;
            materias.push(...(page as MateriaRow[]));
            from += pageSize;
            if (page.length < pageSize) break;
        }
    }
    console.log(`   ${materias.length} matérias carregadas`);

    const match = buildMatcher(materias);

    type ImportRow = {
        id_materia: number | null;
        semestre: string | null;
        campus: string;
        modalidade: string;
        dificuldade: number | null;
        carga_atividades: number | null;
        material_disponibilizado: string | null;
        recomendaria: string | null;
        metodo_avaliacao: string;
        feedback_texto: string;
        fonte: string;
        raw_row_hash: string;
    };

    const resolved: ImportRow[] = [];
    const naoResolvidas: any[] = [];
    const ambiguas: any[] = [];
    const amostraRedacao: any[] = [];
    let redigidas = 0;

    for (const row of data) {
        const disciplinaRaw = row[h.disciplina] ?? "";
        const departamentoRaw = row[h.departamento] ?? "";
        const professorRaw = row[h.professor] ?? "";

        const m = match(disciplinaRaw, departamentoRaw);
        // Confiança entre 0.55 e 0.75 (fuzzy, não exata) fica de fora do import:
        // é "melhor palpite" bom o bastante pra revisão manual, mas arriscado
        // demais pra entrar direto nos agregados de dificuldade/recomendação.
        const idMateriaResolvido = m.method === "sem_match" || (m.method === "nome_fuzzy" && m.confidence < 0.75) ? null : m.id_materia;

        const tokensNome = extrairTokensNome(professorRaw);
        let feedback = row[h.feedback] ?? "";
        let comoFoi = row[h.comoFoi] ?? "";
        let metodoAvaliacao = row[h.metodoAvaliacao] ?? "";
        if (tokensNome.length > 0) {
            const antesFeedback = feedback;
            const antesComoFoi = comoFoi;
            feedback = redigirTexto(feedback, tokensNome);
            comoFoi = redigirTexto(comoFoi, tokensNome);
            metodoAvaliacao = redigirTexto(metodoAvaliacao, tokensNome);
            if (antesFeedback !== feedback || antesComoFoi !== comoFoi) {
                redigidas++;
                if (amostraRedacao.length < 30) {
                    amostraRedacao.push({
                        tokensNome,
                        antes: [antesFeedback, antesComoFoi].filter(Boolean).join(" | "),
                        depois: [feedback, comoFoi].filter(Boolean).join(" | "),
                    });
                }
            }
        }
        const feedbackFinal = [feedback, comoFoi].filter(Boolean).join(" | ");

        const rawRowHash = crypto.createHash("sha256").update(JSON.stringify(row)).digest("hex");

        const importRow: ImportRow = {
            id_materia: idMateriaResolvido,
            semestre: normalizeSemestre(row[h.semestre] ?? ""),
            campus: (row[h.campus] ?? "").replace(/^Campus\s+/i, "").trim(),
            modalidade: (row[h.modalidade] ?? "").replace(/^[^\p{L}]+/u, "").trim(),
            dificuldade: canonDificuldade(row[h.dificuldade] ?? ""),
            carga_atividades: canonCarga(row[h.carga] ?? ""),
            material_disponibilizado: canonMaterial(row[h.material] ?? ""),
            recomendaria: canonRecomendaria(row[h.recomendaria] ?? ""),
            metodo_avaliacao: metodoAvaliacao,
            feedback_texto: feedbackFinal,
            fonte: "formulario_2025",
            raw_row_hash: rawRowHash,
        };

        if (m.method === "sem_match") {
            naoResolvidas.push({
                disciplina: disciplinaRaw,
                departamento: departamentoRaw,
                melhorScore: m.confidence,
                alternativas: m.alternativas,
            });
        } else if (m.method === "nome_fuzzy" && m.confidence < 0.75) {
            // Fica de fora do import (id_materia=null acima); reportado aqui como
            // sugestão para revisão manual, com o candidato que o script cogitou.
            ambiguas.push({
                disciplina: disciplinaRaw,
                departamento: departamentoRaw,
                sugestao: materias.find((mm) => mm.id_materia === m.id_materia)?.nome_materia,
                score: m.confidence,
                alternativas: m.alternativas,
            });
        }

        resolved.push(importRow);
    }

    const nComCodigo = resolved.filter((r, i) => r.id_materia !== null).length;
    const nSemMatch = naoResolvidas.length;

    console.log("");
    console.log("═══════════════════════════════════════════════");
    console.log("📊 RESUMO DO IMPORT");
    console.log("═══════════════════════════════════════════════");
    console.log(`   Total de linhas:        ${data.length}`);
    console.log(`   Resolvidas p/ materia:  ${nComCodigo} (${((nComCodigo / data.length) * 100).toFixed(1)}%)`);
    console.log(`   Sem match (revisão):    ${nSemMatch} (${((nSemMatch / data.length) * 100).toFixed(1)}%)`);
    console.log(`   Matches ambíguos, fora do import (<0.75 confiança): ${ambiguas.length}`);
    console.log(`   Linhas com redação de nome aplicada: ${redigidas}`);
    console.log("═══════════════════════════════════════════════");

    fs.writeFileSync(path.join(outDir, "nao_resolvidas.json"), JSON.stringify(naoResolvidas, null, 2), "utf8");
    fs.writeFileSync(path.join(outDir, "ambiguas.json"), JSON.stringify(ambiguas, null, 2), "utf8");
    fs.writeFileSync(path.join(outDir, "amostra_redacao.json"), JSON.stringify(amostraRedacao, null, 2), "utf8");
    console.log(`📝 Relatórios gravados em: ${outDir}`);

    if (!write) {
        console.log("");
        console.log("ℹ️  Dry-run (sem --write). Nenhuma linha foi inserida no banco.");
        return;
    }

    console.log("");
    console.log("💾 Inserindo em avaliacoes_disciplinas (upsert por raw_row_hash)...");
    const BATCH = 200;
    let inserted = 0;
    for (let i = 0; i < resolved.length; i += BATCH) {
        const batch = resolved.slice(i, i + BATCH);
        const { error } = await supabase.from("avaliacoes_disciplinas").upsert(batch, { onConflict: "raw_row_hash" });
        if (error) {
            console.error(`❌ Erro no batch ${i}-${i + batch.length}:`, error.message);
            throw error;
        }
        inserted += batch.length;
        process.stdout.write(`\r   ${inserted}/${resolved.length}`);
    }
    console.log("");
    console.log("✅ Import concluído.");

    await backfillDificuldadeParaRecalculo(supabase);
}

/**
 * PlanejamentoController só recalcula dificuldade_estimada quando ela está NULL
 * (lazy loading). Sem isso, matérias que já tinham um chute antigo da LLM nunca
 * seriam reavaliadas com o dado real que acabou de entrar no import. Aqui a
 * gente reseta dificuldade_estimada/dificuldade_fonte para as matérias que agora
 * têm pelo menos 1 avaliação real e ainda não estão marcadas como 'real' —
 * na próxima geração de plano, DificuldadeAgenteService recalcula com o dado novo.
 * Idempotente: seguro rodar de novo em imports futuros.
 */
async function backfillDificuldadeParaRecalculo(supabase: ReturnType<typeof createClient>) {
    console.log("");
    console.log("🔄 Backfill: resetando dificuldade_estimada de matérias com dado real novo...");

    const idsComAvaliacaoReal = new Set<number>();
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
            for (const row of data as { id_materia: number }[]) idsComAvaliacaoReal.add(row.id_materia);
            from += pageSize;
            if (data.length < pageSize) break;
        }
    }

    if (idsComAvaliacaoReal.size === 0) {
        console.log("   Nenhuma matéria com avaliação real encontrada — nada a resetar.");
        return;
    }

    const idsParaResetar: number[] = [];
    const idsArray = [...idsComAvaliacaoReal];
    const BATCH = 200;
    for (let i = 0; i < idsArray.length; i += BATCH) {
        const batch = idsArray.slice(i, i + BATCH);
        const { data, error } = await supabase
            .from("materias")
            .select("id_materia")
            .in("id_materia", batch)
            .or("dificuldade_fonte.is.null,dificuldade_fonte.neq.real");
        if (error) throw error;
        for (const row of (data as { id_materia: number }[]) || []) idsParaResetar.push(row.id_materia);
    }

    if (idsParaResetar.length === 0) {
        console.log("   Todas as matérias com dado real já estão marcadas como 'real' — nada a resetar.");
        return;
    }

    let resetadas = 0;
    for (let i = 0; i < idsParaResetar.length; i += BATCH) {
        const batch = idsParaResetar.slice(i, i + BATCH);
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
    }
    console.log(`   ${resetadas} matéria(s) resetada(s) para recálculo (dificuldade_fonte='real'/'hibrido' na próxima geração de plano).`);
}

main().catch((err) => {
    console.error("❌ Falha no import:", err);
    process.exit(1);
});
