import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/casamento.dart';

/// Metadados do envio para a linha de `historicos_usuarios` (o
/// `HistoricoEnvioMetadata` do site).
class MetadadosEnvioHistorico {
  final String? cursoExtraido;
  final String? matrizCurricular;
  final String? matricula;
  final double? ira;
  final double? mediaPonderada;
  final Map<String, dynamic>? cargaHorariaIntegralizada;
  final List<String>? suspensoes;
  final ResumoCasamento? resumo;

  const MetadadosEnvioHistorico({
    this.cursoExtraido,
    this.matrizCurricular,
    this.matricula,
    this.ira,
    this.mediaPonderada,
    this.cargaHorariaIntegralizada,
    this.suspensoes,
    this.resumo,
  });
}

/// Acesso a banco da importação de histórico. A UI e o controller dependem
/// só desta interface — os testes usam um fake.
abstract class ImportarHistoricoRepository {
  /// Chama a RPC `casar_disciplinas` com o `p_dados` já montado
  /// ([ParsedPdfResult.toPDados]) e classifica a resposta.
  ///
  /// Lança [ImportarHistoricoException] com a mensagem do site quando a RPC
  /// demora mais de 30s ou devolve erro de negócio.
  Future<RespostaCasamento> casarDisciplinas(Map<String, dynamic> pDados);

  /// Salva o fluxograma — porte de `saveFluxogramaData`
  /// (supabase-data.service.ts ~723-781):
  /// 1. upsert em `dados_users` (fluxograma_atual como STRING JSON);
  /// 2. insert em `historicos_usuarios` (fluxograma_atual como OBJETO) —
  ///    falha aqui só loga, não interrompe.
  Future<void> salvarFluxograma({
    required int idUser,
    required Map<String, dynamic> fluxogramaJson,
    int? semestreAtual,
    Map<String, dynamic>? cargaHorariaIntegralizada,
    MetadadosEnvioHistorico? metadados,
  });

  /// Cursos + matrizes para o seletor do modo manual (espelho de
  /// `getAllMatrizesWithCurso` do site).
  Future<List<OpcaoCurso>> buscarOpcoesDeCurso();
}

/// Implementação real (Supabase direto, como o site pós-SSR-removal).
class ImportarHistoricoRepositorySupabase
    implements ImportarHistoricoRepository {
  ImportarHistoricoRepositorySupabase({
    SupabaseClient? client,
    this.timeoutRpc = const Duration(seconds: 30),
    Future<dynamic> Function(Map<String, dynamic> pDados)? rpcOverride,
  }) : _clientOverride = client,
       _rpcOverride = rpcOverride;

  final SupabaseClient? _clientOverride;

  /// Limite da RPC (30s no site; encurtado nos testes).
  final Duration timeoutRpc;

  /// Seam da chamada RPC para os testes exercitarem timeout/classificação
  /// sem Supabase real.
  final Future<dynamic> Function(Map<String, dynamic> pDados)? _rpcOverride;

  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  Future<dynamic> _chamarRpc(Map<String, dynamic> pDados) {
    final override = _rpcOverride;
    if (override != null) return override(pDados);
    return _client.rpc('casar_disciplinas', params: {'p_dados': pDados});
  }

  @override
  Future<RespostaCasamento> casarDisciplinas(
    Map<String, dynamic> pDados,
  ) async {
    dynamic data;
    try {
      data = await _chamarRpc(pDados).timeout(timeoutRpc);
    } on TimeoutException {
      throw const ImportarHistoricoException(kMsgTimeoutCasamento);
    } on PostgrestException catch (e) {
      throw ImportarHistoricoException(
        e.message.isNotEmpty ? e.message : 'Erro ao processar disciplinas',
      );
    }

    final json = asMapOrNull(data);
    if (json == null) {
      throw const ImportarHistoricoException('Erro ao processar disciplinas');
    }
    return classificarRespostaCasarDisciplinas(json);
  }

  @override
  Future<void> salvarFluxograma({
    required int idUser,
    required Map<String, dynamic> fluxogramaJson,
    int? semestreAtual,
    Map<String, dynamic>? cargaHorariaIntegralizada,
    MetadadosEnvioHistorico? metadados,
  }) async {
    // Matrícula correta (do parser) sempre presente no JSON gravado.
    var dataToStore = fluxogramaJson;
    final matricula = metadados?.matricula;
    if (matricula != null) {
      dataToStore = {...fluxogramaJson, 'matricula': matricula};
    }

    final payload = <String, dynamic>{
      'id_user': idUser,
      'fluxograma_atual': jsonEncode(dataToStore),
      'semestre_atual': semestreAtual,
    };
    if (cargaHorariaIntegralizada != null) {
      payload['carga_horaria_integralizada'] = cargaHorariaIntegralizada;
    }

    // 1. Estado atual (mesma linha, id_dado_user preservado).
    final Map<String, dynamic> data;
    try {
      data = await _client
          .from('dados_users')
          .upsert(payload, onConflict: 'id_user')
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw ImportarHistoricoException(
        'Erro ao salvar fluxograma: ${e.message}',
      );
    }

    // 2. Registro histórico (acompanhamento ao longo dos anos) — best effort.
    final idDadoUser = parseIntOrNull(data['id_dado_user']);
    if (metadados == null || idDadoUser == null) return;
    final resumo = metadados.resumo;
    final historicoPayload = <String, dynamic>{
      'id_user': idUser,
      'id_dado_user': idDadoUser,
      'curso_extraido': metadados.cursoExtraido,
      'matriz_curricular': metadados.matrizCurricular,
      'matricula': metadados.matricula,
      'semestre_atual': semestreAtual,
      'numero_semestre': semestreAtual,
      'ira': metadados.ira,
      'media_ponderada': metadados.mediaPonderada,
      'carga_horaria_integralizada':
          metadados.cargaHorariaIntegralizada ?? cargaHorariaIntegralizada,
      'suspensoes': metadados.suspensoes,
      'fluxograma_atual': dataToStore,
      'total_disciplinas': resumo?.totalDisciplinas,
      'total_obrigatorias': resumo?.totalObrigatorias,
      'total_obrigatorias_concluidas': resumo?.totalObrigatoriasConcluidas,
      'total_obrigatorias_pendentes': resumo?.totalObrigatoriasPendentes,
      'percentual_conclusao': resumo?.percentualConclusaoObrigatorias,
    };
    try {
      await _client.from('historicos_usuarios').insert(historicoPayload);
    } catch (e) {
      debugPrint(
        '[ImportarHistorico] Falha ao registrar histórico '
        '(tabela pode não existir): $e',
      );
    }
  }

  @override
  Future<List<OpcaoCurso>> buscarOpcoesDeCurso() async {
    final rows = await _client
        .from('matrizes')
        .select(
          'id_matriz, id_curso, curriculo_completo, '
          'cursos(id_curso, nome_curso, turno)',
        )
        .order('curriculo_completo');

    final opcoes = <OpcaoCurso>[];
    for (final row in asListOr(rows)) {
      final map = asMapOrNull(row);
      if (map == null) continue;
      final cursosRaw = map['cursos'];
      final curso =
          asMapOrNull(
            cursosRaw is List && cursosRaw.isNotEmpty
                ? cursosRaw.first
                : cursosRaw,
          ) ??
          const {};
      final nome = parseStringOr(curso['nome_curso']).trim();
      if (nome.isEmpty) continue;
      opcoes.add(
        OpcaoCurso(
          nomeCurso: nome,
          idCurso: parseIntOrNull(curso['id_curso'] ?? map['id_curso']),
          matrizCurricular: parseStringOrNull(map['curriculo_completo']),
          turno: parseStringOrNull(curso['turno']),
        ),
      );
    }
    return opcoes;
  }
}

/// Repositório da importação (override em testes com um fake).
final importarHistoricoRepositoryProvider =
    Provider<ImportarHistoricoRepository>(
      (ref) => ImportarHistoricoRepositorySupabase(),
    );
