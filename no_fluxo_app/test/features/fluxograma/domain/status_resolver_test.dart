import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/curso_model.dart';
import 'package:no_fluxo_app/core/models/equivalencia_model.dart';
import 'package:no_fluxo_app/core/models/materia_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/features/fluxograma/domain/status_resolver.dart';

// ── Fábricas de teste ────────────────────────────────────────────────────────

MateriaModel materia(
  String codigo, {
  required int id,
  int nivel = 1,
  int creditos = 4,
}) {
  return MateriaModel(
    ementa: '',
    idMateria: id,
    nomeMateria: 'Matéria $codigo',
    codigoMateria: codigo,
    nivel: nivel,
    creditos: creditos,
  );
}

PreRequisitoModel preRequisito({
  required int idMateria,
  String codigoRequisito = '',
  int idRequisito = 999,
  int? idPreRequisito,
  String? expressaoOriginal,
  dynamic expressaoLogica,
}) {
  return PreRequisitoModel(
    idPreRequisito: idPreRequisito ?? idMateria * 100 + idRequisito,
    idMateria: idMateria,
    idMateriaRequisito: idRequisito,
    codigoMateriaRequisito: codigoRequisito,
    nomeMateriaRequisito: codigoRequisito.isEmpty
        ? ''
        : 'Requisito $codigoRequisito',
    expressaoOriginal: expressaoOriginal,
    expressaoLogica: expressaoLogica,
  );
}

EquivalenciaModel equivalencia({
  required String origem,
  required String expressao,
}) {
  return EquivalenciaModel(
    idEquivalencia: 1,
    codigoMateriaOrigem: origem,
    nomeMateriaOrigem: 'Origem $origem',
    codigoMateriaEquivalente: '',
    nomeMateriaEquivalente: '',
    expressao: expressao,
  );
}

CursoModel curso({
  required List<MateriaModel> materias,
  List<PreRequisitoModel> preRequisitos = const [],
  List<EquivalenciaModel> equivalencias = const [],
}) {
  return CursoModel(
    nomeCurso: 'Curso Teste',
    matrizCurricular: '1234/1',
    idCurso: 1,
    totalCreditos: null,
    classificacao: '',
    tipoCurso: '',
    materias: materias,
    semestres: 2,
    preRequisitos: preRequisitos,
    equivalencias: equivalencias,
  );
}

DadosMateria registro(
  String codigo, {
  String status = 'APR',
  String mencao = '-',
  String? codigoEquivalente,
}) {
  return DadosMateria(
    codigoMateria: codigo,
    status: status,
    mencao: mencao,
    codigoEquivalente: codigoEquivalente,
  );
}

DadosFluxogramaUser historico(List<DadosMateria> materias) {
  return DadosFluxogramaUser(dadosFluxograma: [materias]);
}

void main() {
  group('resolverStatus — statuses diretos do histórico', () {
    test('APR, CUMP e DISP viram concluída', () {
      final cursoTeste = curso(
        materias: [
          materia('FGA0001', id: 1),
          materia('FGA0002', id: 2),
          materia('FGA0003', id: 3),
        ],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0001', status: 'APR'),
          registro('FGA0002', status: 'CUMP'),
          registro('FGA0003', status: 'DISP'),
        ]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.concluida);
      expect(resultado.statusDe('FGA0002'), StatusMateria.concluida);
      expect(resultado.statusDe('FGA0003'), StatusMateria.concluida);
    });

    test('menção aprovada (MM) com status vazio vira concluída', () {
      final cursoTeste = curso(materias: [materia('FGA0001', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0001', status: '-', mencao: 'MM')]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.concluida);
    });

    test('MATR vira em curso', () {
      final cursoTeste = curso(materias: [materia('FGA0001', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0001', status: 'MATR')]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.emCurso);
    });

    test('REP vira reprovada', () {
      final cursoTeste = curso(materias: [materia('FGA0001', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0001', status: 'REP', mencao: 'MI')]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.reprovada);
    });

    test('menção II/MI/SR sem status NÃO marca reprovada (regra do site)', () {
      // O failedCodes do site (fluxograma.store.svelte.ts) só considera
      // REP/REPF/REPMF; menção sozinha cai em disponível/bloqueada.
      final cursoTeste = curso(
        materias: [
          materia('FGA0001', id: 1),
          materia('FGA0002', id: 2),
          materia('FGA0003', id: 3),
        ],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0001', status: '-', mencao: 'II'),
          registro('FGA0002', status: '', mencao: 'MI'),
          registro('FGA0003', status: '-', mencao: 'SR'),
        ]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.disponivel);
      expect(resultado.statusDe('FGA0002'), StatusMateria.disponivel);
      expect(resultado.statusDe('FGA0003'), StatusMateria.disponivel);
      expect(resultado.codigosReprovados, isEmpty);
    });

    test('reprovação antiga com aprovação posterior vira concluída', () {
      final cursoTeste = curso(materias: [materia('FGA0001', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0001', status: 'REP', mencao: 'MI'),
          registro('FGA0001', status: 'APR', mencao: 'MS'),
        ]),
      );

      // Concluída tem prioridade sobre a tentativa reprovada.
      expect(resultado.statusDe('FGA0001'), StatusMateria.concluida);
    });

    test('códigos casam ignorando caixa e espaços', () {
      final cursoTeste = curso(materias: [materia('FGA0001', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro(' fga0001 ', status: 'APR')]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.concluida);
    });
  });

  group('resolverStatus — pré-requisitos', () {
    CursoModel cursoComPreReq() => curso(
      materias: [
        materia('FGA0001', id: 1, nivel: 1),
        materia('FGA0002', id: 2, nivel: 2),
      ],
      preRequisitos: [
        preRequisito(idMateria: 2, codigoRequisito: 'FGA0001', idRequisito: 1),
      ],
    );

    test('pré-requisito cumprido deixa a matéria disponível', () {
      final resultado = resolverStatus(
        curso: cursoComPreReq(),
        dados: historico([registro('FGA0001', status: 'APR')]),
      );

      expect(resultado.statusDe('FGA0002'), StatusMateria.disponivel);
    });

    test('pré-requisito pendente bloqueia a matéria', () {
      final resultado = resolverStatus(
        curso: cursoComPreReq(),
        dados: historico([]),
      );

      expect(resultado.statusDe('FGA0001'), StatusMateria.disponivel);
      expect(resultado.statusDe('FGA0002'), StatusMateria.bloqueada);
    });

    test('pré-requisito apenas em curso (MATR) NÃO libera a matéria', () {
      final resultado = resolverStatus(
        curso: cursoComPreReq(),
        dados: historico([registro('FGA0001', status: 'MATR')]),
      );

      expect(resultado.statusDe('FGA0002'), StatusMateria.bloqueada);
    });
  });

  group('resolverStatus — pré-requisitos com expressão lógica', () {
    // Linhas do formato novo do banco: sem id_materia_requisito/código do
    // join, só expressao_original + expressao_logica (jsonb).
    CursoModel cursoComExpressao(dynamic expressaoLogica) => curso(
      materias: [
        materia('CIC0001', id: 1, nivel: 1),
        materia('CIC0002', id: 2, nivel: 1),
        materia('MAT0025', id: 3, nivel: 1),
        materia('FGA0100', id: 10, nivel: 2),
      ],
      preRequisitos: [
        preRequisito(
          idMateria: 10,
          idPreRequisito: 500,
          expressaoLogica: expressaoLogica,
        ),
      ],
    );

    test('"A OU B" com só A cursada fica disponível; sem nada, bloqueada', () {
      final cursoTeste = cursoComExpressao({
        'operador': 'OU',
        'condicoes': ['CIC0001', 'CIC0002'],
      });

      final comA = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('CIC0001', status: 'APR')]),
      );
      expect(comA.statusDe('FGA0100'), StatusMateria.disponivel);

      final semNada = resolverStatus(curso: cursoTeste, dados: historico([]));
      expect(semNada.statusDe('FGA0100'), StatusMateria.bloqueada);
    });

    test(
      '"A E B" com só A cursada fica bloqueada; com as duas, disponível',
      () {
        final cursoTeste = cursoComExpressao({
          'operador': 'E',
          'condicoes': ['CIC0001', 'CIC0002'],
        });

        final soA = resolverStatus(
          curso: cursoTeste,
          dados: historico([registro('CIC0001', status: 'APR')]),
        );
        expect(soA.statusDe('FGA0100'), StatusMateria.bloqueada);

        final asDuas = resolverStatus(
          curso: cursoTeste,
          dados: historico([
            registro('CIC0001', status: 'APR'),
            registro('CIC0002', status: 'APR'),
          ]),
        );
        expect(asDuas.statusDe('FGA0100'), StatusMateria.disponivel);
      },
    );

    test('aninhada "(A OU B) E C" exige C e pelo menos um de A/B', () {
      final cursoTeste = cursoComExpressao({
        'operador': 'E',
        'condicoes': [
          {
            'operador': 'OU',
            'condicoes': ['CIC0001', 'CIC0002'],
          },
          'MAT0025',
        ],
      });

      final comBeC = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('CIC0002', status: 'APR'),
          registro('MAT0025', status: 'APR'),
        ]),
      );
      expect(comBeC.statusDe('FGA0100'), StatusMateria.disponivel);

      final soC = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('MAT0025', status: 'APR')]),
      );
      expect(soC.statusDe('FGA0100'), StatusMateria.bloqueada);

      final semC = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('CIC0001', status: 'APR'),
          registro('CIC0002', status: 'APR'),
        ]),
      );
      expect(semC.statusDe('FGA0100'), StatusMateria.bloqueada);
    });

    test('linhas expandidas com o mesmo id_pre_requisito não viram "E"', () {
      // O backend pode expandir "A OU B" em duas linhas (uma por requisito),
      // ambas com a mesma expressão: sem dedup por idPreRequisito o app
      // trataria como conjunção e bloquearia quem só tem B.
      final expressao = {
        'operador': 'OU',
        'condicoes': ['CIC0001', 'CIC0002'],
      };
      final cursoTeste = curso(
        materias: [
          materia('CIC0001', id: 1, nivel: 1),
          materia('CIC0002', id: 2, nivel: 1),
          materia('FGA0100', id: 10, nivel: 2),
        ],
        preRequisitos: [
          preRequisito(
            idMateria: 10,
            idPreRequisito: 700,
            codigoRequisito: 'CIC0001',
            expressaoLogica: expressao,
          ),
          preRequisito(
            idMateria: 10,
            idPreRequisito: 700,
            codigoRequisito: 'CIC0002',
            expressaoLogica: expressao,
          ),
        ],
      );

      final soB = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('CIC0002', status: 'APR')]),
      );
      expect(soB.statusDe('FGA0100'), StatusMateria.disponivel);
    });

    test('fallback textual: expressao_original vale quando não há jsonb', () {
      final cursoTeste = curso(
        materias: [materia('FGA0100', id: 10, nivel: 2)],
        preRequisitos: [
          preRequisito(
            idMateria: 10,
            idPreRequisito: 800,
            expressaoOriginal: '( CCA0105 ) OU ( FUP0289 )',
          ),
        ],
      );

      final comUma = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FUP0289', status: 'APR')]),
      );
      expect(comUma.statusDe('FGA0100'), StatusMateria.disponivel);

      final semNada = resolverStatus(curso: cursoTeste, dados: historico([]));
      expect(semNada.statusDe('FGA0100'), StatusMateria.bloqueada);
    });

    test('formato legado {materias, operador} também é avaliado', () {
      final cursoTeste = cursoComExpressao({
        'materias': ['CIC0001', 'CIC0002'],
        'operador': 'OU',
      });

      final soB = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('CIC0002', status: 'APR')]),
      );
      expect(soB.statusDe('FGA0100'), StatusMateria.disponivel);
    });

    test('fallback: linha só com código do join segue exigindo o código', () {
      final cursoTeste = curso(
        materias: [
          materia('CIC0001', id: 1, nivel: 1),
          materia('FGA0100', id: 10, nivel: 2),
        ],
        preRequisitos: [
          preRequisito(
            idMateria: 10,
            codigoRequisito: 'CIC0001',
            idRequisito: 1,
          ),
        ],
      );

      final sem = resolverStatus(curso: cursoTeste, dados: historico([]));
      expect(sem.statusDe('FGA0100'), StatusMateria.bloqueada);

      final com = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('CIC0001', status: 'APR')]),
      );
      expect(com.statusDe('FGA0100'), StatusMateria.disponivel);
    });
  });

  group('resolverStatus — equivalências', () {
    test('equivalência cumprida marca a matéria da matriz como concluída', () {
      final cursoTeste = curso(
        materias: [materia('FGA0147', id: 1)],
        equivalencias: [equivalencia(origem: 'FGA0147', expressao: 'FGA0146')],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0146', status: 'APR')]),
      );

      expect(resultado.statusDe('FGA0147'), StatusMateria.concluida);
    });

    test('equivalência cumprida também libera pré-requisito', () {
      final cursoTeste = curso(
        materias: [
          materia('FGA0147', id: 1, nivel: 1),
          materia('FGA0200', id: 2, nivel: 2),
        ],
        preRequisitos: [
          preRequisito(
            idMateria: 2,
            codigoRequisito: 'FGA0147',
            idRequisito: 1,
          ),
        ],
        equivalencias: [equivalencia(origem: 'FGA0147', expressao: 'FGA0146')],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0146', status: 'APR')]),
      );

      expect(resultado.statusDe('FGA0200'), StatusMateria.disponivel);
    });

    test('expressão composta "A E B" exige as duas aprovadas', () {
      final cursoTeste = curso(
        materias: [materia('MAT0025', id: 1)],
        equivalencias: [
          equivalencia(origem: 'MAT0025', expressao: 'FGA0158 E FGA0161'),
        ],
      );

      final soUma = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0158', status: 'APR')]),
      );
      expect(soUma.statusDe('MAT0025'), StatusMateria.disponivel);

      final asDuas = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0158', status: 'APR'),
          registro('FGA0161', status: 'APR'),
        ]),
      );
      expect(asDuas.statusDe('MAT0025'), StatusMateria.concluida);
    });

    test('matriculado em equivalente marca a matéria como em curso', () {
      final cursoTeste = curso(
        materias: [materia('FGA0147', id: 1)],
        equivalencias: [equivalencia(origem: 'FGA0147', expressao: 'FGA0146')],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([registro('FGA0146', status: 'MATR')]),
      );

      expect(resultado.statusDe('FGA0147'), StatusMateria.emCurso);
    });

    test('codigoEquivalente do histórico conta como concluída', () {
      final cursoTeste = curso(materias: [materia('FGA0147', id: 1)]);
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0146', status: 'APR', codigoEquivalente: 'FGA0147'),
        ]),
      );

      expect(resultado.statusDe('FGA0147'), StatusMateria.concluida);
    });
  });

  group('resolverStatus — visitante (sem histórico)', () {
    test('sem dados, tudo fica não iniciada', () {
      final cursoTeste = curso(
        materias: [materia('FGA0001', id: 1), materia('FGA0002', id: 2)],
      );
      final resultado = resolverStatus(curso: cursoTeste, dados: null);

      expect(resultado.statusDe('FGA0001'), StatusMateria.naoIniciada);
      expect(resultado.statusDe('FGA0002'), StatusMateria.naoIniciada);
      expect(resultado.codigosConcluidos, isEmpty);
    });
  });

  group('progressoDoCurso', () {
    test('conta só as obrigatórias (nivel > 0)', () {
      final cursoTeste = curso(
        materias: [
          materia('FGA0001', id: 1, nivel: 1),
          materia('FGA0002', id: 2, nivel: 2),
          materia('OPT0001', id: 3, nivel: 0),
        ],
      );
      final resultado = resolverStatus(
        curso: cursoTeste,
        dados: historico([
          registro('FGA0001', status: 'APR'),
          registro('OPT0001', status: 'APR'),
        ]),
      );

      expect(progressoDoCurso(cursoTeste, resultado), closeTo(0.5, 0.0001));
    });

    test('sem obrigatórias, progresso é zero', () {
      final cursoTeste = curso(materias: [materia('OPT0001', id: 1, nivel: 0)]);
      final resultado = resolverStatus(curso: cursoTeste, dados: null);

      expect(progressoDoCurso(cursoTeste, resultado), 0);
    });
  });

  group('encontrarDadosDaMateria', () {
    test('prefere a tentativa aprovada à reprovada antiga', () {
      final dados = historico([
        registro('FGA0001', status: 'REP', mencao: 'MI'),
        registro('FGA0001', status: 'APR', mencao: 'MS'),
      ]);

      final encontrada = encontrarDadosDaMateria(dados, 'FGA0001');
      expect(encontrada?.status, 'APR');
    });

    test('sem histórico retorna null', () {
      expect(encontrarDadosDaMateria(null, 'FGA0001'), isNull);
      expect(encontrarDadosDaMateria(historico([]), 'FGA0001'), isNull);
    });
  });
}
