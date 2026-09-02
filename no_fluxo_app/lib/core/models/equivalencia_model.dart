import '../utils/json_utils.dart';
import 'materia_model.dart';

/// Resultado da avaliação de uma expressão de equivalência.
class ExpressionResult {
  final bool isTrue;
  final Set<String> matchingMaterias;

  ExpressionResult(this.isTrue, this.matchingMaterias);
}

/// Resultado de [EquivalenciaModel.isMateriaEquivalente].
class EquivalenciaResult {
  final bool isEquivalente;
  final List<MateriaModel> equivalentes;

  EquivalenciaResult({required this.isEquivalente, required this.equivalentes});
}

/// Regra de equivalência do SIGAA (tabela `equivalencias`).
///
/// A [expressao] usa a sintaxe do SIGAA com operadores "E"/"OU" e parênteses,
/// ex.: `( FGA0158 E FGA0161 ) OU MAT0025`.
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
      idEquivalencia: parseIntOr(json['id_equivalencia']),
      codigoMateriaOrigem: parseStringOr(json['codigo_materia_origem']),
      nomeMateriaOrigem: parseStringOr(json['nome_materia_origem']),
      codigoMateriaEquivalente: parseStringOr(
        json['codigo_materia_equivalente'],
      ),
      nomeMateriaEquivalente: parseStringOr(json['nome_materia_equivalente']),
      expressao: parseStringOr(json['expressao']),
      idCurso: parseIntOrNull(json['id_curso']),
      nomeCurso: parseStringOrNull(json['nome_curso']),
      matrizCurricular: parseStringOrNull(json['matriz_curricular']),
      curriculo: parseStringOrNull(json['curriculo']),
      dataVigencia: parseStringOrNull(json['data_vigencia']),
      fimVigencia: parseStringOrNull(json['fim_vigencia']),
    );
  }

  /// As matérias cursadas satisfazem esta equivalência? Retorna também quais
  /// matérias contribuíram para a expressão ser verdadeira.
  EquivalenciaResult isMateriaEquivalente(List<MateriaModel> materiasCursadas) {
    final materias = materiasCursadas.map((m) => m.codigoMateria).toSet();
    final result = _evaluateExpressionWithTracking(expressao.trim(), materias);

    final equivalentes = materiasCursadas
        .where(
          (materia) => result.matchingMaterias.contains(materia.codigoMateria),
        )
        .toList();

    return EquivalenciaResult(
      isEquivalente: result.isTrue,
      equivalentes: equivalentes,
    );
  }

  ExpressionResult _evaluateExpressionWithTracking(
    String expression,
    Set<String> materias,
  ) {
    if (expression.isEmpty) return ExpressionResult(false, {});

    expression = _removeOuterParentheses(expression);

    // OU tem precedência menor que E — avalia primeiro.
    final orIndex = _findMainOperator(expression, 'OU');
    if (orIndex != null) {
      final left = expression.substring(0, orIndex).trim();
      final right = expression.substring(orIndex + 2).trim();

      final leftResult = _evaluateExpressionWithTracking(left, materias);
      final rightResult = _evaluateExpressionWithTracking(right, materias);

      final matching = <String>{};
      if (leftResult.isTrue) matching.addAll(leftResult.matchingMaterias);
      if (rightResult.isTrue) matching.addAll(rightResult.matchingMaterias);

      return ExpressionResult(
        leftResult.isTrue || rightResult.isTrue,
        matching,
      );
    }

    final andIndex = _findMainOperator(expression, 'E');
    if (andIndex != null) {
      final left = expression.substring(0, andIndex).trim();
      final right = expression.substring(andIndex + 1).trim();

      final leftResult = _evaluateExpressionWithTracking(left, materias);
      final rightResult = _evaluateExpressionWithTracking(right, materias);

      if (leftResult.isTrue && rightResult.isTrue) {
        return ExpressionResult(true, {
          ...leftResult.matchingMaterias,
          ...rightResult.matchingMaterias,
        });
      }
      return ExpressionResult(false, {});
    }

    // Sem operadores: deve ser um código de matéria.
    final subjectCode = expression.trim();
    final contains = materias.contains(subjectCode);
    return ExpressionResult(contains, contains ? {subjectCode} : {});
  }

  String _removeOuterParentheses(String expression) {
    final trimmed = expression.trim();
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      // Só remove se os parênteses englobam a expressão inteira.
      var count = 0;
      for (var i = 0; i < trimmed.length; i++) {
        if (trimmed[i] == '(') count++;
        if (trimmed[i] == ')') count--;
        if (count == 0 && i < trimmed.length - 1) return trimmed;
      }
      return trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  int? _findMainOperator(String expression, String operator) {
    var parenthesesCount = 0;
    final operatorLength = operator.length;

    // Varre do ÚLTIMO caractere (não de length - operatorLength): começar
    // adiantado pulava o ')' final e deslocava a contagem de parênteses em
    // expressões terminadas em ')' — "A OU ( B )" nunca achava o "OU".
    for (var i = expression.length - 1; i >= 0; i--) {
      if (expression[i] == ')') parenthesesCount++;
      if (expression[i] == '(') parenthesesCount--;

      if (parenthesesCount == 0 &&
          i + operatorLength <= expression.length &&
          expression.substring(i, i + operatorLength) == operator) {
        // Precisa ser palavra inteira (cercada por espaços ou parênteses).
        final validBefore =
            i == 0 || expression[i - 1] == ' ' || expression[i - 1] == ')';
        final validAfter =
            i + operatorLength == expression.length ||
            expression[i + operatorLength] == ' ' ||
            expression[i + operatorLength] == '(';

        if (validBefore && validAfter) return i;
      }
    }
    return null;
  }
}
