// Contador global de mensagens de suporte não lidas (badge no avatar/menu).
// O polling é iniciado uma única vez pelo AccountMenu; o resto do app só lê o store.
import { writable } from 'svelte/store';
import { ticketService } from '$lib/services/ticket.service';

export const ticketsNaoLidas = writable(0);

let timer: ReturnType<typeof setInterval> | null = null;

/** Re-consulta o total de não lidas (silencioso: sem sessão → mantém o valor). */
export async function atualizarTicketsNaoLidas(): Promise<void> {
	try {
		ticketsNaoLidas.set(await ticketService.countUnreadTickets());
	} catch {
		// sem sessão Supabase (anônimo/deslogado) ou rede — badge fica como está
	}
}

export function iniciarPollingTicketsNaoLidas(intervalMs = 60_000): void {
	pararPollingTicketsNaoLidas();
	void atualizarTicketsNaoLidas();
	timer = setInterval(() => void atualizarTicketsNaoLidas(), intervalMs);
}

export function pararPollingTicketsNaoLidas(): void {
	if (timer !== null) {
		clearInterval(timer);
		timer = null;
	}
}
