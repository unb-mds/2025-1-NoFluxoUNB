import 'package:flutter/foundation.dart';

import '../utils/json_utils.dart';
import 'supabase_service.dart';

/// Período letivo derivado da data — mesma heurística da RPC
/// `periodo_letivo_atual` (ano.1 até junho, ano.2 depois).
String periodoLetivoPorData(DateTime data) =>
    '${data.year}.${data.month <= 6 ? 1 : 2}';

/// Fonte única do período letivo ativo (ex.: "2026.1").
///
/// RPC `periodo_letivo_atual` com cache por sessão (muda uma vez por
/// semestre) e fallback pela heurística de data local quando a RPC falha —
/// consumidores nunca precisam do dance try/catch próprio.
class PeriodoLetivo {
  PeriodoLetivo._();

  static String? _cache;

  static Future<String> atual() async {
    final cache = _cache;
    if (cache != null) return cache;
    try {
      final data = await SupabaseService.client.rpc('periodo_letivo_atual');
      final periodo = parseStringOr(data).trim();
      if (periodo.isNotEmpty) {
        _cache = periodo;
        return periodo;
      }
    } catch (e) {
      debugPrint('PeriodoLetivo: falha na RPC periodo_letivo_atual: $e');
    }
    // Falha não é cacheada — a próxima chamada tenta a RPC de novo.
    return periodoLetivoPorData(DateTime.now());
  }

  @visibleForTesting
  static void limparCache() => _cache = null;
}
