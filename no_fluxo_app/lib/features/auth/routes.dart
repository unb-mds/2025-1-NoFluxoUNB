import 'package:go_router/go_router.dart';

import 'ui/login_screen.dart';
import 'ui/signup_screen.dart';

/// Rotas de autenticação (fora do shell com bottom navigation).
final List<RouteBase> authRoutes = [
  GoRoute(
    path: '/login',
    name: 'login',
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: '/signup',
    name: 'signup',
    builder: (context, state) => const SignupScreen(),
  ),
];
