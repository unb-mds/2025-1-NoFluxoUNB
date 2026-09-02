import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/validacao_arquivo.dart';

/// Arquivo escolhido pelo usuário (nome + bytes em memória).
///
/// [bytes] vem nulo quando o arquivo excede o limite — a validação rejeita
/// pelo [tamanhoBytes] sem carregar o conteúdo na memória.
class ArquivoPdfSelecionado {
  final String nome;
  final int tamanhoBytes;
  final Uint8List? bytes;

  const ArquivoPdfSelecionado({
    required this.nome,
    required this.tamanhoBytes,
    required this.bytes,
  });
}

/// Seam do file_picker — a tela depende só disto; testes usam fake.
abstract class SelecionadorDeArquivo {
  /// Abre o seletor nativo restrito a PDF. Null quando o usuário cancela.
  Future<ArquivoPdfSelecionado?> selecionarPdf();
}

/// Implementação real via `file_picker`.
class SelecionadorFilePicker implements SelecionadorDeArquivo {
  @override
  Future<ArquivoPdfSelecionado?> selecionarPdf() async {
    final arquivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (arquivo == null) return null;

    final tamanho = await arquivo.length();
    if (tamanho > kTamanhoMaximoPdf) {
      // Grande demais: não carrega na memória — a validação rejeita.
      return ArquivoPdfSelecionado(
        nome: arquivo.name,
        tamanhoBytes: tamanho,
        bytes: null,
      );
    }
    final bytes = await arquivo.readAsBytes();
    return ArquivoPdfSelecionado(
      nome: arquivo.name,
      tamanhoBytes: tamanho,
      bytes: bytes,
    );
  }
}

/// Seletor de arquivo (override em testes com um fake).
final selecionadorDeArquivoProvider = Provider<SelecionadorDeArquivo>(
  (ref) => SelecionadorFilePicker(),
);
