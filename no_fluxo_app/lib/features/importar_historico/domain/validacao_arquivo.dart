/// Validação do arquivo de histórico — porte de `fileValidation.ts` do site
/// (mesmas mensagens).
library;

/// Tamanho máximo aceito (10MB, como no site).
const int kTamanhoMaximoPdf = 10 * 1024 * 1024;

/// Valida nome/tamanho do arquivo escolhido. Retorna a mensagem de erro
/// (textos idênticos aos do site) ou null quando o arquivo é válido.
String? validarArquivoPdf({required String nome, required int tamanhoBytes}) {
  if (!nome.toLowerCase().endsWith('.pdf')) {
    return 'Formato inválido. Somente arquivos PDF são aceitos.';
  }
  if (tamanhoBytes > kTamanhoMaximoPdf) {
    final tamanhoMb = (tamanhoBytes / (1024 * 1024)).toStringAsFixed(1);
    return 'Arquivo muito grande (${tamanhoMb}MB). O tamanho máximo é 10MB.';
  }
  if (tamanhoBytes == 0) {
    return 'O arquivo está vazio.';
  }
  return null;
}

/// Remove acentos para busca insensível (mesma normalização NFD do site,
/// coberta por tabela — Dart não tem `String.normalize`).
String removerAcentos(String texto) {
  const comAcento = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
  const semAcento = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
  final sb = StringBuffer();
  for (final rune in texto.runes) {
    final char = String.fromCharCode(rune);
    final idx = comAcento.indexOf(char);
    sb.write(idx >= 0 ? semAcento[idx] : char);
  }
  return sb.toString();
}
