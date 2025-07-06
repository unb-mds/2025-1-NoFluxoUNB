import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cache/shared_preferences_helper.dart';
import '../environment.dart';
import '../routes/app_router.dart';
import '../service/auth_service.dart';
import 'splash_widget.dart';

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
    if (widget.route == "/") {
      print(
          "Checking logged in, checking with google? ${widget.state.uri.queryParameters.containsKey("code")}");

      await AppRouter.checkLoggedIn(
        context,
        loggedInWithGoogle:
            widget.state.uri.queryParameters.containsKey("code"),
        onFoundUser: () {
          if (mounted) {
            context.go("/upload-historico");
          }
        },
        onUserNotFound: () {
          if (mounted) {
            context.go("/signup");
          }
        },
        backToLogin: () {
          if (mounted) {
            context.go("/login");
          }
        },
      );
    } else {
      await AppRouter.checkLoggedIn(
        context,
        onUserNotFound: () {
          if (mounted) {
            context.go("/signup");
          }
        },
      );
    }

    if (mounted) {
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
