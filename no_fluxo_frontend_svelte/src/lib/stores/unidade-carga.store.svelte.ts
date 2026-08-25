/**
 * Unidade de Carga — preferência de exibição créditos × horas.
 *
 * O dado interno do app é sempre **créditos** (limite do plano, soma da grade,
 * créditos por matéria); esta store só muda como o número aparece na tela.
 * Padrão é **horas** porque é a linguagem do SIGAA ("matéria de 60 horas") e a
 * que os alunos reconhecem; quem prefere créditos alterna e a escolha fica
 * salva no navegador, valendo para todas as telas (plano de formatura e
 * montador de grade).
 */
import { browser } from '$app/environment';

/** Na UnB, 1 crédito = 15 horas-aula. */
export const HORAS_POR_CREDITO = 15;

export type UnidadeCarga = 'creditos' | 'horas';

const STORAGE_KEY = 'nofluxo:unidade-carga';

function inicial(): UnidadeCarga {
	if (browser) {
		const salvo = localStorage.getItem(STORAGE_KEY);
		if (salvo === 'creditos' || salvo === 'horas') return salvo;
	}
	return 'horas';
}

let unidade = $state<UnidadeCarga>(inicial());

export const unidadeCargaStore = {
	get unidade(): UnidadeCarga {
		return unidade;
	},
	set(valor: UnidadeCarga): void {
		unidade = valor;
		if (browser) localStorage.setItem(STORAGE_KEY, valor);
	},
	alternar(): void {
		this.set(unidade === 'horas' ? 'creditos' : 'horas');
	},
	/** Converte um valor em créditos para o número exibido na unidade escolhida. */
	emUnidade(creditos: number): number {
		return unidade === 'horas' ? creditos * HORAS_POR_CREDITO : creditos;
	},
	/** "60 horas" / "4 créditos" — para frases (toasts, tooltips). */
	formatar(creditos: number): string {
		if (unidade === 'horas') return `${creditos * HORAS_POR_CREDITO} horas`;
		return `${creditos} ${creditos === 1 ? 'crédito' : 'créditos'}`;
	},
	/** "60h" / "4cr" — para espaços apertados (pílulas, listas). */
	formatarCurto(creditos: number): string {
		return unidade === 'horas' ? `${creditos * HORAS_POR_CREDITO}h` : `${creditos}cr`;
	},
	/** Sufixo da unidade sozinho: "h" / "cr". */
	get sufixo(): string {
		return unidade === 'horas' ? 'h' : 'cr';
	}
};
