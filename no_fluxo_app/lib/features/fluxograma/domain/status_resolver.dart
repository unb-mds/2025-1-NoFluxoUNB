import 'dart:ui' show Color;

import '../../../core/models/curso_model.dart';
import '../../../core/models/equivalencia_model.dart';
import '../../../core/models/materia_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';

/// Status de uma matéria no fluxograma, na mesma semântica do
/// `fluxograma.store.svelte.ts` do site.
enum StatusMateria {
  /// APR / CUMP / DISP, menção aprovada (SS/MS/MM) ou equivalência cumprida.
  concluida,

  /// MATR neste período (direto ou "matriculado em equivalente").
  emCurso,

  /// REP/REPF/REPMF sem aprovação posterior (mesma regra do `failedCodes`
  /// do site: menção II/MI/SR sozinha NÃO marca reprovada).
  reprovada,

  /// Todos os pré-requisitos concluídos (inclui matérias sem pré-requisito).
  disponivel,

  /// Algum pré-requisito ainda pendente.
  bloqueada,

  /// Visitante / sem fluxograma salvo — fluxograma genérico da matriz.
  naoIniciada,
}

extension StatusMateriaX on StatusMateria {
  /// Rótulo curto para chips e legendas.
  String get label => switch (this) {
    StatusMateria.concluida => 'Concluída',
    StatusMateria.emCurso => 'Em curso',
    StatusMateria.reprovada => 'Reprovada',
    StatusMateria.disponivel => 'Disponível',
    StatusMateria.bloqueada => 'Bloqueada',
    StatusMateria.naoIniciada => 'Não iniciada',
  };

  /// Cor do card (paleta oficial por status).
  Color get cor => switch (this) {
    StatusMateria.concluida => AppColors.materiaCompleted,
    StatusMateria.emCurso => AppColors.materiaInProgress,
    StatusMateria.reprovada => AppColors.materiaFailed,
    StatusMateria.disponivel => AppColors.materiaAvailable,
    StatusMateria.bloqueada => AppColors.materiaLocked,
    StatusMateria.naoIniciada => AppColors.materiaLocked,
  };
}

/// Resultado de [resolverStatus]: status por código (normalizado) + os
/// conjuntos intermediários, úteis para depuração e testes.
class ResultadoStatus {
  final Map<String, StatusMateria> _porCodigo;

  /// Códigos concluídos, já expandidos com equivalências.
  final Set<String> codigosConcluidos;

  /// Códigos em curso (MATR direto ou por equivalente em curso).
  final Set<String> codigosEmCurso;

  /// Códigos com reprovação registrada (sem considerar aprovação posterior).
  final Set<String> codigosReprovados;

  const ResultadoStatus({
    required Map<String, StatusMateria> porCodigo,
    required this.codigosConcluidos,
    required this.codigosEmCurso,
    required this.codigosReprovados,
  }) : _porCodigo = porCodigo;

  /// Status da matéria (case-insensitive). Códigos fora da matriz caem em
  /// [StatusMateria.naoIniciada].
  StatusMateria statusDe(String codigoMateria) =>
      _porCodigo[_norm(codigoMateria)] ?? StatusMateria.naoIniciada;
}

String _norm(String codigo) => codigo.trim().toUpperCase();

const Set<String> _statusReprovado = {'REP', 'REPF', 'REPMF'};

/// Resolve o status de cada matéria da matriz dado o histórico do aluno.
///
/// Regras (espelhando `determineSubjectStatus` + os derived do store Svelte):
/// prioridade concluída > em curso > reprovada > pré-requisitos
/// (disponível/bloqueada). Equivalências contam tanto para marcar a matéria
/// da matriz como concluída/em curso quanto — por consequência — para
/// cumprir pré-requisito. Sem [dados] (visitante), tudo é "não iniciada".
ResultadoStatus resolverStatus({
  required CursoModel curso,
  DadosFluxogramaUser? dados,
}) {
  if (dados == null) {
    return ResultadoStatus(
      porCodigo: {
        for (final materia in curso.materias)
          _norm(materia.codigoMateria): StatusMateria.naoIniciada,
      },
      codigosConcluidos: const {},
      codigosEmCurso: const {},
      codigosReprovados: const {},
    );
  }

  // ── Conjuntos base do histórico ─────────────────────────────────────────────
  final concluidasBase = <String>{};
  final cursandoBase = <String>{};
  final reprovadas = <String>{};

  for (final materia in dados.todasMaterias) {
    final codigo = _norm(materia.codigoMateria);
    if (codigo.isEmpty) continue;

    if (materia.isAprovada) {
      concluidasBase.add(codigo);
      // Cumprida por equivalência no upload: o código equivalente também conta.
      final equivalente = _norm(materia.codigoEquivalente ?? '');
      if (equivalente.isNotEmpty) concluidasBase.add(equivalente);
    } else if (materia.isEmCurso) {
      cursandoBase.add(codigo);
    }

    // Reprovada APENAS com status REP/REPF/REPMF, espelhando o `failedCodes`
    // do site (fluxograma.store.svelte.ts): lá menção II/MI/SR sem status
    // explícito NÃO marca a matéria como reprovada — ela cai em
    // disponível/bloqueada. O app segue a mesma regra para os dois clientes
    // pintarem o mesmo histórico com as mesmas cores.
    final status = _norm(materia.status);
    if (_statusReprovado.contains(status)) {
      reprovadas.add(codigo);
    }
  }

  // ── Expansão por equivalência (passe único, sem transitividade) ────────────
  final concluidas = <String>{...concluidasBase};
  final stubsConcluidas = _stubsDe(concluidasBase);
  for (final eq in curso.equivalencias) {
    final origem = _norm(eq.codigoMateriaOrigem);
    if (origem.isEmpty || concluidasBase.contains(origem)) continue;
    if (_satisfazEquivalencia(eq, stubsConcluidas)) concluidas.add(origem);
  }

  // "Matriculado em equivalente": expressão satisfeita com (concluídas ∪
  // cursando), mas NÃO só com concluídas — senão seria concluída acima.
  final cursando = <String>{...cursandoBase};
  if (cursandoBase.isNotEmpty) {
    final stubsConcluidasExpandidas = _stubsDe(concluidas);
    final stubsCombinados = _stubsDe({...concluidas, ...cursandoBase});
    for (final eq in curso.equivalencias) {
      final origem = _norm(eq.codigoMateriaOrigem);
      if (origem.isEmpty) continue;
      if (concluidas.contains(origem) || cursandoBase.contains(origem)) {
        continue;
      }
      if (!_satisfazEquivalencia(eq, stubsCombinados)) continue;
      if (_satisfazEquivalencia(eq, stubsConcluidasExpandidas)) continue;
      cursando.add(origem);
    }
  }

  // ── Pré-requisitos diretos por matéria (da lista crua do curso) ────────────
  final prereqsPorIdMateria = <int, List<PreRequisitoModel>>{};
  for (final preReq in curso.preRequisitos) {
    prereqsPorIdMateria.putIfAbsent(preReq.idMateria, () => []).add(preReq);
  }

  // ── Status final por matéria da matriz ─────────────────────────────────────
  final stubsFinais = _stubsDe(concluidas);
  final porCodigo = <String, StatusMateria>{};
  for (final materia in curso.materias) {
    final codigo = _norm(materia.codigoMateria);
    if (codigo.isEmpty) continue;

    final StatusMateria status;
    if (concluidas.contains(codigo)) {
      status = StatusMateria.concluida;
    } else if (cursando.contains(codigo)) {
      status = StatusMateria.emCurso;
    } else if (reprovadas.contains(codigo)) {
      status = StatusMateria.reprovada;
    } else {
      final requisitos =
          prereqsPorIdMateria[materia.idMateria] ?? const <PreRequisitoModel>[];
      status = _satisfazPreRequisitos(requisitos, concluidas, stubsFinais)
          ? StatusMateria.disponivel
          : StatusMateria.bloqueada;
    }
    porCodigo[codigo] = status;
  }

  return ResultadoStatus(
    porCodigo: porCodigo,
    codigosConcluidos: concluidas,
    codigosEmCurso: cursando,
    codigosReprovados: reprovadas,
  );
}

/// Progresso do curso: fração de matérias obrigatórias da matriz (nivel > 0)
/// concluídas. Retorna 0 quando não há obrigatórias ou não há histórico.
double progressoDoCurso(CursoModel curso, ResultadoStatus resultado) {
  final obrigatorias = curso.materias
      .where((materia) => materia.nivel > 0)
      .toList();
  if (obrigatorias.isEmpty) return 0;
  final concluidas = obrigatorias
      .where(
        (materia) =>
            resultado.statusDe(materia.codigoMateria) ==
            StatusMateria.concluida,
      )
      .length;
  return concluidas / obrigatorias.length;
}

/// Registro do histórico do aluno para um código da matriz, preferindo a
/// tentativa aprovada (uma REP antiga não deve esconder o APR posterior).
DadosMateria? encontrarDadosDaMateria(
  DadosFluxogramaUser? dados,
  String codigoMateria,
) {
  if (dados == null) return null;
  final alvo = _norm(codigoMateria);
  if (alvo.isEmpty) return null;

  DadosMateria? fallback;
  for (final materia in dados.todasMaterias) {
    if (_norm(materia.codigoMateria) != alvo) continue;
    if (materia.isAprovada) return materia;
    fallback ??= materia;
  }
  return fallback;
}

/// Um pré-requisito satisfeito? Espelho de `satisfazPreRequisitos` do site
/// (`types/curso.ts`):
/// - linhas com `expressao_logica` avaliam a árvore E/OU, deduplicando por
///   `idPreRequisito` (o backend pode expandir uma expressão em várias
///   linhas — sem dedup, "A OU B" viraria "A E B");
/// - linhas só com o código do join exigem o código concluído (comportamento
///   anterior do app, mantido como fallback);
/// - linhas sem código mas com `expressao_original` avaliam o texto SIGAA;
/// - linhas sem nenhuma informação são ignoradas (fallback do app; o join do
///   Supabase nunca produz esse caso).
bool _satisfazPreRequisitos(
  List<PreRequisitoModel> preRequisitos,
  Set<String> concluidas,
  List<MateriaModel> stubsConcluidas,
) {
  final vistos = <int>{};
  for (final preReq in preRequisitos) {
    if (preReq.expressaoLogica != null) {
      if (!vistos.add(preReq.idPreRequisito)) continue;
      if (!_avaliarExpressaoLogica(
        preReq.expressaoLogica,
        concluidas,
        stubsConcluidas,
      )) {
        return false;
      }
      continue;
    }

    final codigo = _norm(preReq.codigoMateriaRequisito);
    if (codigo.isNotEmpty) {
      if (!concluidas.contains(codigo)) return false;
      continue;
    }

    final expressao = preReq.expressaoOriginal?.trim() ?? '';
    if (expressao.isEmpty) continue;
    if (!_avaliarExpressaoTextual(expressao, stubsConcluidas)) return false;
  }
  return true;
}

/// Código de disciplina isolado (ex.: MAT0026) — mesmo regex do site.
final RegExp _codigoMateriaRegex = RegExp(r'^[A-Za-z]{2,}\d{3,}$');

/// Avalia o jsonb `expressao_logica` contra os códigos concluídos — espelho
/// de `evaluateExpressaoLogica` do site (`utils/expressao-logica.ts`).
///
/// Formatos aceitos: `String` (código único ou expressão textual),
/// `{operador, condicoes}` recursivo e legado `{materias, operador}`.
bool _avaliarExpressaoLogica(
  dynamic expressao,
  Set<String> concluidas,
  List<MateriaModel> stubsConcluidas,
) {
  if (expressao == null) return false;

  if (expressao is String) {
    final texto = expressao.trim();
    if (texto.isEmpty) return false;
    if (_codigoMateriaRegex.hasMatch(texto)) {
      return concluidas.contains(_norm(texto));
    }
    return _avaliarExpressaoTextual(texto, stubsConcluidas);
  }

  final map = asMapOrNull(expressao);
  if (map == null) return false;

  // Formato recursivo {operador, condicoes}.
  final condicoes = map['condicoes'];
  if (condicoes is List) {
    if (condicoes.isEmpty) return false;
    final operador = parseStringOr(map['operador'], 'OU').trim().toUpperCase();
    if (operador == 'E') {
      return condicoes.every(
        (cond) => _avaliarExpressaoLogica(cond, concluidas, stubsConcluidas),
      );
    }
    return condicoes.any(
      (cond) => _avaliarExpressaoLogica(cond, concluidas, stubsConcluidas),
    );
  }

  // Formato legado {materias, operador}.
  final materias = map['materias'];
  if (materias is List) {
    final codigos = [for (final item in materias) _norm(parseStringOr(item))]
      ..removeWhere((codigo) => codigo.isEmpty);
    if (codigos.isEmpty) return false;
    final operador = parseStringOrNull(map['operador'])?.trim().toUpperCase();
    if (operador == 'OU') return codigos.any(concluidas.contains);
    if (operador == 'E') return codigos.every(concluidas.contains);
    return concluidas.contains(codigos.first);
  }

  return false;
}

/// Avalia uma expressão textual SIGAA ("( A OU B ) E C") reaproveitando o
/// parser E/OU do [EquivalenciaModel].
bool _avaliarExpressaoTextual(
  String expressao,
  List<MateriaModel> materiasCursadas,
) {
  final avaliador = EquivalenciaModel(
    idEquivalencia: 0,
    codigoMateriaOrigem: '',
    nomeMateriaOrigem: '',
    codigoMateriaEquivalente: '',
    nomeMateriaEquivalente: '',
    expressao: expressao,
  );
  return avaliador.isMateriaEquivalente(materiasCursadas).isEquivalente;
}

/// Avalia a expressão de equivalência ("A E B OU C") reaproveitando o parser
/// do core, que trabalha sobre uma lista de matérias cursadas.
bool _satisfazEquivalencia(
  EquivalenciaModel equivalencia,
  List<MateriaModel> materiasCursadas,
) {
  if (equivalencia.expressao.trim().isEmpty) return false;
  return equivalencia.isMateriaEquivalente(materiasCursadas).isEquivalente;
}

/// Matérias "stub" só com o código, para alimentar o avaliador de expressões.
List<MateriaModel> _stubsDe(Set<String> codigos) => [
  for (final codigo in codigos)
    MateriaModel(
      ementa: '',
      idMateria: 0,
      nomeMateria: '',
      codigoMateria: codigo,
      nivel: 0,
      creditos: 0,
    ),
];
