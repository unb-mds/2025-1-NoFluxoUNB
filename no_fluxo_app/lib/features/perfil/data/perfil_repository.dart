import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/progresso_calculator.dart';

/// Acesso a dados da tela de Perfil.
///
/// Busca as exigências de carga horária da matriz do aluno (tabela
/// `matrizes`) e a carga horária integralizada dele (coluna JSON
/// `dados_users.carga_horaria_integralizada`).
class PerfilRepository {
  final SupabaseClient? _clientOverride;

  const PerfilRepository({SupabaseClient? client}) : _clientOverride = client;

  /// Lazy para os testes poderem instanciar sem Supabase inicializado.
  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  /// Busca as exigências da matriz pelo identificador `curriculo_completo`
  /// (o `matriz_curricular` do histórico do aluno, ex.: "6360/2 - 2017.1").
  ///
  /// Mesma regra do site (supabase-data.service.ts):
  /// 1) match exato em `curriculo_completo`;
  /// 2) fallback por `id_curso` + `versao` extraídos de "codigo/versao".
  ///
  /// Retorna null quando não encontra ou em erro de rede (a tela degrada
  /// para mostrar só o que não depende da matriz).
  Future<ExigenciasMatriz?> buscarExigenciasMatriz(
    String matrizCurricular,
  ) async {
    final s = matrizCurricular.trim();
    if (s.isEmpty) return null;
    try {
      final exato = await _client
          .from('matrizes')
          .select(
            'curriculo_completo, ch_obrigatoria_exigida, '
            'ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida',
          )
          .eq('curriculo_completo', s)
          .maybeSingle();
      if (exato != null) return ExigenciasMatriz.fromJson(exato);

      final partes = _parseCurriculoCompleto(s);
      final codigoCurso = int.tryParse(partes.codigoCurso);
      if (codigoCurso == null || partes.versao.isEmpty) return null;

      final linhas = await _client
          .from('matrizes')
          .select(
            'curriculo_completo, ch_obrigatoria_exigida, '
            'ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida',
          )
          .eq('id_curso', codigoCurso)
          .eq('versao', partes.versao)
          .order('ano_vigor', ascending: false)
          .limit(1);
      if (linhas.isEmpty) return null;
      return ExigenciasMatriz.fromJson(linhas.first);
    } catch (e) {
      debugPrint('Erro ao buscar exigências da matriz: $e');
      return null;
    }
  }

  /// Busca a carga horária integralizada do usuário logado
  /// (`dados_users.carga_horaria_integralizada`, JSON
  /// `{total, obrigatoria, optativa, complementar}`).
  ///
  /// Retorna null se a linha não existe, a coluna está vazia (upload antigo)
  /// ou em erro de rede.
  Future<CargaHorariaIntegralizada?> buscarCargaHorariaIntegralizada(
    int idUser,
  ) async {
    try {
      final linha = await _client
          .from('dados_users')
          .select('carga_horaria_integralizada')
          .eq('id_user', idUser)
          .maybeSingle();
      if (linha == null) return null;
      return CargaHorariaIntegralizada.fromDynamic(
        linha['carga_horaria_integralizada'],
      );
    } catch (e) {
      debugPrint('Erro ao buscar carga horária integralizada: $e');
      return null;
    }
  }

  /// Decompõe "8117/-2 - 2018.2" (com sufixo opcional " - DIURNO"/" - NOTURNO")
  /// em código do curso e versão — mesma regra do site.
  static ({String codigoCurso, String versao}) _parseCurriculoCompleto(
    String curriculoCompleto,
  ) {
    final semTurno = curriculoCompleto
        .trim()
        .replaceFirst(
          RegExp(r'\s*-\s*(DIURNO|NOTURNO)\s*$', caseSensitive: false),
          '',
        )
        .trim();
    final barra = semTurno.split('/');
    final codigoCurso = barra.isNotEmpty ? barra.first.trim() : '';
    final depoisDaBarra = barra.length > 1 ? barra[1].trim() : '';
    // Remove o sufixo de ano (" - 2018.2") para sobrar só a versão.
    final versao = depoisDaBarra
        .replaceFirst(RegExp(r'\s*-\s*\d{4}\.\d\s*$'), '')
        .trim();
    return (codigoCurso: codigoCurso, versao: versao);
  }
}

/// Repositório da tela de Perfil (override em testes).
final perfilRepositoryProvider = Provider<PerfilRepository>(
  (ref) => const PerfilRepository(),
);

/// Progresso consolidado do usuário logado.
///
/// Junta: exigências da matriz + carga horária integralizada + contagem de
/// matérias do fluxograma. Null quando não há usuário logado. Buscas que
/// falham degradam para null (a tela mostra o que tiver).
final progressoPerfilProvider = FutureProvider.autoDispose<ProgressoPerfil?>((
  ref,
) async {
  final auth = await ref.watch(authProvider.future);
  final user = auth.user;
  if (user == null) return null;

  final dados = auth.dados;
  final repo = ref.watch(perfilRepositoryProvider);

  final resultados = await Future.wait([
    repo.buscarExigenciasMatriz(dados?.matrizCurricular ?? ''),
    repo.buscarCargaHorariaIntegralizada(user.idUser),
  ]);

  return ProgressoCalculator.calcular(
    exigencias: resultados[0] as ExigenciasMatriz?,
    integralizada: resultados[1] as CargaHorariaIntegralizada?,
    dados: dados,
    horasIntegralizadasFallback: dados?.horasIntegralizadas ?? 0,
  );
});
