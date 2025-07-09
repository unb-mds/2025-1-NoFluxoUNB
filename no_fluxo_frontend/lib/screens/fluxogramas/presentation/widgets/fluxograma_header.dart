import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/curso_model.dart';

class FluxogramaHeader extends StatelessWidget {
  final CursoModel? courseData;
  final bool isAnonymous;
  final VoidCallback onSaveFluxograma;
  final VoidCallback onAddMateria;
  final VoidCallback onAddOptativa;

  const FluxogramaHeader({
    super.key,
    required this.courseData,
    required this.onSaveFluxograma,
    required this.onAddMateria,
    required this.onAddOptativa,
    this.isAnonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.permanentMarker(
                          fontSize: 32,
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
                              fontSize: 32,
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
                    const SizedBox(height: 8),
                    Text(
                      '${courseData?.matrizCurricular} • ${courseData?.totalCreditos} créditos',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Only show action buttons for logged-in users
              Column(
                children: [
                  Row(
                    children: [
                      _buildActionButton(
                        'SALVAR FLUXOGRAMA',
                        Icons.save,
                        const Color(0xFF22C55E),
                        const Color(0xFF16A34A),
                        onSaveFluxograma,
                      ),
                      if (!isAnonymous) ...[
                        const SizedBox(width: 12),
                        _buildActionButton(
                          'ADICIONAR MATÉRIA',
                          Icons.add,
                          const Color(0xFF8B5CF6),
                          const Color(0xFF7C3AED),
                          onAddMateria,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          'ADICIONAR OPTATIVA',
                          Icons.add_circle_outline,
                          const Color(0xFF3B82F6),
                          const Color(0xFF1D4ED8),
                          onAddOptativa,
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color startColor,
      Color endColor, VoidCallback onPressed) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
