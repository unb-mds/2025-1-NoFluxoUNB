import 'dart:convert';

import '../utils/json_utils.dart';
import 'equivalencia_model.dart';
import 'materia_model.dart';

/// Pré-requisito entre matérias (tabela `pre_requisitos`).
class PreRequisitoModel {
  int idPreRequisito;
  int idMateria;
  int idMateriaRequisito;
  String codigoMateriaRequisito;
  String nomeMateriaRequisito;

  /// Texto SIGAA original do pré-requisito, ex.: `( CIC0001 OU CIC0002 ) E
  /// MAT0025`. Null quando a linha é do formato antigo (só o código do join).
  String? expressaoOriginal;

  /// Árvore E/OU do jsonb `expressao_logica`, já decodificada. Formatos
  /// aceitos (os mesmos do site em `expressao-logica.ts`):
  /// - `String` — um código de matéria ou expressão textual;
  /// - `{"operador": "OU"|"E", "condicoes": [...]}` — recursivo;
  /// - `{"materias": [...], "operador": "OU"|"E"|null}` — legado.
  dynamic expressaoLogica;

  PreRequisitoModel({
    required this.idPreRequisito,
    required this.idMateria,
    required this.idMateriaRequisito,
    required this.codigoMateriaRequisito,
    required this.nomeMateriaRequisito,
    this.expressaoOriginal,
    this.expressaoLogica,
  });

  factory PreRequisitoModel.fromJson(Map<String, dynamic> json) {
    return PreRequisitoModel(
      idPreRequisito: parseIntOr(json['id_pre_requisito']),
      idMateria: parseIntOr(json['id_materia']),
      idMateriaRequisito: parseIntOr(json['id_materia_requisito']),
      codigoMateriaRequisito: parseStringOr(json['codigo_materia_requisito']),
      nomeMateriaRequisito: parseStringOr(json['nome_materia_requisito']),
      expressaoOriginal: parseStringOrNull(json['expressao_original']),
      expressaoLogica: parseExpressaoLogica(json['expressao_logica']),
    );
  }

  /// Verdadeiro quando a linha carrega uma expressão (jsonb ou texto) — o
  /// caminho novo do banco, sem `id_materia_requisito`.
  bool get temExpressao =>
      expressaoLogica != null ||
      (expressaoOriginal?.trim().isNotEmpty ?? false);

  /// Normaliza o valor cru de `expressao_logica` (o Supabase pode devolver o
  /// jsonb já decodificado ou como String JSON). Retorna Map/List/String ou
  /// null quando não há expressão utilizável.
  ///
  /// Segue o factory do site (parseExpressaoLogica em factories/index.ts):
  /// - `{}` (o DEFAULT da coluna em linhas legadas) e `[]` viram null — sem
  ///   isso, a linha legada com só o join de código nunca cairia no fallback
  ///   e o pré-requisito avaliaria como falso para sempre;
  /// - aspas envolventes de valor duplamente codificado (`"MAT0026"`) são
  ///   removidas, dado real citado pelo próprio site.
  static dynamic parseExpressaoLogica(dynamic valor) {
    if (valor == null) return null;
    if (valor is Map) {
      return (valor.containsKey('condicoes') || valor.containsKey('materias'))
          ? valor
          : null;
    }
    if (valor is List) return valor.isEmpty ? null : valor;
    if (valor is String) {
      var texto = valor.trim();
      // Remove aspas em volta (ex.: "MAT0026" ou \"MAT0026\").
      while (texto.length >= 2 &&
          ((texto.startsWith('"') && texto.endsWith('"')) ||
              (texto.startsWith(r'\"') && texto.endsWith(r'\"')))) {
        texto = texto.startsWith(r'\"')
            ? texto.substring(2, texto.length - 2).trim()
            : texto.substring(1, texto.length - 1).trim();
      }
      if (texto.isEmpty) return null;
      if (texto.startsWith('{') || texto.startsWith('[')) {
        try {
          return parseExpressaoLogica(jsonDecode(texto));
        } on FormatException {
          return null;
        }
      }
      return texto;
    }
    return null;
  }
}

/// Curso + matriz curricular (tabela `cursos` com joins).
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

  /// Shape mínimo usado em listagens de curso (sem matérias).
  factory CursoModel.fromMinimalJson(Map<String, dynamic> json) {
    return CursoModel(
      nomeCurso: parseStringOr(json['nome_curso']),
      matrizCurricular: parseStringOr(json['matriz_curricular']),
      idCurso: parseIntOr(json['id_curso']),
      totalCreditos: parseIntOrNull(json['creditos']),
      tipoCurso: parseStringOr(json['tipo_curso'], 'outro'),
      classificacao: parseStringOr(json['classificacao'], 'outro'),
      materias: [],
      semestres: 0,
    );
  }

  factory CursoModel.fromJson(Map<String, dynamic> json) {
    final materias = <MateriaModel>[];
    for (final materia in asListOr(json['materias_por_curso'])) {
      final map = asMapOrNull(materia);
      if (map != null) materias.add(MateriaModel.fromJson(map));
    }

    final equivalencias = <EquivalenciaModel>[];
    for (final equiv in asListOr(json['equivalencias'])) {
      final map = asMapOrNull(equiv);
      if (map != null) equivalencias.add(EquivalenciaModel.fromJson(map));
    }

    final curso = CursoModel(
      nomeCurso: parseStringOr(json['nome_curso']),
      matrizCurricular: parseStringOr(json['matriz_curricular']),
      idCurso: parseIntOr(json['id_curso']),
      totalCreditos: parseIntOrNull(json['creditos']),
      tipoCurso: parseStringOr(json['tipo_curso'], 'outro'),
      classificacao: parseStringOr(json['classificacao'], 'outro'),
      materias: materias,
      semestres: 0,
      equivalencias: equivalencias,
    );

    var maxSemestre = 0;
    for (final materia in curso.materias) {
      if (materia.nivel > maxSemestre) maxSemestre = materia.nivel;
    }
    curso.semestres = maxSemestre;

    // Só mantém pré-requisitos cuja matéria requisito está na matriz (mesma
    // regra do app legado — matérias de nível 0 são optativas).
    final codigosNaMatriz = curso.materias
        .where((materia) => materia.nivel != 0)
        .map((materia) => materia.codigoMateria)
        .toSet();

    final preRequisitos = <PreRequisitoModel>[];
    for (final item in asListOr(json['pre_requisitos'])) {
      final map = asMapOrNull(item);
      if (map == null) continue;
      final preRequisito = PreRequisitoModel.fromJson(map);
      // Linhas com expressão (formato novo do banco, sem
      // id_materia_requisito) sempre entram: a avaliação E/OU acontece contra
      // o histórico completo do aluno, mesmo que o requisito não esteja na
      // matriz — mesma regra do site (factories/index.ts).
      if (preRequisito.temExpressao ||
          codigosNaMatriz.contains(preRequisito.codigoMateriaRequisito)) {
        preRequisitos.add(preRequisito);
      }
    }
    curso.preRequisitos = preRequisitos;

    curso.populatePrerequisites();

    return curso;
  }

  /// Preenche `materia.preRequisitos` com os pré-requisitos DIRETOS a partir
  /// da lista crua de [preRequisitos].
  ///
  /// A produção lê os diretos por [getDirectPrerequisites] (a UI) e a lista
  /// crua [preRequisitos] (o resolver de status); este método existe porque o
  /// fromJson o chama e testes de fluxograma dependem do campo
  /// `MateriaModel.preRequisitos` preenchido. O fecho transitivo (indiretos)
  /// que existia aqui foi removido: nenhum código o lia.
  void populatePrerequisites() {
    for (final materia in materias) {
      materia.preRequisitos.clear();
    }

    final materiaPorCodigo = <String, MateriaModel>{
      for (final materia in materias) materia.codigoMateria: materia,
    };
    final materiaPorId = <int, MateriaModel>{
      for (final materia in materias) materia.idMateria: materia,
    };

    for (final preReq in preRequisitos) {
      // Defensivo: id fora da matriz é ignorado (o legado estourava aqui).
      final alvo = materiaPorId[preReq.idMateria];
      final prereq = materiaPorCodigo[preReq.codigoMateriaRequisito];
      if (alvo != null && prereq != null) {
        alvo.preRequisitos.add(prereq);
      }
    }
  }

  /// Pré-requisitos diretos de uma matéria (sem os indiretos).
  List<MateriaModel> getDirectPrerequisites(String materiaCode) {
    final materiaPorCodigo = <String, MateriaModel>{
      for (final materia in materias) materia.codigoMateria: materia,
    };
    final materiaPorId = <int, MateriaModel>{
      for (final materia in materias) materia.idMateria: materia,
    };

    final directPrereqs = <MateriaModel>[];
    for (final preReq in preRequisitos) {
      final alvo = materiaPorId[preReq.idMateria];
      if (alvo == null || alvo.codigoMateria != materiaCode) continue;
      final prereq = materiaPorCodigo[preReq.codigoMateriaRequisito];
      if (prereq != null) directPrereqs.add(prereq);
    }
    return directPrereqs;
  }
}
