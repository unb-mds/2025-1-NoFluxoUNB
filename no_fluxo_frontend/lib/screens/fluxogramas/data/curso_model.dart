import 'materia_model.dart';
import 'prerequisite_tree_model.dart';
import 'equivalencia_model.dart';

class PreRequisitoModel {
  int idPreRequisito;
  int idMateria;
  int idMateriaRequisito;
  String codigoMateriaRequisito;
  String nomeMateriaRequisito;

  PreRequisitoModel({
    required this.idPreRequisito,
    required this.idMateria,
    required this.idMateriaRequisito,
    required this.codigoMateriaRequisito,
    required this.nomeMateriaRequisito,
  });

  factory PreRequisitoModel.fromJson(Map<String, dynamic> json) {
    return PreRequisitoModel(
      idPreRequisito: json["id_pre_requisito"],
      idMateria: json["id_materia"],
      idMateriaRequisito: json["id_materia_requisito"],
      codigoMateriaRequisito: json["codigo_materia_requisito"],
      nomeMateriaRequisito: json["nome_materia_requisito"],
    );
  }
}

class CursoModel {
  String nomeCurso;
  String matrizCurricular;
  int idCurso;
  int? totalCreditos;
  String classificacao;
  String tipoCurso;
  List<MateriaModel> materias;
  int semestres;
  List<EquivalenciaModel> equivalencias;
  List<PreRequisitoModel> preRequisitos;

  CursoModel({
    required this.nomeCurso,
    required this.matrizCurricular,
    required this.idCurso,
    required this.totalCreditos,
    required this.classificacao,
    required this.tipoCurso,
    required this.materias,
    required this.semestres,
    this.equivalencias = const [],
    this.preRequisitos = const [],
  });

  factory CursoModel.fromMinimalJson(Map<String, dynamic> json) {
    return CursoModel(
      nomeCurso: json["nome_curso"],
      matrizCurricular: json["matriz_curricular"],
      idCurso: json["id_curso"],
      totalCreditos: json["creditos"],
      tipoCurso: json["tipo_curso"] ?? "outro",
      classificacao: json["classificacao"] ?? "outro",
      materias: [],
      semestres: 0,
      equivalencias: [],
      preRequisitos: [],
    );
  }

  factory CursoModel.fromJson(Map<String, dynamic> json) {
    var curso = CursoModel(
        nomeCurso: json["nome_curso"],
        matrizCurricular: json["matriz_curricular"],
        idCurso: json["id_curso"],
        totalCreditos: json["creditos"],
        tipoCurso: json["tipo_curso"],
        classificacao: json["classificacao"],
        materias: List<MateriaModel>.from(json["materias_por_curso"]
            .map((materia) => MateriaModel.fromJson(materia))),
        semestres: 0,
        equivalencias: json["equivalencias"] != null
            ? List<EquivalenciaModel>.from(json["equivalencias"]
                .map((equiv) => EquivalenciaModel.fromJson(equiv)))
            : [],
        preRequisitos: json["pre_requisitos"] != null
            ? List<PreRequisitoModel>.from(json["pre_requisitos"].map(
                (preRequisito) => PreRequisitoModel.fromJson(preRequisito)))
            : []);

    int maxSemestre = 0;
    for (var materia in curso.materias) {
      if (materia.nivel > maxSemestre) {
        maxSemestre = materia.nivel;
      }
    }

    curso.semestres = maxSemestre;

    // Populate prerequisites for all materias
    curso.populatePrerequisites();

    return curso;
  }

  /// Build prerequisite tree for this course
  PrerequisiteTree buildPrerequisiteTree() {
    return PrerequisiteTree.fromCourse(this);
  }

  /// Populate prerequisites for all materias using the prerequisite tree
  void populatePrerequisites() {
    // Clear existing prerequisites
    for (var materia in materias) {
      materia.prerequisitos.clear();
    }

    // Build prerequisite relationships using the existing preRequisitos data
    Map<String, List<String>> prerequisiteMap = {};

    // Create a map from materia code to materia object for quick lookup
    Map<String, MateriaModel> materiaMap = {};
    for (var materia in materias) {
      materiaMap[materia.codigoMateria] = materia;
    }

    // Build prerequisite map from preRequisitos data
    for (var preReq in preRequisitos) {
      String materiaCode = '';
      String prerequisiteCode = preReq.codigoMateriaRequisito;

      // Find the materia that has this prerequisite
      var targetMateria = materias.firstWhere(
          (m) => m.idMateria == preReq.idMateria,
          orElse: () =>
              throw Exception('Materia not found for id: ${preReq.idMateria}'));
      materiaCode = targetMateria.codigoMateria;

      if (!prerequisiteMap.containsKey(materiaCode)) {
        prerequisiteMap[materiaCode] = [];
      }
      prerequisiteMap[materiaCode]!.add(prerequisiteCode);
    }

    // Populate prerequisites for each materia
    for (var materia in materias) {
      var directPrerequisites = prerequisiteMap[materia.codigoMateria] ?? [];

      // Add direct prerequisites
      for (var prereqCode in directPrerequisites) {
        if (materiaMap.containsKey(prereqCode)) {
          materia.prerequisitos.add(materiaMap[prereqCode]!);
        }
      }

      // Add indirect prerequisites (prerequisites of prerequisites)
      Set<String> allPrerequisites = {};
      _collectAllPrerequisites(
          materia.codigoMateria, prerequisiteMap, allPrerequisites);

      // Add all prerequisites to the materia (avoiding duplicates)
      Set<String> existingCodes =
          materia.prerequisitos.map((m) => m.codigoMateria).toSet();
      for (var prereqCode in allPrerequisites) {
        if (materiaMap.containsKey(prereqCode) &&
            !existingCodes.contains(prereqCode)) {
          materia.prerequisitos.add(materiaMap[prereqCode]!);
        }
      }
    }
  }

  /// Helper method to recursively collect all prerequisites
  void _collectAllPrerequisites(String materiaCode,
      Map<String, List<String>> prerequisiteMap, Set<String> collected) {
    var directPrereqs = prerequisiteMap[materiaCode] ?? [];

    for (var prereqCode in directPrereqs) {
      if (!collected.contains(prereqCode)) {
        collected.add(prereqCode);
        // Recursively collect prerequisites of this prerequisite
        _collectAllPrerequisites(prereqCode, prerequisiteMap, collected);
      }
    }
  }

  /// Get only direct prerequisites for a materia
  List<MateriaModel> getDirectPrerequisites(String materiaCode) {
    Map<String, MateriaModel> materiaMap = {};
    for (var materia in materias) {
      materiaMap[materia.codigoMateria] = materia;
    }

    List<MateriaModel> directPrereqs = [];

    for (var preReq in preRequisitos) {
      var targetMateria = materias.firstWhere(
          (m) => m.idMateria == preReq.idMateria,
          orElse: () =>
              throw Exception('Materia not found for id: ${preReq.idMateria}'));

      if (targetMateria.codigoMateria == materiaCode) {
        var prerequisiteMateria = materiaMap[preReq.codigoMateriaRequisito];
        if (prerequisiteMateria != null) {
          directPrereqs.add(prerequisiteMateria);
        }
      }
    }

    return directPrereqs;
  }

  /// Get prerequisite visualization data for a specific subject
  Map<String, dynamic> getPrerequisiteVisualizationData(String subjectCode) {
    var tree = buildPrerequisiteTree();
    var node = tree.nodes[subjectCode];

    if (node == null) {
      return {
        'subject': subjectCode,
        'chain': <List<String>>[],
        'dependents': <String>[],
        'canBeTaken': false,
      };
    }

    var completedSubjects = materias
        .where((m) => m.status == 'completed')
        .map((m) => m.codigoMateria)
        .toSet();

    return {
      'subject': subjectCode,
      'chain': node.getPrerequisiteChain(),
      'dependents': node.getAllDependentsCodes().toList(),
      'allPrerequisites': node.getAllPrerequisitesCodes().toList(),
      'canBeTaken': node.canBeTaken(completedSubjects),
      'depth': node.depth,
      'isRoot': node.isRoot,
      'isLeaf': node.isLeaf,
    };
  }

  /// Get all prerequisite chains for visualization
  Map<String, dynamic> getAllPrerequisiteVisualizationData() {
    var tree = buildPrerequisiteTree();
    var completedSubjects = materias
        .where((m) => m.status == 'completed')
        .map((m) => m.codigoMateria)
        .toSet();

    return {
      'nodesByLevel': tree.getNodesByLevel().map((level, nodes) => MapEntry(
          level,
          nodes
              .map((n) => {
                    'code': n.materia.codigoMateria,
                    'name': n.materia.nomeMateria,
                    'credits': n.materia.creditos,
                    'status': n.materia.status,
                    'semester': n.materia.nivel,
                    'canBeTaken': n.canBeTaken(completedSubjects),
                    'isRoot': n.isRoot,
                    'isLeaf': n.isLeaf,
                    'depth': n.depth,
                    'prerequisites': n.prerequisites
                        .map((p) => p.materia.codigoMateria)
                        .toList(),
                    'dependents': n.dependents
                        .map((d) => d.materia.codigoMateria)
                        .toList(),
                  })
              .toList())),
      'availableSubjects': tree.getAvailableSubjects(completedSubjects),
      'optimalOrganization': tree.getOptimalSemesterOrganization(),
      'maxDepth': tree.maxDepth,
      'rootNodes': tree.rootNodes.map((n) => n.materia.codigoMateria).toList(),
      'leafNodes': tree.leafNodes.map((n) => n.materia.codigoMateria).toList(),
      'cycles': tree.findCycles(),
    };
  }
}
