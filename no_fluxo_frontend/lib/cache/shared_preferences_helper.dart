import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;
  static const String keyUser = "user";

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static UserModel? get currentUser {
    final userJson = _prefs?.getString(keyUser);
    if (userJson == "null") {
      return null;
    }
    return userJson != null ? UserModel.fromJson(jsonDecode(userJson)) : null;
  }

  static set currentUser(UserModel? user) {
    if (user != null) {
      _prefs?.setString(keyUser, jsonEncode(user.toJson()));
    } else {
      _prefs?.remove(keyUser);
    }
  }
}
