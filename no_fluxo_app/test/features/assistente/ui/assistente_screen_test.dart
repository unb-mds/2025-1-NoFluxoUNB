import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/assistente/data/assistente_repository.dart';
import 'package:no_fluxo_app/features/assistente/ui/assistente_screen.dart';

import '../fakes.dart';

/// App de teste com rotas mínimas para verificar as navegações da tela.
Widget appDeTeste({
  required FakeAssistenteRepository repo,
  AuthNotifier Function()? auth,
}) {
  final router = GoRouter(
    initialLocation: '/assistente',
    routes: [
      GoRoute(path: '/assistente', builder: (_, _) => const AssistenteScreen()),
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
      assistenteRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(auth ?? FakeAuthLogado.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> enviarPeloCampo(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('chat-campo')), texto);
  await tester.tap(find.byKey(const Key('chat-enviar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('visitante vê tela pedindo login e botão leva para /login', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository();
    await tester.pumpWidget(
      appDeTeste(repo: repo, auth: FakeAuthVisitante.new),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entre para conversar com o Darcy'), findsOneWidget);
    expect(find.byKey(const Key('chat-campo')), findsNothing);

    await tester.tap(find.text('Fazer login'));
    await tester.pumpAndSettle();
    expect(find.text('destino-login'), findsOneWidget);
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('tela começa limpa com as 3 sugestões; tocar uma envia', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository(
      resposta: 'Faltam **4 matérias** para você se formar.',
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('O que falta para eu me formar?'), findsOneWidget);
    expect(find.text('Me recomenda optativas de IA'), findsOneWidget);
    expect(find.text('Quais turmas de CIC0007 têm vaga?'), findsOneWidget);

    await tester.tap(find.text('O que falta para eu me formar?'));
    await tester.pumpAndSettle();

    // A sugestão virou a mensagem enviada…
    expect(repo.chamadas.single.mensagem, 'O que falta para eu me formar?');
    // …as sugestões sumiram e a resposta (com negrito) foi renderizada.
    expect(find.text('Me recomenda optativas de IA'), findsNothing);
    expect(
      find.textContaining('4 matérias', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('envio pelo campo manda a matriz curricular como currículo', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository(resposta: 'Anotado!');
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'Quantos créditos eu tenho?');

    expect(repo.chamadas.single.mensagem, 'Quantos créditos eu tenho?');
    expect(repo.chamadas.single.curriculo, '8899/2');
    expect(find.text('Quantos créditos eu tenho?'), findsOneWidget);
    expect(find.text('Anotado!'), findsOneWidget);
  });

  testWidgets('logado sem histórico envia sem curriculoCompleto', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository();
    await tester.pumpWidget(
      appDeTeste(
        repo: repo,
        auth: () => FakeAuthLogado(matrizCurricular: null),
      ),
    );
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'oi');
    expect(repo.chamadas.single.curriculo, isNull);
  });

  testWidgets('enquanto espera mostra "O Darcy está pensando…"', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository()..pendente = Completer<String>();
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat-campo')), 'oi Darcy');
    await tester.tap(find.byKey(const Key('chat-enviar')));
    await tester.pump();

    expect(find.text('O Darcy está pensando…'), findsOneWidget);

    repo.pendente!.complete('Cheguei!');
    await tester.pumpAndSettle();

    expect(find.text('O Darcy está pensando…'), findsNothing);
    expect(find.text('Cheguei!'), findsOneWidget);
  });

  testWidgets('badge de código na resposta navega para /turmas?codigo=X', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository(
      resposta: 'Recomendo CIC0007 no próximo semestre.',
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'o que cursar?');
    expect(find.text('CIC0007'), findsOneWidget);

    await tester.tap(find.text('CIC0007'));
    await tester.pumpAndSettle();
    expect(find.text('destino-turmas:CIC0007'), findsOneWidget);
  });

  testWidgets('[TURMA|...] vira card com horário humanizado', (tester) async {
    final repo = FakeAssistenteRepository(
      resposta: 'Achei:\n[TURMA|01|Edson Alves|35T23|PJC BT-104|10|2025.2]',
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'turmas de apc?');

    expect(find.text('Turma 01'), findsOneWidget);
    expect(find.text('Edson Alves'), findsOneWidget);
    // 35T23 → terça/quinta, T2–T3 (14:00 às 15:50).
    expect(find.text('Ter/Qui 14:00–15:50'), findsOneWidget);
    expect(find.text('PJC BT-104'), findsOneWidget);
    expect(find.text('10 vagas'), findsOneWidget);
    expect(find.text('2025.2'), findsOneWidget);
  });

  testWidgets('[BOTAO|...] envia a mensagem do botão ao tocar', (tester) async {
    final repo = FakeAssistenteRepository(
      resposta: 'Quer ver mais?\n[BOTAO|Ver mais|quero mais turmas]',
    );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'turmas de calculo');
    expect(find.text('Ver mais'), findsOneWidget);

    repo.resposta = 'Aqui vão mais turmas!';
    await tester.tap(find.text('Ver mais'));
    await tester.pumpAndSettle();

    expect(repo.chamadas.last.mensagem, 'quero mais turmas');
    expect(find.text('Aqui vão mais turmas!'), findsOneWidget);
  });

  testWidgets('erro vira mensagem do sistema com "Tentar de novo"', (
    tester,
  ) async {
    final repo = FakeAssistenteRepository()
      ..erro = const AssistenteException(
        'O assistente está indisponível no momento. Tente mais tarde.',
      );
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await enviarPeloCampo(tester, 'oi Darcy');

    expect(
      find.text('O assistente está indisponível no momento. Tente mais tarde.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);

    // Voltando o serviço, o retry reenvia a MESMA mensagem sem duplicar a
    // bolha do usuário.
    repo.erro = null;
    repo.resposta = 'Voltei!';
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, hasLength(2));
    expect(repo.chamadas.last.mensagem, 'oi Darcy');
    expect(find.text('oi Darcy'), findsOneWidget);
    expect(find.text('Voltei!'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('mensagem vazia não é enviada', (tester) async {
    final repo = FakeAssistenteRepository();
    await tester.pumpWidget(appDeTeste(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat-enviar')));
    await tester.pumpAndSettle();
    expect(repo.chamadas, isEmpty);
  });
}
