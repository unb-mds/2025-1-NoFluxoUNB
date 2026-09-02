// Primeiro consumidor: o Assistente IA (chat "Darcy") —
// features/assistente/data/assistente_repository.dart usa este cliente para
// falar com o backend Express (POST /chat/send). O restante do app segue
// falando direto com o Supabase.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Erro de chamada à API Express.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP para a API Express do NoFluxo.
///
/// Rotas autenticadas usam DOIS headers (padrão do backend):
///  - `Authorization`: access token do Supabase (cru, sem "Bearer");
///  - `User-ID`: `id_user` (bigint de `public.users`) do usuário logado.
class ApiClient {
  final http.Client _http;

  /// Fornece o `id_user` do usuário logado (null = visitante/deslogado).
  final int? Function() _userIdProvider;

  ApiClient({required int? Function() userIdProvider, http.Client? httpClient})
    : _userIdProvider = userIdProvider,
      _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiUrl.endsWith('/')
        ? AppConfig.apiUrl.substring(0, AppConfig.apiUrl.length - 1)
        : AppConfig.apiUrl;
    final caminho = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$base$caminho',
    ).replace(queryParameters: (query?.isEmpty ?? true) ? null : query);
  }

  Map<String, String> _headers({required bool autenticado}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (autenticado) {
      headers['Authorization'] = SupabaseService.accessToken ?? '';
      headers['User-ID'] = _userIdProvider()?.toString() ?? '';
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    final corpo = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        corpo.isEmpty ? 'Erro na API' : corpo,
      );
    }
    if (corpo.isEmpty) return null;
    try {
      return jsonDecode(corpo);
    } on FormatException {
      throw ApiException(response.statusCode, 'Resposta não é JSON: $corpo');
    }
  }

  /// GET com resposta JSON.
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool autenticado = false,
  }) async {
    final response = await _http.get(
      _uri(path, query),
      headers: _headers(autenticado: autenticado),
    );
    return _decode(response);
  }

  /// POST com corpo e resposta JSON.
  Future<dynamic> postJson(
    String path,
    Object? body, {
    bool autenticado = false,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(autenticado: autenticado),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  void dispose() => _http.close();
}

/// Cliente da API Express, com o `id_user` vindo do estado de auth.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    userIdProvider: () => ref.read(authProvider).valueOrNull?.user?.idUser,
  );
  ref.onDispose(client.dispose);
  return client;
});
