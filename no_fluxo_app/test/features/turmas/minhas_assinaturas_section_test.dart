import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/assinatura_model.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_providers.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_repository.dart';
import 'package:no_fluxo_app/features/turmas/ui/minhas_assinaturas_section.dart';

import 'fakes.dart';

Widget _criarApp({required TurmasRepository repo, required bool logado}) {
  return ProviderScope(
    overrides: [
      turmasRepositoryProvider.overrideWithValue(repo),
      estaLogadoProvider.overrideWithValue(logado),
    ],
    child: const MaterialApp(home: Scaffold(body: MinhasAssinaturasSection())),
  );
}

void main() {
  const qualquerTurma = AssinaturaModel(
    idAssinatura: 1,
    idMateria: 1,
    codigoMateria: 'CIC0004',
    nomeMateria: 'Algoritmos e Programação de Computadores',
    turma: null,
    anoPeriodo: '2026.1',
  );
  const turmaEspecifica = AssinaturaModel(
    idAssinatura: 2,
    idMateria: 2,
    codigoMateria: 'MAT0025',
    nomeMateria: 'Cálculo 1',
    turma: '05',
    anoPeriodo: '2026.1',
  );

  testWidgets('lista as assinaturas ativas com o alvo de cada uma', (
    tester,
  ) async {
    final repo = FakeTurmasRepository(
      assinaturas: [qualquerTurma, turmaEspecifica],
    );

    await tester.pumpWidget(_criarApp(repo: repo, logado: true));
    await tester.pumpAndSettle();

    expect(
      find.text('CIC0004 — Algoritmos e Programação de Computadores'),
      findsOneWidget,
    );
    expect(find.text('MAT0025 — Cálculo 1'), findsOneWidget);
    expect(find.text('Qualquer turma · 2026.1'), findsOneWidget);
    expect(find.text('Turma 05 · 2026.1'), findsOneWidget);
  });

  testWidgets('remover chama a RPC certa e tira o item da lista', (
    tester,
  ) async {
    final repo = FakeTurmasRepository(
      assinaturas: [qualquerTurma, turmaEspecifica],
    );

    await tester.pumpWidget(_criarApp(repo: repo, logado: true));
    await tester.pumpAndSettle();

    // Remove a primeira assinatura (CIC0004).
    await tester.tap(find.byTooltip('Deixar de seguir').first);
    await tester.pumpAndSettle();

    expect(repo.chamadasDeixarDeSeguir, [1]);
    expect(
      find.text('CIC0004 — Algoritmos e Programação de Computadores'),
      findsNothing,
    );
    expect(find.text('MAT0025 — Cálculo 1'), findsOneWidget);
  });

  testWidgets('sem assinaturas mostra o estado vazio', (tester) async {
    final repo = FakeTurmasRepository();

    await tester.pumpWidget(_criarApp(repo: repo, logado: true));
    await tester.pumpAndSettle();

    expect(find.text('Você ainda não segue nenhuma matéria'), findsOneWidget);
  });

  testWidgets('visitante vê o convite de login', (tester) async {
    final repo = FakeTurmasRepository(assinaturas: [qualquerTurma]);

    await tester.pumpWidget(_criarApp(repo: repo, logado: false));
    await tester.pumpAndSettle();

    expect(find.text('Entre para ser avisado'), findsOneWidget);
    // Nada da lista é mostrado.
    expect(
      find.text('CIC0004 — Algoritmos e Programação de Computadores'),
      findsNothing,
    );
  });
}
