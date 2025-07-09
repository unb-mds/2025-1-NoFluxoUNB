import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../data/curso_model.dart';
import '../../data/materia_model.dart';
import '../../../../utils/utils.dart';
import 'course_card_widget.dart';
import 'materia_data_dialog_content.dart';
import 'prerequisite_connections_widget.dart';

class FluxogramContainer extends StatefulWidget {
  final CursoModel? courseData;
  final double zoomLevel;
  final bool showPrereqChains;
  final bool showConnections;
  final bool isAnonymous;
  final Function(String, String) onShowPrerequisiteChain;
  final Function(MateriaModel) onBuildPrerequisiteIndicator;
  final Function(BuildContext, MateriaModel) onShowMateriaDialog;

  const FluxogramContainer({
    super.key,
    required this.courseData,
    required this.zoomLevel,
    required this.showPrereqChains,
    required this.showConnections,
    required this.onShowPrerequisiteChain,
    required this.onBuildPrerequisiteIndicator,
    required this.onShowMateriaDialog,
    this.isAnonymous = false,
  });

  @override
  State<FluxogramContainer> createState() => _FluxogramContainerState();
}

class _FluxogramContainerState extends State<FluxogramContainer> {
  String? selectedSubjectCode;

  @override
  Widget build(BuildContext context) {
    // Check if there's fluxogram data to display
    bool hasFluxogramData = false;
    for (final semesterSubjects
        in widget.courseData?.materias ?? List<MateriaModel>.empty()) {
      hasFluxogramData = true;
      break;
    }

    if (!hasFluxogramData) {
      return _buildEmptyState(context);
    }

    if (widget.showConnections) {
      return Container(
        margin: const EdgeInsets.only(bottom: 32),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Transform.scale(
                scale: widget.zoomLevel,
                child: PrerequisiteConnectionsWidget(
                  courseData: widget.courseData,
                  zoomLevel: widget.zoomLevel,
                  selectedSubjectCode: selectedSubjectCode,
                  isAnonymous: widget.isAnonymous,
                  onSubjectSelectionChanged: (subjectCode) {
                    setState(() {
                      selectedSubjectCode = subjectCode;
                    });
                  },
                  onShowMateriaDialog: widget.onShowMateriaDialog,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Transform.scale(
              scale: widget.zoomLevel,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int semester = 1;
                      semester <= (widget.courseData?.semestres ?? 0);
                      semester++)
                    _buildSemesterColumn(semester),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum fluxograma encontrado',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isAnonymous
                  ? 'Explore os fluxogramas disponíveis ou faça login para personalizar.'
                  : 'Faça upload do seu histórico acadêmico para visualizar seu fluxograma personalizado.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.isAnonymous)
              ElevatedButton.icon(
                onPressed: () => context.go('/upload-historico'),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: Text(
                  'FAZER UPLOAD DO HISTÓRICO',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterColumn(int semester) {
    return Container(
      margin: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          // Semester Header
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${semester}º Semestre',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          // Course Cards
          ..._getCoursesForSemester(semester),
        ],
      ),
    );
  }

  List<Widget> _getCoursesForSemester(int semester) {
    final subjects = widget.courseData?.materias
            .where((materia) => materia.nivel == semester)
            .toList() ??
        [];

    return subjects
        .map((subject) => Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  widget.onShowMateriaDialog(context, subject);
                },
                onLongPress: widget.showPrereqChains && !widget.isAnonymous
                    ? () {
                        widget.onShowPrerequisiteChain(
                            subject.codigoMateria, subject.nomeMateria);
                      }
                    : null,
                child: Stack(
                  children: [
                    CourseCardWidget(
                      subject: subject,
                      isAnonymous: widget.isAnonymous,
                      onTap: () {
                        widget.onShowMateriaDialog(context, subject);
                      },
                    ),
                    if (widget.showPrereqChains && !widget.isAnonymous)
                      widget.onBuildPrerequisiteIndicator(subject) as Widget,
                  ],
                ),
              ),
            ))
        .toList();
  }
}
