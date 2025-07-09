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
import '../../../../widgets/splash_widget.dart';
import '../../data/course_data.dart';
import '../../data/course_subject.dart';
import '../../data/materia_model.dart';
import '../../data/prerequisite_tree_model.dart';
import '../../services/meu_fluxograma_service.dart';
import '../widgets/course_card_widget.dart';
import '../widgets/fluxograma_header.dart';
import '../widgets/fluxograma_legend_controls.dart';
import '../widgets/progress_summary_section.dart';
import '../widgets/progress_tools_section.dart';
import '../widgets/fluxogram_container.dart';
import '../widgets/prerequisite_chain_dialog.dart';
import '../widgets/prerequisite_indicator_widget.dart';
import '../widgets/tool_modals.dart';
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
  PrerequisiteTree? prerequisiteTree;
  Map<String, dynamic>? prerequisiteVisualizationData;

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

          // Build prerequisite tree and visualization data
          if (currentCourseData != null) {
            prerequisiteTree = currentCourseData!.buildPrerequisiteTree();
            prerequisiteVisualizationData =
                currentCourseData!.getAllPrerequisiteVisualizationData();
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
              return const SplashWidget();
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
                                  FluxogramaHeader(
                                    courseData: currentCourseData,
                                    onSaveFluxograma: () {},
                                    onAddMateria: () {},
                                    onAddOptativa: () {},
                                  ),
                                  FluxogramaLegendControls(
                                    zoomLevel: zoomLevel,
                                    showPrereqChains: showPrereqChains,
                                    onZoomChanged: (newZoom) {
                                      setState(() {
                                        zoomLevel = newZoom;
                                      });
                                    },
                                    onShowPrereqChainsChanged: (value) {
                                      setState(() {
                                        showPrereqChains = value;
                                      });
                                    },
                                  ),
                                  FluxogramContainer(
                                    courseData: currentCourseData,
                                    zoomLevel: zoomLevel,
                                    showPrereqChains: showPrereqChains,
                                    onShowPrerequisiteChain:
                                        _showPrerequisiteChainDialog,
                                    onBuildPrerequisiteIndicator:
                                        _buildPrerequisiteIndicator,
                                    onShowMateriaDialog: _showMateriaDataDialog,
                                  ),
                                  ProgressSummarySection(
                                    courseData: currentCourseData,
                                  ),
                                  ProgressToolsSection(
                                    onShowToolModal: (title) =>
                                        _showToolModal(context, title: title),
                                  ),
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

  /// Get prerequisite chain visualization data for a subject
  Map<String, dynamic>? _getPrerequisiteChainData(String subjectCode) {
    if (currentCourseData == null) return null;
    return currentCourseData!.getPrerequisiteVisualizationData(subjectCode);
  }

  /// Show prerequisite chain dialog for a subject
  void _showPrerequisiteChainDialog(String subjectCode, String subjectName) {
    var chainData = _getPrerequisiteChainData(subjectCode);
    if (chainData == null) return;

    PrerequisiteChainDialog.show(
      context,
      subjectCode: subjectCode,
      subjectName: subjectName,
      chainData: chainData,
    );
  }

  void _showToolModal(BuildContext context, {required String title}) {
    ToolModals.showToolModal(context, title: title);
  }

  /// Show materia data dialog when clicking on a course card
  void _showMateriaDataDialog(BuildContext context, MateriaModel materia) {
    Utils.showCustomizedDialog(
      context: context,
      child: MateriaDataDialogContent(materia: materia),
    );
  }

  /// Build prerequisite indicator for course cards
  Widget _buildPrerequisiteIndicator(MateriaModel subject) {
    return PrerequisiteIndicatorWidget(
      subject: subject,
      getPrerequisiteChainData: _getPrerequisiteChainData,
    );
  }
}
