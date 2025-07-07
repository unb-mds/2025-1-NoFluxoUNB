import 'dart:convert';

class DadosMateria {
  String codigoMateria;
  String mencao;
  String professor;

  DadosMateria({
    required this.codigoMateria,
    required this.mencao,
    required this.professor,
  });

  factory DadosMateria.fromJson(Map<String, dynamic> json) {
    return DadosMateria(
      codigoMateria: json['codigo'],
      mencao: json['mencao'],
      professor: json['professor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigoMateria,
      'mencao': mencao,
      'professor': professor,
    };
  }
}

class DadosFluxogramaUser {
  String nomeCurso;
  double ira;
  String matricula;
  String matrizCurricular;
  int semestreAtual;
  List<List<DadosMateria>> dadosFluxograma;

  DadosFluxogramaUser({
    required this.nomeCurso,
    required this.ira,
    required this.dadosFluxograma,
    required this.matricula,
    required this.semestreAtual,
    required this.matrizCurricular,
  });

  factory DadosFluxogramaUser.fromJson(Map<String, dynamic> json) {
    return DadosFluxogramaUser(
      nomeCurso: json['nome_curso'],
      ira: json['ira'],
      matricula: json['matricula'],
      semestreAtual: json['semestre_atual'],
      matrizCurricular: json['matriz_curricular'],
      dadosFluxograma: List<List<DadosMateria>>.from(json['dados_fluxograma']
          .map((e) =>
              List<DadosMateria>.from(e.map((e) => DadosMateria.fromJson(e))))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome_curso': nomeCurso,
      'ira': ira,
      'matricula': matricula,
      'matriz_curricular': matrizCurricular,
      'semestre_atual': semestreAtual,
      'dados_fluxograma': dadosFluxograma
          .map((e) => e.map((e) => e.toJson()).toList())
          .toList(),
    };
  }
}

class UserModel {
  final int idUser;
  final String email;
  final String nomeCompleto;
  DadosFluxogramaUser? dadosFluxograma;
  String? token;

  UserModel(
      {required this.idUser,
      required this.email,
      required this.nomeCompleto,
      this.dadosFluxograma,
      this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var user = UserModel(
        idUser: json['id_user'],
        email: json['email'],
        nomeCompleto: json['nome_completo'],
        dadosFluxograma: null);

    if (json['dados_users'] != null &&
        json['dados_users'].length > 0 &&
        json['dados_users'][0] != null &&
        json['dados_users'][0] is Map<String, dynamic> &&
        json['dados_users'][0]["fluxograma_atual"] != null) {
      user.dadosFluxograma = DadosFluxogramaUser.fromJson(
          jsonDecode(json['dados_users'][0]["fluxograma_atual"]));
    }

    return user;
  }

  Map<String, dynamic> toJson(
      {bool includeToken = false, bool includeDadosFluxograma = false}) {
    return {
      'id_user': idUser,
      'email': email,
      'nome_completo': nomeCompleto,
      if (includeToken) 'token': token,
      if (includeDadosFluxograma && dadosFluxograma != null)
        'dados_users': [
          Map<String, dynamic>.from(
            {
              "fluxograma_atual": jsonEncode(dadosFluxograma!.toJson()),
            },
          )
        ],
    };
  }

  Map<String, dynamic> toJsonDadosFluxograma() {
    return {"id_user": idUser, 'fluxograma_atual': dadosFluxograma?.toJson()};
  }
}
