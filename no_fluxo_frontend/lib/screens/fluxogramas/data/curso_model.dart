import 'materia_model.dart';

class EquivalenciaModel {
  String expressao;
  int idMateria;
  MateriaModel materia;

  EquivalenciaModel({
    required this.expressao,
    required this.idMateria,
    required this.materia,
  });

  factory EquivalenciaModel.fromJson(Map<String, dynamic> json) {
    return EquivalenciaModel(
      expressao: json["expressao"],
      idMateria: json["id_materia"],
      materia: MateriaModel.fromJson(json),
    );
  }

  bool isMateriaEquivalente(Set<String> materias) {
    return _evaluateExpression(expressao.trim(), materias);
  }

  bool _evaluateExpression(String expression, Set<String> materias) {
    if (expression.isEmpty) return false;

    // Remove outer parentheses if they exist and encompass the entire expression
    expression = _removeOuterParentheses(expression);

    // Find the main operator (OU has lower precedence than E)
    int? orIndex = _findMainOperator(expression, 'OU');
    if (orIndex != null) {
      String left = expression.substring(0, orIndex).trim();
      String right = expression.substring(orIndex + 2).trim();
      return _evaluateExpression(left, materias) ||
          _evaluateExpression(right, materias);
    }

    // Find AND operator
    int? andIndex = _findMainOperator(expression, 'E');
    if (andIndex != null) {
      String left = expression.substring(0, andIndex).trim();
      String right = expression.substring(andIndex + 1).trim();
      return _evaluateExpression(left, materias) &&
          _evaluateExpression(right, materias);
    }

    // If no operators found, it should be a subject code
    String subjectCode = expression.trim();

    return materias.contains(subjectCode);
  }

  String _removeOuterParentheses(String expression) {
    String trimmed = expression.trim();
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      // Check if these parentheses actually encompass the entire expression
      int count = 0;
      for (int i = 0; i < trimmed.length; i++) {
        if (trimmed[i] == '(') count++;
        if (trimmed[i] == ')') count--;
        if (count == 0 && i < trimmed.length - 1) {
          // Parentheses close before the end, so they don't encompass everything
          return trimmed;
        }
      }
      // They do encompass everything, remove them
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  int? _findMainOperator(String expression, String operator) {
    int parenthesesCount = 0;
    int operatorLength = operator.length;

    for (int i = expression.length - operatorLength; i >= 0; i--) {
      // Count parentheses from right to left
      if (expression[i] == ')') parenthesesCount++;
      if (expression[i] == '(') parenthesesCount--;

      // Check if we found the operator at the top level (outside parentheses)
      if (parenthesesCount == 0 &&
          i + operatorLength <= expression.length &&
          expression.substring(i, i + operatorLength) == operator) {
        // Make sure it's a whole word (surrounded by spaces or parentheses)
        bool validBefore =
            i == 0 || expression[i - 1] == ' ' || expression[i - 1] == ')';
        bool validAfter = i + operatorLength == expression.length ||
            expression[i + operatorLength] == ' ' ||
            expression[i + operatorLength] == '(';

        if (validBefore && validAfter) {
          return i;
        }
      }
    }
    return null;
  }
}

class CursoModel {
  String nomeCurso;
  String matrizCurricular;
  int? totalCreditos;
  String classificacao;
  String tipoCurso;
  List<MateriaModel> materias;
  int semestres;
  List<EquivalenciaModel> equivalencias;

  CursoModel({
    required this.nomeCurso,
    required this.matrizCurricular,
    required this.totalCreditos,
    required this.classificacao,
    required this.tipoCurso,
    required this.materias,
    required this.semestres,
    this.equivalencias = const [],
  });

  factory CursoModel.fromMinimalJson(Map<String, dynamic> json) {
    return CursoModel(
      nomeCurso: json["nome_curso"],
      matrizCurricular: json["matriz_curricular"],
      totalCreditos: json["creditos"],
      tipoCurso: json["tipo_curso"] ?? "outro",
      classificacao: json["classificacao"] ?? "outro",
      materias: [],
      semestres: 0,
      equivalencias: [],
    );
  }

  factory CursoModel.fromJson(Map<String, dynamic> json) {
    var curso = CursoModel(
        nomeCurso: json["nome_curso"],
        matrizCurricular: json["matriz_curricular"],
        totalCreditos: json["creditos"],
        tipoCurso: json["tipo_curso"],
        classificacao: json["classificacao"],
        materias: List<MateriaModel>.from(json["materias_por_curso"]
            .map((materia) => MateriaModel.fromJson(materia))),
        semestres: 0,
        equivalencias: json["equivalencias"] != null
            ? List<EquivalenciaModel>.from(json["equivalencias"]
                .map((equiv) => EquivalenciaModel.fromJson(equiv)))
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
}
