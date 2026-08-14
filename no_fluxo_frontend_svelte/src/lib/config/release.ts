/**
 * Versão do "pacote de novidades" e do schema do fluxograma persistido.
 *
 * Como usar num release novo:
 * 1. Incremente RELEASE_ID (qualquer string nova reabre o modal 1x por usuário).
 * 2. Atualize RELEASE_NOVIDADES com o que mudou, na voz do usuário.
 * 3. Incremente FLUXOGRAMA_SCHEMA_VERSION SOMENTE se o dado salvo pelo upload
 *    ganhou informação nova (aí o modal pede reenvio do histórico para quem
 *    tem dado de versão anterior).
 */

/** Identificador deste release — mudar reabre o modal de novidades. */
export const RELEASE_ID = '2026-08.1';

/**
 * Versão do schema do fluxograma_atual salvo no upload.
 * v1: uploads antigos (sem o campo schema_version).
 * v2: equivalências do próprio histórico injetadas + módulo livre/extras.
 */
export const FLUXOGRAMA_SCHEMA_VERSION = 2;

export const RELEASE_TITULO = 'Novidades no NoFluxo';

export const RELEASE_NOVIDADES: string[] = [
	'Módulo livre e eletivas do seu histórico agora aparecem no fluxograma, com etiqueta própria',
	'Equivalências reconhecidas — inclusive as declaradas no próprio histórico — com a etiqueta "equiv."',
	'O Plano de Formatura mostra o % de integralização a cada semestre e avisa quando faltam horas de optativas',
	'O Darcy AI sugere optativas pelos seus interesses e adiciona (ou remove) direto no plano',
	'Chat repaginado: nomes das matérias no lugar dos códigos, respostas com digitação e janela maior'
];
