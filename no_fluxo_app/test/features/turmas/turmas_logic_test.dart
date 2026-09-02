import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/assinatura_model.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/features/turmas/domain/turmas_logic.dart';

TurmaModel _turma(String codigo, {int id = 0}) =>
    TurmaModel(idTurmas: id, idMateria: 1, turma: codigo, anoPeriodo: '2026.1');

void main() {
  group('descreverAtualizadoHa', () {
    final agora = DateTime(2026, 8, 31, 12, 0, 0);

    test('nulo vira string vazia', () {
      expect(descreverAtualizadoHa(null, agora: agora), '');
    });

    test('menos de 1 min é "atualizado agora"', () {
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(seconds: 30)),
          agora: agora,
        ),
        'atualizado agora',
      );
    });

    test('minutos', () {
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(minutes: 5)),
          agora: agora,
        ),
        'atualizado há 5 min',
      );
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(minutes: 59)),
          agora: agora,
        ),
        'atualizado há 59 min',
      );
    });

    test('horas', () {
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(hours: 2, minutes: 10)),
          agora: agora,
        ),
        'atualizado há 2 h',
      );
    });

    test('dias, com singular', () {
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(days: 1)),
          agora: agora,
        ),
        'atualizado há 1 dia',
      );
      expect(
        descreverAtualizadoHa(
          agora.subtract(const Duration(days: 3)),
          agora: agora,
        ),
        'atualizado há 3 dias',
      );
    });

    test('data no futuro (relógio dessincronizado) conta como agora', () {
      expect(
        descreverAtualizadoHa(
          agora.add(const Duration(minutes: 10)),
          agora: agora,
        ),
        'atualizado agora',
      );
    });
  });

  group('ordenarTurmas', () {
    test(
      'ordena por código da turma, case-insensitive, sem mutar a original',
      () {
        final original = [
          _turma('b', id: 3),
          _turma('A', id: 1),
          _turma('03', id: 2),
        ];
        final ordenadas = ordenarTurmas(original);

        expect(ordenadas.map((t) => t.turma).toList(), ['03', 'A', 'b']);
        // A lista original não é alterada.
        expect(original.map((t) => t.turma).toList(), ['b', 'A', '03']);
      },
    );

    test('empate no código desempata pelo id (ordem estável)', () {
      final ordenadas = ordenarTurmas([
        _turma('01', id: 9),
        _turma('01', id: 2),
      ]);
      expect(ordenadas.map((t) => t.idTurmas).toList(), [2, 9]);
    });
  });

  group('sanitizarTermoBusca / termoBuscavel', () {
    test('remove caracteres especiais do PostgREST', () {
      expect(sanitizarTermoBusca('cálculo, (1)%'), 'cálculo 1');
    });

    test('colapsa espaços e apara pontas', () {
      expect(sanitizarTermoBusca('  algoritmos   e  '), 'algoritmos e');
    });

    test('termo curto não é buscável', () {
      expect(termoBuscavel('c'), isFalse);
      expect(termoBuscavel('%,'), isFalse);
      expect(termoBuscavel('ci'), isTrue);
    });
  });

  group('assinaturaDe', () {
    const qualquer = AssinaturaModel(
      idAssinatura: 1,
      idMateria: 7,
      turma: null,
      anoPeriodo: '2026.1',
    );
    const especifica = AssinaturaModel(
      idAssinatura: 2,
      idMateria: 7,
      turma: '01',
      anoPeriodo: '2026.1',
    );
    const inativa = AssinaturaModel(
      idAssinatura: 3,
      idMateria: 7,
      turma: '02',
      anoPeriodo: '2026.1',
      ativa: false,
    );
    const todas = [qualquer, especifica, inativa];

    test('turma null casa só com a assinatura "qualquer turma"', () {
      expect(assinaturaDe(todas, idMateria: 7, turma: null), qualquer);
    });

    test('turma específica casa só com a assinatura daquela turma', () {
      expect(assinaturaDe(todas, idMateria: 7, turma: '01'), especifica);
      expect(assinaturaDe(todas, idMateria: 7, turma: '99'), isNull);
    });

    test('comparação de turma é case-insensitive', () {
      const minuscula = AssinaturaModel(
        idAssinatura: 4,
        idMateria: 7,
        turma: 'a',
        anoPeriodo: '2026.1',
      );
      expect(
        assinaturaDe(const [minuscula], idMateria: 7, turma: 'A'),
        minuscula,
      );
    });

    test('assinatura inativa e matéria diferente não casam', () {
      expect(assinaturaDe(todas, idMateria: 7, turma: '02'), isNull);
      expect(assinaturaDe(todas, idMateria: 99, turma: null), isNull);
    });
  });

  group('descreverAlvoAssinatura', () {
    test('diferencia turma específica de qualquer turma', () {
      const qualquer = AssinaturaModel(
        idAssinatura: 1,
        idMateria: 1,
        anoPeriodo: '2026.1',
      );
      const daTurma = AssinaturaModel(
        idAssinatura: 2,
        idMateria: 1,
        turma: '05',
        anoPeriodo: '2026.1',
      );
      expect(descreverAlvoAssinatura(qualquer), 'Qualquer turma');
      expect(descreverAlvoAssinatura(daTurma), 'Turma 05');
    });
  });
}
