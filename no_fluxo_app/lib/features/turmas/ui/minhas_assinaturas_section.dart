import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/assinatura_model.dart';
import '../../../core/theme/app_colors.dart';
import '../data/turmas_providers.dart';
import '../domain/turmas_logic.dart';

/// Aba "Seguindo": lista as assinaturas ativas de alerta de vaga do usuário,
/// com opção de remover cada uma.
class MinhasAssinaturasSection extends ConsumerWidget {
  const MinhasAssinaturasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logado = ref.watch(estaLogadoProvider);
    if (!logado) {
      return const _MensagemVazia(
        icone: Icons.lock_outline,
        titulo: 'Entre para ser avisado',
        subtitulo:
            'Faça login para seguir matérias e receber '
            'alertas quando abrir vaga.',
      );
    }

    final assinaturas = ref.watch(assinaturasProvider);
    return assinaturas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _MensagemVazia(
        icone: Icons.error_outline,
        titulo: 'Erro ao carregar alertas',
        subtitulo: 'Verifique sua conexão e tente novamente.',
      ),
      data: (lista) {
        final ativas = lista.where((a) => a.ativa).toList();
        if (ativas.isEmpty) {
          return const _MensagemVazia(
            icone: Icons.notifications_none,
            titulo: 'Você ainda não segue nenhuma matéria',
            subtitulo:
                'Busque uma matéria na aba ao lado e toque em '
                '"Avisar quando abrir vaga".',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ativas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _AssinaturaCard(assinatura: ativas[i]),
        );
      },
    );
  }
}

class _AssinaturaCard extends ConsumerWidget {
  final AssinaturaModel assinatura;

  const _AssinaturaCard({required this.assinatura});

  Future<void> _remover(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final erro = await ref
        .read(assinaturasProvider.notifier)
        .deixarDeSeguir(assinatura.idAssinatura);
    if (erro != null) {
      messenger?.showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codigo = assinatura.codigoMateria ?? '—';
    final nome = assinatura.nomeMateria ?? 'Matéria';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$codigo — $nome',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${descreverAlvoAssinatura(assinatura)} · '
                  '${assinatura.anoPeriodo}',
                  style: const TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Deixar de seguir',
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.destructive,
            ),
            onPressed: () => _remover(context, ref),
          ),
        ],
      ),
    );
  }
}

class _MensagemVazia extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;

  const _MensagemVazia({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
