import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/widgets/vagas_badge.dart';

void main() {
  group('VagasBadge', () {
    test(
      'cor semântica: verde com vaga, vermelho sem, neutro desconhecido',
      () {
        expect(VagasBadge.corDe(3), const Color(0xFF1F7A43));
        expect(VagasBadge.corDe(1), const Color(0xFF1F7A43));
        expect(VagasBadge.corDe(0), const Color(0xFF991B1B));
        expect(VagasBadge.corDe(-1), const Color(0xFF991B1B));
        expect(VagasBadge.corDe(null), isNot(const Color(0xFF1F7A43)));
        expect(VagasBadge.corDe(null), isNot(const Color(0xFF991B1B)));
      },
    );

    test('texto: plural, singular, zero e desconhecido', () {
      expect(VagasBadge.textoDe(5), '5 vagas');
      expect(VagasBadge.textoDe(1), '1 vaga');
      expect(VagasBadge.textoDe(0), 'Sem vagas');
      expect(VagasBadge.textoDe(null), 'Vagas ?');
    });

    testWidgets('renderiza o texto e a cor no container', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VagasBadge(vagasSobrando: 2))),
      );

      expect(find.text('2 vagas'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF1F7A43));
    });

    testWidgets('zero vagas fica vermelho', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VagasBadge(vagasSobrando: 0))),
      );

      expect(find.text('Sem vagas'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF991B1B));
    });
  });
}
