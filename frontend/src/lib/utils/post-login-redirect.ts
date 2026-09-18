import { ROUTES } from '$lib/config/routes';

/**
 * Escolhe o destino pós-login: honra um redirect explícito (?redirect=/?next=) se for um
 * caminho interno seguro; senão manda quem já tem fluxograma salvo direto para o fluxograma
 * em vez de repetir a tela de upload de histórico.
 */
export function resolvePostLoginRedirect(candidatePath: string, hasFluxograma: boolean): string {
	if (
		candidatePath.startsWith('/') &&
		!candidatePath.startsWith('//') &&
		!candidatePath.includes('://')
	) {
		return candidatePath;
	}
	return hasFluxograma ? ROUTES.MEU_FLUXOGRAMA : ROUTES.UPLOAD_HISTORICO;
}
