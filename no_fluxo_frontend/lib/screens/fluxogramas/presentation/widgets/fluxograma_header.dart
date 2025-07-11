import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../utils/utils.dart';
import '../../data/curso_model.dart';

class FluxogramaHeader extends StatelessWidget {
  final CursoModel? courseData;
  final bool isAnonymous;
  final VoidCallback onSaveFluxograma;
  final VoidCallback onAddOptativa;

  const FluxogramaHeader({
    super.key,
    required this.courseData,
    required this.onSaveFluxograma,
    required this.onAddOptativa,
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
    if (screenWidth < 600) return 8.0; // Mobile
    if (screenWidth < 900) return 12.0; // Tablet
    return 16.0; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
      child: Column(
        children: [
          // Layout responsivo: coluna em mobile, linha em desktop
          if (isMobile) ...[
            // Mobile: Layout em coluna
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.permanentMarker(
                      fontSize: _getResponsiveFontSize(context, baseSize: 32),
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    children: [
                      const TextSpan(text: 'FLUXOGRAMA: '),
                      TextSpan(
                        text: courseData?.nomeCurso.toUpperCase() ?? '',
                        style: GoogleFonts.permanentMarker(
                          fontSize: _getResponsiveFontSize(context, baseSize: 32),
                          color: const Color(0xFFFF3CA5),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: responsiveSpacing),
                Text(
                  '${courseData?.matrizCurricular} • ${courseData?.totalCreditos} créditos\n${Utils.capitalize(courseData?.tipoCurso ?? '')} • ${Utils.capitalize(courseData?.classificacao ?? '')}',
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(context, baseSize: 16),
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: responsiveSpacing),
                // Botões em linha para mobile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'SALVAR',
                        Icons.save,
                        const Color(0xFF22C55E),
                        const Color(0xFF16A34A),
                        onSaveFluxograma,
                        context,
                      ),
                    ),
                    if (!isAnonymous) ...[
                      SizedBox(width: responsiveSpacing),
                      Expanded(
                        child: _buildActionButton(
                          'OPTATIVA',
                          Icons.add_circle_outline,
                          const Color(0xFF3B82F6),
                          const Color(0xFF1D4ED8),
                          onAddOptativa,
                          context,
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ] else ...[
            // Desktop/Tablet: Layout em linha
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.permanentMarker(
                            fontSize: _getResponsiveFontSize(context, baseSize: 32),
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.7),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          children: [
                            const TextSpan(text: 'FLUXOGRAMA: '),
                            TextSpan(
                              text: courseData?.nomeCurso.toUpperCase() ?? '',
                              style: GoogleFonts.permanentMarker(
                                fontSize: _getResponsiveFontSize(context, baseSize: 32),
                                color: const Color(0xFFFF3CA5),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.7),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: responsiveSpacing),
                      Text(
                        '${courseData?.matrizCurricular} • ${courseData?.totalCreditos} créditos\n${Utils.capitalize(courseData?.tipoCurso ?? '')} • ${Utils.capitalize(courseData?.classificacao ?? '')}',
                        style: GoogleFonts.poppins(
                          fontSize: _getResponsiveFontSize(context, baseSize: 16),
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Botões para desktop/tablet
                Column(
                  children: [
                    Row(
                      children: [
                        _buildActionButton(
                          isTablet ? 'SALVAR FLUXOGRAMA' : 'SALVAR FLUXOGRAMA',
                          Icons.save,
                          const Color(0xFF22C55E),
                          const Color(0xFF16A34A),
                          onSaveFluxograma,
                          context,
                        ),
                        if (!isAnonymous) ...[
                          SizedBox(width: responsiveSpacing),
                          _buildActionButton(
                            isTablet ? 'ADICIONAR OPTATIVA' : 'ADICIONAR OPTATIVA',
                            Icons.add_circle_outline,
                            const Color(0xFF3B82F6),
                            const Color(0xFF1D4ED8),
                            onAddOptativa,
                            context,
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color startColor,
      Color endColor, VoidCallback onPressed, BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : (isTablet ? 14 : 16), 
              vertical: isMobile ? 10 : (isTablet ? 11 : 12)
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  color: Colors.white, 
                  size: isMobile ? 18 : 20
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Flexible(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: _getResponsiveFontSize(context, baseSize: 14),
                    ),
                    overflow: TextOverflow.ellipsis,
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
