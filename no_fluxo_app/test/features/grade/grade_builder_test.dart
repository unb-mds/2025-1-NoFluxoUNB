import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/features/grade/domain/grade_builder.dart';

/// Fábrica de turma para as fixtures.
TurmaModel turma({
  required int id,
  required String codigo,
  String? horario,
  String nome = 'Matéria',
  String turma = '01',
  String? local,
}) {
  return TurmaModel(
    idTurmas: id,
    idMateria: id * 10,
    turma: turma,
    horario: horario,
    local: local,
    anoPeriodo: '2026.1',
    codigoMateria: codigo,
    nomeMateria: nome,
  );
}

void main() {
  group('montarGradeSemanal', () {
    test('monta a grade de 2 turmas sem conflito, com blocos mesclados', () {
      final grade = montarGradeSemanal([
        TurmaGrade(
          turma: turma(
            id: 1,
            codigo: 'FGA0138',
            horario: '246M12',
            nome: 'Métodos',
            local: 'UAC 213',
          ),
        ),
        TurmaGrade(
          turma: turma(id: 2, codigo: 'FGA0158', horario: '35T34'),
          manual: true,
        ),
      ]);

      // Seg/Qua/Sex + Ter/Qui.
      expect(grade.diasComAula, [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ]);
      expect(grade.turmasEmConflito, isEmpty);
      expect(grade.semHorario, isEmpty);

      // M1+M2 consecutivos viram um bloco único 08:00–09:50.
      final segunda = grade.blocosPorDia[DateTime.monday]!;
      expect(segunda, hasLength(1));
      expect(segunda.first.codigo, 'FGA0138');
      expect(segunda.first.inicio, '08:00');
      expect(segunda.first.fim, '09:50');
      expect(segunda.first.local, 'UAC 213');
      expect(segunda.first.manual, isFalse);
      expect(segunda.first.conflito, isFalse);

      // T3+T4 → 14:55–16:55, marcado como manual.
      final terca = grade.blocosPorDia[DateTime.tuesday]!;
      expect(terca.single.inicio, '14:55');
      expect(terca.single.fim, '16:55');
      expect(terca.single.manual, isTrue);
    });

    test('módulos não consecutivos geram blocos separados', () {
      final grade = montarGradeSemanal([
        TurmaGrade(
          turma: turma(id: 1, codigo: 'MAT0025', horario: '2M13'),
        ),
      ]);
      final segunda = grade.blocosPorDia[DateTime.monday]!;
      expect(segunda, hasLength(2));
      expect(segunda[0].inicio, '08:00');
      expect(segunda[0].fim, '08:55');
      expect(segunda[1].inicio, '10:00');
      expect(segunda[1].fim, '10:55');
    });

    test('detecta conflito entre turmas e marca o bloco disputado', () {
      final grade = montarGradeSemanal([
        TurmaGrade(
          turma: turma(id: 1, codigo: 'FGA0138', horario: '246M12'),
        ),
        // Conflita na segunda (M2), mas não na quarta/sexta.
        TurmaGrade(
          turma: turma(id: 2, codigo: 'FGA0158', horario: '2M23'),
        ),
        TurmaGrade(
          turma: turma(id: 3, codigo: 'FGA0164', horario: '3N12'),
        ),
      ]);

      expect(grade.turmasEmConflito, {1, 2});

      final segunda = grade.blocosPorDia[DateTime.monday]!;
      expect(segunda.every((b) => b.conflito), isTrue);

      // Quarta não tem disputa: bloco da turma 1 fica limpo.
      final quarta = grade.blocosPorDia[DateTime.wednesday]!;
      expect(quarta.single.conflito, isFalse);

      // Turma 3 (noite de terça) segue fora do conflito.
      final terca = grade.blocosPorDia[DateTime.tuesday]!;
      expect(terca.single.conflito, isFalse);
    });

    test(
      'turma sem horário (EAD) vai para semHorario; duplicada é ignorada',
      () {
        final ead = turma(id: 9, codigo: 'FGA0999', horario: 'A DEFINIR');
        final grade = montarGradeSemanal([
          TurmaGrade(turma: ead),
          TurmaGrade(turma: ead, manual: true), // mesmo idTurmas → dedup
        ]);
        expect(grade.blocosPorDia, isEmpty);
        expect(grade.semHorario, hasLength(1));
        expect(grade.vazia, isFalse);
      },
    );

    test('blocos do mesmo dia ficam ordenados por horário de início', () {
      final grade = montarGradeSemanal([
        TurmaGrade(
          turma: turma(id: 1, codigo: 'B', horario: '2T23'),
        ),
        TurmaGrade(
          turma: turma(id: 2, codigo: 'A', horario: '2M12'),
        ),
      ]);
      final segunda = grade.blocosPorDia[DateTime.monday]!;
      expect(segunda.map((b) => b.codigo).toList(), ['A', 'B']);
    });
  });

  group('materiasEmCursoComTurma', () {
    test('só considera MATR com turma preenchida, sem duplicar', () {
      final dados = DadosFluxogramaUser(
        dadosFluxograma: [
          [
            DadosMateria(codigoMateria: 'FGA0138', status: 'MATR', turma: '01'),
            DadosMateria(codigoMateria: 'FGA0158', status: 'APR', turma: '02'),
            DadosMateria(codigoMateria: 'FGA0164', status: 'MATR'), // sem turma
          ],
          [
            // Duplicada (mesmo código+turma) em outro semestre.
            DadosMateria(
              codigoMateria: 'fga0138',
              status: 'matr',
              turma: ' 01 ',
            ),
          ],
        ],
      );

      expect(materiasEmCursoComTurma(dados), [
        (codigo: 'FGA0138', turma: '01'),
      ]);
    });
  });

  group('aulaEmDestaque', () {
    // 2026-01-05 é uma segunda-feira.
    final turmas = [
      TurmaGrade(
        turma: turma(id: 1, codigo: 'FGA0138', horario: '2M12'),
      ),
      TurmaGrade(
        turma: turma(id: 2, codigo: 'FGA0158', horario: '4T23'),
      ),
    ];

    test('aula em andamento tem prioridade', () {
      final grade = montarGradeSemanal(turmas);
      final destaque = aulaEmDestaque(
        grade,
        DateTime(2026, 1, 5, 8, 30),
      ); // Seg 08:30
      expect(destaque!.emAndamento, isTrue);
      expect(destaque.bloco.codigo, 'FGA0138');
    });

    test('fora de aula, aponta a próxima a começar', () {
      final grade = montarGradeSemanal(turmas);
      final destaque = aulaEmDestaque(
        grade,
        DateTime(2026, 1, 5, 12, 0),
      ); // Seg 12:00
      expect(destaque!.emAndamento, isFalse);
      expect(destaque.bloco.codigo, 'FGA0158'); // Qua 14:00
    });

    test('grade sem blocos retorna null', () {
      expect(
        aulaEmDestaque(montarGradeSemanal([]), DateTime(2026, 1, 5)),
        isNull,
      );
    });
  });

  group('calcularAgendamentos', () {
    final turmaSeg = TurmaGrade(
      turma: turma(
        id: 7,
        codigo: 'FGA0138',
        horario: '2M12',
        nome: 'Métodos de Desenvolvimento de Software',
        local: 'UAC 213',
      ),
    );

    test('agenda 30 min antes da próxima ocorrência semanal', () {
      // Segunda 07:00 → aula às 08:00, aviso às 07:30 (mesmo dia).
      final agendamentos = calcularAgendamentos(
        turmas: [turmaSeg],
        now: DateTime(2026, 1, 5, 7, 0),
      );

      expect(agendamentos, hasLength(1));
      final a = agendamentos.single;
      expect(a.dateTime, DateTime(2026, 1, 5, 7, 30));
      expect(a.weekday, DateTime.monday);
      expect(a.titulo, 'FGA0138 começa em 30 min');
      expect(
        a.corpo,
        'Métodos de Desenvolvimento de Software · 08:00–09:50 · UAC 213',
      );
    });

    test('aviso já passado empurra para a semana seguinte', () {
      // Segunda 07:45: o aviso de 07:30 já passou → próxima segunda.
      final agendamentos = calcularAgendamentos(
        turmas: [turmaSeg],
        now: DateTime(2026, 1, 5, 7, 45),
      );
      expect(agendamentos.single.dateTime, DateTime(2026, 1, 12, 7, 30));
    });

    test('antecedência configurável muda o disparo', () {
      final agendamentos = calcularAgendamentos(
        turmas: [turmaSeg],
        now: DateTime(2026, 1, 5, 6, 0),
        antecedencia: const Duration(minutes: 60),
      );
      expect(agendamentos.single.dateTime, DateTime(2026, 1, 5, 7, 0));
      expect(agendamentos.single.titulo, 'FGA0138 começa em 60 min');
    });

    test('aviso exatamente em `now` não vale — vai para a próxima semana', () {
      final agendamentos = calcularAgendamentos(
        turmas: [turmaSeg],
        now: DateTime(2026, 1, 5, 7, 30),
      );
      expect(agendamentos.single.dateTime, DateTime(2026, 1, 12, 7, 30));
    });

    test('várias ocorrências por bloco, ordenadas e com ids únicos', () {
      final agendamentos = calcularAgendamentos(
        turmas: [
          turmaSeg,
          TurmaGrade(
            turma: turma(id: 8, codigo: 'FGA0158', horario: '3N12'),
          ),
        ],
        now: DateTime(2026, 1, 5, 7, 0), // segunda
        ocorrenciasPorBloco: 2,
      );

      expect(agendamentos, hasLength(4));
      // Ordenado por data de disparo.
      final datas = agendamentos.map((a) => a.dateTime).toList();
      expect(datas, [
        DateTime(2026, 1, 5, 7, 30), // Seg 1
        DateTime(2026, 1, 6, 18, 30), // Ter 1 (N1 às 19:00)
        DateTime(2026, 1, 12, 7, 30), // Seg 2
        DateTime(2026, 1, 13, 18, 30), // Ter 2
      ]);
      // Ids únicos e estáveis.
      expect(agendamentos.map((a) => a.id).toSet(), hasLength(4));

      final repeticao = calcularAgendamentos(
        turmas: [turmaSeg],
        now: DateTime(2026, 1, 5, 7, 0),
      );
      expect(repeticao.single.id, agendamentos.first.id);
    });

    test('turma sem horário não gera agendamento', () {
      final agendamentos = calcularAgendamentos(
        turmas: [
          TurmaGrade(turma: turma(id: 1, codigo: 'EAD0001', horario: null)),
        ],
        now: DateTime(2026, 1, 5),
      );
      expect(agendamentos, isEmpty);
    });
  });
}
