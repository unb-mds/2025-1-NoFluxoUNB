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

  factory MateriaModel.fromJson(Map<String, dynamic> json) {
    return MateriaModel(
      ementa: json["materias"]["ementa"],
      idMateria: json["materias"]["id_materia"],
      nomeMateria: json["materias"]["nome_materia"],
      codigoMateria: json["materias"]["codigo_materia"],
      creditos: json["materias"]["carga_horaria"] / 15,
      nivel: json["nivel"],
    );
  }
}
