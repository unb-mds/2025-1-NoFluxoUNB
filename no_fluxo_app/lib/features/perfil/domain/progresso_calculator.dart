/// Lógica pura de progresso do curso para a tela de Perfil.
///
/// Nenhuma dependência de Flutter/Supabase: recebe os dados prontos
/// (carga horária integralizada + exigências da matriz + fluxograma) e
/// devolve percentuais, horas faltantes e contagens de matérias.
library;

import '../../../core/models/user_model.dart';
import '../../../core/utils/json_utils.dart';

/// Carga horária integralizada do aluno por natureza.
///
/// Fonte: coluna JSON `dados_users.carga_horaria_integralizada`
/// (`{total, obrigatoria, optativa, complementar}`), extraída do histórico
/// do SIGAA no upload feito pelo site.
class CargaHorariaIntegralizada {
  final int obrigatoria;
  final int optativa;
  final int complementar;
  final int total;

  const CargaHorariaIntegralizada({
    this.obrigatoria = 0,
    this.optativa = 0,
    this.complementar = 0,
    this.total = 0,
  });

  /// Aceita tanto Map (jsonb) quanto String JSON. Retorna null se vazio.
  static CargaHorariaIntegralizada? fromDynamic(dynamic value) {
    final map = decodeJsonMap(value);
    if (map == null) return null;
    return CargaHorariaIntegralizada(
      obrigatoria: parseIntOr(map['obrigatoria']),
      optativa: parseIntOr(map['optativa']),
      complementar: parseIntOr(map['complementar']),
      total: parseIntOr(map['total']),
    );
  }
}

/// Exigências de carga horária da matriz curricular (tabela `matrizes`).
///
/// Valores oficiais do SIGAA; null quando a matriz não informa a natureza.
class ExigenciasMatriz {
  final String curriculoCompleto;
  final int? chObrigatoriaExigida;
  final int? chOptativaExigida;
  final int? chComplementarExigida;
  final int? chTotalExigida;

  const ExigenciasMatriz({
    this.curriculoCompleto = '',
    this.chObrigatoriaExigida,
    this.chOptativaExigida,
    this.chComplementarExigida,
    this.chTotalExigida,
  });

  factory ExigenciasMatriz.fromJson(Map<String, dynamic> json) {
    return ExigenciasMatriz(
      curriculoCompleto: parseStringOr(json['curriculo_completo']),
      chObrigatoriaExigida: parseIntOrNull(json['ch_obrigatoria_exigida']),
      chOptativaExigida: parseIntOrNull(json['ch_optativa_exigida']),
      chComplementarExigida: parseIntOrNull(json['ch_complementar_exigida']),
      chTotalExigida: parseIntOrNull(json['ch_total_exigida']),
    );
  }
}

/// Progresso em uma natureza (obrigatória, optativa, complementar ou total).
class ProgressoNatureza {
  /// Horas integralizadas pelo aluno.
  final int realizado;

  /// Horas exigidas pela matriz (null = matriz não informa).
  final int? exigido;

  const ProgressoNatureza({required this.realizado, this.exigido});

  /// Percentual de conclusão em 0–100. Sem exigência (null ou <= 0) → 0.
  double get percentual => ProgressoCalculator.percentual(realizado, exigido);

  /// Horas que ainda faltam (nunca negativo; sem exigência → 0).
  int get faltam => ProgressoCalculator.horasFaltantes(realizado, exigido);

  /// Há exigência conhecida para exibir a barra desta natureza?
  bool get temExigencia => (exigido ?? 0) > 0;
}

/// Contagem de matérias do fluxograma do aluno por status.
class ContagemMaterias {
  /// APR / CUMP / DISP.
  final int concluidas;

  /// MATR (matriculado neste período).
  final int emCurso;

  /// Todo o resto (não cursada, reprovada, trancada...).
  final int pendentes;

  const ContagemMaterias({
    this.concluidas = 0,
    this.emCurso = 0,
    this.pendentes = 0,
  });

  int get total => concluidas + emCurso + pendentes;
}

/// Resultado consolidado para a tela de Perfil.
class ProgressoPerfil {
  final ProgressoNatureza obrigatoria;
  final ProgressoNatureza optativa;
  final ProgressoNatureza complementar;
  final ProgressoNatureza total;
  final ContagemMaterias contagem;

  const ProgressoPerfil({
    required this.obrigatoria,
    required this.optativa,
    required this.complementar,
    required this.total,
    required this.contagem,
  });

  /// A matriz exige horas complementares? (muitos cursos não exigem)
  bool get temComplementar => complementar.temExigencia;
}

/// Funções puras de cálculo de progresso.
class ProgressoCalculator {
  ProgressoCalculator._();

  /// Percentual `realizado/exigido * 100` com clamp em 0–100.
  ///
  /// Exigência nula ou <= 0 (matriz sem o dado) → 0, nunca divisão por zero.
  static double percentual(int realizado, int? exigido) {
    if (exigido == null || exigido <= 0) return 0;
    return ((realizado / exigido) * 100).clamp(0, 100).toDouble();
  }

  /// Horas faltantes `exigido - realizado`, nunca negativo.
  static int horasFaltantes(int realizado, int? exigido) {
    if (exigido == null || exigido <= 0) return 0;
    final faltam = exigido - realizado;
    return faltam > 0 ? faltam : 0;
  }

  /// Conta as matérias do fluxograma por status:
  /// concluídas (APR/CUMP/DISP), em curso (MATR) e pendentes (o resto).
  static ContagemMaterias contarMaterias(DadosFluxogramaUser? dados) {
    if (dados == null) return const ContagemMaterias();
    var concluidas = 0;
    var emCurso = 0;
    var pendentes = 0;
    for (final materia in dados.todasMaterias) {
      if (materia.isCursada) {
        concluidas++;
      } else if (materia.isEmCurso) {
        emCurso++;
      } else {
        pendentes++;
      }
    }
    return ContagemMaterias(
      concluidas: concluidas,
      emCurso: emCurso,
      pendentes: pendentes,
    );
  }

  /// Monta o [ProgressoPerfil] completo.
  ///
  /// Se [integralizada] for null (upload antigo, sem a coluna JSON), usa
  /// [horasIntegralizadasFallback] (campo `horas_integralizadas` do
  /// fluxograma) apenas no total, deixando as naturezas zeradas.
  static ProgressoPerfil calcular({
    CargaHorariaIntegralizada? integralizada,
    ExigenciasMatriz? exigencias,
    DadosFluxogramaUser? dados,
    int horasIntegralizadasFallback = 0,
  }) {
    final carga =
        integralizada ??
        CargaHorariaIntegralizada(total: horasIntegralizadasFallback);
    return ProgressoPerfil(
      obrigatoria: ProgressoNatureza(
        realizado: carga.obrigatoria,
        exigido: exigencias?.chObrigatoriaExigida,
      ),
      optativa: ProgressoNatureza(
        realizado: carga.optativa,
        exigido: exigencias?.chOptativaExigida,
      ),
      complementar: ProgressoNatureza(
        realizado: carga.complementar,
        exigido: exigencias?.chComplementarExigida,
      ),
      total: ProgressoNatureza(
        realizado: carga.total,
        exigido: exigencias?.chTotalExigida,
      ),
      contagem: contarMaterias(dados),
    );
  }
}

/// Formata horas no padrão pt-BR com separador de milhar: 1230 → "1.230".
String formatarHorasPtBr(int horas) {
  final negativo = horas < 0;
  final digitos = horas.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    final restantes = digitos.length - i;
    buffer.write(digitos[i]);
    if (restantes > 1 && restantes % 3 == 1) buffer.write('.');
  }
  return '${negativo ? '-' : ''}$buffer';
}

/// Iniciais para o avatar: primeiro + último nome ("Ana Beatriz Silva" → "AS").
/// Nome vazio → "?".
String iniciaisDoNome(String nome) {
  final partes = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  final primeira = partes.first[0].toUpperCase();
  if (partes.length == 1) return primeira;
  return primeira + partes.last[0].toUpperCase();
}
