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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AppNavbarDrawer(
          links: AppNavbar.navLinks(this.context, isDrawer: true),
          onNavigate: _handleNavigation,
          animation: animation,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0), // Começa fora da tela à direita
            end: Offset.zero, // Termina na posição normal
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  void _handleNavigation(String text) {
    switch (text.toUpperCase()) {
      case 'HOME':
        context.go('/');
        break;
      case 'MEUS FLUXOGRAMAS':
        if (SharedPreferencesHelper.currentUser != null) {
          if (SharedPreferencesHelper.currentUser!.dadosFluxograma != null) {
            context.go('/meu-fluxograma');
          } else {
            context.go('/upload-historico');
          }
        }
        break;
      case 'FLUXOGRAMAS':
        context.go('/fluxogramas');
        break;
      case 'ASSISTENTE':
        context.go('/assistente');
        break;
      case 'ACESSE NOSSO SISTEMA':
        context.go('/login');
        break;
      case 'SAIR':
        SharedPreferencesHelper.currentUser = null;
        Supabase.instance.client.auth.signOut();
        context.go('/login');
        break;
    }
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

// Drawer lateral para navegação em mobile/tablet
class AppNavbarDrawer extends StatelessWidget {
  final List<Widget> links;
  final Function(String)? onNavigate;
  final Animation<double>? animation;
  const AppNavbarDrawer({required this.links, this.onNavigate, this.animation, super.key});

  // Função para obter dimensões responsivas
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 20.0; // Mobile
    if (screenWidth < 900) return 24.0; // Tablet
    return 28.0; // Desktop
  }

  double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 8.0; // Mobile
    if (screenWidth < 900) return 12.0; // Tablet
    return 16.0; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    
    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    // Largura do drawer baseada no tamanho da tela
    double drawerWidth;
    if (isMobile) {
      drawerWidth = screenWidth * 0.85; // 85% da tela em mobile
    } else if (isTablet) {
      drawerWidth = 350; // Largura fixa em tablet
    } else {
      drawerWidth = 400; // Largura fixa em desktop
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        child: Container(
          width: drawerWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A1A).withOpacity(0.98),
                Colors.black.withOpacity(0.96),
              ],
            ),
            border: Border(
              left: BorderSide(
                color: Color(0xFF7B2FF2).withOpacity(0.3),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: Offset(-8, 0),
              ),
              BoxShadow(
                color: Color(0xFF7B2FF2).withOpacity(0.1),
                blurRadius: 40,
                offset: Offset(-12, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header com gradiente
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: responsivePadding,
                    vertical: isMobile ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF7B2FF2).withOpacity(0.2),
                        Color(0xFFF357A8).withOpacity(0.1),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF7B2FF2),
                                  Color(0xFFF357A8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: isMobile ? 18 : 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Menu de Navegação',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: isMobile ? 20 : 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                
                // Links com scroll
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      vertical: responsiveSpacing,
                      horizontal: responsivePadding,
                    ),
                    children: links
                        .map((w) => Container(
                              margin: EdgeInsets.symmetric(vertical: responsiveSpacing / 2),
                              child: _buildDrawerItem(w, context),
                            ))
                        .toList(),
                  ),
                ),
                
                // Footer com informação
                Container(
                  padding: EdgeInsets.all(responsivePadding),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    'NoFluxoUNB © 2025',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: isMobile ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(Widget widget, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    
    if (widget is GradientUnderlineButton) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop(); // Fecha o drawer
              // Usa Future.delayed para garantir que o drawer seja fechado antes da navegação
              Future.delayed(Duration(milliseconds: 200), () {
                // Executa a navegação via callback
                if (onNavigate != null) {
                  onNavigate!(widget.text);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 16 : 18,
                horizontal: isMobile ? 16 : 20,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForText(widget.text),
                      color: Colors.white.withOpacity(0.9),
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.4),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (widget is GradientCTAButton) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7B2FF2),
              Color(0xFFF357A8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF7B2FF2).withOpacity(0.4),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop(); // Fecha o drawer
              // Usa Future.delayed para garantir que o drawer seja fechado antes da navegação
              Future.delayed(Duration(milliseconds: 200), () {
                // Executa a navegação via callback
                if (onNavigate != null) {
                  onNavigate!(widget.text);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 18 : 20,
                horizontal: isMobile ? 16 : 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.login,
                      color: Colors.white,
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget;
  }



  IconData _getIconForText(String text) {
    switch (text.toUpperCase()) {
      case 'HOME':
        return Icons.home_outlined;
      case 'MEUS FLUXOGRAMAS':
        return Icons.account_tree_outlined;
      case 'FLUXOGRAMAS':
        return Icons.schema_outlined;
      case 'ASSISTENTE':
        return Icons.smart_toy_outlined;
      case 'SAIR':
        return Icons.logout_outlined;
      default:
        return Icons.arrow_forward_ios;
    }
  }
}
