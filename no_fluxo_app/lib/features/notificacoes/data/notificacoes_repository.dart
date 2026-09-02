import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/notificacao_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/json_utils.dart';

/// Resultado da RPC `listar_notificacoes`.
///
/// Shape retornado pelo banco:
/// `{ items: [{id_notificacao, created_at, tipo, titulo, mensagem, metadata,
/// lida, lida_em}], total_nao_lidas }`.
class ResultadoNotificacoes {
  final List<NotificacaoModel> items;
  final int totalNaoLidas;

  const ResultadoNotificacoes({this.items = const [], this.totalNaoLidas = 0});

  /// Parsing defensivo: aceita o retorno cru da RPC (Map), itens inválidos
  /// são descartados e campos ausentes caem nos defaults.
  factory ResultadoNotificacoes.fromJson(dynamic json) {
    final map = asMapOrNull(json) ?? const <String, dynamic>{};
    final items = asListOr(map['items'])
        .map(asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(NotificacaoModel.fromJson)
        .toList();
    return ResultadoNotificacoes(
      items: items,
      totalNaoLidas: parseIntOr(map['total_nao_lidas']),
    );
  }
}

/// Acesso a dados das notificações do usuário logado.
///
/// Abstração fina sobre as RPCs do Supabase — permite fakes nos testes.
abstract class NotificacoesRepository {
  /// RPC `listar_notificacoes(p_limit, p_somente_nao_lidas)`.
  Future<ResultadoNotificacoes> listarNotificacoes({
    int limit = 30,
    bool somenteNaoLidas = false,
  });

  /// RPC `marcar_notificacao_lida(p_id_notificacao)`.
  ///
  /// [idNotificacao] nulo marca TODAS as notificações como lidas.
  Future<void> marcarComoLida({int? idNotificacao});

  /// Assina eventos de INSERT na tabela `notificacoes` via Supabase Realtime
  /// para o badge em tempo real.
  ///
  /// - [onNovaNotificacao] é chamado a cada INSERT recebido (o chamador deve
  ///   refazer a contagem — o payload não é usado por causa do RLS).
  /// - [onFalha] é chamado se o canal não conseguir se inscrever (ex.:
  ///   Realtime não habilitado para a tabela no projeto) — o chamador deve
  ///   cair para polling.
  ///
  /// Retorna uma função de cancelamento da assinatura (idempotente).
  void Function() assinarNovasNotificacoes({
    required void Function() onNovaNotificacao,
    void Function()? onFalha,
  });
}

/// Implementação real sobre o cliente Supabase.
class SupabaseNotificacoesRepository implements NotificacoesRepository {
  SupabaseClient get _client => SupabaseService.client;

  @override
  Future<ResultadoNotificacoes> listarNotificacoes({
    int limit = 30,
    bool somenteNaoLidas = false,
  }) async {
    final data = await _client.rpc<dynamic>(
      'listar_notificacoes',
      params: {'p_limit': limit, 'p_somente_nao_lidas': somenteNaoLidas},
    );
    return ResultadoNotificacoes.fromJson(data);
  }

  @override
  Future<void> marcarComoLida({int? idNotificacao}) async {
    await _client.rpc<dynamic>(
      'marcar_notificacao_lida',
      params: {'p_id_notificacao': idNotificacao},
    );
  }

  /// IMPORTANTE: o Realtime pode NÃO estar habilitado para a tabela
  /// `notificacoes` no projeto Supabase (a publicação `supabase_realtime`
  /// precisa incluir a tabela). Quando isso acontece o canal falha ao
  /// inscrever (channelError/timedOut) — a falha é tratada em silêncio e o
  /// chamador (unreadCountProvider) cai para polling de 60s como fallback.
  @override
  void Function() assinarNovasNotificacoes({
    required void Function() onNovaNotificacao,
    void Function()? onFalha,
  }) {
    RealtimeChannel? canal;
    try {
      canal = _client
          .channel('notificacoes-badge')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notificacoes',
            callback: (_) => onNovaNotificacao(),
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              debugPrint(
                'Realtime indisponível para notificacoes ($status): $error — '
                'caindo para polling.',
              );
              onFalha?.call();
            }
          });
    } catch (e) {
      // Falha silenciosa (ex.: Realtime desligado) — o badge usa polling.
      debugPrint('Erro ao assinar Realtime de notificacoes: $e');
      onFalha?.call();
    }

    return () {
      final c = canal;
      canal = null;
      if (c != null) {
        // unawaited de propósito: cancelamento é best-effort.
        _client.removeChannel(c).ignore();
      }
    };
  }
}
