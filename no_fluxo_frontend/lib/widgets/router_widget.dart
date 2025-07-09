import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cache/shared_preferences_helper.dart';
import '../environment.dart';
import '../routes/app_router.dart';
import '../service/auth_service.dart';
import 'splash_widget.dart';

final log = Environment.getLogger('RouterWidget');

class RouterWidget extends StatefulWidget {
  final String route;
  final GoRouterState state;
  const RouterWidget({super.key, required this.route, required this.state});

  @override
  State<RouterWidget> createState() => _RouterWidgetState();
}

class _RouterWidgetState extends State<RouterWidget> {
  bool loading = true;
  bool _initialized = false;

  Future<void> _checkAuth() async {
    final route = widget.route;
    final hasGoogleCode = widget.state.uri.queryParameters.containsKey("code");

    log.info('🔐 Starting auth check for route: $route');

    if (route == "/") {
      log.info(
          '🏠 Home route detected - checking Google login: $hasGoogleCode');

      await AppRouter.checkLoggedIn(
        context,
        loggedInWithGoogle: hasGoogleCode,
        onFoundUser: () {
          if (mounted) {
            final targetRoute = SharedPreferencesHelper.isAnonimo
                ? "/fluxogramas"
                : "/upload-historico";
            log.info(
                '👤 User found - redirecting to: $targetRoute (anonymous: ${SharedPreferencesHelper.isAnonimo})');
            context.go(targetRoute);
          }
        },
        onUserNotFound: () {
          if (mounted) {
            log.info('❌ User not found - redirecting to signup');
            context.go("/signup");
          }
        },
        backToLogin: () {
          if (mounted) {
            log.info('🔙 Auth failed - redirecting to login');
            context.go("/login");
          }
        },
      );
    } else {
      log.info('🔒 Protected route - checking authentication');
      await AppRouter.checkLoggedIn(
        context,
        onUserNotFound: () {
          if (mounted) {
            log.warning(
                '❌ User not found for protected route - redirecting to signup');
            context.go("/signup");
          }
        },
      );
    }

    if (mounted) {
      log.info('✅ Auth check completed for route: $route');
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _checkAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const SplashWidget()
        : Scaffold(body: Builder(
            builder: (context) {
              return AppRouter.routes[widget.route]!
                  .call(context, widget.state);
            },
          ));
  }
}
