import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/curso_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/json_utils.dart';

/// Curso resumido (para o seletor de curso do visitante).
class CursoResumo {
  final int idCurso;
  final String nomeCurso;

  /// Turno/campus para distinguir cursos homônimos no seletor (a UnB tem
  /// "SERVICO SOCIAL" diurno E noturno, por exemplo). Vazios quando o banco
  /// não informa.
  final String turno;
  final String campus;

  const CursoResumo({
    required this.idCurso,
    required this.nomeCurso,
    this.turno = '',
    this.campus = '',
  });

  /// Complemento exibido abaixo do nome ("Diurno • Darcy Ribeiro"), ou vazio.
  String get detalhe =>
      [turno, campus].where((p) => p.trim().isNotEmpty).join(' • ');
}

/// Matriz curricular resumida (identificada por `curriculo_completo`).
class MatrizResumo {
  final int idMatriz;
  final int idCurso;
  final String curriculoCompleto;
  final String? anoVigor;

  const MatrizResumo({
    required this.idMatriz,
    required this.idCurso,
    required this.curriculoCompleto,
    this.anoVigor,
  });
}

/// Acesso direto ao Supabase (RLS público) para os dados do fluxograma.
///
/// Espelha as queries do site (`supabase-data.service.ts` /
/// `fluxograma.service.ts`): curso + `materias_por_curso` (nivel = semestre,
/// 0 = optativa) + `pre_requisitos` + `equivalencias`, montados num
/// [CursoModel] do core. Cache in-memory simples por matriz.
class FluxogramaRepository {
  FluxogramaRepository({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  /// Cache por `id_matriz` — o fluxograma de uma matriz não muda na sessão.
  final Map<int, CursoModel> _cachePorMatriz = {};

  /// Lista de cursos para o seletor, ordenada por nome. Turno/campus vêm
  /// junto para distinguir cursos homônimos (diurno vs noturno).
  Future<List<CursoResumo>> buscarCursos() async {
    final rows = await _client
        .from('cursos')
        .select('id_curso, nome_curso, turno, campus')
        .order('nome_curso');

    final cursos = <CursoResumo>[];
    for (final row in asListOr(rows)) {
      final map = asMapOrNull(row);
      if (map == null) continue;
      final id = parseIntOrNull(map['id_curso']);
      final nome = parseStringOr(map['nome_curso']).trim();
      if (id == null || nome.isEmpty) continue;
      cursos.add(
        CursoResumo(
          idCurso: id,
          nomeCurso: nome,
          turno: parseStringOr(map['turno']).trim(),
          campus: parseStringOr(map['campus']).trim(),
        ),
      );
    }
    return cursos;
  }

  /// Matrizes de um curso, da mais recente para a mais antiga.
  Future<List<MatrizResumo>> buscarMatrizes(int idCurso) async {
    final rows = await _client
        .from('matrizes')
        .select('id_matriz, id_curso, curriculo_completo, ano_vigor')
        .eq('id_curso', idCurso)
        .order('ano_vigor', ascending: false);
    return _mapearMatrizes(rows);
  }

  /// Matriz pelo identificador `curriculo_completo` (o que o histórico do
  /// aluno guarda em `matriz_curricular`). Null se não encontrada.
  Future<MatrizResumo?> buscarMatrizPorCurriculo(
    String curriculoCompleto,
  ) async {
    final curriculo = curriculoCompleto.trim();
    if (curriculo.isEmpty) return null;
    final rows = await _client
        .from('matrizes')
        .select('id_matriz, id_curso, curriculo_completo, ano_vigor')
        .eq('curriculo_completo', curriculo)
        .limit(1);
    final matrizes = _mapearMatrizes(rows);
    return matrizes.isEmpty ? null : matrizes.first;
  }

  /// Fluxograma completo de uma matriz: matérias com nível, pré-requisitos e
  /// equivalências, já montados num [CursoModel].
  Future<CursoModel> buscarCursoDaMatriz(MatrizResumo matriz) async {
    final emCache = _cachePorMatriz[matriz.idMatriz];
    if (emCache != null) return emCache;

    final cursoRow = await _client
        .from('cursos')
        .select()
        .eq('id_curso', matriz.idCurso)
        .maybeSingle();
    if (cursoRow == null) {
      throw Exception('Curso não encontrado (id ${matriz.idCurso})');
    }

    final materiasRows = await _client
        .from('materias_por_curso')
        .select(
          'id_materia, nivel, tipo_natureza, '
          'materias(id_materia, codigo_materia, nome_materia, '
          'carga_horaria, ementa)',
        )
        .eq('id_matriz', matriz.idMatriz);

    final idsMaterias = <int>[];
    for (final row in asListOr(materiasRows)) {
      final id = parseIntOrNull(asMapOrNull(row)?['id_materia']);
      if (id != null) idsMaterias.add(id);
    }

    List<dynamic> preReqRows = const [];
    List<dynamic> equivalenciasRows = const [];
    if (idsMaterias.isNotEmpty) {
      final resultados = await Future.wait([
        _client
            .from('pre_requisitos')
            .select(
              'id_pre_requisito, id_materia, id_materia_requisito, '
              'expressao_original, expressao_logica, '
              'materias:id_materia_requisito(codigo_materia, nome_materia)',
            )
            .inFilter('id_materia', idsMaterias),
        _client
            .from('equivalencias')
            .select(
              '*, materias!equivalencias_id_materia_fkey'
              '(codigo_materia, nome_materia)',
            )
            .inFilter('id_materia', idsMaterias),
      ]);
      preReqRows = resultados[0];
      equivalenciasRows = resultados[1];
    }

    final curso = montarCursoModel(
      cursoRow: Map<String, dynamic>.from(cursoRow),
      curriculoCompleto: matriz.curriculoCompleto,
      idCurso: matriz.idCurso,
      materiasRows: asListOr(materiasRows),
      preRequisitosRows: preReqRows,
      equivalenciasRows: equivalenciasRows,
    );
    _cachePorMatriz[matriz.idMatriz] = curso;
    return curso;
  }

  List<MatrizResumo> _mapearMatrizes(dynamic rows) {
    final matrizes = <MatrizResumo>[];
    for (final row in asListOr(rows)) {
      final map = asMapOrNull(row);
      if (map == null) continue;
      final idMatriz = parseIntOrNull(map['id_matriz']);
      final idCurso = parseIntOrNull(map['id_curso']);
      final curriculo = parseStringOr(map['curriculo_completo']).trim();
      if (idMatriz == null || idCurso == null || curriculo.isEmpty) continue;
      matrizes.add(
        MatrizResumo(
          idMatriz: idMatriz,
          idCurso: idCurso,
          curriculoCompleto: curriculo,
          anoVigor: parseStringOrNull(map['ano_vigor']),
        ),
      );
    }
    return matrizes;
  }

  // ── Mapeamento puro (testável com fixtures) ────────────────────────────────

  /// Monta o [CursoModel] a partir das linhas cruas do Supabase.
  ///
  /// - `materiasRows`: shape aninhado de `materias_por_curso`
  ///   (`{ nivel, tipo_natureza, materias: {...} }`), aceito direto pelo
  ///   `MateriaModel.fromJson` do core;
  /// - `preRequisitosRows`: achata o join `materias:id_materia_requisito`
  ///   para os campos planos que o `PreRequisitoModel` espera;
  /// - `equivalenciasRows`: resolve o código/nome de origem pelo join e
  ///   filtra por contexto (curso+currículo > curso > global), como o site.
  static CursoModel montarCursoModel({
    required Map<String, dynamic> cursoRow,
    required String curriculoCompleto,
    required int idCurso,
    required List<dynamic> materiasRows,
    required List<dynamic> preRequisitosRows,
    required List<dynamic> equivalenciasRows,
  }) {
    final preRequisitos = <Map<String, dynamic>>[];
    for (final row in preRequisitosRows) {
      final map = asMapOrNull(row);
      if (map == null) continue;
      final requisito = asMapOrNull(map['materias']);
      preRequisitos.add({
        'id_pre_requisito': map['id_pre_requisito'],
        'id_materia': map['id_materia'],
        'id_materia_requisito': map['id_materia_requisito'],
        'codigo_materia_requisito':
            map['codigo_materia_requisito'] ??
            requisito?['codigo_materia'] ??
            '',
        'nome_materia_requisito':
            map['nome_materia_requisito'] ?? requisito?['nome_materia'] ?? '',
        // Formato novo do banco: a regra vive na expressão (o join acima
        // volta null porque id_materia_requisito não é gravado).
        'expressao_original': map['expressao_original'],
        'expressao_logica': map['expressao_logica'],
      });
    }

    final json = <String, dynamic>{
      ...cursoRow,
      'matriz_curricular': curriculoCompleto,
      'materias_por_curso': materiasRows,
      'pre_requisitos': preRequisitos,
      'equivalencias': filtrarEquivalencias(
        equivalenciasRows,
        idCurso: idCurso,
        curriculoCompleto: curriculoCompleto,
      ),
    };
    return CursoModel.fromJson(json);
  }

  /// A tabela `equivalencias` tem registros de vários cursos para a mesma
  /// matéria. Para cada matéria vale o contexto mais específico disponível:
  /// 1) `id_curso` + currículo exato da matriz;
  /// 2) `id_curso` do curso (sem currículo);
  /// 3) global (`id_curso` e currículo nulos).
  static List<Map<String, dynamic>> filtrarEquivalencias(
    List<dynamic> rows, {
    required int idCurso,
    required String curriculoCompleto,
  }) {
    String norm(dynamic valor) => parseStringOr(valor).trim().toUpperCase();
    final curriculoAlvo = norm(curriculoCompleto);

    final porMateria = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final map = asMapOrNull(row);
      if (map == null) continue;
      final idMateria = parseIntOrNull(map['id_materia']);
      if (idMateria == null) continue;
      porMateria.putIfAbsent(idMateria, () => []).add(map);
    }

    final resultado = <Map<String, dynamic>>[];
    for (final candidatas in porMateria.values) {
      bool especifica(Map<String, dynamic> m) =>
          parseIntOrNull(m['id_curso']) == idCurso &&
          norm(m['curriculo']).isNotEmpty &&
          norm(m['curriculo']) == curriculoAlvo;
      bool doCurso(Map<String, dynamic> m) =>
          parseIntOrNull(m['id_curso']) == idCurso &&
          norm(m['curriculo']).isEmpty;
      bool global(Map<String, dynamic> m) =>
          m['id_curso'] == null && norm(m['curriculo']).isEmpty;

      var escolhidas = candidatas.where(especifica).toList();
      if (escolhidas.isEmpty) escolhidas = candidatas.where(doCurso).toList();
      if (escolhidas.isEmpty) escolhidas = candidatas.where(global).toList();

      for (final map in escolhidas) {
        final origem = asMapOrNull(map['materias']);
        resultado.add({
          ...map,
          'codigo_materia_origem':
              map['codigo_materia_origem'] ?? origem?['codigo_materia'] ?? '',
          'nome_materia_origem':
              map['nome_materia_origem'] ?? origem?['nome_materia'] ?? '',
          'expressao': map['expressao'] ?? map['expressao_original'] ?? '',
        });
      }
    }
    return resultado;
  }
}

/// Repositório do fluxograma (override em testes com um fake).
final fluxogramaRepositoryProvider = Provider<FluxogramaRepository>(
  (ref) => FluxogramaRepository(),
);
