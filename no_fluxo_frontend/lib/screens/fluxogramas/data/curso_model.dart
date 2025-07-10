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

    return curso;
  }

  /// Build prerequisite tree for this course
  PrerequisiteTree buildPrerequisiteTree() {
    return PrerequisiteTree.fromCourse(this);
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
