import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/pdf/modelos_extracao.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/casamento.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/montagem_fluxograma.dart';

void main() {
  group('montarDadosFluxogramaUser', () {
    CasarDisciplinasResultado resultadoBase() => CasarDisciplinasResultado(
      disciplinasCasadas: [
        {
          'codigo_materia': 'MAT0025',
          'codigo': 'MAT0025',
          'status': 'APR',
          'mencao': 'MS',
          'professor': 'Prof. X',
          'ano_periodo': '2023.1',
        },
        {
          // Cursada como equivalente (código do histórico ≠ da matriz).
          'codigo_materia': 'FGA0158',
          'codigo_historico': 'CIC0004',
          'nome_historico': 'APC',
          'status': 'APR',
          'mencao': 'SS',
        },
      ],
      materiasConcluidas: [
        {
          'codigo_materia': 'FGA0160',
          'status_fluxograma': 'concluida_equivalencia',
          'status': 'CUMP',
          'mencao': '-',
          'codigo_equivalente': 'ENE0111',
          'nome_equivalente': 'CIRCUITOS',
        },
        {
          // Concluída normal (não-equivalência): NÃO entra de novo.
          'codigo_materia': 'MAT0025',
          'status_fluxograma': 'concluida',
        },
      ],
      dadosValidacao: const {
        'ira': 4.1234,
        'ira_texto': '4,1234',
        'horas_integralizadas': 1530,
      },
    );

    const meta = MetaHistorico(
      nomeCurso: 'ENGENHARIA DE SOFTWARE',
      matricula: '190000000',
      anoAtual: '2025.1',
      matrizCurricular: '6360/2 - 2017.1',
      semestreAtual: 5,
      suspensoes: ['2024.1'],
    );

    test('monta UM único semestre com casadas + equivalências extras', () {
      final dados = montarDadosFluxogramaUser(
        resultado: resultadoBase(),
        meta: meta,
      );

      expect(dados.dadosFluxograma, hasLength(1));
      final semestre = dados.dadosFluxograma.single;
      expect(semestre.map((m) => m.codigoMateria), [
        'MAT0025',
        'FGA0158',
        'FGA0160',
      ]);

      expect(dados.nomeCurso, 'ENGENHARIA DE SOFTWARE');
      expect(dados.matricula, '190000000');
      expect(dados.anoAtual, '2025.1');
      expect(dados.matrizCurricular, '6360/2 - 2017.1');
      expect(dados.semestreAtual, 5);
      expect(dados.suspensoes, ['2024.1']);
      expect(dados.ira, 4.1234);
      expect(dados.iraTexto, '4,1234');
      expect(dados.horasIntegralizadas, 1530);
    });

    test('aprovada cursada como equivalente vira tipo equivalencia', () {
      final dados = montarDadosFluxogramaUser(
        resultado: resultadoBase(),
        meta: meta,
      );
      final fga = dados.dadosFluxograma.single.firstWhere(
        (m) => m.codigoMateria == 'FGA0158',
      );
      expect(fga.tipoDado, 'equivalencia');
      expect(fga.codigoEquivalente, 'CIC0004');
      expect(fga.nomeEquivalente, 'APC');
      expect(fga.status, 'APR');
    });

    test('equivalência do banco que não casou entra como CUMP', () {
      final dados = montarDadosFluxogramaUser(
        resultado: resultadoBase(),
        meta: meta,
      );
      final extra = dados.dadosFluxograma.single.firstWhere(
        (m) => m.codigoMateria == 'FGA0160',
      );
      expect(extra.status, 'CUMP');
      expect(extra.tipoDado, 'equivalencia');
      expect(extra.codigoEquivalente, 'ENE0111');
      expect(extra.nomeEquivalente, 'CIRCUITOS');
    });

    test('equivalência do banco mescla nos dados da casada aprovada', () {
      final resultado = resultadoBase();
      resultado.materiasConcluidas.add({
        'codigo_materia': 'MAT0025',
        'status_fluxograma': 'concluida_equivalencia',
        'status': 'CUMP',
        'mencao': 'MM',
        'professor': 'Prof. Equiv',
        'codigo_equivalente': 'MAT0999',
      });
      final dados = montarDadosFluxogramaUser(resultado: resultado, meta: meta);
      final mat = dados.dadosFluxograma.single.firstWhere(
        (m) => m.codigoMateria == 'MAT0025',
      );
      expect(mat.tipoDado, 'equivalencia');
      expect(mat.status, 'CUMP');
      expect(mat.mencao, 'MM');
      expect(mat.professor, 'Prof. Equiv');
      expect(mat.codigoEquivalente, 'MAT0999');
      // E não duplica no fim do semestre.
      expect(
        dados.dadosFluxograma.single.where((m) => m.codigoMateria == 'MAT0025'),
        hasLength(1),
      );
    });

    test('iraTexto do parâmetro (PDF) prevalece sobre dados_validacao', () {
      final dados = montarDadosFluxogramaUser(
        resultado: resultadoBase(),
        meta: meta,
        iraTexto: '4,9999',
      );
      expect(dados.iraTexto, '4,9999');
    });
  });

  group('injetarEquivalenciasDoPdf', () {
    DadosFluxogramaUser dadosCom(List<DadosMateria> semestre) =>
        DadosFluxogramaUser(dadosFluxograma: [semestre]);

    test('par que falta entra no 1º semestre como CUMP/equivalencia', () {
      final dados = dadosCom([
        DadosMateria(codigoMateria: 'MAT0025', status: 'APR'),
      ]);
      final pares = injetarEquivalenciasDoPdf(dados, const [
        EquivalenciaExtraida(
          cumpriu: 'fga0161',
          nomeCumpriu: 'REQUISITOS',
          atravesDe: 'cic0104',
          nomeEquivalente: 'ENGENHARIA DE REQUISITOS',
          chCumpriu: '60',
          chEquivalente: '60',
        ),
      ]);

      expect(pares, hasLength(1));
      expect(pares.single.cumpriu, 'FGA0161'); // normalizado em caixa alta
      expect(pares.single.atravesDe, 'CIC0104');

      final injetada = dados.dadosFluxograma.first.last;
      expect(injetada.codigoMateria, 'FGA0161');
      expect(injetada.status, 'CUMP');
      expect(injetada.tipoDado, 'equivalencia');
      expect(injetada.codigoEquivalente, 'CIC0104');
      expect(injetada.nomeMateria, 'REQUISITOS');
      expect(injetada.nomeEquivalente, 'ENGENHARIA DE REQUISITOS');
    });

    test('par cujo alvo já está APR/CUMP/equivalência é ignorado', () {
      final dados = dadosCom([
        DadosMateria(codigoMateria: 'FGA0161', status: 'APR'),
      ]);
      final pares = injetarEquivalenciasDoPdf(dados, const [
        EquivalenciaExtraida(
          cumpriu: 'FGA0161',
          nomeCumpriu: '',
          atravesDe: 'CIC0104',
          nomeEquivalente: '',
          chCumpriu: '60',
          chEquivalente: '60',
        ),
      ]);
      // Pares continuam normalizados (vão para equivalencias_pdf)...
      expect(pares, hasLength(1));
      // ...mas nada é injetado no fluxograma.
      expect(dados.dadosFluxograma.first, hasLength(1));
    });

    test('pares inválidos (códigos vazios) são descartados', () {
      final dados = dadosCom([]);
      final pares = injetarEquivalenciasDoPdf(dados, const [
        EquivalenciaExtraida(
          cumpriu: '  ',
          nomeCumpriu: '',
          atravesDe: 'CIC0104',
          nomeEquivalente: '',
          chCumpriu: '',
          chEquivalente: '',
        ),
      ]);
      expect(pares, isEmpty);
      expect(dados.dadosFluxograma.first, isEmpty);
    });

    test('fluxograma vazio ganha um primeiro semestre', () {
      final dados = DadosFluxogramaUser(dadosFluxograma: []);
      injetarEquivalenciasDoPdf(dados, const [
        EquivalenciaExtraida(
          cumpriu: 'FGA0161',
          nomeCumpriu: '',
          atravesDe: 'CIC0104',
          nomeEquivalente: '',
          chCumpriu: '60',
          chEquivalente: '60',
        ),
      ]);
      expect(dados.dadosFluxograma, hasLength(1));
      expect(dados.dadosFluxograma.first.single.codigoMateria, 'FGA0161');
    });
  });
}
