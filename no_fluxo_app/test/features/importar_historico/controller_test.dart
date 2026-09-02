import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/pdf/historico_pdf_parser.dart';
import 'package:no_fluxo_app/core/pdf/modelos_extracao.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/importar_historico/data/importar_historico_repository.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/casamento.dart';
import 'package:no_fluxo_app/features/importar_historico/providers/importar_historico_controller.dart';

import 'fakes.dart';

void main() {
  late FakeParser parser;
  late FakeRepositorio repo;
  late FakeAuthNotifier auth;
  late ProviderContainer container;

  ProviderContainer montarContainer() {
    final c = ProviderContainer(
      overrides: [
        historicoPdfParserProvider.overrideWithValue(parser),
        importarHistoricoRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    parser = FakeParser();
    repo = FakeRepositorio();
    auth = FakeAuthNotifier(AuthState.loggedIn(userFixture()));
  });

  ImportarHistoricoController notifier() =>
      container.read(importarHistoricoControllerProvider.notifier);

  ImportarHistoricoState estado() =>
      container.read(importarHistoricoControllerProvider);

  final bytes = Uint8List.fromList([1, 2, 3]);

  group('fluxo de sucesso', () {
    test('parse + casamento → sucesso com resumo pós-processado', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
      );

      await notifier().processarArquivo('historico.pdf', bytes);

      expect(estado().etapa, EtapaImportacao.sucesso);
      expect(estado().progresso, 100);
      expect(estado().nomeArquivo, 'historico.pdf');
      // Pós-processamento aplicado: pendentes filtradas + resumo recalculado.
      expect(estado().resultado!.materiasPendentes, hasLength(1));
      expect(estado().resultado!.resumo.totalObrigatorias, 2);
      expect(estado().resultado!.resumo.percentualConclusaoObrigatorias, 50.0);
      // p_dados sem full_text e com as chaves do contrato.
      final pDados = repo.pDadosRecebidos.single;
      expect(pDados.containsKey('full_text'), isFalse);
      expect(pDados['matricula'], '190000000');
      expect(pDados['curso_extraido'], 'ENGENHARIA DE SOFTWARE');
      expect(pDados.containsKey('curso_selecionado'), isFalse);
    });
  });

  group('protocolo COURSE_SELECTION → retry', () {
    test(
      'seleção abre modal e o retry reenvia o MESMO p_dados com o curso',
      () async {
        container = montarContainer();
        await container.read(authProvider.future);
        repo.enfileirar(
          classificarRespostaCasarDisciplinas(respostaRpcSelecaoDeCurso()),
        );
        repo.enfileirar(
          classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
        );

        await notifier().processarArquivo('historico.pdf', bytes);

        expect(estado().etapa, EtapaImportacao.casando);
        expect(estado().progresso, 60);
        expect(estado().selecaoDeCurso, isNotNull);
        expect(estado().selecaoDeCurso!.cursos, hasLength(2));

        await notifier().confirmarCursoSelecionado(
          const OpcaoCurso(
            nomeCurso: 'ENGENHARIA ELETRONICA',
            idCurso: 43,
            matrizCurricular: '6363/1',
          ),
        );

        expect(estado().etapa, EtapaImportacao.sucesso);
        expect(estado().selecaoDeCurso, isNull);

        final retry = repo.pDadosRecebidos[1];
        expect(retry['curso_extraido'], 'ENGENHARIA ELETRONICA');
        expect(retry['curso_selecionado'], 'ENGENHARIA ELETRONICA');
        expect(retry['id_curso_selecionado'], 43);
        // matriz_curricular NÃO é sobrescrita pela escolha.
        expect(retry['matriz_curricular'], '6360/2 - 2017.1');
        // O resto do payload é o mesmo do primeiro envio.
        expect(retry['matricula'], repo.pDadosRecebidos[0]['matricula']);
        expect(
          retry['extracted_data'],
          repo.pDadosRecebidos[0]['extracted_data'],
        );
      },
    );

    test('retry pode voltar COURSE_SELECTION de novo (modal reabre)', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSelecaoDeCurso()),
      );
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSelecaoDeCurso()),
      );

      await notifier().processarArquivo('historico.pdf', bytes);
      await notifier().confirmarCursoSelecionado(
        const OpcaoCurso(nomeCurso: 'X'),
      );

      expect(estado().selecaoDeCurso, isNotNull);
      expect(estado().etapa, EtapaImportacao.casando);
    });

    test('cancelar a seleção vira erro com a mensagem do site', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSelecaoDeCurso()),
      );

      await notifier().processarArquivo('historico.pdf', bytes);
      notifier().cancelarSelecaoDeCurso();

      expect(estado().etapa, EtapaImportacao.erro);
      expect(estado().erro, 'Seleção de curso cancelada. Tente novamente.');
      expect(estado().selecaoDeCurso, isNull);
    });
  });

  group('erros', () {
    test('timeout do repositório vira a mensagem do site na tela', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      repo.enfileirarErro(
        const ImportarHistoricoException(kMsgTimeoutCasamento),
      );

      await notifier().processarArquivo('historico.pdf', bytes);

      expect(estado().etapa, EtapaImportacao.erro);
      expect(estado().erro, kMsgTimeoutCasamento);
    });

    test('PDF sem texto usa a mensagem da exceção do parser', () async {
      parser = FakeParser(onParse: (_, _) => throw PdfSemTextoException());
      container = montarContainer();
      await container.read(authProvider.future);

      await notifier().processarArquivo('historico.pdf', bytes);

      expect(estado().etapa, EtapaImportacao.erro);
      expect(estado().erro, contains('Nenhuma informação textual'));
    });

    test('erro desconhecido no casamento usa a mensagem padrão', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      repo.enfileirarErro(StateError('boom'));

      await notifier().processarArquivo('historico.pdf', bytes);

      expect(estado().erro, 'Erro desconhecido ao processar o PDF.');
    });
  });

  group('salvarFluxograma', () {
    Future<void> chegarNoSucesso() async {
      repo.enfileirar(
        classificarRespostaCasarDisciplinas(respostaRpcSucesso()),
      );
      await notifier().processarArquivo('historico.pdf', bytes);
      expect(estado().etapa, EtapaImportacao.sucesso);
    }

    test('salva string+objeto via repo e recarrega o perfil', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      await chegarNoSucesso();

      final erro = await notifier().salvarFluxograma();

      expect(erro, isNull);
      expect(auth.recarregamentos, 1);
      final salvo = repo.salvamentos.single;
      expect(salvo.idUser, 7);
      expect(salvo.semestreAtual, 5);
      expect(salvo.cargaHorariaIntegralizada, {
        'obrigatoria': 1230,
        'optativa': 300,
        'complementar': 0,
        'total': 1530,
      });

      // JSON snake_case com schema_version carimbado.
      expect(salvo.fluxogramaJson['schema_version'], 2);
      expect(salvo.fluxogramaJson['nome_curso'], 'ENGENHARIA DE SOFTWARE');
      expect(salvo.fluxogramaJson['matricula'], '190000000');
      expect(salvo.fluxogramaJson['ira_texto'], '4,1234');
      expect(salvo.fluxogramaJson['dados_fluxograma'], hasLength(1));

      // Metadados do histórico (linha de historicos_usuarios).
      final meta = salvo.metadados!;
      expect(meta.cursoExtraido, 'ENGENHARIA DE SOFTWARE');
      expect(meta.matricula, '190000000');
      expect(meta.ira, 4.1234);
      expect(meta.mediaPonderada, 4.2);
      expect(meta.resumo!.totalObrigatorias, 2);
      expect(meta.resumo!.percentualConclusaoObrigatorias, 50.0);
    });

    test('equivalências do PDF entram no 1º semestre e no JSON', () async {
      parser = FakeParser(
        resultado: parsedFixture(
          equivalenciasPdf: const [
            EquivalenciaExtraida(
              cumpriu: 'FGA0161',
              nomeCumpriu: 'REQUISITOS',
              atravesDe: 'CIC0104',
              nomeEquivalente: 'ENG REQ',
              chCumpriu: '60',
              chEquivalente: '60',
            ),
          ],
        ),
      );
      container = montarContainer();
      await container.read(authProvider.future);
      await chegarNoSucesso();

      final erro = await notifier().salvarFluxograma();
      expect(erro, isNull);

      final json = repo.salvamentos.single.fluxogramaJson;
      expect(json['equivalencias_pdf'], [
        {
          'cumpriu': 'FGA0161',
          'atraves_de': 'CIC0104',
          'nome_cumpriu': 'REQUISITOS',
          'nome_equivalente': 'ENG REQ',
        },
      ]);
      final primeiroSemestre = (json['dados_fluxograma'] as List).first as List;
      final injetada = primeiroSemestre.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['codigo'] == 'FGA0161',
      );
      expect(injetada['status'], 'CUMP');
      expect(injetada['tipo_dado'], 'equivalencia');
    });

    test('falha ao salvar retorna mensagem e não recarrega perfil', () async {
      container = montarContainer();
      await container.read(authProvider.future);
      await chegarNoSucesso();
      repo.erroAoSalvar = const ImportarHistoricoException(
        'Erro ao salvar fluxograma: RLS',
      );

      final erro = await notifier().salvarFluxograma();

      expect(erro, 'Erro ao salvar fluxograma: RLS');
      expect(auth.recarregamentos, 0);
    });

    test(
      'sem resultado ou sem usuário → mensagem de dados insuficientes',
      () async {
        container = montarContainer();
        await container.read(authProvider.future);
        expect(
          await notifier().salvarFluxograma(),
          'Dados insuficientes para salvar.',
        );
      },
    );
  });

  group('modo manual', () {
    test('salva fluxograma zerado com matricula Manual e schema 2', () async {
      container = montarContainer();
      await container.read(authProvider.future);

      final erro = await notifier().iniciarModoManual(
        const OpcaoCurso(
          nomeCurso: 'ENGENHARIA DE SOFTWARE',
          idCurso: 42,
          matrizCurricular: '6360/2 - 2017.1',
        ),
      );

      expect(erro, isNull);
      expect(auth.recarregamentos, 1);
      final salvo = repo.salvamentos.single;
      expect(salvo.semestreAtual, 1);
      final json = salvo.fluxogramaJson;
      expect(json['matricula'], 'Manual');
      expect(json['nome_curso'], 'ENGENHARIA DE SOFTWARE');
      expect(json['matriz_curricular'], '6360/2 - 2017.1');
      expect(json['semestre_atual'], 1);
      expect(json['ano_atual'], '${DateTime.now().year}.1');
      expect(json['dados_fluxograma'], isEmpty);
      expect(json['schema_version'], 2);
      expect(salvo.metadados!.matricula, 'Manual');
    });

    test('deslogado → mensagem de login', () async {
      auth = FakeAuthNotifier(const AuthState.loggedOut());
      container = montarContainer();
      await container.read(authProvider.future);
      expect(
        await notifier().iniciarModoManual(const OpcaoCurso(nomeCurso: 'X')),
        'Você precisa estar logado.',
      );
    });
  });

  test('reset volta ao estado inicial', () async {
    container = montarContainer();
    await container.read(authProvider.future);
    repo.enfileirarErro(StateError('boom'));
    await notifier().processarArquivo('historico.pdf', bytes);
    expect(estado().etapa, EtapaImportacao.erro);

    notifier().reset();

    expect(estado().etapa, EtapaImportacao.inicial);
    expect(estado().progresso, 0);
    expect(estado().erro, isNull);
    expect(estado().extraido, isNull);
  });
}
