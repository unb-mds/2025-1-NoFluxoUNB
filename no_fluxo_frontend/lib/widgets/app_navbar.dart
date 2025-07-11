import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/cache/shared_preferences_helper.dart';
import 'package:mobile_app/routes/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/utils/utils.dart';
import 'gradient_underline_button.dart';
import 'gradient_cta_button.dart';
import 'app_logo.dart';
import 'glass_container.dart';

class AppNavbar extends StatefulWidget {
  final bool hideAcesseButton;
  final bool isFluxogramasPage;
  const AppNavbar(
      {super.key,
      this.hideAcesseButton = false,
      this.isFluxogramasPage = false});

  // Função pública e estática para gerar os links do menu
  static List<Widget> navLinks(BuildContext context, {bool isDrawer = false}) {
    final List<Widget> links = [];
    if (Utils.isCurrentRoute(context, '/upload-historico')) {
      if (SharedPreferencesHelper.currentUser != null) {
        links.add(GradientUnderlineButton(
          onPressed: () {
            SharedPreferencesHelper.currentUser = null;
            Supabase.instance.client.auth.signOut();
            context.go('/login');
          },
          text: 'SAIR',
        ));
      }
    } else {
      links.add(GradientUnderlineButton(
        onPressed: () {
          context.go('/');
        },
        text: 'HOME',
      ));
      if (SharedPreferencesHelper.currentUser != null) {
        links.add(const SizedBox(width: 16));
        links.add(GradientUnderlineButton(
          onPressed: () {
            if (SharedPreferencesHelper.currentUser!.dadosFluxograma != null) {
              context.go('/meu-fluxograma');
            } else {
              context.go('/upload-historico');
            }
          },
          text: 'MEUS FLUXOGRAMAS',
        ));
      }
      if (!Utils.isPublicRoute(context) &&
          !Utils.routeStartsWith(context, '/fluxogramas')) {
        links.add(const SizedBox(width: 16));
        links.add(GradientUnderlineButton(
          onPressed: () {
            context.go('/fluxogramas');
          },
          text: 'FLUXOGRAMAS',
        ));
        if (!SharedPreferencesHelper.isAnonimo) {
          links.add(const SizedBox(width: 16));
          links.add(GradientUnderlineButton(
            onPressed: () {
              context.go('/assistente');
            },
            text: 'ASSISTENTE',
          ));
        }
      }
      if ((Utils.isHomeRoute(context) &&
              SharedPreferencesHelper.currentUser == null) ||
          SharedPreferencesHelper.isAnonimo) {
        links.add(const SizedBox(width: 24));
        links.add(GradientCTAButton(
          onPressed: () {
            context.go('/login');
          },
          text: 'ACESSE NOSSO SISTEMA',
        ));
      }
      if (SharedPreferencesHelper.currentUser != null) {
        links.add(const SizedBox(width: 16));
        links.add(GradientUnderlineButton(
          onPressed: () {
            SharedPreferencesHelper.currentUser = null;
            Supabase.instance.client.auth.signOut();
            context.go('/login');
          },
          text: 'SAIR',
        ));
      }
    }
    if (isDrawer) {
      // Remove espaçamentos extras no Drawer
      return links.where((w) => w is! SizedBox).toList();
    }
    return links;
  }

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  void _openDrawer() {
    Scaffold.of(context).openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    return Stack(
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Título/Logo à esquerda com padding
              const AppLogo(),
              // Responsividade: menu hambúrguer em telas pequenas
              if (!isMobile)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: AppNavbar.navLinks(context),
                )
              else
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                    onPressed: _openDrawer,
                  ),
                ),
            ],
          ),
        ),
        if (isMobile)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topRight,
              child: Builder(
                builder: (context) => SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

// Drawer para navegação em mobile
class AppNavbarDrawer extends StatelessWidget {
  final List<Widget> links;
  const AppNavbarDrawer({required this.links, super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          children: links
              .map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: w,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
