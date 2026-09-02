import 'package:intl/intl.dart';

/// Núcleo compartilhado de formatação de tempo relativo em português.
///
/// - < 1 min (ou data futura, relógio dessincronizado) → "agora"
/// - < 1 h → "há 5 min"
/// - < 24 h → "há 3 h"
/// - até [diasParaDataAbsoluta] dias → "há 1 dia" / "há 2 dias"
/// - além disso → data absoluta "dd/MM/yyyy" (ou continua em dias se
///   [diasParaDataAbsoluta] for null)
///
/// [prefixo] permite variações como "atualizado há 5 min". [agora] é
/// injetável para testes. Retorna string vazia para [data] nula.
String tempoRelativo(
  DateTime? data, {
  DateTime? agora,
  String prefixo = '',
  int? diasParaDataAbsoluta,
}) {
  if (data == null) return '';
  final referencia = agora ?? DateTime.now();
  // difference compara instantes (epoch), então funciona entre UTC e local.
  var diferenca = referencia.difference(data);
  if (diferenca.isNegative) diferenca = Duration.zero;

  final p = prefixo.isEmpty ? '' : '$prefixo ';
  if (diferenca.inMinutes < 1) return '${p}agora';
  if (diferenca.inHours < 1) return '${p}há ${diferenca.inMinutes} min';
  if (diferenca.inDays < 1) return '${p}há ${diferenca.inHours} h';
  if (diasParaDataAbsoluta != null &&
      diferenca.inDays >= diasParaDataAbsoluta) {
    return DateFormat('dd/MM/yyyy').format(data.toLocal());
  }
  final dias = diferenca.inDays;
  return dias == 1 ? '${p}há 1 dia' : '${p}há $dias dias';
}
