import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/features/importar_historico/data/importar_historico_repository.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/casamento.dart';

import 'fakes.dart';

void main() {
  group('classificarRespostaCasarDisciplinas', () {
    test('cursos_disponiveis sem disciplinas_casadas → seleção de curso '
        '(sem olhar o campo type)', () {
      final resposta = classificarRespostaCasarDisciplinas(
        respostaRpcSelecaoDeCurso(),
      );
      expect(resposta, isA<CasamentoPrecisaDeCurso>());
      final selecao = (resposta as CasamentoPrecisaDeCurso).selecao;
      expect(selecao.mensagem, 'Encontramos mais de um curso possível.');
      expect(selecao.cursos, hasLength(2));
      expect(selecao.cursos.first.idCurso, 42);
      expect(selecao.cursos.first.nomeCurso, 'ENGENHARIA DE SOFTWARE');
      expect(selecao.cursos.first.matrizCurricular, '6360/2 - 2017.1');
    });

    test('cursos_disponiveis JUNTO de disciplinas_casadas → sucesso', () {
      final json = respostaRpcSucesso()
        ..['cursos_disponiveis'] = [
          {'nome_curso': 'QUALQUER'},
        ];
      expect(
        classificarRespostaCasarDisciplinas(json),
        isA<CasamentoConcluido>(),
      );
    });

    test('error sem cursos_disponiveis → exceção com a mensagem', () {
      expect(
        () => classificarRespostaCasarDisciplinas({
          'error': 'Curso não encontrado no banco.',
        }),
        throwsA(
          isA<ImportarHistoricoException>().having(
            (e) => e.message,
            'message',
            'Curso não encontrado no banco.',
          ),
        ),
      );
    });

    test('error COM cursos_disponiveis → seleção (mensagem = error)', () {
      final resposta = classificarRespostaCasarDisciplinas({
        'error': 'Múltiplos cursos.',
        'cursos_disponiveis': [
          {'nome_curso': 'A'},
        ],
      });
      expect(resposta, isA<CasamentoPrecisaDeCurso>());
      expect(
        (resposta as CasamentoPrecisaDeCurso).selecao.mensagem,
        'Múltiplos cursos.',
      );
    });
  });

  group('normalizarPendentesObrigatoriasResumo (sempre roda no sucesso)', () {
    test('filtra optativas e nivel 0 das pendentes e recalcula o resumo', () {
      final resposta =
          classificarRespostaCasarDisciplinas(respostaRpcSucesso())
              as CasamentoConcluido;
      final r = resposta.resultado;

      // Das 3 pendentes cruas, só a obrigatória de nivel 2 sobra.
      expect(r.materiasPendentes, hasLength(1));
      expect(r.materiasPendentes.single['codigo'], 'FGA0158');

      // Resumo recalculado: 1 concluída + 1 pendente = 2 obrigatórias, 50%.
      expect(r.resumo.totalObrigatoriasConcluidas, 1);
      expect(r.resumo.totalObrigatoriasPendentes, 1);
      expect(r.resumo.totalObrigatorias, 2);
      expect(r.resumo.percentualConclusaoObrigatorias, 50.0);
      // Campos não recalculados são preservados.
      expect(r.resumo.totalDisciplinas, 4);
      expect(r.resumo.totalOptativas, 1);
    });

    test('percentual com arredondamento de 2 casas (round half up)', () {
      final r = CasarDisciplinasResultado(
        materiasPendentes: [
          {'codigo': 'A', 'nivel': 1},
          {'codigo': 'B', 'nivel': 2},
        ],
        resumo: const ResumoCasamento(totalObrigatoriasConcluidas: 1),
      );
      normalizarPendentesObrigatoriasResumo(r);
      // 1/3 = 33.333...% → 33.33
      expect(r.resumo.percentualConclusaoObrigatorias, 33.33);
    });

    test('sem obrigatórias → percentual 0', () {
      final r = CasarDisciplinasResultado();
      normalizarPendentesObrigatoriasResumo(r);
      expect(r.resumo.totalObrigatorias, 0);
      expect(r.resumo.percentualConclusaoObrigatorias, 0);
    });
  });

  group('ImportarHistoricoRepositorySupabase (seam de RPC)', () {
    test('timeout de 30s vira a mensagem do site', () async {
      final repo = ImportarHistoricoRepositorySupabase(
        timeoutRpc: const Duration(milliseconds: 20),
        rpcOverride: (_) =>
            Future<dynamic>.delayed(const Duration(milliseconds: 300)),
      );
      await expectLater(
        repo.casarDisciplinas(const {}),
        throwsA(
          isA<ImportarHistoricoException>().having(
            (e) => e.message,
            'message',
            kMsgTimeoutCasamento,
          ),
        ),
      );
    });

    test('envia o p_dados recebido e classifica a resposta', () async {
      Map<String, dynamic>? enviado;
      final repo = ImportarHistoricoRepositorySupabase(
        rpcOverride: (pDados) async {
          enviado = pDados;
          return respostaRpcSucesso();
        },
      );
      final resposta = await repo.casarDisciplinas(const {'matricula': '19'});
      expect(enviado, {'matricula': '19'});
      expect(resposta, isA<CasamentoConcluido>());
    });
  });
}
