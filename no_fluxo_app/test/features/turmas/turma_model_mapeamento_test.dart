import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/assinatura_model.dart';
import 'package:no_fluxo_app/core/models/turma_model.dart';

void main() {
  group('TurmaModel.fromJson', () {
    test('mapeia a linha completa de turmas com join de materias', () {
      final json = {
        'id_turmas': 42,
        'id_materia': 7,
        'turma': '02',
        'docente': 'MARIA DA SILVA',
        'horario': '246M12',
        'local': 'PJC BT 076',
        'ano_periodo': '2026.1',
        'vagas_ofertadas': 40,
        'vagas_ocupadas': 38,
        'vagas_sobrando': 2,
        'last_updated_at': '2026-08-31T10:30:00Z',
        'materias': {
          'codigo_materia': 'CIC0004',
          'nome_materia': 'Algoritmos e Programação de Computadores',
        },
      };

      final turma = TurmaModel.fromJson(json);

      expect(turma.idTurmas, 42);
      expect(turma.idMateria, 7);
      expect(turma.turma, '02');
      expect(turma.docente, 'MARIA DA SILVA');
      expect(turma.horario, '246M12');
      expect(turma.local, 'PJC BT 076');
      expect(turma.anoPeriodo, '2026.1');
      expect(turma.vagasOfertadas, 40);
      expect(turma.vagasOcupadas, 38);
      expect(turma.vagasSobrando, 2);
      expect(turma.lastUpdatedAt, DateTime.utc(2026, 8, 31, 10, 30));
      expect(turma.codigoMateria, 'CIC0004');
      expect(turma.nomeMateria, 'Algoritmos e Programação de Computadores');
      expect(turma.temVagas, isTrue);
    });

    test('tolera campos nulos, tipos frouxos e ausência do join', () {
      final turma = TurmaModel.fromJson({
        'id_turmas': '42', // int como String
        'id_materia': 7.0, // double
        'turma': '01',
        'ano_periodo': '2026.1',
        'vagas_sobrando': '0',
        'last_updated_at': 'não-é-data',
      });

      expect(turma.idTurmas, 42);
      expect(turma.idMateria, 7);
      expect(turma.docente, isNull);
      expect(turma.horario, isNull);
      expect(turma.local, isNull);
      expect(turma.vagasOfertadas, isNull);
      expect(turma.vagasSobrando, 0);
      expect(turma.lastUpdatedAt, isNull);
      expect(turma.codigoMateria, isNull);
      expect(turma.temVagas, isFalse);
    });

    test('temVagas trata vagas_sobrando nulo como sem vagas', () {
      final turma = TurmaModel.fromJson({
        'id_turmas': 1,
        'id_materia': 1,
        'turma': '01',
        'ano_periodo': '2026.1',
      });
      expect(turma.vagasSobrando, isNull);
      expect(turma.temVagas, isFalse);
    });
  });

  group('AssinaturaModel.fromJson', () {
    test('mapeia o shape da RPC listar_minhas_assinaturas', () {
      final assinatura = AssinaturaModel.fromJson({
        'id_assinatura': 9,
        'id_materia': 7,
        'codigo_materia': 'CIC0004',
        'nome_materia': 'Algoritmos',
        'turma': null,
        'ano_periodo': '2026.1',
        'ativa': true,
      });

      expect(assinatura.idAssinatura, 9);
      expect(assinatura.idMateria, 7);
      expect(assinatura.codigoMateria, 'CIC0004');
      expect(assinatura.turma, isNull); // qualquer turma
      expect(assinatura.anoPeriodo, '2026.1');
      expect(assinatura.ativa, isTrue);
    });
  });
}
