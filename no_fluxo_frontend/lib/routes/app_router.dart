import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/assistente/assistente_screen.dart';
import '../screens/auth/auth_page.dart';
import '../screens/auth/login_form.dart';
import '../screens/auth/signup_form.dart';
import '../screens/auth/password_recovery_screen.dart';
import '../screens/upload_historico_screen.dart';
import '../screens/fluxogramas/fluxos_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Home Route
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          print('🔵 Navegando para HOME: ${state.uri.path}');
          return const HomeScreen();
        },
      ),

      // Assistente Route
      GoRoute(
        path: '/assistente',
        name: 'assistente',
        builder: (context, state) {
          print('🟢 Navegando para ASSISTENTE: ${state.uri.path}');
          return const AssistenteScreen();
        },
      ),

      // Auth Routes
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),

      GoRoute(
        path: '/auth/upload',
        name: 'auth-upload',
        builder: (context, state) {
          print(
              '📁 Navegando para UPLOAD HISTÓRICO: [36m[1m[4m${state.uri.path}[0m');
          return const UploadHistoricoScreen();
        },
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => LoginForm(
          onToggleView: () => context.go('/signup'),
        ),
      ),

      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => SignupForm(
          onToggleView: () => context.go('/login'),
        ),
      ),

      GoRoute(
        path: '/password-recovery',
        name: 'password-recovery',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),

      // Fluxogramas Route (placeholder - será implementada depois)
      GoRoute(
        path: '/fluxogramas',
        name: 'fluxogramas',
        builder: (context, state) => const FluxogramasIndexScreen(),
      ),

      GoRoute(
        path: '/meu-fluxograma',
        name: 'meu-fluxograma',
        builder: (context, state) => const FluxogramasPlaceholder(),
      ),
    ],

    // Error handling
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
