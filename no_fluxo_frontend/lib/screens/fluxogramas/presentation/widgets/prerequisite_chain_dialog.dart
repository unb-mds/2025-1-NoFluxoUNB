import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrerequisiteChainDialog extends StatelessWidget {
  final String subjectCode;
  final String subjectName;
  final Map<String, dynamic> chainData;

  const PrerequisiteChainDialog({
    super.key,
    required this.subjectCode,
    required this.subjectName,
    required this.chainData,
  });

  static void show(
    BuildContext context, {
    required String subjectCode,
    required String subjectName,
    required Map<String, dynamic> chainData,
    bool isAnonymous = false,
  }) {
    // Don't show prerequisite chain dialog for anonymous users
    if (isAnonymous) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PrerequisiteChainDialog(
        subjectCode: subjectCode,
        subjectName: subjectName,
        chainData: chainData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.black.withOpacity(0.92),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, minWidth: 400),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Cadeia de Pré-requisitos',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8B5CF6),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$subjectName ($subjectCode)',
              style: GoogleFonts.poppins(
                color: const Color(0xFF8B5CF6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Prerequisite Chain Visualization
            PrerequisiteChainVisualization(chainData: chainData),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PrerequisiteChainVisualization extends StatelessWidget {
  final Map<String, dynamic> chainData;

  const PrerequisiteChainVisualization({
    super.key,
    required this.chainData,
  });

  @override
  Widget build(BuildContext context) {
    var chain = chainData['chain'] as List<List<String>>? ?? [];
    var dependents = chainData['dependents'] as List<String>? ?? [];
    var canBeTaken = chainData['canBeTaken'] as bool? ?? false;
    var isRoot = chainData['isRoot'] as bool? ?? false;
    var depth = chainData['depth'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canBeTaken
                ? const Color(0xFF22C55E).withOpacity(0.2)
                : const Color(0xFFEF4444).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canBeTaken
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
          ),
          child: Row(
            children: [
              Icon(
                canBeTaken ? Icons.check_circle : Icons.warning,
                color: canBeTaken
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  canBeTaken
                      ? 'Pode ser cursada agora'
                      : 'Pré-requisitos pendentes',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'Nível: $depth',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Prerequisites chain
        if (chain.isNotEmpty) ...[
          Text(
            'Pré-requisitos (${chain.length} níveis):',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...chain.asMap().entries.map((entry) {
            var level = entry.key;
            var subjects = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nível ${level + 1}:',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8B5CF6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: subjects
                        .map((subject) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                subject,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ] else if (isRoot) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Text(
                  'Esta matéria não possui pré-requisitos',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Dependents
        if (dependents.isNotEmpty) ...[
          Text(
            'Libera as seguintes matérias (${dependents.length}):',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: dependents
                  .map((dependent) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dependent,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_flags, color: Colors.white54),
                const SizedBox(width: 8),
                Text(
                  'Esta matéria não é pré-requisito para outras',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
