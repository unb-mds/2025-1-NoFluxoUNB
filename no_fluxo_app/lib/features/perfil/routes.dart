import 'package:go_router/go_router.dart';

import 'ui/perfil_screen.dart';

/// Rotas da aba Perfil.
final List<RouteBase> perfilRoutes = [
  GoRoute(
    path: '/perfil',
    name: 'perfil',
    builder: (context, state) => const PerfilScreen(),
  ),
];
