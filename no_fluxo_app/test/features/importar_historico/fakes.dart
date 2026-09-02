import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_fluxo_app/core/models/user_model.dart';
import 'package:no_fluxo_app/core/pdf/historico_pdf_parser.dart';
import 'package:no_fluxo_app/core/pdf/modelos_extracao.dart';
import 'package:no_fluxo_app/core/services/auth_service.dart';
import 'package:no_fluxo_app/features/importar_historico/data/importar_historico_repository.dart';
import 'package:no_fluxo_app/features/importar_historico/data/selecionador_arquivo.dart';
import 'package:no_fluxo_app/features/importar_historico/domain/casamento.dart';

/// Parser fake — o real (parser_posicional) pode não estar pronto; a feature
/// depende só do contrato.
class FakeParser implements HistoricoPdfParser {
  final Future<ParsedPdfResult> Function(Uint8List bytes, String filename)?
  onParse;
  final ParsedPdfResult? resultado;
  int chamadas = 0;

  FakeParser({this.onParse, this.resultado});

  @override
  Future<ParsedPdfResult> parse(Uint8List bytes, String filename) {
    chamadas++;
    if (onParse != null) return onParse!(bytes, filename);
    return Future.value(resultado ?? parsedFixture());
  }
}

/// Repositório fake: devolve respostas enfileiradas e grava tudo o que
/// recebeu (p_dados, salvamentos).
class FakeRepositorio implements ImportarHistoricoRepository {
  final Queue<RespostaCasamento Function()> respostas = Queue();
  final List<Map<String, dynamic>> pDadosRecebidos = [];
  final List<SalvamentoRegistrado> salvamentos = [];
  List<OpcaoCurso> opcoesDeCurso = const [];
  Object? erroAoSalvar;

  void enfileirar(RespostaCasamento resposta) {
    respostas.add(() => resposta);
  }

  void enfileirarErro(Object erro) {
    respostas.add(() => throw erro);
  }

  @override
  Future<RespostaCasamento> casarDisciplinas(
    Map<String, dynamic> pDados,
  ) async {
    pDadosRecebidos.add(pDados);
    if (respostas.isEmpty) {
      throw StateError('FakeRepositorio sem resposta enfileirada');
    }
    return respostas.removeFirst()();
  }

  @override
  Future<void> salvarFluxograma({
    required int idUser,
    required Map<String, dynamic> fluxogramaJson,
    int? semestreAtual,
    Map<String, dynamic>? cargaHorariaIntegralizada,
    MetadadosEnvioHistorico? metadados,
  }) async {
    if (erroAoSalvar != null) throw erroAoSalvar!;
    salvamentos.add(
      SalvamentoRegistrado(
        idUser: idUser,
        fluxogramaJson: fluxogramaJson,
        semestreAtual: semestreAtual,
        cargaHorariaIntegralizada: cargaHorariaIntegralizada,
        metadados: metadados,
      ),
    );
  }

  @override
  Future<List<OpcaoCurso>> buscarOpcoesDeCurso() async => opcoesDeCurso;
}

class SalvamentoRegistrado {
  final int idUser;
  final Map<String, dynamic> fluxogramaJson;
  final int? semestreAtual;
  final Map<String, dynamic>? cargaHorariaIntegralizada;
  final MetadadosEnvioHistorico? metadados;

  const SalvamentoRegistrado({
    required this.idUser,
    required this.fluxogramaJson,
    this.semestreAtual,
    this.cargaHorariaIntegralizada,
    this.metadados,
  });
}

/// Auth fake: estado fixo, sem Supabase; registra o recarregarPerfil.
class FakeAuthNotifier extends AuthNotifier {
  final AuthState estadoInicial;

  /// Estado aplicado quando recarregarPerfil é chamado (simula o perfil
  /// voltando do banco com o fluxograma novo).
  AuthState? estadoAposRecarregar;
  int recarregamentos = 0;

  FakeAuthNotifier(this.estadoInicial);

  @override
  Future<AuthState> build() async => estadoInicial;

  @override
  Future<void> recarregarPerfil() async {
    recarregamentos++;
    final novo = estadoAposRecarregar;
    if (novo != null) state = AsyncData(novo);
  }
}

/// Seletor de arquivo fake (o file_picker não roda em teste de widget).
class FakeSelecionador implements SelecionadorDeArquivo {
  ArquivoPdfSelecionado? proximoArquivo;

  @override
  Future<ArquivoPdfSelecionado?> selecionarPdf() async => proximoArquivo;
}

/// Usuário logado padrão dos testes.
UserModel userFixture({DadosFluxogramaUser? dados}) => UserModel(
  idUser: 7,
  email: 'ana@aluno.unb.br',
  nomeCompleto: 'Ana Silva',
  dadosFluxograma: dados,
);

/// ParsedPdfResult típico (com IRA, equivalência do PDF e carga horária).
ParsedPdfResult parsedFixture({
  String? cursoExtraido = 'ENGENHARIA DE SOFTWARE',
  List<EquivalenciaExtraida> equivalenciasPdf = const [],
}) => ParsedPdfResult(
  filename: 'historico.pdf',
  matricula: '190000000',
  cursoExtraido: cursoExtraido,
  matrizCurricular: '6360/2 - 2017.1',
  mediaPonderada: 4.2,
  extractedData: const [
    DisciplinaExtraida(
      tipoDado: 'Disciplina Regular',
      nome: 'CALCULO 1',
      status: 'APR',
      mencao: 'MS',
      codigo: 'MAT0025',
      creditos: 6,
      cargaHoraria: 90,
      anoPeriodo: '2023.1',
    ),
    DisciplinaExtraida(
      tipoDado: 'IRA',
      iraValor: 4.1234,
      iraValorTexto: '4,1234',
    ),
  ],
  equivalenciasPdf: equivalenciasPdf,
  semestreAtual: '2025.1',
  numeroSemestre: 5,
  suspensoes: ['2024.1'],
  cargaHorariaIntegralizada: const CargaHorariaExtraida(
    obrigatoria: 1230,
    optativa: 300,
    complementar: 0,
    total: 1530,
  ),
);

/// Resposta de sucesso da RPC (crua, antes do pós-processamento).
Map<String, dynamic> respostaRpcSucesso() => {
  'disciplinas_casadas': [
    {
      'codigo_materia': 'MAT0025',
      'codigo': 'MAT0025',
      'status': 'APR',
      'mencao': 'MS',
      'professor': 'Prof. X',
      'ano_periodo': '2023.1',
      'tipo_dado': 'Disciplina Regular',
    },
  ],
  'materias_concluidas': <Map<String, dynamic>>[],
  'materias_pendentes': [
    {'codigo': 'FGA0158', 'tipo': 'obrigatoria', 'nivel': 2},
    {'codigo': 'OPT0001', 'tipo': 'optativa'},
    {'codigo': 'FGA0000', 'nivel': 0},
  ],
  'materias_optativas': <Map<String, dynamic>>[],
  'resumo': {
    'percentual_conclusao_obrigatorias': 10.0,
    'total_disciplinas': 4,
    'total_obrigatorias': 4,
    'total_obrigatorias_concluidas': 1,
    'total_obrigatorias_pendentes': 3,
    'total_optativas': 1,
  },
  'dados_validacao': {
    'ira': 4.1234,
    'ira_texto': '4,1234',
    'media_ponderada': 4.2,
    'horas_integralizadas': 1530,
  },
};

/// Resposta da RPC pedindo seleção de curso (sem campo `type`, de propósito:
/// o critério do cliente não olha esse campo).
Map<String, dynamic> respostaRpcSelecaoDeCurso() => {
  'message': 'Encontramos mais de um curso possível.',
  'cursos_disponiveis': [
    {
      'id_curso': 42,
      'nome_curso': 'ENGENHARIA DE SOFTWARE',
      'matriz_curricular': '6360/2 - 2017.1',
    },
    {
      'id_curso': 43,
      'nome_curso': 'ENGENHARIA ELETRONICA',
      'matriz_curricular': '6363/1',
    },
  ],
};

/// Fecha o gap de tempo dos timers de progresso em testes puros.
Future<void> aguardarMicrotasks() => Future<void>.delayed(Duration.zero);
