import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/config/release.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/perfil/data/perfil_repository.dart';
import 'package:no_fluxo_app/features/perfil/ui/novidades_dialog.dart';
import 'package:no_fluxo_app/features/perfil/ui/perfil_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthLogado extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return AuthState.loggedIn(
      UserModel(idUser: 1, email: 'ana@unb.br', nomeCompleto: 'Ana Silva'),
    );
  }

  @override
  Future<void> logout() async {
    state = const AsyncData(AuthState.loggedOut());
  }
}

class _FakeAuthVisitante extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.anonymous();
}

Widget _app({required AuthNotifier Function() auth}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(auth),
      progressoPerfilProvider.overrideWith((ref) => Future.value(null)),
    ],
    child: const MaterialApp(home: PerfilScreen()),
  );
}

void main() {
  testWidgets('mostra o dialog na 1ª visita e persiste o release visto', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(auth: _FakeAuthLogado.new));
    await tester.pumpAndSettle();

    expect(find.text(kNovidadesTitulo), findsOneWidget);
    expect(find.text(kNovidades.first), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text(kNovidadesTitulo), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveReleaseVisto(1)), kReleaseId);
  });

  testWidgets('NÃO mostra de novo quando o release já foi visto', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({chaveReleaseVisto(1): kReleaseId});
    await tester.pumpWidget(_app(auth: _FakeAuthLogado.new));
    await tester.pumpAndSettle();

    expect(find.text(kNovidadesTitulo), findsNothing);
  });

  testWidgets('release novo (string diferente) reabre o dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      chaveReleaseVisto(1): 'release-anterior',
    });
    await tester.pumpWidget(_app(auth: _FakeAuthLogado.new));
    await tester.pumpAndSettle();

    expect(find.text(kNovidadesTitulo), findsOneWidget);
  });

  testWidgets('item "Novidades" da seção de conta reabre manualmente', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({chaveReleaseVisto(1): kReleaseId});
    await tester.pumpWidget(_app(auth: _FakeAuthLogado.new));
    await tester.pumpAndSettle();
    expect(find.text(kNovidadesTitulo), findsNothing);

    await tester.scrollUntilVisible(find.text('Novidades'), 200);
    await tester.tap(find.text('Novidades'));
    await tester.pumpAndSettle();

    expect(find.text(kNovidadesTitulo), findsOneWidget);
  });

  testWidgets('logado vê o item "Suporte e feedback"', (tester) async {
    SharedPreferences.setMockInitialValues({chaveReleaseVisto(1): kReleaseId});
    await tester.pumpWidget(_app(auth: _FakeAuthLogado.new));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Suporte e feedback'), 200);
    expect(find.text('Suporte e feedback'), findsOneWidget);
  });

  testWidgets('visitante não vê suporte, novidades nem o dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(auth: _FakeAuthVisitante.new));
    await tester.pumpAndSettle();
    expect(find.text('Suporte e feedback'), findsNothing);
    expect(find.text('Novidades'), findsNothing);
    expect(find.text(kNovidadesTitulo), findsNothing);
  });
}
