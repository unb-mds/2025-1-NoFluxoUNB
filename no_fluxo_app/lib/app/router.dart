import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/auth_service.dart';
import '../features/auth/routes.dart';
import '../features/fluxograma/routes.dart';
import '../features/importar_historico/domain/redirect_importacao.dart';
import '../features/importar_historico/providers/importar_historico_controller.dart';
import '../features/importar_historico/routes.dart';
import '../features/grade/routes.dart';
import '../features/notificacoes/routes.dart';
import '../features/perfil/routes.dart';
import '../features/turmas/routes.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router do app.
///
/// Cada feature declara suas rotas em `lib/features/<feature>/routes.dart`
/// (exportando `List<RouteBase>`); aqui só se concatena. O redirect protege o
/// shell: sem sessão e sem modo visitante → /login.
final routerProvider = Provider<GoRouter>((ref) {
  // Reavalia o redirect sempre que o estado de auth muda.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authProvider, (_, next) {
    refresh.value++;
    // "Agora não" vale por sessão de login: o logout limpa o adiamento.
    if (next.valueOrNull?.status == AuthStatus.loggedOut) {
      ref.read(adiouImportacaoProvider.notifier).state = false;
    }
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/fluxograma',
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      // Sessão ainda resolvendo (boot do app): não redireciona.
      if (auth.isLoading) return null;

      final status = auth.valueOrNull?.status ?? AuthStatus.loggedOut;
      final emTelaDeAuth =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (status == AuthStatus.loggedOut) {
        return emTelaDeAuth ? null : '/login';
      }
      // Logado ou visitante não fica em tela de auth.
      if (emTelaDeAuth) return '/fluxograma';

      // Onboarding: logado sem fluxograma → importar histórico (a menos que
      // tenha adiado nesta sessão). Visitante nunca entra no onboarding.
      return redirectImportacaoDeHistorico(
        status: status,
        perfilCarregado: auth.valueOrNull?.user != null,
        temFluxograma: auth.valueOrNull?.dados != null,
        adiou: ref.read(adiouImportacaoProvider),
        location: state.matchedLocation,
      );
    },
    routes: [
      ...authRoutes,
      ...importarHistoricoRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: fluxogramaRoutes),
          StatefulShellBranch(routes: turmasRoutes),
          StatefulShellBranch(routes: gradeRoutes),
          StatefulShellBranch(routes: notificacoesRoutes),
          StatefulShellBranch(routes: perfilRoutes),
        ],
      ),
    ],
  );
});
