import '../utils/json_utils.dart';

/// Turma ofertada no semestre (tabela `turmas` do Supabase).
///
/// [codigoMateria]/[nomeMateria] são opcionais e vêm do join com `materias`
/// (`turmas.select('*, materias(codigo_materia, nome_materia)')`).
class TurmaModel {
  final int idTurmas;
  final int idMateria;
  final String turma;
  final String? docente;

  /// Horário no formato SIGAA (ex.: "246M12 35T34"). Pode ser nulo/EAD.
  final String? horario;
  final String? local;
  final String anoPeriodo;
  final int? vagasOfertadas;
  final int? vagasOcupadas;
  final int? vagasSobrando;
  final DateTime? lastUpdatedAt;
  final String? codigoMateria;
  final String? nomeMateria;

  const TurmaModel({
    required this.idTurmas,
    required this.idMateria,
    required this.turma,
    this.docente,
    this.horario,
    this.local,
    required this.anoPeriodo,
    this.vagasOfertadas,
    this.vagasOcupadas,
    this.vagasSobrando,
    this.lastUpdatedAt,
    this.codigoMateria,
    this.nomeMateria,
  });

  factory TurmaModel.fromJson(Map<String, dynamic> json) {
    // Join aninhado com `materias`, quando presente.
    final materia = asMapOrNull(json['materias']);
    return TurmaModel(
      idTurmas: parseIntOr(json['id_turmas'] ?? json['id_turma']),
      idMateria: parseIntOr(json['id_materia']),
      turma: parseStringOr(json['turma']),
      docente: parseStringOrNull(json['docente']),
      horario: parseStringOrNull(json['horario']),
      local: parseStringOrNull(json['local']),
      anoPeriodo: parseStringOr(json['ano_periodo']),
      vagasOfertadas: parseIntOrNull(json['vagas_ofertadas']),
      vagasOcupadas: parseIntOrNull(json['vagas_ocupadas']),
      vagasSobrando: parseIntOrNull(json['vagas_sobrando']),
      lastUpdatedAt: parseDateTimeOrNull(json['last_updated_at']),
      codigoMateria: parseStringOrNull(
        materia?['codigo_materia'] ?? json['codigo_materia'],
      ),
      nomeMateria: parseStringOrNull(
        materia?['nome_materia'] ?? json['nome_materia'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_turmas': idTurmas,
      'id_materia': idMateria,
      'turma': turma,
      'docente': docente,
      'horario': horario,
      'local': local,
      'ano_periodo': anoPeriodo,
      'vagas_ofertadas': vagasOfertadas,
      'vagas_ocupadas': vagasOcupadas,
      'vagas_sobrando': vagasSobrando,
      'last_updated_at': lastUpdatedAt?.toIso8601String(),
      if (codigoMateria != null) 'codigo_materia': codigoMateria,
      if (nomeMateria != null) 'nome_materia': nomeMateria,
    };
  }

  /// Tem vaga sobrando? Null (dado desconhecido) conta como não.
  bool get temVagas => (vagasSobrando ?? 0) > 0;
}
