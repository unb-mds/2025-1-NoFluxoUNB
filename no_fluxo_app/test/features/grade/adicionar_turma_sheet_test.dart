import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/core/widgets/vagas_badge.dart';
import 'package:no_fluxo_app/features/grade/data/grade_repository.dart';
import 'package:no_fluxo_app/features/grade/domain/grade_builder.dart';
import 'package:no_fluxo_app/features/grade/ui/adicionar_turma_sheet.dart';

/// Repositório fake: busca e turmas em memória (lista vazia simula o RLS
/// devolvendo zero linhas sem erro para visitante).
class _GradeRepositoryFake implements GradeRepository {
  final List<MateriaBusca> materias;
  final List<TurmaModel> turmas;

  _GradeRepositoryFake({this.materias = const [], this.turmas = const []});

  @override
  Future<List<TurmaGrade>> carregarGrade({
    DadosFluxogramaUser? dados,
    required int idUser,
  }) async => const [];

  @override
  Future<void> adicionarTurmaManual({
    required int idUser,
    required TurmaModel turma,
  }) async {}

  @override
  Future<void> removerTurmaManual({
    required int idUser,
    required int idTurmas,
  }) async {}

  @override
  Future<List<MateriaBusca>> buscarMaterias(String query) async => materias;

  @override
  Future<List<TurmaModel>> turmasDaMateria(int idMateria) async => turmas;
}

Widget _app({required GradeRepository repo, required bool logado}) {
  return ProviderScope(
    overrides: [
      gradeRepositoryProvider.overrideWithValue(repo),
      estaLogadoProvider.overrideWithValue(logado),
    ],
    child: const MaterialApp(home: Scaffold(body: AdicionarTurmaSheet())),
  );
}

/// Digita [termo] e espera o debounce da busca (350 ms) resolver.
Future<void> _buscar(WidgetTester tester, String termo) async {
  await tester.enterText(find.byType(TextField), termo);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'visitante que busca vê o aviso de login (não o vazio genérico)',
    (tester) async {
      await tester.pumpWidget(
        _app(repo: _GradeRepositoryFake(), logado: false),
      );

      await _buscar(tester, 'calculo');

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
        find.textContaining('Entre com sua conta para buscar turmas'),
        findsOneWidget,
      );
      expect(find.textContaining('Digite ao menos 2 caracteres'), findsNothing);
    },
  );

  testWidgets('logado com busca sem resultado mantém a dica genérica', (
    tester,
  ) async {
    await tester.pumpWidget(_app(repo: _GradeRepositoryFake(), logado: true));

    await _buscar(tester, 'calculo');

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.textContaining('Digite ao menos 2 caracteres'), findsOneWidget);
  });

  testWidgets('lista de turmas usa o VagasBadge compartilhado', (tester) async {
    final repo = _GradeRepositoryFake(
      materias: const [
        MateriaBusca(idMateria: 1, codigo: 'MAT0025', nome: 'Cálculo 1'),
      ],
      turmas: const [
        TurmaModel(
          idTurmas: 10,
          idMateria: 1,
          turma: '01',
          horario: '2M12',
          anoPeriodo: '2026.1',
          vagasSobrando: 2,
          codigoMateria: 'MAT0025',
          nomeMateria: 'Cálculo 1',
        ),
      ],
    );

    await tester.pumpWidget(_app(repo: repo, logado: true));
    await _buscar(tester, 'calculo');

    await tester.tap(find.text('MAT0025'));
    await tester.pumpAndSettle();

    expect(find.byType(VagasBadge), findsOneWidget);
    expect(find.text('2 vagas'), findsOneWidget);
  });
}
