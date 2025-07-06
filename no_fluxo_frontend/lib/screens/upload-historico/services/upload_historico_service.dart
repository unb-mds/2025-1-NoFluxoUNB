import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mobile_app/environment.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mobile_app/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cache/shared_preferences_helper.dart';

final log = Logger('UploadHistoricoService');

class UploadHistoricoService {
  static Future<Either<String, Map<String, dynamic>>> uploadPdfBytes(
      Uint8List bytes, String fileName) async {
    try {
      var uri = Uri.parse('${Environment.apiUrl}/fluxograma/read_pdf');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf',
          bytes,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );
      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        return Right(data);
      } else {
        log.warning('Erro ao enviar PDF: ${response.statusCode}');
        return Left('Erro ao enviar PDF: ${response.statusCode}');
      }
    } catch (e, st) {
      log.severe('Erro ao enviar PDF', e, st);
      return Left('Erro ao enviar PDF: $e');
    }
  }

  static Future<Either<String, Map<String, dynamic>>> casarDisciplinas(
      Map<String, dynamic> dadosExtraidos) async {
    try {
      log.info('Enviando dados para casamento...');
      log.info(
          'Dados extraídos: ${dadosExtraidos['extracted_data']?.length} disciplinas');

      // Log das informações extraídas do PDF
      log.info('Curso extraído: ${dadosExtraidos['curso_extraido']}');
      log.info('Matriz curricular: ${dadosExtraidos['matriz_curricular']}');
      log.info('Média ponderada: ${dadosExtraidos['media_ponderada']}');
      log.info('Frequência geral: ${dadosExtraidos['frequencia_geral']}');

      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/fluxograma/casar_disciplinas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dados_extraidos': dadosExtraidos}),
      );

      log.info('Status da resposta: ${response.statusCode}');

      if (response.statusCode == 200) {
        final resultado = jsonDecode(response.body);
        log.info('Resposta do backend recebida com sucesso');

        // Log detalhado dos resultados
        _logResultadoDetalhado(resultado);

        return Right(resultado);
      } else {
        final errorBody = response.body;
        final errorData = jsonDecode(errorBody);
        log.warning(
            'Erro na resposta: ${response.statusCode}\nDetalhes: $errorBody');

        // Verificar se é um erro de seleção de curso
        if (errorData['cursos_disponiveis'] != null) {
          log.info('Erro de seleção de curso: ${errorData['message']}');
          return Left('SELECAO_CURSO:${jsonEncode(errorData)}');
        }

        return Left('Erro ao processar disciplinas: ${response.statusCode}');
      }
    } catch (e, st) {
      log.severe('Erro ao casar disciplinas', e, st);
      return Left('Erro ao processar disciplinas: $e');
    }
  }

  static void _logResultadoDetalhado(Map<String, dynamic> resultado) {
    log.info(
        'Total disciplinas casadas: ${resultado['disciplinas_casadas']?.length}');
    log.info(
        'Matérias obrigatórias concluídas: ${resultado['materias_concluidas']?.length}');
    log.info(
        'Matérias obrigatórias pendentes: ${resultado['materias_pendentes']?.length}');
    log.info(
        'Matérias optativas: ${resultado['materias_optativas']?.length ?? 0}');
    log.info(
        'Percentual de conclusão obrigatórias: ${resultado['resumo']?['percentual_conclusao_obrigatorias']?.toStringAsFixed(1)}%');

    if (resultado['dados_validacao'] != null) {
      log.info('DADOS DE VALIDAÇÃO:');
      log.info('IRA: ${resultado['dados_validacao']['ira']}');
      log.info(
          'Média ponderada: ${resultado['dados_validacao']['media_ponderada']}');
      log.info(
          'Frequência geral: ${resultado['dados_validacao']['frequencia_geral']}');
      log.info(
          'Horas integralizadas: ${resultado['dados_validacao']['horas_integralizadas']}h');
      log.info(
          'Pendências: ${resultado['dados_validacao']['pendencias'].join(', ')}');
      log.info(
          'Curso extraído: ${resultado['dados_validacao']['curso_extraido']}');
      log.info(
          'Matriz curricular: ${resultado['dados_validacao']['matriz_curricular']}');
    }

    // Debug detalhado das disciplinas
    if (resultado['disciplinas_casadas'] != null) {
      log.fine('DEBUG DETALHADO:');
      for (var disc in resultado['disciplinas_casadas']) {
        bool encontrada = disc['encontrada_no_banco'] == true ||
            disc['encontrada_no_banco'] == 'true';
        if (!encontrada) {
          log.warning(
              'NÃO ENCONTRADA: "${disc['nome']}" (Código: ${disc['codigo'] ?? 'N/A'})');
        } else {
          log.fine('ENCONTRADA: "${disc['nome']}" (ID: ${disc['id_materia']})');
        }
      }
    }
  }

  static Future<Either<String, String>> uploadFluxogramaToDB(
      DadosFluxogramaUser dadosFluxograma) async {
    try {
      log.info('Salvando fluxograma no banco de dados...');
      var uri =
          Uri.parse('${Environment.apiUrl}/fluxograma/upload-dados-fluxograma');
      var response = await http.post(uri,
          body: jsonEncode(dadosFluxograma.toJson()
            ..addAll({
              'periodo_letivo': dadosFluxograma.semestreAtual,
            })),
          headers: Environment.getHeadersForAuthorizedRequest());
      if (response.statusCode == 200) {
        return Right('Fluxograma salvo com sucesso');
      } else {
        log.severe('Erro ao salvar fluxograma: ${response.body}');
        return Left('Erro ao salvar fluxograma: ${response.body}');
      }
    } catch (e, st) {
      log.severe('Erro ao salvar fluxograma', e, st);
      return Left('Erro ao salvar fluxograma: $e');
    }
  }
}
