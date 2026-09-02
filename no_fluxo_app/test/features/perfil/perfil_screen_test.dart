import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/config/release.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/perfil/data/perfil_repository.dart';
import 'package:no_fluxo_app/features/perfil/domain/progresso_calculator.dart';
import 'package:no_fluxo_app/features/perfil/ui/novidades_dialog.dart';
import 'package:no_fluxo_app/features/perfil/ui/perfil_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier fake: devolve um [AuthState] fixo sem tocar em Supabase ou
/// SharedPreferences (o build e o logout reais são sobrescritos).
class _FakeAuthNotifier extends AuthNotifier {
  final AuthState estadoInicial;
  bool logoutChamado = false;

  _FakeAuthNotifier(this.estadoInicial);

  @override
  Future<AuthState> build() async => estadoInicial;

  @override
  Future<void> logout() async {
    logoutChamado = true;
    state = const AsyncData(AuthState.loggedOut());
  }
}

UserModel _userFixture() {
  return UserModel(
    idUser: 1,
    email: 'ana@aluno.unb.br',
    nomeCompleto: 'Ana Beatriz Silva',
    dadosFluxograma: DadosFluxogramaUser(
      nomeCurso: 'Engenharia de Software',
      matrizCurricular: '6360/2 - 2017.1',
      semestreAtual: 5,
      ira: 4.1234,
      iraTexto: '4,1234',
      horasIntegralizadas: 1590,
      dadosFluxograma: [
        [
          DadosMateria(codigoMateria: 'MAT0025', status: 'APR'),
          DadosMateria(codigoMateria: 'FGA0312', status: 'MATR'),
          DadosMateria(codigoMateria: 'FGA0242', status: '-'),
        ],
      ],
    ),
  );
}

ProgressoPerfil _progressoFixture() {
  return ProgressoCalculator.calcular(
    integralizada: const CargaHorariaIntegralizada(
      obrigatoria: 1230,
      optativa: 300,
      complementar: 0,
      total: 1590,
    ),
    exigencias: const ExigenciasMatriz(
      curriculoCompleto: '6360/2 - 2017.1',
      chObrigatoriaExigida: 2400,
      chOptativaExigida: 900,
      chComplementarExigida: 0,
      chTotalExigida: 3420,
    ),
    dados: _userFixture().dadosFluxograma,
  );
}

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: PerfilScreen()),
  );
}

void main() {
  group('PerfilScreen logado', () {
    late _FakeAuthNotifier fake;

    Future<void> montar(WidgetTester tester) async {
      // Novidades já vistas — o dialog não pode cobrir a tela nestes testes
      // (coberto em novidades_dialog_test.dart).
      SharedPreferences.setMockInitialValues({
        chaveReleaseVisto(1): kReleaseId,
      });
      fake = _FakeAuthNotifier(AuthState.loggedIn(_userFixture()));
      await tester.pumpWidget(
        _app([
          authProvider.overrideWith(() => fake),
          progressoPerfilProvider.overrideWith(
            (ref) => Future.value(_progressoFixture()),
          ),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra header com iniciais, nome, e-mail e curso + matriz', (
      tester,
    ) async {
      await montar(tester);
      expect(find.text('AS'), findsOneWidget); // iniciais no avatar
      expect(find.text('Ana Beatriz Silva'), findsOneWidget);
      expect(find.text('ana@aluno.unb.br'), findsOneWidget);
      expect(
        find.text('Engenharia de Software • 6360/2 - 2017.1'),
        findsOneWidget,
      );
    });

    testWidgets('mostra barras de progresso com horas e faltantes', (
      tester,
    ) async {
      await montar(tester);
      expect(find.text('Progresso do curso'), findsOneWidget);
      expect(find.text('1.230/2.400h'), findsOneWidget); // obrigatória
      expect(find.text('300/900h'), findsOneWidget); // optativa
      expect(find.text('1.590/3.420h'), findsOneWidget); // total
      // Complementar não exigida pela matriz → sem barra.
      expect(find.text('Complementar'), findsNothing);
      expect(find.textContaining('faltam 1.170h'), findsOneWidget);
    });

    testWidgets('mostra IRA (iraTexto), semestre atual e contagens', (
      tester,
    ) async {
      await montar(tester);
      expect(find.text('IRA'), findsOneWidget);
      expect(find.text('4,1234'), findsOneWidget);
      expect(find.text('Semestre atual'), findsOneWidget);
      expect(find.text('5º'), findsOneWidget);
      expect(find.text('Concluídas'), findsOneWidget);
      expect(find.text('Em curso'), findsOneWidget);
      expect(find.text('Pendentes'), findsOneWidget);
    });

    testWidgets(
      'mostra card do histórico, rodapé e botão de sair que desloga',
      (tester) async {
        await montar(tester);
        // Conteúdo abaixo da dobra: rola a lista até aparecer. O fixture não
        // tem schemaVersion (upload v1) → card de aviso pedindo reenvio, com o
        // link alternativo do site.
        await tester.scrollUntilVisible(
          find.textContaining('versão antiga'),
          200,
        );
        expect(find.text('Reenviar histórico'), findsOneWidget);
        expect(find.textContaining('ou use o site'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('NoFluxoUNB • dados do SIGAA via importação de histórico'),
          200,
        );

        await tester.scrollUntilVisible(find.text('Sair da conta'), -200);
        await tester.tap(find.text('Sair da conta'));
        await tester.pumpAndSettle();
        expect(fake.logoutChamado, isTrue);
      },
    );
  });

  group('PerfilScreen visitante', () {
    testWidgets('convida a entrar e o botão sai do modo visitante', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(const AuthState.anonymous());
      await tester.pumpWidget(_app([authProvider.overrideWith(() => fake)]));
      await tester.pumpAndSettle();

      expect(find.text('Você está no modo visitante'), findsOneWidget);
      expect(find.text('Entrar ou criar conta'), findsOneWidget);
      // Nada de conteúdo de usuário logado.
      expect(find.text('Progresso do curso'), findsNothing);
      expect(find.text('Sair da conta'), findsNothing);

      await tester.tap(find.text('Entrar ou criar conta'));
      await tester.pumpAndSettle();
      // O router real redireciona para /login quando o estado vira loggedOut.
      expect(fake.logoutChamado, isTrue);
    });
  });
}
