/// Fakes compartilhados dos testes do Assistente IA.
library;

import 'dart:async';

import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/assistente/data/assistente_repository.dart';

/// Auth fake logado, com histórico (matriz curricular) opcional.
class FakeAuthLogado extends AuthNotifier {
  final String? matrizCurricular;

  FakeAuthLogado({this.matrizCurricular = '8899/2'});

  @override
  Future<AuthState> build() async {
    final user = UserModel(
      idUser: 1,
      email: 'teste@unb.br',
      nomeCompleto: 'Aluno Teste',
    );
    final matriz = matrizCurricular;
    if (matriz != null) {
      user.dadosFluxograma = DadosFluxogramaUser(
        nomeCurso: 'Engenharia de Software',
        matrizCurricular: matriz,
      );
    }
    return AuthState.loggedIn(user);
  }
}

/// Auth fake em modo visitante (sem sessão).
class FakeAuthVisitante extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.anonymous();
}

/// Registro de uma chamada a `enviarMensagem`.
typedef ChamadaChat = ({String mensagem, String? curriculo});

/// Repositório fake do assistente com respostas programáveis.
class FakeAssistenteRepository implements AssistenteRepository {
  /// Reply devolvido em sucesso.
  String resposta;

  /// Erro a lançar (tem precedência sobre [resposta]).
  AssistenteException? erro;

  /// Se definido, a chamada fica pendente até o completer resolver —
  /// para testar o estado "pensando".
  Completer<String>? pendente;

  final List<ChamadaChat> chamadas = [];

  FakeAssistenteRepository({this.resposta = 'Oi! Eu sou o Darcy.'});

  @override
  Duration get timeout => const Duration(seconds: 90);

  @override
  Future<String> enviarMensagem(
    String mensagem, {
    String? curriculoCompleto,
  }) async {
    chamadas.add((mensagem: mensagem, curriculo: curriculoCompleto));
    final completer = pendente;
    if (completer != null) return completer.future;
    final e = erro;
    if (e != null) throw e;
    return resposta;
  }
}
