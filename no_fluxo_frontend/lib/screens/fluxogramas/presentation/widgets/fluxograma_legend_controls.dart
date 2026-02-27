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

  // Função para obter dimensões responsivas
  double _getResponsiveFontSize(BuildContext context, {double baseSize = 14.0}) {
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
    final responsiveSpacing = _getResponsiveSpacing(context);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isMobile 
          ? _buildMobileLayout(context, responsiveSpacing)
          : _buildDesktopLayout(context, responsiveSpacing),
    );
  }

  Widget _buildMobileLayout(BuildContext context, double spacing) {
    return Column(
      children: [
        // Legend em mobile - em coluna
        Wrap(
          spacing: spacing,
          runSpacing: spacing / 2,
          children: [
            // Only show full legend for logged-in users
            if (!isAnonymous && !SharedPreferencesHelper.isAnonimo) ...[
              _buildLegendItem(
                const Color(0xFF4ADE80),
                const Color(0xFF22C55E),
                'Concluídas',
                context,
              ),
              _buildLegendItem(
                const Color(0xFFA78BFA),
                const Color(0xFF8B5CF6),
                'Em Curso',
                context,
              ),
              _buildLegendItem(
                const Color(0xFFF59E0B),
                const Color(0xFFD97706),
                'Próximo semestre',
                context,
              ),
            ],
            // Toggle para conexões visuais
            _buildConnectionsToggle(context),
          ],
        ),
        SizedBox(height: spacing),
        // Zoom Controls em mobile - centralizado
        Center(
          child: Container(
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
                  icon: Icon(Icons.remove, color: Colors.white, size: 20),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${(zoomLevel * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: _getResponsiveFontSize(context, baseSize: 14),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final newZoom = (zoomLevel + 0.1).clamp(0.5, 2.0);
                    onZoomChanged(newZoom);
                  },
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double spacing) {
    return Row(
      children: [
        // Legend
        Expanded(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing / 2,
            children: [
              // Only show full legend for logged-in users
              if (!isAnonymous && !SharedPreferencesHelper.isAnonimo) ...[
                _buildLegendItem(
                  const Color(0xFF4ADE80),
                  const Color(0xFF22C55E),
                  'Concluídas',
                  context,
                ),
                _buildLegendItem(
                  const Color(0xFFA78BFA),
                  const Color(0xFF8B5CF6),
                  'Em Curso',
                  context,
                ),
                _buildLegendItem(
                  const Color(0xFFF59E0B),
                  const Color(0xFFD97706),
                  'Cursar no próximo semestre',
                  context,
                ),
              ],
              // Toggle para conexões visuais
              _buildConnectionsToggle(context),
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
                icon: Icon(Icons.remove, color: Colors.white, size: 20),
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${(zoomLevel * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(context, baseSize: 14),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final newZoom = (zoomLevel + 0.1).clamp(0.5, 2.0);
                  onZoomChanged(newZoom);
                },
                icon: Icon(Icons.add, color: Colors.white, size: 20),
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionsToggle(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Tooltip(
      message: showConnections
          ? 'Ocultar conexões entre disciplinas'
          : 'Mostrar conexões visuais entre disciplinas',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onShowConnectionsChanged(!showConnections),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8, 
              vertical: isMobile ? 3 : 4
            ),
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
                  size: isMobile ? 16 : 18,
                ),
                SizedBox(width: isMobile ? 4 : 6),
                Text(
                  isMobile ? 'Conexões' : 'Conexões Visuais',
                  style: GoogleFonts.poppins(
                    color: showConnections
                        ? const Color(0xFF60A5FA)
                        : Colors.white.withOpacity(0.7),
                    fontSize: _getResponsiveFontSize(context, baseSize: 14),
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
      BuildContext context, {bool isDashed = false, bool isClickable = false, VoidCallback? onTap}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    Widget legendContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 16 : 20,
          height: isMobile ? 16 : 20,
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
        SizedBox(width: isMobile ? 6 : 8),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _getResponsiveFontSize(context, baseSize: 14),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (isClickable && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 2 : 4, 
            vertical: isMobile ? 1 : 2
          ),
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
