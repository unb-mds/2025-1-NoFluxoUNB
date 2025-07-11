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

  // Função para obter dimensões responsivas
  double _getResponsiveFontSize(BuildContext context, {double baseSize = 16.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize * 0.8; // Mobile
    if (screenWidth < 900) return baseSize * 0.9; // Tablet
    return baseSize; // Desktop
  }

  double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 12.0; // Mobile
    if (screenWidth < 900) return 16.0; // Tablet
    return 24.0; // Desktop
  }

  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    if (screenWidth < 900) return 20.0; // Tablet
    return 24.0; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    // Don't show progress tools for anonymous users
    if (isAnonymous) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      padding: EdgeInsets.all(responsivePadding),
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
              fontSize: _getResponsiveFontSize(context, baseSize: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsiveSpacing),
          isMobile 
              ? _buildMobileLayout(context, responsiveSpacing)
              : _buildDesktopLayout(context, responsiveSpacing),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, double spacing) {
    return Column(
      children: [
        // Primeira linha: Calculadora de IRA e Progresso do Curso
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                context,
                'Calculadora de IRA',
                Icons.calculate,
                'Simule seu IRA com base em notas futuras',
                'Em breve',
                const Color(0xFF8B5CF6),
                const Color(0xFF7C3AED),
                null, // Desabilitar botão
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildToolCard(
                context,
                'Progresso do Curso',
                Icons.bar_chart,
                'Visualize seu progresso detalhado',
                'Em breve',
                const Color(0xFF3B82F6),
                const Color(0xFF1D4ED8),
                null, // Desabilitar botão
              ),
            ),
          ],
        ),
        SizedBox(height: spacing),
        // Segunda linha: Integralização e Mudança de Curso
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                context,
                'Integralização',
                Icons.info_outline,
                'Verifique requisitos para formatura',
                'Em breve',
                const Color(0xFF22C55E),
                const Color(0xFF16A34A),
                null, // Desabilitar botão
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildToolCard(
                context,
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
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double spacing) {
    return Row(
      children: [
        Expanded(
          child: _buildToolCard(
            context,
            'Calculadora de IRA',
            Icons.calculate,
            'Simule seu IRA com base em notas futuras',
            'Em breve',
            const Color(0xFF8B5CF6),
            const Color(0xFF7C3AED),
            null, // Desabilitar botão
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildToolCard(
            context,
            'Progresso do Curso',
            Icons.bar_chart,
            'Visualize seu progresso detalhado',
            'Em breve',
            const Color(0xFF3B82F6),
            const Color(0xFF1D4ED8),
            null, // Desabilitar botão
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildToolCard(
            context,
            'Integralização',
            Icons.info_outline,
            'Verifique requisitos para formatura',
            'Em breve',
            const Color(0xFF22C55E),
            const Color(0xFF16A34A),
            null, // Desabilitar botão
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildToolCard(
            context,
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
    );
  }

  Widget _buildToolCard(BuildContext context, String title, IconData icon, String description,
      String buttonText, Color startColor, Color endColor,
      [VoidCallback? onPressed]) {
    // Verificar se o botão está desabilitado (onPressed é null)
    bool isDisabled = onPressed == null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Tooltip(
      message:
          isDisabled ? 'Esta funcionalidade estará disponível em breve!' : '',
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : responsivePadding),
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
                Icon(
                  icon, 
                  color: startColor, 
                  size: _getResponsiveFontSize(context, baseSize: 24)
                ),
                SizedBox(width: isMobile ? 6 : responsiveSpacing / 2),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(context, baseSize: 16),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : responsiveSpacing),
            Text(
              description,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: _getResponsiveFontSize(context, baseSize: 12),
              ),
              maxLines: isMobile ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 8 : responsiveSpacing),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDisabled ? startColor.withOpacity(0.5) : startColor,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 6 : 8,
                    horizontal: isMobile ? 8 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(isDisabled ? 0.8 : 1.0),
                    fontSize: _getResponsiveFontSize(context, baseSize: 12),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
