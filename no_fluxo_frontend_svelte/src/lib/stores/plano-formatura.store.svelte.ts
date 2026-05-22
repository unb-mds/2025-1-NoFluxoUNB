/**
 * Plano Formatura Store — Motor 2
 * Svelte 5 runes-based store for the graduation planner.
 * Wires together fluxogramaStore, authStore, and planoFormaturaService.
 */

import { authStore } from '$lib/stores/auth';
import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
import { planoFormaturaService } from '$lib/services/plano-formatura.service';
import type { PlanoFormatura, PreferenciasPlano } from '$lib/types/plano-formatura';
import { DEFAULT_PREFERENCIAS } from '$lib/types/plano-formatura';
import type { AuthState } from '$lib/types/auth';

export type PlanoFormaturaStatus = 'idle' | 'loading' | 'success' | 'error';

export interface PlanoFormaturaStoreState {
	status: PlanoFormaturaStatus;
	plano: PlanoFormatura | null;
	preferencias: PreferenciasPlano;
	/** Erro descritivo ao gerar plano, se houver. */
	error: string | null;
	/** Indica se o modal de onboarding deve estar aberto. */
	showOnboarding: boolean;
}

function createPlanoFormaturaStore() {
	// ─── State ────────────────────────────────────────────────────────────────

	let status = $state<PlanoFormaturaStatus>('idle');
	let plano = $state<PlanoFormatura | null>(null);
	let preferencias = $state<PreferenciasPlano>({ ...DEFAULT_PREFERENCIAS });
	let error = $state<string | null>(null);
	let showOnboarding = $state(false);

	// Mirror the Svelte 4 writable authStore into a $state variable so that
	// $derived expressions can reactively track auth changes.
	let authState = $state<AuthState>({
		user: null,
		isAuthenticated: false,
		isAnonymous: false,
		isLoading: true,
		error: null
	});
	authStore.subscribe((value) => {
		authState = value;
	});

	// ─── Derived ──────────────────────────────────────────────────────────────

	/** Semestres restantes conforme o plano atual. */
	const semestresRestantes = $derived(plano?.semestres_restantes ?? null);

	/** Formatura estimada conforme o plano atual. */
	const formaturaEstimada = $derived(plano?.formatura_estimada ?? null);

	/** true quando o usuário ainda não concluiu o onboarding. */
	const needsOnboarding = $derived(!preferencias.onboardingConcluido);

	// ─── Internal helpers ─────────────────────────────────────────────────────

	function getIdUser(): number | null {
		return authState.user?.idUser ?? null;
	}

	function getCurriculoCompleto(): string | null {
		return fluxogramaStore.state.courseData?.curriculoCompleto ?? null;
	}

	function getSemestreAtual(): number {
		return authState.user?.dadosFluxograma?.semestreAtual ?? 1;
	}

	function getCodigosConcluidos(): string[] {
		return [...fluxogramaStore.completedCodes];
	}

	// ─── Public API ───────────────────────────────────────────────────────────

	return {
		// Expose reactive state as getters
		get status() { return status; },
		get plano() { return plano; },
		get preferencias() { return preferencias; },
		get error() { return error; },
		get showOnboarding() { return showOnboarding; },
		get semestresRestantes() { return semestresRestantes; },
		get formaturaEstimada() { return formaturaEstimada; },
		get needsOnboarding() { return needsOnboarding; },

		/**
		 * Carrega preferências do usuário a partir do Supabase.
		 * Se não houver preferências salvas, mantém os defaults e abre o onboarding.
		 */
		async loadPreferencias(): Promise<void> {
			const idUser = getIdUser();
			if (!idUser) {
				// Usuário não autenticado — usa defaults sem abrir onboarding
				preferencias = { ...DEFAULT_PREFERENCIAS };
				return;
			}

			try {
				const prefs = await planoFormaturaService.loadPreferencias(idUser);
				preferencias = prefs;

				if (!prefs.onboardingConcluido) {
					showOnboarding = true;
				}
			} catch {
				preferencias = { ...DEFAULT_PREFERENCIAS };
				showOnboarding = true;
			}
		},

		/**
		 * Gera o plano de formatura chamando o backend (Motor 2).
		 * Atualiza status, plano e error reativamente.
		 */
		async gerar(): Promise<void> {
			const curriculoCompleto = getCurriculoCompleto();
			if (!curriculoCompleto) {
				error = 'Dados do curso não carregados. Acesse seu fluxograma primeiro.';
				status = 'error';
				return;
			}

			status = 'loading';
			error = null;

			try {
				const resultado = await planoFormaturaService.gerarPlano({
					curriculoCompleto,
					codigosConcluidos: getCodigosConcluidos(),
					semestreAtual: getSemestreAtual(),
					limiteCreditos: preferencias.limiteCreditos
				});
				plano = resultado;
				status = 'success';
			} catch (err) {
				const msg = err instanceof Error ? err.message : 'Erro ao gerar plano de formatura.';
				error = msg;
				status = 'error';
				plano = null;
			}
		},

		/**
		 * Persiste as preferências e fecha o onboarding. Em seguida, regenera o plano.
		 */
		async savePreferencias(novasPreferencias: PreferenciasPlano): Promise<void> {
			preferencias = { ...novasPreferencias, onboardingConcluido: true };
			showOnboarding = false;

			const idUser = getIdUser();
			if (idUser) {
				try {
					await planoFormaturaService.savePreferencias(idUser, preferencias);
				} catch {
					// Falha silenciosa — preferências ficam em memória
				}
			}

			// Regenera o plano com as novas preferências
			await this.gerar();
		},

		/**
		 * Atualiza apenas o limite de créditos e regenera o plano imediatamente.
		 * Usado pelos botões 16/24/32 créditos na PlanoFormaturaView.
		 */
		async setLimiteCreditos(limite: 16 | 24 | 32): Promise<void> {
			if (preferencias.limiteCreditos === limite) return;
			preferencias = { ...preferencias, limiteCreditos: limite };

			const idUser = getIdUser();
			if (idUser) {
				try {
					await planoFormaturaService.savePreferencias(idUser, preferencias);
				} catch {
					// Falha silenciosa
				}
			}

			await this.gerar();
		},

		/**
		 * Abre o modal de onboarding (ex: botão "Ajustar preferências").
		 */
		openOnboarding(): void {
			showOnboarding = true;
		},

		/**
		 * Fecha o modal de onboarding sem salvar.
		 */
		closeOnboarding(): void {
			showOnboarding = false;
		},

		/**
		 * Reseta o store para o estado inicial.
		 */
		reset(): void {
			status = 'idle';
			plano = null;
			preferencias = { ...DEFAULT_PREFERENCIAS };
			error = null;
			showOnboarding = false;
		}
	};
}

export const planoFormaturaStore = createPlanoFormaturaStore();
