import 'package:go_router/go_router.dart';

import 'ui/turmas_screen.dart';

/// Rotas da aba Turmas (busca de turmas, vagas ao vivo e alertas de vaga).
///
/// Aceita `?codigo=CIC0004` para chegar com a busca pré-preenchida
/// (ex.: deep link vindo do fluxograma).
final List<RouteBase> turmasRoutes = [
  GoRoute(
    path: '/turmas',
    name: 'turmas',
    builder: (context, state) =>
        TurmasScreen(codigoInicial: state.uri.queryParameters['codigo']),
  ),
];
