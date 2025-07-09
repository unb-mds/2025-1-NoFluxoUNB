import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FluxogramaLegendControls extends StatelessWidget {
  final double zoomLevel;
  final bool showPrereqChains;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<bool> onShowPrereqChainsChanged;

  const FluxogramaLegendControls({
    super.key,
    required this.zoomLevel,
    required this.showPrereqChains,
    required this.onZoomChanged,
    required this.onShowPrereqChainsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Legend
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                  const Color(0xFF4ADE80),
                  const Color(0xFF22C55E),
                  'Concluídas',
                ),
                _buildLegendItem(
                  const Color(0xFFA78BFA),
                  const Color(0xFF8B5CF6),
                  'Em Curso',
                ),
                _buildLegendItem(
                  const Color(0xFFFB7185),
                  const Color(0xFFE11D48),
                  'Selecionadas',
                ),
                _buildLegendItem(
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.1),
                  'Futuras',
                  isDashed: true,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: showPrereqChains,
                      onChanged: (value) =>
                          onShowPrereqChainsChanged(value ?? false),
                      fillColor: MaterialStateProperty.all(
                          Colors.white.withOpacity(0.2)),
                      checkColor: Colors.white,
                    ),
                    Text(
                      'Cadeias de Pré-requisito',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Zoom Controls
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    final newZoom = (zoomLevel - 0.1).clamp(0.5, 2.0);
                    onZoomChanged(newZoom);
                  },
                  icon: const Icon(Icons.remove, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${(zoomLevel * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final newZoom = (zoomLevel + 0.1).clamp(0.5, 2.0);
                    onZoomChanged(newZoom);
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color startColor, Color endColor, String label,
      {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(4),
            border: isDashed
                ? Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                    style: BorderStyle.solid,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
