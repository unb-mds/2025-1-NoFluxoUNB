import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/environment.dart';

import '../data/curso_model.dart';
import '../data/materia_model.dart';

var log = Environment.getLogger("MeuFluxogramaService");

class MeuFluxogramaService {
  static Future<Either<String, Map<String, String>>> getNameOfMateriasByCode(
      List<String> codes) async {
    try {
      final response = await http.post(
          Uri.parse('${Environment.apiUrl}/materias/materias-name-by-code'),
          body: {"codes": codes});

      if (response.statusCode == 200) {
        return Right(jsonDecode(response.body));
      } else {
        return Left(response.body);
      }
    } catch (e) {
      log.severe(e, StackTrace.current);
      return Left(e.toString());
    }
  }

  static Future<Either<String, List<MateriaModel>>>
      getMateriasCursadasAsMateriaModel(
          List<String> codigosMaterias, int idCurso) async {
    try {
      final response = await http.post(
          Uri.parse('${Environment.apiUrl}/materias/materias-from-codigos'),
          body: {
            "codigos": jsonEncode(codigosMaterias),
            "id_curso": idCurso.toString()
          });

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return Right(List<MateriaModel>.from(
            json.map((materia) => MateriaModel.fromJson(materia))));
      } else {
        return Left(response.body);
      }
    } catch (e) {
      log.severe(e, StackTrace.current);
      return Left(e.toString());
    }
  }

  static Future<Either<String, List<CursoModel>>> getCourseData(
      String courseName) async {
    try {
      if (courseName.isEmpty) {
        return Left('Nome do curso não informado');
      }
      final response = await http.get(Uri.parse(
          '${Environment.apiUrl}/fluxograma/fluxograma?nome_curso=$courseName'));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);

        List<CursoModel> cursos = List<CursoModel>.from(
            json.map((curso) => CursoModel.fromJson(curso)));

        // Prerequisites are automatically populated in CursoModel.fromJson()

        return Right(cursos);
      } else {
        return Left(response.body);
      }
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }

  /// Get prerequisites for a specific materia within a course
  static Future<Either<String, List<MateriaModel>>> getPrerequisitesForMateria(
      int idMateria, int idCurso) async {
    try {
      // First get the course data
      var courseResult = await http.get(Uri.parse(
          '${Environment.apiUrl}/fluxograma/fluxograma-by-id?id_curso=$idCurso'));

      if (courseResult.statusCode != 200) {
        return Left('Failed to get course data: ${courseResult.body}');
      }

      var courseJson = jsonDecode(courseResult.body);
      var curso = CursoModel.fromJson(courseJson[0]); // Assumes first result

      // Find the materia and return its prerequisites
      var materia = curso.materias.firstWhere((m) => m.idMateria == idMateria,
          orElse: () => throw Exception('Materia not found'));

      return Right(materia.prerequisitos);
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }

  /// Get direct prerequisites only (not transitive)
  static Future<Either<String, List<MateriaModel>>>
      getDirectPrerequisitesForMateria(
          String codigoMateria, int idCurso) async {
    try {
      // First get the course data
      var courseResult = await http.get(Uri.parse(
          '${Environment.apiUrl}/fluxograma/fluxograma-by-id?id_curso=$idCurso'));

      if (courseResult.statusCode != 200) {
        return Left('Failed to get course data: ${courseResult.body}');
      }

      var courseJson = jsonDecode(courseResult.body);
      var curso = CursoModel.fromJson(courseJson[0]); // Assumes first result

      // Get direct prerequisites for the materia
      var directPrerequisites = curso.getDirectPrerequisites(codigoMateria);

      return Right(directPrerequisites);
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }

  static Future<Either<String, MateriaModel>> getMateriaData(
      int idMateria) async {
    try {
      final response = await http
          .get(Uri.parse('${Environment.apiUrl}/materias/$idMateria'));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return Right(MateriaModel.fromJson(json));
      } else {
        return Left(response.body);
      }
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }

  static Future<Either<String, List<CursoModel>>> getAllCursosMinimal() async {
    try {
      final response =
          await http.get(Uri.parse('${Environment.apiUrl}/cursos/all-cursos'));

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return Right(List<CursoModel>.from(
            json.map((curso) => CursoModel.fromMinimalJson(curso))));
      } else {
        return Left(response.body);
      }
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }

  static Future<Either<String, bool>> deleteFluxogramaUser(
      String userId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${Environment.apiUrl}/fluxograma/delete-fluxograma'),
        headers: {
          'user-id': userId,
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return const Right(true);
      } else {
        return Left(response.body);
      }
    } catch (e, stackTrace) {
      log.severe(e, stackTrace);
      return Left(e.toString());
    }
  }
}
