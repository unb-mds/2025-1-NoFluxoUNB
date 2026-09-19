import { describe, it, expect, beforeEach, vi } from 'vitest';

/**
 * A persistência do limite de carga por semestre.
 *
 * O slider do Montador mexe na MESMA preferência do plano de formatura — limite
 * de carga é um só. Mas arrastar o slider lá não pode disparar uma volta ao
 * backend a cada ajuste, nem depender do plano estar disponível: o Montador
 * funciona com o backend do plano fora, e já foi visto funcionando assim.
 *
 * Antes disto o valor vivia só na sessão da tela: o aluno ajustava a carga,
 * recarregava e encontrava os 24 créditos do padrão de volta.
 */
const salvos: Array<{ idUser: number; limiteCreditos: number }> = [];
let planosGerados = 0;
let falharAoSalvar = false;

vi.mock('$lib/services/plano-formatura.service', () => ({
	planoFormaturaService: {
		loadPreferencias: async () => ({
			limiteCreditos: 24,
			objetivo: 'equilibrio' as const,
			trabalha: false,
			onboardingConcluido: true
		}),
		savePreferencias: async (idUser: number, prefs: { limiteCreditos: number }) => {
			if (falharAoSalvar) throw new Error('banco fora');
			salvos.push({ idUser, limiteCreditos: prefs.limiteCreditos });
		},
		gerarPlano: async () => {
			planosGerados++;
			return null;
		}
	}
}));

vi.mock('$lib/stores/auth', () => ({
	authStore: {
		// O store lê o usuário pela subscrição, não por `getUser` — entrega o estado
		// na hora da inscrição, como um store svelte de verdade faz.
		subscribe: (fn: (v: unknown) => void) => {
			fn({
				user: { idUser: 7 },
				isAuthenticated: true,
				isAnonymous: false,
				isLoading: false,
				error: null
			});
			return () => {};
		},
		getUser: () => ({ idUser: 7 })
	}
}));

vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: {
		get state() {
			return { courseData: null };
		},
		get completedCodes() {
			return new Set<string>();
		}
	}
}));

const { planoFormaturaStore } = await import('./plano-formatura.store.svelte');

beforeEach(async () => {
	salvos.length = 0;
	planosGerados = 0;
	falharAoSalvar = false;
	await planoFormaturaStore.loadPreferencias();
});

describe('salvarLimiteCreditos', () => {
	it('grava a escolha do aluno', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(28);

		expect(planoFormaturaStore.preferencias.limiteCreditos).toBe(28);
		expect(salvos).toEqual([{ idUser: 7, limiteCreditos: 28 }]);
	});

	/**
	 * O slider do Montador chama isto a cada ajuste. Regenerar o plano de formatura
	 * junto seria uma volta ao backend por arraste — e o Montador precisa continuar
	 * montando mesmo quando esse backend não responde.
	 */
	it('não regenera o plano de formatura', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(28);

		expect(planosGerados).toBe(0);
	});

	it('ignora quando o valor não mudou, sem ir ao banco à toa', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(24);

		expect(salvos).toEqual([]);
	});

	/**
	 * Falha de gravação não pode atrapalhar a montagem: a escolha vale nesta sessão
	 * de qualquer forma, e o aluno só a refaz numa próxima visita.
	 */
	it('mantém o valor na sessão mesmo se o banco falhar', async () => {
		falharAoSalvar = true;

		await expect(planoFormaturaStore.salvarLimiteCreditos(30)).resolves.toBeUndefined();
		expect(planoFormaturaStore.preferencias.limiteCreditos).toBe(30);
	});

	/**
	 * O valor salvo aqui abre a próxima visita ao Montador. Um zero persistido
	 * deixaria o aluno sem nenhuma matéria semeada e sem pista do porquê — para
	 * esvaziar a grade existe o botão "Limpar", que não mexe na preferência.
	 */
	it('não deixa persistir abaixo do piso do sistema', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(0);

		expect(planoFormaturaStore.preferencias.limiteCreditos).toBe(8);
		expect(salvos).toEqual([{ idUser: 7, limiteCreditos: 8 }]);
	});

	/** 32 créditos = 480h, o mesmo teto que o Motor 2 aplica no backend. */
	it('não deixa persistir acima do teto de 480h', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(60);

		expect(planoFormaturaStore.preferencias.limiteCreditos).toBe(32);
	});

	it('aceita o teto exato', async () => {
		await planoFormaturaStore.salvarLimiteCreditos(32);

		expect(planoFormaturaStore.preferencias.limiteCreditos).toBe(32);
		expect(salvos).toEqual([{ idUser: 7, limiteCreditos: 32 }]);
	});
});
