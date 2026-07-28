/**
 * Controle de exibição do tour "novidades" (ex.: alerta de vaga) — uma vez por
 * usuário, persistido em localStorage no mesmo padrão de grade.store.svelte.ts.
 */

const VAGA_TOUR_VERSION = 'v1';

function vagaTourKey(idUser: number | null): string | null {
	return idUser != null ? `nofluxo:novidades:${idUser}:vaga-tour-${VAGA_TOUR_VERSION}` : null;
}

function createNovidadesStore() {
	return {
		shouldShowVagaTour(idUser: number | null): boolean {
			const key = vagaTourKey(idUser);
			if (!key || typeof localStorage === 'undefined') return false;
			try {
				return localStorage.getItem(key) === null;
			} catch {
				return false;
			}
		},

		dismissVagaTour(idUser: number | null): void {
			const key = vagaTourKey(idUser);
			if (!key || typeof localStorage === 'undefined') return;
			try {
				localStorage.setItem(key, 'visto');
			} catch {
				// Sem localStorage disponível — tour pode reaparecer, sem problema.
			}
		}
	};
}

export const novidadesStore = createNovidadesStore();
