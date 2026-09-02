import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/dev/dev_log.dart';
import 'package:no_fluxo_app/core/dev/dev_panel.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth fake que registra as chamadas do painel dev.
class _AuthFake extends AuthNotifier {
  String? emailRecebido;
  String? senhaRecebida;
  bool visitanteChamado = false;

  @override
  Future<AuthState> build() async => const AuthState.loggedOut();

  @override
  Future<String?> loginComEmail(String email, String senha) async {
    emailRecebido = email;
    senhaRecebida = senha;
    return null;
  }

  @override
  Future<void> entrarComoVisitante() async {
    visitanteChamado = true;
  }
}

void main() {
  setUp(() {
    DevLog.limpar();
    SharedPreferences.setMockInitialValues({});
  });

  group('DevLog', () {
    test('registra com timestamp e respeita o limite do buffer', () {
      DevLog.registrar('primeira');
      expect(DevLog.linhas.value.single, contains('primeira'));
      expect(DevLog.linhas.value.single, matches(r'^\[\d{2}:\d{2}:\d{2}\] '));

      for (var i = 0; i < 400; i++) {
        DevLog.registrar('linha $i');
      }
      expect(DevLog.linhas.value.length, 300);
      expect(DevLog.linhas.value.last, contains('linha 399'));
    });

    test('limpar zera o buffer e textoCompleto junta as linhas', () {
      DevLog.registrar('a');
      DevLog.registrar('b');
      expect(DevLog.textoCompleto.split('\n').length, 2);
      DevLog.limpar();
      expect(DevLog.linhas.value, isEmpty);
    });
  });

  group('DevPanel', () {
    testWidgets('login de 1 toque chama loginComEmail e lembra credenciais', (
      tester,
    ) async {
      final auth = _AuthFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: Scaffold(body: DevPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail da conta de teste'),
        'teste@unb.br',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha'),
        'senha123',
      );
      await tester.tap(find.text('Entrar com a conta de teste'));
      await tester.pumpAndSettle();

      expect(auth.emailRecebido, 'teste@unb.br');
      expect(auth.senhaRecebida, 'senha123');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev_panel_email'), 'teste@unb.br');
    });

    testWidgets('botões de conta pré-definida logam com 1 toque', (
      tester,
    ) async {
      final auth = _AuthFake();
      const contas = [
        ContaDev(
          rotulo: 'Entrar como Aluno',
          icone: Icons.school_outlined,
          email: 'aluno@teste.dev',
          senha: 'senha-aluno',
        ),
        ContaDev(
          rotulo: 'Entrar como Admin',
          icone: Icons.admin_panel_settings_outlined,
          email: 'admin@teste.dev',
          senha: 'senha-admin',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: DevPanel(contas: contas)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entrar como Admin'), findsOneWidget);
      await tester.tap(find.text('Entrar como Aluno'));
      await tester.pumpAndSettle();

      expect(auth.emailRecebido, 'aluno@teste.dev');
      expect(auth.senhaRecebida, 'senha-aluno');
      // Conta pré-definida não sobrescreve as credenciais lembradas.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev_panel_email'), isNull);
    });

    testWidgets('atalho de visitante chama entrarComoVisitante', (
      tester,
    ) async {
      final auth = _AuthFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: Scaffold(body: DevPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrar como visitante'));
      await tester.pumpAndSettle();
      expect(auth.visitanteChamado, true);
    });

    testWidgets('campos vazios mostram erro em vez de chamar o login', (
      tester,
    ) async {
      final auth = _AuthFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => auth)],
          child: const MaterialApp(home: Scaffold(body: DevPanel())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrar com a conta de teste'));
      await tester.pumpAndSettle();
      expect(auth.emailRecebido, isNull);
      expect(find.textContaining('Preencha e-mail e senha'), findsOneWidget);
    });
  });

  group('DevLogViewer', () {
    testWidgets('mostra as linhas registradas e destaca erros', (tester) async {
      DevLog.registrar('carregando turmas');
      DevLog.registrar('FLUTTER ERROR: algo quebrou');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DevLogViewer())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('carregando turmas'), findsOneWidget);
      expect(find.textContaining('algo quebrou'), findsOneWidget);
    });
  });
}
