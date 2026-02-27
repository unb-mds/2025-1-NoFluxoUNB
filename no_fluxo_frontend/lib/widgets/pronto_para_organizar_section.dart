import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/auth/auth_page.dart';

class ProntoParaOrganizarSection extends StatefulWidget {
  const ProntoParaOrganizarSection({super.key});

  @override
  State<ProntoParaOrganizarSection> createState() => _ProntoParaOrganizarSectionState();
}

class _ProntoParaOrganizarSectionState extends State<ProntoParaOrganizarSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      color: Colors.black.withOpacity(0.3),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'PRONTO PARA ORGANIZAR SEU FLUXO?',
            style: GoogleFonts.permanentMarker(
              color: Colors.white,
              fontSize: 32,
              letterSpacing: 1.5,
              shadows: const [
                Shadow(
                  color: Color.fromARGB(120, 0, 0, 0),
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Não perca mais tempo tentando entender seu fluxograma. O NoFluxo UNB torna tudo mais simples e visual para você planejar sua jornada acadêmica.',
              style: GoogleFonts.poppins(
                color: Colors.grey[300],
                fontSize: 16,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    color: Color.fromARGB(100, 0, 0, 0),
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 300,
              height: 56,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: AnimatedScale(
                  scale: _isHovered ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.0)),
                      backgroundColor: Colors.transparent,
                      shadowColor: const Color(0xFF0033CC).withOpacity(0.2),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0099FF), Color(0xFF0033CC)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(32.0),
                      ),
                      child: Center(
                        child: Text(
                          'COMEÇAR AGORA',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 