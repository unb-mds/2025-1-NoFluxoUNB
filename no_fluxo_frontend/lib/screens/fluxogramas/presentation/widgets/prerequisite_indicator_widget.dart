import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/materia_model.dart';

class PrerequisiteIndicatorWidget extends StatelessWidget {
  final MateriaModel subject;
  final bool isAnonymous;
  final Function(String subjectCode) getPrerequisiteChainData;

  const PrerequisiteIndicatorWidget({
    super.key,
    required this.subject,
    required this.getPrerequisiteChainData,
    this.isAnonymous = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show prerequisite indicators for anonymous users
    if (isAnonymous) {
      return const SizedBox.shrink();
    }

    var chainData = getPrerequisiteChainData(subject.codigoMateria);
    if (chainData == null) return const SizedBox.shrink();

    var canBeTaken = chainData['canBeTaken'] as bool? ?? false;
    var isRoot = chainData['isRoot'] as bool? ?? false;
    var dependents = chainData['dependents'] as List<String>? ?? [];
    var allPrereqs = chainData['allPrerequisites'] as List<String>? ?? [];

    // Determine indicator color and icon
    Color indicatorColor;
    IconData indicatorIcon;
    String tooltip;

    if (isRoot) {
      indicatorColor = const Color(0xFF22C55E);
      indicatorIcon = Icons.flag;
      tooltip = 'Sem pré-requisitos';
    } else if (canBeTaken) {
      indicatorColor = const Color(0xFF3B82F6);
      indicatorIcon = Icons.check_circle_outline;
      tooltip = 'Pré-requisitos atendidos';
    } else {
      indicatorColor = const Color(0xFFEF4444);
      indicatorIcon = Icons.warning_outlined;
      tooltip = '${allPrereqs.length} pré-requisitos pendentes';
    }

    return Positioned(
      top: 8,
      right: 8,
      child: Tooltip(
        message: '$tooltip\nToque e segure para ver detalhes',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: indicatorColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                indicatorIcon,
                color: Colors.white,
                size: 14,
              ),
              if (dependents.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${dependents.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
