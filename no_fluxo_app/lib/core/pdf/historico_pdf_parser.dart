import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'modelos_extracao.dart';
import 'parser_posicional.dart';

/// Contrato do parser do histórico SIGAA em PDF.
///
/// A implementação real (extração posicional com syncfusion_flutter_pdf,
/// porte fiel de no_fluxo_frontend_svelte/src/lib/services/pdf/) vive em
/// parser_posicional.dart. A UI de importação depende só desta interface —
/// os testes de tela usam um fake.
abstract class HistoricoPdfParser {
  /// Extrai o [ParsedPdfResult] dos bytes do PDF.
  ///
  /// Lança [PdfSemTextoException] quando o PDF não tem texto extraível
  /// (scan/imagem/corrompido).
  Future<ParsedPdfResult> parse(Uint8List bytes, String filename);
}

/// PDF sem conteúdo textual — mesma mensagem do site.
class PdfSemTextoException implements Exception {
  final String message =
      'Nenhuma informação textual pôde ser extraída do PDF. O PDF pode ser '
      'uma imagem de baixa qualidade, estar vazio ou corrompido.';

  @override
  String toString() => message;
}

/// Provider do parser (a UI lê daqui; testes sobrescrevem com fake).
final historicoPdfParserProvider = Provider<HistoricoPdfParser>(
  (ref) => ParserPosicional(),
);
