/**
 * Configuração central da API da Maritaca.
 *
 * Os nomes de modelo ficam aqui porque a Maritaca descontinua versões: o
 * sabia-3 saiu do ar e quebrou dois serviços que o tinham hardcoded cada um por
 * si. Com um ponto único, a próxima troca é uma linha.
 *
 * Catálogo e status de deprecação: https://docs.maritaca.ai/pt/modelos
 */

export const MARITACA_URL = "https://chat.maritaca.ai/api/chat/completions";

export const MARITACA_MODELS = {
    /**
     * Tarefas complexas: conversa multi-turno com tool calling e web search.
     * Sucessor do sabia-3 na mesma faixa de capacidade.
     */
    AGENTE: "sabia-4",

    /**
     * Tarefas simples de alto volume: classificação com saída em formato
     * estrito. Modelo pequeno — baixo custo e boa precisão.
     */
    CLASSIFICACAO: "sabiazinho-4",
} as const;
