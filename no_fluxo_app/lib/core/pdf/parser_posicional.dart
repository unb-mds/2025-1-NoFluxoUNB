import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'extracao_metadados.dart';
import 'extracao_posicional.dart';
import 'extracao_texto.dart';
import 'historico_pdf_parser.dart';
import 'modelos_extracao.dart';

/// Histórico no formato DETALHADO (com EMENTA/OBJETIVOS e situações por
/// extenso). O site cai num fallback regex (`extrairDisciplinasDetalhado`)
/// para esse layout antigo; no app ele não foi portado — os históricos
/// atuais do SIGAA usam o formato posicional. Lançamos uma exceção clara
/// em vez de extrair dados errados.
class FormatoDetalhadoNaoSuportadoException implements Exception {
  final String message =
      'Este histórico está no formato detalhado (com ementas), que ainda não '
      'é suportado no app. Gere o histórico no formato padrão do SIGAA.';

  @override
  String toString() => message;
}

/// Parser posicional do histórico SIGAA — porte fiel do pipeline do site
/// (pdfExtractor + pdfPositionExtractor + pdfDataExtractor + pdfParser),
/// trocando o PDF.js pelo syncfusion_flutter_pdf.
class ParserPosicional implements HistoricoPdfParser {
  @override
  Future<ParsedPdfResult> parse(Uint8List bytes, String filename) async {
    // 1. Carrega o PDF e extrai os itens posicionados (uma lista por página)
    List<List<ItemPosicionado>> paginas;
    try {
      final documento = PdfDocument(inputBytes: bytes);
      try {
        paginas = extrairItensPosicionados(documento);
      } finally {
        documento.dispose();
      }
    } on PdfSemTextoException {
      rethrow;
    } catch (_) {
      // PDF ilegível/corrompido — mesma mensagem do caso sem texto
      throw PdfSemTextoException();
    }

    final textoTotal = extrairTextoPlano(paginas);
    if (textoTotal.trim().isEmpty) {
      throw PdfSemTextoException();
    }

    // 2. Matrícula: prioridade do texto do PDF sobre o nome do arquivo
    final matriculaDoTexto = extrairMatriculaDoTexto(textoTotal);
    final matricula =
        matriculaDoTexto ??
        sanitizarMatriculaDoNomeArquivo(
          extrairMatriculaDoNomeArquivo(filename),
        );

    // 3. Disciplinas regulares — extração posicional
    final ehDetalhado =
        textoTotal.contains('EMENTA:') &&
        RegExp(r'APROVADO\(A\)|REPROVADO\(A\)').hasMatch(textoTotal);
    if (ehDetalhado) {
      throw FormatoDetalhadoNaoSuportadoException();
    }

    var disciplinas = extrairDisciplinasPosicional(paginas);
    disciplinas = consolidarDisciplinasRegularesParaPersistencia(disciplinas);

    // 4. Metadados por regex — matriz primeiro para ancorar o curso ao bloco
    //    correto (evita pegar outro curso citado no meio do PDF)
    final matrizCurricular = extrairMatrizCurricular(textoTotal);
    var textoParaCurso = textoTotal;
    if (matrizCurricular != null) {
      final codeMatch = RegExp(r'^(\d+)/').firstMatch(matrizCurricular);
      if (codeMatch != null) {
        final code = codeMatch[1]!;
        var idx = textoTotal.indexOf('$code/');
        if (idx == -1) idx = textoTotal.indexOf(matrizCurricular);
        if (idx > 0) {
          final fim = (idx + matrizCurricular.length + 400).clamp(
            0,
            textoTotal.length,
          );
          textoParaCurso = textoTotal.substring(0, fim);
        }
      }
    }
    final curso = extrairCurso(textoParaCurso);

    final suspensoes = extrairSuspensoes(textoTotal);

    double? ira;
    String? iraTextoHistorico;
    final iraMatch = regexIraHistorico.firstMatch(textoTotal);
    if (iraMatch != null) {
      iraTextoHistorico = iraMatch[1]!.trim();
      ira = iraStringParaNumero(iraTextoHistorico);
    }

    final mediaPonderada = extrairMediaPonderada(textoTotal);

    // 5. Disciplinas pendentes + 6. equivalências + carga horária
    final pendentes = extrairDisciplinasPendentes(textoTotal);
    final equivalencias = extrairEquivalencias(textoTotal);
    final cargaHorariaIntegralizada = extrairCargaHorariaIntegralizada(
      textoTotal,
    );

    // 7. Monta o extracted_data completo: regulares consolidadas, pendentes,
    //    entrada "Pendencias" (contagem de status) e entrada "IRA"
    final todasDisciplinas = <DisciplinaExtraida>[...disciplinas, ...pendentes];

    final contagemStatus = contarStatus(textoTotal);
    if (contagemStatus.isNotEmpty) {
      todasDisciplinas.add(
        DisciplinaExtraida(
          tipoDado: 'Pendencias',
          mencao: '',
          valores: contagemStatus,
        ),
      );
    }

    if (ira != null) {
      todasDisciplinas.add(
        DisciplinaExtraida(
          tipoDado: 'IRA',
          mencao: '',
          iraValor: ira,
          iraValorTexto: iraTextoHistorico,
        ),
      );
    }

    final semestreAtual = extrairSemestreAtual(todasDisciplinas);
    final periodoReal = extrairPeriodoLetivoAtual(textoTotal);
    final numeroSemestre =
        periodoReal ?? calcularNumeroSemestre(todasDisciplinas);

    return ParsedPdfResult(
      filename: filename,
      matricula: matricula,
      cursoExtraido: curso,
      matrizCurricular: matrizCurricular,
      mediaPonderada: mediaPonderada,
      fullText: textoTotal,
      extractedData: todasDisciplinas,
      equivalenciasPdf: equivalencias,
      semestreAtual: semestreAtual,
      numeroSemestre: numeroSemestre,
      suspensoes: suspensoes,
      cargaHorariaIntegralizada: cargaHorariaIntegralizada,
    );
  }
}

// ─── Consolidação das tentativas por código (porte de pdfParser.ts) ───

({int ano, int periodo})? _parseAnoPeriodo(String? anoPeriodo) {
  final s = (anoPeriodo ?? '').trim();
  final m = RegExp(r'^(\d{4})\.(\d)$').firstMatch(s);
  if (m == null) return null;
  return (ano: int.parse(m[1]!), periodo: int.parse(m[2]!));
}

int _compararAnoPeriodo(String? a, String? b) {
  final pa = _parseAnoPeriodo(a);
  final pb = _parseAnoPeriodo(b);
  if (pa != null && pb != null) {
    if (pa.ano != pb.ano) return pa.ano - pb.ano;
    return pa.periodo - pb.periodo;
  }
  if (pa != null && pb == null) return 1;
  if (pa == null && pb != null) return -1;
  return 0;
}

/// Consolida as tentativas por código de disciplina para persistência —
/// porte fiel de `consolidarDisciplinasRegularesParaPersistencia`:
/// - TODA aprovação (APR/CUMP/DISP) conta, uma por ano/período (chave vazia
///   vira '--'), protegendo repetíveis e aproveitamentos (CUMP sem período);
/// - MATR mais recente é mantida;
/// - sem aprovação nem matrícula: só a tentativa mais recente, e descarta
///   se for TRANC.
List<DisciplinaExtraida> consolidarDisciplinasRegularesParaPersistencia(
  List<DisciplinaExtraida> disciplinas,
) {
  String statusDe(DisciplinaExtraida d) => d.status.trim().toUpperCase();
  const aprovada = {'APR', 'CUMP', 'DISP'};

  final porCodigo = <String, List<(DisciplinaExtraida, int)>>{};
  for (var index = 0; index < disciplinas.length; index++) {
    final item = disciplinas[index];
    final codigo = item.codigo.trim().toUpperCase();
    if (codigo.isEmpty) continue;
    porCodigo.putIfAbsent(codigo, () => []).add((item, index));
  }

  final saida = <(DisciplinaExtraida, int)>[];
  for (final lista in porCodigo.values) {
    final aprovadas = [
      for (final w in lista)
        if (aprovada.contains(statusDe(w.$1))) w,
    ];
    final periodosVistos = <String>{};
    for (final w in aprovadas) {
      final chave = w.$1.anoPeriodo.trim().isEmpty
          ? '--'
          : w.$1.anoPeriodo.trim();
      if (!periodosVistos.add(chave)) continue;
      saida.add(w);
    }

    final matrs = [
      for (final w in lista)
        if (statusDe(w.$1) == 'MATR') w,
    ];
    if (matrs.isNotEmpty) {
      var maisRecente = matrs.first;
      for (final b in matrs.skip(1)) {
        final cmp = _compararAnoPeriodo(
          maisRecente.$1.anoPeriodo,
          b.$1.anoPeriodo,
        );
        if (cmp < 0 || (cmp == 0 && b.$2 > maisRecente.$2)) maisRecente = b;
      }
      saida.add(maisRecente);
    }

    if (aprovadas.isEmpty && matrs.isEmpty) {
      var vencedora = lista.first;
      for (final b in lista.skip(1)) {
        final cmp = _compararAnoPeriodo(
          vencedora.$1.anoPeriodo,
          b.$1.anoPeriodo,
        );
        if (cmp < 0 || (cmp == 0 && b.$2 > vencedora.$2)) vencedora = b;
      }
      if (statusDe(vencedora.$1) != 'TRANC') saida.add(vencedora);
    }
  }

  // Ordem original do extrato — estável para o RPC e para os snapshots.
  saida.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final w in saida) w.$1];
}
