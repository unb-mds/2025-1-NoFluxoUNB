// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile_app/environment.dart';
import 'package:mobile_app/screens/fluxogramas/data/curso_model.dart';
import '../../../../utils/utils.dart';
import '../../../../widgets/app_navbar.dart';
import '../../../../widgets/graffiti_background.dart';
import '../../../../cache/shared_preferences_helper.dart';
import '../../../../models/user_model.dart';
import '../../../../widgets/splash_widget.dart';

import '../../data/materia_model.dart';
import '../../data/prerequisite_tree_model.dart';
import '../../services/meu_fluxograma_service.dart';

import '../widgets/fluxograma_header.dart';
import '../widgets/fluxograma_legend_controls.dart';
import '../widgets/progress_summary_section.dart';
import '../widgets/progress_tools_section.dart';
import '../widgets/fluxogram_container.dart';
import '../widgets/prerequisite_chain_dialog.dart';
import '../widgets/tool_modals.dart';
import '../widgets/optativas_modal.dart';
import '../widgets/optativas_adicionadas_section.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:google_fonts/google_fonts.dart';

import '../widgets/materia_data_dialog_content.dart';

// Modelo para optativas adicionadas
class OptativaAdicionada {
  final MateriaModel materia;
  final int semestre;

  OptativaAdicionada({
    required this.materia,
    required this.semestre,
  });
}

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
  bool isAnonymous = false;
  bool isInteractingWithFluxogram = false;
  bool showOptativasModal = false;
  List<OptativaAdicionada> optativasAdicionadas = [];

  bool loading = false;
  String? errorMessage;

  final ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
  }

  Future<bool> loadCourseData() async {
    if (loading) return false;

    loading = true;
    try {
      var courseName = widget.courseName ??
          (SharedPreferencesHelper.currentUser?.dadosFluxograma?.nomeCurso ??
              "");

      if (courseName == "") {
        courseName =
            SharedPreferencesHelper.currentUser?.dadosFluxograma?.nomeCurso ??
                "";
      }

      if (courseName == "") {
        context.go("/upload-historico");
        return false;
      }

      final loadedCourseData =
          await MeuFluxogramaService.getCourseData(courseName);
      isAnonymous =
          SharedPreferencesHelper.isAnonimo || widget.courseName != null;

      await loadedCourseData.fold(
        (error) async {
          errorMessage = error;
          return false;
        },
        (cursos) async {
          matrizesCurriculares = cursos;
          if (isAnonymous) {
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

          var materiasCursadasPorCodigo = Map<String, DadosMateria>.fromEntries(
              listMaterias.map((e) => MapEntry(e.codigoMateria, e)));

          List<MateriaModel> materiasCursadasAsMateriaModel = [];

          var materiasCursadasAsMateriaModelResponse =
              await MeuFluxogramaService.getMateriasCursadasAsMateriaModel(
                  listMaterias.map((e) => e.codigoMateria).toList(),
                  currentCourseData?.idCurso ?? 0);

          materiasCursadasAsMateriaModelResponse.fold((l) {
            log.severe(l, StackTrace.current);
          }, (r) {
            materiasCursadasAsMateriaModel = r;

            for (var materia in materiasCursadasAsMateriaModel) {
              materia.mencao =
                  materiasCursadasPorCodigo[materia.codigoMateria]?.mencao;
              materia.professor =
                  materiasCursadasPorCodigo[materia.codigoMateria]?.professor;
            }
          });

          var materiasEquivalentesAprovadas =
              currentCourseData?.equivalencias.where((equiv) {
                    var equivalenciaResult = equiv.isMateriaEquivalente(
                        materiasCursadasAsMateriaModel
                            .where((e) =>
                                e.mencao == 'SS' ||
                                e.mencao == 'MS' ||
                                e.mencao == 'MM')
                            .toList());
                    if (equivalenciaResult.isEquivalente) {
                      for (var v in equivalenciaResult.equivalentes) {
                        equiv.equivalenteA = v;
                      }
                    }
                    return equivalenciaResult.isEquivalente;
                  }).toList() ??
                  [];

          var materiasEquivalentesCurrent =
              currentCourseData?.equivalencias.where((equiv) {
                    var equivalenciaResult = equiv.isMateriaEquivalente(
                        materiasCursadasAsMateriaModel
                            .where((e) => e.mencao == 'MATR')
                            .toList());

                    if (equivalenciaResult.isEquivalente) {
                      for (var v in equivalenciaResult.equivalentes) {
                        equiv.equivalenteA = v;
                      }
                    }
                    return equivalenciaResult.isEquivalente;
                  }).toList() ??
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
            materiasPorCodigo[materia.materia.codigoMateria]
                ?.materiaEquivalenteCursada = materia.equivalenteA;
          }

          for (var materia in materiasEquivalentesCurrent) {
            materiasPorCodigo[materia.materia.codigoMateria]?.status =
                'current';
            materiasPorCodigo[materia.materia.codigoMateria]
                ?.materiaEquivalenteCursada = materia.equivalenteA;
          }

          for (var materia
              in currentCourseData?.materias ?? List<MateriaModel>.from([])) {
            if (materiasPorCodigo.containsKey(materia.codigoMateria)) {
              materia.status = materiasPorCodigo[materia.codigoMateria]?.status;
              materia.mencao = materiasPorCodigo[materia.codigoMateria]?.mencao;
              materia.professor =
                  materiasPorCodigo[materia.codigoMateria]?.professor;
              materia.materiaEquivalenteCursada =
                  materiasPorCodigo[materia.codigoMateria]
                      ?.materiaEquivalenteCursada;
            }
          }

          // Build prerequisite tree and visualization data
          if (currentCourseData != null) {
            prerequisiteTree = currentCourseData!.buildPrerequisiteTree();
            prerequisiteVisualizationData =
                currentCourseData!.getAllPrerequisiteVisualizationData();
          }

          // update data
        },
      );

      return true;
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      errorMessage = e.toString();
      return false;
    }
  }

  Future<void> saveFluxogramAsImage() async {
    bool dialogClosed = false;
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: SplashWidget(),
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

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final courseName =
          currentCourseData?.nomeCurso.replaceAll(' ', '_') ?? 'curso';
      final fileName = 'fluxograma_${courseName}_$timestamp.png';

      if (kIsWeb) {
        // Web platform - use browser download
        final blob = html.Blob([imageBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        // Close loading dialog
        dialogClosed = true;
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fluxograma baixado: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Mobile platforms - save to device storage
        Directory? directory;
        if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          throw Exception('Não foi possível acessar o diretório de downloads');
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(imageBytes);

        // Close loading dialog
        dialogClosed = true;
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fluxograma salvo em: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!dialogClosed) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }

      log.severe('Erro ao salvar imagem: $e');

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar imagem: $e'),
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
                          physics: isInteractingWithFluxogram
                              ? const NeverScrollableScrollPhysics()
                              : const AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 1280),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  FluxogramaHeader(
                                    isAnonymous: isAnonymous,
                                    courseData: currentCourseData,
                                    onSaveFluxograma: saveFluxogramAsImage,
                                    onAddOptativa: () {
                                      setState(() {
                                        showOptativasModal = true;
                                      });
                                    },
                                  ),
                                  if (!isAnonymous) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final user = SharedPreferencesHelper
                                                .currentUser;
                                            if (user == null) return;
                                            final result =
                                                await MeuFluxogramaService
                                                    .deleteFluxogramaUser(
                                                        user.idUser.toString(),
                                                        user.token ?? '');
                                            result.fold((l) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Erro ao remover fluxograma: ' +
                                                          l),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }, (r) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Fluxograma removido com sucesso!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              context.go('/upload-historico');
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.refresh,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          label: Text(
                                            'ENVIAR FLUXOGRAMA NOVAMENTE',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 28, vertical: 14),
                                            backgroundColor:
                                                const Color(0xFFFF3CA5),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                            elevation: 8,
                                            shadowColor:
                                                Colors.black.withOpacity(0.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  FluxogramaLegendControls(
                                    isAnonymous: isAnonymous,
                                    zoomLevel: zoomLevel,
                                    showConnections: showConnections,
                                    onZoomChanged: (newZoom) {
                                      setState(() {
                                        zoomLevel = newZoom;
                                      });
                                    },
                                    onShowConnectionsChanged: (value) {
                                      setState(() {
                                        showConnections = value;
                                      });
                                    },
                                  ),
                                  MouseRegion(
                                    onEnter: (_) {
                                      /* setState(() {
                                        isInteractingWithFluxogram = true;
                                      }); */
                                    },
                                    onExit: (_) {
                                      /* setState(() {
                                        isInteractingWithFluxogram = false;
                                      }); */
                                    },
                                    child: Screenshot(
                                      controller: screenshotController,
                                      child: FluxogramContainer(
                                        zoomLevel: zoomLevel,
                                        courseData: currentCourseData,
                                        isAnonymous: isAnonymous,
                                        showConnections: showConnections,
                                        onShowPrerequisiteChain:
                                            _showPrerequisiteChainDialog,
                                        onShowMateriaDialog:
                                            _showMateriaDataDialog,
                                      ),
                                    ),
                                  ),
                                  ProgressSummarySection(
                                    isAnonymous: isAnonymous,
                                    courseData: currentCourseData,
                                  ),
                                  OptativasAdicionadasSection(
                                    optativasAdicionadas: optativasAdicionadas
                                        .map((opt) => opt.materia)
                                        .toList(),
                                    onOptativaClicked: (materia) {
                                      // Encontrar a optativa adicionada correspondente
                                      final optativaAdicionada =
                                          optativasAdicionadas.firstWhere(
                                        (opt) =>
                                            opt.materia.codigoMateria ==
                                            materia.codigoMateria,
                                      );
                                      _showOptativaDataDialog(
                                          context, optativaAdicionada);
                                    },
                                  ),
                                  ProgressToolsSection(
                                    isAnonymous: isAnonymous,
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
                // Modal de optativas
                if (showOptativasModal)
                  OptativasModal(
                    optativasDisponiveis: currentCourseData?.materias
                            .where((materia) => materia.nivel == 0)
                            .toList() ??
                        [],
                    onOptativaSelecionada: (optativa, semestre) {
                      // Verificar se a optativa já foi adicionada
                      bool jaAdicionada = optativasAdicionadas.any((opt) =>
                          opt.materia.codigoMateria == optativa.codigoMateria);

                      if (jaAdicionada) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'A optativa ${optativa.codigoMateria} já foi adicionada!',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        setState(() {
                          showOptativasModal = false;
                        });
                        return;
                      }

                      setState(() {
                        optativasAdicionadas.add(OptativaAdicionada(
                          materia: optativa,
                          semestre: semestre,
                        ));
                        showOptativasModal = false;
                      });

                      // Mostrar mensagem de sucesso
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Optativa ${optativa.codigoMateria} - ${optativa.nomeMateria} adicionada ao ${semestre}º semestre!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    onCancelOptativa: () {
                      setState(() {
                        showOptativasModal = false;
                      });
                    },
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

  /// Mostrar dialog de optativa quando clicada
  void _showOptativaDataDialog(
      BuildContext context, OptativaAdicionada optativa) {
    Utils.showCustomizedDialog(
      context: context,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              optativa.materia.codigoMateria,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              optativa.materia.nomeMateria,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Créditos: ${optativa.materia.creditos}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Semestre: ${optativa.semestre}º',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ementa:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              optativa.materia.ementa,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _removerOptativa(optativa);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                  ),
                  child: Text(
                    'Remover',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                  ),
                  child: Text(
                    'Fechar',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Remover optativa da lista
  void _removerOptativa(OptativaAdicionada optativa) {
    setState(() {
      optativasAdicionadas.removeWhere(
          (opt) => opt.materia.codigoMateria == optativa.materia.codigoMateria);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Optativa ${optativa.materia.codigoMateria} removida com sucesso!',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
