import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type {
	NewTicketInput,
	Ticket,
	TicketAttachment,
	TicketDetail,
	TicketListItem,
	TicketMetadata,
	TicketStatus,
	TicketCategory,
	TicketAuditEntry
} from '$lib/types/ticket';

const BUCKET = 'ticket-attachments';
const SIGNED_URL_TTL_SECONDS = 60 * 60;

export class TicketService {
	private supabase = createSupabaseBrowserClient();

	private collectMetadata(): TicketMetadata {
		if (typeof window === 'undefined') return {};
		return {
			user_agent: window.navigator.userAgent,
			platform: window.navigator.platform,
			url: window.location.href
		};
	}

	private async uploadAttachments(
		ticketId: number,
		files: File[]
	): Promise<TicketAttachment[]> {
		const { data: authData } = await this.supabase.auth.getUser();
		const authId = authData.user?.id;
		if (!authId) throw new Error('Usuário não autenticado.');

		const results: TicketAttachment[] = [];
		for (const file of files) {
			const safeName = file.name.replace(/[^\w.-]+/g, '_');
			const stamp = Date.now();
			const path = `${authId}/${ticketId}/${stamp}_${safeName}`;
			const { error } = await this.supabase.storage
				.from(BUCKET)
				.upload(path, file, { upsert: false, contentType: file.type || 'application/octet-stream' });
			if (error) throw new Error(`Falha ao enviar anexo: ${error.message}`);
			results.push({ path, name: file.name, mime: file.type, size: file.size });
		}
		return results;
	}

	async createTicket(input: NewTicketInput): Promise<Ticket> {
		const { data: authData } = await this.supabase.auth.getUser();
		const authId = authData.user?.id;
		if (!authId) throw new Error('Usuário não autenticado.');

		const { data: inserted, error: insertError } = await this.supabase
			.from('tickets')
			.insert({
				created_by: authId,
				title: input.title.trim(),
				description: input.description.trim(),
				category: input.category,
				status: 'aberto',
				metadata: this.collectMetadata(),
				attachments: []
			})
			.select('*')
			.single();

		if (insertError || !inserted) {
			throw new Error(insertError?.message || 'Erro ao criar ticket.');
		}

		const ticket = inserted as Ticket;

		if (input.attachments && input.attachments.length > 0) {
			const uploaded = await this.uploadAttachments(ticket.id, input.attachments);
			const { data: updated, error: updateError } = await this.supabase
				.from('tickets')
				.update({ attachments: uploaded })
				.eq('id', ticket.id)
				.select('*')
				.single();
			if (updateError) throw new Error(updateError.message);
			return updated as Ticket;
		}

		return ticket;
	}

	async listMyTickets(): Promise<Ticket[]> {
		const { data: authData } = await this.supabase.auth.getUser();
		const authId = authData.user?.id;
		if (!authId) return [];

		const { data, error } = await this.supabase
			.from('tickets')
			.select('*')
			.eq('created_by', authId)
			.order('created_at', { ascending: false });

		if (error) throw new Error(error.message);
		return (data ?? []) as Ticket[];
	}

	async listTicketsAdmin(params: {
		limit?: number;
		offset?: number;
		status?: TicketStatus | null;
		category?: TicketCategory | null;
		search?: string | null;
	} = {}): Promise<{ items: TicketListItem[]; total: number }> {
		const { data, error } = await this.supabase.rpc('get_tickets_paginated', {
			p_limit: params.limit ?? 50,
			p_offset: params.offset ?? 0,
			p_status: params.status ?? null,
			p_category: params.category ?? null,
			p_search: params.search ?? null
		});
		if (error) throw new Error(error.message);
		const rows = (data ?? []) as TicketListItem[];
		return { items: rows, total: rows[0]?.total_count ?? 0 };
	}

	async getTicket(id: number): Promise<TicketDetail> {
		const { data, error } = await this.supabase.rpc('get_ticket_by_id', { p_id: id });
		if (error) throw new Error(error.message);
		if (!data) throw new Error('Ticket não encontrado.');
		const detail = data as { ticket: Ticket; audit_log: TicketAuditEntry[] };
		return { ticket: detail.ticket, audit_log: detail.audit_log ?? [] };
	}

	async updateStatus(id: number, status: TicketStatus, note?: string): Promise<Ticket> {
		const { data, error } = await this.supabase.rpc('update_ticket_status', {
			p_id: id,
			p_status: status,
			p_note: note ?? null
		});
		if (error) throw new Error(error.message);
		return data as Ticket;
	}

	async deleteAttachment(ticketId: number, path: string): Promise<Ticket> {
		const { data, error } = await this.supabase.rpc('delete_ticket_attachment', {
			p_ticket_id: ticketId,
			p_path: path
		});
		if (error) throw new Error(error.message);
		return data as Ticket;
	}

	async signAttachment(path: string): Promise<string | null> {
		const { data, error } = await this.supabase.storage
			.from(BUCKET)
			.createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
		if (error) return null;
		return data?.signedUrl ?? null;
	}

	async signAttachments(attachments: TicketAttachment[]): Promise<TicketAttachment[]> {
		if (!attachments || attachments.length === 0) return [];
		const signed = await Promise.all(
			attachments.map(async (att) => ({
				...att,
				signedUrl: (await this.signAttachment(att.path)) ?? undefined
			}))
		);
		return signed;
	}
}

export const ticketService = new TicketService();
