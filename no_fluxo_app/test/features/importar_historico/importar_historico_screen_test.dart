import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/pdf/historico_pdf_parser.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/importar_historico/data/importar_historico_repository.dart';
import 'package:no_fluxo_app/features/importar_historico/data/selecionador_arquivo.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/casamento.dart';
import 'package:no_fluxo_app/features/importar_historico/providers/importar_historico_controller.dart';
import 'package:no_fluxo_app/features/importar_historico/ui/importar_historico_screen.dart';

import 'fakes.dart';

void main() {
  late FakeParser parser;
  late FakeRepositorio repo;
  late FakeAuthNotifier auth;
  late FakeSelecionador selecionador;

  setUp(() {
    parser = FakeParser();
    repo = FakeRepositorio();
    auth = FakeAuthNotifier(AuthState.loggedIn(userFixture()));
    selecionador = FakeSelecionador();
  });

  Future<ProviderContainer> montarApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        historicoPdfParserProvider.overrideWithValue(parser),
        importarHistoricoRepositoryProvider.overrideWithValue(repo),
        selecionadorDeArquivoProvider.overrideWithValue(selecionador),
        authProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/importar-historico',
      routes: [
        GoRoute(
          path: '/importar-historico',
          builder: (_, _) => const ImportarHistoricoScreen(),
        ),
        GoRoute(
          path: '/fluxograma',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('TELA FLUXOGRAMA'))),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // Rola até o widget (a tela é mais alta que o viewport de teste) e toca.
  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // Deixa o timer de auto-dismiss do SnackBar disparar antes do fim do teste.
  Future<void> varrerSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  ArquivoPdfSelecionado arquivoValido() => ArquivoPdfSelecionado(
    nome: 'historico.pdf',
    tamanhoBytes: 3,
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  group('estado inicial', () {
    testWidgets('mostra os textos do site e as ações', (tester) async {
      await montarApp(tester);

      expect(find.text('Importar histórico'), findsOneWidget);
      expect(
        find.textContaining('Envie o PDF do seu histórico oficial da UnB'),
        findsOneWidget,
      );
      expect(find.text('Selecionar arquivo'), findsOneWidget);
      expect(find.text('Preencha manualmente'), findsOneWidget);
      expect(find.text('Como obter seu histórico acadêmico?'), findsOneWidget);
      expect(find.textContaining('Somente PDF (máx. 10MB)'), findsOneWidget);
    });

    testWidgets('onboarding (sem fluxograma) mostra "Agora não"', (
      tester,
    ) async {
      await montarApp(tester);
      expect(find.text('Agora não'), findsOneWidget);
    });

    testWidgets('reenvio (já tem fluxograma) NÃO mostra "Agora não"', (
      tester,
    ) async {
      auth = FakeAuthNotifier(
        AuthState.loggedIn(userFixture(dados: DadosFluxogramaUser())),
      );
      await montarApp(tester);
      expect(find.text('Agora não'), findsNothing);
    });

    testWidgets('"Agora não" seta o flag da sessão e volta ao fluxograma', (
      tester,
    ) async {
      final container = await montarApp(tester);

      await tocar(tester, find.text('Agora não'));

      expect(container.read(adiouImportacaoProvider), isTrue);
      expect(find.text('TELA FLUXOGRAMA'), findsOneWidget);
    });
  });

  group('validação de arquivo (mensagens do site)', () {
    testWidgets('extensão errada', (tester) async {
      await montarApp(tester);
      selecionador.proximoArquivo = ArquivoPdfSelecionado(
        nome: 'historico.docx',
        tamanhoBytes: 10,
        bytes: Uint8List.fromList([1]),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Formato inválido. Somente arquivos PDF são aceitos.'),
        findsOneWidget,
      );
      expect(parser.chamadas, 0);
      await varrerSnackBars(tester);
    });

    testWidgets('maior que 10MB', (tester) async {
      await montarApp(tester);
      selecionador.proximoArquivo = ArquivoPdfSelecionado(
        nome: 'historico.pdf',
        tamanhoBytes: 12 * 1024 * 1024,
        bytes: Uint8List(12 * 1024 * 1024),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Arquivo muito grande (12.0MB). O tamanho máximo é 10MB.'),
        findsOneWidget,
      );
      await varrerSnackBars(tester);
    });

    testWidgets('arquivo vazio', (tester) async {
      await montarApp(tester);
      selecionador.proximoArquivo = ArquivoPdfSelecionado(
        nome: 'historico.pdf',
        tamanhoBytes: 0,
        bytes: Uint8List(0),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('O arquivo está vazio.'), findsOneWidget);
      await varrerSnackBars(tester);
    });
  });

  group('fluxo de sucesso', () {
    testWidgets('mostra os 4 stat cards e salva ao visualizar', (tester) async {
      final container = await montarApp(tester);
      selecionador.proximoArquivo = arquivoValido();
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Processamento concluído'), findsOneWidget);
      expect(find.text('Total de Obrigatórias'), findsOneWidget);
      expect(find.text('Concluídas (obrig.)'), findsOneWidget);
      expect(find.text('Pendentes (obrig.)'), findsOneWidget);
      expect(find.text('Optativas'), findsOneWidget);
      // Resumo recalculado: 2 obrigatórias (1 concluída + 1 pendente).
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Arquivo selecionado: historico.pdf'), findsOneWidget);

      await tocar(tester, find.text('Visualizar fluxograma'));

      expect(repo.salvamentos, hasLength(1));
      expect(auth.recarregamentos, 1);
      expect(find.text('TELA FLUXOGRAMA'), findsOneWidget);
      // Estado não interfere no teste seguinte.
      container.read(importarHistoricoControllerProvider.notifier).reset();
      await varrerSnackBars(tester);
    });

    testWidgets('"Enviar outro PDF" volta ao estado inicial', (tester) async {
      await montarApp(tester);
      selecionador.proximoArquivo = arquivoValido();
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Enviar outro PDF'));

      expect(find.text('Selecionar arquivo'), findsOneWidget);
    });
  });

  group('erro', () {
    testWidgets('mostra a mensagem e "Tentar novamente" reseta', (
      tester,
    ) async {
      await montarApp(tester);
      selecionador.proximoArquivo = arquivoValido();
      repo.enfileirarErro(
        const ImportarHistoricoException(kMsgTimeoutCasamento),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível processar'), findsOneWidget);
      expect(find.text(kMsgTimeoutCasamento), findsOneWidget);

      await tocar(tester, find.text('Tentar novamente'));

      expect(find.text('Selecionar arquivo'), findsOneWidget);
    });
  });

  group('seleção de curso', () {
    testWidgets('abre painel, busca sem acentos e confirma o retry', (
      tester,
    ) async {
      await montarApp(tester);
      selecionador.proximoArquivo = arquivoValido();
      repo.enfileirar(
        const CasamentoPrecisaDeCurso(
          SelecaoDeCurso(
            mensagem: 'Encontramos mais de um curso possível.',
            cursos: [
              OpcaoCurso(nomeCurso: 'CIÊNCIA DA COMPUTAÇÃO', idCurso: 1),
              OpcaoCurso(nomeCurso: 'ENGENHARIA DE SOFTWARE', idCurso: 42),
            ],
          ),
        ),
      );
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Selecionar Curso'), findsOneWidget);
      expect(find.text('ENGENHARIA DE SOFTWARE'), findsOneWidget);

      // Busca insensível a acento: "ciencia" acha "CIÊNCIA...".
      await tester.enterText(
        find.widgetWithText(TextField, 'Pesquisar curso...'),
        'ciencia da computacao',
      );
      await tester.pumpAndSettle();
      expect(find.text('CIÊNCIA DA COMPUTAÇÃO'), findsOneWidget);
      expect(find.text('ENGENHARIA DE SOFTWARE'), findsNothing);

      await tester.tap(find.text('CIÊNCIA DA COMPUTAÇÃO'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Confirmar'));

      expect(find.text('Processamento concluído'), findsOneWidget);
      final retry = repo.pDadosRecebidos[1];
      expect(retry['curso_selecionado'], 'CIÊNCIA DA COMPUTAÇÃO');
      expect(retry['id_curso_selecionado'], 1);
    });

    testWidgets('cancelar vira erro com a mensagem do site', (tester) async {
      await montarApp(tester);
      selecionador.proximoArquivo = arquivoValido();
      repo.enfileirar(
        const CasamentoPrecisaDeCurso(
          SelecaoDeCurso(
            mensagem: '',
            cursos: [OpcaoCurso(nomeCurso: 'A')],
          ),
        ),
      );

      await tester.tap(find.text('Selecionar arquivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Seleção de curso cancelada. Tente novamente.'),
        findsOneWidget,
      );
    });
  });

  group('modo manual', () {
    testWidgets('seleciona curso e salva fluxograma zerado', (tester) async {
      await montarApp(tester);
      repo.opcoesDeCurso = const [
        OpcaoCurso(
          nomeCurso: 'ENGENHARIA DE SOFTWARE',
          idCurso: 42,
          matrizCurricular: '6360/2 - 2017.1',
        ),
      ];

      await tester.tap(find.text('Preencha manualmente'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Neste modo, você preencherá as disciplinas'),
        findsOneWidget,
      );

      await tester.tap(find.text('ENGENHARIA DE SOFTWARE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(repo.salvamentos, hasLength(1));
      expect(repo.salvamentos.single.fluxogramaJson['matricula'], 'Manual');
      expect(auth.recarregamentos, 1);
      expect(find.text('TELA FLUXOGRAMA'), findsOneWidget);
      await varrerSnackBars(tester);
    });
  });
}
