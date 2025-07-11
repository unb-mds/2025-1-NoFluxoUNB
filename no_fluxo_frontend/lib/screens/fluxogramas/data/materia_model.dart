class MateriaModel {
  String ementa;
  int idMateria;
  String nomeMateria;
  String codigoMateria;
  int nivel;
  int creditos;
  String? status;
  String? mencao;
  String? professor;
  MateriaModel? materiaEquivalenteCursada;
  List<MateriaModel> preRequisitos = [];

  MateriaModel({
    required this.ementa,
    required this.idMateria,
    required this.nomeMateria,
    required this.codigoMateria,
    required this.nivel,
    this.status,
    this.mencao,
    this.professor,
    required this.creditos,
  });

  /// Get prerequisite codes as a list of strings
  List<String> getPrerequisiteCodes() {
    return preRequisitos.map((materia) => materia.codigoMateria).toList();
  }

  /// Get prerequisite names as a list of strings
  List<String> getPrerequisiteNames() {
    return preRequisitos.map((materia) => materia.nomeMateria).toList();
  }

  /// Check if this materia has any prerequisites
  bool hasPrerequisites() {
    return preRequisitos.isNotEmpty;
  }

  /// Check if a specific materia is a prerequisite for this one
  bool hasPrerequisite(String codigoMateria) {
    return preRequisitos
        .any((materia) => materia.codigoMateria == codigoMateria);
  }

  /// Get the total number of prerequisite credits
  int getTotalPrerequisiteCredits() {
    return preRequisitos.fold(0, (sum, materia) => sum + materia.creditos);
  }

  /// Check if this materia can be taken based on completed prerequisite codes
  bool canBeTaken(Set<String> completedMateriasCodes) {
    if (!hasPrerequisites()) return true;

    return preRequisitos.every((prerequisite) =>
        completedMateriasCodes.contains(prerequisite.codigoMateria));
  }

  factory MateriaModel.fromJson(Map<String, dynamic> json) {
    if (json["materias"] == null) {
      return MateriaModel(
        ementa: json["ementa"],
        idMateria: json["id_materia"],
        nomeMateria: json["nome_materia"],
        codigoMateria: json["codigo_materia"],
        creditos: json["carga_horaria"] / 15,
        nivel: json["nivel"] ?? 0,
      );
    }

    return MateriaModel(
      ementa: json["materias"]["ementa"],
      idMateria: json["materias"]["id_materia"],
      nomeMateria: json["materias"]["nome_materia"],
      codigoMateria: json["materias"]["codigo_materia"],
      creditos: json["materias"]["carga_horaria"] / 15,
      nivel: json["nivel"] ?? 0,
    );
  }
}
