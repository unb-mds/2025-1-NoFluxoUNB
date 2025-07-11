import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/materia_model.dart';

class OptativasAdicionadasSection extends StatelessWidget {
  final List<MateriaModel> optativasAdicionadas;
  final Function(MateriaModel) onOptativaClicked;

  const OptativasAdicionadasSection({
    super.key,
    required this.optativasAdicionadas,
    required this.onOptativaClicked,
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
    return 20.0; // Desktop
  }

  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0; // Mobile
    if (screenWidth < 900) return 20.0; // Tablet
    return 24.0; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    if (optativasAdicionadas.isEmpty) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final responsivePadding = _getResponsivePadding(context);
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      margin: EdgeInsets.only(top: isMobile ? 24 : 32),
      padding: EdgeInsets.all(responsivePadding),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPTATIVAS ADICIONADAS',
            style: GoogleFonts.permanentMarker(
              fontSize: _getResponsiveFontSize(context, baseSize: 24),
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox(height: responsiveSpacing),
          Text(
            'Matérias optativas que você adicionou ao seu fluxograma:',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(context, baseSize: 14),
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          SizedBox(height: responsiveSpacing),
          Wrap(
            spacing: responsiveSpacing,
            runSpacing: responsiveSpacing,
            children: optativasAdicionadas.map((optativa) {
              return _buildOptativaCard(context, optativa);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptativaCard(BuildContext context, MateriaModel optativa) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
    
    // Largura responsiva dos cards
    double cardWidth;
    if (isMobile) {
      cardWidth = MediaQuery.of(context).size.width - 64; // Largura total menos padding
    } else if (isTablet) {
      cardWidth = 240;
    } else {
      cardWidth = 280;
    }

    final responsivePadding = _getResponsivePadding(context);

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF7C3AED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOptativaClicked(optativa),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        optativa.codigoMateria,
                        style: GoogleFonts.poppins(
                          fontSize: _getResponsiveFontSize(context, baseSize: 14),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : 8,
                        vertical: isMobile ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${optativa.creditos} créditos',
                        style: GoogleFonts.poppins(
                          fontSize: _getResponsiveFontSize(context, baseSize: 10),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  optativa.nomeMateria,
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(context, baseSize: 12),
                    color: Colors.white,
                  ),
                  maxLines: isMobile ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'Clique para ver detalhes',
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(context, baseSize: 10),
                    color: Colors.white.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
