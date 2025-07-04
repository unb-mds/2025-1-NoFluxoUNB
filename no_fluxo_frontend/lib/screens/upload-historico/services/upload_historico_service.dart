import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mobile_app/environment.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

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
      Map<String, dynamic> dadosExtraidos,
      {String nomeCurso = 'ENGENHARIA DE SOFTWARE'}) async {
    try {
      log.info('Enviando dados para casamento...');
      log.info(
          'Dados extraídos: ${dadosExtraidos['extracted_data']?.length} disciplinas');

      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/fluxograma/casar_disciplinas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'dados_extraidos': dadosExtraidos, 'nome_curso': nomeCurso}),
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
        log.warning(
            'Erro na resposta: ${response.statusCode}\nDetalhes: $errorBody');
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
          'Horas integralizadas: ${resultado['dados_validacao']['horas_integralizadas']}h');
      log.info(
          'Pendências: ${resultado['dados_validacao']['pendencias'].join(', ')}');
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
}
