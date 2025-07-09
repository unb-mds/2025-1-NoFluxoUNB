import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/config/size_config.dart';
import '../cache/shared_preferences_helper.dart';
import '../config/app_colors.dart';
import '../widgets/graffiti_background.dart';
import '../widgets/app_navbar.dart';
import '../widgets/como_funciona_section.dart';
import '../widgets/pronto_para_organizar_section.dart';
import '../widgets/sobre_nos_section.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Importa o flutter_svg

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // const double navbarHeight = 72; // Altura aproximada da navbar
    return Scaffold(
      body: Stack(
        children: [
          const GraffitiBackground(), // Fundo artístico
          // Conteúdo principal, agora começa do topo
          SingleChildScrollView(
            child: Column(
              children: [
                // Adiciona sombra/fundo escuro translúcido atrás da primeira seção
                Container(
                  padding: const EdgeInsets.only(
                      top: 88, left: 64, right: 64, bottom: 48),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Conteúdo alinhado à esquerda
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Título principal com destaque em rosa
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'TENHA SEU\nFLUXOGRAMA\nMUITO ',
                                    style: GoogleFonts.permanentMarker(
                                      fontSize: 64,
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color:
                                              AppColors.black.withOpacity(0.3),
                                          offset: const Offset(3, 3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'RÁPIDO',
                                    style: GoogleFonts.permanentMarker(
                                      fontSize: 64,
                                      color: const Color(0xFFF472B6), // Rosa
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color:
                                              AppColors.black.withOpacity(0.3),
                                          offset: const Offset(3, 3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 32),
                            // Texto descritivo alinhado à esquerda e com largura máxima
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: Text(
                                'O NO FLUXO UNB TE AJUDA A VER O FLUXOGRAMA DO SEU CURSO E AINDA TE PERMITE ADICIONAR MATÉRIAS OPTATIVAS DE ACORDO COM SUAS ÁREAS DE INTERESSE!',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: AppColors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Botão com gradiente azul, sombra, alinhado à esquerda e mais compacto
                            SizedBox(
                              width: 260,
                              height: 48,
                              child: _AnimatedAcesseButton(),
                            ),
                          ],
                        ),
                      ),
                      // SVG à direita
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24.0),
                          child: SvgPicture.asset(
                            'assets/icons/computer_phone.svg',
                            width: 600,
                            theme: SvgTheme(
                                fontSize: getProportionateFontSize(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const ComoFuncionaSection(),
                const ProntoParaOrganizarSection(),
                const SobreNosSection(),
              ],
            ),
          ),
          // Navbar fixa e translúcida sobre o conteúdo
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: AppNavbar()),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAcesseButton extends StatefulWidget {
  @override
  State<_AnimatedAcesseButton> createState() => _AnimatedAcesseButtonState();
}

class _AnimatedAcesseButtonState extends State<_AnimatedAcesseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: ElevatedButton(
          onPressed: () {
            if (SharedPreferencesHelper.currentUser != null) {
              if (SharedPreferencesHelper.currentUser!.dadosFluxograma ==
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
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32.0),
            ),
            backgroundColor: Colors.transparent,
            shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.3 * 255),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color.fromARGB(255, 34, 150, 238), Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(32.0),
            ),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ACESSE NOSSO SISTEMA',
                  style: GoogleFonts.permanentMarker(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
