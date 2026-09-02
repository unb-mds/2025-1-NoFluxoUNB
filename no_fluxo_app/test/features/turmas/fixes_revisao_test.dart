import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/assinatura_model.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_providers.dart';
import 'package:no_fluxo_app/features/turmas/data/turmas_repository.dart';
import 'package:no_fluxo_app/features/turmas/domain/turmas_logic.dart';
import 'package:no_fluxo_app/features/turmas/ui/turmas_screen.dart';

import 'fakes.dart';

/// Repo que atrasa `seguirMateria` de forma controlada, para provar que as
/// mutações do [AssinaturasNotifier] rodam serializadas (fila), não em
/// paralelo com write-last-wins.
class _RepoLento extends FakeTurmasRepository {
  final List<String> eventos = [];
  Completer<void> liberarPrimeiroSeguir = Completer<void>();
  var _primeiro = true;

  @override
  Future<AssinaturaModel> seguirMateria({
    required int idMateria,
    String? turma,
    required String anoPeriodo,
  }) async {
    final rotulo = 'seguir:$idMateria';
    eventos.add('inicio $rotulo');
    if (_primeiro) {
      _primeiro = false;
      await liberarPrimeiroSeguir.future;
    }
    eventos.add('fim $rotulo');
    return super.seguirMateria(
      idMateria: idMateria,
      turma: turma,
      anoPeriodo: anoPeriodo,
    );
  }
}

void main() {
  group('periodoLetivoPorData — fallback quando a RPC falha', () {
    test('ano.1 até junho, ano.2 depois', () {
      expect(periodoLetivoPorData(DateTime(2026, 1, 15)), '2026.1');
      expect(periodoLetivoPorData(DateTime(2026, 6, 30)), '2026.1');
      expect(periodoLetivoPorData(DateTime(2026, 7, 1)), '2026.2');
      expect(periodoLetivoPorData(DateTime(2026, 12, 31)), '2026.2');
    });
  });

  group('AssinaturasNotifier — mutações serializadas', () {
    test('segundo seguir só começa depois do primeiro terminar', () async {
      final repo = _RepoLento();
      final container = ProviderContainer(
        overrides: [
          turmasRepositoryProvider.overrideWithValue(repo),
          estaLogadoProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(assinaturasProvider.notifier);
      // Garante o build inicial antes das mutações.
      await container.read(assinaturasProvider.future);

      final primeira = notifier.seguir(idMateria: 1, anoPeriodo: '2026.1');
      final segunda = notifier.seguir(idMateria: 2, anoPeriodo: '2026.1');

      // Dá chance de a segunda mutação começar ANTES da primeira liberar —
      // se não estivesse serializada, "inicio seguir:2" apareceria aqui.
      await Future<void>.delayed(Duration.zero);
      expect(repo.eventos, ['inicio seguir:1']);

      repo.liberarPrimeiroSeguir.complete();
      expect(await primeira, isNull);
      expect(await segunda, isNull);

      expect(repo.eventos, [
        'inicio seguir:1',
        'fim seguir:1',
        'inicio seguir:2',
        'fim seguir:2',
      ]);
      // Estado final reflete as DUAS assinaturas (nenhuma recarga perdida).
      final estado = container.read(assinaturasProvider).valueOrNull ?? [];
      expect(estado.length, 2);
    });
  });

  group('Busca de turmas — visitante', () {
    testWidgets('busca vazia sem login explica o bloqueio, não mente', (
      tester,
    ) async {
      final repo = FakeTurmasRepository(materias: const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            turmasRepositoryProvider.overrideWithValue(repo),
            estaLogadoProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: TurmasScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'CIC0004');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.textContaining('Entre com sua conta'), findsOneWidget);
      expect(
        find.text('Nenhuma matéria encontrada para essa busca.'),
        findsNothing,
      );
    });
  });
}
