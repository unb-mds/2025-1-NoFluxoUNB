import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/theme/app_colors.dart';
import 'package:no_fluxo_app/features/suporte/data/suporte_repository.dart';
import 'package:no_fluxo_app/features/suporte/data/ticket_model.dart';
import 'package:no_fluxo_app/features/suporte/ui/suporte_screen.dart';

import 'fakes.dart';

Widget _app(FakeSuporteRepository repo) {
  return ProviderScope(
    overrides: [suporteRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: SuporteScreen()),
  );
}

void main() {
  group('cores de status', () {
    test('aberto âmbar, em andamento azul, resolvido verde, fechado cinza', () {
      expect(corDoStatusTicket('aberto'), Colors.amber);
      expect(corDoStatusTicket('em_andamento'), AppColors.destaqueEquivalencia);
      expect(corDoStatusTicket('resolvido'), Colors.green);
      expect(corDoStatusTicket('fechado'), AppColors.mutedForeground);
      // Desconhecido degrada para cinza.
      expect(corDoStatusTicket('zzz'), AppColors.mutedForeground);
    });
  });

  group('lista de chamados', () {
    testWidgets('renderiza títulos, categorias e chips de status', (
      tester,
    ) async {
      final repo = FakeSuporteRepository(
        tickets: [
          ticketDeTeste(id: 1, title: 'App fecha sozinho', status: 'aberto'),
          ticketDeTeste(
            id: 2,
            title: 'Ideia: modo claro',
            status: 'resolvido',
            category: 'sugestao',
          ),
        ],
      );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Meus chamados'), findsOneWidget);
      expect(find.text('App fecha sozinho'), findsOneWidget);
      expect(find.text('Ideia: modo claro'), findsOneWidget);
      expect(find.text('Aberto'), findsOneWidget);
      expect(find.text('Resolvido'), findsOneWidget);
      expect(find.textContaining('Sugestão'), findsOneWidget);
      expect(find.text('Novo chamado'), findsOneWidget); // FAB
    });

    testWidgets('sem chamados mostra estado vazio', (tester) async {
      await tester.pumpWidget(_app(FakeSuporteRepository()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Você ainda não abriu nenhum chamado'),
        findsOneWidget,
      );
    });

    testWidgets('erro ao listar mostra mensagem de falha', (tester) async {
      final repo = FakeSuporteRepository()..erroAoListar = Exception('rede');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Não foi possível carregar seus chamados'),
        findsOneWidget,
      );
    });
  });

  group('novo chamado', () {
    testWidgets(
      'fluxo feliz: preenche, envia, chama o repo e mostra snackbar',
      (tester) async {
        final repo = FakeSuporteRepository();
        await tester.pumpWidget(_app(repo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Novo chamado'));
        await tester.pumpAndSettle();

        // Categoria via SegmentedButton.
        await tester.tap(find.text('Sugestão'));
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Título'),
          'Modo claro',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Descrição'),
          'Queria usar o app de dia',
        );
        await tester.tap(find.text('Enviar chamado'));
        await tester.pumpAndSettle();

        expect(repo.chamadasCriar, hasLength(1));
        final chamada = repo.chamadasCriar.single;
        expect(chamada.title, 'Modo claro');
        expect(chamada.description, 'Queria usar o app de dia');
        expect(chamada.categoria, TicketCategoria.sugestao);

        // Voltou para a lista, com snackbar de sucesso e o ticket novo.
        expect(find.textContaining('Chamado enviado'), findsOneWidget);
        expect(find.text('Modo claro'), findsOneWidget);
      },
    );

    testWidgets('título e descrição são obrigatórios', (tester) async {
      final repo = FakeSuporteRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo chamado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar chamado'));
      await tester.pumpAndSettle();

      expect(find.text('Dê um título ao chamado'), findsOneWidget);
      expect(find.text('Descreva o chamado'), findsOneWidget);
      expect(repo.chamadasCriar, isEmpty);
    });

    testWidgets('falha no envio mantém o form e avisa', (tester) async {
      final repo = FakeSuporteRepository()..erroAoCriar = Exception('rls');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo chamado'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Bug',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Detalhes',
      );
      await tester.tap(find.text('Enviar chamado'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Não foi possível enviar seu chamado'),
        findsOneWidget,
      );
      // Continua na tela do form (não fez pop).
      expect(find.text('Enviar chamado'), findsOneWidget);
    });
  });
}
