import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/notificacoes/providers/notificacoes_provider.dart';
import 'package:no_fluxo_app/features/notificacoes/ui/notificacoes_screen.dart';

import 'fakes.dart';

/// App de teste com rotas mínimas para verificar as navegações da tela.
Widget appDeTeste({
  required FakeNotificacoesRepository repo,
  bool logado = true,
}) {
  final router = GoRouter(
    initialLocation: '/notificacoes',
    routes: [
      GoRoute(
        path: '/notificacoes',
        builder: (_, _) => const NotificacoesScreen(),
      ),
      GoRoute(
        path: '/turmas',
        builder: (_, state) => Scaffold(
          body: Text(
            'destino-turmas:${state.uri.queryParameters['codigo'] ?? ''}',
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('destino-login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      notificacoesRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        () => logado ? FakeAuthLogado() : FakeAuthVisitante(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('visitante vê tela pedindo login e botão leva para /login', (
    tester,
  ) async {
    final repo = FakeNotificacoesRepository(totalNaoLidas: 3);
    await tester.pumpWidget(appDeTeste(repo: repo, logado: false));
    await tester.pumpAndSettle();

    expect(find.text('Entre para receber avisos'), findsOneWidget);
    expect(find.text('Fazer login'), findsOneWidget);
    // Visitante não dispara chamadas ao banco.
    expect(repo.chamadasListar, 0);

    await tester.tap(find.text('Fazer login'));
    await tester.pumpAndSettle();
    expect(find.text('destino-login'), findsOneWidget);
  });

  testWidgets('lista mostra título, mensagem e dot roxo só nas não lidas', (
    tester,
  ) async {
    final repo = FakeNotificacoesRepository(
      notificacoes: [
        notificacaoDeTeste(
          id: 1,
          titulo: 'Vaga em Cálculo 1',
          mensagem: 'Abriu 1 vaga na turma 02',
        ),
        notificacaoDeTeste(
          id: 2,
          titulo: 'Vaga em APC',
          mensagem: 'Abriu 3 vagas',
          lida: true,
        ),
      ],
      totalNaoLidas: 1,
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Vaga em Cálculo 1'), findsOneWidget);
    expect(find.text('Abriu 1 vaga na turma 02'), findsOneWidget);
    expect(find.text('Vaga em APC'), findsOneWidget);
    expect(find.text('há 5 min'), findsNWidgets(2));

    // Dot roxo apenas na não lida (id 1).
    expect(find.byKey(const Key('dot-nao-lida-1')), findsOneWidget);
    expect(find.byKey(const Key('dot-nao-lida-2')), findsNothing);
  });

  testWidgets('estado vazio convida a seguir matéria e leva para /turmas', (
    tester,
  ) async {
    final repo = FakeNotificacoesRepository();
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma notificação'), findsOneWidget);
    expect(
      find.text('Siga uma matéria para ser avisado quando abrirem vagas.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver turmas'));
    await tester.pumpAndSettle();
    expect(find.text('destino-turmas:'), findsOneWidget);
  });

  testWidgets(
    'tocar numa não lida chama marcar_notificacao_lida e some o dot',
    (tester) async {
      final repo = FakeNotificacoesRepository(
        notificacoes: [notificacaoDeTeste(id: 5, titulo: 'Vaga em Cálculo 1')],
        totalNaoLidas: 1,
      );
      await tester.pumpWidget(appDeTeste(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vaga em Cálculo 1'));
      await tester.pumpAndSettle();

      expect(repo.chamadasMarcarLida, [5]);
      // Atualização otimista: o dot some sem precisar recarregar.
      expect(find.byKey(const Key('dot-nao-lida-5')), findsNothing);
    },
  );

  testWidgets(
    'tocar em notificação com codigo_materia navega para /turmas?codigo=XXX',
    (tester) async {
      final repo = FakeNotificacoesRepository(
        notificacoes: [
          notificacaoDeTeste(
            id: 6,
            titulo: 'Vaga em FGA0158',
            metadata: {'codigo_materia': 'FGA0158'},
          ),
        ],
        totalNaoLidas: 1,
      );
      await tester.pumpWidget(appDeTeste(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vaga em FGA0158'));
      await tester.pumpAndSettle();

      expect(repo.chamadasMarcarLida, [6]);
      expect(find.text('destino-turmas:FGA0158'), findsOneWidget);
    },
  );

  testWidgets('botão marca todas como lidas (RPC com null)', (tester) async {
    final repo = FakeNotificacoesRepository(
      notificacoes: [
        notificacaoDeTeste(id: 1, titulo: 'Vaga A'),
        notificacaoDeTeste(id: 2, titulo: 'Vaga B'),
      ],
      totalNaoLidas: 2,
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();

    expect(repo.chamadasMarcarLida, [null]);
    expect(find.byKey(const Key('dot-nao-lida-1')), findsNothing);
    expect(find.byKey(const Key('dot-nao-lida-2')), findsNothing);
    // Sem não lidas, o botão some.
    expect(find.text('Marcar todas como lidas'), findsNothing);
  });

  testWidgets('filtro "só não lidas" refaz a busca filtrada', (tester) async {
    final repo = FakeNotificacoesRepository(
      notificacoes: [
        notificacaoDeTeste(id: 1, titulo: 'Não lida ainda'),
        notificacaoDeTeste(id: 2, titulo: 'Já lida', lida: true),
      ],
      totalNaoLidas: 1,
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Já lida'), findsOneWidget);

    await tester.tap(find.text('Só não lidas'));
    await tester.pumpAndSettle();

    expect(repo.filtrosListagem.last, isTrue);
    expect(find.text('Não lida ainda'), findsOneWidget);
    expect(find.text('Já lida'), findsNothing);
  });

  testWidgets('erro na RPC mostra estado de erro com retry', (tester) async {
    final repo = FakeNotificacoesRepository()
      ..erroAoListar = Exception('sem rede');
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar as notificações'),
      findsOneWidget,
    );

    // Voltando a rede, o retry recarrega a lista.
    repo.erroAoListar = null;
    repo.notificacoes = [notificacaoDeTeste(id: 9, titulo: 'Voltou!')];
    repo.totalNaoLidas = 1;

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Voltou!'), findsOneWidget);
  });
}
