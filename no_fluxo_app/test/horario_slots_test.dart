import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/utils/horario_slots.dart';

/// Monta a máscara esperada a partir de triplas (dia SIGAA, turno, módulo).
BigInt maskDe(List<(String, String, int)> slots) {
  var mask = BigInt.zero;
  for (final (dia, turno, modulo) in slots) {
    final bit = diaIndexMap[dia]! * 16 + turnoOffset[turno]! + (modulo - 1);
    mask |= BigInt.one << bit;
  }
  return mask;
}

void main() {
  group('parseHorarioToMask', () {
    test('"246M12" ocupa Seg/Qua/Sex nos módulos M1 e M2', () {
      final esperado = maskDe([
        ('2', 'M', 1),
        ('2', 'M', 2),
        ('4', 'M', 1),
        ('4', 'M', 2),
        ('6', 'M', 1),
        ('6', 'M', 2),
      ]);
      expect(parseHorarioToMask('246M12'), esperado);
    });

    test('"35T34" ocupa Ter/Qui nos módulos T3 e T4', () {
      final esperado = maskDe([
        ('3', 'T', 3),
        ('3', 'T', 4),
        ('5', 'T', 3),
        ('5', 'T', 4),
      ]);
      expect(parseHorarioToMask('35T34'), esperado);
    });

    test('horário composto "246M12 35T34" é o OR das duas partes', () {
      final composto = parseHorarioToMask('246M12 35T34');
      expect(
        composto,
        parseHorarioToMask('246M12') | parseHorarioToMask('35T34'),
      );
    });

    test('entrada vazia, nula ou EAD vira máscara zero', () {
      expect(parseHorarioToMask(null), BigInt.zero);
      expect(parseHorarioToMask(''), BigInt.zero);
      expect(parseHorarioToMask('A DEFINIR'), BigInt.zero);
    });

    test('módulo fora da faixa do turno é ignorado (N5 não existe)', () {
      // N vai só até 4: o "5" é descartado, o resto vale.
      expect(parseHorarioToMask('2N45'), maskDe([('2', 'N', 4)]));
    });

    test('é case-insensitive e tolera espaços', () {
      expect(parseHorarioToMask(' 246m12 '), parseHorarioToMask('246M12'));
    });
  });

  group('masksConflict', () {
    test('mesmo slot conflita', () {
      final a = parseHorarioToMask('246M12');
      final b = parseHorarioToMask('2M23'); // compartilha Seg M2
      expect(masksConflict(a, b), isTrue);
    });

    test('slots disjuntos não conflitam', () {
      final a = parseHorarioToMask('246M12');
      final b = parseHorarioToMask('35T34');
      expect(masksConflict(a, b), isFalse);
    });

    test('horário composto conflita com cada uma das partes', () {
      final composto = parseHorarioToMask('246M12 35T34');
      expect(masksConflict(composto, parseHorarioToMask('246M12')), isTrue);
      expect(masksConflict(composto, parseHorarioToMask('35T34')), isTrue);
    });

    test('máscara vazia nunca conflita', () {
      expect(masksConflict(BigInt.zero, parseHorarioToMask('246M12')), isFalse);
      expect(masksConflict(BigInt.zero, BigInt.zero), isFalse);
    });
  });

  group('describeHorario', () {
    test('"246M12" → "Seg/Qua/Sex 08:00–09:50"', () {
      expect(describeHorario('246M12'), 'Seg/Qua/Sex 08:00–09:50');
    });

    test('"35T34" → "Ter/Qui 14:55–16:55"', () {
      expect(describeHorario('35T34'), 'Ter/Qui 14:55–16:55');
    });

    test('composto junta as partes com vírgula', () {
      expect(
        describeHorario('246M12 35T34'),
        'Seg/Qua/Sex 08:00–09:50, Ter/Qui 14:55–16:55',
      );
    });

    test('módulos não consecutivos viram intervalos separados', () {
      expect(describeHorario('2M13'), 'Seg 08:00–08:55, Seg 10:00–10:55');
    });

    test('entrada sem padrão vira string vazia', () {
      expect(describeHorario('A DEFINIR'), '');
      expect(describeHorario(null), '');
    });
  });

  group('slotsOf', () {
    test('"2M1" gera um encontro na segunda 08:00–08:55', () {
      final slots = slotsOf('2M1');
      expect(slots, hasLength(1));
      expect(slots.single.weekday, DateTime.monday);
      expect(slots.single.diaLabel, 'Seg');
      expect(slots.single.modulo, 'M1');
      expect(slots.single.startTime, '08:00');
      expect(slots.single.endTime, '08:55');
    });

    test('"246M12" gera 6 encontros com horários reais', () {
      final slots = slotsOf('246M12');
      expect(slots, hasLength(6));
      expect(slots.map((s) => s.weekday).toSet(), {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
      expect(slots.map((s) => s.startTime).toSet(), {'08:00', '08:55'});
    });

    test('turno noturno usa os horários N reais', () {
      final slots = slotsOf('7N12');
      expect(slots.map((s) => s.startTime).toList(), ['19:00', '19:50']);
      expect(slots.map((s) => s.endTime).toList(), ['19:50', '20:40']);
      expect(slots.every((s) => s.weekday == DateTime.saturday), isTrue);
    });

    test('horário vazio gera lista vazia', () {
      expect(slotsOf(null), isEmpty);
      expect(slotsOf('EAD'), isEmpty);
    });
  });

  group('autoMontarGrade', () {
    MateriaTurmas<String> materia(
      String chave,
      List<String> horarios, {
      num peso = 1,
    }) => MateriaTurmas(
      chave: chave,
      peso: peso,
      turmas: [
        for (final h in horarios)
          TurmaCandidata(mask: parseHorarioToMask(h), turma: '$chave:$h'),
      ],
    );

    test('escolhe turmas sem conflito maximizando matérias alocadas', () {
      final resultado = autoMontarGrade<String>([
        materia('A', ['246M12']),
        materia('B', ['246M12', '35T34']), // só a segunda turma cabe
      ]);
      expect(resultado.naoAlocadas, isEmpty);
      expect(resultado.selecao['B']!.turma, 'B:35T34');
      expect(resultado.truncado, isFalse);
    });

    test('matéria impossível volta em naoAlocadas', () {
      final resultado = autoMontarGrade<String>([
        materia('A', ['246M12'], peso: 10),
        materia('B', ['246M12']),
      ]);
      expect(resultado.selecao.keys, ['A']);
      expect(resultado.naoAlocadas, ['B']);
    });

    test('mascaraInicial bloqueia horários já ocupados', () {
      final resultado = autoMontarGrade<String>([
        materia('A', ['246M12']),
      ], mascaraInicial: parseHorarioToMask('2M1'));
      expect(resultado.naoAlocadas, ['A']);
    });
  });
}
