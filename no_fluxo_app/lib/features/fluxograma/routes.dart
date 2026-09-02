import 'package:go_router/go_router.dart';

import 'ui/fluxograma_screen.dart';

/// Rotas da aba Fluxograma.
final List<RouteBase> fluxogramaRoutes = [
  GoRoute(
    path: '/fluxograma',
    name: 'fluxograma',
    builder: (context, state) => const FluxogramaScreen(),
  ),
];
