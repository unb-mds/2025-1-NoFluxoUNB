import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/json_utils.dart';
import 'ticket_model.dart';

/// Versão do app gravada no metadata do ticket (v1 não tem package_info).
const String kSuporteAppVersion = '0.1.0-dev';

/// Acesso a dados dos chamados de suporte do usuário logado.
///
/// Fonte da verdade do shape: `ticket.service.ts` do site — INSERT único na
/// tabela `tickets` (a RLS bloqueia UPDATE pelo criador) e SELECT filtrado
/// por `created_by = auth.uid()`. O v1 do app NÃO envia anexos
/// (`attachments` vai sempre como lista vazia).
abstract class SuporteRepository {
  /// Cria um chamado. Lança [StateError] se não houver usuário autenticado.
  Future<TicketModel> criarTicket({
    required String title,
    required String description,
    required TicketCategoria categoria,
  });

  /// Chamados do usuário logado, mais recentes primeiro. Lista vazia quando
  /// não há sessão.
  Future<List<TicketModel>> meusTickets();
}

/// Implementação real sobre o cliente Supabase.
class SupabaseSuporteRepository implements SuporteRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// UUID do Supabase Auth do usuário logado (mesma origem do site:
  /// `supabase.auth.getUser().id` — aqui o equivalente síncrono do SDK).
  String? get _authId => SupabaseService.currentAuthUser?.id;

  /// Metadata de diagnóstico do dispositivo — o análogo mobile do
  /// `collectMetadata()` do site (que manda user_agent/platform/url).
  static Map<String, dynamic> coletarMetadata() {
    var plataforma = 'android';
    var osVersion = '';
    try {
      plataforma = Platform.isIOS ? 'ios' : 'android';
      osVersion = Platform.operatingSystemVersion;
    } catch (e) {
      // Plataforma sem dart:io completo (ex.: web) — segue com defaults.
      debugPrint('Metadata de plataforma indisponível: $e');
    }
    return {
      'platform': plataforma,
      'app_version': kSuporteAppVersion,
      'os_version': osVersion,
    };
  }

  /// Monta o payload do INSERT em `tickets` — pura, para o shape ser
  /// verificável em teste sem Supabase.
  @visibleForTesting
  static Map<String, dynamic> montarInsertTicket({
    required String authId,
    required String title,
    required String description,
    required TicketCategoria categoria,
    required Map<String, dynamic> metadata,
  }) {
    return {
      'created_by': authId,
      'title': title.trim(),
      'description': description.trim(),
      'category': categoria.valor,
      'status': 'aberto',
      'metadata': metadata,
      'attachments': const <dynamic>[],
    };
  }

  @override
  Future<TicketModel> criarTicket({
    required String title,
    required String description,
    required TicketCategoria categoria,
  }) async {
    final authId = _authId;
    if (authId == null) {
      throw StateError('Usuário não autenticado.');
    }
    final inserted = await _client
        .from('tickets')
        .insert(
          montarInsertTicket(
            authId: authId,
            title: title,
            description: description,
            categoria: categoria,
            metadata: coletarMetadata(),
          ),
        )
        .select('*')
        .single();
    return TicketModel.fromJson(inserted);
  }

  @override
  Future<List<TicketModel>> meusTickets() async {
    final authId = _authId;
    if (authId == null) return const [];
    final data = await _client
        .from('tickets')
        .select('*')
        .eq('created_by', authId)
        .order('created_at', ascending: false);
    return data
        .map(asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(TicketModel.fromJson)
        .toList();
  }
}

/// Repositório de suporte (override em testes).
final suporteRepositoryProvider = Provider<SuporteRepository>(
  (ref) => SupabaseSuporteRepository(),
);

/// Chamados do usuário logado, mais recentes primeiro.
final meusTicketsProvider = FutureProvider.autoDispose<List<TicketModel>>((
  ref,
) {
  return ref.watch(suporteRepositoryProvider).meusTickets();
});
