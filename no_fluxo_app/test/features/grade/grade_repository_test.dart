import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';
import 'package:no_fluxo_app/features/grade/data/grade_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

TurmaModel turma({required int id, required String codigo, String? horario}) {
  return TurmaModel(
    idTurmas: id,
    idMateria: id * 10,
    turma: '01',
    horario: horario,
    anoPeriodo: '2026.1',
    codigoMateria: codigo,
    nomeMateria: 'Matéria $codigo',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `periodoFixo` evita a RPC `periodo_letivo_atual` — só a persistência
  // local (shared_preferences mockado) é exercitada aqui.
  SupabaseGradeRepository novoRepo() =>
      SupabaseGradeRepository(periodoFixo: '2026.1');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('grade manual (shared_preferences)', () {
    test(
      'adicionar → carregar → remover persiste por usuário e período',
      () async {
        final repo = novoRepo();

        await repo.adicionarTurmaManual(
          idUser: 42,
          turma: turma(id: 1, codigo: 'FGA0138', horario: '2M12'),
        );
        await repo.adicionarTurmaManual(
          idUser: 42,
          turma: turma(id: 2, codigo: 'FGA0158', horario: '3T23'),
        );

        final grade = await repo.carregarGrade(dados: null, idUser: 42);
        expect(grade, hasLength(2));
        expect(grade.every((t) => t.manual), isTrue);
        expect(
          grade.map((t) => t.turma.codigoMateria),
          containsAll(['FGA0138', 'FGA0158']),
        );

        // Outro usuário não enxerga a grade de 42.
        expect(await repo.carregarGrade(dados: null, idUser: 7), isEmpty);

        await repo.removerTurmaManual(idUser: 42, idTurmas: 1);
        final aposRemover = await repo.carregarGrade(dados: null, idUser: 42);
        expect(aposRemover.single.turma.idTurmas, 2);
      },
    );

    test('grava no formato JSON documentado (versao 1)', () async {
      final repo = novoRepo();
      await repo.adicionarTurmaManual(
        idUser: 42,
        turma: turma(id: 1, codigo: 'FGA0138', horario: '2M12'),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('grade_manual_v1_42_2026.1');
      expect(raw, isNotNull);

      final json = jsonDecode(raw!) as Map<String, dynamic>;
      expect(json['versao'], 1);
      final turmas = json['turmas'] as List;
      expect(turmas, hasLength(1));
      expect((turmas.first as Map)['id_turmas'], 1);
      expect((turmas.first as Map)['horario'], '2M12');
    });

    test('adicionar o mesmo idTurmas substitui em vez de duplicar', () async {
      final repo = novoRepo();
      await repo.adicionarTurmaManual(
        idUser: 1,
        turma: turma(id: 5, codigo: 'FGA0138', horario: '2M12'),
      );
      await repo.adicionarTurmaManual(
        idUser: 1,
        turma: turma(id: 5, codigo: 'FGA0138', horario: '4M12'),
      );

      final grade = await repo.carregarGrade(dados: null, idUser: 1);
      expect(grade, hasLength(1));
      expect(grade.single.turma.horario, '4M12');
    });

    test('valor corrompido em prefs vira grade vazia (sem estourar)', () async {
      SharedPreferences.setMockInitialValues({
        'grade_manual_v1_1_2026.1': '{isso não é json',
      });
      final repo = novoRepo();
      expect(await repo.carregarGrade(dados: null, idUser: 1), isEmpty);
    });

    test('repositórios distintos leem a mesma persistência', () async {
      await novoRepo().adicionarTurmaManual(
        idUser: 3,
        turma: turma(id: 9, codigo: 'MAT0025', horario: '6M34'),
      );

      final grade = await novoRepo().carregarGrade(dados: null, idUser: 3);
      expect(grade.single.turma.codigoMateria, 'MAT0025');
      expect(grade.single.turma.horario, '6M34');
    });
  });
}
