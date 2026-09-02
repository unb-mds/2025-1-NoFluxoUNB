import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/perfil/ui/perfil_screen.dart';

/// Auth fake: sessão válida mas perfil ainda inacessível (boot offline).
class _AuthSemPerfil extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.loggedInSemPerfil();
}

void main() {
  testWidgets(
    'boot offline logado NÃO vira tela de visitante — mostra o estado real',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(_AuthSemPerfil.new)],
          child: const MaterialApp(home: PerfilScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('seu perfil ainda não pôde ser carregado'),
        findsOneWidget,
      );
      expect(find.text('Sair da conta'), findsOneWidget);
      // Nada de convite de visitante para quem está logado.
      expect(find.textContaining('visitante'), findsNothing);
      expect(find.text('Entrar ou criar conta'), findsNothing);
    },
  );
}
