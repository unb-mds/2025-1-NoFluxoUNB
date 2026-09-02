import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/assinatura_model.dart';
import '../../../core/models/materia_model.dart';
import '../../../core/models/turma_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/periodo_letivo.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/turmas_logic.dart';

/// Colunas do select de turmas + join com `materias` para código/nome
/// (espelha o site). Fonte única: todo select de `turmas` que alimenta um
/// [TurmaModel] (features Turmas e Grade) usa esta lista — enumerada de
/// propósito, `TurmaModel.fromJson` só lê estes campos.
const String kTurmaColunasSelect =
    'id_turmas, id_materia, turma, docente, horario, local, ano_periodo, '
    'vagas_ofertadas, vagas_ocupadas, vagas_sobrando, last_updated_at, '
    'materias(codigo_materia, nome_materia)';

/// Acesso a dados da feature Turmas: busca de matérias, oferta do período
/// atual e as RPCs de assinatura de vagas.
///
/// Interface abstrata para permitir fake nos testes de widget.
abstract class TurmasRepository {
  /// Busca matérias por código ou nome (`ilike` na tabela `materias`).
  /// Termo com menos de [kMinCaracteresBusca] caracteres retorna lista vazia.
  Future<List<MateriaModel>> buscarMaterias(String termo, {int limite = 40});

  /// Período letivo ativo no banco (RPC `periodo_letivo_atual`, ex.: "2026.1").
  Future<String> periodoAtual();

  /// Turmas ofertadas da matéria no período letivo atual, já ordenadas,
  /// com o join de `materias` (código/nome) preenchido.
  Future<List<TurmaModel>> turmasDaMateria(int idMateria);

  /// RPC `seguir_materia` — [turma] null segue qualquer turma da matéria.
  /// Requer usuário autenticado (JWT).
  Future<AssinaturaModel> seguirMateria({
    required int idMateria,
    String? turma,
    required String anoPeriodo,
  });

  /// RPC `deixar_de_seguir_materia`. Requer usuário autenticado.
  Future<void> deixarDeSeguirMateria(int idAssinatura);

  /// RPC `listar_minhas_assinaturas`. Requer usuário autenticado.
  Future<List<AssinaturaModel>> listarMinhasAssinaturas();
}

/// Implementação real sobre o Supabase (anon key + JWT da sessão).
class SupabaseTurmasRepository implements TurmasRepository {
  @override
  Future<List<MateriaModel>> buscarMaterias(
    String termo, {
    int limite = 40,
  }) async {
    final safe = sanitizarTermoBusca(termo);
    if (safe.length < kMinCaracteresBusca) return const [];
    final up = safe.toUpperCase();

    final data = await SupabaseService.client
        .from('materias')
        .select('id_materia, codigo_materia, nome_materia, carga_horaria')
        .or('codigo_materia.ilike.%$up%,nome_materia.ilike.%$safe%')
        .order('codigo_materia', ascending: true)
        .limit(limite);

    return (data as List)
        .map((row) => MateriaModel.fromJson(asMapOrNull(row) ?? const {}))
        .toList();
  }

  @override
  Future<String> periodoAtual() => PeriodoLetivo.atual();

  @override
  Future<List<TurmaModel>> turmasDaMateria(int idMateria) async {
    final periodo = await periodoAtual();
    final data = await SupabaseService.client
        .from('turmas')
        .select(kTurmaColunasSelect)
        .eq('id_materia', idMateria)
        .eq('ano_periodo', periodo)
        .order('turma', ascending: true);

    final turmas = (data as List)
        .map((row) => TurmaModel.fromJson(asMapOrNull(row) ?? const {}))
        .toList();
    return ordenarTurmas(turmas);
  }

  @override
  Future<AssinaturaModel> seguirMateria({
    required int idMateria,
    String? turma,
    required String anoPeriodo,
  }) async {
    final data = await SupabaseService.client.rpc(
      'seguir_materia',
      params: {
        'p_id_materia': idMateria,
        'p_turma': turma,
        'p_ano_periodo': anoPeriodo,
      },
    );
    return AssinaturaModel.fromJson(asMapOrNull(data) ?? const {});
  }

  @override
  Future<void> deixarDeSeguirMateria(int idAssinatura) async {
    await SupabaseService.client.rpc(
      'deixar_de_seguir_materia',
      params: {'p_id_assinatura': idAssinatura},
    );
  }

  @override
  Future<List<AssinaturaModel>> listarMinhasAssinaturas() async {
    final data = await SupabaseService.client.rpc('listar_minhas_assinaturas');
    final assinaturas = asListOr(data)
        .map((row) => AssinaturaModel.fromJson(asMapOrNull(row) ?? const {}))
        .toList();

    // A RPC retorna SETOF vaga_assinaturas — sem código/nome da matéria.
    // Sem este enriquecimento, os cards de "Seguindo" mostrariam "—"/"Matéria"
    // e o usuário não saberia qual assinatura é qual.
    final ids = assinaturas
        .map((a) => a.idMateria)
        .where((id) => id > 0)
        .toSet()
        .toList();
    if (ids.isEmpty) return assinaturas;
    try {
      final rows = await SupabaseService.client
          .from('materias')
          .select('id_materia, codigo_materia, nome_materia')
          .inFilter('id_materia', ids);
      final porId = <int, Map<String, dynamic>>{
        for (final row in asListOr(rows))
          if (asMapOrNull(row) != null)
            parseIntOr(asMapOrNull(row)!['id_materia']): asMapOrNull(row)!,
      };
      return [
        for (final a in assinaturas)
          a.copyWith(
            codigoMateria: parseStringOr(porId[a.idMateria]?['codigo_materia']),
            nomeMateria: parseStringOr(porId[a.idMateria]?['nome_materia']),
          ),
      ];
    } catch (_) {
      // Enriquecimento é cosmético: sem ele a lista ainda funciona.
      return assinaturas;
    }
  }
}

/// Repositório da feature Turmas — override nos testes com um fake.
final turmasRepositoryProvider = Provider<TurmasRepository>(
  (ref) => SupabaseTurmasRepository(),
);
