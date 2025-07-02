import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class AppNavbar extends StatefulWidget {
  const AppNavbar({super.key});

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  bool _isHoveringHome = false;
  bool _isHoveringAbout = false;
  bool _isHoveringAcesso = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black
          .withOpacity(0.5), // Cor de fundo semi-transparente para a navbar
      padding: const EdgeInsets.symmetric(
          horizontal: 24.0, vertical: 8.0), // Aumenta o padding vertical
      child: Row(
        mainAxisAlignment: MainAxisAlignment
            .spaceBetween, // Mantém espaço entre a esquerda e a direita
        children: [
          // Título/Logo à esquerda com padding
          Padding(
            padding: const EdgeInsets.only(
                left: 50.0), // Aumenta o padding à esquerda
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Text(
                'NOFLX UNB',
                style: GoogleFonts.permanentMarker(
                  fontSize: 36, // Tamanho da fonte do título
                  color: AppColors.white,
                  shadows: [
                    const Shadow(
                      color: Color.fromARGB(77, 0, 0,
                          0), // Mantido Color.fromARGB para consistência
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Links de navegação e botão agrupados à direita
          Row(
            mainAxisSize:
                MainAxisSize.min, // Ocupa o mínimo de espaço horizontal
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringHome = true),
                onExit: (_) => setState(() => _isHoveringHome = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: AnimatedScale(
                    scale: _isHoveringHome ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'HOME',
                            style: GoogleFonts.permanentMarker(
                              fontSize: 19,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                          height: 2,
                          width: _isHoveringHome
                              ? 48
                              : 0, // Ajuste para o tamanho do texto
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A1D96), Color(0xFFE11D48)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringAbout = true),
                onExit: (_) => setState(() => _isHoveringAbout = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/#sobre'),
                  child: AnimatedScale(
                    scale: _isHoveringAbout ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'SOBRE NÓS',
                            style: GoogleFonts.permanentMarker(
                              fontSize: 19,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                          height: 2,
                          width: _isHoveringAbout
                              ? 80
                              : 0, // Ajuste para o tamanho do texto
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A1D96), Color(0xFFE11D48)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveringAcesso = true),
                onExit: (_) => setState(() => _isHoveringAcesso = false),
                child: AnimatedScale(
                  scale: _isHoveringAcesso ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/auth');
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
          ),
        ],
      ),
    );
  }
}
