import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache/shared_preferences_helper.dart';

enum EnvironmentType {
  development,
  production,
}

class Environment {
  static String apiUrl = "http://localhost:3000";

  static EnvironmentType environmentType = EnvironmentType.development;

  static String getApiUrl() {
    return apiUrl;
  }

  static void setEnvironmentType(EnvironmentType environmentType) {
    Environment.environmentType = environmentType;

    if (environmentType == EnvironmentType.development) {
      apiUrl = "http://localhost:3000";
    } else {
      apiUrl = "https://no-fluxo.vercel.app";
    }
  }

  static Future<Map<String, String>> getHeadersForAuthorizedRequest() async {
    final session = await Supabase.instance.client.auth.refreshSession();
    return {
      "Authorization": session.session?.accessToken ?? "",
      "User-ID": SharedPreferencesHelper.currentUser?.idUser.toString() ?? "",
      "Content-Type": "application/json"
    };
  }
}
