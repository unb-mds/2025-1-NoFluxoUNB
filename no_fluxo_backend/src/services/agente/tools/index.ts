/**
 * Montagem do registry padrão de tools do agente.
 *
 * A ordem de registro é a mesma da lista inline original (mantém a apresentação
 * das tools ao LLM idêntica): as 2 genéricas primeiro, depois as 5 de plano.
 */

import { ToolRegistry } from "../tool_registry";
import {
    consultarInformacoesMateriaTool,
    consultarTurmasMateriaTool,
    buscarMateriasUnbTool,
} from "./materia_tools";
import {
    consultarPlanoTool,
    simularCenarioTool,
    ajustarCargaTool,
    ajustarCargaSemestreTool,
    moverMateriaTool,
} from "./plano_tools";
import {
    consultarHistoricoAlunoTool,
    consultarStatusMateriaTool,
} from "./aluno_tools";

export function createDefaultRegistry(): ToolRegistry {
    return new ToolRegistry()
        .register(consultarInformacoesMateriaTool)
        .register(consultarTurmasMateriaTool)
        .register(buscarMateriasUnbTool)
        .register(consultarHistoricoAlunoTool)
        .register(consultarStatusMateriaTool)
        .register(consultarPlanoTool)
        .register(simularCenarioTool)
        .register(ajustarCargaTool)
        .register(ajustarCargaSemestreTool)
        .register(moverMateriaTool);
}

/** Registry singleton compartilhado pelos dois chats. */
export const defaultRegistry = createDefaultRegistry();
