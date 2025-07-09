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
      log.info('Uploading PDF: $fileName');
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

      log.info('Sending PDF to backend...');
      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);

        log.info('PDF processed successfully');
        log.info(
            'Extracted data: ${data['extracted_data']?.length ?? 0} items');
        log.info('Course extracted: ${data['curso_extraido']}');
        log.info('Academic matrix: ${data['matriz_curricular']}');

        return Right(data);
      } else {
        final errorStr = await response.stream.bytesToString();
        log.warning('Error uploading PDF: ${response.statusCode}');
        log.warning('Error details: $errorStr');

        try {
          final errorData = jsonDecode(errorStr);
          return Left(errorData['error'] ??
              'Error uploading PDF: ${response.statusCode}');
        } catch (e) {
          return Left('Error uploading PDF: ${response.statusCode}');
        }
      }
    } catch (e, st) {
      log.severe('Exception while uploading PDF', e, st);
      return Left('Error uploading PDF: $e');
    }
  }

  static Future<Either<String, Map<String, dynamic>>> casarDisciplinas(
      Map<String, dynamic> dadosExtraidos) async {
    try {
      log.info('Starting discipline matching...');
      log.info(
          'Extracted data: ${dadosExtraidos['extracted_data']?.length ?? 0} disciplines');

      // Log extracted PDF information
      log.info('Extracted course: ${dadosExtraidos['curso_extraido']}');
      log.info('Academic matrix: ${dadosExtraidos['matriz_curricular']}');
      log.info('Weighted average: ${dadosExtraidos['media_ponderada']}');
      log.info('General frequency: ${dadosExtraidos['frequencia_geral']}');

      final response = await http.post(
        Uri.parse('${Environment.apiUrl}/fluxograma/casar_disciplinas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dados_extraidos': dadosExtraidos}),
      );

      log.info('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final resultado = jsonDecode(response.body);
        log.info('Backend response received successfully');

        // Detailed logging of results
        _logResultadoDetalhado(resultado);

        return Right(resultado);
      } else {
        final errorBody = response.body;
        log.warning(
            'Error response: ${response.statusCode}\nDetails: $errorBody');

        try {
          final errorData = jsonDecode(errorBody);

          // Check if it's a course selection error
          if (errorData['cursos_disponiveis'] != null) {
            log.info('Course selection error: ${errorData['message']}');
            return Left('SELECAO_CURSO:${jsonEncode(errorData)}');
          }

          // Return specific error message if available
          return Left(errorData['error'] ??
              'Error processing disciplines: ${response.statusCode}');
        } catch (e) {
          return Left('Error processing disciplines: ${response.statusCode}');
        }
      }
    } catch (e, st) {
      log.severe('Exception while matching disciplines', e, st);
      return Left('Error processing disciplines: $e');
    }
  }

  static void _logResultadoDetalhado(Map<String, dynamic> resultado) {
    try {
      // Basic statistics
      log.info('=== DISCIPLINE MATCHING RESULTS ===');
      log.info(
          'Total matched disciplines: ${resultado['disciplinas_casadas']?.length ?? 0}');
      log.info(
          'Completed mandatory subjects: ${resultado['materias_concluidas']?.length ?? 0}');
      log.info(
          'Pending mandatory subjects: ${resultado['materias_pendentes']?.length ?? 0}');
      log.info(
          'Elective subjects: ${resultado['materias_optativas']?.length ?? 0}');

      // Summary information
      if (resultado['resumo'] != null) {
        final resumo = resultado['resumo'] as Map<String, dynamic>;
        log.info(
            'Completion percentage: ${resumo['percentual_conclusao_obrigatorias']?.toStringAsFixed(1) ?? 'N/A'}%');
        log.info(
            'Total disciplines in transcript: ${resumo['total_disciplinas'] ?? 0}');
        log.info(
            'Total completed mandatory: ${resumo['total_obrigatorias_concluidas'] ?? 0}');
        log.info(
            'Total pending mandatory: ${resumo['total_obrigatorias_pendentes'] ?? 0}');
        log.info('Total electives: ${resumo['total_optativas'] ?? 0}');
      }

      // Validation data
      if (resultado['dados_validacao'] != null) {
        final validacao = resultado['dados_validacao'] as Map<String, dynamic>;
        log.info('=== VALIDATION DATA ===');
        log.info('IRA: ${validacao['ira'] ?? 'N/A'}');
        log.info('Weighted average: ${validacao['media_ponderada'] ?? 'N/A'}');
        log.info(
            'General frequency: ${validacao['frequencia_geral'] ?? 'N/A'}');
        log.info(
            'Integrated hours: ${validacao['horas_integralizadas'] ?? 0}h');

        if (validacao['pendencias'] != null) {
          final pendencias = validacao['pendencias'];
          if (pendencias is List) {
            log.info('Pending items: ${pendencias.join(', ')}');
          } else if (pendencias is Map) {
            log.info(
                'Pending items: ${pendencias.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
          }
        }

        log.info('Extracted course: ${validacao['curso_extraido'] ?? 'N/A'}');
        log.info('Academic matrix: ${validacao['matriz_curricular'] ?? 'N/A'}');
      }

      // Detailed discipline analysis
      if (resultado['disciplinas_casadas'] != null) {
        final disciplinas = resultado['disciplinas_casadas'] as List<dynamic>;
        int encontradas = 0;
        int naoEncontradas = 0;

        log.fine('=== DETAILED DISCIPLINE ANALYSIS ===');

        for (var disc in disciplinas) {
          bool encontrada = disc['encontrada_no_banco'] == true;

          if (!encontrada) {
            naoEncontradas++;
            log.warning(
                'NOT FOUND: "${disc['nome']}" (Code: ${disc['codigo'] ?? 'N/A'})');
          } else {
            encontradas++;
            log.fine(
                'FOUND: "${disc['nome']}" (ID: ${disc['id_materia']}, Status: ${disc['status']})');
          }
        }

        log.info('=== MATCHING SUMMARY ===');
        log.info('Found in database: $encontradas');
        log.info('Not found in database: $naoEncontradas');
        log.info(
            'Match rate: ${encontradas > 0 ? (encontradas / (encontradas + naoEncontradas) * 100).toStringAsFixed(1) : 0}%');
      }

      // Subject categories breakdown
      _logSubjectCategories(resultado);
    } catch (e, st) {
      log.severe('Error logging detailed results', e, st);
    }
  }

  static void _logSubjectCategories(Map<String, dynamic> resultado) {
    try {
      log.info('=== SUBJECT CATEGORIES ===');

      // Completed mandatory subjects
      if (resultado['materias_concluidas'] != null) {
        final concluidas = resultado['materias_concluidas'] as List<dynamic>;
        log.info('Completed mandatory subjects (${concluidas.length}):');
        for (var materia in concluidas.take(5)) {
          // Show first 5
          log.fine('  ✓ ${materia['nome']} (${materia['status']})');
        }
        if (concluidas.length > 5) {
          log.fine('  ... and ${concluidas.length - 5} more');
        }
      }

      // Pending mandatory subjects
      if (resultado['materias_pendentes'] != null) {
        final pendentes = resultado['materias_pendentes'] as List<dynamic>;
        log.info('Pending mandatory subjects (${pendentes.length}):');
        for (var materia in pendentes.take(3)) {
          // Show first 3
          log.fine(
              '  ⏳ ${materia['nome']} (${materia['status_fluxograma'] ?? 'pending'})');
        }
        if (pendentes.length > 3) {
          log.fine('  ... and ${pendentes.length - 3} more');
        }
      }

      // Elective subjects
      if (resultado['materias_optativas'] != null) {
        final optativas = resultado['materias_optativas'] as List<dynamic>;
        log.info('Elective subjects (${optativas.length}):');
        for (var materia in optativas.take(3)) {
          // Show first 3
          log.fine('  📚 ${materia['nome']} (${materia['status']})');
        }
        if (optativas.length > 3) {
          log.fine('  ... and ${optativas.length - 3} more');
        }
      }
    } catch (e, st) {
      log.severe('Error logging subject categories', e, st);
    }
  }

  static Future<Either<String, String>> uploadFluxogramaToDB(
      DadosFluxogramaUser dadosFluxograma) async {
    try {
      log.info('Saving flowchart to database...');
      var uri =
          Uri.parse('${Environment.apiUrl}/fluxograma/upload-dados-fluxograma');

      final requestBody = {
        "fluxograma": dadosFluxograma.toJson(),
        "periodo_letivo": dadosFluxograma.semestreAtual,
      };

      log.fine('Request body: ${jsonEncode(requestBody).substring(0, 200)}...');

      var response = await http.post(
        uri,
        body: jsonEncode(requestBody),
        headers: await Environment.getHeadersForAuthorizedRequest(),
      );

      if (response.statusCode == 200) {
        log.info('Flowchart saved successfully');
        return Right('Flowchart saved successfully');
      } else {
        log.severe(
            'Error saving flowchart: ${response.statusCode} - ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          return Left(errorData['error'] ??
              'Error saving flowchart: ${response.statusCode}');
        } catch (e) {
          return Left('Error saving flowchart: ${response.statusCode}');
        }
      }
    } catch (e, st) {
      log.severe('Exception while saving flowchart', e, st);
      return Left('Error saving flowchart: $e');
    }
  }
}
