import { SupabaseWrapper } from "../supabase_wrapper";
import { createControllerLogger } from "../utils/controller_logger";
import { MARITACA_URL, MARITACA_MODELS } from "../config/maritaca";
import type { MateriaInput } from "../types/planejamento";

const logger = createControllerLogger("DificuldadeAgenteService", "avaliar");

/**
 * Serviço responsável por chamar a LLM para preencher a dificuldade estimada
 * de disciplinas que ainda não possuem esse dado no banco (Lazy Loading).
 */
export class DificuldadeAgenteService {
    /**
     * Avalia a dificuldade de uma lista de matérias via LLM e salva no Supabase.
     * Atualiza o array original de matérias em memória com os resultados.
     */
    static async avaliarESalvarDificuldades(materiasFaltantes: MateriaInput[]): Promise<void> {
        if (!materiasFaltantes || materiasFaltantes.length === 0) return;

        const apiKey = process.env.MARITACA_API_KEY;
        if (!apiKey) {
            logger.warn("MARITACA_API_KEY não configurada. Pulando avaliação de dificuldade.");
            return;
        }

        // Separar matérias que valem a pena avaliar (tem nome) das que não têm (nome == codigo)
        const materiasParaAvaliar = materiasFaltantes.filter(m => m.nome && m.nome !== m.codigo);
        const materiasParaIgnorar = materiasFaltantes.filter(m => !m.nome || m.nome === m.codigo);

        const supabase = SupabaseWrapper.get();
        const updatePromises: any[] = [];

        // Já resolvemos as ignoradas com valor padrão para não gastar tokens em requisições futuras
        for (const materia of materiasParaIgnorar) {
            materia.dificuldadeEstimada = 4;
            materia.motivoDificuldade = "Nome e ementa indisponíveis no banco de dados. Avaliação automática ignorada.";
            
            updatePromises.push(
                supabase
                    .from("materias")
                    .update({
                        dificuldade_estimada: 4,
                        motivo_dificuldade: materia.motivoDificuldade,
                        dificuldade_calculada_em: new Date().toISOString(),
                    })
                    .eq("codigo_materia", materia.codigo)
            );
        }

        if (materiasParaAvaliar.length === 0) {
            logger.info("Nenhuma matéria válida para avaliar com a LLM. Todas foram ignoradas por falta de nome.");
            await Promise.all(updatePromises);
            return;
        }

        logger.info(`Iniciando avaliação de dificuldade para ${materiasParaAvaliar.length} matérias válidas (ignorando ${materiasParaIgnorar.length} sem nome)...`);

        // Processar em chunks menores para evitar erros de formatação JSON e limite de tokens
        const CHUNK_SIZE = 15;
        const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

        for (let i = 0; i < materiasParaAvaliar.length; i += CHUNK_SIZE) {
            if (i > 0) {
                logger.info("Aguardando 2s para respeitar o Rate Limit da API...");
                await delay(2000);
            }

            const chunk = materiasParaAvaliar.slice(i, i + CHUNK_SIZE);
            
            logger.info(`Avaliant chunk ${Math.floor(i / CHUNK_SIZE) + 1} de ${Math.ceil(materiasParaAvaliar.length / CHUNK_SIZE)}...`);
            
            const listaMaterias = chunk
                .map((m) => `- Código: ${m.codigo} | Nome: ${m.nome} ${m.departamento ? `| Departamento: ${m.departamento}` : ""}`)
                .join("\n");

            const prompt = `Você é um conselheiro acadêmico especialista nos currículos e matérias da Universidade de Brasília (UnB).
Sua tarefa é estimar a Dificuldade e Carga de Trabalho das matérias abaixo, atribuindo uma nota de 1 a 10 para cada uma.
- Nota 1-3: Matérias muito fáceis, geralmente introdutórias ou teóricas leves.
- Nota 4-6: Matérias de dificuldade média (ex: optativas comuns, introdução a programação).
- Nota 7-8: Matérias difíceis que reprovam consideravelmente e exigem muito estudo (ex: Física 1, Estrutura de Dados, Anatomia).
- Nota 9-10: Matérias notórias pelo alto índice de reprovação e carga pesada (ex: Cálculo 2, Cálculo 3, Mecânica dos Fluidos, Sinais e Sistemas).

Você deve basear sua avaliação no nome da disciplina, departamento, e no conhecimento público do histórico dessas matérias na UnB.

REGRAS OBRIGATÓRIAS DE FORMATAÇÃO:
1. Você NÃO PODE usar o formato JSON. Retorne EXCLUSIVAMENTE texto puro.
2. Você DEVE usar o formato de uma linha por matéria, separados por barra vertical (pipe) "|".
3. Formato exato: CODIGO|NOTA|MOTIVO
4. Não use nenhum cabeçalho, introdução, conclusão, aspas ou blocos de código markdown.
5. O texto do MOTIVO deve ser EXTREMAMENTE CURTO. Use no máximo 10 palavras por matéria. Seja super direto.

Exemplo de saída esperada:
MAT0026|9|Reprova muito devido a alta abstracao matematica.
CIC0004|5|Materia introdutoria basica de programacao.

Avalie as seguintes matérias:
${listaMaterias}`;

            try {
                const response = await fetch(MARITACA_URL, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        Authorization: `Key ${apiKey}`,
                    },
                    body: JSON.stringify({
                        model: MARITACA_MODELS.CLASSIFICACAO,
                        messages: [{ role: "user", content: prompt }],
                        temperature: 0.2, // Baixa temperatura para formato estrito e previsível
                        max_tokens: 1024 // Limite mais baixo para não reservar tokens da cota de rate limit
                    }),
                });

                if (!response.ok) {
                    const err = await response.text();
                    throw new Error(`Maritaca API error: ${response.status} ${err}`);
                }

                const data = (await response.json()) as any;
                let content = data.choices?.[0]?.message?.content || "";
                
                // Limpeza e Parse do formato CODIGO|NOTA|MOTIVO
                content = content.replace(/```[a-zA-Z]*\n?/g, "").replace(/```/g, "").trim();
                const linhas = content.split("\n");
                const resultados: Record<string, {nota: number, motivo: string}> = {};

                for (const linha of linhas) {
                    const partes = linha.split("|");
                    if (partes.length >= 3) {
                        const codigo = partes[0].trim();
                        const notaNum = parseInt(partes[1].trim(), 10);
                        const motivoText = partes.slice(2).join("|").trim();
                        
                        if (!isNaN(notaNum)) {
                            resultados[codigo] = { nota: notaNum, motivo: motivoText };
                        }
                    }
                }

                // Processar resultados para o chunk atual
                for (const materia of chunk) {
                    const avaliacao = resultados[materia.codigo];
                    if (avaliacao && typeof avaliacao.nota === "number") {
                        const notaSegura = Math.max(1, Math.min(10, Math.floor(avaliacao.nota)));
                        const motivoStr = String(avaliacao.motivo || "").trim();

                        materia.dificuldadeEstimada = notaSegura;
                        materia.motivoDificuldade = motivoStr;

                        updatePromises.push(
                            supabase
                                .from("materias")
                                .update({
                                    dificuldade_estimada: notaSegura,
                                    motivo_dificuldade: motivoStr,
                                    dificuldade_calculada_em: new Date().toISOString(),
                                })
                                .eq("codigo_materia", materia.codigo)
                        );
                    } else {
                        materia.dificuldadeEstimada = 4;
                        materia.motivoDificuldade = "Dificuldade padrão assumida";
                    }
                }
            } catch (error: any) {
                logger.error(`Erro ao avaliar chunk da LLM: ${error.message}`);
                // Fallback apenas para as matérias deste chunk
                for (const m of chunk) {
                    m.dificuldadeEstimada = 4;
                    m.motivoDificuldade = "Erro na IA";
                }
            }
        }
        
        await Promise.all(updatePromises);
        logger.info("Avaliação de dificuldade concluída e salva no banco.");
    }
}
