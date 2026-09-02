import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/notificacao_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';
import '../providers/notificacoes_provider.dart';
import '../utils/tempo_relativo.dart';
import '../../../core/config/rotas.dart';

/// Tela de notificações (inbox) — mobile-first.
///
/// - Visitante/deslogado: pede login (notificações são por usuário).
/// - Logado: lista com pull-to-refresh, filtro "só não lidas" e ação
///   "marcar todas como lidas". Tocar numa notificação marca como lida e,
///   se o metadata tiver `codigo_materia`, navega para /turmas?codigo=XXX.
class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!ref.watch(estaLogadoProvider)) return const _TelaPedindoLogin();
    return const _TelaInbox();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visitante / deslogado
// ─────────────────────────────────────────────────────────────────────────────

class _TelaPedindoLogin extends StatelessWidget {
  const _TelaPedindoLogin();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Entre para receber avisos',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'As notificações de vagas são por conta. Faça login para '
                'seguir matérias e ser avisado quando abrirem vagas.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Fazer login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inbox (logado)
// ─────────────────────────────────────────────────────────────────────────────

class _TelaInbox extends ConsumerWidget {
  const _TelaInbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEstado = ref.watch(notificacoesProvider);
    final notifier = ref.read(notificacoesProvider.notifier);
    final estado = asyncEstado.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if ((estado?.totalNaoLidas ?? 0) > 0)
            TextButton.icon(
              onPressed: notifier.marcarTodasComoLidas,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Marcar todas como lidas'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Só não lidas'),
                  selected: estado?.somenteNaoLidas ?? false,
                  onSelected: (valor) =>
                      notifier.alternarSomenteNaoLidas(valor),
                  selectedColor: AppColors.primary.withValues(alpha: 0.22),
                  checkmarkColor: AppColors.accent,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.recarregar,
              child: _corpo(context, ref, asyncEstado),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NotificacoesState> asyncEstado,
  ) {
    return asyncEstado.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => _EstadoErro(
        onTentarNovamente: () =>
            ref.read(notificacoesProvider.notifier).recarregar(),
      ),
      data: (estado) {
        if (estado.notificacoes.isEmpty) {
          return _EstadoVazio(filtroAtivo: estado.somenteNaoLidas);
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: estado.notificacoes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _NotificacaoTile(notificacao: estado.notificacoes[index]),
        );
      },
    );
  }
}

/// Card de uma notificação: dot roxo quando não lida, título, mensagem e
/// tempo relativo ("há 5 min").
class _NotificacaoTile extends ConsumerWidget {
  final NotificacaoModel notificacao;

  const _NotificacaoTile({required this.notificacao});

  Future<void> _aoTocar(BuildContext context, WidgetRef ref) async {
    // Marca como lida (otimista; no-op se já estiver lida)…
    final futuroMarcar = ref
        .read(notificacoesProvider.notifier)
        .marcarComoLida(notificacao);

    // …e, se a notificação aponta para uma matéria, vai para a aba Turmas.
    final codigo = parseStringOrNull(notificacao.metadata['codigo_materia']);
    if (codigo != null && codigo.trim().isNotEmpty) {
      context.go(rotaTurmas(codigo: codigo));
    }
    await futuroMarcar;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final naoLida = !notificacao.lida;

    return Material(
      color: naoLida ? AppColors.secondary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _aoTocar(context, ref),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: naoLida
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dot roxo (#8B44F5) marcando não lida.
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 10),
                child: naoLida
                    ? Container(
                        key: Key('dot-nao-lida-${notificacao.idNotificacao}'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox(width: 8, height: 8),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacao.titulo,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: naoLida ? FontWeight.w600 : FontWeight.w500,
                        color: naoLida
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                    if (notificacao.mensagem.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notificacao.mensagem,
                        style: textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      formatarTempoRelativo(notificacao.createdAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedForeground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio: convida a seguir uma matéria na aba Turmas.
class _EstadoVazio extends StatelessWidget {
  /// Quando o filtro "só não lidas" está ativo o texto muda um pouco.
  final bool filtroAtivo;

  const _EstadoVazio({this.filtroAtivo = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // ListView para o RefreshIndicator continuar funcionando no vazio.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                filtroAtivo
                    ? 'Nenhuma notificação não lida'
                    : 'Nenhuma notificação',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                filtroAtivo
                    ? 'Você está em dia! Desative o filtro para ver o '
                          'histórico.'
                    : 'Siga uma matéria para ser avisado quando abrirem '
                          'vagas.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (!filtroAtivo) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/turmas'),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Ver turmas'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Estado de erro com retry (o pull-to-refresh também funciona).
class _EstadoErro extends StatelessWidget {
  final VoidCallback onTentarNovamente;

  const _EstadoErro({required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(height: 16),
              Text(
                'Não foi possível carregar as notificações',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifique sua conexão e tente novamente.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onTentarNovamente,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
