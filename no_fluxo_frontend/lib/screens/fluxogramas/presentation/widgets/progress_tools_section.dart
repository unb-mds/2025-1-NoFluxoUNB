import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressToolsSection extends StatelessWidget {
  final bool isAnonymous;
  final Function(String) onShowToolModal;

  const ProgressToolsSection({
    super.key,
    required this.onShowToolModal,
    this.isAnonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show progress tools for anonymous users
    if (isAnonymous) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ferramentas de Progresso',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildToolCard(
                  'Calculadora de IRA',
                  Icons.calculate,
                  'Simule seu IRA com base em notas futuras',
                  'Em breve',
                  const Color(0xFF8B5CF6),
                  const Color(0xFF7C3AED),
                  null, // Desabilitar botão
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Progresso do Curso',
                  Icons.bar_chart,
                  'Visualize seu progresso detalhado',
                  'Em breve',
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8),
                  null, // Desabilitar botão
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Integralização',
                  Icons.info_outline,
                  'Verifique requisitos para formatura',
                  'Em breve',
                  const Color(0xFF22C55E),
                  const Color(0xFF16A34A),
                  null, // Desabilitar botão
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Mudança de Curso',
                  Icons.swap_horiz,
                  'Simule aproveitamento em outro curso',
                  'Em breve',
                  const Color(0xFFF59E0B),
                  const Color(0xFFD97706),
                  null, // Desabilitar botão
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, IconData icon, String description,
      String buttonText, Color startColor, Color endColor,
      [VoidCallback? onPressed]) {
    // Verificar se o botão está desabilitado (onPressed é null)
    bool isDisabled = onPressed == null;

    return Tooltip(
      message:
          isDisabled ? 'Esta funcionalidade estará disponível em breve!' : '',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor.withOpacity(0.2), endColor.withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: startColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: startColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDisabled ? startColor.withOpacity(0.5) : startColor,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(isDisabled ? 0.8 : 1.0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
