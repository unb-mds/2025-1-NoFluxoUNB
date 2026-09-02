import '../utils/json_utils.dart';

/// Matéria da matriz curricular de um curso (tabela `materias` +
/// `materias_por_curso`).
///
/// Portado do app legado, sem o acoplamento com cache/SharedPreferences.
class MateriaModel {
  String ementa;
  int idMateria;
  String nomeMateria;
  String codigoMateria;

  /// Semestre sugerido na matriz (0 = optativa/fora da grade sugerida).
  int nivel;
  int creditos;
  String? status;
  String? mencao;
  String? professor;

  /// Pré-requisitos DIRETOS, preenchidos por
  /// `CursoModel.populatePrerequisites()`. A produção usa
  /// `CursoModel.getDirectPrerequisites`; este campo é mantido porque testes
  /// de fluxograma dependem dele.
  List<MateriaModel> preRequisitos = [];

  MateriaModel({
    required this.ementa,
    required this.idMateria,
    required this.nomeMateria,
    required this.codigoMateria,
    required this.nivel,
    required this.creditos,
    this.status,
    this.mencao,
    this.professor,
  });

  /// Aceita tanto a linha achatada de `materias` quanto o shape aninhado de
  /// `materias_por_curso` (`{ nivel, materias: {...} }`).
  factory MateriaModel.fromJson(Map<String, dynamic> json) {
    final dados = asMapOrNull(json['materias']) ?? json;
    // Créditos = carga horária / 15 (padrão UnB).
    final cargaHoraria = parseIntOr(dados['carga_horaria']);
    return MateriaModel(
      ementa: parseStringOr(dados['ementa']),
      idMateria: parseIntOr(dados['id_materia']),
      nomeMateria: parseStringOr(dados['nome_materia']),
      codigoMateria: parseStringOr(dados['codigo_materia']),
      creditos: cargaHoraria ~/ 15,
      nivel: parseIntOr(json['nivel']),
    );
  }

  /// Códigos dos pré-requisitos diretos.
  List<String> getPrerequisiteCodes() =>
      preRequisitos.map((materia) => materia.codigoMateria).toList();
}
