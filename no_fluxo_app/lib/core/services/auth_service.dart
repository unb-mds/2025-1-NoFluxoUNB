import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supa
    show AuthChangeEvent, OAuthProvider;

import '../models/user_model.dart';
import 'push_service.dart';
import 'supabase_service.dart';

/// "Há usuário logado?" derivado do [authProvider].
///
/// Provider próprio (em vez de watch direto espalhado pela UI) para os testes
/// de widget poderem sobrescrever sem tocar no Supabase — e para a nuance
/// `loggedInSemPerfil` (isLoggedIn com user null) ser decidida num lugar só.
final estaLogadoProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isLoggedIn ?? false;
});

/// Situação de autenticação do app.
enum AuthStatus {
  /// Sessão Supabase válida + perfil carregado.
  loggedIn,

  /// Modo visitante (flag local em shared_preferences, sem sessão Supabase).
  anonymous,

  /// Sem sessão e sem modo visitante.
  loggedOut,
}

/// Estado de autenticação exposto ao app.
class AuthState {
  final AuthStatus status;
  final UserModel? user;

  /// Fluxograma do usuário — derivado, para nenhum construtor precisar
  /// mantê-lo em sincronia com [user].
  DadosFluxogramaUser? get dados => user?.dadosFluxograma;

  const AuthState({required this.status, this.user});

  const AuthState.loggedOut() : status = AuthStatus.loggedOut, user = null;

  const AuthState.anonymous() : status = AuthStatus.anonymous, user = null;

  AuthState.loggedIn(UserModel this.user) : status = AuthStatus.loggedIn;

  /// Sessão Supabase local válida, mas o perfil ainda não pôde ser carregado
  /// (ex.: boot sem rede). O usuário continua logado; o perfil chega depois
  /// via retry ([AuthNotifier._agendarRetryDePerfil]) ou onAuthStateChange.
  const AuthState.loggedInSemPerfil()
    : status = AuthStatus.loggedIn,
      user = null;

  bool get isLoggedIn => status == AuthStatus.loggedIn;
  bool get isVisitante => status == AuthStatus.anonymous;
}

/// Deep link de retorno do OAuth em mobile.
///
/// TODO(plataforma): registrar o scheme `nofluxo` nas plataformas:
///  - Android: intent-filter com `<data android:scheme="nofluxo"
///    android:host="auth-callback"/>` no AndroidManifest.xml;
///  - iOS: CFBundleURLTypes com URLScheme `nofluxo` no Info.plist;
///  - Supabase: adicionar `nofluxo://auth-callback` em Auth > Redirect URLs.
const String kOAuthRedirectUri = 'nofluxo://auth-callback';

/// Gerencia sessão, perfil e modo visitante.
///
/// Segue o padrão do site (auth.service.ts): auth no Supabase + linha em
/// `public.users`, com o fluxograma em `dados_users.fluxograma_atual`.
class AuthNotifier extends AsyncNotifier<AuthState> {
  static const String _kVisitanteKey = 'nofluxo_modo_visitante';

  Timer? _retryPerfil;
  int _tentativaRetryPerfil = 0;

  @override
  Future<AuthState> build() async {
    escutarMudancasDeAuth();
    ref.onDispose(() => _retryPerfil?.cancel());

    if (temSessaoLocal) {
      try {
        final user = await buscarPerfilDaSessao();
        if (user != null) return AuthState.loggedIn(user);
        // Perfil realmente não existe (query ok, zero linhas): segue o
        // fluxo normal abaixo (visitante/loggedOut).
      } catch (e) {
        // Sessão local válida mas perfil inacessível (ex.: boot offline ou
        // banco fora do ar): NÃO derrubar para loggedOut — mantém o usuário
        // logado sem perfil e agenda retry até a rede voltar.
        debugPrint('Perfil inacessível no boot (mantendo sessão): $e');
        _agendarRetryDePerfil();
        return const AuthState.loggedInSemPerfil();
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kVisitanteKey) ?? false) {
      return const AuthState.anonymous();
    }
    return const AuthState.loggedOut();
  }

  // ── Seams protegidos (sobrescritos nos testes) ─────────────────────────────

  /// Há sessão Supabase persistida localmente?
  @protected
  bool get temSessaoLocal => SupabaseService.session != null;

  /// Registra o listener de onAuthStateChange (chamado uma vez por build).
  ///
  /// OAuth (e login por outras abas do SDK) completa de forma assíncrona via
  /// deep link — o evento signedIn é o ponto único de sincronização.
  @protected
  void escutarMudancasDeAuth() {
    final sub = SupabaseService.auth.onAuthStateChange.listen((data) {
      if (data.event == supa.AuthChangeEvent.signedIn) {
        unawaited(_sincronizarPerfilAposLogin());
      }
      if (data.event == supa.AuthChangeEvent.signedOut) {
        _retryPerfil?.cancel();
        state = const AsyncData(AuthState.loggedOut());
      }
    });
    ref.onDispose(sub.cancel);
  }

  /// Busca o perfil da sessão atual. Diferente de [_carregarPerfil], LANÇA a
  /// exceção em falha de rede/banco — retorna null apenas quando a query
  /// funcionou e o usuário de fato não tem linha em `users`.
  @protected
  Future<UserModel?> buscarPerfilDaSessao() async {
    final authUser = SupabaseService.currentAuthUser;
    if (authUser == null) return null;
    final data = await SupabaseService.client
        .from('users')
        .select('*, dados_users(*)')
        .eq('auth_id', authUser.id)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  /// Atraso antes da [tentativa]-ésima nova busca do perfil (backoff
  /// exponencial 5s→60s). Sobrescrito nos testes para Duration.zero.
  @protected
  Duration atrasoRetryPerfil(int tentativa) {
    final segundos = 5 * (1 << tentativa);
    return Duration(seconds: segundos > 60 ? 60 : segundos);
  }

  /// Reagenda a busca do perfil enquanto o estado for loggedIn sem perfil.
  void _agendarRetryDePerfil() {
    _retryPerfil?.cancel();
    final atraso = atrasoRetryPerfil(_tentativaRetryPerfil);
    _tentativaRetryPerfil++;
    _retryPerfil = Timer(atraso, () async {
      if (!temSessaoLocal) return;
      final estado = state.valueOrNull;
      if (estado == null || !estado.isLoggedIn || estado.user != null) return;
      try {
        final user = await buscarPerfilDaSessao();
        if (user != null) {
          _tentativaRetryPerfil = 0;
          state = AsyncData(AuthState.loggedIn(user));
          return;
        }
        // Query ok e sem linha: o perfil não existe mesmo → deslogado.
        state = const AsyncData(AuthState.loggedOut());
      } catch (_) {
        _agendarRetryDePerfil();
      }
    });
  }

  // ── Fluxos públicos ────────────────────────────────────────────────────────

  /// Login com email/senha. Retorna null em sucesso ou a mensagem de erro.
  Future<String?> loginComEmail(String email, String senha) async {
    try {
      final res = await SupabaseService.auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );
      if (res.user == null) return 'Email ou senha inválidos';

      final user = await _carregarPerfil();
      if (user == null) {
        return 'Usuário autenticado, mas não encontrado no banco de dados '
            'interno. Contate o suporte.';
      }

      await _limparModoVisitante();
      state = AsyncData(AuthState.loggedIn(user));
      return null;
    } on AuthException catch (e) {
      return _mensagemDeErroAuth(e);
    } catch (e) {
      return 'Erro inesperado ao entrar. Tente novamente.';
    }
  }

  /// Cria conta com email/senha + display_name e registra em `public.users`.
  /// Retorna null em sucesso ou a mensagem de erro.
  Future<String?> signup(String nome, String email, String senha) async {
    final nomeLimpo = nome.trim();
    final emailLimpo = email.trim();
    try {
      final res = await SupabaseService.auth.signUp(
        email: emailLimpo,
        password: senha,
        data: nomeLimpo.isNotEmpty ? {'display_name': nomeLimpo} : null,
      );
      if (res.user == null) {
        return 'Erro ao criar conta. Tente novamente.';
      }

      final user = await _registrarNoBanco(
        emailLimpo,
        nomeLimpo.isNotEmpty ? nomeLimpo : emailLimpo.split('@').first,
      );
      if (user == null) {
        // Rollback igual ao site: sem linha no banco, desfaz a sessão.
        await SupabaseService.auth.signOut();
        return 'Não foi possível criar sua conta. Tente novamente ou contate '
            'o suporte.';
      }

      await _limparModoVisitante();
      state = AsyncData(AuthState.loggedIn(user));
      return null;
    } on AuthException catch (e) {
      return _mensagemDeErroAuth(e);
    } catch (e) {
      return 'Erro inesperado ao criar conta. Tente novamente.';
    }
  }

  /// Inicia o fluxo Google OAuth (abre o navegador; o retorno chega via deep
  /// link e é tratado pelo listener de onAuthStateChange).
  Future<String?> loginComGoogle() async {
    try {
      await SupabaseService.auth.signInWithOAuth(
        supa.OAuthProvider.google,
        redirectTo: kOAuthRedirectUri,
        queryParams: const {'prompt': 'consent'},
      );
      return null;
    } on AuthException catch (e) {
      return _mensagemDeErroAuth(e);
    } catch (e) {
      return 'Não foi possível abrir o login do Google.';
    }
  }

  /// Ativa o modo visitante (não é sessão Supabase — só flag local).
  Future<void> entrarComoVisitante() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVisitanteKey, true);
    state = const AsyncData(AuthState.anonymous());
  }

  /// Encerra sessão e/ou modo visitante.
  Future<void> logout() async {
    // Remove o token de push ANTES do signOut — a RPC de remoção precisa da
    // sessão ainda válida. Centralizado aqui para nenhuma via de logout
    // (botões, sessão expirada, futuras) esquecer a ordem. No-op seguro sem
    // Firebase configurado.
    await ref.read(pushServiceProvider).unregister();
    try {
      await SupabaseService.auth.signOut();
    } catch (e) {
      // Limpa o estado local mesmo se o signOut remoto falhar.
      debugPrint('Erro no signOut: $e');
    }
    await _limparModoVisitante();
    state = const AsyncData(AuthState.loggedOut());
  }

  /// Envia email de recuperação de senha. Retorna null em sucesso.
  Future<String?> resetSenha(String email) async {
    try {
      await SupabaseService.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kOAuthRedirectUri,
      );
      return null;
    } on AuthException catch (e) {
      return _mensagemDeErroAuth(e);
    } catch (e) {
      return 'Não foi possível enviar o email de recuperação.';
    }
  }

  /// Recarrega o perfil do banco (ex.: depois de upload de histórico).
  Future<void> recarregarPerfil() async {
    if (SupabaseService.session == null) return;
    final user = await _carregarPerfil();
    if (user != null) {
      state = AsyncData(AuthState.loggedIn(user));
    }
  }

  // ── Internos ───────────────────────────────────────────────────────────────

  /// Busca `users` + `dados_users(*)` pelo auth_id da sessão atual.
  /// Engole exceções (retorna null) — quem precisa distinguir "não existe"
  /// de "falhou" usa [buscarPerfilDaSessao] direto (caso do build()).
  Future<UserModel?> _carregarPerfil() async {
    try {
      return await buscarPerfilDaSessao();
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
      return null;
    }
  }

  /// Insere a linha em `public.users`. Em conflito (23505 — usuário já
  /// existe), cai para a busca. Retorna null em falha.
  Future<UserModel?> _registrarNoBanco(String email, String nome) async {
    final authUser = SupabaseService.currentAuthUser;
    if (authUser == null) return null;
    try {
      await SupabaseService.client.from('users').insert({
        'email': email,
        'nome_completo': nome,
        'auth_id': authUser.id,
      });
      return _carregarPerfil();
    } on PostgrestException catch (e) {
      if (e.code == '23505') return _carregarPerfil();
      debugPrint('Erro ao registrar usuário: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Erro ao registrar usuário: $e');
      return null;
    }
  }

  /// Pós-login vindo do onAuthStateChange (OAuth). Busca o perfil; se for um
  /// usuário Google novo, registra no banco — mesmo fluxo do site.
  Future<void> _sincronizarPerfilAposLogin() async {
    // Só pula se JÁ estiver logado COM perfil carregado — o estado
    // loggedInSemPerfil (boot offline) precisa desta sincronização.
    final atual = state.valueOrNull;
    if ((atual?.isLoggedIn ?? false) && atual?.user != null) return;

    var user = await _carregarPerfil();
    if (user == null) {
      final authUser = SupabaseService.currentAuthUser;
      final email = authUser?.email;
      if (authUser == null || email == null) return;
      final meta = authUser.userMetadata ?? const {};
      final nome =
          (meta['name'] ?? meta['full_name'] ?? meta['display_name'])
              ?.toString() ??
          email.split('@').first;
      user = await _registrarNoBanco(email, nome);
    }

    if (user != null) {
      await _limparModoVisitante();
      state = AsyncData(AuthState.loggedIn(user));
    }
  }

  Future<void> _limparModoVisitante() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVisitanteKey);
  }

  String _mensagemDeErroAuth(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email ou senha inválidos';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Este email já está cadastrado';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu email antes de entrar';
    }
    if (msg.contains('password') && msg.contains('least')) {
      return 'A senha precisa ter pelo menos 6 caracteres';
    }
    return e.message;
  }
}

/// Estado global de autenticação.
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
