import 'materia_model.dart';

class CursoModel {
  String nomeCurso;
  String matrizCurricular;
  int? totalCreditos;
  List<MateriaModel> materias;
  int semestres;

  CursoModel({
    required this.nomeCurso,
    required this.matrizCurricular,
    required this.totalCreditos,
    required this.materias,
    required this.semestres,
  });

  factory CursoModel.fromJson(Map<String, dynamic> json) {
    var curso = CursoModel(
      nomeCurso: json["nome_curso"],
      matrizCurricular: json["matriz_curricular"],
      totalCreditos: json["creditos"],
      materias: List<MateriaModel>.from(json["materias_por_curso"]
          .map((materia) => MateriaModel.fromJson(materia))),
          semestres: 0
    );

    int maxSemestre = 0;
    for (var materia in curso.materias) {
      if (materia.nivel > maxSemestre) {
        maxSemestre = materia.nivel;
      }
    }

    curso.semestres = maxSemestre;

    return curso;
  }
}
