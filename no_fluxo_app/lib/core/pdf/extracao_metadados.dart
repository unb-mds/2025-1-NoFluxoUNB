/// Extração de metadados por regex no texto plano — porte fiel de
/// no_fluxo_frontend_svelte/src/lib/services/pdf/pdfDataExtractor.ts
/// (curso, matriz, matrícula, IRA, MP, suspensões, CH integralizada,
/// período letivo, semestres) e das versões de pdfParser.ts para
/// disciplinas pendentes e equivalências (que são as usadas em produção).
library;

import 'modelos_extracao.dart';

String _normalizarQuebras(String texto) =>
    texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _colapsarEspacos(String s) =>
    s.trim().replaceAll(RegExp(r'\s{2,}'), ' ');

// ─── Curso ───

/// Espelho de `extrairCurso` — nome do curso para casar com cursos.nome_curso.
String? extrairCurso(String texto) {
  final normalizado = _normalizarQuebras(texto);

  // Padrão 0a: nome do curso na linha logo após "Discente"
  // (ex.: GESTÃO DE POLÍTICAS PÚBLICAS/GPP - BACHARELADO - NOTURNO)
  var m = RegExp(
    r'(?:Discente|do\s+Discente)\s*\n\s*([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+)/[A-Z]+\s*-\s*[A-ZÀ-ÿ\s]+\s*-\s*[A-ZÀ-ÿ]+',
    caseSensitive: false,
  ).firstMatch(normalizado);
  if (m != null) return _colapsarEspacos(m[1]!);

  // Padrão 0: nome multi-linha ANTES do label "Curso:"
  m = RegExp(
    r'(?:Discente|do Discente)\s*\n([A-ZÀ-ÿ][A-ZÀ-ÿ\s-]+)/[A-Z]+ - [A-ZÀ-ÿ\s]+\nCurso:\s*\n[A-ZÀ-ÿ][A-ZÀ-ÿ\s]+\s+-\s+\w+',
    caseSensitive: false,
  ).firstMatch(normalizado);
  if (m != null) return _colapsarEspacos(m[1]!);

  // Padrão 1: "Curso:\n<NOME>/CAMPUS - ..."
  m = RegExp(
    r'Curso:\s*\n([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return _colapsarEspacos(m[1]!);

  // Padrão 2: "Curso:          NOME/CAMPUS-..."
  m = RegExp(
    r'Curso:\s+([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)/[A-Z]+\s*-',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return _colapsarEspacos(m[1]!);

  // Padrão 3: "Curso: NOME Status:"
  m = RegExp(
    r'Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return _colapsarEspacos(m[1]!);

  return null;
}

// ─── Matriz curricular (campo Currículo) ───

/// Espelho de `extrairMatrizCurricular` — "60810/1" ou "6360/1 - 2017.1".
String? extrairMatrizCurricular(String texto) {
  final normalizado = _normalizarQuebras(texto);

  // "Currículo: 60810/1" ou "Currículo:\n60810/1"
  var m = RegExp(
    r'Curr[ií]culo:\s*\n?\s*(\d+/-?\d+)(?:\s*-\s*\d{4}\.\d)?',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return m[1]!.trim();

  // "Currículo:" numa linha e "8184/1 - 2019.2" várias linhas depois
  m = RegExp(
    r'Curr[ií]culo:[\s\S]*?(\d+/-?\d+)\s*-\s*(\d{4}\.\d)',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return '${m[1]!.trim()} - ${m[2]!}';

  // "Currículo:    6360/1 - 2017.1" (com ano)
  m = RegExp(
    r'Curr[ií]culo:\s*\n?(\d+/-?\d+)\s*-\s*(\d{4}\.\d)',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return '${m[1]!.trim()} - ${m[2]!}';

  // Sem label: "6360/1 - 2017.1" ou só "60810/1" no texto
  m = RegExp(
    r'(\d+/-?\d+)(?:\s*-\s*\d{4}\.\d)?',
    multiLine: true,
  ).firstMatch(normalizado);
  if (m != null) return m[1]!.trim();

  return null;
}

// ─── Matrícula (do texto do PDF) ───

/// Espelho de `extrairMatriculaFromText` — prioridade sobre o nome do arquivo.
String? extrairMatriculaDoTexto(String texto) {
  final normalizado = _normalizarQuebras(texto);
  var m = RegExp(
    r'\bMatr[ií]cula\s*:?\s*(\d{8,12})\b',
    caseSensitive: false,
  ).firstMatch(normalizado);
  if (m != null) return m[1];
  m = RegExp(
    r'\bN[º°]\s*do\s+Discente\s*:?\s*(\d{8,12})\b',
    caseSensitive: false,
  ).firstMatch(normalizado);
  if (m != null) return m[1];
  m = RegExp(
    r'\bN[úu]mero\s+do\s+discente\s*:?\s*(\d{8,12})\b',
    caseSensitive: false,
  ).firstMatch(normalizado);
  if (m != null) return m[1];
  return null;
}

// ─── Carga horária integralizada ───

List<int> _numerosH(String bloco) => [
  for (final m in RegExp(r'(\d+)\s*h', caseSensitive: false).allMatches(bloco))
    int.parse(m[1]!),
];

CargaHorariaExtraida? _validar(int obrig, int opt, int compl, int total) {
  final soma = obrig + opt + compl;
  if ((soma - total).abs() <= 10) {
    return CargaHorariaExtraida(
      obrigatoria: obrig,
      optativa: opt,
      complementar: compl,
      total: total != 0 ? total : soma,
    );
  }
  return null;
}

/// Espelho de `extrairCargaHorariaIntegralizada` — 6 estratégias em cascata
/// com validação |obrig+opt+compl − total| ≤ 10.
CargaHorariaExtraida? extrairCargaHorariaIntegralizada(String texto) {
  final s = _normalizarQuebras(texto);

  // Estratégia 0 (prioritária): "Integralizado" na MESMA linha dos 4 valores
  var m = RegExp(
    r'Integralizado\s+(\d+)\s*h\s+(\d+)\s*h\s+(\d+)\s*h\s+(\d+)\s*h',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final r = _validarLinha(m);
    if (r != null) return r;
  }
  // Variante: "Integralizado" na linha anterior aos números
  m = RegExp(
    r'Integralizado\s*\n\s*(\d+)\s*h\s+(\d+)\s*h\s+(\d+)\s*h\s+(\d+)\s*h',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final r = _validarLinha(m);
    if (r != null) return r;
  }

  // Estratégia A: linhas "Exigido / Integralizado / Pendente" com valores depois
  m = RegExp(
    r'Exigido\s*\nIntegralizado\s*\nPendente\s*\n',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final r = _extrairDeBlocoAposLinhas(s, m.end);
    if (r != null) return r;
  }

  // Fallback: mesmo padrão sem "Exigido" explícito
  m = RegExp(
    r'\nIntegralizado\s*\nPendente\s*\n',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final r = _extrairDeBlocoAposLinhas(s, m.end);
    if (r != null) return r;
  }

  // Estratégia B: "Integralizado" seguido de números (sem "Pendente" no meio)
  m = RegExp(
    r'Integralizad[oa](?:(?!Pendente)[\s\S]){0,300}?(\d+)\s*h[\s\S]{0,150}?(\d+)\s*h[\s\S]{0,150}?(\d+)\s*h(?:\s*[\s\S]{0,150}?(\d+)\s*h)?',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final obrigatoria = int.parse(m[1]!);
    final optativa = int.parse(m[2]!);
    final complementar = int.parse(m[3]!);
    final total = m[4] != null
        ? int.parse(m[4]!)
        : obrigatoria + optativa + complementar;
    final r = _validar(obrigatoria, optativa, complementar, total);
    if (r != null) return r;
  }

  // Estratégia C: bloco entre "Integralizado" e "Carga Horária"/"Legenda"
  m = RegExp(
    r'Integralizado\s*\n([\s\S]{0,400}?)(?=Carga Horária|Legenda|Complementares|$)',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final nums = _numerosH(m[1]!);
    if (nums.length >= 3) {
      // 3 valores: optativa, obrigatória, complementar (ordem do PDF)
      final a = nums[0], b = nums[1], c = nums[2];
      return CargaHorariaExtraida(
        obrigatoria: b,
        optativa: a,
        complementar: c,
        total: a + b + c,
      );
    }
  }

  return null;
}

CargaHorariaExtraida? _validarLinha(RegExpMatch m) {
  final obrigatoria = int.parse(m[1]!);
  final optativa = int.parse(m[2]!);
  final complementar = int.parse(m[3]!);
  final total = int.parse(m[4]!);
  final soma = obrigatoria + optativa + complementar;
  if ((soma - total).abs() <= 10) {
    return CargaHorariaExtraida(
      obrigatoria: obrigatoria,
      optativa: optativa,
      complementar: complementar,
      total: total,
    );
  }
  return null;
}

CargaHorariaExtraida? _extrairDeBlocoAposLinhas(String s, int inicio) {
  final fim = (inicio + 500).clamp(0, s.length);
  final numeros = _numerosH(s.substring(inicio, fim));

  if (numeros.length >= 12) {
    // POR COLUNA (layout real do PDF): Integralizado = idx 1, 4, 7, 10
    final optativa = numeros[1];
    final total = numeros[4];
    final obrigatoria = numeros[7];
    final complementar = numeros[10];
    final r = _validar(obrigatoria, optativa, complementar, total);
    if (r != null) return r;
  }
  if (numeros.length >= 8) {
    // Fallback por LINHA: Integralizado = idx 4..7
    // (colunas: Obrigatórias, Optativos, Complementares, Total)
    final obrig = numeros[4];
    final opt = numeros[5];
    final compl = numeros[6];
    final total = numeros[7];
    final r = _validar(obrig, opt, compl, total);
    if (r != null) return r;
  }
  return null;
}

// ─── Suspensões ───

/// Espelho de `extrairSuspensoes`.
List<String> extrairSuspensoes(String texto) {
  final m = RegExp(
    r'Suspens[õo]es:\s+(.+)',
    caseSensitive: false,
  ).firstMatch(texto);
  if (m != null) {
    final valor = m[1]!.trim();
    if (RegExp(r'nenhum', caseSensitive: false).hasMatch(valor)) return [];
    return [for (final p in RegExp(r'\d{4}\.\d').allMatches(valor)) p[0]!];
  }
  return [];
}

// ─── Período letivo / semestres ───

/// Espelho de `extrairPeriodoLetivoAtual`.
int? extrairPeriodoLetivoAtual(String texto) {
  final m = RegExp(
    r'Per[íi]odo Letivo Atual:\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(texto);
  if (m != null) return int.parse(m[1]!);
  return null;
}

final _reAnoPeriodoCompleto = RegExp(r'^\d{4}\.\d$');

/// Espelho de `extrairSemestreAtual` — semestre mais recente com MATR.
String? extrairSemestreAtual(List<DisciplinaExtraida> disciplinas) {
  final semestres = <String>[];
  for (final d in disciplinas) {
    if (d.status == 'MATR' &&
        d.anoPeriodo.isNotEmpty &&
        _reAnoPeriodoCompleto.hasMatch(d.anoPeriodo)) {
      semestres.add(d.anoPeriodo);
    }
  }
  if (semestres.isEmpty) return null;
  semestres.sort((a, b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    return pa[0] != pb[0] ? pa[0].compareTo(pb[0]) : pa[1].compareTo(pb[1]);
  });
  return semestres.last;
}

/// Espelho de `calcularNumeroSemestre` — semestres distintos cursados + 1.
int calcularNumeroSemestre(List<DisciplinaExtraida> disciplinas) {
  const statusValidos = {'APR', 'DISP', 'REP', 'REPF', 'REPMF', 'CUMP'};
  final semestresUnicos = <String>{};
  for (final d in disciplinas) {
    if (statusValidos.contains(d.status) && d.anoPeriodo.isNotEmpty) {
      semestresUnicos.add(d.anoPeriodo);
    }
  }
  return semestresUnicos.isNotEmpty ? semestresUnicos.length + 1 : 1;
}

// ─── IRA e MP ───

/// Espelho de `REGEX_IRA_HISTORICO` ($lib/utils/ira.ts).
final regexIraHistorico = RegExp(
  r'IRA[:\s]+(\d+[.,]\d+)',
  caseSensitive: false,
);

/// Espelho de `iraStringParaNumero` — só normaliza o separador decimal.
double iraStringParaNumero(String raw) =>
    double.parse(raw.replaceAll(',', '.').trim());

/// Espelho da extração de MP em pdfParser.ts.
double? extrairMediaPonderada(String texto) {
  final m = RegExp(
    r'MP[:\s]+(\d+[.,]\d+)',
    caseSensitive: false,
  ).firstMatch(texto);
  if (m != null) return double.parse(m[1]!.replaceAll(',', '.'));
  return null;
}

// ─── Disciplinas pendentes (versão de pdfParser.ts) ───

/// Espelho de `extrairDisciplinasPendentes` de pdfParser.ts (a versão usada
/// em produção — âncora única, sem o modo detalhado de pdfDataExtractor).
List<DisciplinaExtraida> extrairDisciplinasPendentes(String texto) {
  final disciplinas = <DisciplinaExtraida>[];

  final pendMatch = RegExp(
    r'Componentes Curriculares Obrigat[óo]rios Pendentes:\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(texto);
  if (pendMatch == null) return disciplinas;

  final secao = texto.substring(pendMatch.start);
  final linhas = secao.split('\n');

  final reHeader = RegExp(r'^C[óo]digo\s+Componente', caseSensitive: false);
  final reFim = RegExp(
    r'^(Observações|Equivalências|Para verificar|Atenção|SIGAA|Componentes Curriculares Optativos)',
    caseSensitive: false,
  );
  final reLinha = RegExp(
    r'^\s*([A-Z]{2,}\d{3,}|ENADE|-)\s+(.+?)\s+(?:(Matriculado(?:\s+em\s+Equivalente)?)\s+)?(\d+)\s*h',
    caseSensitive: false,
  );
  final reProfessor = RegExp(
    r'^(?:Dr\.|Dra\.|MSc\.|Prof\.)\s',
    caseSensitive: false,
  );
  final reHorasProf = RegExp(r'\(\d+h\)', caseSensitive: false);
  var comecou = false;

  for (final linha in linhas) {
    if (reHeader.hasMatch(linha.trim())) {
      comecou = true;
      continue;
    }
    if (!comecou) continue;

    if (reFim.hasMatch(linha.trim())) break;

    final m = reLinha.firstMatch(linha);
    if (m != null) {
      final codigo = m[1]!;
      final nome = m[2]!;
      final matriculado = m[3];
      final chStr = m[4]!;
      if (codigo == '-') continue; // entradas "CADEIA DE SELETIVIDADE"
      if (reProfessor.hasMatch(nome.trim())) continue;
      if (reHorasProf.hasMatch(nome)) continue;

      final nomeLimpo = nome
          .replaceFirst(RegExp(r'^[^a-zA-ZÀ-ÿ0-9]+'), '')
          .replaceFirst(RegExp(r'[^a-zA-ZÀ-ÿ0-9]+$'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      final ch = int.parse(chStr);
      disciplinas.add(
        DisciplinaExtraida(
          tipoDado: 'Disciplina Pendente',
          nome: nomeLimpo,
          status: matriculado != null ? 'MATR' : 'PENDENTE',
          mencao: '-',
          creditos: ch ~/ 15,
          codigo: codigo == 'ENADE' ? 'ENADE' : codigo,
          cargaHoraria: ch,
          observacao: matriculado,
        ),
      );
    }
  }

  return disciplinas;
}

// ─── Equivalências declaradas no PDF ───

/// Espelho de `extrairEquivalencias` de pdfParser.ts
/// ("Cumpriu X - NOME (60h) através de Y - NOME (60h)").
List<EquivalenciaExtraida> extrairEquivalencias(String texto) {
  final re = RegExp(
    r'Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)',
    caseSensitive: false,
  );
  return [
    for (final m in re.allMatches(texto))
      EquivalenciaExtraida(
        cumpriu: m[1]!,
        nomeCumpriu: m[2]!.trim(),
        atravesDe: m[4]!,
        nomeEquivalente: m[5]!.trim(),
        chCumpriu: m[3]!,
        chEquivalente: m[6]!,
      ),
  ];
}

// ─── Contagem de status (entrada "Pendencias") ───

/// Espelho da contagem global de status em pdfParser.ts.
Map<String, int> contarStatus(String texto) {
  final contagem = <String, int>{};
  final re = RegExp(
    r'\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b',
    caseSensitive: false,
  );
  for (final m in re.allMatches(texto)) {
    final chave = m[1]!.toUpperCase();
    contagem[chave] = (contagem[chave] ?? 0) + 1;
  }
  return contagem;
}
