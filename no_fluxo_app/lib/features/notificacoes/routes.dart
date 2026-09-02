import 'package:go_router/go_router.dart';

import 'ui/notificacoes_screen.dart';

/// Rotas da aba Notificações.
final List<RouteBase> notificacoesRoutes = [
  GoRoute(
    path: '/notificacoes',
    name: 'notificacoes',
    builder: (context, state) => const NotificacoesScreen(),
  ),
];
