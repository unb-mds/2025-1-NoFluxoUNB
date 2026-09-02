import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notificacao_model.dart';
import '../../../core/services/auth_service.dart';
import '../data/notificacoes_repository.dart';

/// Repositório de notificações (sobrescrever nos testes com um fake).
final notificacoesRepositoryProvider = Provider<NotificacoesRepository>(
  (ref) => SupabaseNotificacoesRepository(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Badge de não lidas
// ─────────────────────────────────────────────────────────────────────────────

/// Contagem de notificações NÃO LIDAS do usuário logado.
///
/// É o provider que outros widgets devem consumir para exibir badge (ex.: o
/// ícone da aba Notificações na bottom bar):
///
/// ```dart
/// final naoLidas = ref.watch(unreadCountProvider);
/// ```
///
/// Comportamento:
/// - visitante/deslogado → sempre 0 (sem chamadas ao banco);
/// - logado → busca a contagem via RPC e assina INSERTs na tabela
///   `notificacoes` via Supabase Realtime, refazendo a contagem a cada evento;
/// - se o Realtime não estiver habilitado para a tabela no projeto, a falha é
///   silenciosa e o provider cai para polling de 60s (Timer.periodic).
final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

/// Notifier da contagem de não lidas — ver [unreadCountProvider].
class UnreadCountNotifier extends Notifier<int> {
  /// Intervalo do polling de fallback quando o Realtime falha.
  ///
  /// Mutável apenas para os testes encurtarem a espera.
  @visibleForTesting
  static Duration intervaloPolling = const Duration(seconds: 60);

  /// Geração do build atual: invalida callbacks pendentes de builds antigos
  /// (troca de usuário, dispose) sem precisar de flags espalhadas.
  int _geracao = 0;
  Timer? _timerPolling;
  void Function()? _cancelarRealtime;

  @override
  int build() {
    final geracao = ++_geracao;
    ref.onDispose(_limpar);

    final auth = ref.watch(authProvider).valueOrNull;
    if (auth == null || !auth.isLoggedIn) return 0;

    // O build de Notifier é síncrono — a carga inicial e a assinatura do
    // Realtime ficam para um microtask.
    Future.microtask(() {
      if (geracao != _geracao) return;
      unawaited(_iniciar(geracao));
    });
    return 0;
  }

  Future<void> _iniciar(int geracao) async {
    await recarregar();
    if (geracao != _geracao) return;

    // Badge em tempo real: INSERT em `notificacoes` → refaz a contagem.
    // Se o Realtime não estiver habilitado para a tabela (onFalha), cai em
    // silêncio para polling de 60s — documentado no repositório.
    _cancelarRealtime = ref
        .read(notificacoesRepositoryProvider)
        .assinarNovasNotificacoes(
          onNovaNotificacao: () {
            if (geracao != _geracao) return;
            unawaited(recarregar());
          },
          onFalha: () {
            if (geracao != _geracao) return;
            _iniciarPolling();
          },
        );

    // O build pode ter sido invalidado enquanto a assinatura era criada.
    if (geracao != _geracao) {
      _cancelarRealtime?.call();
      _cancelarRealtime = null;
    }
  }

  void _iniciarPolling() {
    _timerPolling?.cancel();
    _timerPolling = Timer.periodic(
      intervaloPolling,
      (_) => unawaited(recarregar()),
    );
  }

  /// Refaz a contagem via RPC (limit mínimo — só interessa `total_nao_lidas`).
  /// Falhas são silenciosas: o badge nunca pode derrubar o app.
  Future<void> recarregar() async {
    final geracao = _geracao;
    try {
      final resultado = await ref
          .read(notificacoesRepositoryProvider)
          .listarNotificacoes(limit: 1);
      if (geracao != _geracao) return;
      state = resultado.totalNaoLidas;
    } catch (_) {
      // Silencioso — mantém a última contagem conhecida.
    }
  }

  /// Sincroniza a contagem sem nova chamada ao banco (usado pela tela de
  /// notificações ao marcar itens como lidos).
  void definirContagem(int valor) {
    state = valor < 0 ? 0 : valor;
  }

  void _limpar() {
    _geracao++;
    _timerPolling?.cancel();
    _timerPolling = null;
    _cancelarRealtime?.call();
    _cancelarRealtime = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de notificações (tela)
// ─────────────────────────────────────────────────────────────────────────────

/// Estado da tela de notificações.
class NotificacoesState {
  final List<NotificacaoModel> notificacoes;
  final int totalNaoLidas;

  /// Filtro "só não lidas" ativo.
  final bool somenteNaoLidas;

  const NotificacoesState({
    this.notificacoes = const [],
    this.totalNaoLidas = 0,
    this.somenteNaoLidas = false,
  });

  NotificacoesState copyWith({
    List<NotificacaoModel>? notificacoes,
    int? totalNaoLidas,
    bool? somenteNaoLidas,
  }) {
    return NotificacoesState(
      notificacoes: notificacoes ?? this.notificacoes,
      totalNaoLidas: totalNaoLidas ?? this.totalNaoLidas,
      somenteNaoLidas: somenteNaoLidas ?? this.somenteNaoLidas,
    );
  }
}

/// Lista de notificações da tela (inbox).
final notificacoesProvider =
    AsyncNotifierProvider<NotificacoesNotifier, NotificacoesState>(
      NotificacoesNotifier.new,
    );

/// Notifier da lista de notificações.
class NotificacoesNotifier extends AsyncNotifier<NotificacoesState> {
  bool _somenteNaoLidas = false;

  NotificacoesRepository get _repo => ref.read(notificacoesRepositoryProvider);

  @override
  Future<NotificacoesState> build() {
    // Troca de usuário (login/logout) reconstrói o notifier — sem isso, o
    // provider keep-alive mostraria o inbox cacheado da conta anterior.
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth == null || !auth.isLoggedIn) {
      return Future.value(
        NotificacoesState(
          notificacoes: const [],
          totalNaoLidas: 0,
          somenteNaoLidas: _somenteNaoLidas,
        ),
      );
    }
    return _carregar();
  }

  Future<NotificacoesState> _carregar() async {
    final resultado = await _repo.listarNotificacoes(
      somenteNaoLidas: _somenteNaoLidas,
    );
    _sincronizarBadge(resultado.totalNaoLidas);
    return NotificacoesState(
      notificacoes: resultado.items,
      totalNaoLidas: resultado.totalNaoLidas,
      somenteNaoLidas: _somenteNaoLidas,
    );
  }

  /// Recarrega a lista (pull-to-refresh). Mantém os dados atuais visíveis
  /// enquanto busca.
  Future<void> recarregar() async {
    state = await AsyncValue.guard(_carregar);
  }

  /// Liga/desliga o filtro "só não lidas" e recarrega.
  Future<void> alternarSomenteNaoLidas(bool valor) async {
    if (_somenteNaoLidas == valor) return;
    _somenteNaoLidas = valor;
    final atual = state.valueOrNull;
    if (atual != null) {
      // Reflete o chip imediatamente; a lista chega em seguida.
      state = AsyncData(atual.copyWith(somenteNaoLidas: valor));
    }
    await recarregar();
  }

  /// Marca UMA notificação como lida (otimista; desfaz recarregando em erro).
  Future<void> marcarComoLida(NotificacaoModel notificacao) async {
    if (notificacao.lida) return;

    final atual = state.valueOrNull;
    if (atual != null) {
      final novaLista = atual.notificacoes
          .map(
            (n) => n.idNotificacao == notificacao.idNotificacao
                ? n.copyWith(lida: true, lidaEm: DateTime.now())
                : n,
          )
          .toList();
      final novoTotal = atual.totalNaoLidas > 0 ? atual.totalNaoLidas - 1 : 0;
      state = AsyncData(
        atual.copyWith(notificacoes: novaLista, totalNaoLidas: novoTotal),
      );
      _sincronizarBadge(novoTotal);
    }

    try {
      await _repo.marcarComoLida(idNotificacao: notificacao.idNotificacao);
    } catch (_) {
      await recarregar();
    }
  }

  /// Marca TODAS como lidas (RPC com p_id_notificacao = null).
  Future<void> marcarTodasComoLidas() async {
    final atual = state.valueOrNull;
    if (atual != null) {
      final novaLista = atual.notificacoes
          .map(
            (n) => n.lida ? n : n.copyWith(lida: true, lidaEm: DateTime.now()),
          )
          .toList();
      state = AsyncData(
        atual.copyWith(notificacoes: novaLista, totalNaoLidas: 0),
      );
      _sincronizarBadge(0);
    }

    try {
      await _repo.marcarComoLida();
    } catch (_) {
      await recarregar();
    }
  }

  /// Mantém o badge da bottom bar em dia sem nova ida ao banco.
  void _sincronizarBadge(int total) {
    ref.read(unreadCountProvider.notifier).definirContagem(total);
  }
}
