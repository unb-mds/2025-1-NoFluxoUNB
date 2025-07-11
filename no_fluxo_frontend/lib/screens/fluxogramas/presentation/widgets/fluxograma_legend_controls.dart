import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../cache/shared_preferences_helper.dart';

class FluxogramaLegendControls extends StatelessWidget {
  final double zoomLevel;
  final bool showConnections;
  final bool isAnonymous;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<bool> onShowConnectionsChanged;

  const FluxogramaLegendControls({
    super.key,
    required this.zoomLevel,
    required this.showConnections,
    required this.onZoomChanged,
    required this.onShowConnectionsChanged,
    this.isAnonymous = false,
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
                // Only show full legend for logged-in users
                if (!isAnonymous && !SharedPreferencesHelper.isAnonimo) ...[
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
                    const Color(0xFFF59E0B),
                    const Color(0xFFD97706),
                    'Cursar no próximo semestre	',
                  ),
                ],
                // Toggle para conexões visuais - com melhor distinção visual
                _buildConnectionsToggle(),
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

  Widget _buildConnectionsToggle() {
    return Tooltip(
      message: showConnections
          ? 'Ocultar conexões entre disciplinas (hover/clique para ver pré-requisitos e próximas matérias)'
          : 'Mostrar conexões visuais entre disciplinas (hover/clique para ver pré-requisitos e próximas matérias)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onShowConnectionsChanged(!showConnections),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: showConnections
                  ? const Color(0xFF3B82F6).withOpacity(0.2)
                  : Colors.transparent,
              border: Border.all(
                color: showConnections
                    ? const Color(0xFF3B82F6)
                    : Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showConnections
                      ? Icons.account_tree
                      : Icons.account_tree_outlined,
                  color: showConnections
                      ? const Color(0xFF60A5FA)
                      : Colors.white.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Conexões Visuais',
                  style: GoogleFonts.poppins(
                    color: showConnections
                        ? const Color(0xFF60A5FA)
                        : Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight:
                        showConnections ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color startColor, Color endColor, String label,
      {bool isDashed = false, bool isClickable = false, VoidCallback? onTap}) {
    Widget legendContent = Row(
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

    if (isClickable && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
          child: legendContent,
        ),
      );
    }

    return legendContent;
  }
}
