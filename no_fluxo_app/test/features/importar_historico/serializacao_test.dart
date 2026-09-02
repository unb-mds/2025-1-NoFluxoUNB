import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/montagem_fluxograma.dart';

/// Serialização snake_case contra golden map — espelho exato de
/// `dadosFluxogramaUserToJson`/`dadosMateriaToJson` do site.
void main() {
  test('dadosFluxogramaUserParaJson — golden com todos os campos', () {
    final dados = DadosFluxogramaUser(
      nomeCurso: 'ENGENHARIA DE SOFTWARE',
      ira: 4.1234,
      iraTexto: '4,1234',
      matricula: '190000000',
      matrizCurricular: '6360/2 - 2017.1',
      semestreAtual: 5,
      anoAtual: '2025.1',
      horasIntegralizadas: 1530,
      suspensoes: ['2024.1'],
      dadosFluxograma: [
        [
          DadosMateria(
            codigoMateria: 'MAT0025',
            mencao: 'MS',
            professor: 'Prof. X',
            status: 'APR',
            anoPeriodo: '2023.1',
            frequencia: '100',
            tipoDado: 'Disciplina Regular',
            turma: 'A',
          ),
          DadosMateria(
            codigoMateria: 'FGA0161',
            status: 'CUMP',
            tipoDado: 'equivalencia',
            codigoEquivalente: 'CIC0104',
            nomeEquivalente: 'ENG DE REQUISITOS',
            nomeMateria: 'REQUISITOS',
            creditos: 4,
            nivel: 3,
            nivelDestino: 2,
            isManual: true,
          ),
        ],
      ],
      optativasPlanejadas: const [
        OptativaPlanejadaRef(codigoMateria: 'CIC0007', semestre: 6),
      ],
      schemaVersion: kFluxogramaSchemaVersion,
    );

    final json = dadosFluxogramaUserParaJson(
      dados,
      equivalenciasPdf: const [
        EquivalenciaPdfNormalizada(
          cumpriu: 'FGA0161',
          atravesDe: 'CIC0104',
          nomeCumpriu: 'REQUISITOS',
        ),
      ],
    );

    expect(json, {
      'nome_curso': 'ENGENHARIA DE SOFTWARE',
      'ira': 4.1234,
      'ira_texto': '4,1234',
      'matricula': '190000000',
      'matriz_curricular': '6360/2 - 2017.1',
      'semestre_atual': 5,
      'ano_atual': '2025.1',
      'horas_integralizadas': 1530,
      'suspensoes': ['2024.1'],
      'dados_fluxograma': [
        [
          {
            'codigo': 'MAT0025',
            'mencao': 'MS',
            'professor': 'Prof. X',
            'status': 'APR',
            'ano_periodo': '2023.1',
            'frequencia': '100',
            'tipo_dado': 'Disciplina Regular',
            'turma': 'A',
            'is_manual': false,
          },
          {
            'codigo': 'FGA0161',
            'mencao': '-',
            'professor': '',
            'status': 'CUMP',
            'ano_periodo': null,
            'frequencia': null,
            'tipo_dado': 'equivalencia',
            'turma': null,
            'codigo_equivalente': 'CIC0104',
            'nome_equivalente': 'ENG DE REQUISITOS',
            'is_manual': true,
            'nivel_destino': 2,
            'nivel': 3,
            'nome_materia': 'REQUISITOS',
            'creditos': 4,
          },
        ],
      ],
      'optativas_planejadas': [
        {'codigo_materia': 'CIC0007', 'semestre': 6},
      ],
      'equivalencias_pdf': [
        {
          'cumpriu': 'FGA0161',
          'atraves_de': 'CIC0104',
          'nome_cumpriu': 'REQUISITOS',
        },
      ],
      'schema_version': 2,
    });
  });

  test('opcionais ausentes são OMITIDOS (não viram null)', () {
    final json = dadosFluxogramaUserParaJson(
      DadosFluxogramaUser(
        nomeCurso: 'CURSO',
        matricula: 'Manual',
        anoAtual: '2026.1',
        matrizCurricular: '8184/1',
        semestreAtual: 1,
        dadosFluxograma: [],
      ),
    );

    expect(json, {
      'nome_curso': 'CURSO',
      'ira': 0.0,
      'matricula': 'Manual',
      'matriz_curricular': '8184/1',
      'semestre_atual': 1,
      'ano_atual': '2026.1',
      'horas_integralizadas': 0,
      'suspensoes': <String>[],
      'dados_fluxograma': <List<Map<String, dynamic>>>[],
    });
    expect(json.containsKey('ira_texto'), isFalse);
    expect(json.containsKey('optativas_planejadas'), isFalse);
    expect(json.containsKey('equivalencias_pdf'), isFalse);
    expect(json.containsKey('schema_version'), isFalse);
  });

  test('ira_texto vazio é omitido como no site', () {
    final json = dadosFluxogramaUserParaJson(DadosFluxogramaUser(iraTexto: ''));
    expect(json.containsKey('ira_texto'), isFalse);
  });
}
