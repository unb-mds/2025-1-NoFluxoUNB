import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;
  static const String keyUser = "user";
  static const String keyAnonimo = "anonimo";

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  

  static UserModel? get currentUser {
    final userJson = _prefs?.getString(keyUser);
    if (userJson == "null") {
      return null;
    }

    if (userJson == null) {
      return null;
    }

    var userJsonMap = jsonDecode(userJson);

    var user = UserModel.fromJson(userJsonMap);
    user.token = userJsonMap["token"];
    return user;
  }

  static set currentUser(UserModel? user) {
    if (user != null) {
      _prefs?.setString(
          keyUser,
          jsonEncode(
              user.toJson(includeToken: true, includeDadosFluxograma: true)));
    } else {
      _prefs?.remove(keyUser);
    }
  }

  static bool get isAnonimo {
    return _prefs?.getBool(keyAnonimo) ?? false;
  }

  static set isAnonimo(bool value) {
    _prefs?.setBool(keyAnonimo, value);
  }
}
