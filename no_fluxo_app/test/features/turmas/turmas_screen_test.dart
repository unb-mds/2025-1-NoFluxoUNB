import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_providers.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_repository.dart';
import 'package:no_fluxo_app/features/turmas/ui/turmas_screen.dart';

import 'fakes.dart';

Widget _criarApp({
  required TurmasRepository repo,
  required bool logado,
  String? codigoInicial,
}) {
  return ProviderScope(
    overrides: [
      turmasRepositoryProvider.overrideWithValue(repo),
      estaLogadoProvider.overrideWithValue(logado),
    ],
    child: MaterialApp(home: TurmasScreen(codigoInicial: codigoInicial)),
  );
}

FakeTurmasRepository _repoComOferta() {
  return FakeTurmasRepository(
    materias: [materiaCic0004()],
    turmasPorMateria: {
      1: [
        turmaExemplo(
          idTurmas: 10,
          turma: '01',
          vagasSobrando: 5,
          lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        turmaExemplo(idTurmas: 11, turma: '02', vagasSobrando: 0),
      ],
    },
  );
}

/// Abre a tela já com a busca preenchida e entra na matéria CIC0004.
Future<void> _abrirMateria(
  WidgetTester tester,
  FakeTurmasRepository repo, {
  bool logado = true,
}) async {
  await tester.pumpWidget(
    _criarApp(repo: repo, logado: logado, codigoInicial: 'CIC0004'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Algoritmos e Programação de Computadores'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Viewport alto: os cards de turma cabem sem precisar rolar.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> usarTelaAlta(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('?codigo pré-preenche a busca e lista a matéria', (tester) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();

    await tester.pumpWidget(
      _criarApp(repo: repo, logado: true, codigoInicial: 'CIC0004'),
    );
    await tester.pumpAndSettle();

    // Campo preenchido + resultado da busca na lista.
    expect(find.widgetWithText(TextField, 'CIC0004'), findsOneWidget);
    expect(
      find.text('Algoritmos e Programação de Computadores'),
      findsOneWidget,
    );
  });

  testWidgets('busca digitada dispara após o debounce', (tester) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();

    await tester.pumpWidget(_criarApp(repo: repo, logado: true));
    await tester.enterText(find.byType(TextField), 'algoritmos');

    // Antes do debounce nada mudou.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Algoritmos e Programação de Computadores'), findsNothing);

    // Depois do debounce a busca resolve.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.text('Algoritmos e Programação de Computadores'),
      findsOneWidget,
    );
  });

  testWidgets('cards de turma mostram docente, horário humanizado, local, '
      'badge de vagas e "atualizado há"', (tester) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();
    await _abrirMateria(tester, repo);

    expect(find.text('Turma 01'), findsOneWidget);
    expect(find.text('Turma 02'), findsOneWidget);
    expect(find.text('FULANO DE TAL'), findsNWidgets(2));
    // describeHorario("246M12") → Seg/Qua/Sex 08:00–09:50.
    expect(find.text('Seg/Qua/Sex 08:00–09:50'), findsNWidgets(2));
    expect(find.text('PJC BT 076'), findsNWidgets(2));
    // Badge verde (5 vagas) e vermelho (sem vagas).
    expect(find.text('5 vagas'), findsOneWidget);
    expect(find.text('Sem vagas'), findsOneWidget);
    // Frescor do dado (só a turma 01 tem last_updated_at).
    expect(find.text('atualizado há 5 min'), findsOneWidget);
  });

  testWidgets('seguir turma específica chama a RPC com a turma certa', (
    tester,
  ) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();
    await _abrirMateria(tester, repo);

    // Botões por turma têm o rótulo curto (o da matéria tem o sufixo
    // "(qualquer turma)").
    await tester.tap(find.text('Avisar quando abrir vaga').first);
    await tester.pumpAndSettle();

    expect(repo.chamadasSeguir, [
      (idMateria: 1, turma: '01', anoPeriodo: '2026.1'),
    ]);
    // Botão vira estado ativo.
    expect(find.text('Seguindo — toque para desfazer'), findsOneWidget);
  });

  testWidgets('seguir a matéria inteira chama a RPC com turma nula', (
    tester,
  ) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();
    await _abrirMateria(tester, repo);

    await tester.tap(find.text('Avisar quando abrir vaga (qualquer turma)'));
    await tester.pumpAndSettle();

    expect(repo.chamadasSeguir, [
      (idMateria: 1, turma: null, anoPeriodo: '2026.1'),
    ]);
  });

  testWidgets('tocar num botão ativo desfaz a assinatura', (tester) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();
    await _abrirMateria(tester, repo);

    await tester.tap(find.text('Avisar quando abrir vaga').first);
    await tester.pumpAndSettle();
    final idCriado = repo.assinaturas.single.idAssinatura;

    await tester.tap(find.text('Seguindo — toque para desfazer'));
    await tester.pumpAndSettle();

    expect(repo.chamadasDeixarDeSeguir, [idCriado]);
    expect(repo.assinaturas, isEmpty);
    expect(find.text('Seguindo — toque para desfazer'), findsNothing);
  });

  testWidgets('visitante vê botões desabilitados com a dica de login', (
    tester,
  ) async {
    await usarTelaAlta(tester);
    final repo = _repoComOferta();
    await _abrirMateria(tester, repo, logado: false);

    // Todos os botões de seguir estão desabilitados.
    final botoes = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .toList();
    expect(botoes, isNotEmpty);
    for (final botao in botoes) {
      expect(botao.onPressed, isNull);
    }
    // Dica aparece (matéria + 2 turmas).
    expect(find.text('Entre para ser avisado'), findsNWidgets(3));

    // E nenhuma RPC é chamada num toque.
    await tester.tap(find.text('Avisar quando abrir vaga').first);
    await tester.pumpAndSettle();
    expect(repo.chamadasSeguir, isEmpty);
  });

  testWidgets('matéria sem oferta mostra o aviso de período', (tester) async {
    await usarTelaAlta(tester);
    final repo = FakeTurmasRepository(
      materias: [materiaCic0004()],
      turmasPorMateria: const {},
    );
    await _abrirMateria(tester, repo);

    expect(
      find.text('Nenhuma turma ofertada no período atual.'),
      findsOneWidget,
    );
  });
}
