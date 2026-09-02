/// Modelos da extração do histórico PDF — espelho FIEL do `ParsedPdfResult`
/// do site (no_fluxo_frontend_svelte/src/lib/services/pdf/), porque o shape
/// serializado vira o `p_dados` da RPC `casar_disciplinas`.
library;

/// Uma entrada de `extracted_data`. Os campos opcionais (observacao, IRA,
/// valores…) só existem em tipos específicos — ver toJson.
class DisciplinaExtraida {
  final String
  tipoDado; // 'Disciplina Regular'|'Disciplina Pendente'|'Pendencias'|'IRA'
  final String nome;
  final String
  status; // APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP|PENDENTE|''
  final String mencao; // SS|MS|MM|MI|II|SR|'-'
  final int creditos;
  final String codigo;
  final int cargaHoraria;
  final String anoPeriodo; // "2024.1" ou ''
  final String prefixo; // símbolo da coluna: * & # e @ § %
  final String professor;
  final String turma;
  final String? frequencia;
  final String? observacao; // 'Matriculado' | 'Matriculado em Equivalente'
  final double? iraValor; // só em tipo 'IRA'
  final String? iraValorTexto; // ex.: "4,1234", fiel ao PDF
  final Map<String, int>? valores; // só em tipo 'Pendencias'

  const DisciplinaExtraida({
    required this.tipoDado,
    this.nome = '',
    this.status = '',
    this.mencao = '-',
    this.creditos = 0,
    this.codigo = '',
    this.cargaHoraria = 0,
    this.anoPeriodo = '',
    this.prefixo = '',
    this.professor = '',
    this.turma = '',
    this.frequencia,
    this.observacao,
    this.iraValor,
    this.iraValorTexto,
    this.valores,
  });

  Map<String, dynamic> toJson() => {
    'tipo_dado': tipoDado,
    'nome': nome,
    'status': status,
    'mencao': mencao,
    'creditos': creditos,
    'codigo': codigo,
    'carga_horaria': cargaHoraria,
    'ano_periodo': anoPeriodo,
    'prefixo': prefixo,
    'professor': professor,
    'turma': turma,
    'frequencia': frequencia,
    'nota': null, // sempre null, como no site
    if (observacao != null) 'observacao': observacao,
    if (iraValor != null) ...{
      'IRA': 'IRA',
      'valor': iraValor,
      'valor_texto': iraValorTexto,
    },
    if (valores != null) 'valores': valores,
  };
}

/// Equivalência declarada no próprio PDF ("Cumpriu X através de Y").
class EquivalenciaExtraida {
  final String cumpriu;
  final String nomeCumpriu;
  final String atravesDe;
  final String nomeEquivalente;
  final String chCumpriu; // strings, como no site
  final String chEquivalente;

  const EquivalenciaExtraida({
    required this.cumpriu,
    required this.nomeCumpriu,
    required this.atravesDe,
    required this.nomeEquivalente,
    required this.chCumpriu,
    required this.chEquivalente,
  });

  Map<String, dynamic> toJson() => {
    'cumpriu': cumpriu,
    'nome_cumpriu': nomeCumpriu,
    'atraves_de': atravesDe,
    'nome_equivalente': nomeEquivalente,
    'ch_cumpriu': chCumpriu,
    'ch_equivalente': chEquivalente,
  };
}

/// Carga horária integralizada extraída do bloco "Exigido/Integralizado".
class CargaHorariaExtraida {
  final int obrigatoria;
  final int optativa;
  final int complementar;
  final int total;

  const CargaHorariaExtraida({
    required this.obrigatoria,
    required this.optativa,
    required this.complementar,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'obrigatoria': obrigatoria,
    'optativa': optativa,
    'complementar': complementar,
    'total': total,
  };
}

/// Resultado completo do parse — o toJson (sem `full_text`) é o `p_dados`.
class ParsedPdfResult {
  final String filename;
  final String matricula; // texto do PDF > filename sanitizado > 'desconhecida'
  final String? cursoExtraido;
  final String? matrizCurricular; // "8184/1" ou "8184/1 - 2019.2"
  final double? mediaPonderada;
  final String fullText; // NUNCA vai no p_dados
  final List<DisciplinaExtraida> extractedData;
  final List<EquivalenciaExtraida> equivalenciasPdf;
  final String? semestreAtual; // "2025.1"
  final int? numeroSemestre;
  final List<String> suspensoes;
  final CargaHorariaExtraida? cargaHorariaIntegralizada;

  const ParsedPdfResult({
    required this.filename,
    required this.matricula,
    this.cursoExtraido,
    this.matrizCurricular,
    this.mediaPonderada,
    this.fullText = '',
    this.extractedData = const [],
    this.equivalenciasPdf = const [],
    this.semestreAtual,
    this.numeroSemestre,
    this.suspensoes = const [],
    this.cargaHorariaIntegralizada,
  });

  /// Payload do `p_dados` da RPC `casar_disciplinas` — mesmas chaves do site,
  /// SEM `full_text` (nunca lido pelo PL/pgSQL, só engorda o request).
  /// [cursoSelecionado]/[idCursoSelecionado] entram no retry pós
  /// COURSE_SELECTION.
  Map<String, dynamic> toPDados({
    String? cursoSelecionado,
    int? idCursoSelecionado,
  }) => {
    'message': 'PDF processado com sucesso!',
    'filename': filename,
    'matricula': matricula,
    'curso_extraido': cursoSelecionado ?? cursoExtraido,
    'matriz_curricular': matrizCurricular,
    'media_ponderada': mediaPonderada,
    'frequencia_geral': null,
    'extracted_data': [for (final d in extractedData) d.toJson()],
    'equivalencias_pdf': [for (final e in equivalenciasPdf) e.toJson()],
    'semestre_atual': semestreAtual,
    'numero_semestre': numeroSemestre,
    'suspensoes': suspensoes,
    'carga_horaria_integralizada': cargaHorariaIntegralizada?.toJson(),
    'curso_selecionado': ?cursoSelecionado,
    'id_curso_selecionado': ?idCursoSelecionado,
  };
}
