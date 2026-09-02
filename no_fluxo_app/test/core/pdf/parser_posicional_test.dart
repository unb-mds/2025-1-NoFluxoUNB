// Testes do parser posicional contra PDFs REAIS de históricos SIGAA
// (test_historicos/historicos/, na raiz do repositório).
//
// `flutter test` roda com cwd = raiz do app, então o caminho relativo é
// construído a partir de Directory.current.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_fluxo_app/core/pdf/historico_pdf_parser.dart';
import 'package:no_fluxo_app/core/pdf/modelos_extracao.dart';
import 'package:no_fluxo_app/core/pdf/parser_posicional.dart';

final _reCodigoDisciplina = RegExp(r'^[A-Z]{2,}\d{3,}$');
const _statusValidos = {
  'APR',
  'REP',
  'REPF',
  'REPMF',
  'CANC',
  'DISP',
  'TRANC',
  'MATR',
  'CUMP',
};

Uint8List _lerPdf(String nome) {
  final caminho =
      '${Directory.current.path}/../test_historicos/historicos/$nome';
  final arquivo = File(caminho);
  expect(
    arquivo.existsSync(),
    isTrue,
    reason: 'PDF de teste não encontrado: $caminho',
  );
  return arquivo.readAsBytesSync();
}

Iterable<DisciplinaExtraida> _regulares(ParsedPdfResult r) =>
    r.extractedData.where((d) => d.tipoDado == 'Disciplina Regular');

Iterable<DisciplinaExtraida> _pendentes(ParsedPdfResult r) =>
    r.extractedData.where((d) => d.tipoDado == 'Disciplina Pendente');

/// Asserções comuns a todo histórico no formato posicional.
void _validarHistorico(ParsedPdfResult r) {
  // Metadados não-vazios e plausíveis
  expect(r.cursoExtraido, isNotNull);
  expect(r.cursoExtraido, isNotEmpty);
  expect(r.matrizCurricular, isNotNull);
  expect(r.matrizCurricular, matches(RegExp(r'^\d+/-?\d+')));
  expect(r.matricula, matches(RegExp(r'^\d{8,12}$')));

  // Entrada IRA com valor plausível e valor_texto fiel ao PDF
  final ira = r.extractedData.where((d) => d.tipoDado == 'IRA').toList();
  expect(ira, hasLength(1));
  expect(ira.single.iraValor, isNotNull);
  expect(ira.single.iraValor, greaterThanOrEqualTo(0));
  expect(ira.single.iraValor, lessThanOrEqualTo(5));
  expect(ira.single.iraValorTexto, matches(RegExp(r'^\d+[.,]\d+$')));

  // Entrada Pendencias (contagem global de status) sempre presente
  final pendencias = r.extractedData
      .where((d) => d.tipoDado == 'Pendencias')
      .toList();
  expect(pendencias, hasLength(1));
  expect(pendencias.single.valores, isNotEmpty);

  // Disciplinas regulares: códigos e statuses válidos
  final regulares = _regulares(r).toList();
  expect(regulares, isNotEmpty);
  for (final d in regulares) {
    expect(
      d.codigo,
      matches(_reCodigoDisciplina),
      reason: 'código inválido: "${d.codigo}" (${d.nome})',
    );
    expect(
      _statusValidos,
      contains(d.status),
      reason: 'status inválido: "${d.status}" (${d.codigo})',
    );
    expect(d.nome, isNotEmpty, reason: 'nome vazio para ${d.codigo}');
    expect(d.cargaHoraria, greaterThan(0), reason: 'CH zerada em ${d.codigo}');
    if (d.anoPeriodo.isNotEmpty) {
      expect(d.anoPeriodo, matches(RegExp(r'^\d{4}\.\d$')));
    }
  }

  // Consolidação: sem duplicatas por (codigo, ano_periodo)
  final chaves = <String>{};
  for (final d in regulares) {
    final chave = '${d.codigo}|${d.anoPeriodo}';
    expect(
      chaves.add(chave),
      isTrue,
      reason: 'tentativa duplicada após consolidação: $chave',
    );
  }

  // Pendentes: código válido (ou ENADE) e status PENDENTE/MATR
  for (final d in _pendentes(r)) {
    expect(
      d.codigo == 'ENADE' || _reCodigoDisciplina.hasMatch(d.codigo),
      isTrue,
      reason: 'código pendente inválido: "${d.codigo}"',
    );
    expect({'PENDENTE', 'MATR'}, contains(d.status));
    // ENADE aparece com 0 h; as demais têm CH positiva
    expect(d.cargaHoraria, greaterThanOrEqualTo(0));
    if (d.codigo != 'ENADE') {
      expect(
        d.cargaHoraria,
        greaterThan(0),
        reason: 'CH zerada em ${d.codigo}',
      );
    }
  }

  // Ordem do extracted_data: regulares, pendentes, Pendencias, IRA
  final tipos = r.extractedData.map((d) => d.tipoDado).toList();
  expect(tipos.last, 'IRA');
  expect(tipos[tipos.length - 2], 'Pendencias');
  final idxPrimeiroPendente = tipos.indexOf('Disciplina Pendente');
  if (idxPrimeiroPendente != -1) {
    expect(
      tipos.lastIndexOf('Disciplina Regular'),
      lessThan(idxPrimeiroPendente),
    );
  }
}

void main() {
  final parser = ParserPosicional();

  group('ParserPosicional — PDFs reais', () {
    test('historico_222006202 (1).pdf — Engenharia de Software', () async {
      final r = await parser.parse(
        _lerPdf('historico_222006202 (1).pdf'),
        'historico_222006202 (1).pdf',
      );
      _validarHistorico(r);

      expect(r.cursoExtraido, 'ENGENHARIA DE SOFTWARE');
      expect(r.matrizCurricular, '6360/1');
      expect(r.matricula, '222006202'); // do texto, sem o lixo " (1)"
      expect(r.mediaPonderada, closeTo(3.5094, 1e-9));
      expect(r.semestreAtual, '2025.1');
      expect(r.numeroSemestre, 6); // "Período Letivo Atual: 6"
      expect(r.suspensoes, isEmpty);

      final regulares = _regulares(r).toList();
      expect(regulares.length, greaterThan(10));

      // CH integralizada — confere com a tabela do PDF
      final ch = r.cargaHorariaIntegralizada!;
      expect(ch.obrigatoria, 630);
      expect(ch.optativa, 420);
      expect(ch.complementar, 0);
      expect(ch.total, 1050);

      // Disciplina conhecida com todos os campos
      final cic = regulares.firstWhere((d) => d.codigo == 'CIC0004');
      expect(cic.nome, 'ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES');
      expect(cic.status, 'APR');
      expect(cic.mencao, 'MM');
      expect(cic.cargaHoraria, 90);
      expect(cic.creditos, 6);
      expect(cic.anoPeriodo, '2022.2');
      expect(cic.turma, '11');
      expect(cic.frequencia, '79,0');
      expect(cic.professor, 'DANIEL SUNDFELD LIMA');

      // Aproveitamento (CUMP) sem período sobrevive à consolidação
      final cump = regulares.where((d) => d.status == 'CUMP');
      expect(cump.map((d) => d.codigo), contains('FGA0221'));

      // Equivalência declarada no PDF
      expect(r.equivalenciasPdf, hasLength(1));
      final eq = r.equivalenciasPdf.single;
      expect(eq.cumpriu, 'MAT0025');
      expect(eq.atravesDe, 'MAT0137');
      expect(eq.chCumpriu, '90');
      expect(eq.chEquivalente, '90');

      // Pendentes: 31 extraídas (33 declaradas − 2 CADEIA, como no site)
      expect(_pendentes(r).length, 31);
      final pendMatr = _pendentes(r).where((d) => d.status == 'MATR');
      expect(
        pendMatr.map((d) => d.observacao),
        everyElement(matches(RegExp(r'^Matriculado( em Equivalente)?$'))),
      );
    });

    test('historico_222038485.pdf — Gestão de Políticas Públicas', () async {
      final r = await parser.parse(
        _lerPdf('historico_222038485.pdf'),
        'historico_222038485.pdf',
      );
      _validarHistorico(r);

      expect(r.cursoExtraido, 'GESTÃO DE POLÍTICAS PÚBLICAS');
      expect(r.matrizCurricular, '8184/1');
      expect(r.matricula, '222038485');
      expect(_regulares(r).length, greaterThan(10));
      expect(_pendentes(r).length, 6);

      final ch = r.cargaHorariaIntegralizada!;
      expect(ch.obrigatoria, 1320);
      expect(ch.optativa, 210);
      expect(ch.complementar, 0);
      expect(ch.total, 1530);
    });

    test('historico_231014508-5_250711_141618.pdf — Direito', () async {
      final r = await parser.parse(
        _lerPdf('historico_231014508-5_250711_141618.pdf'),
        'historico_231014508-5_250711_141618.pdf',
      );
      _validarHistorico(r);

      expect(r.cursoExtraido, 'DIREITO');
      expect(r.matrizCurricular, '8486/1');
      // Matrícula vem do texto do PDF, não do nome de arquivo poluído
      expect(r.matricula, '231014508');
      expect(_regulares(r).length, greaterThan(10));

      final ch = r.cargaHorariaIntegralizada!;
      expect(ch.obrigatoria, 1410);
      expect(ch.optativa, 615);
      expect(ch.complementar, 300);
      expect(ch.total, 2325);
    });

    test('historico_190012579 (5) (1).pdf — suspensões e dispensas', () async {
      final r = await parser.parse(
        _lerPdf('historico_190012579 (5) (1).pdf'),
        'historico_190012579 (5) (1).pdf',
      );
      _validarHistorico(r);

      expect(r.cursoExtraido, 'ENGENHARIA DE SOFTWARE');
      expect(r.matrizCurricular, '6360/1');
      expect(r.matricula, '190012579');
      expect(r.suspensoes, ['2020.1', '2024.1']);
      expect(_regulares(r).length, greaterThan(10));

      // DISP consolidada como aprovação
      final disp = _regulares(r).where((d) => d.status == 'DISP');
      expect(disp.map((d) => d.codigo), contains('CIC0007'));

      final ch = r.cargaHorariaIntegralizada!;
      expect(ch.obrigatoria, 1080);
      expect(ch.optativa, 600);
      expect(ch.total, 1680);
    });

    test('historico_232021516.pdf — calouro só com MATR', () async {
      final r = await parser.parse(
        _lerPdf('historico_232021516.pdf'),
        'historico_232021516.pdf',
      );
      _validarHistorico(r);

      expect(r.matricula, '232021516');
      expect(r.matrizCurricular, '6009/1');
      // Todas as regulares em MATR (1º semestre)
      final regulares = _regulares(r).toList();
      expect(regulares, isNotEmpty);
      expect(regulares.map((d) => d.status).toSet(), {'MATR'});
      expect(r.semestreAtual, '2023.2');
      expect(r.numeroSemestre, 1); // "Período Letivo Atual: 1"

      // Integralizado zerado ainda é extraído (0/0/0/0)
      final ch = r.cargaHorariaIntegralizada!;
      expect(ch.total, 0);
    });

    test('formato detalhado (com EMENTA) lança exceção clara', () async {
      expect(
        () => parser.parse(
          _lerPdf('historico_211029503 (1).pdf'),
          'historico_211029503 (1).pdf',
        ),
        throwsA(isA<FormatoDetalhadoNaoSuportadoException>()),
      );
    });

    test('bytes que não são PDF lançam PdfSemTextoException', () async {
      expect(
        () => parser.parse(
          Uint8List.fromList(List.filled(64, 42)),
          'nao_e_pdf.pdf',
        ),
        throwsA(isA<PdfSemTextoException>()),
      );
    });
  });
}
