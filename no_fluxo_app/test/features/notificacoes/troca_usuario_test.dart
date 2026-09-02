import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/notificacao_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/notificacoes/providers/notificacoes_provider.dart';

import 'fakes.dart';

/// Auth fake mutável: os testes disparam transições login/logout.
class _AuthMutavel extends AuthNotifier {
  _AuthMutavel(this._inicial);

  final AuthState _inicial;

  @override
  Future<AuthState> build() async => _inicial;

  void emitir(AuthState novo) => state = AsyncData(novo);
}

NotificacaoModel _notif(int id, String titulo) => NotificacaoModel(
  idNotificacao: id,
  createdAt: DateTime(2026, 8, 31),
  tipo: 'vaga_disponivel',
  titulo: titulo,
  mensagem: 'msg',
  metadata: const {},
  lida: false,
);

void main() {
  test(
    'troca de usuário reconstrói a lista — sem vazar inbox entre contas',
    () async {
      final repo = FakeNotificacoesRepository(
        notificacoes: [_notif(1, 'Vaga para a conta A')],
        totalNaoLidas: 1,
      );
      final auth = _AuthMutavel(
        AuthState.loggedIn(
          UserModel(idUser: 1, email: 'a@unb.br', nomeCompleto: 'Conta A'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          notificacoesRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(() => auth),
        ],
      );
      addTearDown(container.dispose);
      // Mantém o provider vivo durante as transições, como a UI faria.
      container.listen(notificacoesProvider, (_, _) {});

      // Conta A carrega o inbox dela.
      await container.read(authProvider.future);
      var estado = await container.read(notificacoesProvider.future);
      expect(estado.notificacoes.single.titulo, 'Vaga para a conta A');
      final chamadasComA = repo.chamadasListar;

      // Logout: o estado cacheado de A não pode sobreviver.
      auth.emitir(const AuthState.loggedOut());
      await container.pump();
      estado = await container.read(notificacoesProvider.future);
      expect(estado.notificacoes, isEmpty);

      // Conta B loga no mesmo aparelho: a lista é recarregada do servidor
      // (nova chamada), não servida do cache de A.
      repo.notificacoes = [_notif(2, 'Vaga para a conta B')];
      auth.emitir(
        AuthState.loggedIn(
          UserModel(idUser: 2, email: 'b@unb.br', nomeCompleto: 'Conta B'),
        ),
      );
      await container.pump();
      estado = await container.read(notificacoesProvider.future);
      expect(estado.notificacoes.single.titulo, 'Vaga para a conta B');
      expect(repo.chamadasListar, greaterThan(chamadasComA));
    },
  );
}
