import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/redirect_importacao.dart';

void main() {
  String? decidir({
    AuthStatus status = AuthStatus.loggedIn,
    bool perfilCarregado = true,
    bool temFluxograma = false,
    bool adiou = false,
    String location = '/fluxograma',
  }) => redirectImportacaoDeHistorico(
    status: status,
    perfilCarregado: perfilCarregado,
    temFluxograma: temFluxograma,
    adiou: adiou,
    location: location,
  );

  group('redirect pós-login para o onboarding', () {
    test('logado sem fluxograma → /importar-historico', () {
      expect(decidir(), kRotaImportarHistorico);
    });

    test('já na tela de importação → não redireciona (sem loop)', () {
      expect(decidir(location: kRotaImportarHistorico), isNull);
    });

    test('com fluxograma salvo → não redireciona', () {
      expect(decidir(temFluxograma: true), isNull);
    });

    test('"Agora não" (adiou) → não redireciona nesta sessão', () {
      expect(decidir(adiou: true), isNull);
    });

    test('perfil ainda não carregado (boot offline) → não redireciona', () {
      expect(decidir(perfilCarregado: false), isNull);
    });

    test('visitante NUNCA vai para o onboarding', () {
      expect(decidir(status: AuthStatus.anonymous), isNull);
    });

    test('visitante que cair na tela de importação volta ao fluxograma', () {
      expect(
        decidir(status: AuthStatus.anonymous, location: kRotaImportarHistorico),
        '/fluxograma',
      );
    });

    test('deslogado → nada (o redirect de login cuida)', () {
      expect(decidir(status: AuthStatus.loggedOut), isNull);
    });

    test('funciona a partir de qualquer aba do shell', () {
      expect(decidir(location: '/perfil'), kRotaImportarHistorico);
    });
  });
}
