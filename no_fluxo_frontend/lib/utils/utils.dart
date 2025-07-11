import 'package:flutter/material.dart';
import 'package:mobile_app/config/size_config.dart';
import 'package:mobile_app/config/app_colors.dart';
import 'package:go_router/go_router.dart';

class Pair<T, U> {
  final T first;
  final U second;

  Pair(this.first, this.second);
}


class Utils {

  

  static Future<void> showCustomizedDialog(
      {required BuildContext context,
      required Widget child,
      bool barrierDismissible = true}) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return Dialog(
          elevation: 5,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.dialogBackground,
              border:
                  Border.all(color: AppColors.white.withOpacity(0.1), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: BoxConstraints(
              maxWidth: getProportionateScreenWidth(500),
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              minHeight: getProportionateScreenHeight(300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // ======================== ROUTER UTILS ========================
  
  /// Retorna a rota atual baseada no contexto
  static String getCurrentRoute(BuildContext context) {
    return GoRouterState.of(context).uri.path;
  }

  /// Verifica se está na rota especificada
  static bool isCurrentRoute(BuildContext context, String route) {
    return getCurrentRoute(context) == route;
  }

  /// Verifica se está em uma das rotas especificadas
  static bool isCurrentRouteOneOf(BuildContext context, List<String> routes) {
    final currentRoute = getCurrentRoute(context);
    return routes.contains(currentRoute);
  }

  /// Verifica se está na rota home (/ ou /home)
  static bool isHomeRoute(BuildContext context) {
    return isCurrentRouteOneOf(context, ["/", "/home"]);
  }

  /// Verifica se está em uma rota de autenticação
  static bool isAuthRoute(BuildContext context) {
    return isCurrentRouteOneOf(context, ["/login", "/signup", "/password-recovery", "/login-anonimo"]);
  }

  /// Verifica se está em uma rota que não precisa de login
  static bool isPublicRoute(BuildContext context) {
    const publicRoutes = [
      '/',
      "",
      "/login",
      "/signup", 
      "/password-recovery",
      "/home",
      "/login-anonimo"
    ];
    return isCurrentRouteOneOf(context, publicRoutes);
  }

  /// Retorna os parâmetros da rota atual
  static Map<String, String> getCurrentRouteParams(BuildContext context) {
    return GoRouterState.of(context).pathParameters;
  }

  /// Retorna os query parameters da rota atual
  static Map<String, String> getCurrentRouteQuery(BuildContext context) {
    return GoRouterState.of(context).uri.queryParameters;
  }

  /// Verifica se a rota atual começa com um determinado prefixo
  static bool routeStartsWith(BuildContext context, String prefix) {
    return getCurrentRoute(context).startsWith(prefix);
  }
}
