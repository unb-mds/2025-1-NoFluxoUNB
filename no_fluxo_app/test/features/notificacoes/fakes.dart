/// Fakes compartilhados dos testes de notificações.
library;

import 'package:no_fluxo_app/core/models/notificacao_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/notificacoes/data/notificacoes_repository.dart';

/// Auth fake: sobrescreve o build para não tocar no Supabase.
class FakeAuthLogado extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return AuthState.loggedIn(
      UserModel(idUser: 1, email: 'teste@unb.br', nomeCompleto: 'Aluno Teste'),
    );
  }
}

/// Auth fake em modo visitante (sem sessão).
class FakeAuthVisitante extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.anonymous();
}

/// Registro de uma chamada a `marcarComoLida` (null = todas).
typedef ChamadaMarcarLida = int?;

/// Repositório fake em memória com registro de chamadas.
class FakeNotificacoesRepository implements NotificacoesRepository {
  List<NotificacaoModel> notificacoes;
  int totalNaoLidas;

  /// Erro a lançar em `listarNotificacoes` (para testar estado de erro).
  Object? erroAoListar;

  /// Histórico de chamadas: id passado (null = marcar todas).
  final List<ChamadaMarcarLida> chamadasMarcarLida = [];

  /// Argumentos `somenteNaoLidas` das chamadas de listagem (exclui as do
  /// badge, que usam limit == 1).
  final List<bool> filtrosListagem = [];

  int chamadasListar = 0;

  /// Callback do Realtime capturado (para simular INSERT nos testes).
  void Function()? onNovaNotificacao;

  /// Callback de falha capturado (para simular Realtime desabilitado).
  void Function()? onFalhaRealtime;

  int assinaturasAtivas = 0;

  FakeNotificacoesRepository({
    this.notificacoes = const [],
    this.totalNaoLidas = 0,
  });

  @override
  Future<ResultadoNotificacoes> listarNotificacoes({
    int limit = 30,
    bool somenteNaoLidas = false,
  }) async {
    chamadasListar++;
    if (limit != 1) filtrosListagem.add(somenteNaoLidas);
    final erro = erroAoListar;
    if (erro != null) throw erro;
    final itens = somenteNaoLidas
        ? notificacoes.where((n) => !n.lida).toList()
        : List<NotificacaoModel>.from(notificacoes);
    return ResultadoNotificacoes(
      items: itens.take(limit).toList(),
      totalNaoLidas: totalNaoLidas,
    );
  }

  @override
  Future<void> marcarComoLida({int? idNotificacao}) async {
    chamadasMarcarLida.add(idNotificacao);
    if (idNotificacao == null) {
      notificacoes = notificacoes
          .map((n) => n.copyWith(lida: true, lidaEm: DateTime.now()))
          .toList();
      totalNaoLidas = 0;
    } else {
      notificacoes = notificacoes
          .map(
            (n) => n.idNotificacao == idNotificacao
                ? n.copyWith(lida: true, lidaEm: DateTime.now())
                : n,
          )
          .toList();
      totalNaoLidas = notificacoes.where((n) => !n.lida).length;
    }
  }

  @override
  void Function() assinarNovasNotificacoes({
    required void Function() onNovaNotificacao,
    void Function()? onFalha,
  }) {
    this.onNovaNotificacao = onNovaNotificacao;
    onFalhaRealtime = onFalha;
    assinaturasAtivas++;
    return () => assinaturasAtivas--;
  }
}

/// Atalho para montar uma notificação nos testes.
NotificacaoModel notificacaoDeTeste({
  int id = 1,
  String titulo = 'Vaga aberta',
  String mensagem = 'Abriu vaga em Cálculo 1',
  bool lida = false,
  Map<String, dynamic> metadata = const {},
  DateTime? createdAt,
}) {
  return NotificacaoModel(
    idNotificacao: id,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(minutes: 5)),
    tipo: 'vaga_aberta',
    titulo: titulo,
    mensagem: mensagem,
    metadata: metadata,
    lida: lida,
  );
}
