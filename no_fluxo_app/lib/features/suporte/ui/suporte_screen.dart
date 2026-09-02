import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/tempo_relativo.dart';
import '../data/suporte_repository.dart';
import '../data/ticket_model.dart';
import 'novo_chamado_screen.dart';

/// Cor do chip de status de um ticket (fechado/desconhecido → cinza).
Color corDoStatusTicket(String status) {
  switch (status) {
    case 'aberto':
      return Colors.amber;
    case 'em_andamento':
      return AppColors.destaqueEquivalencia; // azul
    case 'aguardando_info':
      return AppColors.destaqueOptativa; // laranja
    case 'resolvido':
      return Colors.green;
    case 'fechado':
    default:
      return AppColors.mutedForeground; // cinza
  }
}

/// Tela de suporte: lista "Meus chamados" + FAB "Novo chamado".
///
/// Acessada pela seção de conta do Perfil (só para usuário logado).
class SuporteScreen extends ConsumerWidget {
  const SuporteScreen({super.key});

  Future<void> _abrirNovoChamado(BuildContext context, WidgetRef ref) async {
    final criado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const NovoChamadoScreen()));
    if (criado == true) {
      // Recarrega a lista com o chamado recém-criado.
      ref.invalidate(meusTicketsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chamado enviado! Vamos te responder '
              'em breve.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(meusTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Suporte e feedback')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirNovoChamado(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo chamado'),
      ),
      body: tickets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _MensagemCentral(
          icone: Icons.cloud_off_outlined,
          texto:
              'Não foi possível carregar seus chamados. '
              'Verifique sua conexão e tente novamente.',
        ),
        data: (lista) => lista.isEmpty
            ? const _MensagemCentral(
                icone: Icons.support_agent_outlined,
                texto:
                    'Você ainda não abriu nenhum chamado.\n'
                    'Achou um bug ou tem uma sugestão? Conta pra gente!',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(meusTicketsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: lista.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Meus chamados',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    }
                    return _TicketCard(ticket: lista[i - 1]);
                  },
                ),
              ),
      ),
    );
  }
}

/// Card de um chamado: título, categoria + quando, e chip de status.
class _TicketCard extends StatelessWidget {
  final TicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final categoria = ticket.categoria?.label;
    final quando = tempoRelativo(ticket.createdAt, diasParaDataAbsoluta: 30);
    final subtitulo = [?categoria, if (quando.isNotEmpty) quando].join(' • ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: tema.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: tema.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: ticket.status, label: ticket.statusLabel),
          ],
        ),
      ),
    );
  }
}

/// Chip colorido de status (aberto âmbar, em andamento azul, resolvido
/// verde, fechado cinza).
class _StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final cor = corDoStatusTicket(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cor, height: 1.2),
      ),
    );
  }
}

/// Mensagem centralizada (vazio / erro) que ainda permite pull-to-refresh
/// visual simples.
class _MensagemCentral extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _MensagemCentral({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
