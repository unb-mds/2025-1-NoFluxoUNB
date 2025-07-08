// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dartz/dartz.dart' show Left;
import 'package:mobile_app/environment.dart';
import 'package:mobile_app/screens/fluxogramas/data/curso_model.dart';
import '../../../../utils/utils.dart';
import '../../../../widgets/app_navbar.dart';
import '../../../../widgets/graffiti_background.dart';
import '../../../../cache/shared_preferences_helper.dart';
import '../../../../models/user_model.dart';
import '../../data/course_data.dart';
import '../../data/course_subject.dart';
import '../../data/materia_model.dart';
import '../../services/meu_fluxograma_service.dart';
import '../widgets/course_card_widget.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';

import '../widgets/materia_data_dialog_content.dart';

var log = Environment.getLogger("MeuFluxogramaScreen");

class MeuFluxogramaScreen extends StatefulWidget {
  final String? courseName;
  const MeuFluxogramaScreen({super.key, this.courseName});

  @override
  State<MeuFluxogramaScreen> createState() => _MeuFluxogramaScreenState();
}

class _MeuFluxogramaScreenState extends State<MeuFluxogramaScreen> {
  double zoomLevel = 1.0;
  bool showPrereqChains = false;
  CursoModel? currentCourseData;
  List<CursoModel> matrizesCurriculares = [];

  bool loading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> loadCourseData() async {
    if (loading) return false;

    loading = true;
    try {
      var courseName =
          SharedPreferencesHelper.currentUser?.dadosFluxograma?.nomeCurso ??
              (widget.courseName ?? '');

      final loadedCourseData =
          await MeuFluxogramaService.getCourseData(courseName);

      loadedCourseData.fold(
        (error) {
          errorMessage = error;
          return false;
        },
        (cursos) {
          matrizesCurriculares = cursos;
          if (SharedPreferencesHelper.isAnonimo) {
            currentCourseData = cursos[0];
          } else {
            currentCourseData = cursos.firstWhere((curso) =>
                curso.nomeCurso == courseName &&
                curso.matrizCurricular ==
                    SharedPreferencesHelper
                        .currentUser?.dadosFluxograma?.matrizCurricular);
          }

          var materiasPorCodigo = Map<String, MateriaModel>.fromEntries(
              currentCourseData?.materias
                      .map((e) => MapEntry(e.codigoMateria, e)) ??
                  []);

          var listMaterias = SharedPreferencesHelper
                  .currentUser?.dadosFluxograma?.dadosFluxograma
                  .expand((e) => e)
                  .toList() ??
              List<DadosMateria>.from([]);

          var materiasAprovadas = listMaterias
              .where((e) =>
                  e.mencao == 'SS' || e.mencao == 'MS' || e.mencao == 'MM')
              .toList();

          var materiasCurrent =
              listMaterias.where((e) => e.status == "MATR").toList();

          var materiasEquivalentesAprovadas = currentCourseData?.equivalencias
                  .where((e) => e.isMateriaEquivalente(Set<String>.from(
                      materiasAprovadas.map((e) => e.codigoMateria))))
                  .toList() ??
              [];

          var materiasEquivalentesCurrent = currentCourseData?.equivalencias
                  .where((e) => e.isMateriaEquivalente(Set<String>.from(
                      materiasCurrent.map((e) => e.codigoMateria))))
                  .toList() ??
              [];

          for (var materia in SharedPreferencesHelper
                  .currentUser?.dadosFluxograma?.dadosFluxograma
                  .expand((e) => e) ??
              List<DadosMateria>.from([])) {
            if (materiasPorCodigo.containsKey(materia.codigoMateria)) {
              var isCompleted = materia.mencao == 'SS' ||
                  materia.mencao == 'MS' ||
                  materia.mencao == 'MM';
              var isCurrent = materia.status == "MATR";
              materiasPorCodigo[materia.codigoMateria]?.status = isCompleted
                  ? 'completed'
                  : isCurrent
                      ? 'current'
                      : '';
              materiasPorCodigo[materia.codigoMateria]?.mencao = materia.mencao;
              materiasPorCodigo[materia.codigoMateria]?.professor =
                  materia.professor;
            }
          }

          for (var materia in materiasEquivalentesAprovadas) {
            materiasPorCodigo[materia.materia.codigoMateria]?.status =
                'completed';
          }

          for (var materia in materiasEquivalentesCurrent) {
            materiasPorCodigo[materia.materia.codigoMateria]?.status =
                'current';
          }
        },
      );

      return true;
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      errorMessage = e.toString();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: loadCourseData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (errorMessage != null) {
              return Center(child: Text(errorMessage!));
            }

            return Stack(
              children: [
                const GraffitiBackground(),
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const AppNavbar(isFluxogramasPage: true),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 1280),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildPageHeader(),
                                  _buildLegendAndControls(),
                                  _buildFluxogramContainer(),
                                  _buildProgressSummary(),
                                  _buildProgressTools(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Título e descrição
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
                            text: currentCourseData?.nomeCurso.toUpperCase() ??
                                '',
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
                      '${currentCourseData?.matrizCurricular} • ${currentCourseData?.totalCreditos} créditos',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Botões de ação
              Column(
                children: [
                  Row(
                    children: [
                      _buildActionButton(
                        'SALVAR FLUXOGRAMA',
                        Icons.save,
                        const Color(0xFF22C55E),
                        const Color(0xFF16A34A),
                        () {},
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        'ADICIONAR MATÉRIA',
                        Icons.add,
                        const Color(0xFF8B5CF6),
                        const Color(0xFF7C3AED),
                        () {},
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        'ADICIONAR OPTATIVA',
                        Icons.add_circle_outline,
                        const Color(0xFF3B82F6),
                        const Color(0xFF1D4ED8),
                        () {},
                      ),
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

  Widget _buildLegendAndControls() {
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
                      onChanged: (value) {
                        setState(() {
                          showPrereqChains = value ?? false;
                        });
                      },
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
                    setState(() {
                      zoomLevel = (zoomLevel - 0.1).clamp(0.5, 2.0);
                    });
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
                    setState(() {
                      zoomLevel = (zoomLevel + 0.1).clamp(0.5, 2.0);
                    });
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

  Widget _buildFluxogramContainer() {
    // Verificar se há dados do fluxograma para exibir
    bool hasFluxogramData = false;
    for (final semesterSubjects
        in currentCourseData?.materias ?? List<MateriaModel>.empty()) {
      hasFluxogramData = true;
      break;
    }

    if (!hasFluxogramData) {
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
                'Faça upload do seu histórico acadêmico para visualizar seu fluxograma personalizado.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Transform.scale(
          scale: zoomLevel,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int semester = 1;
                  semester <= (currentCourseData?.semestres ?? 0);
                  semester++)
                _buildSemesterColumn(semester),
            ],
          ),
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
    final subjects = currentCourseData?.materias
            .where((materia) => materia.nivel == semester)
            .toList() ??
        [];

    return subjects
        .map((subject) => CourseCardWidget(
              subject: subject,
              onTap: () {
                Utils.showCustomizedDialog(
                  context: context,
                  child: MateriaDataDialogContent(materia: subject),
                );
              },
            ))
        .toList();
  }

  Widget _buildProgressSummary() {
    // Calcular progresso real baseado nos dados do usuário
    final obrigatorias = currentCourseData?.totalCreditos ?? 160;
    final optativas = currentCourseData?.totalCreditos ?? 24;
    final livre = currentCourseData?.totalCreditos ?? 24;

    // Calcular créditos concluídos
    int currentObrigatorias = 0;
    int currentOptativas = 0;
    int currentLivre = 0;

    // Percorrer todos os semestres para contar créditos concluídos
    /* currentCourseData?.materias.forEach((subject) {
        if (subject.status == 'completed') {
          // Por enquanto, considera todas as matérias concluídas como obrigatórias
          // Isso pode ser melhorado futuramente com dados mais específicos
        currentObrigatorias += subject.mencao ?? 0;
      }
    }); */

    final totalCurrent = currentObrigatorias + currentOptativas + currentLivre;
    final totalRequired = obrigatorias + optativas + livre;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          // Credits Progress
          Expanded(
            child: _buildProgressCard(
              'Progresso de Créditos',
              Icons.school,
              const Color(0xFF8B5CF6),
              [
                {
                  'label': 'Obrigatórias',
                  'progress': totalRequired > 0
                      ? currentObrigatorias / obrigatorias
                      : 0.0,
                  'current': currentObrigatorias,
                  'total': obrigatorias
                },
                {
                  'label': 'Optativas',
                  'progress':
                      optativas > 0 ? currentOptativas / optativas : 0.0,
                  'current': currentOptativas,
                  'total': optativas
                },
                {
                  'label': 'Módulo Livre',
                  'progress': livre > 0 ? currentLivre / livre : 0.0,
                  'current': currentLivre,
                  'total': livre
                },
                {
                  'label': 'Total',
                  'progress':
                      totalRequired > 0 ? totalCurrent / totalRequired : 0.0,
                  'current': totalCurrent,
                  'total': totalRequired,
                  'isTotal': true
                },
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Current Semester
          Expanded(
            child: _buildCurrentSemesterCard(),
          ),
          const SizedBox(width: 24),

          // Recommendations
          Expanded(
            child: _buildRecommendationsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, IconData icon, Color color,
      List<Map<String, dynamic>> progressItems) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...progressItems.map((item) => _buildProgressItem(item)),
        ],
      ),
    );
  }

  Widget _buildProgressItem(Map<String, dynamic> item) {
    final isTotal = item['isTotal'] ?? false;
    final height = isTotal ? 12.0 : 10.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['label'],
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '${item['current']}/${item['total']} créditos',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item['progress'],
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTotal
                        ? [const Color(0xFFEC4899), const Color(0xFFDB2777)]
                        : [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSemesterCard() {
    // Calcular semestre atual baseado nos dados do usuário
    final currentUser = SharedPreferencesHelper.currentUser;
    int currentSemester = 1;

    if (currentUser?.dadosFluxograma != null) {
      currentSemester = currentUser!.dadosFluxograma!.semestreAtual;
    }

    final currentSubjects = currentCourseData?.materias
            .where((materia) => materia.nivel == currentSemester)
            .toList() ??
        [];
    final currentCredits =
        currentSubjects.fold<int>(0, (sum, subject) => sum + subject.creditos);

    // Calcular dados do próximo semestre
    final nextSemester = currentSemester + 1;
    final nextSubjects = currentCourseData?.materias
            .where((materia) => materia.nivel == nextSemester)
            .toList() ??
        [];
    final selectedSubjects =
        nextSubjects.where((s) => s.status == 'selected').length;
    final plannedCredits = nextSubjects
        .where((s) => s.status == 'selected')
        .fold<int>(0, (sum, subject) => sum + subject.creditos);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semestre Atual: ${currentSemester}º',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Total de Matérias', '${currentSubjects.length}'),
          _buildInfoRow('Créditos', '$currentCredits'),
          _buildInfoRow('Carga Horária Semanal',
              '${(currentCredits * 2.5).round()} horas'),
          const SizedBox(height: 16),
          Text(
            'Próximo Semestre',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Matérias Selecionadas', '$selectedSubjects'),
          _buildInfoRow('Créditos Planejados', '$plannedCredits'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    // TODO: Gerar recomendações baseadas nos dados do usuário e curso
    // Por enquanto, usa recomendações genéricas
    final recommendations = <Map<String, String>>[];

    // TODO: Analisar pré-requisitos pendentes
    final pendingPrereqs = _getPendingPrerequisites();
    if (pendingPrereqs.isNotEmpty) {
      recommendations.add({
        'title': 'Pré-requisitos Pendentes',
        'description':
            'Você precisa cursar ${pendingPrereqs.take(3).join(", ")} para desbloquear matérias futuras.',
      });
    }

    // TODO: Analisar balanceamento de carga
    recommendations.add({
      'title': 'Balanceamento de Carga',
      'description':
          'Considere adicionar mais 2-3 matérias para o próximo semestre para manter um ritmo adequado.',
    });

    // TODO: Sugerir matérias baseadas no perfil
    recommendations.add({
      'title': 'Matérias Sugeridas',
      'description':
          'Com base no seu perfil, recomendamos consultar o assistente de IA para sugestões personalizadas.',
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recomendações',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...recommendations.map((rec) =>
              _buildRecommendationItem(rec['title']!, rec['description']!)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/assistente'),
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
              label: Text(
                'VER ASSISTENTE DE IA',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TODO: Implementar análise de pré-requisitos pendentes
  List<String> _getPendingPrerequisites() {
    // TODO: Analisar todas as matérias e verificar pré-requisitos não atendidos
    return [];
  }

  Widget _buildRecommendationItem(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTools() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildToolCard(
                  'Calculadora de IRA',
                  Icons.calculate,
                  'Simule seu IRA com base em notas futuras',
                  'Calcular IRA',
                  const Color(0xFF8B5CF6),
                  const Color(0xFF7C3AED),
                  () => _showToolModal(context, title: 'Calculadora de IRA'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Progresso do Curso',
                  Icons.bar_chart,
                  'Visualize seu progresso detalhado',
                  'Ver Progresso',
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8),
                  () => _showToolModal(context, title: 'Progresso do Curso'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Integralização',
                  Icons.info_outline,
                  'Verifique requisitos para formatura',
                  'Verificar',
                  const Color(0xFF22C55E),
                  const Color(0xFF16A34A),
                  () => _showToolModal(context, title: 'Integralização'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildToolCard(
                  'Mudança de Curso',
                  Icons.swap_horiz,
                  'Simule aproveitamento em outro curso',
                  'Simular',
                  const Color(0xFFF59E0B),
                  const Color(0xFFD97706),
                  () => _showToolModal(context, title: 'Mudança de Curso'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, IconData icon, String description,
      String buttonText, Color startColor, Color endColor,
      [VoidCallback? onPressed]) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: startColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: startColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToolModal(BuildContext context, {required String title}) {
    if (title == 'Calculadora de IRA') {
      // ...modal customizado da Calculadora de IRA (como já implementado)...
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.black.withOpacity(0.92),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520, minWidth: 400),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Calculadora de IRA',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF818CF8),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicione as disciplinas e notas esperadas para simular seu IRA futuro.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF818CF8),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Campos de disciplina (editáveis)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Disciplina',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF374151)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Nota',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF374151)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Créditos',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF374151)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botão adicionar disciplina (sem ação)
                  TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add,
                        color: Color(0xFF818CF8), size: 18),
                    label: Text(
                      'Adicionar disciplina',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF818CF8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Card IRA
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('IRA Atual:',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFDBEAFE),
                                    fontWeight: FontWeight.w500)),
                            Text('-',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('IRA Simulado:',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFDBEAFE),
                                    fontWeight: FontWeight.w500)),
                            Text('-',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Calcular'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }
    if (title == 'Progresso do Curso') {
      // ...modal customizado do Progresso do Curso (com progressos zerados)...
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.black.withOpacity(0.92),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progresso do Curso',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF60A5FA),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white54, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progresso geral
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Progresso Geral',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              Text('0% (0/0 créditos)',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF60A5FA),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: const LinearProgressIndicator(
                              value: 0.0,
                              minHeight: 12,
                              backgroundColor: Color(0xFF374151),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Disciplinas por área e desempenho por área
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Disciplinas por área
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Disciplinas por Área',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 10),
                                _buildProgressBarRow('Obrigatórias',
                                    '0/0 créditos', 0.0, Colors.blue),
                                _buildProgressBarRow('Optativas',
                                    '0/0 créditos', 0.0, Colors.blue),
                                _buildProgressBarRow('Complementares',
                                    '0/0 créditos', 0.0, Colors.blue),
                              ],
                            ),
                          ),
                        ),
                        // Desempenho por área
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Desempenho por Área',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 10),
                                _buildProgressBarRow(
                                    'Programação', '0.0', 0.0, Colors.green),
                                _buildProgressBarRow(
                                    'Matemática', '0.0', 0.0, Colors.green),
                                _buildProgressBarRow(
                                    'Engenharia', '0.0', 0.0, Colors.green),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Histórico de IRA por semestre (área para gráfico)
                    Text('Histórico de IRA por Semestre',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Gráfico em breve...',
                        style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 16,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
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
            ),
          );
        },
      );
      return;
    }
    if (title == 'Integralização') {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.black.withOpacity(0.92),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Integralização Curricular',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white54, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Card de previsão de formatura
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14532D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFF22C55E), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Previsão de formatura: ',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF22C55E),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '2º semestre de 2023',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF22C55E),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Título dos requisitos
                    Text(
                      'Requisitos para Integralização',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Créditos Obrigatórios
                    _buildRequirementCard(
                      'Créditos Obrigatórios',
                      '0/160 créditos (0%)',
                      0.0,
                      'Faltam 160 créditos em disciplinas obrigatórias.',
                    ),
                    const SizedBox(height: 12),
                    // Créditos Optativos
                    _buildRequirementCard(
                      'Créditos Optativos',
                      '0/40 créditos (0%)',
                      0.0,
                      'Faltam 40 créditos em disciplinas optativas.',
                    ),
                    const SizedBox(height: 12),
                    // Atividades Complementares
                    _buildRequirementCard(
                      'Atividades Complementares',
                      '0/40 horas (0%)',
                      0.0,
                      'Faltam 40 horas de atividades complementares.',
                    ),
                    const SizedBox(height: 12),
                    // TCC
                    _buildTCCCard(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
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
            ),
          );
        },
      );
      return;
    }
    if (title == 'Mudança de Curso') {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.black.withOpacity(0.92),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, minWidth: 400),
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Simulação de Mudança de Curso',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFF59E0B),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white54, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Selecione um curso para simular o aproveitamento de disciplinas e créditos.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF59E0B),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Dropdown de seleção de curso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curso de Destino',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFF59E0B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF374151)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: null,
                            decoration: const InputDecoration(
                              hintText: 'Selecione um curso',
                              hintStyle: TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.black,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: InputBorder.none,
                            ),
                            dropdownColor: Colors.black,
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cc',
                                  child: Text('Ciência da Computação')),
                              DropdownMenuItem(
                                  value: 'si',
                                  child: Text('Sistemas de Informação')),
                              DropdownMenuItem(
                                  value: 'ec',
                                  child: Text('Engenharia da Computação')),
                              DropdownMenuItem(
                                  value: 'ads',
                                  child: Text(
                                      'Análise e Desenvolvimento de Sistemas')),
                            ],
                            onChanged: (value) {
                              // TODO: Implementar lógica de simulação
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Resultados da simulação (inicialmente ocultos)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF92400E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo do Aproveitamento',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFF59E0B),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '-',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFCD34D),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Aproveitamento',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFF59E0B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '-',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFCD34D),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Créditos aproveitados',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFF59E0B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '-',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFCD34D),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Semestres adicionais',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFF59E0B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Disciplinas aproveitadas
                    _buildSubjectListCard(
                      'Disciplinas Aproveitadas',
                      [],
                      isApproved: true,
                    ),
                    const SizedBox(height: 12),
                    // Disciplinas adicionais necessárias
                    _buildSubjectListCard(
                      'Disciplinas Adicionais Necessárias',
                      [],
                      isApproved: false,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFF374151)),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Simular'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      return;
    }
  }

  // Helper para card de lista de disciplinas
  Widget _buildSubjectListCard(String title, List<String> subjects,
      {required bool isApproved}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: subjects.isEmpty
                ? Center(
                    child: Text(
                      'Selecione um curso para ver as disciplinas',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Column(
                    children: subjects
                        .map((subject) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isApproved ? Icons.check : Icons.add,
                                    color: isApproved
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    subject,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // Helper para card de requisito
  Widget _buildRequirementCard(
      String title, String progress, double percent, String description,
      {bool isCompleted = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF374151)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso:',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      progress,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF374151),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                  ),
                ),
                const SizedBox(height: 12),
                if (isCompleted)
                  Row(
                    children: [
                      const Icon(Icons.check,
                          color: Color(0xFF22C55E), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E), fontSize: 12),
                      ),
                    ],
                  )
                else
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para card do TCC
  Widget _buildTCCCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF374151)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Trabalho de Conclusão de Curso',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '0%',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Não iniciado',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Disponível a partir do 7º semestre.',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para barra de progresso customizada
  Widget _buildProgressBarRow(
      String label, String value, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
              Text(value,
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFF374151),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
