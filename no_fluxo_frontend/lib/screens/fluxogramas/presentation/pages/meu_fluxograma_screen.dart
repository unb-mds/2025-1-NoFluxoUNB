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
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  bool showConnections = false;
  CursoModel? currentCourseData;
  List<CursoModel> matrizesCurriculares = [];
  PrerequisiteTree? prerequisiteTree;
  Map<String, dynamic>? prerequisiteVisualizationData;

  bool loading = false;
  String? errorMessage;

  // Screenshot controller for PDF generation
  final ScreenshotController screenshotController = ScreenshotController();

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

  Future<void> saveFluxogramAsPdf() async {
    bool closed = false;
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Capture the widget as image
      final Uint8List? imageBytes = await screenshotController.capture(
        delay: const Duration(milliseconds: 500),
        pixelRatio: 2.0,
      );

      if (imageBytes == null) {
        throw Exception('Erro ao capturar imagem do fluxograma');
      }

      // Create PDF document
      final pdf = pw.Document();

      // Convert image to PDF format
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Fluxograma - ${currentCourseData?.nomeCurso ?? 'Curso'}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.Image(
                      image,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Gerado em: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Save or share the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'fluxograma_${currentCourseData?.nomeCurso?.replaceAll(' ', '_') ?? 'curso'}.pdf',
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fluxograma salvo como PDF com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!closed) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }

      log.severe('Erro ao salvar PDF: $e');

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                                    isAnonymous:
                                        SharedPreferencesHelper.isAnonimo,
                                    courseData: currentCourseData,
                                    onSaveFluxograma: saveFluxogramAsPdf,
                                    onAddMateria: () {},
                                    onAddOptativa: () {},
                                  ),
                                  FluxogramaLegendControls(
                                    isAnonymous:
                                        SharedPreferencesHelper.isAnonimo,
                                    zoomLevel: zoomLevel,
                                    showPrereqChains: showPrereqChains,
                                    showConnections: showConnections,
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
                                    onShowConnectionsChanged: (value) {
                                      setState(() {
                                        showConnections = value;
                                      });
                                    },
                                  ),
                                  Screenshot(
                                    controller: screenshotController,
                                    child: FluxogramContainer(
                                      courseData: currentCourseData,
                                      zoomLevel: zoomLevel,
                                      isAnonymous:
                                          SharedPreferencesHelper.isAnonimo,
                                      showPrereqChains: showPrereqChains,
                                      showConnections: showConnections,
                                      onShowPrerequisiteChain:
                                          _showPrerequisiteChainDialog,
                                      onBuildPrerequisiteIndicator:
                                          _buildPrerequisiteIndicator,
                                      onShowMateriaDialog:
                                          _showMateriaDataDialog,
                                    ),
                                  ),
                                  ProgressSummarySection(
                                    isAnonymous:
                                        SharedPreferencesHelper.isAnonimo,
                                    courseData: currentCourseData,
                                  ),
                                  ProgressToolsSection(
                                    isAnonymous:
                                        SharedPreferencesHelper.isAnonimo,
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
