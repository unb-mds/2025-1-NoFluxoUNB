import '../utils/json_utils.dart';

/// Assinatura de alerta de vagas (shape da RPC `listar_minhas_assinaturas`).
///
/// O usuário assina uma matéria (opcionalmente uma turma específica) e recebe
/// notificação quando abre vaga.
class AssinaturaModel {
  final int idAssinatura;
  final int idMateria;
  final String? codigoMateria;
  final String? nomeMateria;

  /// Turma específica assinada; null = qualquer turma da matéria.
  final String? turma;
  final String anoPeriodo;
  final bool ativa;

  const AssinaturaModel({
    required this.idAssinatura,
    required this.idMateria,
    this.codigoMateria,
    this.nomeMateria,
    this.turma,
    required this.anoPeriodo,
    this.ativa = true,
  });

  factory AssinaturaModel.fromJson(Map<String, dynamic> json) {
    return AssinaturaModel(
      idAssinatura: parseIntOr(json['id_assinatura']),
      idMateria: parseIntOr(json['id_materia']),
      codigoMateria: parseStringOrNull(json['codigo_materia']),
      nomeMateria: parseStringOrNull(json['nome_materia']),
      turma: parseStringOrNull(json['turma']),
      anoPeriodo: parseStringOr(json['ano_periodo']),
      ativa: parseBoolOr(json['ativa'], true),
    );
  }

  /// Cópia com código/nome preenchidos (enriquecimento pós-RPC — a
  /// `listar_minhas_assinaturas` retorna só o `id_materia`). Valores vazios
  /// não sobrescrevem.
  AssinaturaModel copyWith({String? codigoMateria, String? nomeMateria}) {
    return AssinaturaModel(
      idAssinatura: idAssinatura,
      idMateria: idMateria,
      codigoMateria: (codigoMateria?.isNotEmpty ?? false)
          ? codigoMateria
          : this.codigoMateria,
      nomeMateria: (nomeMateria?.isNotEmpty ?? false)
          ? nomeMateria
          : this.nomeMateria,
      turma: turma,
      anoPeriodo: anoPeriodo,
      ativa: ativa,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_assinatura': idAssinatura,
      'id_materia': idMateria,
      if (codigoMateria != null) 'codigo_materia': codigoMateria,
      if (nomeMateria != null) 'nome_materia': nomeMateria,
      'turma': turma,
      'ano_periodo': anoPeriodo,
      'ativa': ativa,
    };
  }
}
