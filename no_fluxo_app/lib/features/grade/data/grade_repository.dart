/// Repositório da grade horária do aluno.
///
/// Duas fontes compõem a grade:
///  1. **Automática** — matérias com status MATR no fluxograma do aluno
///     (`dados_users.fluxograma_atual`), casadas com a oferta da tabela
///     `turmas` no período letivo ativo (RPC `periodo_letivo_atual`);
///  2. **Manual** — turmas que o aluno adicionou pelo botão "+ turma",
///     persistidas localmente em `shared_preferences`.
///
/// ### Formato da persistência local (fonte manual)
/// Chave: `grade_manual_v1_<idUser>_<periodo>` (ex.: `grade_manual_v1_42_2026.1`;
/// visitante usa idUser 0). Valor: JSON string
/// ```json
/// {"versao": 1, "turmas": [ <TurmaModel.toJson()>, ... ]}
/// ```
/// Guardar o `TurmaModel` inteiro permite exibir a grade manual offline.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/turma_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/periodo_letivo.dart';
import '../../../core/utils/busca.dart';
import '../../../core/utils/json_utils.dart';
import '../../turmas/data/turmas_repository.dart' show kTurmaColunasSelect;
import '../../turmas/domain/turmas_logic.dart' show ordenarTurmas;
import '../domain/grade_builder.dart';

/// Resultado da busca de matéria para o "+ turma".
class MateriaBusca {
  final int idMateria;
  final String codigo;
  final String nome;

  const MateriaBusca({
    required this.idMateria,
    required this.codigo,
    required this.nome,
  });
}

/// Contrato do repositório — a UI depende só disto (fácil de falsificar em
/// widget tests).
abstract class GradeRepository {
  /// Carrega a grade completa (fonte automática + manual), sem duplicar
  /// turma presente nas duas fontes (a automática prevalece).
  Future<List<TurmaGrade>> carregarGrade({
    DadosFluxogramaUser? dados,
    required int idUser,
  });

  /// Grava uma turma na grade manual (substitui se o `idTurmas` já existir).
  Future<void> adicionarTurmaManual({
    required int idUser,
    required TurmaModel turma,
  });

  /// Remove uma turma da grade manual.
  Future<void> removerTurmaManual({required int idUser, required int idTurmas});

  /// Busca global de matérias por código ou nome (mínimo
  /// [kMinCaracteresBusca] caracteres).
  Future<List<MateriaBusca>> buscarMaterias(String query);

  /// Turmas ofertadas de uma matéria no período letivo ativo.
  Future<List<TurmaModel>> turmasDaMateria(int idMateria);
}

/// Implementação real: Supabase (fontes remotas) + shared_preferences
/// (grade manual).
class SupabaseGradeRepository implements GradeRepository {
  /// Período fixo para testes (pula a RPC `periodo_letivo_atual`).
  final String? periodoFixo;

  SupabaseGradeRepository({this.periodoFixo});

  // ── Período letivo ─────────────────────────────────────────────────────────

  /// Período letivo ativo (ex.: "2026.1") — fonte única no core, com cache e
  /// fallback pela data local embutidos.
  Future<String> _periodoAtivo() async {
    if (periodoFixo != null) return periodoFixo!;
    return PeriodoLetivo.atual();
  }

  // ── Fonte 1: matérias MATR do fluxograma ───────────────────────────────────

  /// Casa os pares (código, turma) do fluxograma com a oferta do período.
  Future<List<TurmaModel>> _turmasDoFluxograma(
    DadosFluxogramaUser dados,
    String periodo,
  ) async {
    final pares = materiasEmCursoComTurma(dados);
    if (pares.isEmpty) return const [];

    // Resolve código → id_materia.
    final codigos = pares.map((p) => p.codigo).toSet().toList();
    final materias = await SupabaseService.client
        .from('materias')
        .select('id_materia, codigo_materia')
        .inFilter('codigo_materia', codigos);
    final idPorCodigo = <String, int>{
      for (final m in asListOr(materias))
        if (asMapOrNull(m) != null)
          parseStringOr(asMapOrNull(m)!['codigo_materia']).trim().toUpperCase():
              parseIntOr(asMapOrNull(m)!['id_materia']),
    };
    if (idPorCodigo.isEmpty) return const [];

    final rows = await SupabaseService.client
        .from('turmas')
        .select(kTurmaColunasSelect)
        .inFilter('id_materia', idPorCodigo.values.toList())
        .eq('ano_periodo', periodo);

    final ofertadas = [
      for (final row in asListOr(rows))
        if (asMapOrNull(row) != null) TurmaModel.fromJson(asMapOrNull(row)!),
    ];

    // Só entra a turma exata em que o aluno está matriculado.
    final chavesAluno = {for (final p in pares) '${p.codigo}|${p.turma}'};
    return ofertadas
        .where(
          (t) => chavesAluno.contains(
            '${(t.codigoMateria ?? '').trim().toUpperCase()}'
            '|${t.turma.trim().toUpperCase()}',
          ),
        )
        .toList();
  }

  // ── Fonte 2: grade manual em shared_preferences ────────────────────────────

  String _chaveManual(int idUser, String periodo) =>
      'grade_manual_v1_${idUser}_$periodo';

  Future<List<TurmaModel>> _carregarManuais(int idUser, String periodo) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chaveManual(idUser, periodo));
    final map = decodeJsonMap(raw);
    if (map == null) return const [];
    return [
      for (final item in asListOr(map['turmas']))
        if (asMapOrNull(item) != null) TurmaModel.fromJson(asMapOrNull(item)!),
    ];
  }

  Future<void> _salvarManuais(
    int idUser,
    String periodo,
    List<TurmaModel> turmas,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chaveManual(idUser, periodo),
      jsonEncode({
        'versao': 1,
        'turmas': turmas.map((t) => t.toJson()).toList(),
      }),
    );
  }

  @override
  Future<void> adicionarTurmaManual({
    required int idUser,
    required TurmaModel turma,
  }) async {
    final periodo = await _periodoAtivo();
    final atuais = await _carregarManuais(idUser, periodo);
    final novas = [
      for (final t in atuais)
        if (t.idTurmas != turma.idTurmas) t,
      turma,
    ];
    await _salvarManuais(idUser, periodo, novas);
  }

  @override
  Future<void> removerTurmaManual({
    required int idUser,
    required int idTurmas,
  }) async {
    final periodo = await _periodoAtivo();
    final atuais = await _carregarManuais(idUser, periodo);
    await _salvarManuais(
      idUser,
      periodo,
      atuais.where((t) => t.idTurmas != idTurmas).toList(),
    );
  }

  // ── Grade completa ─────────────────────────────────────────────────────────

  @override
  Future<List<TurmaGrade>> carregarGrade({
    DadosFluxogramaUser? dados,
    required int idUser,
  }) async {
    final periodo = await _periodoAtivo();

    // As duas fontes são independentes entre si — carrega em paralelo.
    Future<List<TurmaModel>> automaticasOuVazio() async {
      if (dados == null) return const [];
      try {
        return await _turmasDoFluxograma(dados, periodo);
      } catch (e) {
        // Sem rede/erro remoto: a grade manual (local) ainda deve aparecer.
        debugPrint('Grade: falha ao carregar turmas do fluxograma: $e');
        return const [];
      }
    }

    final fontes = await Future.wait([
      automaticasOuVazio(),
      _carregarManuais(idUser, periodo),
    ]);
    final automaticas = fontes[0];
    final manuais = fontes[1];

    final idsAutomaticas = automaticas.map((t) => t.idTurmas).toSet();
    return [
      for (final t in automaticas) TurmaGrade(turma: t),
      for (final t in manuais)
        if (!idsAutomaticas.contains(t.idTurmas))
          TurmaGrade(turma: t, manual: true),
    ];
  }

  // ── Busca para o "+ turma" ─────────────────────────────────────────────────

  @override
  Future<List<MateriaBusca>> buscarMaterias(String query) async {
    final safe = sanitizarTermoBusca(query);
    if (safe.length < kMinCaracteresBusca) return const [];
    final up = safe.toUpperCase();

    final rows = await SupabaseService.client
        .from('materias')
        .select('id_materia, codigo_materia, nome_materia')
        .or('codigo_materia.ilike.%$up%,nome_materia.ilike.%$safe%')
        .order('codigo_materia', ascending: true)
        .limit(30);

    return [
      for (final row in asListOr(rows))
        if (asMapOrNull(row) != null)
          MateriaBusca(
            idMateria: parseIntOr(asMapOrNull(row)!['id_materia']),
            codigo: parseStringOr(asMapOrNull(row)!['codigo_materia']),
            nome: parseStringOr(asMapOrNull(row)!['nome_materia']),
          ),
    ];
  }

  @override
  Future<List<TurmaModel>> turmasDaMateria(int idMateria) async {
    final periodo = await _periodoAtivo();
    final rows = await SupabaseService.client
        .from('turmas')
        .select(kTurmaColunasSelect)
        .eq('id_materia', idMateria)
        .eq('ano_periodo', periodo)
        .order('turma', ascending: true);

    // Mesma ordenação da feature Turmas (alfabética com desempate estável).
    return ordenarTurmas([
      for (final row in asListOr(rows))
        if (asMapOrNull(row) != null) TurmaModel.fromJson(asMapOrNull(row)!),
    ]);
  }
}

/// Repositório da grade (override em testes com um fake).
final gradeRepositoryProvider = Provider<GradeRepository>(
  (ref) => SupabaseGradeRepository(),
);
