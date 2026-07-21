/**
 * Assinaturas de vaga (runes) — compartilhado pelo Montador de Grade.
 * Carrega a lista uma vez e expõe seguir/deixar de seguir por turma, reusando o
 * vagaNotificacaoService (mesma infra do TurmasVagasPanel/NotificationsMenu).
 */
import { vagaNotificacaoService } from '$lib/services/vaga-notificacao.service';
import type { VagaAssinatura } from '$lib/types/notificacao';

function createVagaAssinaturasStore() {
	let assinaturas = $state<VagaAssinatura[]>([]);
	let carregado = $state(false);
	let busyKey = $state<string | null>(null);

	function key(idMateria: number, turma: string | null, anoPeriodo: string): string {
		return `${idMateria}::${turma ?? '__toda__'}::${anoPeriodo}`;
	}

	function encontrar(
		idMateria: number,
		turma: string | null,
		anoPeriodo: string
	): VagaAssinatura | null {
		return (
			assinaturas.find(
				(a) =>
					a.ativa &&
					a.id_materia === idMateria &&
					(a.turma ?? null) === turma &&
					a.ano_periodo === anoPeriodo
			) ?? null
		);
	}

	return {
		get carregado() {
			return carregado;
		},

		async load(): Promise<void> {
			try {
				assinaturas = await vagaNotificacaoService.listarMinhasAssinaturas();
				carregado = true;
			} catch {
				// Sem login/erro → segue sem assinaturas; botões ficam ocultos.
				assinaturas = [];
				carregado = false;
			}
		},

		isSeguindo(idMateria: number, turma: string | null, anoPeriodo: string): boolean {
			return encontrar(idMateria, turma, anoPeriodo) !== null;
		},

		isBusy(idMateria: number, turma: string | null, anoPeriodo: string): boolean {
			return busyKey === key(idMateria, turma, anoPeriodo);
		},

		async toggle(idMateria: number, turma: string | null, anoPeriodo: string): Promise<void> {
			const k = key(idMateria, turma, anoPeriodo);
			if (busyKey) return;
			busyKey = k;
			try {
				const existente = encontrar(idMateria, turma, anoPeriodo);
				if (existente) {
					await vagaNotificacaoService.deixarDeSeguir(existente.id_assinatura);
				} else {
					await vagaNotificacaoService.seguirMateria(idMateria, turma, anoPeriodo);
				}
				assinaturas = await vagaNotificacaoService.listarMinhasAssinaturas();
			} catch {
				// Falha silenciosa — o estado visual simplesmente não muda.
			} finally {
				busyKey = null;
			}
		}
	};
}

export const vagaAssinaturasStore = createVagaAssinaturasStore();
