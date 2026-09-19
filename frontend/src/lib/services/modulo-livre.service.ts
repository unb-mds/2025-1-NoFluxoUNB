/**
 * Sugestões de módulo livre por tema, para o painel "Situação" do Montador.
 *
 * Fala com `POST /planejamento/modulo-livre-sugestoes`, que usa a mesma busca
 * semântica do chat da Darcy (`SabiaService`). A busca literal por nome — que é
 * o que `searchMaterias` faz — não serve aqui: quem procura "robótica" não quer
 * só as matérias com "robótica" no título, e módulo livre é escolhido por
 * interesse, não por código.
 *
 * O servidor resolve sozinho a matriz do aluno a partir da sessão. É de
 * propósito: a matriz é justamente o que define o que NÃO é módulo livre, então
 * deixá-la vir do cliente seria deixar o cliente receber a própria obrigatória
 * de outro currículo como "matéria de fora do curso".
 */
import { apiRequest } from '$lib/utils/api';

export interface SugestaoModuloLivre {
	codigo: string;
	nome: string;
	/** Proximidade semântica com o tema, como o buscador a calculou. */
	similaridade?: number;
}

export interface RespostaModuloLivre {
	materias: SugestaoModuloLivre[];
	/** Explicação pronta para a tela quando a lista vem vazia. */
	aviso: string | null;
	/**
	 * A busca semântica não pôde ser feita (backend fora, Sabiá indisponível).
	 *
	 * Diferente de "procurei e não achei": quem chama pode tentar a busca literal
	 * do catálogo em vez de dizer ao aluno que não existe nada sobre o tema.
	 */
	falhou: boolean;
}

/**
 * Procura matérias de módulo livre sobre um tema.
 *
 * Nunca lança: a busca é um extra do painel, e derrubar a tela por causa dela
 * seria pior do que não sugerir nada. Falha vira lista vazia com aviso.
 */
export async function buscarSugestoesModuloLivre(tema: string): Promise<RespostaModuloLivre> {
	const termo = tema.trim();
	if (termo.length < 2) return { materias: [], aviso: null, falhou: false };

	const { data, error } = await apiRequest<RespostaModuloLivre>(
		'/planejamento/modulo-livre-sugestoes',
		{ method: 'POST', body: { tema: termo } }
	);

	if (error || !data) {
		return { materias: [], aviso: null, falhou: true };
	}
	return { materias: data.materias ?? [], aviso: data.aviso ?? null, falhou: false };
}
