import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/curso_model.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/features/fluxograma/data/fluxograma_repository.dart';
import 'package:no_fluxo_app/features/fluxograma/domain/status_resolver.dart';

/// Fixtures no shape exato das respostas do Supabase (ver
/// `supabase-data.service.ts` do site).
Map<String, dynamic> cursoRowFixture() => {
  'id_curso': 10,
  'nome_curso': 'ENGENHARIA DE SOFTWARE',
  'tipo_curso': 'BACHARELADO',
  'classificacao': 'graduacao',
  'creditos': 240,
};

List<Map<String, dynamic>> materiasRowsFixture() => [
  {
    'id_materia': 1,
    'nivel': 1,
    'tipo_natureza': 0,
    'materias': {
      'id_materia': 1,
      'codigo_materia': 'FGA0158',
      'nome_materia': 'CÁLCULO 1',
      'carga_horaria': 90,
      'ementa': 'Limites, derivadas e integrais.',
    },
  },
  {
    'id_materia': 2,
    'nivel': 2,
    'tipo_natureza': 0,
    'materias': {
      'id_materia': 2,
      'codigo_materia': 'FGA0161',
      'nome_materia': 'CÁLCULO 2',
      'carga_horaria': 90,
      'ementa': '',
    },
  },
  {
    'id_materia': 3,
    'nivel': 0,
    'tipo_natureza': 1,
    'materias': {
      'id_materia': 3,
      'codigo_materia': 'FGA0999',
      'nome_materia': 'OPTATIVA LEGAL',
      'carga_horaria': 60,
      'ementa': '',
    },
  },
];

List<Map<String, dynamic>> preRequisitosRowsFixture() => [
  {
    'id_pre_requisito': 100,
    'id_materia': 2,
    'id_materia_requisito': 1,
    // Join aninhado, como o PostgREST devolve.
    'materias': {'codigo_materia': 'FGA0158', 'nome_materia': 'CÁLCULO 1'},
  },
];

List<Map<String, dynamic>> equivalenciasRowsFixture() => [
  // Global (vale para qualquer curso).
  {
    'id_equivalencia': 1,
    'id_materia': 1,
    'id_curso': null,
    'curriculo': null,
    'expressao_original': 'MAT0025',
    'materias': {'codigo_materia': 'FGA0158', 'nome_materia': 'CÁLCULO 1'},
  },
  // Específica de outro curso — deve ser descartada.
  {
    'id_equivalencia': 2,
    'id_materia': 2,
    'id_curso': 77,
    'curriculo': null,
    'expressao_original': 'MAT0026',
    'materias': {'codigo_materia': 'FGA0161', 'nome_materia': 'CÁLCULO 2'},
  },
  // Do curso alvo — deve prevalecer sobre a global da mesma matéria.
  {
    'id_equivalencia': 3,
    'id_materia': 2,
    'id_curso': 10,
    'curriculo': null,
    'expressao_original': 'MAT0026 E MAT0027',
    'materias': {'codigo_materia': 'FGA0161', 'nome_materia': 'CÁLCULO 2'},
  },
];

void main() {
  group('FluxogramaRepository.montarCursoModel', () {
    final curso = FluxogramaRepository.montarCursoModel(
      cursoRow: cursoRowFixture(),
      curriculoCompleto: '6360/2',
      idCurso: 10,
      materiasRows: materiasRowsFixture(),
      preRequisitosRows: preRequisitosRowsFixture(),
      equivalenciasRows: equivalenciasRowsFixture(),
    );

    test('mapeia os dados do curso e da matriz', () {
      expect(curso.nomeCurso, 'ENGENHARIA DE SOFTWARE');
      expect(curso.idCurso, 10);
      expect(curso.matrizCurricular, '6360/2');
      expect(curso.semestres, 2);
    });

    test('mapeia matérias com nível e créditos (carga horária / 15)', () {
      expect(curso.materias, hasLength(3));

      final calculo1 = curso.materias.firstWhere(
        (materia) => materia.codigoMateria == 'FGA0158',
      );
      expect(calculo1.nomeMateria, 'CÁLCULO 1');
      expect(calculo1.nivel, 1);
      expect(calculo1.creditos, 6); // 90 / 15
      expect(calculo1.ementa, 'Limites, derivadas e integrais.');

      final optativa = curso.materias.firstWhere(
        (materia) => materia.codigoMateria == 'FGA0999',
      );
      expect(optativa.nivel, 0); // optativa
      expect(optativa.creditos, 4); // 60 / 15
    });

    test('achata o join do pré-requisito e liga as matérias', () {
      expect(curso.preRequisitos, hasLength(1));
      expect(curso.preRequisitos.single.codigoMateriaRequisito, 'FGA0158');
      expect(curso.preRequisitos.single.idMateria, 2);

      final calculo2 = curso.materias.firstWhere(
        (materia) => materia.codigoMateria == 'FGA0161',
      );
      expect(calculo2.getPrerequisiteCodes(), contains('FGA0158'));
    });

    test('resolve código de origem da equivalência pelo join', () {
      final origem = curso.equivalencias
          .map((equivalencia) => equivalencia.codigoMateriaOrigem)
          .toSet();
      expect(origem, contains('FGA0158'));
    });

    test('equivalência do curso prevalece; a de outro curso é descartada', () {
      final deCalculo2 = curso.equivalencias
          .where(
            (equivalencia) => equivalencia.codigoMateriaOrigem == 'FGA0161',
          )
          .toList();
      expect(deCalculo2, hasLength(1));
      expect(deCalculo2.single.expressao, 'MAT0026 E MAT0027');
      expect(deCalculo2.single.idCurso, 10);
    });
  });

  group('FluxogramaRepository.montarCursoModel — expressao_logica', () {
    /// Linha no formato real do banco: sem id_materia_requisito (o join
    /// `materias` volta null), só expressao_original + expressao_logica.
    Map<String, dynamic> preReqExpressaoRow({dynamic expressaoLogica}) => {
      'id_pre_requisito': 200,
      'id_materia': 2,
      'id_materia_requisito': null,
      'expressao_original': '( FGA0158 ) OU ( MAT0025 )',
      'expressao_logica':
          expressaoLogica ??
          {
            'operador': 'OU',
            'condicoes': ['FGA0158', 'MAT0025'],
          },
      'materias': null,
    };

    CursoModel montar(List<Map<String, dynamic>> preReqRows) =>
        FluxogramaRepository.montarCursoModel(
          cursoRow: cursoRowFixture(),
          curriculoCompleto: '6360/2',
          idCurso: 10,
          materiasRows: materiasRowsFixture(),
          preRequisitosRows: preReqRows,
          equivalenciasRows: const [],
        );

    test('mantém a linha de pré-requisito só com expressão (join nulo)', () {
      final curso = montar([preReqExpressaoRow()]);

      expect(curso.preRequisitos, hasLength(1));
      final preReq = curso.preRequisitos.single;
      expect(preReq.idMateria, 2);
      expect(preReq.expressaoOriginal, '( FGA0158 ) OU ( MAT0025 )');
      expect(preReq.expressaoLogica, isNotNull);
    });

    test('expressao_logica vinda como String JSON é decodificada', () {
      final curso = montar([
        preReqExpressaoRow(
          expressaoLogica: '{"operador":"E","condicoes":["FGA0158","MAT0025"]}',
        ),
      ]);

      final expressao = curso.preRequisitos.single.expressaoLogica;
      expect(expressao, isA<Map<dynamic, dynamic>>());
      expect((expressao as Map)['operador'], 'E');
    });

    test('ponta a ponta: "A OU B" com só B aprovada libera a matéria', () {
      final curso = montar([preReqExpressaoRow()]);

      final comB = resolverStatus(
        curso: curso,
        dados: DadosFluxogramaUser(
          dadosFluxograma: [
            [DadosMateria(codigoMateria: 'MAT0025', status: 'APR')],
          ],
        ),
      );
      expect(comB.statusDe('FGA0161'), StatusMateria.disponivel);

      final semNada = resolverStatus(
        curso: curso,
        dados: DadosFluxogramaUser(dadosFluxograma: const [[]]),
      );
      expect(semNada.statusDe('FGA0161'), StatusMateria.bloqueada);
    });
  });

  group('FluxogramaRepository.filtrarEquivalencias', () {
    test('currículo exato prevalece sobre id_curso e global', () {
      final rows = [
        {
          'id_equivalencia': 1,
          'id_materia': 1,
          'id_curso': null,
          'curriculo': null,
          'expressao_original': 'GLOBAL01',
          'materias': {'codigo_materia': 'FGA0001', 'nome_materia': 'A'},
        },
        {
          'id_equivalencia': 2,
          'id_materia': 1,
          'id_curso': 10,
          'curriculo': '6360/2',
          'expressao_original': 'ESPEC01',
          'materias': {'codigo_materia': 'FGA0001', 'nome_materia': 'A'},
        },
      ];

      final filtradas = FluxogramaRepository.filtrarEquivalencias(
        rows,
        idCurso: 10,
        curriculoCompleto: '6360/2',
      );

      expect(filtradas, hasLength(1));
      expect(filtradas.single['expressao'], 'ESPEC01');
    });

    test('sem match específico, cai na global', () {
      final rows = [
        {
          'id_equivalencia': 1,
          'id_materia': 1,
          'id_curso': null,
          'curriculo': null,
          'expressao_original': 'GLOBAL01',
          'materias': {'codigo_materia': 'FGA0001', 'nome_materia': 'A'},
        },
      ];

      final filtradas = FluxogramaRepository.filtrarEquivalencias(
        rows,
        idCurso: 10,
        curriculoCompleto: '6360/2',
      );

      expect(filtradas, hasLength(1));
      expect(filtradas.single['expressao'], 'GLOBAL01');
    });

    test('linhas inválidas (sem id_materia) são ignoradas', () {
      final filtradas = FluxogramaRepository.filtrarEquivalencias(
        [
          {'id_equivalencia': 1, 'expressao_original': 'X'},
          'lixo',
        ],
        idCurso: 10,
        curriculoCompleto: '6360/2',
      );

      expect(filtradas, isEmpty);
    });
  });
}
