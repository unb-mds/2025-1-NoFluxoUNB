import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake do AuthNotifier que simula sessão local presente e controla o
/// resultado do carregamento do perfil, sem depender do Supabase real.
class _AuthNotifierFake extends AuthNotifier {
  _AuthNotifierFake({
    required this.resultados,
    this.atrasoRetry = Duration.zero,
  });

  /// Fila de resultados de buscarPerfilDaSessao: cada chamada consome um.
  /// Um item `Exception` é lançado; um `UserModel?` é retornado.
  final List<Object?> resultados;
  final Duration atrasoRetry;
  int chamadas = 0;

  @override
  bool get temSessaoLocal => true;

  @override
  void escutarMudancasDeAuth() {
    // no-op: sem Supabase inicializado nos testes.
  }

  @override
  Duration atrasoRetryPerfil(int tentativa) => atrasoRetry;

  @override
  Future<UserModel?> buscarPerfilDaSessao() async {
    final resultado = resultados[chamadas.clamp(0, resultados.length - 1)];
    chamadas++;
    if (resultado is Exception) throw resultado;
    return resultado as UserModel?;
  }
}

UserModel _usuarioDeTeste() => UserModel(
  idUser: 1,
  authId: 'abc',
  email: 'teste@unb.br',
  nomeCompleto: 'Teste da Silva',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthNotifier.build com sessão local presente', () {
    test('erro de rede no perfil NÃO derruba para loggedOut', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _AuthNotifierFake(
              resultados: [const SocketException('sem rede')],
              // Atraso longo: o retry não chega a rodar dentro do teste.
              atrasoRetry: const Duration(minutes: 5),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final estado = await container.read(authProvider.future);
      expect(estado.status, AuthStatus.loggedIn);
      expect(estado.user, isNull);
    });

    test('perfil inexistente (null, sem erro) vira loggedOut', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _AuthNotifierFake(resultados: [null]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final estado = await container.read(authProvider.future);
      expect(estado.status, AuthStatus.loggedOut);
    });

    test('perfil carregado com sucesso vira loggedIn com user', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _AuthNotifierFake(resultados: [_usuarioDeTeste()]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final estado = await container.read(authProvider.future);
      expect(estado.status, AuthStatus.loggedIn);
      expect(estado.user?.idUser, 1);
    });

    test('retry recupera o perfil depois de falha transitória', () async {
      final fake = _AuthNotifierFake(
        resultados: [const SocketException('sem rede'), _usuarioDeTeste()],
      );
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final inicial = await container.read(authProvider.future);
      expect(inicial.status, AuthStatus.loggedIn);
      expect(inicial.user, isNull);

      // Dá tempo do Timer (Duration.zero) do retry disparar.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final depois = container.read(authProvider).valueOrNull;
      expect(fake.chamadas, greaterThanOrEqualTo(2));
      expect(depois?.status, AuthStatus.loggedIn);
      expect(depois?.user?.idUser, 1);
    });
  });
}
