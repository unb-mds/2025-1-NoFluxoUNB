/// Protocolo do casamento de disciplinas — porte fiel do site
/// (`upload.service.ts`): classificação da resposta da RPC `casar_disciplinas`
/// (sucesso × seleção de curso × erro de negócio) e o pós-processamento que
/// SEMPRE roda no sucesso (filtro de pendentes só-obrigatórias + resumo
/// recalculado).
library;

import '../../../core/utils/json_utils.dart';

/// Erro de importação com mensagem pronta para a UI (mesmos textos do site).
class ImportarHistoricoException implements Exception {
  final String message;

  const ImportarHistoricoException(this.message);

  @override
  String toString() => message;
}

/// Mensagem quando a RPC estoura o limite de 30s (idêntica à do site).
const String kMsgTimeoutCasamento =
    'O processamento demorou mais de 30 segundos. Tente novamente ou use um '
    'PDF menor.';

/// Uma opção de curso no modal de seleção (vinda da RPC ou do modo manual).
class OpcaoCurso {
  final String nomeCurso;
  final int? idCurso;
  final String? matrizCurricular;
  final String? turno;

  const OpcaoCurso({
    required this.nomeCurso,
    this.idCurso,
    this.matrizCurricular,
    this.turno,
  });

  factory OpcaoCurso.fromJson(Map<String, dynamic> json) {
    return OpcaoCurso(
      nomeCurso: parseStringOr(json['nome_curso']),
      idCurso: parseIntOrNull(json['id_curso']),
      matrizCurricular: parseStringOrNull(json['matriz_curricular']),
      turno: parseStringOrNull(json['turno']),
    );
  }

  /// Complemento exibido ao lado do nome ("(Noturno) — 8184/1"), ou vazio.
  String get detalhe {
    final partes = <String>[];
    final t = (turno ?? '').trim().toUpperCase();
    if (t.isNotEmpty) {
      partes.add(
        t == 'NOTURNO'
            ? 'Noturno'
            : t == 'DIURNO'
            ? 'Diurno'
            : turno!.trim(),
      );
    }
    final m = (matrizCurricular ?? '').trim();
    if (m.isNotEmpty) partes.add(m);
    return partes.join(' — ');
  }
}

/// Pedido de seleção de curso (o `COURSE_SELECTION` do site).
class SelecaoDeCurso {
  final String mensagem;
  final List<OpcaoCurso> cursos;

  const SelecaoDeCurso({required this.mensagem, required this.cursos});
}

/// Resumo do casamento (bloco `resumo` da RPC), recalculado no cliente.
class ResumoCasamento {
  final int totalDisciplinas;
  final int totalObrigatorias;
  final int totalObrigatoriasConcluidas;
  final int totalObrigatoriasPendentes;
  final int totalOptativas;
  final double percentualConclusaoObrigatorias;

  const ResumoCasamento({
    this.totalDisciplinas = 0,
    this.totalObrigatorias = 0,
    this.totalObrigatoriasConcluidas = 0,
    this.totalObrigatoriasPendentes = 0,
    this.totalOptativas = 0,
    this.percentualConclusaoObrigatorias = 0,
  });

  factory ResumoCasamento.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const {};
    return ResumoCasamento(
      totalDisciplinas: parseIntOr(map['total_disciplinas']),
      totalObrigatorias: parseIntOr(map['total_obrigatorias']),
      totalObrigatoriasConcluidas: parseIntOr(
        map['total_obrigatorias_concluidas'],
      ),
      totalObrigatoriasPendentes: parseIntOr(
        map['total_obrigatorias_pendentes'],
      ),
      totalOptativas: parseIntOr(map['total_optativas']),
      percentualConclusaoObrigatorias: parseDoubleOr(
        map['percentual_conclusao_obrigatorias'],
      ),
    );
  }
}

/// Resposta de sucesso da RPC, já pós-processada.
class CasarDisciplinasResultado {
  final List<Map<String, dynamic>> disciplinasCasadas;
  final List<Map<String, dynamic>> materiasConcluidas;
  List<Map<String, dynamic>> materiasPendentes;
  final List<Map<String, dynamic>> materiasOptativas;
  final Map<String, dynamic> dadosValidacao;
  final String? cursoExtraido;
  final String? matrizCurricular;
  ResumoCasamento resumo;

  CasarDisciplinasResultado({
    this.disciplinasCasadas = const [],
    this.materiasConcluidas = const [],
    this.materiasPendentes = const [],
    this.materiasOptativas = const [],
    this.dadosValidacao = const {},
    this.cursoExtraido,
    this.matrizCurricular,
    this.resumo = const ResumoCasamento(),
  });

  factory CasarDisciplinasResultado.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> listaDeMapas(dynamic valor) => [
      for (final item in asListOr(valor))
        if (asMapOrNull(item) != null) asMapOrNull(item)!,
    ];
    return CasarDisciplinasResultado(
      disciplinasCasadas: listaDeMapas(json['disciplinas_casadas']),
      materiasConcluidas: listaDeMapas(json['materias_concluidas']),
      materiasPendentes: listaDeMapas(json['materias_pendentes']),
      materiasOptativas: listaDeMapas(json['materias_optativas']),
      dadosValidacao: asMapOrNull(json['dados_validacao']) ?? const {},
      cursoExtraido: parseStringOrNull(json['curso_extraido']),
      matrizCurricular: parseStringOrNull(json['matriz_curricular']),
      resumo: ResumoCasamento.fromJson(asMapOrNull(json['resumo'])),
    );
  }
}

/// Resultado da chamada de casamento: ou concluiu, ou pede seleção de curso.
sealed class RespostaCasamento {
  const RespostaCasamento();
}

class CasamentoConcluido extends RespostaCasamento {
  final CasarDisciplinasResultado resultado;

  const CasamentoConcluido(this.resultado);
}

class CasamentoPrecisaDeCurso extends RespostaCasamento {
  final SelecaoDeCurso selecao;

  const CasamentoPrecisaDeCurso(this.selecao);
}

/// true = conta como obrigatória no casamento (não é optativa da grade) —
/// porte de `isMateriaObrigatoriaNoCasamento` (casar-materias.ts).
bool isMateriaObrigatoriaNoCasamento(Map<String, dynamic> materia) {
  final tipo = parseStringOr(materia['tipo']).trim().toLowerCase();
  if (tipo == 'optativa') return false;
  final nivel = materia['nivel'];
  if (nivel != null && nivel != '' && parseIntOrNull(nivel) == 0) return false;
  return true;
}

/// Pós-processamento que SEMPRE roda no sucesso — porte de
/// `normalizarPendentesObrigatoriasResumo` (upload.service.ts):
/// `materias_pendentes` só com obrigatórias e resumo recalculado
/// (total = concluídas + pendentes filtradas; % com 2 casas).
void normalizarPendentesObrigatoriasResumo(CasarDisciplinasResultado r) {
  final filtradas = r.materiasPendentes
      .where(isMateriaObrigatoriaNoCasamento)
      .toList();
  r.materiasPendentes = filtradas;

  final concluidas = r.resumo.totalObrigatoriasConcluidas;
  final pendentes = filtradas.length;
  final totalObrigatorias = concluidas + pendentes;
  final percentual = totalObrigatorias > 0
      ? (concluidas / totalObrigatorias * 10000).round() / 100
      : 0.0;

  r.resumo = ResumoCasamento(
    totalDisciplinas: r.resumo.totalDisciplinas,
    totalObrigatorias: totalObrigatorias,
    totalObrigatoriasConcluidas: concluidas,
    totalObrigatoriasPendentes: pendentes,
    totalOptativas: r.resumo.totalOptativas,
    percentualConclusaoObrigatorias: percentual,
  );
}

/// Classifica a resposta crua da RPC — porte do fim de `casarDisciplinas`
/// (upload.service.ts). O critério de COURSE_SELECTION é o do cliente:
/// `cursos_disponiveis` presente E `disciplinas_casadas` ausente (o campo
/// `type` NÃO é consultado). `error` sem cursos → exceção com a mensagem.
RespostaCasamento classificarRespostaCasarDisciplinas(
  Map<String, dynamic> json,
) {
  final temCasadas = json['disciplinas_casadas'] != null;

  if (json['cursos_disponiveis'] != null && !temCasadas) {
    return CasamentoPrecisaDeCurso(
      SelecaoDeCurso(
        mensagem: parseStringOr(json['message'] ?? json['error']),
        cursos: [
          for (final item in asListOr(json['cursos_disponiveis']))
            if (asMapOrNull(item) != null)
              OpcaoCurso.fromJson(asMapOrNull(item)!),
        ],
      ),
    );
  }

  if (json['error'] != null && !temCasadas) {
    throw ImportarHistoricoException(
      parseStringOr(json['error'], 'Erro ao processar disciplinas'),
    );
  }

  final resultado = CasarDisciplinasResultado.fromJson(json);
  normalizarPendentesObrigatoriasResumo(resultado);
  return CasamentoConcluido(resultado);
}
