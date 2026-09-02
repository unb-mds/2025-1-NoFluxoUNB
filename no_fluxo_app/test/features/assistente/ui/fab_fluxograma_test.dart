import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/curso_model.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/assistente/data/assistente_repository.dart';
import 'package:no_fluxo_app/features/fluxograma/data/fluxograma_repository.dart';
import 'package:no_fluxo_app/features/fluxograma/ui/fluxograma_screen.dart';

import '../fakes.dart';

/// Repositório de fluxograma vazio — aqui só interessa o FAB da tela.
class FluxogramaRepositorioVazio implements FluxogramaRepository {
  @override
  Future<List<CursoResumo>> buscarCursos() async => const [];

  @override
  Future<List<MatrizResumo>> buscarMatrizes(int idCurso) async => const [];

  @override
  Future<MatrizResumo?> buscarMatrizPorCurriculo(
    String curriculoCompleto,
  ) async => null;

  @override
  Future<CursoModel> buscarCursoDaMatriz(MatrizResumo matriz) async =>
      throw UnimplementedError();
}

Widget appDeTeste({required AuthNotifier Function() auth}) {
  return ProviderScope(
    overrides: [
      fluxogramaRepositoryProvider.overrideWithValue(
        FluxogramaRepositorioVazio(),
      ),
      assistenteRepositoryProvider.overrideWithValue(
        FakeAssistenteRepository(),
      ),
      authProvider.overrideWith(auth),
    ],
    child: const MaterialApp(home: FluxogramaScreen()),
  );
}

void main() {
  testWidgets('logado vê o FAB do assistente e ele abre o chat', (
    tester,
  ) async {
    await tester.pumpWidget(appDeTeste(auth: FakeAuthLogado.new));
    await tester.pumpAndSettle();

    final fab = find.byTooltip('Assistente IA');
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Chat aberto por cima (Navigator.push), começando limpo com sugestões.
    expect(find.text('Oi! Eu sou o Darcy'), findsOneWidget);
    expect(find.text('O que falta para eu me formar?'), findsOneWidget);
  });

  testWidgets('visitante não vê o FAB do assistente', (tester) async {
    await tester.pumpWidget(appDeTeste(auth: FakeAuthVisitante.new));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Assistente IA'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
