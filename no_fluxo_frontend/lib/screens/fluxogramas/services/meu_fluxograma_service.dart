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

        return Right(cursos);
      } else {
        return Left(response.body);
      }
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
    } catch (e) {
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
    } catch (e) {
      return Left(e.toString());
    }
  }
}
