import 'materia_model.dart';

class ExpressionResult {
  bool isTrue;
  Set<String> matchingMaterias;

  ExpressionResult(this.isTrue, this.matchingMaterias);
}

class EquivalenciaResult {
  bool isEquivalente;
  List<MateriaModel> equivalentes;

  EquivalenciaResult({
    required this.isEquivalente,
    required this.equivalentes,
  });
}

class EquivalenciaModel {
  final int idEquivalencia;
  final String codigoMateriaOrigem;
  final String nomeMateriaOrigem;
  final String codigoMateriaEquivalente;
  final String nomeMateriaEquivalente;
  final String expressao;
  final int? idCurso;
  final String? nomeCurso;
  final String? matrizCurricular;
  final String? curriculo;
  final String? dataVigencia;
  final String? fimVigencia;

  EquivalenciaModel({
    required this.idEquivalencia,
    required this.codigoMateriaOrigem,
    required this.nomeMateriaOrigem,
    required this.codigoMateriaEquivalente,
    required this.nomeMateriaEquivalente,
    required this.expressao,
    this.idCurso,
    this.nomeCurso,
    this.matrizCurricular,
    this.curriculo,
    this.dataVigencia,
    this.fimVigencia,
  });

  factory EquivalenciaModel.fromJson(Map<String, dynamic> json) {
    return EquivalenciaModel(
      idEquivalencia: json["id_equivalencia"],
      codigoMateriaOrigem: json["codigo_materia_origem"] ?? '',
      nomeMateriaOrigem: json["nome_materia_origem"] ?? '',
      codigoMateriaEquivalente: json["codigo_materia_equivalente"] ?? '',
      nomeMateriaEquivalente: json["nome_materia_equivalente"] ?? '',
      expressao: json["expressao"] ?? '',
      idCurso: json["id_curso"],
      nomeCurso: json["nome_curso"] ?? '',
      matrizCurricular: json["matriz_curricular"] ?? '',
      curriculo: json["curriculo"] ?? '',
      dataVigencia: json["data_vigencia"]?.toString() ?? '',
      fimVigencia: json["fim_vigencia"]?.toString() ?? '',
    );
  }

  EquivalenciaResult isMateriaEquivalente(List<MateriaModel> materiasCursadas) {
    // Extract codes from the MateriaModel objects
    Set<String> materias = materiasCursadas.map((m) => m.codigoMateria).toSet();

    var result = _evaluateExpressionWithTracking(expressao.trim(), materias);

    // Filter materiasCursadas to only include those that contributed to the expression being true
    var equivalenteMaterias = materiasCursadas
        .where((materia) =>
            result.matchingMaterias.contains(materia.codigoMateria))
        .toList();

    return EquivalenciaResult(
      isEquivalente: result.isTrue,
      equivalentes: equivalenteMaterias,
    );
  }

  ExpressionResult _evaluateExpressionWithTracking(
      String expression, Set<String> materias) {
    if (expression.isEmpty) return ExpressionResult(false, {});

    // Remove outer parentheses if they exist and encompass the entire expression
    expression = _removeOuterParentheses(expression);

    // Find the main operator (OU has lower precedence than E)
    int? orIndex = _findMainOperator(expression, 'OU');
    if (orIndex != null) {
      String left = expression.substring(0, orIndex).trim();
      String right = expression.substring(orIndex + 2).trim();

      var leftResult = _evaluateExpressionWithTracking(left, materias);
      var rightResult = _evaluateExpressionWithTracking(right, materias);

      // For OR: if either side is true, include materias from true side(s)
      Set<String> matchingMaterias = {};
      if (leftResult.isTrue) {
        matchingMaterias.addAll(leftResult.matchingMaterias);
      }
      if (rightResult.isTrue) {
        matchingMaterias.addAll(rightResult.matchingMaterias);
      }

      return ExpressionResult(
          leftResult.isTrue || rightResult.isTrue, matchingMaterias);
    }

    // Find AND operator
    int? andIndex = _findMainOperator(expression, 'E');
    if (andIndex != null) {
      String left = expression.substring(0, andIndex).trim();
      String right = expression.substring(andIndex + 1).trim();

      var leftResult = _evaluateExpressionWithTracking(left, materias);
      var rightResult = _evaluateExpressionWithTracking(right, materias);

      // For AND: only if both sides are true, include materias from both sides
      if (leftResult.isTrue && rightResult.isTrue) {
        Set<String> matchingMaterias = {};
        matchingMaterias.addAll(leftResult.matchingMaterias);
        matchingMaterias.addAll(rightResult.matchingMaterias);
        return ExpressionResult(true, matchingMaterias);
      } else {
        return ExpressionResult(false, {});
      }
    }

    // If no operators found, it should be a subject code
    String subjectCode = expression.trim();
    bool contains = materias.contains(subjectCode);

    return ExpressionResult(contains, contains ? {subjectCode} : {});
  }

  bool _evaluateExpression(String expression, Set<String> materias) {
    return _evaluateExpressionWithTracking(expression, materias).isTrue;
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
