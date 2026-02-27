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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final horizontalPadding =
        screenWidth * 0.05 > 24 ? screenWidth * 0.05 : 16.0;
    final verticalPadding = screenWidth < 500 ? 24.0 : 48.0;
    final titleFontSize = isMobile ? 32.0 : 64.0;
    final descFontSize = isMobile ? 14.0 : 20.0;
    final svgWidth = isMobile ? screenWidth * 0.7 : 600.0;

    return Scaffold(
      endDrawer: AppNavbarDrawer(
        links: AppNavbar.navLinks(context, isDrawer: true),
      ),
      body: Stack(
        children: [
          const GraffitiBackground(),
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: isMobile ? 56 : 88,
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                                height: isMobile
                                    ? 48
                                    : 64), // Espaço extra abaixo da navbar
                            _HomeTextSection(
                              titleFontSize: titleFontSize,
                              descFontSize: descFontSize,
                              isMobile: isMobile,
                            ),
                            const SizedBox(height: 24),
                            SvgPicture.asset(
                              'assets/icons/computer_phone.svg',
                              width: svgWidth,
                              theme: SvgTheme(fontSize: 10),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  SizedBox(
                                      height:
                                          64), // Espaço extra abaixo da navbar
                                  _HomeTextSection(
                                    titleFontSize: titleFontSize,
                                    descFontSize: descFontSize,
                                    isMobile: isMobile,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 24.0),
                                child: SvgPicture.asset(
                                  'assets/icons/computer_phone.svg',
                                  width: svgWidth,
                                  theme: SvgTheme(fontSize: 10),
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

class _HomeTextSection extends StatelessWidget {
  final double titleFontSize;
  final double descFontSize;
  final bool isMobile;
  const _HomeTextSection({
    required this.titleFontSize,
    required this.descFontSize,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'TENHA SEU\nFLUXOGRAMA\nMUITO ',
                style: GoogleFonts.permanentMarker(
                  fontSize: titleFontSize,
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppColors.black.withOpacity(0.3),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              TextSpan(
                text: 'RÁPIDO',
                style: GoogleFonts.permanentMarker(
                  fontSize: titleFontSize,
                  color: const Color(0xFFF472B6),
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: AppColors.black.withOpacity(0.3),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
        ),
        SizedBox(height: isMobile ? 16 : 32),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? 400 : 700),
          child: Text(
            'O NO FLUXO UNB TE AJUDA A VER O FLUXOGRAMA DO SEU CURSO E AINDA TE PERMITE ADICIONAR MATÉRIAS OPTATIVAS DE ACORDO COM SUAS ÁREAS DE INTERESSE!',
            style: GoogleFonts.poppins(
              fontSize: descFontSize,
              color: AppColors.white.withOpacity(0.95),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
          ),
        ),
        SizedBox(height: isMobile ? 24 : 40),
        SizedBox(
          width: isMobile ? 180 : 260,
          height: 48,
          child: _AnimatedAcesseButton(),
        ),
      ],
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
