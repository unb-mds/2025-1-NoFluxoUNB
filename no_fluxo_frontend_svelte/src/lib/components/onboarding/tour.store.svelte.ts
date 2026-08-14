/**
 * Estado do onboarding guiado (coach marks).
 *
 * Fica fora do componente porque o tour é aberto de vários lugares: sozinho na
 * primeira visita, pelo botão "Como funciona" do cabeçalho e pelo menu de ajuda.
 */

export interface TourStep {
	/** Valor de `data-tour` do elemento destacado. Sem alvo = card centralizado. */
	target?: string;
	title: string;
	description: string;
	/** Dica extra, em tom mais leve (aparece com marcador). */
	hint?: string;
	/** Lado preferido do card em relação ao alvo. */
	side?: 'top' | 'bottom' | 'left' | 'right';
	/** Espaço extra no recorte do spotlight (px). */
	padding?: number;
}

function chaveStorage(id: string): string {
	return `nofluxo:tour:${id}`;
}

/**
 * Já concluiu/pulou este tour antes? Storage bloqueado (aba anônima, Safari
 * restrito) conta como "não" — melhor repetir o tour a cada visita do que
 * nunca mostrá-lo para quem mais precisa. `startSeNovo` só roda no browser,
 * então retornar false sem localStorage não afeta SSR.
 */
export function tourConcluido(id: string): boolean {
	if (typeof localStorage === 'undefined') return false;
	try {
		return localStorage.getItem(chaveStorage(id)) === 'done';
	} catch {
		return false;
	}
}

function marcarConcluido(id: string): void {
	if (typeof localStorage === 'undefined') return;
	try {
		localStorage.setItem(chaveStorage(id), 'done');
	} catch {
		/* modo privado / storage cheio: o tour só volta a aparecer na próxima visita */
	}
}

class TourStore {
	id = $state<string | null>(null);
	steps = $state<TourStep[]>([]);
	index = $state(0);

	readonly aberto = $derived(this.id !== null);
	readonly stepAtual = $derived<TourStep | null>(this.steps[this.index] ?? null);
	readonly total = $derived(this.steps.length);
	readonly isPrimeiro = $derived(this.index === 0);
	readonly isUltimo = $derived(this.index >= this.steps.length - 1);

	start(id: string, steps: TourStep[], fromStep = 0): void {
		if (steps.length === 0) return;
		this.id = id;
		this.steps = steps;
		this.index = Math.min(Math.max(fromStep, 0), steps.length - 1);
	}

	/** Abre só se o usuário ainda não viu — usado no primeiro acesso à página. */
	startSeNovo(id: string, steps: TourStep[]): void {
		if (tourConcluido(id)) return;
		this.start(id, steps);
	}

	proximo(): void {
		if (this.isUltimo) {
			this.concluir();
			return;
		}
		this.index += 1;
	}

	anterior(): void {
		if (this.index > 0) this.index -= 1;
	}

	irPara(index: number): void {
		if (index < 0 || index >= this.steps.length) return;
		this.index = index;
	}

	/**
	 * Fecha marcando como visto — só para saídas explícitas ("Entendi!" e
	 * "Pular"). Dispensas acidentais (clique fora, X, Esc) usam fechar(), que
	 * não persiste: o tour volta a se oferecer na próxima visita.
	 */
	concluir(): void {
		if (this.id) marcarConcluido(this.id);
		this.fechar();
	}

	fechar(): void {
		this.id = null;
		this.steps = [];
		this.index = 0;
	}
}

export const tourStore = new TourStore();
