/// Helpers de parsing defensivo de JSON.
///
/// O `fluxograma_atual` no banco é TEXT com JSON gerado por versões diferentes
/// do upload, então nenhum campo é confiável: pode faltar, vir com outro tipo
/// (int como String, double como int) ou vir nulo. Estes helpers garantem que
/// os `fromJson` dos models nunca estourem por causa disso.
library;

import 'dart:convert';

/// Converte para [int], com fallback quando nulo ou inválido.
int parseIntOr(dynamic value, [int fallback = 0]) {
  return parseIntOrNull(value) ?? fallback;
}

/// Converte para [int] ou retorna null.
int? parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ??
      double.tryParse(value.toString())?.toInt();
}

/// Converte para [double], com fallback quando nulo ou inválido.
double parseDoubleOr(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  // Histórico do SIGAA usa vírgula decimal ("4,1234").
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
}

/// Converte para [String], com fallback quando nulo.
String parseStringOr(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

/// Converte para [String] ou retorna null (nunca a string "null").
String? parseStringOrNull(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

/// Converte para [bool], aceitando "true"/1 vindos de serialização frouxa.
bool parseBoolOr(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final texto = value.toString().trim().toLowerCase();
  if (texto == 'true' || texto == '1') return true;
  if (texto == 'false' || texto == '0') return false;
  return fallback;
}

/// Converte para [DateTime] ou retorna null (aceita ISO 8601).
DateTime? parseDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// Retorna o valor como `Map<String, dynamic>` ou null.
Map<String, dynamic>? asMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Retorna o valor como [List] ou lista vazia.
List<dynamic> asListOr(dynamic value) {
  if (value is List) return value;
  return const [];
}

/// Aceita tanto um Map já decodificado quanto uma String contendo JSON
/// (caso do `dados_users.fluxograma_atual`, que é TEXT no banco).
/// Retorna null se não for possível obter um Map.
Map<String, dynamic>? decodeJsonMap(dynamic value) {
  if (value == null) return null;
  final map = asMapOrNull(value);
  if (map != null) return map;
  if (value is String) {
    if (value.trim().isEmpty) return null;
    try {
      return asMapOrNull(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }
  return null;
}
