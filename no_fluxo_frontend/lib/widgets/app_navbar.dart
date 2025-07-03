import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/cache/shared_preferences_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../screens/home_screen.dart';
import '../screens/auth/auth_page.dart';
import 'dart:ui';

class AppNavbar extends StatefulWidget {
  final bool hideAcesseButton;
  const AppNavbar({super.key, this.hideAcesseButton = false});

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  bool _isHoveringHome = false;
  bool _isHoveringAbout = false;
  bool _isHoveringAcesso = false;
  bool _isHoveringLogout = false;

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
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHoveringHome = true),
                    onExit: (_) => setState(() => _isHoveringHome = false),
                    child: AnimatedScale(
                      scale: _isHoveringHome ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: TextButton(
                        onPressed: () {
                          context.go('/');
                        },
                        child: Text(
                          'HOME',
                          style: GoogleFonts.permanentMarker(
                            fontSize: 19,
                            color: _isHoveringHome
                                ? AppColors.primary
                                : AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHoveringAbout = true),
                    onExit: (_) => setState(() => _isHoveringAbout = false),
                    child: AnimatedScale(
                      scale: _isHoveringAbout ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implementar navegação para a tela Sobre Nós
                        },
                        child: Text(
                          'SOBRE NÓS',
                          style: GoogleFonts.permanentMarker(
                            fontSize: 19,
                            color: _isHoveringAbout
                                ? AppColors.primary
                                : AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (GoRouterState.of(context).uri.path == "/" ||
                      GoRouterState.of(context).uri.path == "/home") ...[
                    const SizedBox(width: 24),
                    MouseRegion(
                      onEnter: (_) => setState(() => _isHoveringAcesso = true),
                      onExit: (_) => setState(() => _isHoveringAcesso = false),
                      child: AnimatedScale(
                        scale: _isHoveringAcesso ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: ElevatedButton(
                          onPressed: () {
                            if (SharedPreferencesHelper.currentUser != null) {
                              context.go('/upload-historico');
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
                        ),
                      ),
                    ),
                  ],
                  if (SharedPreferencesHelper.currentUser != null &&
                      GoRouterState.of(context).uri.path != "/home" &&
                      GoRouterState.of(context).uri.path != "/") ...[
                    const SizedBox(width: 16),
                    MouseRegion(
                        onEnter: (_) =>
                            setState(() => _isHoveringLogout = true),
                        onExit: (_) =>
                            setState(() => _isHoveringLogout = false),
                        child: AnimatedScale(
                          scale: _isHoveringLogout ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: TextButton(
                            onPressed: () {
                              SharedPreferencesHelper.currentUser = null;
                              Supabase.instance.client.auth.signOut();
                              context.go('/login');
                            },
                            child: Text(
                              'SAIR',
                              style: GoogleFonts.permanentMarker(
                                fontSize: 19,
                                color: _isHoveringLogout
                                    ? AppColors.primary
                                    : AppColors.white,
                              ),
                            ),
                          ),
                        ))
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
