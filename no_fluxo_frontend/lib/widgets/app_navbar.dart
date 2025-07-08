import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/cache/shared_preferences_helper.dart';
import 'package:mobile_app/routes/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../screens/home_screen.dart';
import '../screens/auth/auth_page.dart';
import 'dart:ui';

class AppNavbar extends StatefulWidget {
  final bool hideAcesseButton;
  final bool isFluxogramasPage;
  const AppNavbar(
      {super.key,
      this.hideAcesseButton = false,
      this.isFluxogramasPage = false});

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  bool _isHoveringHome = false;
  bool _isHoveringAbout = false;
  bool _isHoveringAcesso = false;
  bool _isHoveringAcesseNossoSistema = false;
  bool _isHoveringLogout = false;
  bool _isHoveringFluxogramas = false;
  bool _isHoveringAssistente = false;
  bool _isHoveringMeusFluxogramas = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: 4.0, sigmaY: 4.0), // Blur para o efeito de vidro
        child: Container(
          color: Colors.black.withOpacity(0.3), // Vidro translúcido
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Título/Logo à esquerda com padding
              Padding(
                padding: const EdgeInsets.only(left: 50.0),
                child: Text(
                  'NOFLX UNB',
                  style: GoogleFonts.permanentMarker(
                    fontSize: 36,
                    color: AppColors.white,
                    shadows: [
                      const Shadow(
                        color: Color.fromARGB(77, 0, 0, 0),
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Links de navegação e botão agrupados à direita
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NavItem(
                    isHovered: _isHoveringHome,
                    onPressed: () {
                      context.go('/');
                    },
                    text: 'HOME',
                    onEnter: () => setState(() => _isHoveringHome = true),
                    onExit: () => setState(() => _isHoveringHome = false),
                  ),
                  const SizedBox(width: 16),
                  NavItem(
                    isHovered: _isHoveringAbout,
                    onPressed: () {
                      // TODO: Implementar navegação para a tela Sobre Nós
                    },
                    text: 'SOBRE NÓS',
                    onEnter: () => setState(() => _isHoveringAbout = true),
                    onExit: () => setState(() => _isHoveringAbout = false),
                  ),
                  // Botão "MEUS FLUXOGRAMAS" só aparece quando:
                  // 1. Usuário está logado
                  // 2. Usuário já fez upload do fluxograma (dadosFluxograma != null)
                  if (SharedPreferencesHelper.currentUser != null &&
                      SharedPreferencesHelper.currentUser!.dadosFluxograma !=
                          null) ...[
                    const SizedBox(width: 16),
                    NavItem(
                      isHovered: _isHoveringMeusFluxogramas,
                      onPressed: () {
                        context.go('/meu-fluxograma');
                      },
                      text: 'MEUS FLUXOGRAMAS',
                      onEnter: () =>
                          setState(() => _isHoveringMeusFluxogramas = true),
                      onExit: () =>
                          setState(() => _isHoveringMeusFluxogramas = false),
                    ),
                  ],
                  // Botões FLUXOGRAMAS e ASSISTENTE aparecem quando não está nas rotas de login/cadastro
                  if (!AppRouter.routesThatNeedNoLogin
                      .contains(GoRouterState.of(context).uri.path)) ...[
                    const SizedBox(width: 16),
                    NavItem(
                      isHovered: _isHoveringFluxogramas,
                      onPressed: () {
                        context.go('/fluxogramas');
                      },
                      text: 'FLUXOGRAMAS',
                      onEnter: () =>
                          setState(() => _isHoveringFluxogramas = true),
                      onExit: () =>
                          setState(() => _isHoveringFluxogramas = false),
                    ),
                    const SizedBox(width: 16),
                    NavItem(
                      isHovered: _isHoveringAssistente,
                      onPressed: () {
                        context.go('/assistente');
                      },
                      text: 'ASSISTENTE',
                      onEnter: () =>
                          setState(() => _isHoveringAssistente = true),
                      onExit: () =>
                          setState(() => _isHoveringAssistente = false),
                    ),
                  ],
                  if (GoRouterState.of(context).uri.path == "/" ||
                      GoRouterState.of(context).uri.path == "/home") ...[
                    const SizedBox(width: 24),
                    MouseRegion(
                        onEnter: (_) => setState(
                            () => _isHoveringAcesseNossoSistema = true),
                        onExit: (_) => setState(
                            () => _isHoveringAcesseNossoSistema = false),
                        child: AnimatedScale(
                            scale: _isHoveringAcesseNossoSistema ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: TextButton(
                              onPressed: () {
                                if (SharedPreferencesHelper.currentUser !=
                                    null) {
                                  if (SharedPreferencesHelper
                                          .currentUser!.dadosFluxograma ==
                                      null) {
                                    context.go('/upload-historico');
                                  } else {
                                    context.go('/meu-fluxograma');
                                  }
                                } else {
                                  context.go('/login');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0)),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.purple, AppColors.pink],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 260.0, minHeight: 40.0),
                                alignment: Alignment.center,
                                child: Text(
                                  'ACESSE NOSSO SISTEMA',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.permanentMarker(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ))),
                  ],
                  if (SharedPreferencesHelper.currentUser != null &&
                      GoRouterState.of(context).uri.path != "/home" &&
                      GoRouterState.of(context).uri.path != "/") ...[
                    const SizedBox(width: 16),
                    NavItem(
                      isHovered: _isHoveringLogout,
                      onPressed: () {
                        SharedPreferencesHelper.currentUser = null;
                        Supabase.instance.client.auth.signOut();
                        context.go('/login');
                      },
                      text: 'SAIR',
                      onEnter: () => setState(() => _isHoveringLogout = true),
                      onExit: () => setState(() => _isHoveringLogout = false),
                    )
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem extends StatefulWidget {
  final bool isHovered;
  final VoidCallback onPressed;
  final String text;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const NavItem({
    Key? key,
    required this.isHovered,
    required this.onPressed,
    required this.text,
    required this.onEnter,
    required this.onExit,
  }) : super(key: key);

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  final GlobalKey _textKey = GlobalKey();
  double _textWidth = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTextWidth();
    });
  }

  void _updateTextWidth() {
    final RenderBox? renderBox =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _textWidth = renderBox.size.width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onEnter(),
      onExit: (_) => widget.onExit(),
      child: Stack(
        children: [
          TextButton(
            key: _textKey,
            onPressed: widget.onPressed,
            child: Text(
              widget.text,
              style: GoogleFonts.permanentMarker(
                fontSize: 19,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 2,
              width: widget.isHovered ? _textWidth : 0.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.purple,
                    AppColors.pink,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
