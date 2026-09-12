/**
 * A situação de integralização do aluno, traduzida para o vocabulário do
 * Montador de Grade.
 *
 * Existe porque o montador sabia dizer "esta matéria é obrigatória" mas não
 * "faltam 480h de obrigatória e a carga optativa já está cumprida". Sem isso ele
 * recomendava optativa para quem já tinha optativa sobrando e nunca oferecia
 * módulo livre para quem ainda devia 120h dele — uma grade que parece boa e
 * gasta um semestre.
 *
 * A fonte é `getIntegralizacao`, o mesmo cálculo que o /meu-fluxograma mostra:
 * os números das duas telas têm de bater, e um segundo cálculo aqui garantiria
 * que um dia não batessem.
 */
import { getIntegralizacao } from '$lib/services/integralizacao.service';
import { authStore } from '$lib/stores/auth';
import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';

/**
 * As três cargas que a matriz exige. A matriz (e o SIGAA) chamam a terceira de
 * "complementar"; o aluno a conhece como módulo livre, e é o nome que o montador
 * usa — `docs/unb-domain.md:13` trata as duas como a mesma coisa.
 */
export type NaturezaCH = 'obrigatoria' | 'optativa' | 'modulo_livre';

export interface SituacaoAcademica {
	/**
	 * Horas que faltam por natureza.
	 *
	 * `null` é "não deu para saber", e é deliberadamente diferente de `0`: zero
	 * significa "já cumprida, pare de recomendar", e afirmar isso sem fonte faria
	 * o montador esconder do aluno a matéria que ele ainda precisa cursar.
	 */
	faltam: Record<NaturezaCH, number | null>;
	exigido: Record<NaturezaCH, number>;
	realizado: Record<NaturezaCH, number>;
	/**
	 * A matriz exige carga de módulo livre? Falso quando `ch_complementar_exigida`
	 * é 0 ou null — matriz que não exige não deve render pergunta ao aluno.
	 */
	exigeModuloLivre: boolean;
	/**
	 * A carga complementar realizada veio do PDF do SIGAA.
	 *
	 * `getGradeByMatriz` classifica cada disciplina só como obrigatória ou
	 * optativa — nunca como complementar. Então, fora do caminho do PDF, o
	 * realizado de módulo livre é sempre 0 por ausência de dado, não por medição.
	 */
	complementarConfiavel: boolean;
}

/**
 * Uma natureza já está satisfeita?
 *
 * `null` (desconhecido) e ausência de situação NUNCA saturam. É o que faz toda
 * falha desta camada degradar para o comportamento anterior do montador em vez
 * de para um pior: sem dado, ninguém é descartado.
 */
export function saturada(s: SituacaoAcademica | null, n: NaturezaCH): boolean {
	const falta = s?.faltam[n];
	return typeof falta === 'number' && falta <= 0;
}

/** Situação memoizada da sessão — ver `carregarSituacao`. */
let emVoo: Promise<SituacaoAcademica | null> | null = null;

/**
 * Situação do aluno, memoizada por sessão.
 *
 * A rota chama isto no `onMount` e o painel lê o mesmo resultado; sem a memo,
 * cada consumidor abriria a sua própria consulta de matriz e grade. Idempotente
 * e à prova de chamadas concorrentes, como `garantirContextoGrade`.
 *
 * Nunca lança: qualquer falha vira `null`, e `null` significa "monte como antes".
 */
export function carregarSituacao(): Promise<SituacaoAcademica | null> {
	if (emVoo) return emVoo;

	emVoo = (async (): Promise<SituacaoAcademica | null> => {
		const curriculoCompleto = authStore.getUser()?.dadosFluxograma?.matrizCurricular ?? null;
		if (!curriculoCompleto) {
			emVoo = null; // pode ser que a sessão ainda não tenha carregado
			return null;
		}

		try {
			const carga = fluxogramaStore.cargaHorariaIntegralizada ?? null;
			const r = await getIntegralizacao({
				curriculoCompleto,
				dadosFluxograma: authStore.getUser()?.dadosFluxograma ?? null,
				cargaHorariaIntegralizada: carga,
				equivalencias: fluxogramaStore.state.courseData?.equivalencias
			});
			if (!r) return null;

			// Mesma condição que `getIntegralizacao` usa para preferir o PDF à soma
			// das disciplinas. Fora dela, o realizado complementar é 0 por falta de
			// dado — e "0 realizado" não pode virar "faltam todas as horas".
			const complementarConfiavel =
				!!carga && (carga.total > 0 || carga.obrigatoria > 0 || carga.optativa > 0);

			return {
				faltam: {
					obrigatoria: r.faltam.chObrigatoria,
					optativa: r.faltam.chOptativa,
					modulo_livre: complementarConfiavel ? r.faltam.chComplementar : null
				},
				exigido: {
					obrigatoria: r.exigido.chObrigatoria,
					optativa: r.exigido.chOptativa,
					modulo_livre: r.exigido.chComplementar
				},
				realizado: {
					obrigatoria: r.realizado.chObrigatoria,
					optativa: r.realizado.chOptativa,
					modulo_livre: r.realizado.chComplementar
				},
				exigeModuloLivre: (r.exigido.chComplementar ?? 0) > 0,
				complementarConfiavel
			};
		} catch {
			emVoo = null; // deixa tentar de novo numa próxima navegação
			return null;
		}
	})();

	return emVoo;
}

/** Descarta a situação memoizada — usado pelos testes e ao trocar de aluno. */
export function invalidarSituacao(): void {
	emVoo = null;
}
