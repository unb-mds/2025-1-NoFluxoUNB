import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cache/shared_preferences_helper.dart';
import '../environment.dart';
import '../routes/app_router.dart';
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      () async {
        if (widget.route == "/") {
          print(
              "Checking logged in, checking with google? ${widget.state.uri.queryParameters.containsKey("code")}");

          await AppRouter.checkLoggedIn(
            // ignore: use_build_context_synchronously
            context,
            loggedInWithGoogle:
                widget.state.uri.queryParameters.containsKey("code"),
            onFoundUser: () => context.go("/upload-historico"),
            onUserNotFound: () => context.go("/signup"),
            backToLogin: () => context.go("/login"),
          );
        } else {
          await AppRouter.checkLoggedIn(
            // ignore: use_build_context_synchronously
            context,
            onUserNotFound: () => context.go("/signup"),
          );
        }
        setState(() {
          loading = false;
        });
      }();
    });
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
