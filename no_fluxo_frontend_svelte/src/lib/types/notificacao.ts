export interface VagaAssinatura {
	id_assinatura: number;
	id_user: number;
	id_materia: number;
	turma: string | null;
	ano_periodo: string;
	ativa: boolean;
	created_at: string;
}

export interface Notificacao {
	id_notificacao: number;
	created_at: string;
	tipo: string;
	titulo: string;
	mensagem: string;
	metadata: Record<string, unknown>;
	lida: boolean;
	lida_em: string | null;
}
