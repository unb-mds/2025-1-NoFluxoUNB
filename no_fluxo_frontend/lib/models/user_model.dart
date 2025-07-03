class UserModel {
  final int idUser;
  final String email;
  final String nomeCompleto;

  UserModel(
      {required this.idUser, required this.email, required this.nomeCompleto});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
        idUser: json['id_user'],
        email: json['email'],
        nomeCompleto: json['nome_completo']);
  }

  Map<String, dynamic> toJson() {
    return {'id_user': idUser, 'email': email, 'nome_completo': nomeCompleto};
  }
}
