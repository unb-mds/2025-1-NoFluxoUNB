import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:no_fluxo_app/core/config/release.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/perfil/data/perfil_repository.dart';
import 'package:no_fluxo_app/features/perfil/ui/novidades_dialog.dart';
import 'package:no_fluxo_app/features/perfil/ui/perfil_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth fake com o usuário injetado (varia o estado do histórico por teste).
class _FakeAuth extends AuthNotifier {
  final UserModel user;

  _FakeAuth(this.user);

  @override
  Future<AuthState> build() async => AuthState.loggedIn(user);
}

UserModel _user({DadosFluxogramaUser? dados}) {
  return UserModel(
    idUser: 1,
    email: 'ana@unb.br',
    nomeCompleto: 'Ana Silva',
    dadosFluxograma: dados,
  );
}

Widget _app(UserModel user) {
  final router = GoRouter(
    initialLocation: '/perfil',
    routes: [
      GoRoute(path: '/perfil', builder: (_, _) => const PerfilScreen()),
      GoRoute(
        path: '/importar-historico',
        builder: (_, _) =>
            const Scaffold(body: Text('TELA IMPORTAR HISTORICO')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuth(user)),
      progressoPerfilProvider.overrideWith((ref) => Future.value(null)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    // Novidades já vistas — o dialog não pode cobrir o card nos testes.
    SharedPreferences.setMockInitialValues({chaveReleaseVisto(1): kReleaseId});
  });

  testWidgets('sem histórico: CTA de importação que navega para a rota', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_user(dados: null)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Importe seu histórico para desbloquear fluxograma, progresso '
        'e grade',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ou use o site'), findsOneWidget);
    expect(find.text('Histórico importado'), findsNothing);

    await tester.tap(find.text('Importar histórico'));
    await tester.pumpAndSettle();
    expect(find.text('TELA IMPORTAR HISTORICO'), findsOneWidget);
  });

  testWidgets('histórico de schema antigo: aviso + reenviar', (tester) async {
    // schemaVersion null == v1 (upload anterior ao versionamento).
    final dados = DadosFluxogramaUser(nomeCurso: 'Eng. de Software');
    await tester.pumpWidget(_app(_user(dados: dados)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Seu histórico foi importado numa versão antiga — reenvie para '
        'ver equivalências e módulo livre',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ou use o site'), findsOneWidget);

    await tester.tap(find.text('Reenviar histórico'));
    await tester.pumpAndSettle();
    expect(find.text('TELA IMPORTAR HISTORICO'), findsOneWidget);
  });

  testWidgets('histórico atualizado: card ok + reenviar discreto', (
    tester,
  ) async {
    final dados = DadosFluxogramaUser(
      nomeCurso: 'Eng. de Software',
      schemaVersion: kFluxogramaSchemaVersion,
    );
    await tester.pumpWidget(_app(_user(dados: dados)));
    await tester.pumpAndSettle();

    expect(find.text('Histórico importado'), findsOneWidget);
    expect(find.text('Reenviar histórico'), findsOneWidget);
    expect(find.textContaining('ou use o site'), findsOneWidget);
    expect(find.textContaining('versão antiga'), findsNothing);

    await tester.tap(find.text('Reenviar histórico'));
    await tester.pumpAndSettle();
    expect(find.text('TELA IMPORTAR HISTORICO'), findsOneWidget);
  });
}
