/// Montagem do [DadosFluxogramaUser] a partir do casamento — porte fiel de
/// `buildDadosFluxogramaUserFromCasarResponse`, `injetarEquivalenciasDoPdf` e
/// `dadosFluxogramaUserToJson` (factories/index.ts do site).
///
/// O model do core não tem o campo `equivalenciasPdf` do site, então os pares
/// normalizados são carregados por fora ([EquivalenciaPdfNormalizada]) e
/// entram na serialização via parâmetro de [dadosFluxogramaUserParaJson].
library;

import '../../../core/models/user_model.dart';
import '../../../core/pdf/modelos_extracao.dart';
import '../../../core/utils/json_utils.dart';
import 'casamento.dart';

/// Versão do schema gravada pelo upload — espelho de
/// `FLUXOGRAMA_SCHEMA_VERSION` (config/release.ts do site).
const int kFluxogramaSchemaVersion = 2;

/// Metadados do histórico usados na montagem (o `meta` do site).
class MetaHistorico {
  final String nomeCurso;
  final String matricula;
  final String anoAtual;
  final String matrizCurricular;
  final int semestreAtual;
  final List<String> suspensoes;

  const MetaHistorico({
    this.nomeCurso = '',
    this.matricula = '',
    this.anoAtual = '',
    this.matrizCurricular = '',
    this.semestreAtual = 0,
    this.suspensoes = const [],
  });
}

/// Par de equivalência do PDF já normalizado (códigos em caixa alta).
class EquivalenciaPdfNormalizada {
  final String cumpriu;
  final String atravesDe;
  final String? nomeCumpriu;
  final String? nomeEquivalente;

  const EquivalenciaPdfNormalizada({
    required this.cumpriu,
    required this.atravesDe,
    this.nomeCumpriu,
    this.nomeEquivalente,
  });
}

/// Porte de `buildDadosFluxogramaUserFromCasarResponse` (linhas ~337-463):
/// UM único semestre com todas as disciplinas casadas; equivalências do banco
/// (`status_fluxograma == 'concluida_equivalencia'`) indexadas e mescladas
/// nas casadas aprovadas; as que não casaram entram no fim do semestre como
/// tipo 'equivalencia'.
DadosFluxogramaUser montarDadosFluxogramaUser({
  required CasarDisciplinasResultado resultado,
  required MetaHistorico meta,
  String? iraTexto,
}) {
  // Índice das concluídas por equivalência (banco), por código da matriz.
  final equivalenciaPorCodigo = <String, Map<String, dynamic>>{};
  for (final r in resultado.materiasConcluidas) {
    if (r['status_fluxograma'] != 'concluida_equivalencia') continue;
    final codigo = parseStringOr(
      r['codigo_materia'] ?? r['codigo'],
    ).trim().toUpperCase();
    if (codigo.isEmpty) continue;
    equivalenciaPorCodigo[codigo] = r;
  }

  final primeiroSemestre = <DadosMateria>[];
  for (final raw in resultado.disciplinasCasadas) {
    final codigoMatriz = parseStringOr(
      raw['codigo_materia'] ?? raw['codigo'],
    ).trim();
    final codigoUpper = codigoMatriz.toUpperCase();
    final codigoHist = parseStringOr(raw['codigo_historico']).trim();
    final nomeHist = parseStringOrNull(raw['nome_historico']);
    final foiCursadaComoEquivalente =
        codigoHist.isNotEmpty && codigoHist.toUpperCase() != codigoUpper;

    final base = DadosMateria.fromJson({
      ...raw,
      'codigo': raw['codigo_materia'] ?? raw['codigo'],
    });

    final equiv = equivalenciaPorCodigo[codigoUpper];
    final usarComoEquivalencia =
        base.isAprovada &&
        (equiv != null ||
            (foiCursadaComoEquivalente &&
                (codigoHist.isNotEmpty || nomeHist != null)));

    if (usarComoEquivalencia) {
      base.tipoDado = 'equivalencia';
      if (equiv != null) {
        final professorEq = parseStringOr(equiv['professor']);
        if (professorEq.isNotEmpty) base.professor = professorEq;
        final mencaoEq = parseStringOr(equiv['mencao'], '-');
        if (mencaoEq != '-') base.mencao = mencaoEq;
        // No site o status da equivalência cai para 'CUMP' quando nulo.
        final statusEq = parseStringOr(equiv['status'], 'CUMP');
        if (statusEq.isNotEmpty) base.status = statusEq;
        base.anoPeriodo =
            parseStringOrNull(equiv['ano_periodo']) ?? base.anoPeriodo;
      }
      base.codigoEquivalente =
          parseStringOrNull(equiv?['codigo_equivalente']) ??
          (codigoHist.isNotEmpty ? codigoHist : null);
      base.nomeEquivalente =
          parseStringOrNull(equiv?['nome_equivalente']) ?? nomeHist;
    }
    primeiroSemestre.add(base);
  }

  // Concluídas por equivalência que não apareceram nas casadas.
  final codigosJaIncluidos = {
    for (final m in primeiroSemestre) m.codigoMateria.trim().toUpperCase(),
  };
  for (final r in resultado.materiasConcluidas) {
    if (r['status_fluxograma'] != 'concluida_equivalencia') continue;
    final codigo = parseStringOr(r['codigo_materia'] ?? r['codigo']).trim();
    if (codigo.isEmpty || codigosJaIncluidos.contains(codigo.toUpperCase())) {
      continue;
    }
    primeiroSemestre.add(
      DadosMateria(
        codigoMateria: codigo,
        status: parseStringOr(r['status'], 'CUMP'),
        mencao: parseStringOr(r['mencao'], '-'),
        professor: parseStringOr(r['professor']),
        anoPeriodo: parseStringOrNull(r['ano_periodo']),
        tipoDado: 'equivalencia',
        codigoEquivalente: parseStringOrNull(r['codigo_equivalente']),
        nomeEquivalente: parseStringOrNull(r['nome_equivalente']),
      ),
    );
    codigosJaIncluidos.add(codigo.toUpperCase());
  }

  final iraTextoResolvido =
      (iraTexto ?? parseStringOrNull(resultado.dadosValidacao['ira_texto']))
          ?.trim();

  return DadosFluxogramaUser(
    nomeCurso: meta.nomeCurso,
    ira: parseDoubleOr(resultado.dadosValidacao['ira']),
    iraTexto: (iraTextoResolvido == null || iraTextoResolvido.isEmpty)
        ? null
        : iraTextoResolvido,
    matricula: meta.matricula,
    horasIntegralizadas: parseIntOr(
      resultado.dadosValidacao['horas_integralizadas'],
    ),
    suspensoes: meta.suspensoes,
    anoAtual: meta.anoAtual,
    matrizCurricular: meta.matrizCurricular,
    semestreAtual: meta.semestreAtual,
    dadosFluxograma: [primeiroSemestre],
  );
}

/// Porte de `injetarEquivalenciasDoPdf` (~239-275): os pares "Cumpriu X
/// através de Y" declarados no próprio PDF que ainda faltam no fluxograma
/// entram no 1º semestre com status CUMP e tipo_dado 'equivalencia'. Pares
/// cujo alvo já está APR/CUMP/equivalência são ignorados (o banco chegou
/// primeiro). Retorna os pares normalizados para a serialização
/// (`equivalencias_pdf`) — lista vazia quando não há pares válidos.
List<EquivalenciaPdfNormalizada> injetarEquivalenciasDoPdf(
  DadosFluxogramaUser dados,
  List<EquivalenciaExtraida> equivalenciasPdf,
) {
  final pares = <EquivalenciaPdfNormalizada>[];
  for (final e in equivalenciasPdf) {
    final cumpriu = e.cumpriu.trim().toUpperCase();
    final atravesDe = e.atravesDe.trim().toUpperCase();
    if (cumpriu.isEmpty || atravesDe.isEmpty) continue;
    pares.add(
      EquivalenciaPdfNormalizada(
        cumpriu: cumpriu,
        atravesDe: atravesDe,
        nomeCumpriu: e.nomeCumpriu.trim().isEmpty ? null : e.nomeCumpriu,
        nomeEquivalente: e.nomeEquivalente.trim().isEmpty
            ? null
            : e.nomeEquivalente,
      ),
    );
  }
  if (pares.isEmpty) return const [];

  final presentes = <String>{};
  for (final semestre in dados.dadosFluxograma) {
    for (final m in semestre) {
      final st = m.status.trim().toUpperCase();
      if (st == 'APR' || st == 'CUMP' || m.tipoDado == 'equivalencia') {
        presentes.add(m.codigoMateria.trim().toUpperCase());
      }
    }
  }

  if (dados.dadosFluxograma.isEmpty) {
    dados.dadosFluxograma = [<DadosMateria>[]];
  }
  final primeiroSemestre = dados.dadosFluxograma.first;
  for (final eq in pares) {
    if (presentes.contains(eq.cumpriu)) continue;
    presentes.add(eq.cumpriu);
    primeiroSemestre.add(
      DadosMateria(
        codigoMateria: eq.cumpriu,
        status: 'CUMP',
        mencao: '-',
        professor: '',
        tipoDado: 'equivalencia',
        codigoEquivalente: eq.atravesDe,
        nomeEquivalente: eq.nomeEquivalente,
        nomeMateria: eq.nomeCumpriu,
      ),
    );
  }
  return pares;
}

/// Porte de `dadosMateriaToJson` — snake_case, opcionais omitidos quando
/// nulos (como o `?? undefined` + JSON.stringify do site).
Map<String, dynamic> dadosMateriaParaJson(DadosMateria m) => {
  'codigo': m.codigoMateria,
  'mencao': m.mencao,
  'professor': m.professor,
  'status': m.status,
  'ano_periodo': m.anoPeriodo,
  'frequencia': m.frequencia,
  'tipo_dado': m.tipoDado,
  'turma': m.turma,
  if (m.codigoEquivalente != null) 'codigo_equivalente': m.codigoEquivalente,
  if (m.nomeEquivalente != null) 'nome_equivalente': m.nomeEquivalente,
  'is_manual': m.isManual,
  if (m.nivelDestino != null) 'nivel_destino': m.nivelDestino,
  if (m.nivel != null) 'nivel': m.nivel,
  if (m.nomeMateria != null) 'nome_materia': m.nomeMateria,
  if (m.creditos != null) 'creditos': m.creditos,
};

/// Porte de `dadosFluxogramaUserToJson` (~190-228) — snake_case, opcionais
/// omitidos, `schema_version` no fim. Os pares de equivalência do PDF entram
/// por parâmetro porque o model do core não tem o campo.
Map<String, dynamic> dadosFluxogramaUserParaJson(
  DadosFluxogramaUser dados, {
  List<EquivalenciaPdfNormalizada> equivalenciasPdf = const [],
}) {
  final iraTexto = dados.iraTexto;
  return {
    'nome_curso': dados.nomeCurso,
    'ira': dados.ira,
    if (iraTexto != null && iraTexto.isNotEmpty) 'ira_texto': iraTexto,
    'matricula': dados.matricula,
    'matriz_curricular': dados.matrizCurricular,
    'semestre_atual': dados.semestreAtual,
    'ano_atual': dados.anoAtual,
    'horas_integralizadas': dados.horasIntegralizadas,
    'suspensoes': dados.suspensoes,
    'dados_fluxograma': [
      for (final semestre in dados.dadosFluxograma)
        [for (final materia in semestre) dadosMateriaParaJson(materia)],
    ],
    if (dados.optativasPlanejadas.isNotEmpty)
      'optativas_planejadas': [
        for (final p in dados.optativasPlanejadas)
          {'codigo_materia': p.codigoMateria, 'semestre': p.semestre},
      ],
    if (equivalenciasPdf.isNotEmpty)
      'equivalencias_pdf': [
        for (final e in equivalenciasPdf)
          {
            'cumpriu': e.cumpriu,
            'atraves_de': e.atravesDe,
            if (e.nomeCumpriu != null) 'nome_cumpriu': e.nomeCumpriu,
            if (e.nomeEquivalente != null)
              'nome_equivalente': e.nomeEquivalente,
          },
      ],
    if (dados.schemaVersion != null) 'schema_version': dados.schemaVersion,
  };
}
