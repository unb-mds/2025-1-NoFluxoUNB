/// Repositório do Assistente IA (chat "Darcy") — fala com o backend Express.
///
/// Contrato (chat_controller.ts): `POST /chat/send` com o access token do
/// Supabase no header e body `{message, curriculoCompleto?}` → `{reply}`.
/// O histórico da conversa vive NO SERVIDOR (sessão keyed pelo token) — o
/// app manda só a mensagem nova, nunca o histórico.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Erro do assistente já com mensagem amigável para exibir no chat.
class AssistenteException implements Exception {
  final String mensagem;

  const AssistenteException(this.mensagem);

  @override
  String toString() => 'AssistenteException: $mensagem';
}

/// Envia mensagens ao orquestrador de chat do backend.
class AssistenteRepository {
  final ApiClient _api;

  /// A resposta envolve LLM + tools no servidor — bem mais lenta que uma
  /// rota comum, daí o teto explícito de 90s.
  final Duration timeout;

  const AssistenteRepository(
    this._api, {
    this.timeout = const Duration(seconds: 90),
  });

  /// Manda [mensagem] ao Darcy e devolve o reply (texto com marcadores —
  /// ver `domain/reply_parser.dart`).
  ///
  /// [curriculoCompleto] é a matriz curricular do aluno
  /// (`dados.matrizCurricular`), quando existir — dá contexto ao orquestrador.
  Future<String> enviarMensagem(
    String mensagem, {
    String? curriculoCompleto,
  }) async {
    final curriculo = curriculoCompleto?.trim() ?? '';
    try {
      final json = await _api
          .postJson('/chat/send', {
            'message': mensagem,
            if (curriculo.isNotEmpty) 'curriculoCompleto': curriculo,
          }, autenticado: true)
          .timeout(timeout);

      final reply = json is Map ? json['reply'] : null;
      if (reply is! String || reply.trim().isEmpty) {
        throw const AssistenteException(
          'O assistente respondeu em um formato inesperado. Tente de novo.',
        );
      }
      return reply;
    } on AssistenteException {
      rethrow;
    } on TimeoutException {
      throw const AssistenteException(
        'O assistente demorou demais para responder. Tente de novo.',
      );
    } on ApiException catch (e) {
      throw AssistenteException(_mensagemDeErro(e));
    } catch (_) {
      throw const AssistenteException(
        'Não foi possível conectar ao assistente. Verifique sua conexão.',
      );
    }
  }

  /// Erros da API (`{"error": ...}`) → mensagem exibível no chat.
  String _mensagemDeErro(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Sua sessão expirou. Entre de novo para conversar com o Darcy.';
      case 503:
        return 'O assistente está indisponível no momento. Tente mais tarde.';
    }
    // 400/500: usa o campo `error` do corpo quando houver.
    try {
      final corpo = jsonDecode(e.message);
      final erro = corpo is Map ? corpo['error'] : null;
      if (erro is String && erro.trim().isNotEmpty) return erro;
    } on FormatException {
      // Corpo não-JSON: cai na mensagem genérica.
    }
    return 'O assistente encontrou um erro. Tente de novo.';
  }
}

/// Repositório do assistente, com o [ApiClient] compartilhado do app.
final assistenteRepositoryProvider = Provider<AssistenteRepository>((ref) {
  return AssistenteRepository(ref.watch(apiClientProvider));
});
