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

  // Função para obter dimensões responsivas
  static double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    if (screenWidth < 900) return 20.0; // Tablet
    return 24.0; // Desktop
  }

  static double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 6.0; // Mobile - reduzido de 8.0
    if (screenWidth < 900) return 8.0; // Tablet - reduzido de 12.0
    return 12.0; // Desktop - reduzido de 16.0
  }

  // Função pública e estática para gerar os links do menu
  static List<Widget> navLinks(BuildContext context, {bool isDrawer = false}) {
    final List<Widget> links = [];
    final responsiveSpacing = _getResponsiveSpacing(context);
    
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
        links.add(SizedBox(width: responsiveSpacing));
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
        links.add(SizedBox(width: responsiveSpacing));
        links.add(GradientUnderlineButton(
          onPressed: () {
            context.go('/fluxogramas');
          },
          text: 'FLUXOGRAMAS',
        ));
        if (!SharedPreferencesHelper.isAnonimo) {
          links.add(SizedBox(width: responsiveSpacing));
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
        links.add(SizedBox(width: responsiveSpacing * 1.2)); // Reduzido de 1.5
        links.add(GradientCTAButton(
          onPressed: () {
            context.go('/login');
          },
          text: 'ACESSE NOSSO SISTEMA',
        ));
      }
      if (SharedPreferencesHelper.currentUser != null) {
        links.add(SizedBox(width: responsiveSpacing));
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
    // Ajuste dinâmico de fonte e espaçamento
    double fontSize;
    double spacing;
    double paddingH;
    double paddingV;
    if (screenWidth > 1300) {
      fontSize = 22;
      spacing = 24; // Reduzido de 32
      paddingH = 32;
      paddingV = 12;
    } else if (screenWidth > 1100) {
      fontSize = 18;
      spacing = 16; // Reduzido de 20
      paddingH = 28;
      paddingV = 10;
    } else if (screenWidth > 900) {
      fontSize = 15;
      spacing = 10; // Reduzido de 12
      paddingH = 20;
      paddingV = 8;
    } else {
      // Mobile/tablet: menu hambúrguer
      fontSize = 15;
      spacing = 6; // Reduzido de 8
      paddingH = 16;
      paddingV = 6;
    }
    final isMobile = screenWidth < 800;
    final isDesktop = screenWidth >= 800;

    double logoFontSize;
    EdgeInsets logoPadding;
    if (screenWidth > 1300) {
      logoFontSize = 36;
      logoPadding = const EdgeInsets.only(left: 50.0);
    } else if (screenWidth > 1100) {
      logoFontSize = 30;
      logoPadding = const EdgeInsets.only(left: 30.0);
    } else if (screenWidth > 900) {
      logoFontSize = 24;
      logoPadding = const EdgeInsets.only(left: 16.0);
    } else {
      logoFontSize = 20;
      logoPadding = const EdgeInsets.only(left: 4.0);
    }

    return Stack(
      children: [
        GlassContainer(
          padding: EdgeInsets.symmetric(
            horizontal: paddingH, 
            vertical: paddingV
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo responsiva
              AppLogo(fontSize: logoFontSize, padding: logoPadding),
              if (isDesktop)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: AppNavbar.navLinks(context).map((w) {
                    if (w is GradientUnderlineButton) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing / 3), // Reduzido de spacing / 2
                        child: GradientUnderlineButton(
                          onPressed: w.onPressed,
                          text: w.text,
                          fontSize: fontSize,
                        ),
                      );
                    } else if (w is GradientCTAButton) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing / 3), // Reduzido de spacing / 2
                        child: GradientCTAButton(
                          onPressed: w.onPressed,
                          text: w.text,
                          fontSize: fontSize,
                        ),
                      );
                    } else if (w is SizedBox) {
                      return SizedBox(width: spacing);
                    } else {
                      return w;
                    }
                  }).toList(),
                )
              else
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu, 
                      color: Colors.white, 
                      size: 28
                    ),
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

// Drawer para navegação em mobile/tablet
class AppNavbarDrawer extends StatelessWidget {
  final List<Widget> links;
  const AppNavbarDrawer({required this.links, super.key});

  // Função para obter dimensões responsivas
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    if (screenWidth < 900) return 20.0; // Tablet
    return 24.0; // Desktop
  }

  double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 6.0; // Mobile - reduzido de 8.0
    if (screenWidth < 900) return 8.0; // Tablet - reduzido de 12.0
    return 12.0; // Desktop - reduzido de 16.0
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 20 : 24, 
            horizontal: responsivePadding
          ),
          children: links
              .map((w) => Padding(
                    padding: EdgeInsets.symmetric(vertical: responsiveSpacing / 2),
                    child: w,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
