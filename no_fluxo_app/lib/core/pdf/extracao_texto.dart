/// Extração de texto posicionado do PDF — porte fiel de
/// no_fluxo_frontend_svelte/src/lib/services/pdf/pdfExtractor.ts, adaptado
/// do PDF.js para o syncfusion_flutter_pdf.
///
/// Diferenças de plataforma (validadas contra os PDFs reais):
/// - Eixo Y: o PDF.js tem origem embaixo (topo→base = Y decrescente); o
///   Syncfusion tem origem no TOPO (topo→base = Y CRESCENTE). A ordenação
///   final foi adaptada para produzir as linhas na mesma ordem (topo→base).
/// - Itens: o PDF.js entrega "runs" de texto com espaços internos; o
///   Syncfusion entrega PALAVRAS separadas (TextWord), sem itens de espaço.
///   Por isso, além do porte da regra de gaps grandes (SPACE_GAP_THRESHOLD),
///   reinserimos UM espaço entre palavras com gap pequeno mas positivo —
///   sem isso o texto plano sairia com as palavras coladas.
library;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Espelho do `PositionedTextItem` do site.
class ItemPosicionado {
  final String text;
  final double x;
  final double y;
  final double width;

  const ItemPosicionado({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
  });
}

/// Limiar (em pontos) para agrupar itens na mesma linha por proximidade de Y.
const double limiarProximidadeY = 3;

/// Distância (em pontos) acima da qual espaços múltiplos são inseridos.
const double _limiarGapEspacos = 10;

/// Largura estimada por caractere (para fallback de largura).
const double _larguraCaractereEstimada = 6;

/// Máximo de espaços inseridos para um único gap.
const int _maxEspacos = 10;

/// Gap mínimo para reinserir UM espaço entre palavras adjacentes
/// (adaptação Syncfusion — ver doc da biblioteca).
const double _gapEspacoSimples = 1.0;

/// Extrai os itens posicionados de todas as páginas do documento,
/// uma lista por página (espelho de `extractPositionedItemsFromDoc`).
List<List<ItemPosicionado>> extrairItensPosicionados(PdfDocument documento) {
  final paginas = List.generate(
    documento.pages.count,
    (_) => <ItemPosicionado>[],
  );
  final linhas = PdfTextExtractor(documento).extractTextLines();
  for (final linha in linhas) {
    if (linha.pageIndex < 0 || linha.pageIndex >= paginas.length) continue;
    for (final palavra in linha.wordCollection) {
      final texto = palavra.text.trim();
      if (texto.isEmpty) continue;
      paginas[linha.pageIndex].add(
        ItemPosicionado(
          text: texto,
          x: palavra.bounds.left,
          y: palavra.bounds.top,
          width: palavra.bounds.width,
        ),
      );
    }
  }
  return paginas;
}

/// Agrupa itens em linhas por proximidade de Y (espelho de
/// `groupItemsIntoLines`/`groupItemsIntoRows`). Retorna pares (yChave, itens)
/// em ordem de Y crescente — que no Syncfusion já é topo→base.
List<(double, List<ItemPosicionado>)> agruparItensEmLinhas(
  List<ItemPosicionado> itens,
) {
  final linhas = <(double, List<ItemPosicionado>)>[];
  if (itens.isEmpty) return linhas;

  final ordenados = [...itens]..sort((a, b) => a.y.compareTo(b.y));
  var chaveAtual = ordenados.first.y;
  var grupoAtual = <ItemPosicionado>[ordenados.first];
  linhas.add((chaveAtual, grupoAtual));

  for (var i = 1; i < ordenados.length; i++) {
    final item = ordenados[i];
    if ((item.y - chaveAtual).abs() <= limiarProximidadeY) {
      grupoAtual.add(item);
    } else {
      chaveAtual = item.y;
      grupoAtual = [item];
      linhas.add((chaveAtual, grupoAtual));
    }
  }

  return linhas;
}

/// Reconstrói uma linha de texto a partir dos itens, ordenados por X
/// (espelho de `reconstructLine`, com a reinserção de espaço simples).
String reconstruirLinha(List<ItemPosicionado> itens) {
  final ordenados = [...itens]..sort((a, b) => a.x.compareTo(b.x));

  final resultado = StringBuffer();
  var ultimoX = double.negativeInfinity;

  for (final item in ordenados) {
    if (ultimoX > double.negativeInfinity) {
      if (item.x > ultimoX + _limiarGapEspacos) {
        final gap = item.x - ultimoX;
        final numEspacos = ((gap / _larguraCaractereEstimada).floor()).clamp(
          1,
          _maxEspacos,
        );
        resultado.write(' ' * numEspacos);
      } else if (item.x > ultimoX + _gapEspacoSimples) {
        resultado.write(' ');
      }
    }

    resultado.write(item.text);

    final larguraTexto = item.width > 0
        ? item.width
        : item.text.length * _larguraCaractereEstimada;
    ultimoX = item.x + larguraTexto;
  }

  return resultado.toString();
}

/// Monta o texto plano do PDF inteiro, página a página, linhas do topo para
/// a base (espelho de `extractTextFromPdfDoc`; a ordenação por página
/// crescente + Y crescente equivale ao "página asc, Y desc" do PDF.js).
String extrairTextoPlano(List<List<ItemPosicionado>> paginas) {
  final todasLinhas = <(int, double, String)>[];

  for (var p = 0; p < paginas.length; p++) {
    for (final (y, itensLinha) in agruparItensEmLinhas(paginas[p])) {
      final texto = reconstruirLinha(itensLinha);
      if (texto.trim().isNotEmpty) {
        todasLinhas.add((p, y, texto));
      }
    }
  }

  todasLinhas.sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1); // página crescente
    return a.$2.compareTo(b.$2); // Y crescente = topo→base no Syncfusion
  });

  return todasLinhas.map((l) => l.$3).join('\n');
}

/// Extrai a matrícula do nome do arquivo (`prefixo_MATRICULA.pdf`) —
/// espelho de `extractMatriculaFromFilename`.
String extrairMatriculaDoNomeArquivo(String filename) {
  if (filename.contains('_')) {
    final partes = filename.split('_');
    if (partes.length < 2) return 'desconhecida';
    return partes[1].split('.').first;
  }
  return 'desconhecida';
}

/// Sanitiza a matrícula vinda do nome do arquivo (remove " (2)", " - cópia").
/// Espelho de `sanitizeMatriculaFromFilename`.
String sanitizarMatriculaDoNomeArquivo(String raw) {
  if (raw.isEmpty || raw == 'desconhecida') return raw;
  final limpa = raw
      .replaceFirst(RegExp(r'\s*\(\d+\)\s*$', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*-\s*c[óo]pia\s*$', caseSensitive: false), '')
      .trim();
  final soDigitos = limpa.replaceAll(RegExp(r'\D'), '');
  if (soDigitos.length >= 8 && soDigitos.length <= 12) return soDigitos;
  return limpa.isNotEmpty ? limpa : raw;
}
