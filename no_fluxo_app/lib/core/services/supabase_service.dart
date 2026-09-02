import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper fino (singleton) sobre o cliente Supabase.
///
/// Centraliza o acesso a `Supabase.instance.client` para os services não
/// espalharem a dependência direta — e para facilitar mock em testes.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  /// Sessão atual (null se deslogado).
  static Session? get session => auth.currentSession;

  /// Usuário do Supabase Auth (null se deslogado).
  static User? get currentAuthUser => auth.currentUser;

  /// Access token JWT atual (null se deslogado). O supabase_flutter renova a
  /// sessão automaticamente.
  static String? get accessToken => session?.accessToken;
}
