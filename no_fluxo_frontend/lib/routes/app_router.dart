import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:mobile_app/widgets/router_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/shared_preferences_helper.dart';
import '../environment.dart';
import '../screens/auth/anonymous_login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/assistente/assistente_screen.dart';
import '../screens/auth/auth_page.dart';
import '../screens/auth/password_recovery_screen.dart';
import '../screens/upload-historico/presentation/upload_historico_screen.dart';
import '../screens/fluxogramas/presentation/pages/fluxogramas_index_screen.dart';
import '../screens/fluxogramas/presentation/pages/meu_fluxograma_screen.dart';
import '../service/auth_service.dart';

final log = Environment.getLogger('AppRouter');

class AppRouter {
  static final List<String> routesThatNeedNoLogin = [
    '/',
    "",
    "/login",
    "/signup",
    "/password-recovery",
    "/home",
    "/login-anonimo"
  ];

  static Future<Session?> safeGetSession() async {
    final supabase = Supabase.instance.client;

    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        await supabase.auth.signOut(); // ⚠️ limpa tokens inválidos
        return null;
      }

      // Check if session is expired
      if (session.expiresAt != null &&
          DateTime.now().isAfter(
              DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000))) {
        await supabase.auth.signOut();
        return null;
      }

      return session;
    } catch (e) {
      await supabase.auth.signOut();
      return null;
    }
  }

  static Future<bool> checkWhenUserLogged(BuildContext context) async {
    final currentRoute = GoRouterState.of(context).uri.path;

    // If we're already on a public route, no need to redirect
    if (routesThatNeedNoLogin.contains(currentRoute)) {
      return true;
    }

    // Check if we have a valid session and user data
    final session = await safeGetSession();
    if (session == null || SharedPreferencesHelper.currentUser == null) {
      // ignore: use_build_context_synchronously
      context.go("/login");
      return false;
    }

    return true;
  }

  static Future<void> checkLoggedIn(
    BuildContext context, {
    bool loggedInWithGoogle = false,
    VoidCallback? onFoundUser,
    VoidCallback? onUserNotFound,
    VoidCallback? backToLogin,
  }) async {
    var route = GoRouterState.of(context).uri.path;

    if (routesThatNeedNoLogin.contains(route) && !loggedInWithGoogle) {
      return;
    }

    try {
      /// 1. Recupera sessão de forma segura
      final session = await safeGetSession();
      final email = session?.user.email;

      if (SharedPreferencesHelper.isAnonimo && !loggedInWithGoogle) {
        onFoundUser?.call();
        return;
      }

      if (email == null) {
        // não logado
        backToLogin?.call();
        return;
      }

      /// 2. Busca o usuário no banco
      final result = await AuthService.databaseSearchUser(email);

      await result.fold(
        (error) async {
          if (loggedInWithGoogle) {
            final resultRegister =
                await AuthService.databaseRegisterUserWhenLoggedInWithGoogle(
                    email,
                    Supabase.instance.client.auth.currentUser
                            ?.userMetadata?["name"] ??
                        "");

            resultRegister.fold(
              (error) {
                log.severe(error);
              },
              (userFromDb) {
                SharedPreferencesHelper.currentUser = userFromDb;
              },
            );

            if (resultRegister.isRight()) {
              onFoundUser?.call();
              return;
            } else {
              onUserNotFound?.call();
              return;
            }
          }

          onUserNotFound?.call();
        },
        (userFromDb) async {
          /// 3. Grava em SharedPreferences com segurança de nulos
          SharedPreferencesHelper.currentUser = userFromDb;

          onFoundUser?.call();

          if (onFoundUser == null) {
            // fluxo normal
            checkWhenUserLogged(context);
          }
        },
      );
    } catch (e, st) {
      log.severe(e, st);
      await Supabase.instance.client.auth.signOut();
      backToLogin?.call();
    }
  }

  static Map<String, Widget Function(BuildContext, GoRouterState)> routes = {
    '/home': (context, state) => const HomeScreen(),
    '/': (context, state) => const HomeScreen(),
    '/assistente': (context, state) => const AssistenteScreen(),
    '/upload-historico': (context, state) => const UploadHistoricoScreen(),
    '/login': (context, state) => const AuthPage(isLogin: true),
    '/signup': (context, state) => const AuthPage(isLogin: false),
    '/password-recovery': (context, state) => const PasswordRecoveryScreen(),
    '/fluxogramas': (context, state) => const FluxogramasIndexScreen(),
    '/meu-fluxograma': (context, state) => const MeuFluxogramaScreen(),
    '/meu-fluxograma/:courseName': (context, state) {
      final courseName = state.pathParameters['courseName'] ?? '';
      return MeuFluxogramaScreen(courseName: courseName);
    },
    '/login-anonimo': (context, state) => const AnonymousLoginScreen(),
  };

  static GoRouter? router;

  static GoRouter getRouter() {
    router ??= GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      redirect: (BuildContext context, GoRouterState state) async {
        final currentPath = state.uri.path;
        final queryParams =
            state.uri.queryParameters.isNotEmpty ? '?${state.uri.query}' : '';

        log.info('🧭 Navigation attempt to: $currentPath$queryParams');

        // Don't redirect for routes that don't need login
        if (routesThatNeedNoLogin.contains(currentPath)) {
          log.info('✅ Route $currentPath does not require authentication');
          return null;
        }

        // Check session

        return null;
      },
      routes: routes.entries.map((entry) {
        return GoRoute(
          path: entry.key,
          name: entry.key,
          pageBuilder: (context, state) {
            final fullPath = state.uri.toString();
            final pathParams = state.pathParameters.isNotEmpty
                ? ' (params: ${state.pathParameters})'
                : '';
            final queryParams = state.uri.queryParameters.isNotEmpty
                ? ' (query: ${state.uri.queryParameters})'
                : '';

            log.info(
                '📱 Building page for route: ${entry.key}$pathParams$queryParams');
            log.fine('🔗 Full URI: $fullPath');

            return NoTransitionPage(
                key: UniqueKey(),
                child: RouterWidget(route: entry.key, state: state));
          },
        );
      }).toList(),
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Página não encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'A página ${state.uri.path} não existe.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );

    return router!;
  }
}

// Placeholder para a página de fluxograma individual
class FluxogramasPlaceholder extends StatelessWidget {
  const FluxogramasPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Fluxograma'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 64,
              color: Colors.purple,
            ),
            SizedBox(height: 16),
            Text(
              'Seu Fluxograma',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aqui aparecerá o seu fluxograma personalizado após importar o histórico!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
